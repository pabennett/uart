-------------------------------------------------------------------------------
-- TB_UART
-- This testbench instantiates two instances of the UART component which are
-- referred to as the 'local' UART and the 'remote' UART. The local UART is
-- given data to send from the input text file 'input.txt' which it then sends
-- to the remote UART. The remote UART is configured in loopback mode so it 
-- will retransmit any data that it receives. The testbench will store any 
-- data received by the local UART into the output file 'output.txt'.
-- Stimulus input and output checking is performed by the external Python
-- unit test 'uart_unit_tests.py', which is designed to work with the ChipTools
-- framework. This testbench allows the clock frequencies of the local and 
-- remote UARTs to be configured separately as well as their phase relationship
-- and baud rates. A full suite of tests covering various configurations is 
-- provided in the unit test suite.
-------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library std;
    use std.textio.all; 

library lib_uart;
    use lib_uart.all;

entity tb_uart is
    generic (
        -- Phase delay between local and remote comms links
        delay_ns            : real := 0.75;
        -- Local and remote baud rates
        baud                : positive := 115200;
        -- Remote clock frequency
        remote_clock_hz     : positive := 100000000;
        -- Local clock frequency
        local_clock_hz      : positive := 100000000
    );
end entity;

architecture beh of tb_uart is
    component uart is
        generic (
            baud                : positive;
            clock_frequency     : positive
        );
        port (  
            -- general
            clock               :   in      std_logic;
            reset               :   in      std_logic;    
            data_stream_in      :   in      std_logic_vector(7 downto 0);
            data_stream_in_stb  :   in      std_logic;
            data_stream_in_ack  :   out     std_logic := '0';
            data_stream_out     :   out     std_logic_vector(7 downto 0);
            data_stream_out_stb :   out     std_logic;
            data_stream_out_ack :   in      std_logic;
            tx                  :   out     std_logic;
            rx                  :   in      std_logic
        );
    end component;
    signal remote_clock         : std_logic := '0';
    signal remote_clock_int     : std_logic := '0';
    signal remote_data          : std_logic_vector(7 downto 0);
    signal remote_data_in_stb   : std_logic;
    signal remote_data_in_ack   : std_logic;
    signal remote_data_out      : std_logic_vector(7 downto 0);
    signal remote_data_out_stb  : std_logic;
    signal remote_data_out_ack  : std_logic;
    signal remote_tx            : std_logic;
    signal remote_rx            : std_logic; 
    signal local_clock          : std_logic := '0';
    signal local_data           : std_logic_vector(7 downto 0);
    signal local_data_in_stb    : std_logic := '0';
    signal local_data_in_ack    : std_logic := '0';
    signal local_data_out       : std_logic_vector(7 downto 0);
    signal local_data_out_stb   : std_logic;
    signal local_data_out_ack   : std_logic;
    signal local_tx             : std_logic;
    signal local_rx             : std_logic; 
begin
    ---------------------------------------------------------------------------
    -- GENERATE LOCAL AND REMOTE CLOCKS
    ---------------------------------------------------------------------------
    local_clock_gen : process(local_clock)
    begin
        local_clock <= not local_clock after (
            (1.0 / real(local_clock_hz)) * real(1e9)
        ) * 1 ns;
    end process;
    remote_clock_gen : process(remote_clock_int)
    begin
        remote_clock_int <= not remote_clock_int after (
            (1.0 / real(remote_clock_hz)) * real(1e9)
        ) * 1 ns;
        remote_clock <= transport remote_clock_int after delay_ns * 1 ns;
    end process;
    ---------------------------------------------------------------------------
    -- READ/WRITE STIMULUS DATA FILES
    ---------------------------------------------------------------------------
    stim_parser : process
        constant input_path     : string := "input.txt";
        constant output_path    : string := "output.txt";
        file     input_file     : text;
        file     output_file    : text;
        variable data_line      : line;
        variable output_line    : line;
        variable status         : file_open_status := status_error;
        variable data           : bit_vector(7 downto 0);
        variable read_ok        : boolean;
        variable first_call     : boolean := true;
    begin
        if status /= open_ok then
            file_open(status, input_file, input_path, read_mode);
            assert (status = open_ok) 
                report "Failed to open " & input_path
                severity failure;
            file_open(status, output_file, output_path, write_mode);
            assert (status = open_ok) 
                report "Failed to open " & output_path
                severity failure;
        end if;

        if local_data_out_stb = '1' then
            write(output_line, to_bitvector(local_data_out));
            writeline(output_file, output_line);
        end if;

        if not endfile(input_file) then
            if local_data_in_stb = '0' or local_data_in_ack = '1' then
                -- Get Data
                readline(input_file, data_line);
                read(data_line, data, read_ok);
                local_data          <= to_stdlogicvector(data);
                local_data_in_stb   <= '1';
            end if;
            wait until rising_edge(local_clock);
        else
            if local_data_in_ack = '1' then
                local_data_in_stb <= '0';
            end if;
            wait until rising_edge(local_clock);
        end if;
    end process;
    ---------------------------------------------------------------------------
    -- REMOTE UART
    ---------------------------------------------------------------------------
    remote_uart : uart
    generic map(
        baud                 => baud,
        clock_frequency     => remote_clock_hz
    )
    port map(
        -- general
        clock               => remote_clock,
        reset               => '0',
        data_stream_in      => remote_data,
        data_stream_in_stb  => remote_data_in_stb,
        data_stream_in_ack  => remote_data_in_ack,
        data_stream_out     => remote_data_out,
        data_stream_out_stb => remote_data_out_stb,
        data_stream_out_ack => remote_data_out_ack,
        tx                  => remote_tx,
        rx                  => remote_rx
    );
    -- Loopback on remote.
    remote_data_out_ack <= remote_data_in_ack;
    remote_data <= remote_data_out;
    remote_data_in_stb <= remote_data_out_stb;
    ---------------------------------------------------------------------------
    -- LOCAL UART
    ---------------------------------------------------------------------------
    local_uart : uart
    generic map(
        baud                => baud,
        clock_frequency     => local_clock_hz
    )
    port map(
        -- general
        clock               => local_clock,
        reset               => '0',
        data_stream_in      => local_data,
        data_stream_in_stb  => local_data_in_stb,
        data_stream_in_ack  => local_data_in_ack,
        data_stream_out     => local_data_out,
        data_stream_out_stb => local_data_out_stb,
        data_stream_out_ack => '1',
        tx                  => local_tx,
        rx                  => local_rx
    );
    -- Connect local and remote UART interfaces
    remote_rx   <= local_tx;
    local_rx    <= remote_tx;
end beh;