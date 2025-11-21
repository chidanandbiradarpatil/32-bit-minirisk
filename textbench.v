`timescale 1ns / 1ps

module pipeline_tb;

    reg clk;
    reg rst;
    
    integer user_input_A;
    integer user_input_B;
    integer operation_selector;

    PIPELINE_RISC_CPU uut ( .clk(clk), .rst(rst) );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("pipeline_wave.vcd");
        $dumpvars(0, pipeline_tb);

        rst = 1;
        #10;
        rst = 0;

        // =========================================
        // === USER INPUT SECTION =================
        // =========================================
        user_input_A = 10; 
        user_input_B = 5; 
        
        // 1=ADD, 2=SUB, 3=AND, 4=OR
        // 5=XOR, 6=NOR, 7=MUL, 8=DIV
        operation_selector = 8; // Currently: MUL

        // =========================================

        uut.DM[1] = user_input_A;
        uut.DM[2] = user_input_B;

        $display("------------------------------------------------");
        $display("PIPELINE INPUTS: A=%d, B=%d", user_input_A, user_input_B);
        if(operation_selector == 5) $display("OP: XOR");
        if(operation_selector == 6) $display("OP: NOR");
        if(operation_selector == 7) $display("OP: MUL");
        if(operation_selector == 8) $display("OP: DIV");
        $display("------------------------------------------------");

        // 1. Load A -> R1
        uut.IM[0] = {6'b000101, 5'd1, 5'd0, 16'd1}; 
        // 2. Load B -> R2
        uut.IM[1] = {6'b000101, 5'd2, 5'd0, 16'd2}; 

        // BUBBLES (Delay for Data Hazard)
        uut.IM[2] = 32'd0; uut.IM[3] = 32'd0; uut.IM[4] = 32'd0;

        // 3. Operation
        if (operation_selector == 1)      uut.IM[5] = {6'b000001, 5'd3, 5'd1, 5'd2, 11'd0}; // ADD
        else if (operation_selector == 2) uut.IM[5] = {6'b000010, 5'd3, 5'd1, 5'd2, 11'd0}; // SUB
        else if (operation_selector == 3) uut.IM[5] = {6'b000011, 5'd3, 5'd1, 5'd2, 11'd0}; // AND
        else if (operation_selector == 4) uut.IM[5] = {6'b000100, 5'd3, 5'd1, 5'd2, 11'd0}; // OR
        else if (operation_selector == 5) uut.IM[5] = {6'b001100, 5'd3, 5'd1, 5'd2, 11'd0}; // XOR (Op 12)
        else if (operation_selector == 6) uut.IM[5] = {6'b001101, 5'd3, 5'd1, 5'd2, 11'd0}; // NOR (Op 13)
        else if (operation_selector == 7) uut.IM[5] = {6'b001010, 5'd3, 5'd1, 5'd2, 11'd0}; // MUL (Op 10)
        else if (operation_selector == 8) uut.IM[5] = {6'b001011, 5'd3, 5'd1, 5'd2, 11'd0}; // DIV (Op 11)

        // BUBBLES (Delay for Result)
        uut.IM[6] = 32'd0; uut.IM[7] = 32'd0; uut.IM[8] = 32'd0;

        // 4. Store Result
        // Op:SW, Rd:0, Rs1:3 (Data R3), Imm:5 (Addr)
        uut.IM[9] = {6'b000110, 5'd0, 5'd3, 16'd5};

        #300; 

        $display("------------------------------------------------");
        $display("FINAL PIPELINE RESULT: %d", uut.DM[5]);
        $display("------------------------------------------------");
        $finish;
    end

endmodule
