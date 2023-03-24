# tch-coreutils

Statically linked arm binaries of the GNU coreutils, specifically for deployment on Technicolor Gateway routers.

## Building

Built on Debian v11.6 (bullseye) running on a Marvell Feroceon 88FR131 (armv5tel) processor system with the following packages installed:
```
apt install make gcc upx curl
```

Binaries were built using the `build.sh` script from https://github.com/luciusmagn/coreutils-static.
