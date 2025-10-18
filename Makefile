SHELL=bash
.SHELLFLAGS=-euo pipefail -c

VAR_FILE :=
VAR_FILE_OPTION := $(addprefix -var-file=,$(VAR_FILE))

PACKER_ENV := CHECKPOINT_DISABLE=1 \
			PACKER_LOG=1 \
			PACKER_OUTPUT_BASE_DIR=$${PACKER_OUTPUT_BASE_DIR:-.} \
			PKR_VAR_vagrant_box=$@

PHONY += help
help:
	@echo type make build-virtualbox

PHONY += build-virtualbox
build-virtualbox: proxmox-ve-amd64-virtualbox.box

proxmox-ve-amd64-virtualbox.box: provisioners/*.sh proxmox-ve.pkr.hcl Vagrantfile.template $(VAR_FILE)
	rm -f $@
	$(PACKER_ENV) PACKER_LOG_PATH=$@.init.log \
		packer init proxmox-ve.pkr.hcl
	$(PACKER_ENV) PACKER_LOG_PATH=$@.log \
		packer build -only=virtualbox-iso.proxmox-ve-amd64 -on-error=abort -timestamp-ui $(VAR_FILE_OPTION) proxmox-ve.pkr.hcl
	@./box-metadata.sh virtualbox proxmox-ve-amd64 $@

PHONY += clean
clean:
	rm -rf packer_cache $${PACKER_OUTPUT_BASE_DIR:-.}/output-proxmox-ve*

.PHONY: $(PHONY)
