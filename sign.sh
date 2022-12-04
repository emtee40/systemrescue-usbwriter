#! /usr/bin/env bash
#
# sign an AppImage with GnuPG
#
# ATTENTION: this rebuilds the AppImage with an embedded signature.
# The original sysrescueusbwriter-x86_64.AppImage file is **overwritten**
# 
# call: ./sign.sh [GPG-KEY-ID]
#
# GPG-KEY-ID is an optional key id, without it the default key configured in GnuPG will be used
#
# Do not call in a docker image (if you are using them), but outside to allow easy access to the 
# GnuPG key storage. Only appimagetool, gpg and sha256/512sum are required.
#
# Author: Gerd v. Egidy
# SPDX-License-Identifier: GPL-3.0-or-later

# abort on failures
set -o errexit -o pipefail -o noclobber -o nounset

APPIMAGE_FILE="sysrescueusbwriter-x86_64.AppImage"

OWD=`pwd`
PATH="${OWD}:${PATH}"

if ! command -v gpg &>/dev/null ; then
    echo "ERROR: 'gpg' command not found."
    exit 1
fi

if ! command -v sha256sum &>/dev/null ; then
    echo "ERROR: 'sha256sum' command not found."
    exit 1
fi

if ! command -v appimagetool-x86_64.AppImage &>/dev/null ; then
    echo "ERROR: 'appimagetool-x86_64.AppImage' command not found."
    exit 1
fi

if [[ ! -x "$APPIMAGE_FILE" ]]; then
    echo "ERROR: can't find $APPIMAGE_FILE in current directory"
    exit 1
fi

if "${OWD}/${APPIMAGE_FILE}" --version | grep -E -q "^git-|\?\?\?\?" ; then
    echo "ERROR: this is not a tagged release. Please only sign properly tagged releases"
    echo -n "Version "
    "${OWD}/${APPIMAGE_FILE}" --version
    exit 10
fi

SIGNKEY=""
if [[ ! -z ${1+x} ]]; then
    SIGNKEY="$1"
fi

cleanup()
{
    # clean up our temp dir, called via EXIT trap
    rm -rf "${TMPDIR}"
    
    cd "$OWD"
}

# if not configured we use /tmp
if ! [[ -v TMPDIR ]] || [[ -z "$TMPDIR" ]]; then
    TMPDIR=/tmp
fi

# always create a subdir below a given TMPDIR for security/reliability reasons
TMPDIR=$(mktemp --tmpdir="${TMPDIR}" --directory sysrescueusbwriter.XXXXXXXXXX)

# always clean up our tmpdir when the script exits
trap cleanup EXIT

# cleanup() will cd back to the original working dir
cd "$TMPDIR"

# unpack original AppImage, always to "./squashfs-root/" dir
"${OWD}/${APPIMAGE_FILE}" --appimage-extract

if ! [[ -d "${TMPDIR}/squashfs-root" ]]; then
    echo "ERROR: problem unpacking AppImage, no squashfs-root"
    exit 2
fi

# rebuild, this time with embedded signature
if [[ -n "$SIGNKEY" ]]; then
    # key ids can be given as hex id or "firstname lastname" - for the latter we need escaping
    appimagetool-x86_64.AppImage squashfs-root "${APPIMAGE_FILE}" --sign "--sign-key=${SIGNKEY}"
else
    appimagetool-x86_64.AppImage squashfs-root "${APPIMAGE_FILE}" --sign
fi

# while the AppImage format contains a mechanism to embed gpg signatures, the tooling
# to properly verify these isn't widespread yet. So always create separate signature files too
if [[ -n "$SIGNKEY" ]]; then
    # key ids can be given as hex id or "firstname lastname" - for the latter we need escaping
    gpg --detach-sign --armor --batch --yes "--local-user=${SIGNKEY}" "$APPIMAGE_FILE"
else
    gpg --detach-sign --armor --batch --yes "$APPIMAGE_FILE"
fi

rm -f "${APPIMAGE_FILE}.sha256"
rm -f "${APPIMAGE_FILE}.sha512"
sha256sum --binary "$APPIMAGE_FILE" >"${APPIMAGE_FILE}.sha256"
sha512sum --binary "$APPIMAGE_FILE" >"${APPIMAGE_FILE}.sha512"

mv -f "${APPIMAGE_FILE}" "${OWD}"
mv -f "${APPIMAGE_FILE}.asc" "${OWD}"
mv -f "${APPIMAGE_FILE}.sha256" "${OWD}"
mv -f "${APPIMAGE_FILE}.sha512" "${OWD}"
