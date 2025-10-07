This builds an up-to-date [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) Vagrant Base Box.

Currently this targets Proxmox VE 8.

# Usage

Create the base box as described in the section corresponding to your provider.

If you want to troubleshoot the packer execution see the `.log` file that is created in the current directory.

After the example vagrant environment is started, you can access the [Proxmox Web Interface](https://10.10.10.2:8006/) with the default `root` user and password `vagrant`.

For a cluster example see [rgl/proxmox-ve-cluster-vagrant](https://github.com/rgl/proxmox-ve-cluster-vagrant).

## VirtualBox

Create the base box:

```bash
make build-virtualbox
```

> [!NOTE]
> Currently, the credentials generated are `root:vagrantt`, I should patch it soon. `vagrant ssh` should still work since it uses ssh keys.

Add the base box as suggested in make output:

```bash
vagrant box add -f proxmox-ve-amd64 proxmox-ve-amd64-libvirt.box # or proxmox-ve-amd64-virtualbox.box
```

Start the example vagrant environment with:

```bash
mkdir my-example; cd my-example
vagrant init proxmox-ve-amd64 --provider=virtualbox
vagrant up --no-destroy-on-error --provider=virtualbox
```

> [!NOTE]
> You can add the following lines to the generated vagrant file to access the web ui through `https://localhost:8006`
> ```
>   # forward proxmox API port
>   config.vm.network "forwarded_port",
>     guest: 8006,
>     host_ip: "127.0.0.1",
>     host: 8006
> ```

## Packer build performance options

To improve the build performance you can use the following options.

### Accelerate build time with Apt Caching Proxy

To speed up package downloads, you can specify an apt caching proxy 
(e.g. [apt-cacher-ng](https://www.unix-ag.uni-kl.de/~bloch/acng/))
by defining the environment variables `APT_CACHE_HOST` (default: undefined)
and `APT_CACHE_PORT` (default: 3124).

Example:

```bash
APT_CACHE_HOST=10.10.10.100 make build-libvirt
```

### Decrease disk wear by using temporary memory file-system

To decrease disk wear (and potentially reduce io times),
you can use `/dev/shm` (temporary memory file-system) as `output_directory` for Packer builders.
Your system must have enough available memory to store the created virtual machine.

Example:

```bash
PACKER_OUTPUT_BASE_DIR=/dev/shm make build-libvirt
```

Remember to also define `PACKER_OUTPUT_BASE_DIR` when you run `make clean` afterwards.

## Variables override

Some properties of the virtual machine and the Proxmox VE installation can be overridden.
Take a look at `proxmox-ve.pkr.hcl`, `variable` blocks, to get an idea which values can be
overridden. Do not override `iso_url` and `iso_checksum` as the `boot_command`s might be
tied to a specific Proxmox VE version. Also take care when you decide to override `country`.

Create the base box:

```bash
make build-libvirt VAR_FILE=example.pkrvars.hcl  # or build-virtualbox or build-hyperv
```

The following content of `example.pkrvars.hcl`:

* sets the initial disk size to 128 GB
* sets the initial memory to 4 GB
* sets the Packer output base directory to /dev/shm
* sets the country to Germany (timezone is updated by Proxmox VE installer) and changes
  the keyboard layout back to "U.S. English" as this is needed for the subsequent
  `boot_command` statements
* sets the hostname to pve-test.example.local
* uses all default shell provisioners (see [`./provisioners`](./provisioners)) and a
  custom one for german localisation

```hcl
disk_size = 128 * 1024
memory = 4 * 1024
output_base_dir = "/dev/shm"
step_country = "Ger<wait>m<wait>a<wait>n<wait><enter>"
step_hostname = "pve-test.example.local"
step_keyboard_layout = "<end><up><wait>"
shell_provisioner_scripts = [
  "provisioners/apt_proxy.sh",
  "provisioners/upgrade.sh",
  "provisioners/network.sh",
  "provisioners/localisation-de.sh",
  "provisioners/reboot.sh",
  "provisioners/provision.sh",
]
```

# Packer boot_command

As Proxmox does not have any way to be pre-seeded, this environment has to answer all the
installer questions through the packer `boot_command` interface. This is quite fragile, so
be aware when you change anything. The following table describes the current steps and
corresponding answers.

| step                              | boot_command                                          |
|----------------------------------:|-------------------------------------------------------|
| select "Install Proxmox VE"       | `<enter>`                                             |
| wait for boot                     | `<wait1m>`                                            |
| agree license                     | `<enter><wait>`                                       |
| target disk                       | `<enter><wait>`                                       |
| type country                      | `United States<wait><enter><wait><tab><wait>`         |
| timezone                          | `<tab><wait>`                                         |
| keyboard layout                   | `<tab><wait>`                                         |
| advance to the next button        | `<tab><wait>`                                         |
| advance to the next page          | `<enter><wait5>`                                      |
| password                          | `vagrant<tab><wait>`                                  |
| confirm password                  | `vagrant<tab><wait>`                                  |
| email                             | `pve@example.com<tab><wait>`                          |
| advance to the next button        | `<tab><wait>`                                         |
| advance to the next page          | `<enter><wait5>`                                      |
| hostname                          | `pve.example.com<tab><wait>`                          |
| ip address                        | `<tab><wait>`                                         |
| netmask                           | `<tab><wait>`                                         |
| gateway                           | `<tab><wait>`                                         |
| DNS server                        | `<tab><wait>`                                         |
| advance to the next button        | `<tab><wait>`                                         |
| advance to the next page          | `<enter><wait5>`                                      |
| install                           | `<enter><wait5>`                                      |

**NB** Do not change the keyboard layout. If you do, the email address will fail to be typed.
