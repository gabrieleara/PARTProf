#!/usr/bin/env python3

"""
This module contains a support function that simplifies using the argparse
module.

It provides a single function which accepts a map containing the argparse
configuration.
"""

import argparse

# -------------------------------------------------------- #
#                         Classes                          #
# -------------------------------------------------------- #

class CustomFormatter(
    argparse.ArgumentDefaultsHelpFormatter,
    argparse.RawDescriptionHelpFormatter):
    """
    This class is a formatter for argparse. It is the default formatter when using the parse_args function.
    """
    pass

# -------------------------------------------------------- #
#                        Functions                         #
# -------------------------------------------------------- #

def parse_args(config, formatter_class=CustomFormatter, *args, **kwargs):
    """
    Parse command line arguments.

    The only mandatory argument `config` should be a map structured as follows:
    {
        'options': [
            {
                'short': <str or None>,
                'long': <str>
                'opts': {
                    # list of arguments to be passed to argparse
                }
            },
            # other options ...
        ],

        'required_options': [
            # same as the contents of 'options', but all these options become
            # required ...
        ],

        'defaults': {
            # list of key-value pairs for default values of certain variables
        }
    }

    In addition, other arguments can be provided to customize argparse behavior,
    they will be forwarded to argparse.ArgumentParser constructor.
    """

    # Set default empty values to non-provided attributes
    config.setdefault('options', [])
    config.setdefault('required_options', [])
    config.setdefault('defaults', {})

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=formatter_class,
        *args,
        **kwargs,
    )

    for o in config['options']:
        if o['short']:
            parser.add_argument(o['short'], o['long'], **o['opts'])
        else:
            parser.add_argument(o['long'], **o['opts'])

    required_group = parser.add_argument_group('required named arguments')
    for o in config['required_options']:
        if o['short']:
            required_group.add_argument(o['short'], o['long'], required=True, **o['opts'])
        else:
            required_group.add_argument(o['long'], required=True, **o['opts'])

    parser.set_defaults(**config['defaults'])

    return parser.parse_args()
#-- parse_cmdline_args
