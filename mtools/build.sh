#!/bin/bash

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

VERSION=4.0.42

# clean build dir
rm -rf "${HERE}/build"
mkdir "${HERE}/build"

pushd "${HERE}/build" >/dev/null

tar xjf ../mtools-${VERSION}.tar.bz2
cd mtools-${VERSION}
patch -p1 <../../mtools-mcopy-progress-output.patch
patch -p1 <../../mtools-only-env-config.patch

./configure --disable-vold --disable-new-vold --disable-xdf --without-x
make
strip --strip-unneeded mtools

popd >/dev/null
