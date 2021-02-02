#ifdef STATS_H
#error "Cannot include this file multiple times in the same project"
#else
#define STATS_H
#endif

#ifdef __INTELLISENSE__
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>

#define STATS_ARRAY_MAX 10000000

int stats_go_ahead = 1;

// TODO: Wrap around and such
static long long unsigned int stats_array[STATS_ARRAY_MAX];
static long long unsigned int stats_array_c;

void dump(int signum __attribute((unused)), siginfo_t *info __attribute((unused)), void *ptr __attribute((unused)))
{
    stats_go_ahead = 0;
}

void init_sigkill_action()
{
    struct sigaction int_action;

    memset(&int_action, 0, sizeof(int_action));

    int_action.sa_sigaction = dump;
    int_action.sa_flags = SA_SIGINFO;

    sigaction(SIGINT, &int_action, NULL);
    sigaction(SIGTERM, &int_action, NULL);
    sigaction(SIGQUIT, &int_action, NULL);
}

long long unsigned int time_diff_nsec(const struct timespec *t1, const struct timespec *t2)
{
    struct timespec sub;

    //printf("t1:\t %ld \t %ld \n", t1->tv_sec, t1->tv_nsec);
    //printf("t2:\t %ld \t %ld \n", t2->tv_sec, t2->tv_nsec);

    sub.tv_sec = t1->tv_sec - t2->tv_sec;
    sub.tv_nsec = t1->tv_nsec - t2->tv_nsec;

    if (sub.tv_nsec < 0)
    {
        sub.tv_sec -= 1;
        sub.tv_nsec += 1e9;
    }

    //printf("sub:\t %ld \t %ld \n", sub.tv_sec, sub.tv_nsec);

    return (long long unsigned int)(sub.tv_sec) * 1e9 + sub.tv_nsec;
}

void print_current_stat()
{
    static int first_time = 1;
    static struct timespec t_old;
    struct timespec t_new;

    if (first_time)
    {
        first_time = 0;
        clock_gettime(CLOCK_MONOTONIC, &t_old);
        return;
    }

    clock_gettime(CLOCK_MONOTONIC, &t_new);

    printf("%lld\n", time_diff_nsec(&t_new, &t_old));
    fflush(stdout);

    // This is a waste of time, but t_new is not directly assigned to t_old
    // to prevent counting the time spent in computing clocks statistics
    clock_gettime(CLOCK_MONOTONIC, &t_old);
}

void print_stat()
{
    for (long long unsigned int i = 0; i < stats_array_c; ++i)
        printf("%lld\n", stats_array[i]);
}

void store_stat()
{
    static int first_time = 1;
    static struct timespec t_old;
    struct timespec t_new;

    clock_gettime(CLOCK_MONOTONIC, &t_new);

    if (first_time)
    {
        first_time = 0;
        stats_array_c = 0;
        t_old = t_new;
        return;
    }

    stats_array[stats_array_c++] = time_diff_nsec(&t_new, &t_old);
    // Use this if the program is interested in the time elapsed between
    // one stored stat and the next one, regardless on the time needed to store
    // the computation
    t_old = t_new;

    if (stats_array_c == STATS_ARRAY_MAX)
    {
        printf("ERROR: Maximum array size reached, early print/quit\n");
        print_stat();
        exit(-1);
    }

    // This is a waste of time, but t_new is not directly assigned to t_old
    // to prevent counting the time spent in computing clocks statistics
    //clock_gettime(CLOCK_MONOTONIC, &t_old);
}