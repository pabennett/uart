--------------------------------------------------------------------------------
-- UART
-- Simple loopback
--           
-- @author         Peter A Bennett
-- @copyright      (c) 2012 Peter A Bennett
-- @license        LGPL      
-- @email          pab850@googlemail.com
-- @contact        www.bytebash.com
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LOOPBACK is
    port 
    (  
        -- General
        CLOCK                   :   in      std_logic;
        RESET                   :   in      std_logic;    
        RX                      :   in      std_logic;
        TX                      :   out     std_logic;
        LED_TX                  :   out     std_logic;
        LED_RX                  :   out     std_logic;
        LED_HEARTBEAT           :   out     std_logic
    );
end LOOPBACK;

architecture RTL of LOOPBACK is
    ----------------------------------------------------------------------------
    -- UART constants
    ----------------------------------------------------------------------------
    
    constant BAUD_RATE              : positive := 9600;
    constant CLOCK_FREQUENCY        : positive := 100000000;
    
    ----------------------------------------------------------------------------
    -- Component declarations
    ----------------------------------------------------------------------------
    component UART is
        generic (
                BAUD_RATE           : positive;
                CLOCK_FREQUENCY     : positive
            );
        port (  -- General
                CLOCK               :   in      std_logic;
                RESET               :   in      std_logic;    
                DATA_STREAM_IN      :   in      std_logic_vector(7 downto 0);
                DATA_STREAM_IN_STB  :   in      std_logic;
                DATA_STREAM_IN_ACK  :   out     std_logic;
                DATA_STREAM_OUT     :   out     std_logic_vector(7 downto 0);
                DATA_STREAM_OUT_STB :   out     std_logic;
                DATA_STREAM_OUT_ACK :   in      std_logic;
                TX                  :   out     std_logic;
                RX                  :   in      std_logic
             );
    end component UART;
    
    ----------------------------------------------------------------------------
    -- UART signals
    ----------------------------------------------------------------------------
    
    signal uart_data_in             : std_logic_vector(7 downto 0);
    signal uart_data_out            : std_logic_vector(7 downto 0);
    signal uart_data_in_stb         : std_logic;
    signal uart_data_in_ack         : std_logic;
    signal uart_data_out_stb        : std_logic;
    signal uart_data_out_ack        : std_logic;
    
    signal led_tx_bit               : std_logic;
    signal led_rx_bit               : std_logic;
    signal led_tx_count             : unsigned(22 downto 0);
    signal led_rx_count             : unsigned(22 downto 0);
    signal led_hb_count             : unsigned(22 downto 0);
    
    signal led_hb                   : std_logic;
  
begin

    ----------------------------------------------------------------------------
    -- UART instantiation
    ----------------------------------------------------------------------------

    UART_inst1 : UART
    generic map (
            BAUD_RATE           => BAUD_RATE,
            CLOCK_FREQUENCY     => CLOCK_FREQUENCY
    )
    port map    (  
            -- General
            CLOCK               => CLOCK,
            RESET               => RESET,
            DATA_STREAM_IN      => uart_data_in,
            DATA_STREAM_IN_STB  => uart_data_in_stb,
            DATA_STREAM_IN_ACK  => uart_data_in_ack,
            DATA_STREAM_OUT     => uart_data_out,
            DATA_STREAM_OUT_STB => uart_data_out_stb,
            DATA_STREAM_OUT_ACK => uart_data_out_ack,
            TX                  => TX,
            RX                  => RX
    );
    
    ----------------------------------------------------------------------------
    -- Simple loopback, retransmit any received data
    ----------------------------------------------------------------------------
    
    UART_LOOPBACK : process (CLOCK)
    begin
        if rising_edge(CLOCK) then
            if RESET = '1' then
                uart_data_in_stb        <= '0';
                uart_data_out_ack       <= '0';
                uart_data_in            <= (others => '0');
            else
                -- Acknowledge data receive strobes and set up a transmission
                -- request
                uart_data_out_ack       <= '0';
                if uart_data_out_stb = '1' then
                    uart_data_out_ack   <= '1';
                    uart_data_in_stb    <= '1';
                    uart_data_in        <= uart_data_out;
                end if;
                
                -- Clear transmission request strobe upon acknowledge.
                if uart_data_in_ack = '1' then
                    uart_data_in_stb    <= '0';
                end if;
            end if;
        end if;
    end process;
    
    LED_TX  <= led_tx_bit;
    LED_RX  <= led_rx_bit;
    LED_HEARTBEAT <= led_hb;
    
    TX_LED  : process (CLOCK)
    begin
        if rising_edge(CLOCK) then
            if RESET = '1' then
                led_tx_bit <= '1';
                led_tx_count <= (others => '1');
            else
                if uart_data_in_ack = '1' then
                    led_tx_count <= (others => '1');
                end if;
                
                if led_tx_count > 0 then
                    led_tx_bit <= '1';
                    led_tx_count <= led_tx_count - 1;
                else
                    led_tx_bit <= '0';
                end if;
            end if;
        end if;
    end process;
    
    RX_LED  : process (CLOCK)
    begin
        if rising_edge(CLOCK) then
            if RESET = '1' then
                led_rx_bit <= '1';
                led_rx_count <= (others => '1');
            else
                if uart_data_out_ack = '1' then
                    led_rx_count <= (others => '1');
                end if;
                
                if led_rx_count > 0 then
                    led_rx_bit <= '1';
                    led_rx_count <= led_rx_count - 1;
                else
                    led_rx_bit <= '0';
                end if;
            end if;
        end if;
    end process;  
    
    HEARTBEAT  : process (CLOCK)
    begin
        if rising_edge(CLOCK) then
            if RESET = '1' then
                led_hb <= '1';
                led_hb_count <= (others => '1');
            else                
                led_hb_count <= led_hb_count - 1;
                if led_hb_count = 0 then
                    led_hb <= not led_hb;
                end if;
            end if;
        end if;
    end process; 
            
end RTL;
