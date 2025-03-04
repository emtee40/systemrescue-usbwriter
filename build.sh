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

if ! command -v pacman &>/dev/null ; then
    echo "ERROR: 'pacman' command not found."
    exit 1
fi

# ensure all required packages are installed

declare -a required_pkgs
required_pkgs=(
    acl
    bash
    binutils
    busybox
    coreutils
    dialog
    diffutils
    dosfstools
    findutils
    fuse2
    gcc
    gcc-libs
    git
    glibc
    grep
    isomd5sum
    libburn
    libcap
    libisoburn
    libisofs
    libtool
    make
    ncurses
    nnn
    pacman
    patch
    patchelf
    pcre2
    popt
    readline
    sed
    squashfs-tools
    syslinux
    systemd-libs
    util-linux
    util-linux-libs
    zlib
)

declare -a missing_pkgs=()
for pkg in "${required_pkgs[@]}"; do
    if ! pacman -Q "${pkg}" >/dev/null 2>&1 ; then
        missing_pkgs+=("${pkg}")
    fi
done

if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    echo "ERROR: missing packages. Please install them with pacman and try again:"
    echo
    echo "pacman -S" ${missing_pkgs[@]}
    exit 1
fi

if ! command -v appimagetool-x86_64.AppImage &>/dev/null && \
   ! [[ -x "${HERE}/appimagetool-x86_64.AppImage" ]] ; then
   
    echo "ERROR: 'appimagetool-x86_64.AppImage' command not found."
    echo "Please get it from https://github.com/AppImage/AppImageKit/releases"
    exit 1
fi

