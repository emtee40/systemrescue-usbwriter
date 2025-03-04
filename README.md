# SystemRescue USB writer

Tool to write [SystemRescue](https://system-rescue.org) to a USB memory stick.

It is packaged as AppImage so it can directly run on most Linux systems.

### Download AppImage

Get the latest release build from https://gitlab.com/systemrescue/systemrescue-usbwriter/-/releases/

### Signatures and Verification

All official releases of the AppImages are digitally signed to allow checking the authenticity.
These signatures are made with GnuPG using the same key as SystemRescue itself. 
See [here](https://www.system-rescue.org/Download/) for the key and how to verify.

To sign an AppImage yourself use the `sign.sh` script.

### Running

- `chmod 755 sysrescueusbwriter-x86_64.AppImage`
- `./sysrescueusbwriter-x86_64.AppImage [OPTIONS] <ISO-FILE>`

### Options

```
-t|--targetdev=<DEVICE-PATH>   Device file of the USB media you want to write to.
                               Something like /dev/sdb.
                               A text UI to select a likely device is shown if missing.
                               
-i|--verify-only=<DEVICE-PATH> Don't write out the image, but just compare the current
                               content on the given device to the image.
                               Can't be used together with -t|--targetdev.

-e|--tmpdir=<TMPDIR>           Use the given directory for storing temporary files.
                               You need enough space there for unpacking the whole
                               iso image. Defaults to the TMPDIR environment variable.

-g|--grant=<TOOL>              <TOOL> being one of: sudo, pkexec, su
                               Use the given tool to grant permissions for accessing the
                               target device node. By default all 3 tools are tried.

-c|--cli                       Do not use the ncurses text UI, only command line

--appimage-extract             Unpack the AppImage. Overrides other parameters.

--appimage-mount               Mounts the AppImage to a path in TMPDIR, prints out the path.
                               Unmounts when terminated with Ctrl+C. Overrides other parameters.

-l|--licenses                  Show licenses of all programs packaged in the AppImage.
                               Use 'e' to view a file and 'q' to quit.
                               Showing the licenses overrides other parameters.

-h|--help                      Show this help. Overrides other parameters.

-V|--version                   Show the version number of sysrescueusbwriter.
                               Overrides other parameters.

```

### Access rights

When running as non-root user, you usually need to gain write access to the target device.

sysrescueusbwriter checks if permissions are lacking and then tries `sudo`, `pkexec` and `su`
(in this order) to change the access rights. One of these programs has to be installed, be in $PATH and 
configured for automatic rights acquisition to work. 

Automatic rights acquisition works by chowning the file to the current user ($EUID). Since device
handles are usually created dynamically by udev, the handle owner is reset when the device is
disconnected or the system rebooted.

The alternative is that the user/admin grants access rights through alternative means before 
running sysrescueusbwriter.

### Requirements and Limitations

All AppImages need `libfuse.so.2`, `fusermount` and glibc to run. On some systems these are not installed by default
and might need to be installed manually:

| Distribution                  | Install command                                                                  |
| ----------------------------- |----------------------------------------------------------------------------------|
| Alpine Linux                  | `doas apk add gcompat fuse doas-sudo-shim; doas modprobe fuse` <sup>*)</sup>     |
| Arch Linux                    | `sudo pacman -S fuse2`                                                           |
| CentOS 7                      | `sudo yum install fuse-libs`                                                     |
| NixOS                         | `nix-env -iA nixos.appimage-run`                                                 |
|                               | Then run: `appimage-run sysrescueusbwriter-x86_64.AppImage ...`                   |
| Ubuntu 22.04 and newer        | `sudo apt install libfuse2`                                                      |

<sup>*)</sup> Requires the "community" repository to be enabled in `/etc/apk/repositories`

AppImage upstream is working on reducing these dependencies, see [#877](https://github.com/AppImage/AppImageKit/issues/877).

Viewing the embedded license files requires `less` to be in the $PATH.

### Version compatibility

To successfully create bootable USB media, SystemRescue USB writer must use the exact same version of syslinux that was
used to build SystemRescue. Also SystemRescue USB writer must be adapted to the directory layout used by SystemRescue.
That means one version of SystemRescue USB writer is just compatible with a limited set of SystemRescue versions.

| SystemRescue version   | SystemRescue USB writer version                                                  |
| ---------------------- |----------------------------------------------------------------------------------|
| 7.00 - 9.04            | compatibility likely, not tested                                                 |
| 9.05 - 10.02           | compatible with version 1.0.0 - 1.0.2                                            |
| >= 11.00               | compatible with version 1.0.3                                                    |

SystemRescue USB writer is able to automatically check compatibility and will print an error message if it is not compatible
with a given iso image.

Since i686 architecture releases of SystemRescue are deprecated, SystemRescue USB writer was only developed for 
the x86_64 architecture.

### Screenshots

| [<img src="./images/screenshot1.png" alt="Screenshot1" width="400"/>](./images/screenshot1.png) | [<img src="./images/screenshot2.png" alt="Screenshot2" width="400"/>](./images/screenshot2.png) |

### Building without docker

- Arch Linux on x86_64 required to build the AppImage
- Download `appimagetool-x86_64.AppImage` from https://github.com/AppImage/AppImageKit/releases
- call `build.sh`
- The build script will notify you of missing packages required for building

### Building with docker or podman

If you are not running Arch Linux or if your system does not have all the
required packages installed, you can run the build process in a docker
container. You need to have a Linux system running with docker installed
and configured. You can use the helper scripts provided in the `docker`
folder in this repository.

First you must run the script which builds a new docker image based on Arch Linux,
and then you must run the wrapper script which uses the new docker image to run the
usbwriter build process inside docker. The wrapper script will pass the arguments it
receives to the main `build.sh` script.

In other words, you need to run the following two scripts:
```
./docker/build-docker-image.sh
./docker/build-usbwriter.sh
```

These scripts call the `docker` command from your `$PATH` by default. But you can use the `DOCKER_CMD`
environment variable to override that. This allows you for example to use podman instead of docker:
`DOCKER_CMD=podman ./docker/build-docker-image.sh`.

### Package sources

During the build process (see above) appimagetool copies and packs the required binaries from the build
environment. These binaries are taken from Arch Linux as packaged by them. If you want to build
these packages from source, read the [Arch Build System Documentation](https://wiki.archlinux.org/title/Arch_Build_System)
first.

Download the desired PKGBUILD file from https://github.com/archlinux/svntogit-packages
Make sure to use the correct branch and version. If you want to rebuild a package as used in a
specific version of sysrescueusbwriter, use the package version that was current at the time
sysrescueusbwriter was build (see the `--version` option).

When you have the correct PKGBUILD file, run `makepkg` to build. By default this will automatically 
download the required source files from the upstream project. Alternatively Arch Linux publishes 
these sources at `https://archive.archlinux.org/repos/<date>/sources/`. Use the date corresponding 
to the date of the PKGBUILD you are using.

### Licensing

The SystemRescue USB writer scripts (and helper scripts) themselves are licensed `GPL-3.0-or-later`.

The AppImage contains separate programs and libraries that are licensed under their own licenses.
The license texts are contained in the AppImage below the path `./usr/share/licenses/`. To view the licenses
either call the AppImage with the `--licenses` parameter or unpack it.

