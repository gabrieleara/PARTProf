# Simple script tools for board management

In the `tools` folder there are some scripts that help can you manage images for
board sd cards/eMMC memories. Typically, sdcard images are maintained in the
`images` folder, which is not under version control.

## `backupsd.sh` **[Deprecated]**

Saves the whole content of a disk path as a compressed binary archive in the
desired output file. This can be simply used to backup sdcards before fomatting
them again for some other use afterwards.

> **NOTE**: This tool is here just for backward compatibility and shall be
> removed soon. The new `sdtools.sh` script can manage both burning and
> backupping sdcards and other kinds of media.

## `imagemanager.sh` **[WIP]**

Downloads images that shall be burned on sdcards, uncompressing them. It
automatically checks whether an image is already present or not and then
proceeds to download it/unpack it only if necessary.

> **NOTE**: This script does not accept any input parameter and must be modified
> to adapt to the image you want to get from the internet.

## `sdtools.sh`

This script supports two operations:
- `backup` backups the content of the provided disk path to a (potentially
    compressed if the `-c` option is used) image file;
- `burn` burns an image file on the provided disk path (uncompressing it if
  enabled with `-c`).

> **NOTE**: For the compression to work, the image to be burn into an sdcard
> must have been previously compressed using the `backup` tool. Otherwise you
> have to uncompress it yourself first.

Examples:
```sh
# To backup a compressed image, with sdX name of the device:
./tools/sdtools.sh backup /dev/sdX \
  -c -o images/backups/imagename.img.xz

# To burn a backupped compressed image, with sdX name of the device:
./tools/sdtools.sh burn /dev/sdX \
  -c -i images/backups/imagename.img.xz
```

For more options and details run
```sh
./tools/sdtools.sh -h
```

> **TODO**: I believe that there is an error in the help command of this file,
> because the compression argument is used both by `backup` and `burn`, but
> listed as an option only for the `backup` command.
