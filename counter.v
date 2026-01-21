module counter (
    input clk,
    input rst_n,
    input timer_en,
    input div_en,
    input [3:0] div_val,
    input halt,
    input tdr0_wr_select,
    input tdr1_wr_select,
    input [31:0] tdr0_init,
    input [31:0] tdr1_init,
    output reg [63:0] counter
);

    // Internal registers
    reg [7:0] div_cnt;
    reg [31:0] tdr0_reg;
    reg [31:0] tdr1_reg;
    
    // Internal signals
    wire cnt_en;
    wire [8:0] div_sel;

    // TDR Registers (Load Values)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                tdr0_reg <= 32'h0;
                tdr1_reg <= 32'h0;
            end
        else
            begin
                if (tdr0_wr_select)
                    tdr0_reg <= tdr0_init;
                if (tdr1_wr_select)
                    tdr1_reg <= tdr1_init;
            end
    end
    
    // Divider Logic
    assign div_sel = div_en ? 1 << div_val : 4'h0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            div_cnt <= 0;
        else
            begin
                if (timer_en && !halt)
                    begin
                        if (div_cnt == (div_en ? div_sel - 1 : 0))
                            div_cnt <= 0;
                        else
                            div_cnt <= div_cnt + 1;
                    end
                else
                    div_cnt <= 0;
            end
    end
    
    // Counter enable signal
    assign cnt_en = (timer_en && !halt && div_cnt == (div_en ? div_sel - 1 : 0));
    
    // Counter Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                counter <= 0;
            end
        else
            begin
                if (!timer_en)
                    begin
                        counter <= {tdr1_reg, tdr0_reg};
                    end
                else if (cnt_en && !halt)
                    begin
                        counter <= counter + 1;
                    end
            end
    end

endmodule
