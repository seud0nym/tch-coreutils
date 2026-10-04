# Pinned musl-cross-make configuration for the BCM63138 (DJA0230):
# ARMv7-A Cortex-A9, soft-float EABI (arm_cortex-a9 opkg architecture).
# Copy to musl-cross-make/config.mak before building. Every version below has
# a sha1 in musl-cross-make/hashes at submodule commit fe915821.
TARGET = arm-linux-musleabi

GCC_VER = 11.2.0
BINUTILS_VER = 2.33.1
MUSL_VER = 1.2.3
GMP_VER = 6.1.2
MPC_VER = 1.1.0
MPFR_VER = 4.0.2
LINUX_VER = headers-4.19.88-1

# Default code generation: Cortex-A9, ARM mode, no FP instructions (soft-float
# EABI), so libc, libgcc and every program match the stock userland ABI.
GCC_CONFIG += --with-cpu=cortex-a9 --with-float=soft

# Build musl's libc.a and libgcc as PIE code so programs can be linked as
# static PIE (ASLR, like the stock PIE dnsmasq). Programs linked with plain
# -static still come out as fixed-address static executables.
GCC_CONFIG += --enable-default-pie

# Smaller, deterministic toolchain build.
COMMON_CONFIG += CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2" LDFLAGS="-s"
COMMON_CONFIG += --disable-nls
GCC_CONFIG += --disable-libquadmath --disable-decimal-float --disable-multilib
