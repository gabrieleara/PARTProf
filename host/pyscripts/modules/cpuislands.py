#!/usr/bin/env python3

import sys

def cpu_range_append_comma(list, cpu):
    list.append(cpu)
    return list

def cpu_range_append_dash(list, cpu):
    if len(list) < 1:
        cur_cpu = 0
    else:
        cur_cpu = list[-1] + 1

    while cur_cpu <= cpu:
        list.append(cur_cpu)
        cur_cpu = cur_cpu+1

    return list

def cpu_range_to_list(c):
    list = []

    delimiters = {
        ',': cpu_range_append_comma,
        '-': cpu_range_append_dash,
    }

    c_copy = c

    cur_delimiter = ','
    next_delimiter = ''
    while len(c):
        cpu = -1
        for d in delimiters:
            try:
                split = c.split(d, maxsplit=1)

                if len(split) < 1:
                    cur_delimiter=''
                    break

                cpu = int(split[0])
                next_delimiter = d

                if len(split) > 1:
                    c = split[1]
                else:
                    c = ''

                break
            except ValueError:
                continue

        if cpu < 0:
            sys.exit("The given list '" + str(c_copy) + "' is invalid!")

        list = delimiters[cur_delimiter](list, cpu)
        cur_delimiter = next_delimiter

    if cur_delimiter == '-':
        sys.exit("The given list '" + str(c_copy) + "' is invalid!")

    return list

def island_cpus_map(islands, cpu_ranges):
    if len(islands) != len(cpu_ranges):
        sys.exit("The list of islands has a different length"
                 " than the list of cpu ranges!")

    map = {}
    for i, c in zip(islands, cpu_ranges):
        map[i] = cpu_range_to_list(c)

    return map

def policy_island_map(islands, policies):
    if len(islands) != len(policies):
        sys.exit("The list of islands has a different length"
                 " than the list of policies!")

    map = {}
    for i, p in zip(islands, policies):
        map[p] = i

    return map
