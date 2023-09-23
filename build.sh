#!/bin/bash

GREEN='\033[1;32m'
GREY='\033[90m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

__PKG_ONLY=N
__THIS_ARCH=$(uname -m)

# aarch64 musl builds are commented out because currently they core dump when run on Technicolor ARM Cortex-A53 devices
# 32-bit arm builds seem to run fine on Technicolor ARM Cortex-A53 devices

if [ $__THIS_ARCH == x86_64 ]; then
  #__MUSL_ARCH=(arm aarch64)
  #__MUSL_PRFX=(${__MUSL_ARCH[0]}-linux-musleabi ${__MUSL_ARCH[1]}-linux-musl)
  __MUSL_ARCH=(arm arm)
  __MUSL_PRFX=(${__MUSL_ARCH[0]}-linux-musleabi ${__MUSL_ARCH[1]}-linux-musleabi)
  __OWRT_ARCH=(arm_cortex-a9 arm_cortex-a53)
#elif [ $__THIS_ARCH == aarch64 ]; then
#  #__MUSL_ARCH=(aarch64)
#  __MUSL_ARCH=(arm)
#  __OWRT_ARCH=(arm_cortex-a53)
#elif [[ $__THIS_ARCH =~ ^armv[567] ]]; then
#  __MUSL_ARCH=(arm)
#  __OWRT_ARCH=(arm_cortex-a9)
else
  echo -e "${RED}$(date +%X) ==> ERROR: Unsupported build machine: ${__THIS_ARCH}!${NC}"
  exit 2
fi

echo -e "${GREEN}$(date +%X) ==> INFO:  Checking for required keys....${GREY}[$(pwd)]${NC}"
[ -e keys/seud0nym-private.key ] || { echo -e "${RED}$(date +%X) ==> ERROR: Private key not found!${NC}"; exit 2; }
echo -e "${GREEN}$(date +%X) ==> INFO:  Checking for required executables....${GREY}[$(pwd)]${NC}"
for __BINARY in cmake curl git make tar gcc upx; do
  which $__BINARY >/dev/null || { echo -e "${RED}$(date +%X) ==> ERROR: $__BINARY not found!${NC}"; exit 2; }
done

if [ "$1" == "clean" ]; then
  shift
  echo -e "${GREEN}$(date +%X) ==> INFO:  Cleaning...${GREY}[$(pwd)]${NC}"
  rm -rf .work bin/usign releases repository toolchains
elif [ "$1" == "pkgonly" ]; then
  shift
  __PKG_ONLY=Y
fi

git submodule init
git submodule update

