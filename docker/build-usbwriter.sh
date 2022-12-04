#!/bin/bash

# Make sure the docker image exists
dockerimg="sysrescueusbwriter:latest"
if ! docker inspect ${dockerimg} >/dev/null 2>/dev/null ; then
    echo "ERROR: You must build the following docker image before you run this script: ${dockerimg}"
    exit 1
fi

# Determine the path to the git repository
fullpath="$(realpath $0)"
curdir="$(dirname ${fullpath})"
repodir="$(realpath ${curdir}/..)"
echo "curdir=${curdir}"
echo "repodir=${repodir}"

# Run a shell in the container from which to build packages 
docker run --rm --user 0:0 --privileged -it --workdir /workspace \
    --cap-add SYS_ADMIN --device /dev/fuse \
    --volume=${repodir}:/workspace \
    ${dockerimg} /usr/bin/bash -x /workspace/build.sh "$@"
