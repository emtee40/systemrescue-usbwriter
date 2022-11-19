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
- `./sysrescueusbwriter-x86_64.AppImage [OPTIONS] <ISO-FILE>`

### Options

```
-t|--targetdev=<DEVICE-PATH>   Device file of the USB media you want to write to.
                               Something like /dev/sdb.
                               A text UI to select a likely device is shown if missing.

-e|--tmpdir=<TMPDIR>           Use the given directory for storing temporary files.
                               You need enough space there for unpacking the whole
                               iso image. Defaults to the TMPDIR environment variable.

-l|--licenses                  Show licenses of all programs packaged in the AppImage.
                               Use 'e' to view a file and 'q' to quit.
                               Showing the licenses overrides other parameters.

-h|--help                      Show this help. Overrides other parameters.

```

### Requirements and Limitations

All AppImages need `libfuse.so.2` to run. On some systems it is not installed by default.
For example on CentOS 7 you need `sudo yum install fuse-libs`. On Ubuntu 22.04 you need 
`sudo apt install libfuse2`.

Also you need glibc for it to work. This seems to require changes on NixOS and Alpine Linux.

AppImage upstream is working on improving this, see [#877](https://github.com/AppImage/AppImageKit/issues/877).

Viewing the embedded license files requires `less` to be in the $PATH.

When running as non-root user, you need to gain write access to the target device. sysrescueusbwriter
tries `sudo`, `pkexec` and `su` (in this order) to change the access rights. One of these programs has to
be installed and configured for automatic rights acquisition to work. Otherwise the user has to change
the access rights manually.
