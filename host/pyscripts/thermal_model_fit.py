#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt

# mpl.use('pgf')
# plt.style.use('seaborn')
plt.rcParams.update({
    "font.family": "serif",  # use serif/main font for text elements
    # "text.usetex": True,     # use inline math for ticks
    "pgf.rcfonts": False     # don't setup fonts from rc parameters
    })
plt.rcParams["axes.axisbelow"] = False


from modules import cmdargs
from modules import tabletools
from modules import tempmodelmulticore as tpfit

# +--------------------- PARAMETERS ---------------------+ #

SEED            = 19940913
NUM_SAMPLE_RUNS = 500
TASK            = 'gzip'
FREQ            = 1900000000
MODEL           = tpfit.tempmodel_ode
METHOD          = 'leastsq' # 'differential_evolution' #
SKIP_FIT        = False
FIT_ASYMPTOTE   = False
CPU_NUM         = 4
PLOT            = True

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

RNG = np.random.default_rng(seed=SEED)

def sample_runs(db, num_sample_runs):
    runs = db.index.get_level_values('runid').max()+1
    ids = np.sort(
        RNG.choice(runs, size=num_sample_runs, replace=True, shuffle=False)
    )
    print(ids)
    return db.query('runid in @ids')

def sample_runs_per_tf(db, task, frequency):
    db = db[db['task'] == task]
    db = db[db['freq'] == frequency]

    # TODO: using only the ones in which the cpu0 is higher, so basically using
    # only one run
    db = db.query('power_cpu0 > power_cpu1')
    return db

def main():
    args = cmdargs.parse_args(cmdargs_conf)

    print('modelfit: creating db')
    megadb = tabletools.pd_read_csv(args.db_file)
    megadb = megadb.set_index(['runid', 'type', 'time'])

    print('modelfit: sampling')
    if TASK and FREQ:
        sampledb = sample_runs_per_tf(megadb, TASK, FREQ)
    else:
        sampledb = sample_runs(megadb, NUM_SAMPLE_RUNS)

    print('modelfit: fitting')
    params = tpfit.fit_temp_multirun(sampledb, MODEL,
        skip_fit=SKIP_FIT,
        fit_asymptote=FIT_ASYMPTOTE,
        )

    if PLOT:
        print('modelfit: plotting comparisons')
        runids   = tpfit.db_get_runids(sampledb)
        runtypes = tpfit.db_get_runtypes(sampledb)

        for runid in runids:
            for runtype in runtypes:
                if runtype == 'cooldown':
                    continue
                selection   = tpfit.db_select_run(sampledb, runid, runtype)
                t           = tpfit.db_get_t(selection)
                inputs      = tpfit.db_get_inputs(selection, CPU_NUM)
                data        = tpfit.db_get_data(selection, CPU_NUM)

                task        = selection['task'].to_numpy()[0]
                freq        = selection['freq'].to_numpy()[0]
                i_p         = np.argmax(inputs['P'])

                print('Plotting ', runid, task, freq, i_p)

                model = MODEL(params, t, inputs)

                fig = plt.figure()
                ax = fig.gca()

                linewidth_base = 1.2

                for i in range(CPU_NUM):
                    ax.plot(t, data[i, :],  label='Measured CPU %d' % i)
                for i in range(CPU_NUM):
                    ax.plot(t - 0.5, model[i, :], label='Simulated CPU %d' % i)
                legend = plt.legend(
                    # title='CPU Temperature',
                    loc='lower right',
                    fancybox=False,
                    edgecolor='black',
                    bbox_to_anchor=(0.975, 0.05),
                    ncol=2,
                    columnspacing=1,
                    labelspacing=0.35,
                )

                frame = legend.get_frame()
                frame.set_linewidth(linewidth_base)

                plt.xlabel('Time [ s ]', fontsize=12, labelpad=10)
                plt.ylabel('Core Temperature [ °C ]', fontsize=12, labelpad=10)

                plt.xlim(0, 32)
                plt.ylim(35.1, 57)
                plt.grid()

                for axis in ['top', 'bottom', 'left', 'right']:
                    ax.spines[axis].set_linewidth(1.5 * linewidth_base)

                plt.tick_params(
                    direction='in',
                    length=8,
                    width=1.4 * linewidth_base,
                    grid_color='black',
                    left=True,
                    right=True,
                    bottom=True,
                    zorder=1,
                    top=True,
                    grid_alpha=.2,
                    grid_linewidth=.5 * linewidth_base)

                # plt.tight_layout()

                plt.savefig("graph.pdf",
                    #This is simple recomendation for publication plots
                    dpi=1000,
                    # Plot will be occupy a maximum of available space
                    bbox_inches='tight',
                    )

                # plt.show()

                plt.clf()

    return 0
#-- main

if __name__ == "__main__":
    main()
