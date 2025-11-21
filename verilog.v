module PIPELINE_RISC_CPU (
    input clk,
    input rst
);
    // --- OPCODES ---
    parameter ADD  = 6'b000001; // 1
    parameter SUB  = 6'b000010; // 2
    parameter AND  = 6'b000011; // 3
    parameter OR   = 6'b000100; // 4
    parameter LW   = 6'b000101; // 5
    parameter SW   = 6'b000110; // 6
    parameter JMP  = 6'b000111; // 7
    parameter ADDI = 6'b001000; // 8
    parameter BEQ  = 6'b001001; // 9
    // --- NEW OPCODES ---
    parameter MUL  = 6'b001010; // 10
    parameter DIV  = 6'b001011; // 11
    parameter XOR  = 6'b001100; // 12
    parameter NOR  = 6'b001101; // 13

    // --- PIPELINE REGISTERS ---
    reg [31:0] IF_ID_PC, IF_ID_IR;
    reg [31:0] ID_EX_PC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [5:0]  ID_EX_Op;
    reg [4:0]  ID_EX_Rd, ID_EX_Rs1, ID_EX_Rs2;
    reg [31:0] EX_MEM_ALUOut, EX_MEM_B;
    reg [5:0]  EX_MEM_Op;
    reg [4:0]  EX_MEM_Rd;
    reg [31:0] MEM_WB_MemOut, MEM_WB_ALUOut;
    reg [5:0]  MEM_WB_Op;
    reg [4:0]  MEM_WB_Rd;

    // --- MEMORY & REGISTERS ---
    reg [31:0] PC;
    reg [31:0] IM [0:63]; 
    reg [31:0] DM [0:63]; 
    reg [31:0] RF [0:31]; 

    // --- INTERNAL WIRES ---
    wire [31:0] IF_Instr;
    wire [31:0] ID_A, ID_B;
    reg  [31:0] ALU_Result;
    wire        Branch_Taken;
    
    integer i;

    // --- INITIALIZATION ---
    initial begin
        for(i=0; i<32; i=i+1) RF[i] = 0;
        PC = 0;
        IF_ID_IR = 0;
    end

    // =================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // =================================================
    assign IF_Instr = IM[PC]; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 0;
            IF_ID_IR <= 0;
            IF_ID_PC <= 0;
        end else begin
            if (Branch_Taken) begin
                PC <= ALU_Result; 
                IF_ID_IR <= 0; // Flush
                IF_ID_PC <= 0;
            end else begin
                PC <= PC + 1; 
                IF_ID_IR <= IF_Instr;
                IF_ID_PC <= PC;
            end
        end
    end

    // =================================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // =================================================
    assign ID_A = RF[IF_ID_IR[20:16]]; // Rs1
    assign ID_B = RF[IF_ID_IR[15:11]]; // Rs2

    always @(posedge clk or posedge rst) begin
        if (rst || Branch_Taken) begin
            ID_EX_Op <= 0; ID_EX_Rd <= 0; ID_EX_A <= 0; ID_EX_B <= 0; ID_EX_Imm <= 0;
        end else begin
            ID_EX_PC  <= IF_ID_PC;
            ID_EX_Op  <= IF_ID_IR[31:26];
            ID_EX_Rd  <= IF_ID_IR[25:21];
            ID_EX_Rs1 <= IF_ID_IR[20:16];
            ID_EX_Rs2 <= IF_ID_IR[15:11];
            ID_EX_A   <= ID_A;
            ID_EX_B   <= ID_B;
            ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
        end
    end

    // =================================================
    // STAGE 3: EXECUTE (EX)
    // =================================================
    always @(*) begin
        case (ID_EX_Op)
            ADD:  ALU_Result = ID_EX_A + ID_EX_B;
            SUB:  ALU_Result = ID_EX_A - ID_EX_B;
            AND:  ALU_Result = ID_EX_A & ID_EX_B;
            OR:   ALU_Result = ID_EX_A | ID_EX_B;
            ADDI: ALU_Result = ID_EX_A + ID_EX_Imm; 
            LW:   ALU_Result = ID_EX_Imm; 
            SW:   ALU_Result = ID_EX_Imm;
            JMP:  ALU_Result = ID_EX_Imm; 
            BEQ:  ALU_Result = ID_EX_PC + ID_EX_Imm; 
            
            // --- NEW LOGIC ---
            MUL:  ALU_Result = ID_EX_A * ID_EX_B;
            DIV:  if(ID_EX_B != 0) ALU_Result = ID_EX_A / ID_EX_B; else ALU_Result = 0;
            XOR:  ALU_Result = ID_EX_A ^ ID_EX_B;
            NOR:  ALU_Result = ~(ID_EX_A | ID_EX_B);

            default: ALU_Result = 0;
        endcase
    end

    assign Branch_Taken = (ID_EX_Op == JMP) || ((ID_EX_Op == BEQ) && (ID_EX_A == ID_EX_B));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            EX_MEM_Op <= 0; EX_MEM_Rd <= 0; EX_MEM_ALUOut <= 0; EX_MEM_B <= 0;
        end else if (Branch_Taken) begin
            EX_MEM_Op <= 0; 
        end else begin
            EX_MEM_Op     <= ID_EX_Op;
            EX_MEM_Rd     <= ID_EX_Rd;
            EX_MEM_ALUOut <= ALU_Result;
            
            // Fix for SW (Store Word) to get correct Data B
            if (ID_EX_Op == SW) 
                EX_MEM_B <= ID_EX_A; // Move Data from Rs1 to Write Port
            else
                EX_MEM_B <= ID_EX_B;
        end
    end

    // =================================================
    // STAGE 4: MEMORY ACCESS (MEM)
    // =================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_WB_Op <= 0; MEM_WB_Rd <= 0; MEM_WB_MemOut <= 0; MEM_WB_ALUOut <= 0;
        end else begin
            if (EX_MEM_Op == SW) begin
                DM[EX_MEM_ALUOut] <= EX_MEM_B;
            end
            if (EX_MEM_Op == LW) begin
                MEM_WB_MemOut <= DM[EX_MEM_ALUOut];
            end else begin
                MEM_WB_MemOut <= 0;
            end
            MEM_WB_Op     <= EX_MEM_Op;
            MEM_WB_Rd     <= EX_MEM_Rd;
            MEM_WB_ALUOut <= EX_MEM_ALUOut;
        end
    end

    // =================================================
    // STAGE 5: WRITE BACK (WB)
    // =================================================
    always @(posedge clk) begin
        if (!rst) begin
            case (MEM_WB_Op)
                ADD, SUB, AND, OR, ADDI, MUL, DIV, XOR, NOR: RF[MEM_WB_Rd] <= MEM_WB_ALUOut;
                LW: RF[MEM_WB_Rd] <= MEM_WB_MemOut;
            endcase
        end
    end

endmodule
