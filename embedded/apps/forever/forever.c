#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

volatile sig_atomic_t runcount = 0;
volatile sig_atomic_t pid;
volatile sig_atomic_t stop = false;

#define WIFEXITED_SOMEHOW(status) (WIFEXITED((status)) || WIFSIGNALED((status)))

// Assumes that t2 is greater or equal than t1, which is always true for the
// CLOCK_MONOTONIC clock
static inline void time_diff(struct timespec *tdest, const struct timespec *t2,
                             const struct timespec *t1) {

    tdest->tv_sec = t2->tv_sec - t1->tv_sec;
    tdest->tv_nsec = t2->tv_nsec - t1->tv_nsec;

    if (tdest->tv_nsec < 0) {
        tdest->tv_nsec = 1000000000 - tdest->tv_nsec;
        tdest->tv_sec -= 1;
    }
}

static inline void terminate(int signum __attribute((unused)),
                             siginfo_t *info __attribute((unused)),
                             void *ptr __attribute((unused))) {
    // Abruptly terminate child pid if run at least once,
    // otherwise let it finish undisturbed

    // TODO: change maybe so that it always waits for the
    // child to finish and just avoids starting a new one?
    if (pid > 0 && runcount > 0)
        kill(pid, SIGKILL);
    stop = true;
}

static inline void init_sigkill_action() {
    struct sigaction int_action;

    memset(&int_action, 0, sizeof(int_action));

    int_action.sa_sigaction = terminate;
    int_action.sa_flags = SA_SIGINFO;

    sigaction(SIGINT, &int_action, NULL);
    sigaction(SIGTERM, &int_action, NULL);
    sigaction(SIGQUIT, &int_action, NULL);
}

static inline int fork_and_wait(char **args, struct timespec *start,
                                struct timespec *end) {
    int status;

    if (clock_gettime(CLOCK_MONOTONIC, start)) {
        perror("FOREVER: failed clock_gettime");
        return EXIT_FAILURE;
    }

    pid = fork();
    if (pid == 0) {
        // Change program, emulating shell behavior
        if (execvp(args[0], args) == -1)
            perror("FOREVER: Failed exec");

        // Should never get here unless error occurs
        exit(EXIT_FAILURE);
    } else if (pid < 0) {
        // Error forking
        perror("FOREVER: Failed fork");
    } else {
        // Parent process
        bool redo;

        // Wait for child termination
        do {
            redo = false;
            if (waitpid(pid, &status, 0) < 0) {
                status = 0;
                if (errno == ECHILD) {
                    perror("FOREVER: child not existing");
                    return EXIT_FAILURE;
                } else if (errno == EINTR) {
                    redo = true;
                } else {
                    perror("FOREVER: failed waitpid");
                    return EXIT_FAILURE;
                }
            }
        } while (!WIFEXITED_SOMEHOW(status) || redo);

        // If terminated by a signal exit right away
        if (WIFSIGNALED(status)) {
            perror("FOREVER: child signaled");
            return EXIT_FAILURE;
        }

        if (clock_gettime(CLOCK_MONOTONIC, end))
            perror("FOREVER: failed clock_gettime");

        // Return child exit status (if not terminated abruptly by the signal
        // handler
        return WEXITSTATUS(status);
    }

    return EXIT_FAILURE;
}

const char SEP = ',';
const char default_prefix[] = "time ";
const char default_prefix_runcount[] = "runcount ";
const size_t num_separators = 8; // TODO: parse perf arguments and determine how many columns there are

static inline const char *build_prefix_or_default(
    const char *pname, const char *thedefault, const size_t howmany_seps) {
    if (strcmp(pname, "perf") == 0) {
        char *str = calloc(howmany_seps + 1, sizeof(char));
        for (size_t i = 0; i < howmany_seps; ++i) {
            str[i] = SEP;
        }
        return str;
    } else {
        // String is automatically freed by exiting the program
        return thedefault;
    }
}

static inline const char *build_prefix_string(const char* pname) {
    return build_prefix_or_default(pname, default_prefix, num_separators);
}

static inline const char *build_prefix_runcount_string(const char *pname) {
    return build_prefix_or_default(pname, default_prefix_runcount,
        num_separators + 1);
}

int main(int argc, char **argv) {
    int exit_status = EXIT_SUCCESS;
    struct timespec diff = {0};
    struct timespec start = {0};
    struct timespec end = {0};
    const char *prefix = NULL;
    const char *prefix_runcount = NULL;

    if (argc < 2) {
        fprintf(stderr, "ERROR: no program to run provided!");
        exit_status = EXIT_FAILURE;
    }

    prefix = build_prefix_string(argv[1]);
    prefix_runcount = build_prefix_runcount_string(argv[1]);

    init_sigkill_action();

    // TODO: do I need the double newline?

    for (runcount = 0; (runcount < 1 || !stop) && !exit_status; ++runcount) {
        exit_status = fork_and_wait(argv + 1, &start, &end);
        if (!exit_status) {
            time_diff(&diff, &end, &start);
            fprintf(stderr, "\n%s%ld.%09ld\n", prefix, diff.tv_sec,
                diff.tv_nsec);
        }
    }

    if (exit_status)
        --runcount;

    fprintf(stderr, "\n%s%d\n", prefix_runcount, runcount);
    return exit_status;
}
