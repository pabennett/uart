-------------------------------------------------------------------------------
-- UART
-- Simple loopback
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loopback is
    port (  
        clock   :   in std_logic;
        reset   :   in std_logic;    
        rx      :   in std_logic;
        tx      :   out std_logic
    );
end loopback;

architecture rtl of loopback is
    ----------------------------------------------------------------------------
    -- UART constants
    ----------------------------------------------------------------------------
    constant baud_rate              : positive := 115200;
    constant clock_frequency        : positive := 100000000;
    ----------------------------------------------------------------------------
    -- Component declarations
    ----------------------------------------------------------------------------
    component uart is
        generic (
            baud_rate           : positive;
            clock_frequency     : positive
        );
        port (
            clock               :   in      std_logic;
            reset               :   in      std_logic;    
            data_stream_in      :   in      std_logic_vector(7 downto 0);
            data_stream_in_stb  :   in      std_logic;
            data_stream_in_ack  :   out     std_logic;
            data_stream_out     :   out     std_logic_vector(7 downto 0);
            data_stream_out_stb :   out     std_logic;
            data_stream_out_ack :   in      std_logic;
            tx                  :   out     std_logic;
            rx                  :   in      std_logic
        );
    end component uart;
    ----------------------------------------------------------------------------
    -- UART signals
    ----------------------------------------------------------------------------
    signal uart_data_in             : std_logic_vector(7 downto 0);
    signal uart_data_out            : std_logic_vector(7 downto 0);
    signal uart_data_in_stb         : std_logic;
    signal uart_data_in_ack         : std_logic;
    signal uart_data_out_stb        : std_logic;
    signal uart_data_out_ack        : std_logic;
begin

    ----------------------------------------------------------------------------
    -- UART instantiation
    ----------------------------------------------------------------------------
    uart_inst : uart
    generic map (
        baud_rate           => baud_rate,
        clock_frequency     => clock_frequency
    )
    port map    (  
        -- general
        clock               => clock,
        reset               => reset,
        data_stream_in      => uart_data_in,
        data_stream_in_stb  => uart_data_in_stb,
        data_stream_in_ack  => uart_data_in_ack,
        data_stream_out     => uart_data_out,
        data_stream_out_stb => uart_data_out_stb,
        data_stream_out_ack => uart_data_out_ack,
        tx                  => tx,
        rx                  => rx
    );
    ----------------------------------------------------------------------------
    -- Simple loopback, retransmit any received data
    ----------------------------------------------------------------------------
    uart_loopback : process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                uart_data_in_stb        <= '0';
                uart_data_out_ack       <= '0';
                uart_data_in            <= (others => '0');
            else
                -- acknowledge data receive strobes and set up a transmission
                -- request
                uart_data_out_ack       <= '0';
                if uart_data_out_stb = '1' then
                    uart_data_out_ack   <= '1';
                    uart_data_in_stb    <= '1';
                    uart_data_in        <= uart_data_out;
                end if;
                
                -- clear transmission request strobe upon acknowledge.
                if uart_data_in_ack = '1' then
                    uart_data_in_stb    <= '0';
                end if;
            end if;
        end if;
    end process;    
end rtl;