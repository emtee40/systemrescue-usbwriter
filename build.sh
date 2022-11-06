#! /usr/bin/env bash
#
# build an AppImage for sysrescueusbwriter
# 
# Author: Gerd v. Egidy
# SPDX-License-Identifier: GPL-3.0-or-later

# abort on failures
set -o errexit -o pipefail -o noclobber -o nounset

SELF=$(readlink -f "$0")
export HERE=${SELF%/*}

# limit to Arch Linux, we need pacman, the dir layout etc.
if ! grep -q "ID=arch" /etc/os-release || grep -q "ID_LIKE=.*arch" /etc/os-release ; then
    echo "ERROR: this script is not designed to work on other distros than Arch Linux"
    exit 1
fi

if ! uname -m | grep -q "x86_64"; then
    echo "ERROR: this script only works on x86_64"
    exit 1
fi

# TODO: check for all required pacman packages

# clean & create build dir
rm -rf ${HERE}/AppDirBuild/*
mkdir -p ${HERE}/AppDirBuild
cp -R ${HERE}/AppDirSrc/* ${HERE}/AppDirBuild/

# install binaries
declare -a install_bins
install_bins=(
    bash
    cat
    cmp
    dd
    df
    dialog
    find
    getopt
    grep
    lsblk
    mcopy
    mkdir
    mkfs.fat
    mktemp
    mtools
    rm
    sed
    sfdisk
    stat
    sync
    syslinux
    xorriso
)

for bin in "${install_bins[@]}"; do
    cp --no-dereference --preserve=links,mode,ownership,timestamps "/usr/bin/${bin}" "${HERE}/AppDirBuild/usr/bin/"
done

# install libraries
# explicitly list them because we need to manually check their licenses
# for compatibility and bundle them if necessary
declare -a install_libs
install_libs=(
    ld-linux-x86-64
    libacl
    libblkid
    libburn
    libc
    libdialog
    libdl
    libfdisk
    libgcc_s
    libisoburn
    libisofs
    libm
    libmount
    libncursesw
    libpcre2-8
    libpthread
    libreadline
    libsmartcols
    libtinfo
    libudev
    libuuid
    libz
)

for lib in "${install_libs[@]}"; do
    cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/${lib}.so.* "${HERE}/AppDirBuild/usr/lib/"
done

# check used libs
for bin in "${install_bins[@]}"; do
    ldd "${HERE}/AppDirBuild/usr/bin/${bin}" | while read -r line; do
        # ignore vdso & ld-linux, they are necessary for shared libs and are expteced to be always available on the target
        if ! echo $line | grep -q "linux-vdso.so" && ! echo $line | grep -q "ld-linux-x86-64.so" ; then
            found=0
            
            # check against the list of libs we installed
            for lib in "${install_libs[@]}"; do
                if echo $line | grep -q "${lib}.so." ; then
                    found=1
                    break
                fi
            done
            
            if [[ $found -eq 0 ]] ; then
                echo "ERROR: library linked into ${bin} not found: ${line}"
                exit 1
            fi
        fi
    done
done

# set rpath & ELF interpreter for binaries
for bin in "${install_bins[@]}"; do
    if ! ldd "${HERE}/AppDirBuild/usr/bin/${bin}" | grep -q -E "(not a dynamic executable|statically linked)"; then
        
        # patch the ELF interpreter: that is the library responsible for loading shared libraries = ld-linux.so
        # it must exactly match the libc version. Since we bring our own libc, we use a relative interpreter path
        # this means the whole AppImage must be run with the current path set to the root of the AppDir
        # AppRun is responsible for storing the current path, pushd, popd etc.
        patchelf --set-interpreter "./usr/lib/ld-linux-x86-64.so.2" "${HERE}/AppDirBuild/usr/bin/${bin}"

        # once the ELF interpreter is loaded, it can understand rpaths with $ORIGIN, meaning relative to the
        # location of the binary or library
        patchelf --set-rpath "\$ORIGIN/../lib/" --force-rpath "${HERE}/AppDirBuild/usr/bin/${bin}"
        
    fi
done

# set rpath for libraries
ls -1 "${HERE}/AppDirBuild/usr/lib/" | while read -r line; do
    if [[ -f "${line}" ]] && ! ldd "${HERE}/AppDirBuild/usr/lib/${line}" | grep -q -E "(not a dynamic executable|statically linked)"; then
    
        # same as with binaries. shared libs don't have an interpreter
        patchelf --set-rpath "\$ORIGIN" --force-rpath "${HERE}/AppDirBuild/usr/lib/${line}"
    fi
done

# install syslinux boot blocks
mkdir -p "${HERE}/AppDirBuild/usr/lib/syslinux/bios"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/syslinux/bios/*.bin "${HERE}/AppDirBuild/usr/lib/syslinux/bios/"

# TODO: install all license files

PATH="./:${PATH}"
appimagetool-x86_64.AppImage AppDirBuild sysrescueusbwriter-x86_64.AppImage

echo "done"
