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
        print('Testing single characters...')
        for i in range(256):
            print('Checking byte: ' + hex(i) + ' '*50, end='')
            self.ser.write([i])
            time.sleep(0.1)
            self.assertEqual(self.ser.inWaiting(), 1)
            self.assertEqual(int(self.ser.read()[0]), i)
            print('\r', end='')
        print('')

    def test_static_sequences(self):
        """
        This test transmits 256 blocks of 2**10 bytes using the blockId as the
        static character to send.
        """
        print('Testing character sequences [0x00 0x01 ... 0xFF]...')
        self.burst_test(
            2**10,
            256,
            lambda charId, burstId: burstId
        )

    def test_bit_flips_0xAA_0x55(self):
        """
        This test transmits 20 blocks of 2**16 bits using an alternating byte
        pattern of 0xAA 0x55.
        """
        print('Testing character sequences 0xAA 0x55...')
        self.burst_test(
            2**16,
            20,
            lambda charId, burstId: [0xAA, 0x55][charId % 2]
        )

    def test_bit_flips_0xFF_0x00(self):
        """
        This test transmits 20 blocks of 2**16 bits using an alternating byte
        pattern of 0xFF 0xFF.
        """
        print('Testing character sequences 0xFF 0x00...')
        self.burst_test(
            2**16,
            20,
            lambda charId, burstId: [0xFF, 0x00][charId % 2]
        )

    def test_endianness(self):
        """
        This test transmits 20 blocks of 2**16 bits using an alternating byte
        pattern of 0x81 0x18.
        """
        print('Testing character sequences 0x81 0x18...')
        self.burst_test(
            2**16,
            20,
            lambda charId, burstId: [0x81, 0x18][charId % 2]
        )

    def test_random_byte_sequences(self):
        """
        This test transmits 20 blocks of 2**16 random bytes to the UART and
        checks that the data is correctly returned. If data is not returned by
        the device or the data is incorrect this test will fail.
        """
        print('Testing random character sequences...')
        self.burst_test(
            2**16,
            20,
            lambda charId, burstId: random.randint(0, 2**8-1)
        )

    def burst_test(self, burst_size, num_bursts, data_fn):
        """
        This test transmits 20 blocks of 2**16 random bytes to the UART and
        checks that the data is correctly returned. If data is not returned by
        the device or the data is incorrect this test will fail.
        """
        for burstId in range(num_bursts):
            print(
                "Transferring block {0} of {1} (block size: {2})".format(
                    burstId+1,
                    num_bursts,
                    burst_size
                ) + ''*50,
                end=''
            )
            data_in = [data_fn(i, burstId) for i in range(burst_size)]
            self.ser.write(data_in)
            self.ser.flush()
            retries = 2
            while True:
                time.sleep(0.2)
                bytes_waiting = self.ser.inWaiting()
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
            print('\r', end='')
        print('')

if __name__ == '__main__':
    unittest.main()
