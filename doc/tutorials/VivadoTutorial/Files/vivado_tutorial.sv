
module vivado_tutorial (
    input  wire       Clk,
    input  wire [3:0] Buttons,
    input  wire [3:0] Switches,
    output wire [3:0] Led
);

    ////////////////////////////////////////////////////////////////////////////
    // Local Parameters Declarations
    ////////////////////////////////////////////////////////////////////////////
    localparam real SYS_CLOCK_FREQ  = 125.0e6;
    localparam real FAST_CLOCK_FREQ = 225.0e6;
    localparam real SLOW_CLOCK_FREQ = 33.3e6;

    localparam real DEBOUNCE_TIME   = 25.0e-3;

    ////////////////////////////////////////////////////////////////////////////
    // Signal Declarations
    ////////////////////////////////////////////////////////////////////////////
    // System Domain
    wire       SysClk;
    wire       SysRst;
    wire       SysRstInit;
    wire       SysFromFastRst;
    wire       SysFromSlowRst;

    wire [3:0] SysSwitchesSync;

    // Fast Domain
    wire       FastClk;
    wire       FastRst;

    wire [1:0] FastButtonsSync;
    reg  [1:0] FastButtonsLast;
    reg  [1:0] FastButtonsRisingEdges;

    wire [1:0] FastFromSlowButtonsRisingEdges;

    wire [3:0] FastFromSysSwitches;

    // Slow Domain
    wire       SlowClk;
    wire       SlowRst;

    wire [1:0] SlowButtonsSync;
    reg  [1:0] SlowButtonsLast;
    reg  [1:0] SlowButtonsRisingEdges;

    wire [1:0] SlowFromFastButtonsRisingEdges;
    
    wire [3:0] SlowFromSysSwitches;

    ////////////////////////////////////////////////////////////////////////////
    // System Domain
    ////////////////////////////////////////////////////////////////////////////
    assign SysRst = SysFromFastRst | SysFromSlowRst;
    assign SysClk = Clk;

    clock_gen i_clock_gen (
        .reset(SysRstInit),
        .clk_in1(SysClk),
        .clk_out1(FastClk),
        .clk_out2(SlowClk)
    );

    // Assert reset after power up
    olo_base_reset_gen i_reset (                  
        .Clk(SysClk),
        .RstOut(SysRstInit)
    );  

    // Debounce Switches
    olo_intf_debounce #(
        .ClkFrequency_g(SYS_CLOCK_FREQ),
        .DebounceTime_g(DEBOUNCE_TIME),
        .Width_g(4)
    ) i_sys_switches (
        .Clk(SysClk),
        .Rst(SysRst),
        .DataAsync(Switches),
        .DataOut(SysSwitchesSync)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Fast Domain
    ////////////////////////////////////////////////////////////////////////////

    // Debounce Buttons
    olo_intf_debounce #(
        .ClkFrequency_g(FAST_CLOCK_FREQ),
        .DebounceTime_g(DEBOUNCE_TIME),
        .Width_g(2)
    ) i_fast_buttons (
        .Clk(FastClk),
        .Rst(FastRst),
        .DataAsync(Buttons[1:0]),
        .DataOut(FastButtonsSync)
    );

    // -- Edge Detection
    always @(posedge FastClk) begin
        if (FastRst) begin
            FastButtonsLast <= 2'b00;
            FastButtonsRisingEdges <= 2'b00;
        end else begin
            FastButtonsRisingEdges <= FastButtonsSync & ~FastButtonsLast;
            FastButtonsLast <= FastButtonsSync;
        end
    end

    // FIFO
    olo_base_fifo_sync #(
        .Width_g(2),
        .Depth_g(4096)
    ) i_fast_fifo (
        .Clk(FastClk),
        .Rst(FastRst),
        .In_Data(FastFromSysSwitches[3:2]),
        .In_Valid(FastFromSlowButtonsRisingEdges[0]),
        .Out_Data(Led[3:2]),
        .Out_Ready(FastFromSlowButtonsRisingEdges[1])
    );

    ////////////////////////////////////////////////////////////////////////////
    // Slow Domain
    ////////////////////////////////////////////////////////////////////////////
    // Debounce Buttons
    olo_intf_debounce #(
        .ClkFrequency_g(SLOW_CLOCK_FREQ),
        .DebounceTime_g(DEBOUNCE_TIME),
        .Width_g(2)
    ) i_slow_buttons (
        .Clk(SlowClk),
        .Rst(SlowRst),
        .DataAsync(Buttons[3:2]),
        .DataOut(SlowButtonsSync)
    );

    // -- Edge Detection
    always @(posedge SlowClk) begin
        if (SlowRst) begin
            SlowButtonsLast <= 2'b00;
            SlowButtonsRisingEdges <= 2'b00;
        end else begin
            SlowButtonsRisingEdges <= SlowButtonsSync & ~SlowButtonsLast;
            SlowButtonsLast <= SlowButtonsSync;
        end
    end

   // FIFO
    olo_base_fifo_sync #(
        .Width_g(2),
        .Depth_g(4096)
    ) i_slow_fifo (
        .Clk(SlowClk),
        .Rst(SlowRst),
        .In_Data(SlowFromSysSwitches[1:0]),
        .In_Valid(SlowFromFastButtonsRisingEdges[0]),
        .Out_Data(Led[1:0]),
        .Out_Ready(SlowFromFastButtonsRisingEdges[1])
    );

    ////////////////////////////////////////////////////////////////////////////
    // Clock Domain Crossing
    ////////////////////////////////////////////////////////////////////////////
    olo_base_cc_reset i_fast_cc_reset (
        .A_Clk(SysClk),
        .A_RstIn(SysRstInit),
        .A_RstOut(SysFromFastRst),

        .B_Clk(FastClk),
        .B_RstIn(),
        .B_RstOut(FastRst)
    );

    olo_base_cc_reset i_slow_cc_reset (
        .A_Clk(SysClk),
        .A_RstIn(SysRstInit),
        .A_RstOut(SysFromSlowRst),

        .B_Clk(SlowClk),
        .B_RstIn(),
        .B_RstOut(SlowRst)
    );

    olo_base_cc_pulse #(
        .Width_g(2)
    ) i_fast_from_slow_buttons (
        .In_Clk(SlowClk),
        .In_Pulse(SlowButtonsRisingEdges),

        .Out_Clk(FastClk),
        .Out_Pulse(FastFromSlowButtonsRisingEdges)
    );

    olo_base_cc_pulse #(
        .Width_g(2)
    ) i_slow_from_fast_buttons (
        .In_Clk(FastClk),
        .In_Pulse(FastButtonsRisingEdges),

        .Out_Clk(SlowClk),
        .Out_Pulse(SlowFromFastButtonsRisingEdges)
    );

    olo_base_cc_bits #(
        .Width_g(4)
    ) i_fast_from_sys_switches (
        .In_Clk(SysClk),
        .In_Rst(SysRst),
        .In_Data(SysSwitchesSync),

        .Out_Clk(FastClk),
        .Out_Rst(FastRst),
        .Out_Data(FastFromSysSwitches)
    );

    olo_base_cc_bits #(
        .Width_g(4)
    ) i_slow_from_sys_switches (
        .In_Clk(SysClk),
        .In_Rst(SysRst),
        .In_Data(SysSwitchesSync),

        .Out_Clk(SlowClk),
        .Out_Rst(SlowRst),
        .Out_Data(SlowFromSysSwitches)
    );

endmodule