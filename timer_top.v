module timer_top (
    input sys_clk,
    input sys_rst_n,
    input tim_psel,
    input tim_pwrite,
    input tim_penable,
    input [11:0] tim_paddr,
    input [31:0] tim_pwdata,
    input [3:0] tim_pstrb,
    input dbg_mode,
    output tim_int,
    output tim_pready,
    output tim_pslverr,
    output [31:0] tim_prdata
);

    // Internal wires
    wire [11:0] addr;
    wire [31:0] wdata;
    wire [31:0] rdata;
    wire [3:0] byte_en;
    wire reg_ren;
    wire reg_wen;
    wire error_response;

    // Control signals
    wire timer_en;
    wire div_en;
    wire halt_req;
    wire int_en;
    wire int_clr;
    wire compare;
    wire int_st;
    wire halt_ack;
    wire [3:0] div_val;
    wire halt_en;
    wire [63:0] counter_out;
    wire tdr0_wr_select;
    wire tdr1_wr_select;
    wire [31:0] tdr0_value;
    wire [31:0] tdr1_value;

    // APB interface instantiation
    apb_if APB (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .psel(tim_psel),
        .pwrite(tim_pwrite),
        .penable(tim_penable),
        .paddr(tim_paddr),
        .pwdata(tim_pwdata),
        .pstrb(tim_pstrb),
        .error(error_response),
        .rdata(rdata),
        .pready(tim_pready),
        .pslverr(tim_pslverr),
        .prdata(tim_prdata),
        .reg_ren(reg_ren),
        .reg_wen(reg_wen),
        .addr(addr),
        .wdata(wdata),
        .byte_en(byte_en)
    );

    // Register file instantiation
    register_file REG (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .r_en(reg_ren),
        .w_en(reg_wen),
        .addr(addr),
        .wdata(wdata),
        .byte_en(byte_en),
        .counter(counter_out),
        .int_st(int_st),
        .halt_ack(halt_ack),
        .error(error_response),
        .rdata(rdata),
        .timer_en(timer_en),
        .div_en(div_en),
        .div_val(div_val),
        .halt_req(halt_req),
        .int_en(int_en),
        .int_clr(int_clr),
        .compare(compare),
        .tdr0_wr_select(tdr0_wr_select),
        .tdr1_wr_select(tdr1_wr_select),
        .tdr0_value(tdr0_value),
        .tdr1_value(tdr1_value)
    );

    // Counter instantiation
    counter CNT (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .timer_en(timer_en),
        .div_en(div_en),
        .div_val(div_val),
        .halt(halt_en),
        .tdr0_wr_select(tdr0_wr_select),
        .tdr1_wr_select(tdr1_wr_select),
        .tdr0_init(tdr0_value),
        .tdr1_init(tdr1_value),
        .counter(counter_out)
    );

    // Interrupt controller instantiation
    interrupt_ctrl INTR (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .int_en(int_en),
        .compare(compare),
        .int_clr(int_clr),
        .tim_int(tim_int),
        .int_st(int_st)
    );

    // Halt controller instantiation
    halt_ctrl HALT (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .halt_req(halt_req),
        .dbg_mode(dbg_mode),
        .halt_ack(halt_ack),
        .halt_en(halt_en)
    );

endmodule
