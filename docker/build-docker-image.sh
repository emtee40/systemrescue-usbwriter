#!/bin/bash

# Determine the path to the git repository
fullpath="$(realpath $0)"
curdir="$(dirname ${fullpath})"
repodir="$(realpath ${curdir}/..)"
echo "fullpath=${fullpath}"
echo "repodir=${repodir}"

# Build the docker image
dockerimg="sysrescueusbwriter:latest"
docker build -t ${dockerimg} -f ${repodir}/docker/Dockerfile-build-usbwriter ${repodir}/docker
