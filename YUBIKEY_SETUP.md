# YubiKey Bio FIDO2 Setup Instructions

## After System Rebuild

Once you've rebuilt your system with the new configuration, follow these steps to complete the YubiKey Bio setup:

### 0. Activate Group Membership (Important!)
After rebuilding, you need to activate the pcscd group membership:
```bash
# Option 1: Log out and log back in (recommended)
# This ensures all services recognize your group membership

# Option 2: Use newgrp for current session only
newgrp pcscd

# Option 3: Use sg command to run commands with proper group context
# Example: sg pcscd -c "ykman list"
```

### 1. Verify YubiKey Detection
```bash
# First restart pcscd service and reload udev rules
sudo systemctl restart pcscd
sudo udevadm control --reload-rules
sudo udevadm trigger

# Check if YubiKey is detected
ykman list

# Check FIDO2 info
ykman fido info

# Alternative detection using libfido2
fido2-token -L
```

### 2. Set Up FIDO2 PIN (if not already set)
```bash
# Set a FIDO2 PIN for your YubiKey Bio
ykman fido access change-pin
```

### 3. Enroll Fingerprints (YubiKey Bio only)
```bash
# Add fingerprint enrollment (can add multiple)
ykman fido fingerprints add "finger1"
ykman fido fingerprints add "finger2"  # optional backup finger

# List enrolled fingerprints
ykman fido fingerprints list
```

### 4. Generate U2F Mappings (CORRECTED)
```bash
# IMPORTANT: Remove old mapping file first
sudo rm -f /etc/u2f_mappings

# Generate U2F mapping with verification support for YubiKey Bio
# The -v flag enables user verification (fingerprint/PIN)
pamu2fcfg -u $(whoami) -v | sudo tee /etc/u2f_mappings

# Verify the mapping contains +verification flag
sudo cat /etc/u2f_mappings
# Should show something like: john:*,<key_data>,es256,+verification
```

### 5. Test Authentication Step by Step
```bash
# Test 1: Check YubiKey detection
fido2-token -L

# Test 2: Test FIDO2 functionality
fido2-token -I $(fido2-token -L | head -1)

# Test 3: Test PAM authentication with debug
# Check /var/log/auth.log or journal for debug output
pamtester login $(whoami) authenticate

# Test 4: Check PAM logs for debugging
journalctl -f | grep -E "(pam|u2f)" &
# Then run pamtester again in another terminal
```

### 6. Authentication Flow (Fixed)
Your login will now work as follows:
1. **Primary**: YubiKey Bio fingerprint verification (if +verification flag present)
2. **Fallback 1**: YubiKey PIN verification (if fingerprint fails)
3. **Fallback 2**: Traditional password authentication (if YubiKey unavailable)

### 7. Troubleshooting (Enhanced)
If authentication fails:

**YubiKey Not Detected:**
```bash
# Check USB connection and permissions
lsusb | grep -i yubi
ls -la /dev/hidraw*
groups $(whoami)  # Should include 'pcscd'
```

**PC/SC Issues:**
```bash
# Check pcscd status and logs
systemctl status pcscd
journalctl -u pcscd -f
```

**PAM U2F Issues:**
```bash
# Check PAM configuration
grep -r "pam_u2f" /etc/pam.d/
# Check auth file
sudo cat /etc/u2f_mappings
# Enable more verbose logging
sudo journalctl -f | grep pam_u2f
```

**Mapping File Issues:**
- Old mapping might not have `+verification` flag needed for biometric
- Regenerate with `-v` flag for user verification support
- Ensure file permissions allow PAM to read it

### 8. Common Fixes
```bash
# If YubiKey Manager shows "No YubiKey detected"
sudo systemctl restart pcscd
sudo udevadm control --reload-rules

# If pamtester still asks for password without YubiKey prompt
# Check that mapping has +verification flag, not just +presence
sudo cat /etc/u2f_mappings | grep "+verification"

# If getting "access denied" errors
# The user should already be in pcscd group via NixOS config
# Verify with: groups $(whoami)
# If not present, rebuild system: ~/dotfiles/scripts/switch.sh nixos
```

### Security Notes
- Keep your FIDO2 PIN secure and different from other PINs
- The fingerprint data is stored securely on the YubiKey, not on your computer
- If you lose your YubiKey, you can still log in with your password
- Consider enrolling multiple fingerprints for redundancy
- The `+verification` flag enables biometric authentication vs just presence detection