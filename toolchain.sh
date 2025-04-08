#!/usr/bin/env bash

set -euo pipefail

# Set work dir
AROOT="$(pwd)"

# Vars
BINUTILS_VERSION=2.43
GCC_VERSION=14.2.0

# Threads
THREADS="-j$(nproc --all)"

# Config
export TARGET=aarch64-linux-gnu
export PREFIX="$AROOT/tools"
export PATH="$PREFIX/bin:$PATH"
export SRC="$AROOT/src"
export BUILD="$AROOT/build"

### Bash Color #############################################################

RST="\033[0m" 		# reset
BLD="\033[1m"		# bold
RED="\033[01;31m"	# red
GRN="\033[01;32m"	# green
YLW="\033[01;33m"	# yellow
CYN="\033[01;36m"	# cyan

#### Functions #############################################################

# Alias for echo to handle escape codes like colors
echo() {
    command echo -e "${@}"
}

# Prints a formatted header to point out what is being done to the user
header() {
    echo "${CYN}"
    echo " ====$(printf '=%.0s' $(seq ${#1}))===="
    echo " ==  ${1}  =="
    echo " ====$(printf '=%.0s' $(seq ${#1}))===="
    echo "${RST}"
}

# Prints a statement in bold green
success() {
	echo
    echo " ${GRN}${1}${RST}"
}

# Prints an info in bold yellow
info() {
	echo
    echo " ${YLW}${1}${RST}"
}

#############################################################

# Timer: Total start
TOTAL_START=$(date +%s)

# Create working dirs
mkdir -p "$PREFIX" "$SRC" "$BUILD"

# Timer: Download start
DOWNLOAD_START=$(date +%s)

# Download sources
header "[1/3] Downloading sources..."

cd "$SRC"
# Binutils extract
if [ ! -d binutils-$BINUTILS_VERSION ]; then
  info "Binutils $BINUTILS_VERSION"
  wget https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz
  tar -xf binutils-$BINUTILS_VERSION.tar.xz
fi

# GCC extract
if [ ! -d gcc-$GCC_VERSION ]; then
  info "GCC $GCC_VERSION"
  wget https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz
  tar -xf gcc-$GCC_VERSION.tar.xz
  cd gcc-$GCC_VERSION
  ./contrib/download_prerequisites
  cd ..
fi

# Timer: Download end
DOWNLOAD_END=$(date +%s)
DOWNLOAD_DURATION=$((DOWNLOAD_END - DOWNLOAD_START))
DL_MIN=$((DOWNLOAD_DURATION / 60))
DL_SEC=$((DOWNLOAD_DURATION % 60))

success "[1/3] Download done in ${DL_MIN}m ${DL_SEC}s"

# Timer: Build start
BUILD_START=$(date +%s)

# Build binutils
header "[2/3] Build Binutils..."

cd "$BUILD"
rm -rf binutils && mkdir binutils && cd binutils
"$SRC/binutils-$BINUTILS_VERSION/configure" \
  --target=$TARGET \
  --prefix="$PREFIX" \
  --disable-nls \
  --disable-werror
make -s "${THREADS}"
make -s install

success "[2/3] Build Binutils done."

# Build GCC (only C, minimal)
header "[3/3] Build GCC (minimal)..."

cd "$BUILD"
rm -rf gcc && mkdir gcc && cd gcc
"$SRC/gcc-$GCC_VERSION/configure" \
  --target=$TARGET \
  --prefix="$PREFIX" \
  --without-headers \
  --with-newlib \
  --disable-nls \
  --disable-shared \
  --disable-threads \
  --disable-multilib \
  --disable-libssp \
  --disable-libquadmath \
  --disable-libgomp \
  --disable-libvtv \
  --disable-libstdcxx \
  --disable-libatomic \
  --disable-libsanitizer \
  --disable-libitm \
  --enable-languages=c
make -s all-gcc "${THREADS}"
make -s all-target-libgcc "${THREADS}"
make -s install-gcc
make -s install-target-libgcc

success "[3/3] Build GCC done."

# Timer: Build end
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
BUILD_MIN=$((BUILD_DURATION / 60))
BUILD_SEC=$((BUILD_DURATION % 60))

# Timer: Total end
TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
TOTAL_MIN=$((TOTAL_DURATION / 60))
TOTAL_SEC=$((TOTAL_DURATION % 60))

# Done
success "Cross-Compiler for $TARGET build successfull"
echo "    Download time:  ${DL_MIN}m ${DL_SEC}s"
echo "    Build time:     ${BUILD_MIN}m ${BUILD_SEC}s"
echo "    Total time:     ${TOTAL_MIN}m ${TOTAL_SEC}s"
echo ""
echo " ${BLD}Installed in: $PREFIX${RST}"
echo ""
