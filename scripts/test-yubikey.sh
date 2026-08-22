#!/usr/bin/env bash

# YubiKey Bio FIDO2 Authentication Test Script
# Run this after system rebuild to verify YubiKey setup

set -e

echo "🔐 YubiKey Bio FIDO2 Authentication Test"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_step() {
    local description="$1"
    local command="$2"

    echo -e "\n🔍 Testing: ${YELLOW}$description${NC}"
    if eval "$command" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}PASS${NC}: $description"
        return 0
    else
        echo -e "❌ ${RED}FAIL${NC}: $description"
        return 1
    fi
}

# Test with detailed output
test_step_verbose() {
    local description="$1"
    local command="$2"

    echo -e "\n🔍 Testing: ${YELLOW}$description${NC}"
    echo "Command: $command"
    if eval "$command"; then
        echo -e "✅ ${GREEN}PASS${NC}: $description"
        return 0
    else
        echo -e "❌ ${RED}FAIL${NC}: $description"
        return 1
    fi
}

echo -e "\n📋 Pre-checks..."

# Check if user is in pcscd group
if groups | grep -q "pcscd"; then
    echo -e "✅ ${GREEN}User is in pcscd group (current session)${NC}"
elif getent group pcscd | grep -q "$(whoami)"; then
    echo -e "⚠️  ${YELLOW}User is in pcscd group (system) but not in current session${NC}"
    echo "You need to log out and log back in for group membership to take effect"
    echo "Or run: newgrp pcscd (temporary for this session)"
else
    echo -e "❌ ${RED}User is NOT in pcscd group${NC}"
    echo "This should be handled by NixOS config. Try rebuilding system."
    echo "Run: ~/dotfiles/scripts/switch.sh nixos"
fi

# Check if pcscd service is available
test_step "pcscd service is enabled" "systemctl is-enabled pcscd"

echo -e "\n🔄 Restarting services and reloading udev rules..."
sudo systemctl restart pcscd
sudo udevadm control --reload-rules
sudo udevadm trigger

echo -e "\n🔍 Device Detection Tests..."

# Test YubiKey detection
test_step_verbose "YubiKey detection with ykman" "ykman list"
test_step_verbose "FIDO2 token detection" "fido2-token -L"

# Check FIDO2 info
echo -e "\n📊 YubiKey FIDO2 Information:"
if ykman fido info 2>/dev/null; then
    echo -e "✅ ${GREEN}YubiKey FIDO2 info retrieved successfully${NC}"
else
    echo -e "❌ ${RED}Could not retrieve YubiKey FIDO2 info${NC}"
fi

echo -e "\n🗝️  U2F Mapping Tests..."

# Check if mapping file exists
if [ -f "/etc/u2f_mappings" ]; then
    echo -e "✅ ${GREEN}U2F mappings file exists${NC}"
    echo "Contents:"
    sudo cat /etc/u2f_mappings

    # Check for verification flag
    if sudo cat /etc/u2f_mappings | grep -q "+verification"; then
        echo -e "✅ ${GREEN}Mapping includes +verification flag (biometric support)${NC}"
    else
        echo -e "⚠️  ${YELLOW}Mapping only has +presence flag (no biometric)${NC}"
        echo "Regenerate with: pamu2fcfg -u \$(whoami) -v | sudo tee /etc/u2f_mappings"
    fi
else
    echo -e "❌ ${RED}U2F mappings file does not exist${NC}"
    echo "Generate with: pamu2fcfg -u \$(whoami) -v | sudo tee /etc/u2f_mappings"
fi

echo -e "\n🔐 PAM Configuration Test..."

# Check PAM configuration
if grep -r "pam_u2f" /etc/pam.d/ >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}PAM U2F module is configured${NC}"
else
    echo -e "❌ ${RED}PAM U2F module is NOT configured${NC}"
fi

echo -e "\n🧪 Authentication Test..."
echo "This will test PAM authentication. You should see YubiKey prompts."
echo "Press Enter to continue or Ctrl+C to skip..."
read

# Test PAM authentication
echo "Running pamtester - follow YubiKey prompts for fingerprint/PIN..."
if pamtester login "$(whoami)" authenticate; then
    echo -e "✅ ${GREEN}PAM authentication test PASSED${NC}"
else
    echo -e "❌ ${RED}PAM authentication test FAILED${NC}"
    echo "Check logs with: journalctl -f | grep -E '(pam|u2f)'"
fi

echo -e "\n📝 Summary and Next Steps:"
echo "================================"
echo "1. If YubiKey detection failed: Check USB connection and replug device"
echo "2. If mapping file missing: Follow YUBIKEY_SETUP.md instructions"
echo "3. If authentication failed: Check debug logs and verify PIN/fingerprints"
echo "4. For detailed troubleshooting: See YUBIKEY_SETUP.md"
echo ""
echo -e "🎯 ${GREEN}Test complete!${NC} Check output above for any issues."