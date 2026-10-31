# Run a coding agent (OpenCode, or Ori - OpenRouter's agent launcher) inside a
# sandbox: bubblewrap on Linux, Seatbelt (sandbox-exec) on macOS. Opt-in: the plain `opencode` / `ori` commands are
# untouched; use `opencode-safe` / `ori-safe` (aliases) or call this directly.
#
# What the agent can see:
#   - the current project directory, read-write (git toplevel if inside a repo)
#   - its own config/state directories, read-write
#   - Linux: /usr, /etc and /nix read-only, plus a read-only git config and
#     nix profile. macOS: everything outside $HOME may be read, but not written
#   - the network (it needs it to reach the model API), unless --no-net
# What it cannot see:
#   - the rest of $HOME: ~/.ssh, ~/.aws, ~/.claude, gh tokens, other projects
#   - WSL: /mnt (the Windows drives) and the interop socket, so it cannot
#     launch Windows executables to step outside the sandbox
#   - any environment variable not on the allow-list below
#
# Usage:
#   agent-sandbox [options] opencode [args...]
#   agent-sandbox [options] ori [args...]
#   agent-sandbox [options] -- <command> [args...]   # generic, no tool state
# Options:
#   --rw PATH      extra read-write bind (repeatable)
#   --ro PATH      extra read-only bind (repeatable)
#   --env NAME     pass an extra environment variable through (repeatable)
#   --no-net       no network at all (only useful with local models)
#   --dir PATH     project directory to expose instead of the cwd/git root
#   --shell        open bash inside the sandbox instead (for poking around)

set -euo pipefail

die() {
  echo "agent-sandbox: $*" >&2
  exit 1
}

# rw/ro hold absolute paths; each backend turns them into its own rules.
rw=()
ro=()
envs=(OPENROUTER_API_KEY ORI_TELEMETRY ORI_TELEMETRY_LEVEL)
net=1
project=""
shell=0

while (($#)); do
  case "$1" in
    --rw) rw+=("$(realpath "$2")"); shift 2 ;;
    --ro) ro+=("$(realpath "$2")"); shift 2 ;;
    --env) envs+=("$2"); shift 2 ;;
    --no-net) net=0; shift ;;
    --dir) project="$(realpath "$2")"; shift 2 ;;
    --shell) shell=1; shift ;;
    --) shift; break ;;
    -h | --help) sed -n '/^# Run a coding agent/,/^#   --shell/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) break ;;
  esac
done
(($#)) || die "no command given (try: agent-sandbox opencode)"

tool="$1"
shift
state=()
ro_state=()
# Resolved through PATH, which puts ~/.opencode/bin (the self-updating
# installer's location) ahead of a Nix-installed opencode.
case "$tool" in
  opencode)
    cmd=(opencode)
    state=(.opencode .config/opencode .local/share/opencode .local/state/opencode .cache/opencode)
    envs+=(KIMI_API_KEY)
    ;;
  ori)
    cmd=("$HOME/.local/bin/ori")
    ro_state=(.local/bin/ori)
    # Ori launches OpenCode itself, so it needs OpenCode's state too.
    state=(.ori .opencode .config/opencode .local/share/opencode .local/state/opencode .cache/opencode)
    ;;
  *) cmd=("$tool") ;;
esac
cmd+=("$@")
((shell)) && cmd=(/bin/bash)

if [[ -z "$project" ]]; then
  project="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
