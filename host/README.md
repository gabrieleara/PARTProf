# PARTProf Host Component

This component can run either on the embedded platform or on a more powerful
device (usually referred to as the host device). The objective of this software
suite is to provide tools that automate the analysis of the data produced by the
[Embedded Component](../embedded).

The content of this component is structured as follows:
```
host/
├── base.makefile
├── build.sh
├── cmaps
│   ├── odroid_xu4.cmap
│   └── ...
├── gen_deps.sh
├── post-build.sh
├── pyscripts
│   ├── collapse.py
│   ├── collect_samples.py
│   ├── collect_stats.py
│   ├── describe_all_errors.py
│   ├── errors.py
│   ├── fit.py
│   ├── perf_csv_to_csv.py
│   ├── plot
│   │   ├── plotall.sh
│   │   └── plot_time.py
│   ├── plotallcombinations.py
│   ├── plotstuff.py
│   ├── prepare_tables.py
│   ├── raw_csv_to_stats.py
│   ├── raw_to_csv.py
│   ├── simtable.py
│   ├── simulate.py
│   └── TODO
└── README.md
```

## Installing dependencies

This component relies heavily on Python 3 and has some Python dependencies. You
can use any tool you want to install them.

On Debian-based distributions you can use `apt` and `pip3`:
```sh
sudo apt update &&
    sudo apt install -y python3-pip &&
    pip3 install pandas
```

Or if you prefer to keep your installation in an environment you can use `conda`
or even the Docker image that is used to develop this project. For Visual Studio
Code users, open the [root project directory](..) and just accept when asked if
you want to open the folder in a Dev Container environment. Otherwise, you can
pull the Docker image from Dockerhub: the image is called
`gabrieleara/dev_environment:python` and once pulled from the Hub you can run it
and mount the project directory in it to have all dependencies satisfied.

For more information about the image, check [this page on
GitHub](https://github.com/gabrieleara/dev_environment/tree/python/python).

## Running an automated analysis on data produced by the embedded component

This component uses GNU Make to automate the analysis of data collected on
target embedded devices. The `build.sh` script analyzes the content of a
directory given as input and creates a list commands that should be run to
produce the final result: a set of files that can later be used to simulate the
behavior of the profiled apps on the target platform under different
configurations. It does so by creating a temporary Makefile and invoking `make`
on it. This means that if you apply some changes to only a subset of files only
the necessary operations will be re-performed and that commands can be easily
parallelized using the classical `make` capabilities.

In general, this script has two input arguments and an output argument, which
indicates where the final output file shall be produced. Note that all
intermediary files will be created directly in the input directory and all its
subfolders. Out-of-source build is not supported.

Supposing your terminal current directory is the project root folder, you can
run the automated analysis tool like this:
```sh
./host/build.sh -c ./host/cmaps/odroid-xu4.cmap -C ./data/results/odroid-xu4
```

The `-c` option specifies a *column map file* used by the automated tool. This
is needed because for different platforms input files could slightly differ from
one another and this file should specify which input values should be used to
automate the build process.

While the project contains already a bunch of `.cmap` files for platforms used
to develop PARTProf, you can write your own to adapt the framework to a
different embedded device. [This section](#how-cmap-files-work) contains a
comprehensive guide of all the options available in a `.cmap` file.

The `-C` option behaves in the exact same way as the namesake option in GNU
Make, hence it specifies the input directory where the automated analysis tool
should work. Similarly, you can use the `-j` option to automatically parallelize
the execution of the analysis tools.

> **Note**: The `-C` option assumes that the provided directory structure has
> been produced by the embedded component. Check out [the "Output Data"
> section](../embedded/README.md#output-data) in the description of the embedded
> component to see how it should be structured and notice that the input
> directory of this command is not the base `data` directory, but a directory
> associated with a specific board. You can always iterate between multiple
> boards, if needed, by issuing this command multiple times if needed (providing
> each time the appropriate `.cmap` file).

## Steps in the automated processing of input data

> **TODO**: work in progress

This section describes each step taken by the automated analysis tool and how to
customize its behavior if needed. Each step is illustrated in order of
occurrence during a typical run of the analysis tool.

### Converting power data from key-value `.txt` files to `.csv` tables

First of all, input files in the provided directory structure have to be
converted from the `.txt` formats described in [the "Output Data"
section](../embedded/README.md#output-data) of the embedde component description
to a more manageable format.

> **NOTE**: This is the step that uses the `.cmap` file provided as input.

The script that takes care of this step is the `raw_to_csv.py` script. It takes
as input a `measure_power.txt` file and produces a `raw_measure_power.csv` file
in the same directory.

Output files contain all sampled values as columns, where each row represents a
step in the sampling loop (so all values on the same row are sampled roughly at
the same time).

The time interval between each row is specified in a special column, called
`UPDATE_PERIOD_[unit]`, where `[unit]` is a time unit (usually `us` for
miscroseconds). The column only contains one value stored in a single row,
separated from the sampled values.

There is also another special column called `breakpoint`, which indicates at
which point in time the experiment switched from the *active phase* (in which
the profiled workload is running) to the *cooldown phase* (in which no workload
is running, waiting for the next loop). Data is sampled in both phases to gather
information about the thermal evolution of the system over time. Similarly to
the update time column, this column also contains one single value in a special
row that separates the value before and after the *breakpoint*.

> **NOTE**: This is probably the most computationally expensive step, even if
> it's a simple file conversion. I use Python just beacause it's easier to
> write, but the implementation of this step is not efficient at all. In the
> future, this step might be implemented in C/C++ for the sake of speed, but
> since speed is a non-functional requirement for an offline analysis tool this
> step will have to wait.

### Converting time data from input `.txt` files to `.csv` tables

The embedded tools profiles the execution time of all workloads under evaluation
by repeatedly running them in a loop. In each step, an outer program measures
the elapsed time between the activation of each task and its end. Also, during
the execution, `perf` is used to collect data from performance counters in the
CPU. The resulting file is kind of a blend of all the values collected by these
two programs, which makes it difficult to analyze in post process.

This step converts the input `measure_time.txt` file (which is sort of a CSV
file format, but produced by the mentioned programs) to a `raw_measure_time.csv`
file, which is easier to process.

> **NOTE**: This is step also uses the `.cmap` file provided as input.

While the file produced as input contains also a blend of values collected
during the experiment in (mostly) equidistant time intervals and some values
related to the time needed by the task to run, these values are not intended to
be analyzed in a time-progression (only overall stats are interesting from our
point-of-view), so it's fine.

## How `.cmap` files work

**TODO**: write it down
