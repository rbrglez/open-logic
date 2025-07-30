---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Rene Brglez
-- All rights reserved.
-- Authors: Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_arb_wrr_tb is
    generic (
        runner_cfg    : string;
        RandomStall_g : boolean              := false;
        Latency_g     : natural range 0 to 1 := 0
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_wrr_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant GrantWidth_c  : positive := 5;
    constant WeightWidth_c : positive := 4;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- *** Verification Components ***
    -- Slave VC
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length => GrantWidth_c,
            stall_config => new_stall_config(0.0, 0, 0)
        );

    -- Master VC
    constant TotalInBits_c : integer := GrantWidth_c + WeightWidth_c*GrantWidth_c;

    signal In_Data : std_logic_vector(TotalInBits_c - 1 downto 0);

    constant In_Data_ReqHighIdx_c     : integer := TotalInBits_c - 1;
    constant In_Data_ReqLowIdx_c      : integer := TotalInBits_c - GrantWidth_c;
    constant In_Data_WeightsHighIdx_c : integer := In_Data_ReqLowIdx_c - 1;
    constant In_Data_WeightsLowIdx_c  : integer := 0;

    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
            data_length  => TotalInBits_c,
            stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 5, 10)
        );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                   := '0';
    signal Rst        : std_logic                                   := '1';
    signal In_Valid   : std_logic;
    signal In_Weights : std_logic_vector(WeightWidth_c * GrantWidth_c - 1 downto 0);
    signal In_Req     : std_logic_vector(GrantWidth_c - 1 downto 0);
    signal Out_Valid  : std_logic                                   := '0';
    signal Out_Grant  : std_logic_vector(GrantWidth_c - 1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Procedures  and Functions ***

    -- Converts an integer array to a std_logic_vector
    function integerArray2Slv (IntArray : IntegerArray_t; VectorWidth : positive) return std_logic_vector is
        constant ArrayWidth_c : positive := IntArray'length;
        variable Vec_v        : std_logic_vector(ArrayWidth_c * VectorWidth - 1 downto 0);
    begin

        for i in IntArray'range loop
            Vec_v((i + 1)*VectorWidth - 1 downto i*VectorWidth) := toUslv(IntArray(i), VectorWidth);
        end loop;

        return Vec_v;
    end function;

    -- Writes Weights and Request to DUT and compares received Grant with the ExpectedGrant
    procedure testSample (
        signal net    : inout network_t;
        Weights       : in    IntegerArray_t;
        Request       : in    std_logic_vector;
        ExpectedGrant : in    std_logic_vector;
        Check         : in    boolean := true;
        Msg           : in    string  := "") is
        variable WeightsStdlv_v         : std_logic_vector(WeightWidth_c * GrantWidth_c - 1 downto 0);
        variable WeightsDescendingArr_v : IntegerArray_t(Weights'high downto Weights'low);
    begin
        -- Ensures IntegerArray has a descending range and reverses it if necessary
        if (Weights'ascending) then

            for i in Weights'range loop
                WeightsDescendingArr_v(i) := Weights(Weights'right - i);
            end loop;

        else
            WeightsDescendingArr_v := Weights;
        end if;
        WeightsStdlv_v := integerArray2Slv(WeightsDescendingArr_v, WeightWidth_c);

        push_axi_stream(net, AxisMaster_c, Request & WeightsStdlv_v);

        -- Option to disable AXI stream checking, useful for development and debugging
        if Check then
            check_axi_stream(net, AxisSlave_c, ExpectedGrant, blocking => false, msg => Msg);
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_wrr
        generic map (
            GrantWidth_g  => GrantWidth_c,
            WeightWidth_g => WeightWidth_c,
            Latency_g     => Latency_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid,
            In_Weights => In_Weights,
            In_Req     => In_Req,
            Out_Valid  => Out_Valid,
            Out_Grant  => Out_Grant
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    In_Req     <= In_Data(In_Data_ReqHighIdx_c downto In_Data_ReqLowIdx_c);
    In_Weights <= In_Data(In_Data_WeightsHighIdx_c downto In_Data_WeightsLowIdx_c);

    vc_master : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            Aclk   => Clk,
            Tvalid => In_Valid,
            Tdata  => In_Data
        );

    vc_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TData  => Out_Grant
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable In_Req_v          : std_logic_vector(In_Req'range);
        variable In_WeightsArray_v : IntegerArray_t(GrantWidth_c - 1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            Rst <= '1';
            wait for Clk_Period_c * 5;
            Rst <= '0';

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RoundRobinWeights") then

                In_WeightsArray_v := (others => 1);

                for i in 0 to 2 - 1 loop
                    testSample(net, In_WeightsArray_v, "11111", "10000");
                    testSample(net, In_WeightsArray_v, "11111", "01000");
                    testSample(net, In_WeightsArray_v, "11111", "00100");
                    testSample(net, In_WeightsArray_v, "11111", "00010");
                    testSample(net, In_WeightsArray_v, "11111", "00001");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_ZeroWeights") then

                In_WeightsArray_v := (others => 0);

                testSample(net, In_WeightsArray_v, "11111", "00000");
                testSample(net, In_WeightsArray_v, "11111", "00000");
                testSample(net, In_WeightsArray_v, "11111", "00000");
                testSample(net, In_WeightsArray_v, "11111", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RandomNonZeroWeights") then

                In_WeightsArray_v := (4,
                                      1,
                                      1,
                                      4,
                                      3);

                for i in 0 to 2 - 1 loop
                    testSample(net, In_WeightsArray_v, "11111", "10000", Msg => "0");
                    testSample(net, In_WeightsArray_v, "11111", "10000", Msg => "1");
                    testSample(net, In_WeightsArray_v, "11111", "10000", Msg => "2");
                    testSample(net, In_WeightsArray_v, "11111", "10000", Msg => "3");

                    testSample(net, In_WeightsArray_v, "11111", "01000", Msg => "4");

                    testSample(net, In_WeightsArray_v, "11111", "00100", Msg => "5");

                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "6");
                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "7");
                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "8");
                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "9");

                    testSample(net, In_WeightsArray_v, "11111", "00001", Msg => "10");
                    testSample(net, In_WeightsArray_v, "11111", "00001", Msg => "11");
                    testSample(net, In_WeightsArray_v, "11111", "00001", Msg => "12");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RandomWeights") then

                In_WeightsArray_v := (1,
                                      0,
                                      2,
                                      3,
                                      0);

                for i in 0 to 2 - 1 loop
                    testSample(net, In_WeightsArray_v, "11111", "10000", Msg => "0");

                    testSample(net, In_WeightsArray_v, "11111", "00100", Msg => "1");
                    testSample(net, In_WeightsArray_v, "11111", "00100", Msg => "2");

                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "3");
                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "4");
                    testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "5");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllLowReq_RandomNonZeroWeights") then

                In_WeightsArray_v := (1,
                                      4,
                                      3,
                                      4,
                                      4);

                testSample(net, In_WeightsArray_v, "00000", "00000");
                testSample(net, In_WeightsArray_v, "00000", "00000");
                testSample(net, In_WeightsArray_v, "00000", "00000");
                testSample(net, In_WeightsArray_v, "00000", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_RandomNonZeroReq_RandomNonZeroWeights") then

                In_WeightsArray_v := (3,
                                      3,
                                      1,
                                      4,
                                      3);

                for i in 0 to 2 - 1 loop
                    testSample(net, In_WeightsArray_v, "10010", "10000");
                    testSample(net, In_WeightsArray_v, "10010", "10000");
                    testSample(net, In_WeightsArray_v, "10010", "10000");

                    testSample(net, In_WeightsArray_v, "10010", "00010");
                    testSample(net, In_WeightsArray_v, "10010", "00010");
                    testSample(net, In_WeightsArray_v, "10010", "00010");
                    testSample(net, In_WeightsArray_v, "10010", "00010");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_RandomReq_RandomWeights") then

                In_WeightsArray_v := (3,
                                      4,
                                      3,
                                      0,
                                      2);

                for i in 0 to 2 - 1 loop
                    testSample(net, In_WeightsArray_v, "11011", "10000");
                    testSample(net, In_WeightsArray_v, "11011", "10000");
                    testSample(net, In_WeightsArray_v, "11011", "10000");

                    testSample(net, In_WeightsArray_v, "11011", "01000");
                    testSample(net, In_WeightsArray_v, "11011", "01000");
                    testSample(net, In_WeightsArray_v, "11011", "01000");
                    testSample(net, In_WeightsArray_v, "11011", "01000");

                    testSample(net, In_WeightsArray_v, "11011", "00001");
                    testSample(net, In_WeightsArray_v, "11011", "00001");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("SemiStatic_RandomNonZeroReq_RandomNonZeroWeights") then

                -- First "Complete Grant Cycle"
                In_WeightsArray_v := (1,
                                      4,
                                      3,
                                      3,
                                      1);

                testSample(net, In_WeightsArray_v, "10111", "10000");

                testSample(net, In_WeightsArray_v, "10111", "00100");
                testSample(net, In_WeightsArray_v, "10111", "00100");
                testSample(net, In_WeightsArray_v, "10111", "00100");

                testSample(net, In_WeightsArray_v, "10111", "00010");
                testSample(net, In_WeightsArray_v, "10111", "00010");
                testSample(net, In_WeightsArray_v, "10111", "00010");

                testSample(net, In_WeightsArray_v, "10111", "00001");

                -- Second "Complete Grant Cycle"
                In_WeightsArray_v := (4,
                                      3,
                                      1,
                                      4,
                                      1);

                testSample(net, In_WeightsArray_v, "11100", "10000");
                testSample(net, In_WeightsArray_v, "11100", "10000");
                testSample(net, In_WeightsArray_v, "11100", "10000");
                testSample(net, In_WeightsArray_v, "11100", "10000");

                testSample(net, In_WeightsArray_v, "11100", "01000");
                testSample(net, In_WeightsArray_v, "11100", "01000");
                testSample(net, In_WeightsArray_v, "11100", "01000");

                testSample(net, In_WeightsArray_v, "11100", "00100");

                -- Third "Complete Grant Cycle"
                In_WeightsArray_v := (4,
                                      1,
                                      3,
                                      2,
                                      1);

                testSample(net, In_WeightsArray_v, "01100", "01000");

                testSample(net, In_WeightsArray_v, "01100", "00100");
                testSample(net, In_WeightsArray_v, "01100", "00100");
                testSample(net, In_WeightsArray_v, "01100", "00100");
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("SemiStatic_RandomReq_RandomWeights") then

                -- First "Complete Grant Cycle"
                In_WeightsArray_v := (0,
                                      2,
                                      1,
                                      4,
                                      3);

                testSample(net, In_WeightsArray_v, "11001", "01000");
                testSample(net, In_WeightsArray_v, "11001", "01000");

                testSample(net, In_WeightsArray_v, "11001", "00001");
                testSample(net, In_WeightsArray_v, "11001", "00001");
                testSample(net, In_WeightsArray_v, "11001", "00001");

                -- Second "Complete Grant Cycle"
                In_WeightsArray_v := (2,
                                      3,
                                      0,
                                      3,
                                      1);

                testSample(net, In_WeightsArray_v, "00100", "00000");
                testSample(net, In_WeightsArray_v, "00100", "00000");
                testSample(net, In_WeightsArray_v, "00100", "00000");
                testSample(net, In_WeightsArray_v, "00100", "00000");

                -- Third "Complete Grant Cycle"
                In_WeightsArray_v := (0,
                                      0,
                                      0,
                                      0,
                                      0);

                testSample(net, In_WeightsArray_v, "01101", "00000");
                testSample(net, In_WeightsArray_v, "01101", "00000");
                testSample(net, In_WeightsArray_v, "01101", "00000");
                testSample(net, In_WeightsArray_v, "01101", "00000");
                testSample(net, In_WeightsArray_v, "01101", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Dynamic_RandomReq_RandomNonZeroWeights") then

                In_WeightsArray_v := (2,
                                      1,
                                      3,
                                      2,
                                      1);
                testSample(net, In_WeightsArray_v, "10101", "10000", Msg => "0");
                testSample(net, In_WeightsArray_v, "00010", "00010", Msg => "1");
                testSample(net, In_WeightsArray_v, "01100", "01000", Msg => "2");
                testSample(net, In_WeightsArray_v, "11011", "00010", Msg => "3");
                testSample(net, In_WeightsArray_v, "00010", "00010", Msg => "4");
                testSample(net, In_WeightsArray_v, "11101", "00001", Msg => "5");
                testSample(net, In_WeightsArray_v, "01011", "01000", Msg => "6");
                testSample(net, In_WeightsArray_v, "10000", "10000", Msg => "7");
                testSample(net, In_WeightsArray_v, "00101", "00100", Msg => "8");
                testSample(net, In_WeightsArray_v, "01111", "00100", Msg => "9");
                testSample(net, In_WeightsArray_v, "10110", "00100", Msg => "10");

                In_WeightsArray_v := (1,
                                      3,
                                      3,
                                      4,
                                      3);
                testSample(net, In_WeightsArray_v, "11010", "00010", Msg => "11");
                testSample(net, In_WeightsArray_v, "00111", "00010", Msg => "12");
                testSample(net, In_WeightsArray_v, "10100", "10000", Msg => "13");
                testSample(net, In_WeightsArray_v, "01101", "01000", Msg => "14");
                testSample(net, In_WeightsArray_v, "00011", "00010", Msg => "15");
                testSample(net, In_WeightsArray_v, "11100", "10000", Msg => "16");
                testSample(net, In_WeightsArray_v, "01010", "01000", Msg => "17");
                testSample(net, In_WeightsArray_v, "10011", "00010", Msg => "18");
                testSample(net, In_WeightsArray_v, "00100", "00100", Msg => "19");
                testSample(net, In_WeightsArray_v, "11001", "00001", Msg => "20");

                In_WeightsArray_v := (1,
                                      1,
                                      4,
                                      1,
                                      1);
                testSample(net, In_WeightsArray_v, "00101", "00001", Msg => "21"); -- "00100" or "00001", both OK
                testSample(net, In_WeightsArray_v, "11000", "10000", Msg => "22");
                testSample(net, In_WeightsArray_v, "11110", "01000", Msg => "23");
                testSample(net, In_WeightsArray_v, "00110", "00100", Msg => "24");
                testSample(net, In_WeightsArray_v, "10011", "00010", Msg => "25");
                testSample(net, In_WeightsArray_v, "01010", "01000", Msg => "26");
                testSample(net, In_WeightsArray_v, "11111", "00100", Msg => "27");
                testSample(net, In_WeightsArray_v, "00001", "00001", Msg => "28");
                testSample(net, In_WeightsArray_v, "10010", "10000", Msg => "29");
                testSample(net, In_WeightsArray_v, "01101", "01000", Msg => "30");
                testSample(net, In_WeightsArray_v, "01111", "00100", Msg => "31");
                testSample(net, In_WeightsArray_v, "11011", "00010", Msg => "32");
                testSample(net, In_WeightsArray_v, "01001", "00001", Msg => "33");

                In_WeightsArray_v := (3,
                                      1,
                                      2,
                                      3,
                                      1);
                testSample(net, In_WeightsArray_v, "10100", "10000", Msg => "34");
                testSample(net, In_WeightsArray_v, "01001", "01000", Msg => "35");
                testSample(net, In_WeightsArray_v, "11100", "00100", Msg => "36");
                testSample(net, In_WeightsArray_v, "00011", "00010", Msg => "37");
                testSample(net, In_WeightsArray_v, "00100", "00100", Msg => "38");
                testSample(net, In_WeightsArray_v, "11010", "00010", Msg => "39");
                testSample(net, In_WeightsArray_v, "01110", "00010", Msg => "40");
                testSample(net, In_WeightsArray_v, "10001", "00001", Msg => "41");
                testSample(net, In_WeightsArray_v, "00111", "00100", Msg => "42");
                testSample(net, In_WeightsArray_v, "01000", "01000", Msg => "43");
                testSample(net, In_WeightsArray_v, "11111", "00100", Msg => "44");
                testSample(net, In_WeightsArray_v, "10101", "00100", Msg => "45");
                testSample(net, In_WeightsArray_v, "00100", "00100", Msg => "46");
                testSample(net, In_WeightsArray_v, "10010", "00010", Msg => "47");
                testSample(net, In_WeightsArray_v, "11001", "00001", Msg => "48");
                testSample(net, In_WeightsArray_v, "01101", "01000", Msg => "49");
                testSample(net, In_WeightsArray_v, "10111", "00100", Msg => "50");
                testSample(net, In_WeightsArray_v, "00110", "00100", Msg => "51");
                testSample(net, In_WeightsArray_v, "10110", "00010", Msg => "52");
                testSample(net, In_WeightsArray_v, "01011", "00010", Msg => "53");
                testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "54");

                In_WeightsArray_v := (2,
                                      4,
                                      1,
                                      3,
                                      2);
                testSample(net, In_WeightsArray_v, "00000", "00000", Msg => "55");
                testSample(net, In_WeightsArray_v, "00110", "00100", Msg => "56");
                testSample(net, In_WeightsArray_v, "00000", "00000", Msg => "57");
                testSample(net, In_WeightsArray_v, "01101", "00001", Msg => "58");
                testSample(net, In_WeightsArray_v, "11100", "10000", Msg => "59");
                testSample(net, In_WeightsArray_v, "01010", "01000", Msg => "60");
                testSample(net, In_WeightsArray_v, "11101", "01000", Msg => "61");
                testSample(net, In_WeightsArray_v, "11011", "01000", Msg => "62");
                testSample(net, In_WeightsArray_v, "11001", "01000", Msg => "63");
                testSample(net, In_WeightsArray_v, "01100", "00100", Msg => "64");
                testSample(net, In_WeightsArray_v, "00011", "00010", Msg => "65");
                testSample(net, In_WeightsArray_v, "10101", "00001", Msg => "66");
                testSample(net, In_WeightsArray_v, "11010", "10000", Msg => "67");
                testSample(net, In_WeightsArray_v, "00110", "00100", Msg => "68");
                testSample(net, In_WeightsArray_v, "11111", "00010", Msg => "69");
                testSample(net, In_WeightsArray_v, "10000", "10000", Msg => "70");
                testSample(net, In_WeightsArray_v, "01001", "01000", Msg => "71");
                testSample(net, In_WeightsArray_v, "00000", "00000", Msg => "72");
                testSample(net, In_WeightsArray_v, "11101", "00100", Msg => "73");
                testSample(net, In_WeightsArray_v, "00000", "00000", Msg => "74");
                testSample(net, In_WeightsArray_v, "00000", "00000", Msg => "75");
                testSample(net, In_WeightsArray_v, "01010", "00010", Msg => "76");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Dynamic_AllHighReq_RandomNonZeroWeights") then

                In_Req_v := (others => '1');

                testSample(net, (4,1,3,2,2), In_Req_v, "10000", Msg => "0");
                testSample(net, (3,1,4,3,2), In_Req_v, "10000", Msg => "1");
                testSample(net, (2,3,4,4,1), In_Req_v, "10000", Msg => "2");
                testSample(net, (1,2,3,1,2), In_Req_v, "01000", Msg => "3");
                testSample(net, (2,4,1,3,3), In_Req_v, "01000", Msg => "4");
                testSample(net, (1,1,2,4,4), In_Req_v, "01000", Msg => "5");
                testSample(net, (3,3,2,1,2), In_Req_v, "00100", Msg => "6");
                testSample(net, (4,2,1,3,1), In_Req_v, "00100", Msg => "7");
                testSample(net, (2,2,3,4,4), In_Req_v, "00010", Msg => "8");
                testSample(net, (3,4,2,1,3), In_Req_v, "00010", Msg => "9");
                testSample(net, (1,3,4,2,2), In_Req_v, "00001", Msg => "10");
                testSample(net, (2,1,3,4,1), In_Req_v, "00001", Msg => "11");
                testSample(net, (4,4,1,2,3), In_Req_v, "10000", Msg => "12");
                testSample(net, (1,2,4,3,3), In_Req_v, "10000", Msg => "13");
                testSample(net, (3,1,2,2,4), In_Req_v, "01000", Msg => "14");
                testSample(net, (2,3,1,4,1), In_Req_v, "00100", Msg => "15");
                testSample(net, (4,3,2,1,3), In_Req_v, "00010", Msg => "16");
                testSample(net, (1,1,3,2,4), In_Req_v, "00001", Msg => "17");
                testSample(net, (2,4,4,1,2), In_Req_v, "00001", Msg => "18");
                testSample(net, (3,2,1,4,3), In_Req_v, "10000", Msg => "19");
                testSample(net, (4,2,3,3,1), In_Req_v, "10000", Msg => "20");
                testSample(net, (1,3,2,2,4), In_Req_v, "10000", Msg => "21");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Dynamic_AllHighReq_RandomWeights") then

                In_Req_v := (others => '1');

                testSample(net, (3,0,2,1,1), In_Req_v, "10000", Msg => "0");
                testSample(net, (1,0,3,2,0), In_Req_v, "10000", Msg => "1");
                testSample(net, (2,2,0,3,1), In_Req_v, "01000", Msg => "2");
                testSample(net, (0,3,1,1,2), In_Req_v, "01000", Msg => "3");
                testSample(net, (2,1,3,0,3), In_Req_v, "01000", Msg => "4");
                testSample(net, (1,1,2,3,0), In_Req_v, "00100", Msg => "5");
                testSample(net, (0,2,1,1,3), In_Req_v, "00100", Msg => "6");
                testSample(net, (3,0,0,2,1), In_Req_v, "00010", Msg => "7");
                testSample(net, (2,3,2,3,0), In_Req_v, "00010", Msg => "8");
                testSample(net, (1,2,3,0,3), In_Req_v, "00010", Msg => "9");
                testSample(net, (0,1,0,3,2), In_Req_v, "00001", Msg => "10");
                testSample(net, (3,2,1,0,1), In_Req_v, "00001", Msg => "11");
                testSample(net, (1,3,0,2,3), In_Req_v, "10000", Msg => "12");
                testSample(net, (0,0,3,1,2), In_Req_v, "00100", Msg => "13");
                testSample(net, (2,1,1,2,0), In_Req_v, "00100", Msg => "14");
                testSample(net, (3,3,0,3,1), In_Req_v, "00010", Msg => "15");
                testSample(net, (0,2,2,0,3), In_Req_v, "00010", Msg => "16");
                testSample(net, (1,1,3,1,2), In_Req_v, "00001", Msg => "17");
                testSample(net, (2,0,2,3,0), In_Req_v, "00001", Msg => "18");
                testSample(net, (3,2,0,2,1), In_Req_v, "10000", Msg => "19");
                testSample(net, (0,3,1,0,2), In_Req_v, "10000", Msg => "20");
                testSample(net, (1,0,2,3,3), In_Req_v, "00100", Msg => "21");

            end if;

            wait_until_idle(net, as_sync(AxisSlave_c));
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait for Clk_Period_c*10;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
