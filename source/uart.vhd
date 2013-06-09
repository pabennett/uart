--------------------------------------------------------------------------------
-- UART
-- Implements a universal asynchronous receiver transmitter with parameterisable
-- BAUD rate. Tested on a Spartan 6 LX9 connected to a Silicon Labs Cp210
-- USB-UART Bridge.
--
-- @author         Peter A Bennett
-- @copyright      (c) 2012 Peter A Bennett
-- @license        LGPL
-- @email          pab850@googlemail.com
-- @contact        www.bytebash.com
--
-- Extended by
-- @author         Robert Lange
-- @copyright      (c) 2013 Robert Lange
-- @license        LGPL
-- @home           https://github.com/sd2k9/
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- Math/log2,ceil required to get the number of bits for our counter
use ieee.math_real.log2;
use ieee.math_real.ceil;


entity UART is
    Generic (
            -- Baudrate in bps
            -- The baudrate must satisify the following condition:
            -- BAUD_DIVIDER := truncate(CLOCK_FREQUENCY/BAUD_RATE)
            -- remainder(BAUD_DIVIDER/16) == 0
            -- Why: 16 times oversampling on the receiver side
            -- Also take care that the remainder(CLOCK_FREQUENCY/BAUD_RATE) is
            -- small because this determines the UART baud rate error
            -- See constant c_oversample_divider_val for more information
            BAUD_RATE           : positive;
            -- Input Clock frequency in Hz
            CLOCK_FREQUENCY     : positive
        );
    Port (
            -- System Clock
            CLOCK           :   in      std_logic;
            -- High-Active Asynchronous Reset
            RESET               :   in      std_logic;
            -- The input data: 8 bit - this is the UART sender
            -- Provide data on DATA_STREAM_IN and set STB to high
            -- Keep the data stable until ACK is set to high which shows that
            -- the data is copied into the internal buffer. Then you should
            -- revoke STB and you can change IN as you want.
            DATA_STREAM_IN      :   in      std_logic_vector(7 downto 0);
            DATA_STREAM_IN_STB  :   in      std_logic;
            DATA_STREAM_IN_ACK  :   out     std_logic := '0';
            -- The output data: 8 bit - this is the UART receiver
            -- Data is only valid during the time the STB is high
            -- Acknowledge the data with a pulse on ACK, which is confirmed by
            -- revoking STB.
            -- When the following start bit is received the data becomes
            -- invalid and the STB is revoked. So take care about fetching the
            -- data early enough, or install your own FIFO buffer
            DATA_STREAM_OUT     :   out     std_logic_vector(7 downto 0);
            DATA_STREAM_OUT_STB :   out     std_logic;
            DATA_STREAM_OUT_ACK :   in      std_logic;
            TX                  :   out     std_logic;
            RX                  :   in      std_logic  -- Async Receive
         );
end UART;