fi
# Exposing $HOME (or anything above it) read-write would defeat the point.
case "$HOME/" in
  "${project%/}"/*) die "refusing to expose $project - cd into a project directory or pass --dir" ;;
esac

# Read-only bits of home the agent's shell commands need: the nix profile
# (git, rg, ...), git identity, and the shared AGENTS.md instructions.
for p in .nix-profile .local/state/nix .config/git .gitconfig .agents "${ro_state[@]}"; do
  [[ -e "$HOME/$p" || -L "$HOME/$p" ]] && ro+=("$HOME/$p")
done
for p in "${state[@]}"; do
  mkdir -p "$HOME/$p"
  rw+=("$HOME/$p")
done
rw+=("$project")

envs+=(COLORTERM LANG LOCALE_ARCHIVE EDITOR)
setenv=(
  HOME="$HOME"
  USER="$USER"
  SHELL=/bin/bash
  TERM="${TERM:-xterm-256color}"
  AGENT_SANDBOX=1
)
for v in "${envs[@]}"; do
  [[ -n "${!v:-}" ]] && setenv+=("$v=${!v}")
done

run_bwrap() {
  local args=(
    --unshare-all
    --die-with-parent
    --clearenv
    --ro-bind /usr /usr
    --symlink usr/bin /bin
    --symlink usr/sbin /sbin
    --symlink usr/lib /lib
    --symlink usr/lib64 /lib64
    --ro-bind /etc /etc
    --ro-bind /nix /nix
    --proc /proc
    --dev /dev
    --tmpfs /tmp
    --tmpfs /run
    --dir "$HOME"
  )
  ((net)) && args+=(--share-net)
  # On WSL /etc/resolv.conf is a symlink into /mnt/wsl; expose just that file.
  [[ -e /mnt/wsl/resolv.conf ]] && args+=(--ro-bind /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf)
  local p kv
  for p in "${ro[@]}"; do args+=(--ro-bind "$p" "$p"); done
  for p in "${rw[@]}"; do args+=(--bind "$p" "$p"); done
  args+=(--chdir "$project")
  setenv+=(PATH="$HOME/.opencode/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin")
  for kv in "${setenv[@]}"; do args+=(--setenv "${kv%%=*}" "${kv#*=}"); done
  exec bwrap "${args[@]}" -- "${cmd[@]}"
}

# Seatbelt cannot hide paths, only deny access to them, so the policy denies
# reading file contents anywhere under $HOME and writing anywhere at all, then
# re-allows the paths above. Metadata stays readable so path lookups work.
# Paths go in as -D parameters rather than being spliced into the policy, so
# they need no quoting.
run_seatbelt() {
  local policy defs=() i=0 p
  policy='(version 1)
(allow default)
(deny file-read-data (subpath (param "HOME")))
(deny file-write*)
(allow file-write* (subpath "/private/tmp") (subpath "/private/var/folders")
  (literal "/dev/null") (literal "/dev/ptmx") (literal "/dev/dtracehelper") (regex #"^/dev/tty") (regex #"^/dev/fd/"))'
  defs+=(-D "HOME=$HOME")
  ((net)) || policy+=$'\n(deny network-outbound (remote ip "*:*"))'
  for p in "${ro[@]}"; do
    # Allow a symlink's target too, e.g. ~/.gitconfig -> /nix/store.
    defs+=(-D "RO$i=$p" -D "ROT$i=$(realpath "$p")")
    policy+=$'\n'"(allow file-read-data (subpath (param \"RO$i\")) (subpath (param \"ROT$i\")))"
    i=$((i + 1))
  done
  i=0
  for p in "${rw[@]}"; do
    defs+=(-D "RW$i=$p")
    policy+=$'\n'"(allow file-read-data file-write* (subpath (param \"RW$i\")))"
    i=$((i + 1))
  done
  # The system PATH (Homebrew, nix-darwin's profiles) lives outside $HOME and
  # stays readable, so it is kept; only the tool directories are prepended.
  setenv+=(PATH="$HOME/.opencode/bin:$PATH" TMPDIR="${TMPDIR:-/tmp}")
  cd "$project"
  exec env -i "${setenv[@]}" /usr/bin/sandbox-exec -p "$policy" "${defs[@]}" "${cmd[@]}"
}

case "$(uname -s)" in
  Linux) run_bwrap ;;
  Darwin) run_seatbelt ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac
