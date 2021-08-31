# Installation scripts in the `install` folder

The scripts included in the `install` directory help you install the necessary
software on embedded boards and similar, maintaining a consistent state between
the version of source files on your host machine and the ones on the remote one.

> **NOTE**: In general, changes made on the embedded device are overwritten by
> the install scripts with the content of the files present on the host machine,
> so please be careful when overwriting data on embedded devices. You can check
> which files would be overwritten using the "dry-run" options of the
> installation scripts.

## `odroid-kernel-update.bash` **[Deprecated]**

This script can be used to update the kernel image on the ODROID-XU3/XU4 boards.
This is no longer maintained and it may or may not work. If you need to do
something similar, check out its content, it's fairly easy to understand.

## `install-dep.sh`

In its current version, this script is used only to install `rsync` on the
embedded platform **if needed.
**
> **NOTE**: This is done automatically by the `install.sh` script if you use the
> appropriate option, so you should never touch or run this file manually. Its
> content is pretty straightforward anyway.

## `install.sh`

This script can be used to install source files from this project on the given
destination path. The path can be local or it can be a path on a remote host. In
that case, the `--ssh` option shall be used, with only the hostname (or the
username followed by the hostname) shall be given as argument.

Esample:
```sh
./install/install.sh --install-deps \
    --ssh user@hostname /path/on/remote/host
```

For more usage and options run
```sh
./install/install.sh -h
```
