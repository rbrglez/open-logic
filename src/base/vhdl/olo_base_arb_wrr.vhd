---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler, Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an efficient weighted round-robin arbiter.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_arb_wrr.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_arb_wrr is
    generic (
        GrantWidth_g  : positive;
        WeightWidth_g : positive;
        Latency_g     : natural range 0 to 1
    );
    port (
        Clk        : in    std_logic;
        Rst        : in    std_logic;

        -- Request Interface
        In_Valid   : in    std_logic;
        In_Ready   : out   std_logic;
        In_Weights : in    std_logic_vector(WeightWidth_g*GrantWidth_g-1 downto 0);
        In_Req     : in    std_logic_vector(GrantWidth_g-1 downto 0);

        -- Grant Interface
        Out_Valid  : out   std_logic;
        Out_Grant  : out   std_logic_vector(GrantWidth_g-1 downto 0)
    );
end entity;

architecture rtl of olo_base_arb_wrr is

    -- Functions
    -- Generates a mask for the input request vector.
    -- Each bit is set to '1' if the corresponding weight is not zero, otherwise it is '0'.
    -- Effectively masks out requests with zero weight.
    function generateRequestWeightsMask (
        Weights     : std_logic_vector;
        WeightWidth : positive;
        GrantWidth  : positive) return std_logic_vector is
        -- Variables
        variable RequestWeightsMask_v : std_logic_vector(GrantWidth-1 downto 0);
    begin

        for i in (GrantWidth-1) downto 0 loop
            if (unsigned(Weights((i+1)*WeightWidth-1 downto i*WeightWidth)) /= 0) then
                RequestWeightsMask_v(i) := '1';
            else
                RequestWeightsMask_v(i) := '0';
            end if;
        end loop;

        return RequestWeightsMask_v;
    end function;

    -- state record
    type State_t is (
            Idle_s,
            SendGrant_s
        );

    -- Two Process Method
    type TwoProcess_t is record
        -- Round Robin
        RrReq        : std_logic_vector(In_Req'range);
        RrGrantReady : std_logic;
        -- Request Interface
        ReqReady   : std_logic;
        -- Weighted Round Robin Grant Interface
        Grant      : std_logic_vector(Out_Grant'range);
        GrantValid : std_logic;
        -- Support signals
        GrantIdx  : integer;
        Weight    : unsigned(WeightWidth_g - 1 downto 0);
        WeightCnt : unsigned(WeightWidth_g - 1 downto 0);
        --
        State : State_t;
    end record;

    signal r      : TwoProcess_t;
    signal r_next : TwoProcess_t;

    -- Component connection signals
    signal RrReq        : std_logic_vector(In_Req'range);
    signal RrGrant      : std_logic_vector(Out_Grant'range);
    signal RrGrantValid : std_logic;
    signal RrGrantReady : std_logic;

begin

    -- *** Component Instantiations ***
    i_arb_rr : entity work.olo_base_arb_rr
        generic map (
            Width_g => GrantWidth_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Req    => RrReq,
            Out_Valid => RrGrantValid,
            Out_Ready => RrGrantReady,
            Out_Grant => RrGrant
        );

    ----------------------------------------------------------------------------
    -- Latency Implementation
    ----------------------------------------------------------------------------
    g_latency : if (Latency_g /= 0) generate

        -- *** Combinatorial Process ***
        p_comb : process (all) is
            variable v : TwoProcess_t;
        begin

            -- hold variables stable
            v := r;

            -- Pulsed Signals
            v.GrantValid   := '0';
            v.RrGrantReady := '0';

            -- FSM
            case r.State is
                ----------------------------------------------------------------
                when Idle_s =>
                    v.ReqReady := '1';
                    if (In_Valid = '1' and r.ReqReady = '1') then
                        v.ReqReady := '0';
                        v.RrReq    := In_Req and generateRequestWeightsMask(In_Weights, WeightWidth_g, GrantWidth_g);
                        v.Weight   := unsigned(In_Weights((r.GrantIdx + 1) * WeightWidth_g - 1 downto r.GrantIdx * WeightWidth_g));

                        -- Get next Grant if current is invalid or 
                        -- can't be sent due to Request or Weight change
                        if (
                                r.WeightCnt = 0 or
                                v.RrReq(r.GrantIdx) = '0' or
                                r.WeightCnt >= v.Weight
                            ) then
                            -- Reset WeightCnt for new Grant
                            v.WeightCnt    := (others => '0');
                            v.RrGrantReady := '1';
                            v.GrantIdx     := getLeadingSetBitIndex(RrGrant);
                            -- Recalculate Weight as it may have changed because of new GrantIdx
                            v.Weight := unsigned(In_Weights((v.GrantIdx + 1) * WeightWidth_g - 1 downto v.GrantIdx * WeightWidth_g));
                            v.Grant  := RrGrant;

                        end if;

                        -- Assert GrantValid before entering SendGrant_s to minimize latency
                        v.GrantValid := '1';
                        v.State      := SendGrant_s;

                    end if;

                ----------------------------------------------------------------
                when SendGrant_s =>
                    -- WARNING: GrantValid must be asserted in the prior state. 
                    -- Otherwise the FSM won't respond to the input request!

                    -- Sent zero Grant. Reset WeightCnt
                    if (unsigned(r.Grant) = 0) then
                        v.WeightCnt := (others => '0');

                    -- All current Grants have been sent. Reset WeightCnt.
                    elsif (r.WeightCnt >= r.Weight - 1) then
                        v.WeightCnt := (others => '0');

                    -- Current Grant is still valid and can be resent if requested. 
                    -- Increment WeightCnt.
                    else
                        v.WeightCnt := r.WeightCnt + 1;

                    end if;

                    -- Assert ReqReady before entering Idle_s to minimize latency
                    v.ReqReady := '1';
                    v.State    := Idle_s;

                ----------------------------------------------------------------
                -- coverage off
                -- unreachable code
                when others => null;
                -- coverage on

            end case;

            -- Apply to record
            r_next <= v;
        end process;

        ------------------------------------------------------------------------
        -- Assign outputs
        ------------------------------------------------------------------------
        -- Request interface
        In_Ready <= r.ReqReady;
        -- Grant Interface
        Out_Grant <= r.Grant;
        Out_Valid <= r.GrantValid;
        -- RoundRobin Component signals
        RrReq        <= r_next.RrReq;
        RrGrantReady <= r_next.RrGrantReady;

    end generate;

    ----------------------------------------------------------------------------
    -- No Latency Implementation
    ----------------------------------------------------------------------------
    g_no_latency : if (Latency_g = 0) generate

        -- *** Combinatorial Process ***
        p_comb : process (all) is
            variable v : TwoProcess_t;
        begin
            -- hold variables stable
            v := r;

            -- No Latency Implementation is always ready
            v.ReqReady := '1';

            -- Pulsed Signals
            v.GrantValid   := '0';
            v.RrGrantReady := '0';

            v.State := Idle_s;
            -- ReqReady statement is redundant, but added for completeness
            if (In_Valid = '1' and v.ReqReady = '1') then
                v.RrReq  := In_Req and generateRequestWeightsMask(In_Weights, WeightWidth_g, GrantWidth_g);
                v.Weight := unsigned(In_Weights((r.GrantIdx + 1) * WeightWidth_g - 1 downto r.GrantIdx * WeightWidth_g));

                -- Get next Grant if current is invalid or 
                -- can't be sent due to Request or Weight change
                if (
                        r.WeightCnt = 0 or
                        v.RrReq(v.GrantIdx) = '0' or
                        r.WeightCnt >= v.Weight
                    ) then
                    -- Reset WeightCnt for new Grant
                    v.WeightCnt    := (others => '0');
                    v.RrGrantReady := '1';
                    v.GrantIdx     := getLeadingSetBitIndex(RrGrant);
                    -- Recalculate Weight as it may have changed because of new GrantIdx
                    v.Weight := unsigned(In_Weights((v.GrantIdx + 1) * WeightWidth_g - 1 downto v.GrantIdx * WeightWidth_g));
                    v.Grant  := RrGrant;

                end if;

                v.GrantValid := '1';
                v.State := SendGrant_s;

            end if;

            --------------------------------------------------------------------
            -- Send The Grant (same for both GetRrGrant_s and SendGrant_s state)
            if (v.State = SendGrant_s) then
                -- Sent zero Grant. Reset WeightCnt
                if (unsigned(v.Grant) = 0) then
                    v.WeightCnt := (others => '0');

                -- All current Grants have been sent. Reset WeightCnt.
                elsif (v.WeightCnt >= v.Weight - 1) then
                    v.WeightCnt := (others => '0');

                -- Current Grant is still valid and can be resent if requested. 
                -- Increment WeightCnt.
                else
                    v.WeightCnt := v.WeightCnt + 1;

                end if;
            end if;

            -- Apply to record
            r_next <= v;
        end process;

        ------------------------------------------------------------------------
        -- Assign outputs
        ------------------------------------------------------------------------
        -- Request interface
        In_Ready <= r_next.ReqReady;
        -- Grant Interface
        Out_Grant <= r_next.Grant;
        Out_Valid <= r_next.GrantValid;
        -- RoundRobin Component signals
        RrReq        <= r_next.RrReq;
        RrGrantReady <= r_next.RrGrantReady;

    end generate;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.RrGrantReady <= '0';
                r.GrantIdx     <= (GrantWidth_g - 1);
                r.GrantValid   <= '0';
                r.ReqReady     <= '0';
                r.WeightCnt    <= (others => '0');
                r.State        <= Idle_s;
            end if;
        end if;
    end process;

end architecture;