architecture RTL of UART is
    ----------------------------------------------------------------------------
    -- BAUD Generation
    ----------------------------------------------------------------------------
    -- First create the divider for the 16 times oversampled baud rate,
    -- the baud rate then is derived by dividing by 16.
    -- Thats why the 16 times oversampling clock must be derived without any reminder left
    -- from the baud rate, to not disturb the resulting bit rate
    -- You need to take care about this when selecting baud and clock frequency
    -- Substract one, otherwise the reloading step is counted twice
    constant c_oversample_divider_steps : natural := natural(CLOCK_FREQUENCY / (16*BAUD_RATE))-1;
    -- And also how many bits do we need?
    constant c_oversample_divider_bits : natural := natural(ceil(log2(real(c_oversample_divider_steps))));
    -- And this is the counter type we use
    subtype oversample_baud_counter_type is unsigned(c_oversample_divider_bits-1 downto 0);
    -- Please only use this final value
    constant c_oversample_divider_val : oversample_baud_counter_type  := to_unsigned(c_oversample_divider_steps, c_oversample_divider_bits);
    -- Datatype for the rx and tx counter type, must accomodate for the 8bit positions
    subtype uart_rxtx_count_type is unsigned(2 downto 0);
    constant c_uart_rxtx_count_reset : uart_rxtx_count_type  := "000";  -- Reset value: 0

    signal oversample_baud_counter    : oversample_baud_counter_type := c_oversample_divider_val;
    -- Tick created every counter reset
    signal oversample_baud_tick       : std_ulogic := '0';
    -- At this moment we sample the incoming signal
    signal uart_rx_sample_tick        :   std_ulogic := '0';
    -- The baud rate itself is the oversampling tick divided by 16
    subtype baud_counter_type is unsigned(3 downto 0);
    signal baud_counter  :   baud_counter_type := ( others => '1');
    signal baud_tick     :   std_ulogic := '0';

    ----------------------------------------------------------------------------
    -- Transmitter Signals
    ----------------------------------------------------------------------------
    type    uart_tx_states is ( idle,
                                wait_for_tick,
                                send_start_bit,
                                transmit_data,
                                send_stop_bit);

    signal  uart_tx_state       : uart_tx_states := idle;

    signal  uart_tx_data_block  : std_logic_vector(7 downto 0) := (others => '0');
    signal  uart_tx_data        : std_logic := '1';
    signal  uart_tx_count       : uart_rxtx_count_type := c_uart_rxtx_count_reset; -- 8 states, stored in 3 bits
    signal  uart_rx_data_in_ack : std_logic := '0';
    ----------------------------------------------------------------------------
    -- Receiver Signals
    ----------------------------------------------------------------------------
    type    uart_rx_states is ( rx_wait_start_synchronise  -- Wait and deliver data
                                , rx_get_start_bit  -- We are reading the start bit
                                , rx_get_data
                                , rx_get_stop_bit
                                );

    signal  uart_rx_state       : uart_rx_states := rx_wait_start_synchronise;
    signal  uart_rx_bit         : std_logic := '0';
    signal  uart_rx_data_block  : std_logic_vector(7 downto 0) := (others => '0');
    signal  uart_rx_filter      : unsigned(1 downto 0)  := (others => '0');
    signal  uart_rx_count       : uart_rxtx_count_type := c_uart_rxtx_count_reset; -- 8 states, stored in 3 bits
    signal  uart_rx_data_out_stb: std_ulogic := '0';
    -- Syncing Clock to Receive Data, compared to baud_counter and creates uart_rx_sample_tick
    signal  uart_rx_sync_clock  : baud_counter_type := (others => '0');

    ----------------------------------------------------------------------------
    -- Helper functions
    ----------------------------------------------------------------------------
    pure function shift_right_by_one (        -- Shift right by 1, fill with new bit
      constant shift : in std_logic_vector(7 downto 0);  -- Signal to shift
      constant fill  : in std_ulogic)                    -- New bit 7
      return std_logic_vector is
      variable ret : std_logic_vector(7 downto 0);
    begin  -- function shift_right_by_one
      ret(7) := fill;
      ret(6 downto 0) := shift (7 downto 1);
      return ret;
    end function shift_right_by_one;

    ----------------------------------------------------------------------------
    -- Begin Body
    ----------------------------------------------------------------------------
