# Run a coding agent (OpenCode, or Ori - OpenRouter's agent launcher) inside a
# bubblewrap sandbox. Opt-in: the plain `opencode` / `ori` commands are
# untouched; use `opencode-safe` / `ori-safe` (aliases) or call this directly.
#
# What the agent can see:
#   - the current project directory, read-write (git toplevel if inside a repo)
#   - its own config/state directories, read-write
#   - /usr, /etc and /nix read-only, plus a read-only git config and nix profile
#   - the network (it needs it to reach the model API), unless --no-net
# What it cannot see:
#   - the rest of $HOME: ~/.ssh, ~/.aws, ~/.claude, gh tokens, other projects
#   - /mnt (the Windows drives) and the WSL interop socket, so it cannot launch
#     Windows executables to step outside the sandbox
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

extra=()
envs=(OPENROUTER_API_KEY ORI_TELEMETRY ORI_TELEMETRY_LEVEL)
net=(--share-net)
project=""
shell=0

while (($#)); do
  case "$1" in
    --rw) extra+=(--bind "$(realpath "$2")" "$(realpath "$2")"); shift 2 ;;
    --ro) extra+=(--ro-bind "$(realpath "$2")" "$(realpath "$2")"); shift 2 ;;
    --env) envs+=("$2"); shift 2 ;;
    --no-net) net=(); shift ;;
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
case "$tool" in
  opencode)
    cmd=("$HOME/.opencode/bin/opencode")
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

if [[ -z "$project" ]]; then
  project="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
fi
# Exposing $HOME (or anything above it) read-write would defeat the point.
case "$HOME/" in
  "${project%/}"/*) die "refusing to expose $project - cd into a project directory or pass --dir" ;;
esac

args=(
  --unshare-all "${net[@]}"
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
# On WSL /etc/resolv.conf is a symlink into /mnt/wsl; expose just that file.
[[ -e /mnt/wsl/resolv.conf ]] && args+=(--ro-bind /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf)

# Read-only bits of home the agent's shell commands need: the nix profile
# (git, rg, ...), git identity, and the shared AGENTS.md instructions.
for p in .nix-profile .local/state/nix .config/git .gitconfig .agents "${ro_state[@]}"; do
  [[ -e "$HOME/$p" || -L "$HOME/$p" ]] && args+=(--ro-bind "$HOME/$p" "$HOME/$p")
done
for p in "${state[@]}"; do
  mkdir -p "$HOME/$p"
  args+=(--bind "$HOME/$p" "$HOME/$p")
done
args+=(--bind "$project" "$project" --chdir "$project")
args+=("${extra[@]}")

args+=(
  --setenv HOME "$HOME"
  --setenv USER "$USER"
  --setenv SHELL /bin/bash
  --setenv PATH "$HOME/.opencode/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin"
  --setenv TERM "${TERM:-xterm-256color}"
  --setenv AGENT_SANDBOX 1
)
for v in COLORTERM LANG LOCALE_ARCHIVE EDITOR "${envs[@]}"; do
  [[ -n "${!v:-}" ]] && args+=(--setenv "$v" "${!v}")
done

((shell)) && cmd=(/bin/bash)
exec bwrap "${args[@]}" -- "${cmd[@]}"
