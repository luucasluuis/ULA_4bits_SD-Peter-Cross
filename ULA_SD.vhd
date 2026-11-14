library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ULA_SD is
    generic (
        CLK_FREQ_HZ    : integer := 50_000_000;  -- board clock
        DEBOUNCE_MS    : integer := 20;          -- debounce time
        BTN_ACTIVE_LOW : boolean := false        -- set true if button is active low
    );
    port (
        input      : in  STD_LOGIC_VECTOR(3 downto 0); -- switches
        clk        : in  STD_LOGIC;
        button     : in  STD_LOGIC;                    -- confirms each input
        reset      : in  STD_LOGIC;

        Cout       : out STD_LOGIC;
        Overflow   : out STD_LOGIC;
        Zero       : out STD_LOGIC;
        Negative   : out STD_LOGIC;
        output     : out STD_LOGIC_VECTOR(3 downto 0)
    );
end ULA_SD;

architecture Behavioral of ULA_SD is
    component Debouncer
        generic (
            CLK_FREQ_HZ : integer;
            DEBOUNCE_MS : integer;
            ACTIVE_LOW  : boolean
        );
        port (
            clk        : in  STD_LOGIC;
            button_in  : in  STD_LOGIC;
            button_out : out STD_LOGIC
        );
    end component;

    -- states used to know what the switches currently represent
    type state_t is (S_OP, S_A, S_B);
    signal state : state_t := S_OP;

    -- registers that keep the operation and both operands
    signal input1_reg, input2_reg, operation_reg :
        STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    -- goes high for one clock when A and B are ready
    signal input_ready : STD_LOGIC := '0';

    -- button signals
    signal debounced_button : STD_LOGIC := '0';
    signal btn_prev         : STD_LOGIC := '0';
    signal btn_edge         : STD_LOGIC;

    -- reset synchronizer
    signal reset_s1, reset_s2 : STD_LOGIC := '0';
    signal rst                : STD_LOGIC;

begin
    -- clean the button signal before using it in the FSM
    c0 : Debouncer
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            ACTIVE_LOW  => BTN_ACTIVE_LOW
        )
        port map (
            clk        => clk,
            button_in  => button,
            button_out => debounced_button
        );

    -- creates a one-clock pulse when the button is pressed
    btn_edge <= debounced_button and not btn_prev;

    -- Synchronize reset with the clock
    process(clk)
    begin
        if rising_edge(clk) then
            reset_s1 <= reset;
            reset_s2 <= reset_s1;
        end if;
    end process;

    rst <= reset_s2;

    -- first operation, then A, then B
    process(clk)
    begin
        if rising_edge(clk) then
            btn_prev    <= debounced_button;
            input_ready <= '0';

            if rst = '1' then
                state         <= S_OP;
                input1_reg    <= (others => '0');
                input2_reg    <= (others => '0');
                operation_reg <= (others => '0');
            else
                case state is
                    -- save the operation code
                    when S_OP =>
                        if btn_edge = '1' then
                            operation_reg <= input;
                            state         <= S_A;
                        end if;
                    -- save operand A
                    when S_A =>
                        if btn_edge = '1' then
                            input1_reg <= input;
                            state      <= S_B;
                        end if;
                    -- save operand B and tell the ALU to calculate
                    when S_B =>
                        if btn_edge = '1' then
                            input2_reg  <= input;
                            input_ready <= '1';
                            state       <= S_OP;
                        end if;
                end case;
            end if;
        end if;
    end process;

    process(clk)
        -- extra bit is useful for arithmetic operations
        variable result      : SIGNED(4 downto 0);
        variable u_sum       : UNSIGNED(4 downto 0);
        variable output_temp : STD_LOGIC_VECTOR(3 downto 0);
        variable a_s, r_s    : SIGNED(3 downto 0);
        
        -- used because 1111 means "true" in comparisons,
        -- not a negative number
        variable is_cmp      : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                output   <= (others => '0');
                Cout     <= '0';
                Overflow <= '0';
                Zero     <= '0';
                Negative <= '0';
            elsif input_ready = '1' then
                is_cmp := false;
                case operation_reg is
                    -- A + B
                    when "0000" =>
                        result :=
                            resize(SIGNED(input1_reg), 5)
                            +
                            resize(SIGNED(input2_reg), 5);

                        -- separate unsigned sum used only to get carry out
                        u_sum :=
                            ('0' & UNSIGNED(input1_reg))
                            +
                            ('0' & UNSIGNED(input2_reg));
                        output_temp :=
                            STD_LOGIC_VECTOR(result(3 downto 0));
                        Cout <= u_sum(4);

                        -- overflow when two equal-sign numbers
                        -- produce a result with the opposite sign
                        Overflow <=
                            (input1_reg(3) xor result(3))
                            and
                            not (input1_reg(3) xor input2_reg(3));

                    -- A - B
                    when "0001" =>
                        result :=
                            resize(SIGNED(input1_reg), 5)
                            -
                            resize(SIGNED(input2_reg), 5);
                        output_temp :=
                            STD_LOGIC_VECTOR(result(3 downto 0));

                        -- Cout is used as borrow for subtraction
                        if UNSIGNED(input1_reg) < UNSIGNED(input2_reg) then
                            Cout <= '1';
                        else
                            Cout <= '0';
                        end if;
                        Overflow <=
                            (input1_reg(3) xor result(3))
                            and
                            (input1_reg(3) xor input2_reg(3));

                    -- Bitwise OR
                    when "0010" =>
                        output_temp := input1_reg or input2_reg;
                        Cout     <= '0';
                        Overflow <= '0';

                    -- Bitwise AND
                    when "0011" =>
                        output_temp := input1_reg and input2_reg;
                        Cout     <= '0';
                        Overflow <= '0';

                    -- A + 1
                    -- B is still entered because of the FSM, but it is ignored here
                    when "0100" =>
                        a_s := SIGNED(input1_reg);
                        r_s := a_s + 1;
                        output_temp := STD_LOGIC_VECTOR(r_s);
                        Cout <= '0';
                        -- +7 becomes -8 in 4-bit signed arithmetic
                        Overflow <= (not a_s(3)) and r_s(3);

                    -- A < B using unsigned comparison
                    when "0101" =>
                        is_cmp := true;
                        if UNSIGNED(input1_reg) < UNSIGNED(input2_reg) then
                            output_temp := "1111";
                        else
                            output_temp := "0000";
                        end if;
                        Cout     <= '0';
                        Overflow <= '0';

                    -- Bitwise XOR
                    when "0110" =>
                        output_temp := input1_reg xor input2_reg;
                        Cout     <= '0';
                        Overflow <= '0';

                    -- A > B using unsigned comparison
                    when "0111" =>
                        is_cmp := true;
                        if UNSIGNED(input1_reg) > UNSIGNED(input2_reg) then
                            output_temp := "1111";
                        else
                            output_temp := "0000";
                        end if;
                        Cout     <= '0';
                        Overflow <= '0';

                    -- unused operation codes
                    when others =>
                        output_temp := (others => '0');
                        Cout     <= '0';
                        Overflow <= '0';
                end case;

                -- Zero flag
                if output_temp = "0000" then
                    Zero <= '1';
                else
                    Zero <= '0';
                end if;

                -- For comparisons, 1111 means true, so Negative stays zero
                if is_cmp then
                    Negative <= '0';
                else
                    Negative <= output_temp(3);
                end if;
                -- Save the final result
                output <= output_temp;
            end if;
        end if;
    end process;
end architecture Behavioral;
