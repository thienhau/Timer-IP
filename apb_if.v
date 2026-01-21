module apb_if (
    input clk,
    input rst_n,
    input psel,
    input pwrite,
    input penable,
    input [11:0] paddr,
    input [31:0] pwdata,
    input [3:0] pstrb,
    input error,
    input [31:0] rdata,
    output reg pready,
    output pslverr,
    output reg [31:0] prdata,
    output reg_ren,
    output reg_wen,
    output [11:0] addr,
    output [31:0] wdata,
    output [3:0] byte_en
);

    // Internal registers
    reg wait_cnt;
    reg [1:0] state;
    reg [1:0] next_state;
    
    // State encoding
    parameter IDLE = 0;
    parameter SETUP = 1;
    parameter WAIT = 2;
    parameter ACCESS = 3;

    // Continuous assignments
    assign addr = paddr;
    assign wdata = pwdata;
    assign byte_en = pstrb;
    assign reg_wen = (state == ACCESS && pwrite);
    assign reg_ren = (state == ACCESS && !pwrite);

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:
                begin
                    if (psel && !penable)
                        next_state = SETUP;
                    else
                        next_state = IDLE;
                end
            SETUP:
                if (psel && penable)
                    next_state = WAIT;
            WAIT:
                if (wait_cnt == 1)
                    next_state = ACCESS;
            ACCESS:
                begin
                    if (psel && !penable)
                        next_state = SETUP;
                    else
                        next_state = IDLE;
                end
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Control signals and data path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                wait_cnt <= 0;
                prdata <= 0;
                pready <= 0;
            end
        else
            begin
                case (state)
                    IDLE:
                        begin
                            wait_cnt <= 0;
                            pready <= 0;
                        end
                    WAIT:
                        begin
                            wait_cnt <= 1;
                            pready <= 0;
                        end
                    ACCESS:
                        begin
                            prdata <= rdata;
                            pready <= 1;
                            wait_cnt <= 0;
                        end
                    default:
                        pready <= 0;
                endcase
            end
    end

    // Error signal
    assign pslverr = (state == ACCESS) && error;

endmodule
