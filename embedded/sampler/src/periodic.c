#include <sched.h>
#include <unistd.h>

#include "periodic.h"
#include "time_utils.h"

// Mark the time of the initial period
void rt_start_period(struct timespec *at)
{
    clock_gettime(CLOCK_MONOTONIC, at);
}

// Sleep precisely to the beginning of the next period
void rt_next_period(struct timespec *at, long period_us)
{
    time_add_us(at, period_us);

    while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, at, NULL) != 0)
    {
    }
}

// Set scheduling properties of the current process (can be used to set RT priority to task)
int rt_sched_setschedprio(const int policy, int priority) {
    // Cap the values
    const int maxprio = sched_get_priority_max(policy);
    const int minprio = sched_get_priority_min(policy);

    if (priority > maxprio)
        priority = maxprio;
    if (priority < minprio)
        priority = minprio;

    struct sched_param param = { 0 };
    param.sched_priority = priority;

    return sched_setscheduler(getpid(), policy, &param);
}
