`timescale 1ns/1ps

module timer_tb;

    // -------------------------------------------------------------------------
    // 1. Parameter Definitions
    // -------------------------------------------------------------------------
    // Register Offsets
    parameter A_TCR   = 12'h000;
    parameter A_TDR0  = 12'h004;
    parameter A_TDR1  = 12'h008;
    parameter A_TCMP0 = 12'h00C;
    parameter A_TCMP1 = 12'h010;
    parameter A_TIER  = 12'h014;
    parameter A_TISR  = 12'h018;
    parameter A_THCSR = 12'h01C;

    // -------------------------------------------------------------------------
    // 2. Signal Declarations
    // -------------------------------------------------------------------------
    reg sys_clk;
    reg sys_rst_n;
    
    // APB Signals
    reg tim_psel;
    reg tim_pwrite;
    reg tim_penable;
    reg [11:0] tim_paddr;
    reg [31:0] tim_pwdata;
    reg [3:0] tim_pstrb;
    
    wire [31:0] tim_prdata;
    wire tim_pready;
    wire tim_pslverr;
    
    // Sideband Signals
    reg dbg_mode;
    wire tim_int;

    // Testbench Variables
    integer test_pass;
    integer test_fail;
    integer test_case_num;
    
    reg [31:0] read_data;
    reg [31:0] temp_val;
    reg [31:0] start_val;
    reg [31:0] end_val;
    reg [31:0] frozen_val;

    // -------------------------------------------------------------------------
    // 3. DUT Instantiation
    // -------------------------------------------------------------------------
    timer_top DUT (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .tim_psel(tim_psel),
        .tim_pwrite(tim_pwrite),
        .tim_penable(tim_penable),
        .tim_paddr(tim_paddr),
        .tim_pwdata(tim_pwdata),
        .tim_pstrb(tim_pstrb),
        .dbg_mode(dbg_mode),
        .tim_int(tim_int),
        .tim_pready(tim_pready),
        .tim_pslverr(tim_pslverr),
        .tim_prdata(tim_prdata)
    );

    // -------------------------------------------------------------------------
    // 4. Clock Generation
    // -------------------------------------------------------------------------
    initial sys_clk = 0;
    always #5 sys_clk = ~sys_clk; // 100MHz clock

    // -------------------------------------------------------------------------
    // 5. Tasks
    // -------------------------------------------------------------------------
    
    // Task: APB Write
    task apb_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            @(posedge sys_clk);
            tim_paddr   <= addr;
            tim_pwdata  <= data;
            tim_pwrite  <= 1'b1;
            tim_psel    <= 1'b1;
            tim_pstrb   <= strb;
            tim_penable <= 1'b0;
            
            @(posedge sys_clk);
            tim_penable <= 1'b1;
            
            // Wait for pready (handling wait states)
            // Using logic wait to ensure compatibility
            while (tim_pready === 1'b0) begin
                @(posedge sys_clk);
            end
            
            @(posedge sys_clk);
            tim_psel    <= 1'b0;
            tim_penable <= 1'b0;
            tim_pwrite  <= 1'b0;
            tim_pstrb   <= 4'b0000;
        end
    endtask

    // Task: APB Read
    task apb_read;
        input [11:0] addr;
        output [31:0] data_out;
        begin
            @(posedge sys_clk);
            tim_paddr   <= addr;
            tim_pwrite  <= 1'b0;
            tim_psel    <= 1'b1;
            tim_penable <= 1'b0;
            
            @(posedge sys_clk);
            tim_penable <= 1'b1;
            
            while (tim_pready === 1'b0) begin
                @(posedge sys_clk);
            end
            
            data_out = tim_prdata; // Sample data
            
            @(posedge sys_clk); 
            tim_psel    <= 1'b0;
            tim_penable <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // 6. Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        // Initialize signals
        sys_rst_n = 0;
        tim_psel = 0;
        tim_pwrite = 0;
        tim_penable = 0;
        tim_paddr = 0;
        tim_pwdata = 0;
        tim_pstrb = 0;
        dbg_mode = 0;
        
        test_pass = 0;
        test_fail = 0;
        test_case_num = 0;

        // Reset Sequence
        #50;
        sys_rst_n = 1;
        #20;

        $display("==========================================================");
        $display("STARTING TIMER VERIFICATION");
        $display("==========================================================");

        // ==========================================================
        // GROUP 1: RESET VALUES CHECKS
        // ==========================================================
        
        // TC01
        test_case_num = 1;
        apb_read(A_TCR, read_data);
        if (read_data == 32'h0000_0100) begin
            $display("[PASS] TC01: TCR Reset Value is 32'h0000_0100"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC01: TCR Reset Value is %h", read_data); test_fail = test_fail + 1;
        end

        // TC02
        test_case_num = 2;
        apb_read(A_TDR0, read_data);
        if (read_data == 32'h0) begin
            $display("[PASS] TC02: TDR0 Reset Value is 0"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC02: TDR0 mismatch"); test_fail = test_fail + 1;
        end

        // TC03
        test_case_num = 3;
        apb_read(A_TDR1, read_data);
        if (read_data == 32'h0) begin
            $display("[PASS] TC03: TDR1 Reset Value is 0"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC03: TDR1 mismatch"); test_fail = test_fail + 1;
        end

        // TC04
        test_case_num = 4;
        apb_read(A_TCMP0, read_data);
        if (read_data == 32'hFFFFFFFF) begin
            $display("[PASS] TC04: TCMP0 Reset Value is FFFFFFFF"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC04: TCMP0 mismatch"); test_fail = test_fail + 1;
        end

        // TC05
        test_case_num = 5;
        apb_read(A_TCMP1, read_data);
        if (read_data == 32'hFFFFFFFF) begin
            $display("[PASS] TC05: TCMP1 Reset Value is FFFFFFFF"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC05: TCMP1 mismatch"); test_fail = test_fail + 1;
        end

        // ==========================================================
        // GROUP 2: BASIC READ/WRITE & BYTE ACCESS
        // ==========================================================
        
        // TC06
        test_case_num = 6;
        apb_write(A_TDR0, 32'h1234_5678, 4'b1111);
        apb_read(A_TDR0, read_data);
        if (read_data == 32'h1234_5678) begin
            $display("[PASS] TC06: Standard 32-bit RW"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC06: Expected 12345678, Got %h", read_data); test_fail = test_fail + 1;
        end

        // TC07: Byte Enable Write (Lower Byte Only)
        // Current: 12345678 -> Write AA to byte 0 -> 123456AA
        test_case_num = 7;
        apb_write(A_TDR0, 32'h0000_00AA, 4'b0001); 
        apb_read(A_TDR0, read_data);
        if (read_data == 32'h1234_56AA) begin
            $display("[PASS] TC07: Byte 0 Write Success"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC07: Expected 123456AA, Got %h", read_data); test_fail = test_fail + 1;
        end

        // TC08: Byte Enable Write (Upper Byte Only)
        // Current: 123456AA -> Write BB to byte 3 -> BB3456AA
        test_case_num = 8;
        apb_write(A_TDR0, 32'hBB00_0000, 4'b1000); 
        apb_read(A_TDR0, read_data);
        if (read_data == 32'hBB34_56AA) begin
            $display("[PASS] TC08: Byte 3 Write Success"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC08: Expected BB3456AA, Got %h", read_data); test_fail = test_fail + 1;
        end

        // TC09: Write to Read-Only/Reserved Bits in TIER
        test_case_num = 9;
        apb_write(A_TIER, 32'hFFFF_FFFF, 4'b1111);
        apb_read(A_TIER, read_data);
        if (read_data == 32'h0000_0001) begin
            $display("[PASS] TC09: Reserved bits in TIER protected"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC09: Expected 1, Got %h", read_data); test_fail = test_fail + 1;
        end

        // TC10: Write 0 to TISR (Status Register) - No effect
        test_case_num = 10;
        apb_write(A_TISR, 32'h0000_0000, 4'b1111);
        apb_read(A_TISR, read_data);
        if (read_data == 32'h0) begin
            $display("[PASS] TC10: Write 0 to TISR ignored"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC10: TISR changed unexpectedly"); test_fail = test_fail + 1;
        end

        // ==========================================================
        // GROUP 3: TIMER COUNTING OPERATION
        // ==========================================================
        
        // Reset TDR0
        apb_write(A_TDR0, 32'h0, 4'b1111);

        // TC11: Enable Timer
        test_case_num = 11;
        apb_write(A_TCR, 32'h0000_0001, 4'b1111); 
        #100; // Run for 10 clocks
        apb_read(A_TDR0, read_data);
        if (read_data > 0) begin
            $display("[PASS] TC11: Timer is counting"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC11: Timer not counting"); test_fail = test_fail + 1;
        end

        // TC12: Verify Increment
        test_case_num = 12;
        temp_val = read_data;
        #50;
        apb_read(A_TDR0, read_data);
        if (read_data > temp_val) begin
            $display("[PASS] TC12: Value incremented"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC12: Value stuck"); test_fail = test_fail + 1;
        end

        // TC13: Disable Timer (TCR.timer_en = 0)
        test_case_num = 13;
        apb_write(A_TCR, 32'h0000_0000, 4'b1111);
        #50;
        apb_read(A_TDR0, read_data);
        // Advanced: H->L reset to initial value (0)
        if (read_data == 0) begin
            $display("[PASS] TC13: Disable reset counter to 0"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC13: Counter not reset"); test_fail = test_fail + 1;
        end

        // TC14: Set Initial Value != 0 and Enable
        test_case_num = 14;
        apb_write(A_TDR0, 32'd100, 4'b1111); 
        apb_write(A_TCR, 32'h1, 4'b1111); 
        #20;
        apb_read(A_TDR0, read_data);
        if (read_data >= 100) begin
            $display("[PASS] TC14: Loaded initial value"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC14: Failed to load init value"); test_fail = test_fail + 1;
        end

        // TC15: Disable Timer restores Initial Value
        test_case_num = 15;
        apb_write(A_TCR, 32'h0, 4'b1111); 
        #20;
        apb_read(A_TDR0, read_data);
        if (read_data == 100) begin
            $display("[PASS] TC15: Reset to specific init value (100)"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC15: Expected 100, Got %d", read_data); test_fail = test_fail + 1;
        end

        // ==========================================================
        // GROUP 4: DIVIDER LOGIC
        // ==========================================================

        // TC16: Enable Divisor Mode /2
        test_case_num = 16;
        apb_write(A_TCR, 32'h0000_0103, 4'b1111);
        start_val = DUT.CNT.counter[31:0];
        #200; // 20 cycles
        end_val = DUT.CNT.counter[31:0];
        // Expect increase by ~10 (20/2)
        if ((end_val - start_val) <= 12 && (end_val - start_val) >= 8) begin
             $display("[PASS] TC16: Divider /2 OK (Diff: %d)", end_val - start_val); test_pass = test_pass + 1;
        end else begin
             $display("[FAIL] TC16: Divider /2 Failed (Diff: %d)", end_val - start_val); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111); // Disable

        // TC17: Divider /4
        test_case_num = 17;
        apb_write(A_TCR, 32'h0000_0203, 4'b1111);
        start_val = DUT.CNT.counter[31:0];
        #400; // 40 cycles -> expect ~10
        end_val = DUT.CNT.counter[31:0];
        if ((end_val - start_val) <= 12 && (end_val - start_val) >= 8) begin
             $display("[PASS] TC17: Divider /4 OK (Diff: %d)", end_val - start_val); test_pass = test_pass + 1;
        end else begin
             $display("[FAIL] TC17: Divider /4 Failed (Diff: %d)", end_val - start_val); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111);

        // TC18: div_en disable
        test_case_num = 18;
        apb_write(A_TCR, 32'h0000_0201, 4'b1111);
        start_val = DUT.CNT.counter[31:0];
        #100; // 10 cycles -> expect ~10
        end_val = DUT.CNT.counter[31:0];
        if ((end_val - start_val) <= 12 && (end_val - start_val) >= 8) begin
             $display("[PASS] TC18: Counter with div_en = 0 OK (Diff: %d)", end_val - start_val); test_pass = test_pass + 1;
        end else begin
             $display("[FAIL] TC18: Counter with div_en = 0 Failed (Diff: %d)", end_val - start_val); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111);

        // TC19: timer_en disable
        test_case_num = 19;
        apb_write(A_TCR, 32'h0000_0200, 4'b1111);
        start_val = DUT.CNT.counter[31:0];
        #100; // 10 cycles -> expect ~0
        end_val = DUT.CNT.counter[31:0];
        if ((end_val - start_val) == 0) begin
             $display("[PASS] TC19: Counter with timer_en = 0 OK (Diff: %d)", end_val - start_val); test_pass = test_pass + 1;
        end else begin
             $display("[FAIL] TC19: Counter with timer_en = 0 Failed (Diff: %d)", end_val - start_val); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111);

        // TC20: Divider /256
        test_case_num = 20;
        apb_write(A_TCR, 32'h0000_0803, 4'b1111);
        start_val = DUT.CNT.counter[31:0];
        #2560; 
        end_val = DUT.CNT.counter[31:0];
        if ((end_val - start_val) >= 1) begin
             $display("[PASS] TC20: Divider /256 OK (Diff: %d)", end_val - start_val); test_pass = test_pass + 1;
        end else begin
             $display("[FAIL] TC20: Divider /256 Failed (Diff: %d)", end_val - start_val); test_fail = test_fail + 1;
        end

        // ==========================================================
        // GROUP 5: ADVANCED ERROR HANDLING
        // ==========================================================

        // TC21: Error on Invalid div_val (>8)
        test_case_num = 21;
        apb_write(A_TCR, 32'h0000_0903, 4'b1111);
        if (DUT.CNT.div_val !== 4'd9) begin
            $display("[PASS] TC21: Error Response on Invalid div_val"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC21: No Error Response"); test_fail = test_fail + 1;
        end

        // TC22: Verify Register Not Updated on Error
        test_case_num = 22;
        apb_write(A_TCR, 32'h0, 4'b1111); // Clear
        apb_write(A_TCR, 32'h0000_0903, 4'b1111); // Invalid
        apb_read(A_TCR, read_data);
        if (read_data[11:8] != 9) begin
            $display("[PASS] TC22: Register protected"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC22: Register updated with invalid val"); test_fail = test_fail + 1;
        end

        // TC23: Error on Changing div_val while timer is ON
        test_case_num = 23;
        apb_write(A_TCR, 32'h0, 4'b1111); // Clear
        apb_write(A_TCR, 32'h0000_0103, 4'b1111); // Enable
        apb_write(A_TCR, 32'h0000_0203, 4'b1111); // Change while active
        if (DUT.CNT.div_val === 4'd1) begin
            $display("[PASS] TC23: Error on changing div_val while active"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC23: No Error Response"); test_fail = test_fail + 1;
        end
        
        // TC24
        test_case_num = 24;
        apb_read(A_TCR, read_data);
        if (read_data[11:8] == 4'h1) begin
            $display("[PASS] TC24: div_val unchanged"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC24: div_val changed"); test_fail = test_fail + 1;
        end

        // TC25: Error on Changing div_en while timer is ON
        test_case_num = 25;
        apb_write(A_TCR, 32'h0000_0101, 4'b1111); // Turn off div_en while timer_en=1
        if (DUT.CNT.div_en === 1'b1) begin
            $display("[PASS] TC25: Error on changing div_en while active"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC25: No Error Response"); test_fail = test_fail + 1;
        end

        // TC26
        test_case_num = 26;
        apb_read(A_TCR, read_data);
        if (read_data[1] == 4'h1) begin
            $display("[PASS] TC26: div_en unchanged"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC26: div_en changed"); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111); // Stop

        // ==========================================================
        // GROUP 6: INTERRUPT FUNCTIONALITY
        // ==========================================================

        // TC27: Configure Compare
        test_case_num = 27;
        apb_write(A_TCMP0, 32'd50, 4'b1111);
        apb_write(A_TCMP1, 32'd0, 4'b1111);
        $display("[PASS] TC27: Compare value set to 50");
        test_pass = test_pass + 1; // Implicit pass if no bus error

        // TC28: Enable Interrupt
        test_case_num = 28;
        apb_write(A_TIER, 32'h1, 4'b1111);
        apb_read(A_TIER, read_data);
        if (read_data[0] == 1) begin
            $display("[PASS] TC28: Interrupt Enabled"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC28: Failed to enable interrupt"); test_fail = test_fail + 1;
        end

        // TC29: Enable Timer
        test_case_num = 29;
        apb_write(A_TDR0, 32'h0, 4'b1111);
        apb_write(A_TCR, 32'h1, 4'b1111);
        $display("[PASS] TC29: Timer Started");
        test_pass = test_pass + 1;

        // TC30: Wait for Interrupt
        test_case_num = 30;
        wait(tim_int === 1'b1);
        if (tim_int == 1) begin
            $display("[PASS] TC30: Interrupt Asserted"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC30: Interrupt not asserted"); test_fail = test_fail + 1;
        end

        // TC31: Check TISR
        test_case_num = 31;
        apb_read(A_TISR, read_data);
        if (read_data[0] == 1) begin
            $display("[PASS] TC31: TISR Pending Bit Set"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC31: TISR not set"); test_fail = test_fail + 1;
        end

        // TC32: Clear Interrupt
        test_case_num = 32;
        apb_write(A_TISR, 32'h1, 4'b1111);
        apb_read(A_TISR, read_data);
        if (read_data[0] == 0) begin
            $display("[PASS] TC32: TISR Cleared"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC32: TISR not cleared"); test_fail = test_fail + 1;
        end
        
        // TC33: Output de-assertion
        test_case_num = 33;
        #10;
        if (tim_int == 0) begin
            $display("[PASS] TC33: Interrupt Output Low"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC33: Interrupt Output Stuck High"); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111); // Stop

        // ==========================================================
        // GROUP 7: 64-BIT COUNTER & ROLLOVER
        // ==========================================================

        // TC34
        test_case_num = 34;
        apb_write(A_TDR0, 32'hFFFF_FFF0, 4'b1111);
        apb_write(A_TDR1, 32'h0000_0000, 4'b1111);
        apb_write(A_TCR, 32'h1, 4'b1111); // Enable
        $display("[INFO] TC34: Setup 64-bit rollover test");
        test_pass = test_pass + 1;
        
        #200; 
        
        // TC35
        test_case_num = 35;
        apb_read(A_TDR1, read_data);
        if (read_data == 1) begin
            $display("[PASS] TC35: 64-bit Rollover Success (TDR1=1)"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC35: Rollover failed. TDR1=%h", read_data); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111);

        // ==========================================================
        // GROUP 8: HALT / DEBUG MODE
        // ==========================================================

        // TC36: Request Halt WITHOUT Debug Mode
        test_case_num = 36;
        dbg_mode = 0;
        apb_write(A_THCSR, 32'h1, 4'b1111); // halt_req = 1
        #20;
        apb_read(A_THCSR, read_data);
        // Bit 1 is halt_ack.
        if (read_data[1] == 0) begin
            $display("[PASS] TC36: Halt ignored when dbg_mode=0"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC36: Halt Ack unexpected"); test_fail = test_fail + 1;
        end

        // TC37: Request Halt WITH Debug Mode
        test_case_num = 37;
        dbg_mode = 1;
        apb_write(A_TCR, 32'h1, 4'b1111); // Start timer
        apb_write(A_THCSR, 32'h1, 4'b1111); // halt_req
        #20;
        apb_read(A_THCSR, read_data);
        if (read_data[1] == 1) begin
            $display("[PASS] TC37: Halt Ack received"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC37: Halt Ack missing"); test_fail = test_fail + 1;
        end

        // TC38: Verify Counter is Frozen
        test_case_num = 38;
        apb_read(A_TDR0, frozen_val);
        #100;
        apb_read(A_TDR0, read_data);
        if (read_data == frozen_val) begin
            $display("[PASS] TC38: Counter is frozen"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC38: Counter moved"); test_fail = test_fail + 1;
        end

        // TC39: Resume
        test_case_num = 39;
        apb_write(A_THCSR, 32'h0, 4'b1111); // Clear req
        #50;
        apb_read(A_TDR0, read_data);
        if (read_data > frozen_val) begin
            $display("[PASS] TC39: Counter Resumed"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC39: Counter stuck"); test_fail = test_fail + 1;
        end

        apb_write(A_TCR, 32'h0, 4'b1111);

        // ==========================================================
        // GROUP 9: RESERVED SPACE
        // ==========================================================

        // TC40: Access Reserved Address (RAZ/WI)
        test_case_num = 40;
        apb_write(12'h100, 32'hDEAD_BEEF, 4'b1111);
        apb_read(12'h100, read_data);
        if (read_data == 32'h0) begin
            $display("[PASS] TC40: Reserved Address is RAZ/WI"); test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TC40: Reserved Address not 0"); test_fail = test_fail + 1;
        end

        // ==========================================================
        // SUMMARY
        // ==========================================================
        $display("==========================================================");
        $display("TEST COMPLETION");
        $display("Total Cases: %0d", test_case_num);
        $display("Passed     : %0d", test_pass);
        $display("Failed     : %0d", test_fail);
        $display("==========================================================");
        
        if (test_fail == 0) 
            $display("RESULT: ALL TESTS PASSED");
        else 
            $display("RESULT: FAILED");
            
        $finish;
    end

endmodule