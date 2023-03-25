# tch-coreutils

Statically linked arm binaries of the GNU coreutils, specifically for deployment on Technicolor Gateway routers.

## Configuring opkg

The `/etc/opkg.conf` file must contain the architecture for your device. e.g. for a 32 bit Technicolor device, it will look something like this:
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
src/gz coreutils https://raw.githubusercontent.com/seud0nym/tch-coreutils/master/repository/arm_cortex-a9/packages
```

64-bit devices (such as the Telstra Smart Modem Gen 3), would use `arm_cortex_a53` instead of `arm_cortex-a9`.

## Building

### Release Binaries

The release binaries were built using the `build.sh` script from https://github.com/luciusmagn/coreutils-static on Debian v11.6 (bullseye) running on a Marvell Feroceon 88FR131 (armv5tel) processor system with the following packages installed:
```
apt install make gcc upx curl
```

### OpenWrt Packages

The individual OpenWrt opkg .ipk files are built using an adapted version of the `make-ipk.sh` from https://bitsum.com/creating_ipk_packages.htm.

The `build-packages.sh` script will create two .ipk files in the repository (one each for the arm_cortex-a9 and arm_cortex-a53 architectures) for each executable found in the `releases` directory. It will also create the base coreutils package, which is added as a dependency to all the individual packages, to mimic the official OpenWrt packages.