begin

    ----------------------------------------------------------------------------
    -- Transmitter Part: Sending Data
    ----------------------------------------------------------------------------
    TX                  <= uart_tx_data;

    -- The input clock is CLOCK_FREQUENCY
    -- For example its set to 100Mhz, then needs to be divided down to the
    -- rate dictated by the BAUD_RATE. For example, if 115200 baud is selected
    -- (115200 baud = 115200 bps - 115.2kbps) a tick must be generated once
    -- every 1/115200
    -- As explained above we use a two-step approach, so we just scale down
    -- here the 16-times oversampled RX clock again
    -- Use a down-counter to have a simple test for zero
    -- Thats the counter part
   TX_CLOCK_DIVIDER   : process (CLOCK, RESET)
    begin
      if RESET = '1' then
        baud_counter     <= (others => '1');
      elsif rising_edge (CLOCK) then
              if oversample_baud_tick = '1'  then  -- Use as Clock enable
                if baud_counter = 0 then
                    baud_counter <= (others => '1');
                else
                    baud_counter <= baud_counter - 1;
                end if;
              end if;
      end if;
    end process TX_CLOCK_DIVIDER;
    -- And thats the baud tick, which is of course only one clock long
    -- So both counters should be Zero
    TX_TICK: baud_tick <= '0' when RESET = '1' else
                          '1' when oversample_baud_tick = '1' and baud_counter = 0 else
                          '0';

    -- Get data from DATA_STREAM_IN and send it one bit at a time
    -- upon each BAUD tick. LSB first.
    -- Wait 1 tick, Send Start Bit (0), Send Data 0-7, Send Stop Bit (1)
    UART_SEND_DATA :    process(CLOCK, RESET)
    begin
      if RESET = '1' then
                uart_tx_data            <= '1';
                uart_tx_data_block      <= (others => '0');
                uart_tx_count           <= c_uart_rxtx_count_reset;
                uart_tx_state           <= idle;
                uart_rx_data_in_ack     <= '0';
      elsif rising_edge(CLOCK) then
                uart_rx_data_in_ack     <= '0';
                case uart_tx_state is
                    when idle =>
                        if DATA_STREAM_IN_STB = '1' then
                            uart_tx_data_block  <= DATA_STREAM_IN;
                            uart_rx_data_in_ack <= '1';
                            uart_tx_state       <= wait_for_tick;
                        end if;
                    when wait_for_tick =>
                        if baud_tick = '1' then
                            uart_tx_state   <= send_start_bit;
                        end if;
                    when send_start_bit =>
                        if baud_tick = '1' then
                            uart_tx_data    <= '0';
                            uart_tx_state   <= transmit_data;
                        end if;
                    when transmit_data =>
                        if baud_tick = '1' then
                          -- Send next bit
                          uart_tx_data    <=  uart_tx_data_block(0);
                          -- Shift for next transmit bit, filling with don't care
                          -- Xilinx ISE does not know srl? So just build it ourself, hehe
			  -- uart_tx_data_block <=  uart_tx_data_block srl 1;
                          uart_tx_data_block <= shift_right_by_one(uart_tx_data_block, '-');
                          if uart_tx_count = 7 then  -- binary 111
                            -- We're done, move to next state
                            uart_tx_state   <= send_stop_bit;
                          else
                            -- Stay in current state
                            uart_tx_state   <= transmit_data;
                          end if;
                          -- Always increment here, will go to zero if we're out
                          uart_tx_count   <= uart_tx_count + 1;
                        end if;
                    when send_stop_bit =>
                        if baud_tick = '1' then
                            uart_tx_data <= '1';
                            uart_tx_state <= idle;
                        end if;
                    when others =>
                        uart_tx_data <= '1';
                        uart_tx_state <= idle;
                end case;
      end if;
    end process UART_SEND_DATA;

    ----------------------------------------------------------------------------
    -- Receiver Part: Getting Data
    ----------------------------------------------------------------------------
    DATA_STREAM_IN_ACK  <= uart_rx_data_in_ack;
    DATA_STREAM_OUT     <= uart_rx_data_block;
    DATA_STREAM_OUT_STB <= uart_rx_data_out_stb;

    -- The RX clock divider uses the 16 times oversampled clock, which we
    -- create here from the input clock
    -- Use a down-counter to have a simple test for zero
    -- Thats for the counter and tick creation part
   RX_CLOCK_DIVIDER   : process (CLOCK, RESET)
    begin
      if RESET = '1' then
        oversample_baud_counter     <= c_oversample_divider_val;
        oversample_baud_tick        <= '0';
      elsif rising_edge (CLOCK) then
                if oversample_baud_counter = 0 then
                    oversample_baud_counter <= c_oversample_divider_val;
                    oversample_baud_tick    <= '1';
                else
                    oversample_baud_counter <= oversample_baud_counter - 1;
                    oversample_baud_tick    <= '0';
                end if;
      end if;
    end process RX_CLOCK_DIVIDER;

    -- We create the sample time by syncing the oversampled tick (BAUD * 16)
    -- to the received start bit by comparing then vs. the stored receive sync value
    -- It's only one clock tick active
    RX_SAMPLE: uart_rx_sample_tick <= '0' when RESET = '1' else
                                      '1' when oversample_baud_tick = '1' and uart_rx_sync_clock = baud_counter else
                                      '0';


    -- Synchronise RXD and Filter to suppress spikes with a 2 bit counter
    -- This is done with the 16-times oversampled clock
    -- Take care, every time the receive clock is resynchronized to the next
    -- start bit we can have somewhat of a jump here. But thats no problem
    -- because the jump (in case it occur) is still synchronous. And we save us
    -- another counter :-)
    RXD_SYNC_FILTER  :   process(CLOCK, RESET)
    begin
      if RESET = '1' then
        uart_rx_filter <= (others => '1');
        uart_rx_bit    <= '1';
      elsif rising_edge(CLOCK) then
                if oversample_baud_tick = '1' then
                    -- Filter RXD.
                    if RX = '1' and uart_rx_filter < 3 then
                        uart_rx_filter <= uart_rx_filter + 1;
                    elsif RX = '0' and uart_rx_filter > 0 then
                        uart_rx_filter <= uart_rx_filter - 1;
                    end if;
                    -- Set the RX bit.
                    if uart_rx_filter = 3 then
                        uart_rx_bit <= '1';
                    elsif uart_rx_filter = 0 then
                        uart_rx_bit <= '0';
                    end if;
                end if;
      end if;
    end process RXD_SYNC_FILTER;

    UART_RECEIVE_DATA   : process(CLOCK, RESET)
    begin
      if RESET = '1' then
        uart_rx_state           <= rx_wait_start_synchronise;
        uart_rx_data_block      <= (others => '0');
        uart_rx_count           <= c_uart_rxtx_count_reset;
        uart_rx_data_out_stb    <= '0';
        uart_rx_sync_clock      <=  (others => '0');
      elsif rising_edge(CLOCK) then
                case uart_rx_state is
                    -- Waiting for new data to come
                    when rx_wait_start_synchronise =>
                        -- With normal clock: Take care about the ACK from
                        -- previous received data
                        if DATA_STREAM_OUT_ACK = '1' then
                          -- Revoke strobe
                          uart_rx_data_out_stb    <= '0';
                          -- No need to reset data block, it's anyway overwritten during recive
                          -- uart_rx_data_block      <= (others => '0');
                        end if;
                        -- Only here we need to look for start with the
                        -- oversampled clock rate
                        if oversample_baud_tick = '1' and uart_rx_bit = '0' then
                            -- We are back in business!
                            uart_rx_state <= rx_get_start_bit;
                            -- Resynchronize the receive bit timing with the input signal
                            -- invert the MSB, because we need to skip half of
                            -- the start bit.
                            -- We want to sample in the MIDDLE of the bit, remember?
                            -- This will be used from now on as sample moment
                            uart_rx_sync_clock <=
                                 (not baud_counter(3), baud_counter(2), baud_counter(1), baud_counter(0) );
                        end if;         -- oversample_baud_tick = '1' and uart_rx_bit = '0'
                    when rx_get_start_bit =>
                        -- With normal clock: Take care about the ACK from
                        -- previous received data
                        if DATA_STREAM_OUT_ACK = '1' then
                          -- Revoke strobe
                          uart_rx_data_out_stb    <= '0';
                          -- No need to reset data block, it's anyway overwritten during recive
                          -- uart_rx_data_block      <= (others => '0');
                        end if;
                        if uart_rx_sample_tick = '1' then
                          if  uart_rx_bit = '0' then
                            -- Everything alright, we really got a start bit
                            -- Please continue with data reception
                            uart_rx_state <= rx_get_data;
                            -- This is the last time we can revoke a potentially pending
                            -- receive strobe
                            -- Your fault if you didn't fetched the data until here!
                            uart_rx_data_out_stb    <= '0';
                            -- But at least warn about this
                            -- Not for synthesis:
                            -- pragma translate_off
                            assert uart_rx_data_out_stb = '0'
                              report "Receive Data was not fetched by system! Loosing previous data byte!"
                              severity warning;
                            -- pragma translate_on
                          else
                            -- Oh now! Corrupted Start bit! Now we're in troube
                            -- Best to abort the game and issue an (simulation)
                            -- warning
                            uart_rx_state <= rx_wait_start_synchronise;
                            -- Not for synthesis:
                            -- pragma translate_off
                            report "We got an corrupted start bit! Something is wrong and most likely we will now fail to receive the following data. Trying to reset the receive state machine."
                              severity error;
                            -- pragma translate_on
                          end if;
                        end if;
                    when rx_get_data =>
                        if uart_rx_sample_tick = '1' then
                          -- Receive next bit, shift others one bit down
                          -- We receive lsb first, thus we're filling and shifting from msb direction
                          uart_rx_data_block <= shift_right_by_one(uart_rx_data_block, uart_rx_bit);
                          if uart_rx_count = 7 then  -- binary 111
                            -- We're done, move to next state
                            uart_rx_state <= rx_get_stop_bit;
                          else
                            -- Continue in this state
                            uart_rx_state <= rx_get_data;
                          end if;
                          -- Always increment here, will go to zero if we're out
                          uart_rx_count   <= uart_rx_count + 1;
                        end if;
                    when rx_get_stop_bit =>
                        if uart_rx_sample_tick = '1' then
                            if uart_rx_bit = '1' then
                                -- Everything alright, we really got the closing stop  bit
                                -- Set our strobe: Data is ready!
                                uart_rx_data_out_stb    <= '1';
                            else
                              -- Oh now! Corrupted Stop bit! Now we're in troube
                              -- Best to abort the game and issue an (simulation) warning
                              -- Not for synthesis:
                              -- pragma translate_off
                              report "We got an corrupted stop bit! Something is wrong - throwing away this data byte"
                                severity error;
                              -- pragma translate_on
                            end if;
                            -- Anyway, go to wait for next datablock
                            uart_rx_state <= rx_wait_start_synchronise;
                        end if;
                    when others =>      -- This is an illegal state - start over
                        uart_rx_state   <= rx_wait_start_synchronise;
                end case;
      end if;
    end process UART_RECEIVE_DATA;
end RTL;
