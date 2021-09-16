# PARTProf Embedded Component

This component is the one that is supposed to run on the target embedded
platform which shall be profiled.

The content of this component is structured as follows:
```
embedded
├── apps
│   ├── cacheapp
│   │   └── ...
│   ├── forever
│   │   └── ...
│   └── sampler
│       └── ...
├── build.sh
├── CMakeLists.txt
├── confdir
│   └── ...
└── scripts
    ├── old
    │   └── ...
    ├── pmc-load-events.sh
    ├── run.sh
    ├── sweep.sh
    └── util
        └── ...
```

## Installing the profiler on the embedded platform

See the content of the [install](install) directory to find out how to install
PARTProf on an embedded board.

Additionally, the embedded component requires the following dependencies:
 - cmake 3.12.0 or above
 - make/build essentials

Optionally, the profiler needs `libudev-dev` to connect to some external power
meters via USB.

On Debian-based platforms, the embedded component auto-installs its dependencies
on the first run using the `build.sh` script, automatically invoked. You don't
have to install them manually if your board is running a Debian-based
distribution and is connected to the Internet. Otherwise, install `cmake` by
yourself and the `build.sh` script will skip the installation of its
dependencies. Be careful to install `libudev-dev` as well in that case if you
need it.

## Running the profiler on the embedded platform

The two main scripts that are used to run the profiler are `run.sh` and
`sweep.sh`, both residing in the `scripts` directory:
 - the first runs a single experiment from a given configuration for all enabled
   frequencies of each CPU island;
 - the latter is used to iterate through multiple configurations, repeatedly
   invoking the `run.sh` script automatically.

The content of the `util` directory are scripts that are included in these two
scripts and that provide some functions and funcionality used by `run.sh` and
`sweep.sh`.

> **NOTE**: In general, the `sweep.sh` script is the one you want to run! Check
> it out.

### Behavior of a single experiment run

The arguments of the `run.sh` are a list of Bash scripts that are sourced on top
of the default configuration to drive the behavior of the script.

Example:
```sh
./scripts/run.sh conf-file1.sh conf-file2.sh
```

The behavior of the `run.sh` script can be split into phases.

At first, there's the initialization phase, in which the following operations
are performed:
 1. Load functions from scripts in the `util` directory
 2. Load base parameters from `confdir/base/base.sh`
 3. Load the set of tasks to be run from `confdir/tasks/simple.sh`
 4. Load the content of the list of files provided as command line arguments in
    the order they were provided, to overwrite the basic configuration already
    loaded in
 5. Prepare the output filesystem (see [this section](#output-data))
 6. Rebuild application binaries if needed (using cmake)
 7. Generate a bunch of files starting from the configuration of each task using
    random data of a pre-determined size
 8. Lock trip points for the given platform and disable real-time limits

Once this phase is over, the script iterates over all available cpufreq policies
(aka CPU frequency islands) on the platform (skipping disabled ones in
configuration).

For each selected policy (from now on referred to as `policy`), it tries to
select a different one (from now on referred to as `policy_other`), which will
be used to run the script itself or other applications that could interfere with
the experiment, should they run on the same island as `policy`.

Finding a different policy is not always possible, so on some platforms
(example: Raspberry), `policy` and `policy_other` may be the same. In that case,
the script tries to avoid overlapping on the same CPU running tasks with service
tasks if possible.

Once this choice is made, it starts to iterate all (enabled) frequencies on the
`policy`. For each frequency it selects the frequency as the running frequency
for that policy and then iterates the list of tasks provided by the default
configuration or overruled by some user-provided configuration.

For each task in the list, repeat the following operations a configured number
of times:
 1. Copy the appropriate input file in a ramfs
 2. Start the power sampler application on the `policy_other`, redirecting its
    output into files called `measure_power.txt` and `measure_power.txt.err` in
    ramfs (name is configurable)
 3. Start `N` instances of the same task (with `N` configurable and in general
    not more than the number of cores in the given policy), redirecting their
    stderr output to a file in ramfs called `measure_time.txt.$i` (name is
    configurable), where `$i` is the index of the current task among the `N`
    started
 4. Wait a predetermined amount of time
 5. Signal the sampler to print out a "marker" in its output, to separate the
    first phase from the second phase of the run (cooldown)
 6. Kill all tasks
 7. Wait for the same predetermined amount of time for the platform to cool down
 8. Move back data collected data from ramfs to the disk in the appropriate
    directory (see [this section](#output-data))

Tasks are started like this:
 1. Set the core on which it has to run with `taskset`
 2. Start the command used to measure time; normally, this is the binary of the
    `apps/forever` application, which repeatedly restarts the task until
    interrupted; however, if `perf` is also to be used this will start `forever
    perf stat <args>`
 3. Set the priority/niceness of the task using either `nice` or `chrt`
 4. Start the task itself

> **TODO**: Directly skip policies that do not have at least `N` CPUs, with `N`
> the number of tasks to start; this is useful for non-uniform number of CPUs on
> the platform across frequency islands (eg. ARM Dynamiq)

### Iterating multiple run configurations

The `sweep.sh` script is very straightforward: it iterates the number of tasks
to start from 1 up to the maximum number of cores per cpu island present on the
current platform. That is, if a platform has two islands with 4 and 8 cores
respectively, `sweep.sh` runs 8 times the `run.sh` script with 8 times the same
configuration and changing only the number of tasks to start.

As of now, following is the list of parameters provided to `run.sh` to override
its default configuration:
 - `confdir/base/timeperfpower.sh`
 - `confdir/tasks/simple.sh`
 - `confdir/howmany_tasks/${i}.sh` **<== (this is the only file that changes between
   runs, the one which determines the number `N` of tasks to start)**
 - `confdir/freqs-only-in-list.sh`
 - `confdir/policies-only-in-list.sh`
 - all the files given as argument to `sweep.sh`, in order

This way, its default configuration (which differs from the one in `run.sh`) can
be overridden as well. For example, the files `confdir/freqs-only-in-list.sh`
and `confdir/policies-only-in-list.sh` can be edited to match preferences, or
they can be overridden by passing other argument files to `sweep.sh`. Similarly,
the taskset can be changed by passing another configuration file to override
`confdir/tasks/simple.sh`.

## Output data

While not part of this component, the `data` directory that is expected to be in
the root of `PARTProf` is built up on the values collected during runs managed
by this component. That data is the used in the host component as well, which
adds additional directories and files to the structure of the `data` directory
which will not be covered here. See [../host/README.md](../host/README.md) for
more information about that.

The directory structure of the `data` folder expected typically in the root
directory of this project is the following:

```
data
└── results
    └── <board-name>
    |   ├── howmany_<H>
    |   │   └── policy_<P>
    │   │       ├── freq_<F>
    │   │       │   ├── task_<T>
    │   │       │   │   ├── <N>
    │   │       │   │   │   ├── measure_power.txt
    │   │       │   │   │   ├── measure_power.txt.err
    │   │       │   │   │   └── measure_time.txt.<1-H>
    ...
```

> **TODO**: Write down this section

### Power Data Format

> **TODO**: Write down this section

### Time Data Format

> **TODO**: Write down this section

## Apps

> **TODO**: Write down this section
