SHELL=bash
.SHELLFLAGS=-euo pipefail -c

PACKER_ENV := CHECKPOINT_DISABLE=1 \
			PACKER_LOG=1 \

PACKER_FLAGS := -on-error=abort -timestamp-ui -var-file=variables.pkrvars.hcl

PHONY += help
help:
	@echo type make build, make build-v8 or make build-v9
	@echo make build will build a proxmox v9 image

PHONY += build
build: proxmox-v9/proxmox-ve-amd64-virtualbox.box

PHONY += build-v8 build-v9
build-v9: proxmox-v9/proxmox-ve-amd64-virtualbox.box
build-v8: proxmox-v8/proxmox-ve-amd64-virtualbox.box

PHONY += proxmox-v8/proxmox-ve-amd64-virtualbox.box proxmox-v9/proxmox-ve-amd64-virtualbox.box
proxmox-v%/proxmox-ve-amd64-virtualbox.box: provisioners/*.sh proxmox-ve.pkr.hcl Vagrantfile.template $(VAR_FILE)
	mkdir -p proxmox-v$*.old
	mv proxmox-v$*/* proxmox-v$*.old || true  # Backup previous build in case of build failure
	mkdir -p $(dir $@)
	# rm -f $@
	$(PACKER_ENV) PACKER_LOG_PATH=$@.init.log \
		PACKER_OUTPUT_BASE_DIR=$(dir $@). \
		packer init proxmox-ve.pkr.hcl
	$(PACKER_ENV) \
		PACKER_LOG_PATH=$@.log \
		PKR_VAR_vagrant_box=$@ \
		PKR_VAR_proxmox_version=$* \
		PACKER_OUTPUT_BASE_DIR=proxmox-v$*/* \
		packer build $(PACKER_FLAGS) proxmox-ve.pkr.hcl
	./box-metadata.sh virtualbox "proxmox-ve-v$*-amd64" "$@"
	rm -rf proxmox-v$*.old  # Delete previous build

PHONY += clean
clean:
	rm -rf packer_cache proxmox-v[89] proxmox-v[89].old

.PHONY: $(PHONY)
