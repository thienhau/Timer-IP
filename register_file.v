module register_file (
    input clk,
    input rst_n,
    input r_en,
    input w_en,
    input [11:0] addr,
    input [31:0] wdata,
    input [3:0] byte_en,
    input [63:0] counter,
    input int_st,
    input halt_ack,
    output error,
    output reg [31:0] rdata,
    output timer_en,
    output div_en,
    output [3:0] div_val,
    output halt_req,
    output int_en,
    output int_clr,
    output compare,
    output reg tdr0_wr_select,
    output reg tdr1_wr_select,
    output [31:0] tdr0_value,
    output [31:0] tdr1_value
);

    // Register addresses
    localparam A_TCR   = 12'h000;
    localparam A_TDR0  = 12'h004;
    localparam A_TDR1  = 12'h008;
    localparam A_TCMP0 = 12'h00C;
    localparam A_TCMP1 = 12'h010;
    localparam A_TIER  = 12'h014;
    localparam A_TISR  = 12'h018;
    localparam A_THCSR = 12'h01C;

    // Internal registers
    reg [31:0] TCR;
    reg [31:0] TCMP0;
    reg [31:0] TCMP1;
    reg [31:0] TIER;
    reg [31:0] TISR;
    reg [31:0] THCSR;
    reg [31:0] TDR0;
    reg [31:0] TDR1;
    
    // Write masks
    wire [31:0] TCR_wm = 32'h00000F03;
    wire [31:0] TIER_wm = 32'h00000001;
    wire [31:0] THCSR_wm = 32'h00000001;
    
    // Error signals
    wire div_val_er;
    wire timer_en_div_val_er;
    wire timer_en_div_en_er;

    // Helper function for byte enables
    function [31:0] apply_byte_en;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0] byte_en;
        begin
            apply_byte_en = old_data;
            if (byte_en[0])
                apply_byte_en[7:0] = new_data[7:0];
            if (byte_en[1])
                apply_byte_en[15:8] = new_data[15:8];
            if (byte_en[2])
                apply_byte_en[23:16] = new_data[23:16];
            if (byte_en[3])
                apply_byte_en[31:24] = new_data[31:24];
        end
    endfunction
    
    // Control signal assignments
    assign timer_en = TCR[0];
    assign div_en = TCR[1];
    assign div_val = TCR[11:8];
    assign int_en = TIER[0];
    assign halt_req = THCSR[0];
    assign compare = (TCMP0 == counter[31:0]) && (TCMP1 == counter[63:32]);
    assign int_clr = (w_en && addr == A_TISR && wdata[0] == 1);
    
    // Error Logic
    assign div_val_er = w_en && addr == A_TCR && (wdata[11:8] > 4'd8);
    assign timer_en_div_val_er = w_en && addr == A_TCR && TCR[0] && byte_en[1] && (TCR[11:8] !== wdata[15:8]);
    assign timer_en_div_en_er = w_en && addr == A_TCR && TCR[0] && byte_en[0] && (TCR[1] !== wdata[1]);
    assign error = div_val_er || timer_en_div_val_er || timer_en_div_en_er;
    
    // Output assignments
    assign tdr0_value = TDR0;
    assign tdr1_value = TDR1;

    // Register write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                TCR <= 32'h0000_0100; 
                TCMP0 <= 32'hFFFF_FFFF; 
                TCMP1 <= 32'hFFFF_FFFF;
                TIER <= 0;
                TISR <= 0;
                THCSR <= 0;
                TDR0 <= 0;
                TDR1 <= 0;
                tdr0_wr_select <= 0;
                tdr1_wr_select <= 0;
            end 
        else
            begin
                tdr0_wr_select <= w_en && addr == A_TDR0;
                tdr1_wr_select <= w_en && addr == A_TDR1;
                
                // TISR Clear Logic
                if (w_en && addr == A_TISR && byte_en[0] && wdata[0])
                    begin
                        TISR[0] <= 0;
                    end
                else if (int_st)
                    begin
                        TISR[0] <= 1;
                    end
                
                // Halt acknowledge bit
                if (halt_ack)
                    THCSR[1] <= 1;
                else
                    THCSR[1] <= 0;
                
                if (w_en)
                    begin
                        case (addr)
                            A_TCR:
                                begin
                                    // Always allow timer_en update
                                    if (byte_en[0])
                                        TCR[0] <= wdata[0];

                                    // Update config bits only if no error
                                    if (!error)
                                        begin
                                            if (byte_en[0])
                                                TCR[1] <= wdata[1];
                                            if (byte_en[1])
                                                TCR[11:8] <= wdata[11:8];
                                        end
                                end
                            A_TDR0:
                                TDR0 <= apply_byte_en(TDR0, wdata, byte_en);
                            A_TDR1:
                                TDR1 <= apply_byte_en(TDR1, wdata, byte_en);
                            A_TCMP0:
                                TCMP0 <= apply_byte_en(TCMP0, wdata, byte_en);
                            A_TCMP1:
                                TCMP1 <= apply_byte_en(TCMP1, wdata, byte_en);
                            A_TIER:
                                TIER <= (apply_byte_en(TIER, wdata, byte_en) & TIER_wm) | (TIER & ~TIER_wm);
                            A_THCSR:
                                THCSR <= (apply_byte_en(THCSR, wdata, byte_en) & THCSR_wm) | (THCSR & ~THCSR_wm);
                            default: ;
                        endcase
                    end
            end
    end

    // Read logic
    always @(*) begin
        if (r_en)
            begin
                case (addr)
                    A_TCR:
                        rdata = {20'h0, TCR[11:8], 6'h0, TCR[1:0]};
                    A_TDR0:
                        rdata = counter[31:0];  // Return live counter
                    A_TDR1:
                        rdata = counter[63:32]; // Return live counter
                    A_TCMP0:
                        rdata = TCMP0;
                    A_TCMP1:
                        rdata = TCMP1;
                    A_TIER:
                        rdata = {31'h0, TIER[0]};
                    A_TISR:
                        rdata = {31'h0, TISR[0]};
                    A_THCSR:
                        rdata = {30'h0, THCSR[1:0]};
                    default:
                        rdata = 32'h0;
                endcase
            end
        else
            rdata = 32'h0;
    end

endmodule
