packer {
  required_plugins {
   # see https://github.com/hashicorp/packer-plugin-virtualbox
    virtualbox = {
      version = "1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
    # see https://github.com/hashicorp/packer-plugin-vagrant
    vagrant = {
      version = "1.1.2"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "proxmox_version" {
  type    = number
  default = 9
}

variable "vagrant_box" {
  type = string
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2 * 1024
}

variable "disk_size" {
  type    = number
  default = 40 * 1024
}

variable "proxmox_node" {
  type    = string
  default = env("PROXMOX_NODE")
}

variable "apt_cache_host" {
  type    = string
  default = env("APT_CACHE_HOST")
}

variable "apt_cache_port" {
  type    = string
  default = env("APT_CACHE_PORT")
}

variable "output_base_dir" {
  type    = string
  default = env("PACKER_OUTPUT_BASE_DIR")
}

locals {
  iso_url_map = {
    "6" = "http://download.proxmox.com/iso/proxmox-ve_6.4-1.iso"
    "7" = "http://download.proxmox.com/iso/proxmox-ve_7.4-1.iso"
    "8" = "http://download.proxmox.com/iso/proxmox-ve_8.4-1.iso"
    "9" = "http://download.proxmox.com/iso/proxmox-ve_9.0-1.iso"
  }
  iso_checksum_map = {
    "6" = "sha256:ab71b03057fdeea29804f96f0ff4483203b8c7a25957a4f69ed0002b5f34e607"
    "7" = "sha256:55b672c4b0d2bdcbff9910eea43df3b269aaab3f23e7a1df18b82d92eb995916"
    "8" = "sha256:d237d70ca48a9f6eb47f95fd4fd337722c3f69f8106393844d027d28c26523d8"
    "9" = "sha256:228f948ae696f2448460443f4b619157cab78ee69802acc0d06761ebd4f51c3e"
  }
  iso_url      = local.iso_url_map[var.proxmox_version]
  iso_checksum = local.iso_checksum_map[var.proxmox_version]
}

variable "shell_provisioner_scripts" {
  type = list(string)
  default = [
    "provisioners/apt_proxy.sh",
    "provisioners/upgrade.sh",
    "provisioners/network.sh",
    "provisioners/localisation-pt.sh",
    "provisioners/reboot.sh",
    "provisioners/provision.sh",
  ]
}

source "virtualbox-iso" "proxmox-ve-amd64" {
  guest_os_type        = "Debian_64"
  guest_additions_mode = "attach"
  headless             = true
  http_directory       = "."
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--memory", var.memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.cpus],
    ["modifyvm", "{{.Name}}", "--nested-hw-virt", "on"],
    ["modifyvm", "{{.Name}}", "--vram", "16"],
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--nictype1", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype2", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype3", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype4", "82540EM"],
  ]
  vboxmanage_post = [
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"],
  ]
  cd_label            = "proxmox-ais"
  cd_files            = ["answer.toml"]

  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  hard_drive_discard   = true
  iso_url              = local.iso_url
  iso_checksum         = local.iso_checksum
  output_directory     = "${var.output_base_dir}/output-{{build_name}}"
  ssh_username         = "root"
  ssh_password         = "password"
  ssh_timeout          = "20m"
  boot_wait            = "5s"

  boot_command = [
    # select Advanced Options.
    "<end><enter>",
    # select Install Proxmox VE (Automated).
    "<down><down><down><enter>",
    # wait for the shell prompt.
    "<wait1m>",
    # do the installation.
    "proxmox-fetch-answer partition proxmox-ais >/run/automatic-installer-answers<enter><wait>exit<enter>",
  ]
  shutdown_command = "poweroff"
}

build {
  sources = [
    "source.virtualbox-iso.proxmox-ve-amd64",
  ]

  provisioner "shell" {
    expect_disconnect = true
    environment_vars = [
      "apt_cache_host=${var.apt_cache_host}",
      "apt_cache_port=${var.apt_cache_port}",
    ]
    scripts = var.shell_provisioner_scripts
  }

  post-processor "vagrant" {
    only = [
      "virtualbox-iso.proxmox-ve-amd64",
    ]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }
}
