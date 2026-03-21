# jetson-homelab

Codified, disaster-recoverable setup for the Jetson Orin Nano Super (8GB).

**Stack:** Home Assistant + UniFi Network Application + Portainer, all in Docker,
with NVIDIA container runtime ready for GPU workloads.

**Tooling:** Ansible (provisioning) · Ansible Vault (secrets) · Docker Compose (services)

---

## Repo Structure

```
jetson-homelab/
├── README.md
├── Makefile                        # convenience commands
├── bootstrap-mac.sh                # one-time macOS setup
├── ansible/
│   ├── site.yml                    # master playbook
│   ├── inventory/
│   │   └── hosts.yml               # Jetson connection details
│   ├── group_vars/
│   │   └── all/
│   │       ├── vars.yml            # non-secret vars
│   │       └── vault.yml           # Ansible Vault encrypted secrets
│   └── roles/
│       ├── base/                   # OS hardening, packages, user setup
│       ├── docker/                 # Docker CE + Compose plugin
│       ├── nvidia/                 # NVIDIA container toolkit
│       └── homelab/                # deploys compose stack
└── compose/
    ├── docker-compose.yml
    ├── .env                        # generated from vault at deploy time
    └── unifi/
        └── init-mongo.js
```

---

## Phase 1: Flash JetPack to USB

1. Download the JetPack 7.x `.img` for Orin Nano from:
   https://developer.nvidia.com/embedded/jetpack
2. Flash to your USB thumb drive with **Balena Etcher** (https://etcher.balena.io)
   - Select the `.img` → select your USB drive → Flash
3. Boot your Jetson from USB — it will install to NVMe automatically
4. Complete the Ubuntu OOBE (set username, password, timezone)
5. After first boot, confirm NVMe is the root device: `lsblk`

---

## Phase 2: Bootstrap Your Mac

Run the bootstrap script once to install all dependencies:

```bash
chmod +x bootstrap-mac.sh
./bootstrap-mac.sh
```

This will:
- Install Homebrew (if needed) and Ansible
- Install Python packages (`passlib`)
- Install Ansible Galaxy collections
- Generate an SSH key — you'll be asked whether to use **Touch ID / passkey** (FIDO2 `ed25519-sk`) or a standard `ed25519` key
- Create your Ansible Vault password file

### Touch ID SSH (recommended)

If your Mac supports it (Apple Silicon or T2 chip, macOS Ventura+), choose the passkey option during bootstrap. This generates a FIDO2 resident key stored in your Mac's Secure Enclave — every SSH connection requires a Touch ID tap.

If you already have a standard key and want to upgrade later:

```bash
ssh-keygen -t ed25519-sk -C "jetson-homelab" -O resident -f ~/.ssh/id_ed25519_sk
```

Then update `ansible_ssh_private_key_file` in `ansible/inventory/hosts.yml` to `~/.ssh/id_ed25519_sk`.

---

## Phase 3: Copy SSH Key to Jetson

```bash
# For passkey/Touch ID key:
ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub tonsoffun@10.1.1.187

# For standard ed25519 key:
ssh-copy-id tonsoffun@10.1.1.187
```

Verify passwordless access:

```bash
ssh tonsoffun@10.1.1.187
```

> **Note:** After provisioning, password auth is disabled. Make sure key auth works first.

---

## Phase 4: Set Up Secrets

```bash
# Edit the encrypted vault (opens $EDITOR)
make vault-edit
```

Fill in all values — see `ansible/group_vars/all/vault.yml` for the required keys.

If the vault isn't encrypted yet:

```bash
make vault-encrypt
```

---

## Phase 5: Provision

```bash
make provision          # full run
make provision-base     # OS + packages only
make provision-docker   # Docker + NVIDIA runtime only
make provision-homelab  # Compose stack only
```

---

## Accessing Services

| Service           | URL                              |
|-------------------|----------------------------------|
| Home Assistant    | http://10.1.1.187:8123           |
| UniFi Controller  | https://10.1.1.187:8443          |
| Portainer         | https://10.1.1.187:9443          |

---

## Day-2 Operations

```bash
make logs       # tail all container logs
make pull       # pull latest images
make restart    # restart all containers
make shell      # SSH into Jetson
make status     # docker compose ps
```

---

## GPU Workloads

Template for any GPU-enabled container in `docker-compose.yml`:

```yaml
  your-service:
    image: your-gpu-image
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
```

Monitor with `jtop` (installed by the base role).

---

## Disaster Recovery

1. Flash USB → boot → complete OOBE
2. `ssh-copy-id tonsoffun@<new-ip>`
3. Update IP in `inventory/hosts.yml`
4. `make provision`

HA config and UniFi data live in `compose/` subdirs — back these up separately
or add a backup role to the playbook.
