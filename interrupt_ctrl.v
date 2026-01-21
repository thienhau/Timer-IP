module interrupt_ctrl (
    input clk,
    input rst_n,
    input int_en,
    input compare,
    input int_clr,
    output tim_int,
    output reg int_st
);

    // Interrupt status register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            begin
                int_st <= 0;
            end
        else
            begin
                if (int_clr)
                    begin
                        int_st <= 0;
                    end
                else if (compare)
                    begin
                        int_st <= 1;
                    end
            end
    end
    
    // Interrupt output
    assign tim_int = int_en && int_st;

endmodule
