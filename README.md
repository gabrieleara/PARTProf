# PARTProf - Power Aware Real-Time Profiler for Embedded Platforms

This document describes all the tools and methodologies included in this bundle.

## Project Structure

Structure of the project, including untracked but useful dirs that are typically
used with it:

```
PARTProf
├── build         [untracked]
│   ├── embedded  [untracked]
│   └── host      [untracked]
├── data          [untracked]
│   └── ...
├── embedded
│   ├── ...
├── host
│   ├── ...
├── images        [untracked]
│   └── backups   [untracked]
├── install
└── tools
```

Description:
- `build`: contains the output of executables built for some of the tools of
  this project; all the tools used in this project are open source, so this
  directory is expected to contain all executables built from those sources
  automatically. It is usually divided in multiple directories, called
  `embedded` and `host`, just like the two major components of this project.

- `data`: this untracked folder is where all data managed by this project should
  be; we don't share the dataset bundled with the tool (for now), but data
  inside that folder is expected to follow a specific structure that is
  explained in [README-DATA-MANAGEMENT.md](README-DATA-MANAGEMENT.md).

- `embedded`: contains all source code for tools to be used on the embedded
  platform; see [embedded/README.md](embedded/README.md) for more details.

- `host`: contains all source code for tools to be used on the host platform;
  see [host/README.md](host/README.md) for more details.

- `images`: contains images and backup images of disks to be used on embedded
  devices (sdcards, eMMC memories, etc.); see [tools/README.md](tools/README.md)
  for more details.

- `install`: contains scripts that are used to install dependencies and maintain
  a consistent state of source files between host and embedded devices; see
  [install/README.md](install/README.md) for more details.

- `tools`: contains scripts that are used to manage sdcards, eMMC memories,
  etc.; see [tools/README.md](tools/README.md) for more details.

## Installing

The project consists on a lot of Bash scripts, C/C++ source files and Python
scripts.

Typically, no action is requied to use the components of the project on the
destination system: all files that shall be compiled are re-compiled (when
necessary) before being used directly from the sources. This is true both for
the `host` and the `embedded` components.

However, some dependencies may need to be installed. Please refer to each
component that you intend to use for its dependencies.
