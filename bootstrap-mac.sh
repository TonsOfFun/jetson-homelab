#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap-mac.sh
#
# Run this ONCE on your macOS control machine before the first `make provision`.
# Sets up all tools needed to manage the Jetson homelab from your Mac.
#
# Usage:
#   chmod +x bootstrap-mac.sh
#   ./bootstrap-mac.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bootstrap]${NC} $*"; }

# ── Homebrew ─────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  info "Homebrew already installed — skipping"
fi

# ── Ansible ──────────────────────────────────────────────────────────────────
if ! command -v ansible &>/dev/null; then
  info "Installing Ansible..."
  brew install ansible
else
  info "Ansible $(ansible --version | head -1) already installed — skipping"
fi

# ── Python packages needed by Ansible ────────────────────────────────────────
info "Installing Python packages (passlib for password hashing)..."
pip3 install --quiet --break-system-packages passlib

# ── Ansible Galaxy collections ────────────────────────────────────────────────
info "Installing Ansible Galaxy collections..."
cd ansible
ansible-galaxy collection install -r requirements.yml --upgrade
cd ..

# ── SSH key ───────────────────────────────────────────────────────────────────
# Prefer FIDO2/passkey key (Touch ID on macOS) if available, fall back to ed25519
SSH_SK_KEY=~/.ssh/id_ed25519_sk
SSH_KEY=~/.ssh/id_ed25519

if [ -f "$SSH_SK_KEY" ]; then
  info "FIDO2/passkey SSH key already exists at $SSH_SK_KEY — skipping"
elif [ -f "$SSH_KEY" ]; then
  info "SSH key already exists at $SSH_KEY — skipping"
  warn "To upgrade to Touch ID, run: ssh-keygen -t ed25519-sk -C \"jetson-homelab\" -O resident"
else
  echo ""
  info "Generating SSH key..."
  echo "  Option 1: FIDO2/passkey (Touch ID) — requires macOS Ventura+ and a compatible Mac"
  echo "  Option 2: Standard ed25519 key"
  echo ""
  read -rp "Use Touch ID / passkey for SSH? (y/n): " use_sk
  if [[ "$use_sk" =~ ^[Yy] ]]; then
    info "Generating FIDO2 resident key (Touch ID will prompt)..."
    ssh-keygen -t ed25519-sk -C "jetson-homelab" -O resident -f "$SSH_SK_KEY"
    info "Passkey SSH key saved to $SSH_SK_KEY"
    info "Update ansible_ssh_private_key_file in inventory/hosts.yml to: ~/.ssh/id_ed25519_sk"
  else
    ssh-keygen -t ed25519 -C "jetson-homelab" -f "$SSH_KEY" -N ""
    info "SSH key saved to $SSH_KEY"
  fi
fi

# ── Vault password file ───────────────────────────────────────────────────────
VAULT_PASS=~/.ansible-vault-pass
if [ ! -f "$VAULT_PASS" ]; then
  warn "No vault password file found at $VAULT_PASS"
  echo ""
  read -rsp "Enter a strong password for Ansible Vault (you'll need this for disaster recovery): " vpass
  echo ""
  echo "$vpass" > "$VAULT_PASS"
  chmod 600 "$VAULT_PASS"
  info "Vault password saved to $VAULT_PASS — store this somewhere safe (1Password etc)"
else
  info "Vault password file already exists at $VAULT_PASS — skipping"
fi

# ── Encrypt vault.yml if it isn't already ─────────────────────────────────────
VAULT_FILE=ansible/group_vars/all/vault.yml
if grep -q "CHANGE_ME" "$VAULT_FILE" 2>/dev/null; then
  warn ""
  warn "vault.yml still contains placeholder passwords!"
  warn "Edit it now:  make vault-edit"
  warn "Then encrypt: make vault-encrypt"
  warn ""
elif head -1 "$VAULT_FILE" | grep -q '^\$ANSIBLE_VAULT'; then
  info "vault.yml is already encrypted — good"
else
  warn "vault.yml exists but is not encrypted — run: make vault-encrypt"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "Bootstrap complete. Next steps:"
echo ""
echo "  1. Verify ansible/inventory/hosts.yml has the correct IP and user"
echo "  2. Copy SSH key to Jetson:"
if [ -f "$SSH_SK_KEY" ]; then
  echo "     ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub tonsoffun@10.1.1.187"
else
  echo "     ssh-copy-id tonsoffun@10.1.1.187"
fi
echo "  3. Edit secrets:       make vault-edit"
echo "     (change all CHANGE_ME values, then save and quit)"
echo "  4. Encrypt vault:      make vault-encrypt"
echo "  5. Test connectivity:  make ping"
echo "  6. Full provision:     make provision"
echo ""