if [ $__THIS_ARCH == x86_64 ]; then
  [ ! -d toolchains ] && mkdir toolchains
  for I in $(seq 0 $((${#__MUSL_PRFX[@]} - 1))); do
    [ -n "$1" -a "$1" != "${__MUSL_ARCH[$I]}" ] && continue
    __TARGET=${__MUSL_PRFX[$I]}
    if [ -n "$(find toolchains/ -name ${__TARGET}-gcc)" ]; then
      echo -e "${GREEN}$(date +%X) ==> INFO:  Found $__TARGET toolchain${GREY}[$(pwd)]${NC}"
    else
      echo -e "${GREEN}$(date +%X) ==> INFO:  Updating musl-cross-make submodule...${GREY}[$(pwd)]${NC}"
      pushd musl-cross-make
        git fetch
        git gc
        git reset --hard HEAD
        git merge origin/master
      popd #musl-cross-make
      echo -e "${GREEN}$(date +%X) ==> INFO:  Building $__TARGET toolchain...${GREY}[$(pwd)]${NC}"
      echo "TARGET = $__TARGET" > musl-cross-make/config.mak
      make -C musl-cross-make clean
      make -C musl-cross-make -j $(nproc)
      echo -e "${GREEN}$(date +%X) ==> INFO:  Installing $__TARGET toolchain...${GREY}[$(pwd)]${NC}"
      make -C musl-cross-make OUTPUT="/" DESTDIR="$(pwd)/toolchains" install
    fi
    unset __TARGET
  done
fi

echo -e "${GREEN}$(date +%X) ==> INFO:  Getting latest coreutils version....${GREY}[$(pwd)]${NC}"
__CORE_VER=$(curl -sL http://ftp.gnu.org/gnu/coreutils | grep -o 'coreutils-[0-9.]*[0-9]' | cut -d- -f2 | sort -un | tail -n1)
__BASE_DIR=$(pwd)

if [ $__PKG_ONLY == Y ]; then
  echo -e "${GREEN}$(date +%X) ==> INFO:  Skipping build...${GREY}[$(pwd)]${NC}"
else
  [ ! -d releases ] && mkdir releases
  [ ! -d .work ] && mkdir .work
  pushd .work

  rm -rf coreutils-${__CORE_VER}
  echo -e "${GREEN}$(date +%X) ==> INFO:  Downloading coreutils v${__CORE_VER}...${GREY}[$(pwd)]${NC}"
  curl -LO http://ftp.gnu.org/gnu/coreutils/coreutils-${__CORE_VER}.tar.xz
  echo -e "${GREEN}$(date +%X) ==> INFO:  Extracting coreutils v${__CORE_VER}...${GREY}[$(pwd)]${NC}"
  tar -xJf coreutils-${__CORE_VER}.tar.xz
  rm -f coreutils-${__CORE_VER}.tar.xz

  __PATH=$PATH
  for I in $(seq 0 $((${#__MUSL_ARCH[@]} - 1))); do
    [ -n "$1" -a "$1" != "${__MUSL_ARCH[$I]}" ] && continue
    __ARCH=${__MUSL_ARCH[$I]}
    if [ -e ../releases/$__ARCH/VERSION -a "$(cat ../releases/$__ARCH/VERSION 2>/dev/null)" == "${__CORE_VER}" ]; then
      echo -e "${ORANGE}$(date +%X) ==> WARN:  Skipping coreutils v${__CORE_VER} $__ARCH build - release already exists.${GREY}[$(pwd)]${NC}"
      continue
    fi
    if [ $__THIS_ARCH == x86_64 ]; then
      export CC="${__MUSL_PRFX[$I]}-gcc"
	  	export PATH=$__PATH:$(readlink -f $(dirname $(find ../toolchains/ -name "$CC"))/..)/bin
      __STRIP="${__MUSL_PRFX[$I]}-strip"
    else
      __STRIP="strip"
    fi
    pushd coreutils-${__CORE_VER}
      echo -e "${GREEN}$(date +%X) ==> INFO:  Configuring coreutils v${__CORE_VER} $__ARCH build...${GREY}[$(pwd)]${NC}"
      env FORCE_UNSAFE_CONFIGURE=1 CFLAGS="-static -Os -ffunction-sections -fdata-sections" LDFLAGS='-Wl,--gc-sections' ./configure --host="$__ARCH"
      echo -e "${GREEN}$(date +%X) ==> INFO:  Cleaning any previous coreutils v${__CORE_VER} build...${GREY}[$(pwd)]${NC}"
      make clean
      echo -e "${GREEN}$(date +%X) ==> INFO:  Building coreutils v${__CORE_VER} for ${__ARCH}...${GREY}[$(pwd)]${NC}"
      make --silent
    popd # coreutils-${__CORE_VER}

    __EXE_FILES=$(find coreutils-${__CORE_VER}/src/ -maxdepth 1 -type f ! -name '*.*' -executable | sort)
    echo -e "${GREEN}$(date +%X) ==> INFO:  Compressing coreutils v${__CORE_VER} $__ARCH executables...${GREY}[$(pwd)]${NC}"
    $__STRIP -s -R .comment -R .gnu.version --strip-unneeded $__EXE_FILES
    upx --ultra-brute --no-lzma $__EXE_FILES
    echo -e "${GREEN}$(date +%X) ==> INFO:  Copying coreutils v${__CORE_VER} executables to releases directory...${GREY}[$(pwd)]${NC}"
    rm -rf ../releases/$__ARCH
    mkdir -p ../releases/$__ARCH
    echo "${__CORE_VER}" > ../releases/$__ARCH/VERSION
    cp $(find coreutils-${__CORE_VER}/src/ -maxdepth 1 -type f ! -name '*.*') ../releases/$__ARCH
  done
  unset __PATH __STRIP

  popd # .work
fi

echo -e "${GREEN}$(date +%X) ==> INFO:  Preparing to package coreutils v${__CORE_VER} executables...${GREY}[$(pwd)]${NC}"

__PKG_TMP=".work/.tmp"
rm -rf ${__PKG_TMP} 
mkdir -p ${__PKG_TMP}

#region conffiles debian_binary postinst prerm
cat <<"CNF" > ${__PKG_TMP}/conffiles
CNF

cat <<"DEB" > ${__PKG_TMP}/debian_binary
2.0
DEB

cat <<"POI" > ${__PKG_TMP}/postinst
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@
POI
chmod +x ${__PKG_TMP}/postinst

cat <<"PRR" > ${__PKG_TMP}/prerm
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_prerm $0 $@
PRR
chmod +x ${__PKG_TMP}/prerm
#endregion

clear_work_dir() {
  echo -e "${GREEN}$(date +%X) ==> INFO:  Clearing work directory ${__PKG_TMP}...${GREY}[$(pwd)]${NC}"
  find ${__PKG_TMP}/ -mindepth 1 -maxdepth 1 ! -name conffiles -a ! -name debian_binary -a ! -name postinst -a ! -name prerm -exec rm -rf {} \;
}

update_packages_file() {
  local arch="$1"
  local ipk="$(basename $2)"
  local sha256="$(sha256sum "$2" | cut -d" " -f1)"
  local size="$(du --bytes $2 | cut -f1)"
  echo -e "${GREEN}$(date +%X) ==> INFO:  Updating Packages file with ${ipk} (Size=${size})...${GREY}[$(pwd)]${NC}"
  sed -e "/^Installed-Size:/a\Filename: ${ipk}\nSize: ${size}\nSHA256sum: ${sha256}" $__PKG_TMP/control >> ${__BASE_DIR}/repository/${arch}/packages/Packages
  echo "" >> ${__BASE_DIR}/repository/${arch}/packages/Packages
}

chmod +x bin/*

unset CC

if [ ! -x bin/usign ]; then
  pushd usign
    git fetch
    git gc
    git reset --hard HEAD
    git merge origin/master
    rm -rf build
    mkdir build
    pushd build
      echo -e "${GREEN}$(date +%X) ==> INFO:  Generating build system for usign...${GREY}[$(pwd)]${NC}"
      cmake ..
      echo -e "${GREEN}$(date +%X) ==> INFO:  Building usign...${GREY}[$(pwd)]${NC}"
      make --silent
    popd # build
  popd # usign
  cp usign/build/usign bin/usign
else
  echo -e "${GREEN}$(date +%X) ==> INFO:  usign exists${GREY}[$(pwd)]${NC}"
fi

for I in $(seq 0 $((${#__MUSL_ARCH[@]} - 1))); do
  [ -n "$1" -a "$1" != "${__MUSL_ARCH[$I]}" ] && continue
  __ARCH=${__OWRT_ARCH[$I]}

  echo -e "${GREEN}$(date +%X) ==> INFO:  Recreating $__ARCH repository...${GREY}[$(pwd)]${NC}"
  rm -rf ${__BASE_DIR}/repository/${__ARCH}
  mkdir -p ${__BASE_DIR}/repository/${__ARCH}/packages

  if [ "$__ARCH" == "arm_cortex-a53" -a "${__MUSL_ARCH[$I]}" == "arm" ]; then
    echo "**WARNING:** These are 32-bit binaries, because the 64-bit binaries currently coredump when run on a $__ARCH Technicolor device!" >${__BASE_DIR}/repository/${__ARCH}/README.md
  fi

  for __F in $(find releases/${__MUSL_ARCH[$I]}/ -mindepth 1 -maxdepth 1 -executable ! -name '\[' | sort); do
    __FILENAME=$(basename $__F)
    echo -e "${GREEN}$(date +%X) ==> INFO:  Packaging $__FILENAME...${GREY}[$(pwd)]${NC}"
    mkdir -p ${__PKG_TMP}/usr/bin
    cp -p "$__F" ${__PKG_TMP}/usr/bin/
    [ $__FILENAME == test ] && cp -p '[' ${__PKG_TMP}/usr/bin/
    chmod +x "$__F"
    #region control
    cat <<CTL > ${__PKG_TMP}/control
Package: coreutils-$__FILENAME
Version: $__CORE_VER
Depends: coreutils
License: GPL-3.0-or-later
Section: utils
Architecture: $__ARCH
Installed-Size: $(du --bytes "$__F" | cut -f1)
Description:  Statically-linked full version of standard GNU $__FILENAME utility.
CTL
    #endregion
    echo "#!/bin/sh" > ${__PKG_TMP}/postrm
    for __BIN in ${__PKG_TMP}/usr/bin/; do
      echo "[ -e '/rom/usr/bin/$__BIN' ] && cp -a '/rom/usr/bin/$__BIN' '/usr/bin/$__BIN'" >> ${__PKG_TMP}/postrm
    done
    echo "exit 0" >> ${__PKG_TMP}/postrm
    chmod +x ${__PKG_TMP}/postrm
    bin/make_ipk.sh "${__BASE_DIR}/repository/${__ARCH}/packages/coreutils-${__FILENAME}_${__CORE_VER}_${__ARCH}.ipk" "$__PKG_TMP" || exit 1
    update_packages_file "${__ARCH}" "${__BASE_DIR}/repository/${__ARCH}/packages/coreutils-${__FILENAME}_${__CORE_VER}_${__ARCH}.ipk"
    clear_work_dir
  done

  echo -e "${GREEN}$(date +%X) ==> INFO:  Creating base coreutils package...${GREY}[$(pwd)]${NC}"
  #region control
  cat <<CTL > $__PKG_TMP/control
Package: coreutils
Version: $__CORE_VER
License: GPL-3.0-or-later
Section: utils
Architecture: $__ARCH
Installed-Size: 0
Description:  Statically-linked full versions of standard GNU utilities. If an equivalent 
 Busybox applet is available, you should consider using that instead as Busybox applets are
 usually smaller, at the expense of reduced functionality.
CTL
  #endregion
  bin/make_ipk.sh "${__BASE_DIR}/repository/${__ARCH}/packages/coreutils_${__CORE_VER}_${__ARCH}.ipk" "$__PKG_TMP" || exit 1
  update_packages_file "${__ARCH}" "${__BASE_DIR}/repository/${__ARCH}/packages/coreutils_${__CORE_VER}_${__ARCH}.ipk"
  clear_work_dir

  echo -e "${GREEN}$(date +%X) ==> INFO:  Signing Packages file...${GREY}[$(pwd)]${NC}"
  bin/usign -S -m ${__BASE_DIR}/repository/${__ARCH}/packages/Packages -s keys/seud0nym-private.key -x ${__BASE_DIR}/repository/${__ARCH}/packages/Packages.sig
  echo -e "${GREEN}$(date +%X) ==> INFO:  GZipping Packages file...${GREY}[$(pwd)]${NC}"
  gzip -fk ${__BASE_DIR}/repository/${__ARCH}/packages/Packages
done

echo -e "${GREEN}$(date +%X) ==> INFO:  Done${NC}"
