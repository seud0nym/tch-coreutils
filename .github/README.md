# tch-coreutils

Statically linked arm binaries of the GNU coreutils, specifically for deployment on Technicolor Gateway routers.

### /etc/opkg.conf

The `/etc/opkg.conf` file must contain the architecture for your device.

#### 32 bit ARM Cortex-A9 Devices

Example for a 32 bit Technicolor device such as the Telstra Smart Modem Gen 2 and earlier generation devices:

```
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
arch all 1
arch noarch 1
arch arm_cortex-a9 10
arch arm_cortex-a9_neon 20
arch brcm63xx-tch 30
arch bcm53xx 40
```

The following line also needs to be added to `/etc/opkg/customfeeds.conf`:

```
src/gz tch_static https://raw.githubusercontent.com/seud0nym/tch-coreutils/master/repository/arm_cortex-a9/packages
```

#### 64-bit device ARM Cortex-A53 Devices

**WARNING:** These are not aarch64 binaries, because the 64-bit binaries currently core-dump when run on an ARM Cortex-A53 Technicolor device! However, the 32-bit binaries do run appear to run successfully.

Example for a 64 bit Technicolor device such as the Telstra Smart Modem Gen 3:

```
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
option check_signature
dest lcm_native /opt/
arch all 1
arch noarch 1
arch arm_cortex-a53 10
arch aarch64_cortex-a53 20
```

The following line also needs to be added to `/etc/opkg/customfeeds.conf`:
```
src/gz tch_static https://raw.githubusercontent.com/seud0nym/tch-coreutils/master/repository/arm_cortex-a53/packages
```

### Package Signature Verification

Later versions of `opkg` require the Package index file to signed. If you get a "_Signature check failed_" error when executing `opkg update`, download and add the key file:

```bash
curl -sklO https://raw.githubusercontent.com/seud0nym/tch-coreutils/master/keys/seud0nym-public.key
opkg-key add seud0nym-public.key
rm seud0nym-public.key
```

## Building

The release binaries were built using the `build.sh` script. The individual OpenWrt opkg .ipk files are built using an adapted version of the `make-ipk.sh` script from https://bitsum.com/creating_ipk_packages.htm, which is executed automatically by `build.sh`.

### Prerequisites

The following packages are required to be installed before running `build.sh`:
* git
* make
* gcc
* curl
* cmake
* upx-ucl

The usign private key `seud0nym-private.key` is also required to sign the Packages file.
