import random
import os
import re
from chiptools.testing.testloader import ChipToolsTest
import traceback

base = os.path.dirname(__file__)


class UartTestBase(ChipToolsTest):
    duration = 0
    generics = {}
    entity = 'tb_uart'
    library = 'lib_tb_uart'
    project = os.path.join(base, '..', 'uart.xml')

    def setUp(self):
        """Place any code that is required to prepare simulator inputs in this
        method."""
        # Set the paths for the input and output files using the
        # 'simulation_root' attribute as the working directory
        self.input_path = os.path.join(self.simulation_root, 'input.txt')
        self.output_path = os.path.join(self.simulation_root, 'output.txt')

    def check_output(self, path, values):
        output_values = []
        with open(path, 'r') as f:
            data = f.readlines()
        for valueIdx, value in enumerate(data):
            # testbench response
            output_values.append(int(value, 2))  # Binary to integer

        # Compare the expected result to what the Testbench returned:
        self.assertListEqual(output_values, values)

    def tearDown(self):
        # Remove files generated by the test
        os.remove(self.input_path)
        os.remove(self.output_path)

    def write_stimulus(self, path, values):
        # Write the values to the testbench input file
        with open(path, 'w') as f:
            for value in values:
                f.write('{0}\n'.format(bin(value)[2:].zfill(8)))

    def run_and_check(
        self, values, baud, local_clock, remote_clock, delay_ns
    ):
        """Prepare the simulation environment and run the simulation."""
        self.generics = {
            'baud': int(baud),
            'remote_clock_hz': int(remote_clock),
            'local_clock_hz': int(local_clock),
        }
        # Write the stimulus file to be used by the testbench
        self.write_stimulus(self.input_path, values)
        # Run the simulation
        return_code, stdout, stderr = self.simulate()
        self.assertEqual(return_code, 0)
        # Check output
        self.check_output(self.output_path, values)
        self.assertIsNone(re.search('.*Error:.*', stdout))

    def generic_random_data_test(
        self,
        n,
        baud=115200,
        local_clock=100e6,
        remote_clock=100e6,
        delay_ns=0
    ):
        self.run_and_check(
            values=[random.randint(0, 2**8-1) for i in range(n)],
            baud=baud,
            local_clock=local_clock,
            remote_clock=remote_clock,
            delay_ns=delay_ns
        )

    def generic_static_data_test(
        self,
        n,
        data,
        baud=115200,
        local_clock=100e6,
        remote_clock=100e6,
        delay_ns=0
    ):
        self.run_and_check(
            values=[data for i in range(n)],
            baud=baud,
            local_clock=local_clock,
            remote_clock=remote_clock,
            delay_ns=delay_ns
        )


