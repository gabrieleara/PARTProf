#ifndef READFILE_H
#define READFILE_H

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

static inline int readfile2(const char *fname, char *buff, size_t size) {
    int fd = open(fname, O_RDONLY);
    if (fd < 0)
        return fd;
    int nread = read(fd, buff, size);
    close(fd);
    return nread;
}

#define UNTIL_INTERRUPTED(call)                                                \
    ({                                                                         \
        int __res;                                                             \
        do {                                                                   \
            __res = call;                                                      \
        } while (__res < 0 && (errno == EINTR));                               \
        __res;                                                                 \
    })

static inline int readfile(const char *fname, char *buff, size_t size) {
    return UNTIL_INTERRUPTED(readfile2(fname, buff, size));
}

#define __READVALUE_BODY(type, converter)                                      \
    ({                                                                         \
        type retval;                                                           \
        char buff[32];                                                         \
        int nread = readfile(fname, buff, sizeof(buff) - 1);                   \
        if (nread <= 0)                                                        \
            retval = 0;                                                        \
        else {                                                                 \
            buff[nread] = '\0';                                                \
            retval = converter(buff);                                          \
        }                                                                      \
        retval;                                                                \
    })

static inline int readint(const char *fname) {
    return __READVALUE_BODY(int, atoi);
}
static inline long readlong(const char *fname) {
    return __READVALUE_BODY(long, atol);
}
static inline double readdouble(const char *fname) {
    return __READVALUE_BODY(double, atof);
}

#endif // READFILE_H
