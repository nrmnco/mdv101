
module bitty(
    input        run,         // Activate Bitty (high to enable)
    input        clk,
    input        reset,       // Active-low reset
    input [15:0] d_instr,     // Instruction input
    output[15:0] d_out,       // ALU output
    output       done,        // High when instruction is executed

    // UART communication ports (if handled within Bitty)
    input [7:0]  rx_data,
    input        rx_done,
    input        tx_done,
    output       tx_en,
    output[7:0]  tx_data,

    output [15:0] out [7:0]
);
    
    wire en_instr, en_s, en_c, en_0, en_1, en_2, en_3, en_4, en_5, en_6, en_7, cmp, cout, mem_alu, done_ls;
    wire [1:0] en_ls;
    wire [2:0] alu_sel;
    wire [3:0] mux_sel;
    wire [15:0] imm_val;
    wire [15:0] mux_out, alu_out, reg_s_out;

    wire [15:0] mux_ma_out, mem_read_data, reg0_out, reg1_out, reg2_out, reg3_out, reg4_out, reg5_out, reg6_out, reg7_out, reg_instr_out;

    always @(posedge clk) begin
        $display("instr: ", d_instr);
        $display("reg_instr_out: ", reg_instr_out);
        $display("en_i: ", en_instr);
        $display("run: ", run);
        $display("reset: ", reset);
        $display("alu_out: ", alu_out);
    end

    assign out[0] = reg0_out;
    assign out[1] = reg1_out;
    assign out[2] = reg2_out;
    assign out[3] = reg3_out;
    assign out[4] = reg4_out;
    assign out[5] = reg5_out;
    assign out[6] = reg6_out;
    assign out[7] = reg7_out;

    mem_alu_mux ma_mux(
        .en_mem(mem_alu),
        .memory_data(mem_read_data),
        .alu_data(d_out),
        .data(mux_ma_out)
    );
    
    lsu lsu_inst(
        .clk(clk),
        .reset(reset),
        .done_out(done_ls),
        
        .en_ls(en_ls),
        .address(mux_out[7:0]),
        .data_to_store(reg_s_out),
        .data_to_load(mem_read_data),

        .rx_do(rx_done),
        .rx_data(rx_data),
        .tx_done(tx_done),
        .tx_start_out(tx_en),
        .tx_data_out(tx_data)
    );

    control_unit control_inst(
        .clk(clk),
        .reset(reset),
        .d_in(reg_instr_out),
        .run(run),
        .done_ls(done_ls),
        .en_ls(en_ls),
        .imm_val(imm_val),
        .alu_sel(alu_sel),
        .mux_sel(mux_sel),
        .en_i(en_instr),
        .en_s(en_s),
        .en_c(en_c),
        .en_0(en_0),
        .en_1(en_1),
        .en_2(en_2),
        .en_3(en_3),
        .en_4(en_4),
        .en_5(en_5),
        .en_6(en_6),
        .en_7(en_7),
        .mem_alu(mem_alu),
        .done(done)
    );

    register reg_instr_inst(
        .clk(clk),
        .reset(reset), 
        .d_in(d_instr), 
        .en(en_instr),
        .d_out(reg_instr_out)
    );

    register reg_s_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_out),
        .en(en_s),
        .d_out(reg_s_out)
    );
    register reg_c_inst(
        .clk(clk),
        .reset(reset),
        .d_in(alu_out),
        .en(en_c),
        .d_out(d_out)
    );
    register reg0_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_0),
        .d_out(reg0_out)
    );
    register reg1_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_1),
        .d_out(reg1_out)
    );
    register reg2_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_2),
        .d_out(reg2_out)
    );
    register reg3_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_3),
        .d_out(reg3_out)
    );
    register reg4_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_4),
        .d_out(reg4_out)
    );
    register reg5_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_5),
        .d_out(reg5_out)
    );
    register reg6_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_6),
        .d_out(reg6_out)
    );
    register reg7_inst(
        .clk(clk),
        .reset(reset),
        .d_in(mux_ma_out),
        .en(en_7),
        .d_out(reg7_out)
    );

    mux mux_inst(
        .sel(mux_sel),
        .in0(reg0_out),
        .in1(reg1_out),
        .in2(reg2_out),
        .in3(reg3_out),
        .in4(reg4_out),
        .in5(reg5_out), 
        .in6(reg6_out),
        .in7(reg7_out),
        .imm_val(imm_val),
        .out(mux_out)
    );

    alu alu_inst(
        .in_a(reg_s_out),
        .in_b(mux_out),
        .sel(alu_sel),
        .out(alu_out)
    );


endmodule