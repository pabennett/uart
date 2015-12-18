"""
fpga_unit_tests.py
The tests contained in this script are designed to test the UART loopback
example when it is programmed on to an FPGA. To run the tests you must first
have programmed an FPGA board with the loopback example and connected a serial
cable to your PC. The PORT setting in this file, which defaults to 'COM4', must
be edited to match the port address assigned to the FPGA board. These tests
check the default configuration of 115200 BAUD.
"""
import serial
import random
import unittest
import time
from serial.tools import list_ports

print(list(list_ports.comports()))


class TestSerial(unittest.TestCase):

    def setUp(self):
        self.ser = serial.Serial(
            # Update this to match the device port for the FPGA board
            port='COM4',
            baudrate=115200,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
        )
        self.assertTrue(self.ser.isOpen())
        if self.ser.inWaiting() > 0:
            self.ser.read(self.ser.inWaiting())

    def tearDown(self):
        self.ser.close()

    def test_single_byte(self):
        """
        Send bytes 0-255 to the UART individually and ensure that they are
        returned.
        """
        for i in range(256):
            print('Checking byte: ' + hex(i) + ' '*50, end='')
            self.ser.write([i])
            time.sleep(0.1)
            self.assertEqual(self.ser.inWaiting(), 1)
            self.assertEqual(int(self.ser.read()[0]), i)
            print('\r', end='')
        print('')

    def test_random_byte_sequences(self):
        """
        This test transmits 20 blocks of 2**16 random bytes to the UART and
        checks that the data is correctly returned. If data is not returned by
        the device or the data is incorrect this test will fail.
        """
        burst_size = 2**16
        num_bursts = 20
        for burstId in range(num_bursts):
            print(
                "Transferring block {0} of {1} (block size: {2})".format(
                    burstId+1,
                    num_bursts,
                    burst_size
                )
            )
            data_in = [random.randint(0, 2**8-1) for i in range(burst_size)]
            self.ser.write(data_in)
            self.ser.flush()
            retries = 2
            while True:
                time.sleep(0.2)
                bytes_waiting = self.ser.inWaiting()
                print(bytes_waiting, burst_size)
                if bytes_waiting < burst_size:
                    if retries > 0:
                        retries -= 1
                    else:
                        self.fail("Did not get data in time")
                else:
                    break
            data_out = self.ser.read(self.ser.inWaiting())
            data_out = [int(x) for x in data_out]
            self.assertListEqual(data_out, data_in)


if __name__ == '__main__':
    unittest.main()
