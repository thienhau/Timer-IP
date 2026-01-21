module halt_ctrl (
    input clk,
    input rst_n,
    input halt_req,
    input dbg_mode,
    output reg halt_ack,
    output halt_en
);

    // Halt acknowledge register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            halt_ack <= 1'b0;
        else
            halt_ack <= halt_req && dbg_mode;
    end
    
    // Halt enable signal
    assign halt_en = halt_req && dbg_mode;

endmodule

