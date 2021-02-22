#ifndef MINIMAL_RT_H
#define MINIMAL_RT_H

#include <time.h>

// Mark the time of the initial period
extern void rt_start_period(struct timespec *at);

// Sleep precisely to the beginning of the next period
extern void rt_next_period(struct timespec *at, long period_us);

// Set scheduling properties of the current process (can be used to set RT priority to task)
extern int rt_sched_setschedprio(const int policy, int priority);

#endif // MINIMAL_RT_H
