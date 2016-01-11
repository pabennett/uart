"""
uart_unit_tests provides a suite of tests for checking the behaviour of the
uart in the loopback configuration. Additional tests can be added to the
load_tests function below to expand the test suite. The generate_test function,
which is located in the uart_test_bases module, will instance and configure a
unit test which it will then add to the supplied test suite. The generate_test
function can configure the baud rate of the uart, the clock frequencies used
by the local and remote receivers, the data to be transferred and the phase
offset of the local and remote receivers.
"""
import random
import unittest
import itertools
import os
import sys
import inspect

local_root = os.path.realpath(
    os.path.abspath(
        os.path.join(os.path.split(inspect.getfile(
            inspect.currentframe()))[0], '.'
        )
    )
)
# Add the directory of this script to the Python path to allow relative/local
# imports. (This allows us to import the uart_test_bases module for example).
if local_root not in sys.path:
    sys.path.insert(0, local_root)

from uart_test_bases import generate_test


def generate_random_data_tests(
    suite,
    loader,
    baud_rates,
    n=2000,
    local_clock=100e6,
    remote_clock=100e6,
    test_name=None,
    doc=None,
):
    """
    Test the provided baud rates using N random bytes.
    """
    for baud in baud_rates:
        # Test all standard baud rates using a local and remote receiver clock
        # of 100MHz and a data stream of 2000 random bytes.
        generate_test(
            suite, loader, baud=baud, local_clock_frequency=local_clock,
            remote_clock_frequency=remote_clock,
            values=[random.randint(0, 2**8-1) for i in range(n)],
            test_name="random_data_{0}_baud_{1}mhz_&_{2}mhz_clocks".format(
                baud,
                int(local_clock/1e6),
                int(remote_clock/1e6),
            ) if test_name is None else test_name,
            test_docstring=(
                (
                    "Check UART with a {0}MHz local clock and a {1}MHz " +
                    "remote clock using a {2} baud rate with {3} " +
                    "random bytes."
                ).format(
                    int(local_clock/1e6), int(remote_clock/1e6), baud, n
                ) if doc is None else doc
            ),
        )


def generate_static_data_tests(
    suite,
    loader,
    baud_rates,
    data=0x00,
    n=250,
    clock=100e6
):
    """
    Test the provided baud rates with N static bytes.
    """
    for baud in baud_rates:
        # Test all standard baud rates using a local and remote receiver clock
        # of 100MHz and a data stream of 2000 random bytes.
        generate_test(
            suite, loader, baud=baud, values=[data for i in range(n)],
            test_name="static_data_{0}_uart_{1}_baud_{2}mhz_clock".format(
                hex(data),
                baud,
                int(clock/1e6)
            ),
            test_docstring=(
                (
                    "Check UART with a {0}MHz clock " +
                    "using a {1} baud rate with {2} static bytes ({3})."
                ).format(int(clock/1e6), baud, n, hex(data))
            ),
        )


def load_tests(loader, standard_tests, pattern):
    """
    The load_tests function overloads the testloader used in the Python Unit
    Test framework and allows us to define how the tests are generated and
    loaded. This method is automatically called by the ChipTools unit test
    loader.
    """
    suite = unittest.TestSuite()
    fast_bauds = [115200, 230400, 460800, 921600]
    slow_bauds = [4800, 9600, 19200, 38400]
    clocks = [100e6, 32e6, 125e6]
    # Test random data sequences across all baud rates
    generate_random_data_tests(suite, loader, fast_bauds, n=2000)
    generate_random_data_tests(suite, loader, slow_bauds, n=20)
    # Test static data sequences across common baud rates
    generate_static_data_tests(suite, loader, [921600], data=0x00, n=250)
    generate_static_data_tests(suite, loader, [921600], data=0x55, n=250)
    generate_static_data_tests(suite, loader, [921600], data=0xAA, n=250)
    generate_static_data_tests(suite, loader, [921600], data=0xFF, n=250)
    generate_static_data_tests(suite, loader, slow_bauds, data=0x00, n=1)
    generate_static_data_tests(suite, loader, slow_bauds, data=0x55, n=1)
    generate_static_data_tests(suite, loader, slow_bauds, data=0xAA, n=1)
    generate_static_data_tests(suite, loader, slow_bauds, data=0xFF, n=1)
    # Test all combinations of local/remote receiver clocks from the list
    # of clock frequencies:
    for clock_pair in itertools.combinations(clocks, 2):
        generate_random_data_tests(
            suite, loader, [115200], local_clock=clock_pair[0],
            remote_clock=clock_pair[1]
        )

    # Spot tests for unusual configurations
    # Test situation where the RX and TX counters dividers are a power of 2.
    generate_random_data_tests(
        suite, loader, [115200], local_clock=117.9648e6,
        remote_clock=117.9648e6,
        test_name="power_of_2_divisor_baud_115200_random_data",
        doc="Check UART when the RX and TX dividers are a power of 2"
    )

    return suite

# This script can be run directly to test the load_tests method for runtime
# errors.
if __name__ == '__main__':
    test_loader = unittest.TestLoader()
    load_tests(test_loader, None, None)
