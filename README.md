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
├── ansible/
│   ├── site.yml                    # master playbook
│   ├── inventory/
│   │   └── hosts.yml               # your Jetson's IP/hostname
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

## Prerequisites (macOS control machine)

```bash
brew install ansible
pip3 install ansible passlib
```

---

## Phase 1: Flash JetPack to USB

1. Download the JetPack 7.x `.img` for Orin Nano from:
   https://developer.nvidia.com/embedded/jetpack
2. Flash to your USB thumb drive with **Balena Etcher** (https://etcher.balena.io)
   - Select the `.img` → select your USB drive → Flash
3. Boot your Jetson from USB — it will install to NVMe automatically
4. Complete the Ubuntu OOBE (set username, password, timezone)
   - **Use username `jetson`** or update `ansible_user` in `inventory/hosts.yml`
5. After first boot, confirm NVMe is the root device: `lsblk`

---

## Phase 2: Configure Inventory

Edit `ansible/inventory/hosts.yml` — find your Jetson's IP from your router's DHCP leases:

```yaml
jetson:
  hosts:
    jetson-orin:
      ansible_host: 192.168.1.XXX   # ← set this
```

---

## Phase 3: Set Up Secrets

```bash
# Create vault password file — keep this OUT of git, store it in 1Password/etc
echo "your-strong-vault-password" > ~/.ansible-vault-pass
chmod 600 ~/.ansible-vault-pass

# Edit the encrypted vault (opens $EDITOR)
make vault-edit
```

Fill in all values — see `ansible/group_vars/all/vault.yml` for the required keys.

---

## Phase 4: SSH Key Auth

```bash
ssh-copy-id jetson@192.168.1.XXX
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
| Home Assistant    | http://\<jetson-ip\>:8123        |
| UniFi Controller  | https://\<jetson-ip\>:8443       |
| Portainer         | https://\<jetson-ip\>:9443       |

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
2. `ssh-copy-id jetson@<new-ip>`
3. Update IP in `inventory/hosts.yml`
4. `make provision`

HA config and UniFi data live in `compose/` subdirs — back these up separately
or add a backup role to the playbook.