class UartRandomDataTests(UartTestBase):

    def test_random_data_115200baud(self):
        """Check UART with a 115200 baud rate with 2000 random bytes."""
        self.generic_random_data_test(2000)

    def test_random_data_230400baud(self):
        """Check UART with a 230400 baud rate with 2000 random bytes."""
        self.generic_random_data_test(2000, baud=230400)

    def test_random_data_460800baud(self):
        """Check UART with a 460800 baud rate with 2000 random bytes."""
        self.generic_random_data_test(2000, baud=460800)

    def test_random_data_921600baud(self):
        """Check UART with a 921600 baud rate with 2000 random bytes."""
        self.generic_random_data_test(2000, baud=921600)

    def test_random_data_4800baud(self):
        """Check UART with a 4800 baud rate with 20 random bytes."""
        self.generic_random_data_test(20, baud=4800)

    def test_random_data_9600baud(self):
        """Check UART with a 9600 baud rate with 20 random bytes."""
        self.generic_random_data_test(20, baud=9600)

    def test_random_data_19200baud(self):
        """Check UART with a 19200 baud rate with 20 random bytes."""
        self.generic_random_data_test(20, baud=19200)

    def test_random_data_38400baud(self):
        """Check UART with a 38400 baud rate with 20 random bytes."""
        self.generic_random_data_test(20, baud=38400)

    def test_random_data_115200_baud_60MHz_local_32MHz_remote(self):
        """Check UART with a 60MHz local clock and a 32MHz remote clock."""
        self.generic_random_data_test(
            2500,
            baud=115200,
            local_clock=60e6,
            remote_clock=32e6
        )

    def test_random_data_115200_baud_100MHz_local_125MHz_remote(self):
        """Check UART with a 100MHz local clock and a 125MHz remote clock."""
        self.generic_random_data_test(
            2500,
            baud=115200,
            local_clock=100e6,
            remote_clock=125e6
        )

    def test_random_data_115200_baud_32MHz_local_125MHz_remote(self):
        """Check UART with a 32MHz local clock and a 125MHz remote clock."""
        self.generic_random_data_test(
            2500,
            baud=115200,
            local_clock=32e6,
            remote_clock=125e6
        )

    def test_random_data_115200_baud_100MHz_local_32MHz_remote(self):
        """Check UART with a 100MHz local clock and a 32MHz remote clock."""
        self.generic_random_data_test(
            2500,
            baud=115200,
            local_clock=100e6,
            remote_clock=32e6
        )

    def test_power_of_2_divisor_baud_115200_random_data(self):
        """Check UART when the RX and TX dividers are a power of 2"""
        self.generic_random_data_test(
            2500,
            baud=115200,
            local_clock=117.9648e6,
            remote_clock=117.9648e6
        )


class UartStaticDataTests(UartTestBase):

    def test_static_0x00_data_921600_baud(self):
        """Check UART with a 921600 baud rate with 250 0x00 bytes"""
        self.generic_static_data_test(250, data=0x00, baud=921600)

    def test_static_0x55_data_921600_baud(self):
        """Check UART with a 921600 baud rate with 250 0x55 bytes"""
        self.generic_static_data_test(250, data=0x55, baud=921600)

    def test_static_0xAA_data_921600_baud(self):
        """Check UART with a 921600 baud rate with 250 0xAA bytes"""
        self.generic_static_data_test(250, data=0xAA, baud=921600)

    def test_static_0xFF_data_921600_baud(self):
        """Check UART with a 921600 baud rate with 250 0xFF bytes"""
        self.generic_static_data_test(250, data=0xFF, baud=921600)

    def test_static_0xFF_data_4800_baud(self):
        """Check UART with a 4800 baud rate with 1 0xFF byte"""
        self.generic_static_data_test(1, data=0xFF, baud=4800)

    def test_static_0xFF_data_9600_baud(self):
        """Check UART with a 9600 baud rate with 1 0xFF byte"""
        self.generic_static_data_test(1, data=0xFF, baud=9600)

    def test_static_0xFF_data_19200_baud(self):
        """Check UART with a 19200 baud rate with 1 0xFF byte"""
        self.generic_static_data_test(1, data=0xFF, baud=19200)

    def test_static_0xFF_data_38400_baud(self):
        """Check UART with a 38400 baud rate with 1 0xFF byte"""
        self.generic_static_data_test(1, data=0xFF, baud=38400)

    def test_static_0xAA_data_4800_baud(self):
        """Check UART with a 4800 baud rate with 1 0xAA byte"""
        self.generic_static_data_test(1, data=0xAA, baud=4800)

    def test_static_0xAA_data_9600_baud(self):
        """Check UART with a 9600 baud rate with 1 0xAA byte"""
        self.generic_static_data_test(1, data=0xAA, baud=9600)

    def test_static_0xAA_data_19200_baud(self):
        """Check UART with a 19200 baud rate with 1 0xAA byte"""
        self.generic_static_data_test(1, data=0xAA, baud=19200)

    def test_static_0xAA_data_38400_baud(self):
        """Check UART with a 38400 baud rate with 1 0xAA byte"""
        self.generic_static_data_test(1, data=0xAA, baud=38400)
