#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt

from modules import cmdargs
from modules import tabletools
from modules import tempmodelmulticore as tpfit

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

cmdargs_conf = {
    "options": [
        {
            'short': None,
            'long': 'db_file',
            'opts': {
                'metavar': 'db-file',
                'type': cmdargs.argparse.FileType('r'),
            },
        },
        {
            'short': '-o',
            'long': '--out-file',
            'opts': {
                'help': 'The output file basename (+path), hence without extension',
                'type': str,
                'default': 'out',
            },
        },
    ],
    'required_options': [ ],
    'defaults': { }
}

# +--------------------------------------------------------+
# |                   Plotting Functions                   |
# +--------------------------------------------------------+

# Assumptions:
# - 4 cores
# - all cores are equal

SEED = 19940913
RNG = np.random.default_rng(seed=SEED)
print()
print()
print()
print()
print('RNG STATE:\t', np.random.get_state())
print()
print()
print()
print()

def sample_runs(megadb, num_sample_runs):
    runs = megadb.index.get_level_values('runid').max()+1
    ids = np.sort(
        RNG.choice(runs, size=num_sample_runs, replace=True, shuffle=False)
    )
    print(ids)
    return megadb.query('runid in @ids')


def main():
    args = cmdargs.parse_args(cmdargs_conf)

    print('modelfit: creating db')
    megadb = tabletools.pd_read_csv(args.db_file)
    megadb = megadb.set_index(['runid', 'type', 'time'])

    NUM_SAMPLE_RUNS = 500
    print('modelfit: sampling')
    sampledb = sample_runs(megadb, NUM_SAMPLE_RUNS)

    THE_MODEL = tpfit.tempmodel_ode

    SKIP_FIT        = False
    FIT_ASYMPTOTE   = True

    print('modelfit: fitting')
    params = tpfit.fit_temp_multirun(sampledb, THE_MODEL,
        skip_fit=SKIP_FIT,
        fit_asymptote=FIT_ASYMPTOTE,
        )

    CPU_NUM = 4
    PRINT   = True

    if PRINT:
        print('modelfit: plotting comparisons')
        runids   = tpfit.db_get_runids(sampledb)
        runtypes = tpfit.db_get_runtypes(sampledb)

        for runid in runids:
            for runtype in runtypes:
                selection   = tpfit.db_select_run(sampledb, runid, runtype)
                t           = tpfit.db_get_t(selection)
                inputs      = tpfit.db_get_inputs(selection, CPU_NUM)
                data        = tpfit.db_get_data(selection, CPU_NUM)

                model = THE_MODEL(params, t, inputs)

                for i in range(CPU_NUM):
                    plt.plot(t, data[i, :],  label='Y-%d' % i)
                    plt.plot(t, model[i, :], label='M-%d' % i)

                plt.legend()
                plt.show()
                plt.clf()

    return 0
#-- main

if __name__ == "__main__":
    main()
