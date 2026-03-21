VAULT_PASS_FILE := ~/.ansible-vault-pass
ANSIBLE_DIR     := ansible
INVENTORY       := $(ANSIBLE_DIR)/inventory/hosts.yml
ANSIBLE_USER    := tonsoffun

.PHONY: help provision provision-base provision-docker provision-nvidia provision-homelab \
        vault-edit vault-view vault-encrypt pull restart logs status shell ping

help:
	@echo ""
	@echo "  jetson-homelab Makefile"
	@echo ""
	@echo "  Setup:"
	@echo "    make provision           Full provision (all roles)"
	@echo "    make provision-base      OS setup, packages, hardening"
	@echo "    make provision-docker    Docker CE + Compose plugin"
	@echo "    make provision-nvidia    NVIDIA container runtime"
	@echo "    make provision-homelab   Deploy Docker Compose stack"
	@echo ""
	@echo "  Secrets:"
	@echo "    make vault-edit          Edit encrypted vault"
	@echo "    make vault-view          View decrypted vault"
	@echo ""
	@echo "  Day-2:"
	@echo "    make ping                Test Ansible connectivity"
	@echo "    make pull                Pull latest container images"
	@echo "    make restart             Restart all containers"
	@echo "    make logs                Tail all container logs"
	@echo "    make status              docker compose ps"
	@echo "    make shell               SSH into the Jetson"
	@echo ""

# ─── Provisioning ────────────────────────────────────────────────────────────

provision:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE)

provision-base:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags base

provision-docker:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags docker

provision-nvidia:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags nvidia

provision-homelab:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags homelab

# ─── Vault ───────────────────────────────────────────────────────────────────

vault-edit:
	ansible-vault edit $(ANSIBLE_DIR)/group_vars/all/vault.yml \
		--vault-password-file $(VAULT_PASS_FILE)

vault-view:
	ansible-vault view $(ANSIBLE_DIR)/group_vars/all/vault.yml \
		--vault-password-file $(VAULT_PASS_FILE)

vault-encrypt:
	ansible-vault encrypt $(ANSIBLE_DIR)/group_vars/all/vault.yml \
		--vault-password-file $(VAULT_PASS_FILE)

# ─── Day-2 ops ───────────────────────────────────────────────────────────────

ping:
	cd $(ANSIBLE_DIR) && ansible all -i inventory/hosts.yml -m ping

pull:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags pull

restart:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/hosts.yml \
		--vault-password-file $(VAULT_PASS_FILE) \
		--tags restart

logs:
	ssh $(ANSIBLE_USER)@$$(cd $(ANSIBLE_DIR) && ansible-inventory -i inventory/hosts.yml --list | python3 -c "import sys,json; h=json.load(sys.stdin)['_meta']['hostvars']; print(list(h.values())[0]['ansible_host'])") \
		"cd ~/homelab && docker compose logs -f"

status:
	ssh $(ANSIBLE_USER)@$$(cd $(ANSIBLE_DIR) && ansible-inventory -i inventory/hosts.yml --list | python3 -c "import sys,json; h=json.load(sys.stdin)['_meta']['hostvars']; print(list(h.values())[0]['ansible_host'])") \
		"cd ~/homelab && docker compose ps"

shell:
	ssh -t $(ANSIBLE_USER)@$$(cd $(ANSIBLE_DIR) && ansible-inventory -i inventory/hosts.yml --list | python3 -c "import sys,json; h=json.load(sys.stdin)['_meta']['hostvars']; print(list(h.values())[0]['ansible_host'])")
