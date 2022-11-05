# SystemRescue USB writer

Tool to write SystemRescue to a USB memory stick.

It is packaged as AppImage so it can directly run on most Linux systems.

### Status

Currently only very basic copy is done, many checks and safeties are still missing.

!!! Use with care and don't blame me if you accidently overwrite some important partition !!!

### Building

- Arch Linux on x86_64 required to build the AppImage
- Some packages must be installed, exact list TBD
- Download `appimagetool-x86_64.AppImage` from https://github.com/AppImage/AppImageKit/releases
- call `build.sh`

### Running

- `chmod 755 sysrescueusbwriter-x86_64.AppImage`
- `./sysrescueusbwriter-x86_64.AppImage <iso-image> <target-device>`

### Limitations

All AppImages need `libfuse.so.2` to run. On some systems it is not installed by default.
For example on CentOS 7 you need `sudo yum install fuse-libs`. On Ubuntu 22.04 you need 
`sudo apt install libfuse2`.

Also you need glibc for it to work. This seems to be problematic on NixOS and Alpine Linux.

AppImage upstream is working on improving this, see [#877](https://github.com/AppImage/AppImageKit/issues/877).
