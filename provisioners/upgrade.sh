#!/bin/bash
set -euxo pipefail

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# switch to the non-enterprise repository.
# see https://pve.proxmox.com/wiki/Package_Repositories
if [ "$(pveversion | grep -o '[89]' | head -c 1)" -eq 8 ]; then  # Proxmox v8
    dpkg-divert --divert /etc/apt/sources.list.d/pve-enterprise.list.distrib.disabled --rename --add /etc/apt/sources.list.d/pve-enterprise.list
    dpkg-divert --divert /etc/apt/sources.list.d/ceph.list.distrib.disabled --rename --add /etc/apt/sources.list.d/ceph.list
    echo "deb http://download.proxmox.com/debian/pve $(. /etc/os-release && echo "$VERSION_CODENAME") pve-no-subscription" >/etc/apt/sources.list.d/pve.list
    echo "deb http://download.proxmox.com/debian/ceph-reef $(. /etc/os-release && echo "$VERSION_CODENAME") no-subscription" >/etc/apt/sources.list.d/ceph.list

else  # Proxmox v9
    dpkg-divert --divert /etc/apt/sources.list.d/pve-enterprise.sources.distrib.disabled --rename --add /etc/apt/sources.list.d/pve-enterprise.sources
    dpkg-divert --divert /etc/apt/sources.list.d/ceph.sources.distrib.disabled --rename --add /etc/apt/sources.list.d/ceph.sources
    cat >/etc/apt/sources.list.d/pve.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    cat >/etc/apt/sources.list.d/ceph.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
fi

# switch the apt mirror from us to nl.
sed -i -E 's,ftp\.us\.debian,ftp.nl.debian,' /etc/apt/sources.list

# upgrade.
apt-get update
apt-get dist-upgrade -y
