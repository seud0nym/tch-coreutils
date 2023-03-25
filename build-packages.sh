#!/bin/sh

WORK_DIR="tmp"
COREUTILS_VERSION="$(grep '^coreutils_version=' build.sh | grep -oE '[0-9.-]+')"

rm -rf ${WORK_DIR} 
mkdir ${WORK_DIR}

cat <<"CNF" > ${WORK_DIR}/conffiles
CNF

cat <<"DEB" > ${WORK_DIR}/debian_binary
2.0
DEB

cat <<"POI" > ${WORK_DIR}/postinst
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@
POI
chmod +x ${WORK_DIR}/postinst

cat <<"PRR" > ${WORK_DIR}/prerm
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_prerm $0 $@
PRR
chmod +x ${WORK_DIR}/prerm

clear_work_dir() {
  find ${WORK_DIR}/ -mindepth 1 -maxdepth 1 ! -name conffiles -a ! -name debian_binary -a ! -name postinst -a ! -name prerm -exec rm -rf {} \;
}

update_packages_file() {
  local arch="$1"
  local ipk="$(basename $2)"
  local sha256="$(sha256sum "$2" | cut -d" " -f1)"
  local size="$(du --bytes $2 | cut -f1)"
  sed -e "/^Installed-Size:/a\Filename: ${ipk}\nSize: ${size}\nSHA256sum: ${sha256}" $WORK_DIR/control >> repository/${arch}/packages/Packages
  echo "" >> repository/${arch}/packages/Packages
}

for ARCH in arm_cortex-a9 arm_cortex-a53; do
  rm -rf repository/${ARCH}
  mkdir -p repository/${ARCH}/packages

  for f in $(ls releases/* | grep -v '\['); do
    if file -b "$f" | grep -q '^ELF'; then
      filename=$(basename $f)
      mkdir -p ${WORK_DIR}/usr/bin
      cp -p "$f" ${WORK_DIR}/usr/bin/
      chmod +x "$f"
      cat <<CTL > ${WORK_DIR}/control
Package: coreutils-$filename
Version: $COREUTILS_VERSION
Depends: coreutils
License: GPL-3.0-or-later
Section: utils
Architecture: $ARCH
Installed-Size: $(du --bytes "$f" | cut -f1)
Description:  Statically-linked full version of standard GNU $filename utility.
CTL
      cat <<POR > ${WORK_DIR}/postrm
#!/bin/sh
[ -e /rom/usr/bin/$filename ] && cp -a /rom/usr/bin/$filename /usr/bin/$filename
exit 0
POR
      chmod +x ${WORK_DIR}/postrm
      ./make_ipk.sh "${PWD}/repository/${ARCH}/packages/coreutils-${filename}_${COREUTILS_VERSION}_${ARCH}.ipk" "$WORK_DIR" || exit 1
      update_packages_file "${ARCH}" "${PWD}/repository/${ARCH}/packages/coreutils-${filename}_${COREUTILS_VERSION}_${ARCH}.ipk"
      clear_work_dir
    fi
  done

  cat <<CTL > $WORK_DIR/control
Package: coreutils
Version: $COREUTILS_VERSION
License: GPL-3.0-or-later
Section: utils
Architecture: $ARCH
Installed-Size: 0
Description:  Statically-linked full versions of standard GNU utilities. If an equivalent 
 Busybox applet is available, you should consider using that instead as Busybox applets are
 usually smaller, at the expense of reduced functionality.
CTL

  ./make_ipk.sh "${PWD}/repository/${ARCH}/packages/coreutils_${COREUTILS_VERSION}_${ARCH}.ipk" "$WORK_DIR" || exit 1
  update_packages_file "${ARCH}" "${PWD}/repository/${ARCH}/packages/coreutils_${COREUTILS_VERSION}_${ARCH}.ipk"
  clear_work_dir

  gzip -fk "repository/${ARCH}/packages/Packages"
done

exit 0