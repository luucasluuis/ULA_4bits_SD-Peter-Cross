library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Debouncer is
  generic (
    CLK_FREQ_HZ : integer := 50_000_000;
    DEBOUNCE_MS : integer := 20;
    ACTIVE_LOW  : boolean := false
  );
  port (
    clk        : in  std_logic;
    button_in  : in  std_logic;   -- raw (bouncing) button
    button_out : out std_logic    -- clean button level
  );
end Debouncer;

architecture rtl of Debouncer is
  -- number of clock cycles the input must remain stable
  constant THRESHOLD : integer := (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

  signal raw       : std_logic;
  signal s1, s2    : std_logic := '0';   -- synchronizer
  signal stable    : std_logic := '0';   -- filtered value
  signal cnt       : integer range 0 to THRESHOLD := 0;
  
begin
  raw <= (not button_in) when ACTIVE_LOW else button_in;

  process(clk)
  begin
    if rising_edge(clk) then
      s1 <= raw;
      s2 <= s1;
      if s2 = stable then
        cnt <= 0;                 -- input agrees with output: restart count
      elsif cnt = THRESHOLD then
        stable <= s2;             -- held long enough: accept new value
        cnt    <= 0;
      else
        cnt <= cnt + 1;           -- input differs: keep counting
      end if;
    end if;
  end process;

  button_out <= stable;
end rtl;