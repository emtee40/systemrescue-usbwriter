# SystemRescue USB writer

Tool to write SystemRescue to a USB memory stick.

It is packaged as AppImage so it can directly run on most Linux systems.

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
                               
--appimage-extract             Unpack the AppImage. Overrides other parameters.

--appimage-mount               Mounts the AppImage to a path in TMPDIR, prints out the path.
                               Unmounts when terminated with Ctrl+C. Overrides other parameters.

-l|--licenses                  Show licenses of all programs packaged in the AppImage.
                               Use 'e' to view a file and 'q' to quit.
                               Showing the licenses overrides other parameters.

-h|--help                      Show this help. Overrides other parameters.

```

### Access rights

When running as non-root user, you usually need to gain write access to the target device.

sysrescueusbwriter checks if permissions are lacking and then tries `sudo`, `pkexec` and `su`
(in this order) to change the access rights. One of these programs has to be installed and 
configured for automatic rights acquisition to work. 

Automatic rights acquisition works by chowning the file to the current user ($EUID). Since device
handles are usually created dynamically by udev, the handle owner is reset when the device is
disconnected or the system rebooted.

The alternative is that the user/admin grants access rights through alternative means before 
running sysrescueusbwriter.

### Requirements and Limitations

All AppImages need `libfuse.so.2` to run. On some systems it is not installed by default.
For example on CentOS 7 you need `sudo yum install fuse-libs`. On Ubuntu 22.04 you need 
`sudo apt install libfuse2`.

Also you need glibc for it to work. This seems to require changes on NixOS and Alpine Linux.

AppImage upstream is working on improving this, see [#877](https://github.com/AppImage/AppImageKit/issues/877).

Viewing the embedded license files requires `less` to be in the $PATH.

### Licensing

The SystemRescue USB writer scripts (and helper scripts) themselves are licensed `GPL-3.0-or-later`.

The AppImage contains separate programs and libraries that are licensed under their own licenses.
The license texts are contained in the AppImage below the path `./usr/share/licenses/`. To view the licenses
either call the AppImage with the `--licenses` parameter or unpack it.