# clean & create build dir
rm -rf ${HERE}/AppDirBuild/*
mkdir -p ${HERE}/AppDirBuild
cp -R ${HERE}/AppDirSrc/* ${HERE}/AppDirBuild/

# install binaries
declare -a install_bins
install_bins=(
    bash
    busybox
    checkisomd5
    cmp
    dd
    df
    dialog
    find
    getopt
    grep
    lsblk
    mkfs.fat
    mktemp
    nnn
    sed
    sfdisk
    syslinux
    xorriso
)

for bin in "${install_bins[@]}"; do
    cp --no-dereference --preserve=links,mode,ownership,timestamps "/usr/bin/${bin}" "${HERE}/AppDirBuild/usr/bin/"
done

declare -a busybox_symlinks
busybox_symlinks=(
    cat
    clear
    mkdir
    pgrep
    rm
    stat
    stty
    sync
    tail
)

for bin in "${busybox_symlinks[@]}"; do
    ln -s busybox "${HERE}/AppDirBuild/usr/bin/${bin}"
done

# build & install our own patched mtools
${HERE}/mtools/build.sh

cp --no-dereference --preserve=links,mode,ownership,timestamps "${HERE}/mtools/build/mtools-4.0.42/mtools" "${HERE}/AppDirBuild/usr/bin/"
install_bins+=("mtools")
ln -s mtools "${HERE}/AppDirBuild/usr/bin/mattrib"
ln -s mtools "${HERE}/AppDirBuild/usr/bin/mcopy"
ln -s mtools "${HERE}/AppDirBuild/usr/bin/mmove"

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
    libcap
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
    libpopt
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

# properly check if a program is dynamically link or a shared library
# works reliably with -o errexit -o pipefail
is_dynamic_exec()
{
    local FILE=$1
    
    local exitcode=0
    local lddout
    
    lddout=$(ldd "$FILE" 2>&1 || exitcode=$?)
    
    if [[ $exitcode -ne 0 ]]; then
        # ldd returned an error code
        return 1
    fi
    
    if echo "$lddout" | grep -q "\(not a dynamic executable\|statically linked\)"; then
        # ldd returned no error code, but found no dynamic executable
        return 1
    fi
    
    return 0
}

# check used libs
for bin in "${install_bins[@]}"; do

    if ! is_dynamic_exec "${HERE}/AppDirBuild/usr/bin/${bin}"; then
        continue
    fi

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

# check used libs in libs
ls -1 "${HERE}/AppDirBuild/usr/lib/" | while read -r libline; do

    if ! [[ -f "${HERE}/AppDirBuild/usr/lib/${libline}" ]] || ! is_dynamic_exec "${HERE}/AppDirBuild/usr/lib/${libline}"; then
        continue
    fi

    ldd "${HERE}/AppDirBuild/usr/lib/${libline}" | while read -r line; do
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
                echo "ERROR: library linked into ${libline} not found: ${line}"
                exit 1
            fi
        fi
    done
done

# set rpath & ELF interpreter for binaries
for bin in "${install_bins[@]}"; do

    if ! is_dynamic_exec "${HERE}/AppDirBuild/usr/bin/${bin}"; then
        continue
    fi

    # patch the ELF interpreter: that is the library responsible for loading shared libraries = ld-linux.so
    # it must exactly match the libc version. Since we bring our own libc, we use a relative interpreter path
    # this means the whole AppImage must be run with the current path set to the root of the AppDir
    # AppRun is responsible for storing the current path, pushd, popd etc.
    patchelf --set-interpreter "./usr/lib/ld-linux-x86-64.so.2" "${HERE}/AppDirBuild/usr/bin/${bin}"

    # once the ELF interpreter is loaded, it can understand rpaths with $ORIGIN, meaning relative to the
    # location of the binary or library
    patchelf --set-rpath "\$ORIGIN/../lib/" --force-rpath "${HERE}/AppDirBuild/usr/bin/${bin}"
done

# set rpath for libraries
ls -1 "${HERE}/AppDirBuild/usr/lib/" | while read -r line; do
    if [[ -f "${HERE}/AppDirBuild/usr/lib/${line}" ]] && \
       ! [[ -L "${HERE}/AppDirBuild/usr/lib/${line}" ]] && is_dynamic_exec "${HERE}/AppDirBuild/usr/lib/${line}"; then
        # ensure exec permissions
        chmod 755 "${HERE}/AppDirBuild/usr/lib/${line}"
        
        # same as with binaries. shared libs don't have an interpreter
        patchelf --set-rpath "\$ORIGIN" --force-rpath "${HERE}/AppDirBuild/usr/lib/${line}"
    fi
done

# copy gconv data for codepage 850 (dos default for FAT)
mkdir -p "${HERE}/AppDirBuild/usr/lib/gconv/gconv-modules.d"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/gconv/IBM850.so "${HERE}/AppDirBuild/usr/lib/gconv/"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/gconv/ISO8859-1.so "${HERE}/AppDirBuild/usr/lib/gconv/"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/gconv/gconv-modules "${HERE}/AppDirBuild/usr/lib/gconv/"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/gconv/gconv-modules.d/gconv-modules-extra.conf "${HERE}/AppDirBuild/usr/lib/gconv/gconv-modules.d"
patchelf --set-rpath "\$ORIGIN/.." --force-rpath "${HERE}/AppDirBuild/usr/lib/gconv/IBM850.so"
patchelf --set-rpath "\$ORIGIN/.." --force-rpath "${HERE}/AppDirBuild/usr/lib/gconv/ISO8859-1.so"

# copy terminfo data for ncurses
cp --no-dereference -r --preserve=links,mode,ownership,timestamps /usr/share/terminfo/ "${HERE}/AppDirBuild/usr/share/"

# install syslinux boot blocks
mkdir -p "${HERE}/AppDirBuild/usr/lib/syslinux/bios"
cp --no-dereference --preserve=links,mode,ownership,timestamps /usr/lib/syslinux/bios/*.bin "${HERE}/AppDirBuild/usr/lib/syslinux/bios/"

# store exact syslinux version for compatibility check
mkdir -p "${HERE}/AppDirBuild/usr/share/versions"
pacman -Q syslinux | sed -e "s#syslinux \(.*\)#\1#" >"${HERE}/AppDirBuild/usr/share/versions/syslinux"

# store git commit id or tag of sysrescueusbwriter
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 ; then
    # we have git, use it
    COMMIT_ID=$(git rev-parse HEAD)
    
    if git describe --tags --exact-match "$COMMIT_ID" >/dev/null 2>&1; then
        # we have a tag for the current commit, use it
        git describe --tags --exact-match "$COMMIT_ID" >"${HERE}/AppDirBuild/usr/share/versions/sysrescueusbwriter"
    else
        # we don't have a tag, use a shortened commit id
        echo "git-${COMMIT_ID:0:8}" >"${HERE}/AppDirBuild/usr/share/versions/sysrescueusbwriter"
    fi
else
    # unkown version
    echo "???????" >"${HERE}/AppDirBuild/usr/share/versions/sysrescueusbwriter"
fi

# store build date too since it is helpful in determining exact package versions embedded
date +%Y-%m-%d >"${HERE}/AppDirBuild/usr/share/versions/sysrescueusbwriter-builddate"

link_license()
{
    local PROG=$1
    local SPDX=$2
    local LICFILE
    
    case "$SPDX" in
        GPL-3.0-or-later)
            LICFILE="../gpl-3.0.txt"
            ;;
        GPL-3.0-only)
            LICFILE="../gpl-3.0.txt"
            ;;
        GPL-2.0-or-later)
            LICFILE="../gpl-2.0.txt"
            ;;
        GPL-2.0-only)
            LICFILE="../gpl-2.0.txt"
            ;;
        LGPL-2.1-or-later)
            LICFILE="../lgpl-2.1.txt"
            ;;
        LGPL-2.1-only)
            LICFILE="../lgpl-2.1.txt"
            ;;
        *)
            echo "ERROR: unknown license $SPDX for program $PROG"
            exit 1
            ;;
    esac
    
    mkdir -p "${HERE}/AppDirBuild/usr/share/licenses/${PROG}"
    ln -s "${LICFILE}" "${HERE}/AppDirBuild/usr/share/licenses/${PROG}/${SPDX}"
}

copy_license()
{
    local PROG=$1
    local LICFILE=$2
    
    mkdir -p "${HERE}/AppDirBuild/usr/share/licenses/${PROG}"
    cp --no-dereference --preserve=links,mode,ownership,timestamps "$LICFILE" "${HERE}/AppDirBuild/usr/share/licenses/${PROG}"
}

# symlink common licenses, use SPDX-License-Identifier as the symlink name
link_license "sysrescueusbwriter" "GPL-3.0-or-later"
link_license "bash" "GPL-3.0-or-later"
link_license "busybox" "GPL-2.0-only"
link_license "isomd5sum" "GPL-2.0-or-later"
link_license "diffutils" "GPL-3.0-or-later"
link_license "coreutils" "GPL-3.0-or-later"
link_license "dialog" "LGPL-2.1-only"
link_license "findutils" "GPL-3.0-or-later"
link_license "util-linux" "GPL-2.0-or-later"
link_license "grep" "GPL-3.0-or-later"
link_license "dosfstools" "GPL-3.0-or-later"
link_license "sed" "GPL-3.0-or-later"
link_license "syslinux" "GPL-2.0-or-later"
link_license "libisoburn" "GPL-2.0-or-later"
link_license "mtools" "GPL-3.0-or-later"
link_license "glibc" "LGPL-2.1-or-later"
link_license "acl" "LGPL-2.1-or-later"
link_license "util-linux-libs" "LGPL-2.1-or-later"
link_license "libburn" "GPL-2.0-or-later"
link_license "gcc-libs" "GPL-3.0-or-later"
link_license "libisofs" "GPL-2.0-or-later"
link_license "readline" "GPL-3.0-or-later"
link_license "libcap" "GPL-2.0-only"

# this doesn't use the Arch package name but the library name because
# libudev is LGPL-2.1-or-later while other parts of systemd-libs are licensed differently
link_license "libudev" "LGPL-2.1-or-later"

# packages with custom licenses or additions
copy_license "nnn" "/usr/share/licenses/nnn/LICENSE"
copy_license "gcc-libs" "/usr/share/licenses/gcc-libs/RUNTIME.LIBRARY.EXCEPTION"
copy_license "ncurses" "/usr/share/licenses/ncurses/COPYING"
copy_license "pcre2" "/usr/share/licenses/pcre2/LICENSE"
copy_license "popt" "/usr/share/licenses/popt/LICENSE"
copy_license "zlib" "/usr/share/licenses/zlib/LICENSE"

PATH="./:${PATH}"
appimagetool-x86_64.AppImage AppDirBuild sysrescueusbwriter-x86_64.AppImage

echo "done"
