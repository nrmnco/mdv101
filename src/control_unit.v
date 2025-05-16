module control_unit(
    input clk,
    input reset,
    input [15:0] d_in,
    input done_ls,
    input run,
    output reg [1:0] en_ls,
    output reg [15:0] imm_val,
    output reg [2:0] alu_sel,
    output reg [3:0] mux_sel,
    output reg mem_alu,
    output reg en_s,
    output reg en_c,
    output reg en_0,
    output reg en_1,
    output reg en_2,
    output reg en_3,
    output reg en_4,
    output reg en_5,
    output reg en_6,
    output reg en_7,
    output reg en_i,
    output reg done
);
    parameter STATE0 = 2'b00, STATE1 = 2'b01, STATE2 = 2'b10, STATE3 = 2'b11;

    reg [1:0] state, next_state;

    assign imm_val = {{8{1'b0}}, d_in[12:5]};
    
    always @(posedge clk or negedge reset) begin
      if (!reset) begin
            // $display("resetting");
            state <= STATE0;
      end
      else if (run) begin
            state <= next_state;
            $display("-------------");
            $display("immval: ", imm_val);
            $display("en_i cu: ", en_i);
            $display("instr: ", d_in);
            $display("state: ", state);
            $display("-------------");
      end else begin
            state <= STATE0;
      end
    end

    //next_state logic
    always @(*) begin
        case(state)
            STATE0: next_state = STATE1;
            STATE1: next_state = STATE2;
            STATE2: next_state = (d_in[1:0] != 2'b11) ? STATE3 : (done_ls) ? STATE3 : STATE2;
            STATE3: next_state = STATE0;
        endcase
    end
    
  //main logic
  always @(*) begin
        done = 1'b0;
        en_i = 1'b0;
        en_s = 1'b0;
        en_c = 1'b0;
        en_0 = 1'b0;
        en_1 = 1'b0;
        en_2 = 1'b0;
        en_3 = 1'b0;
        en_4 = 1'b0;
        en_5 = 1'b0;
        en_6 = 1'b0;
        en_7 = 1'b0;
        mux_sel = 4'b0;
        alu_sel = 3'b0;
        en_ls = 2'b00;
        mem_alu = 1'b0;

        case(state)
            STATE0: begin
                en_i = 1'b1;
            end
            STATE1: begin
                mux_sel = {1'b0, d_in[15:13]};
                en_s = 1'b1;
            end
            STATE2: begin
                if (d_in[1:0] == 2'b11) begin
                    en_ls = (d_in[2] == 1'b0) ? 2'b01 : 2'b10;
                    en_c = 1'b0;
                end else begin
                    en_c = 1'b1;
                end
                
                alu_sel = d_in[4:2];
                if (d_in[1:0] == 2'b01) begin
                    mux_sel = 4'b1000;
                end
                else begin
                    mux_sel = {1'b0, d_in[12:10]};
                end
            end
            STATE3: begin
                if (d_in[1:0] == 2'b11) begin
                    mem_alu = 1'b1;
                end

                if (d_in[2:0] != 3'b111) begin
                    case(d_in[15:13])
                        3'b000: en_0 = 1'b1;
                        3'b001: en_1 = 1'b1;
                        3'b010: en_2 = 1'b1;
                        3'b011: en_3 = 1'b1;
                        3'b100: en_4 = 1'b1;
                        3'b101: en_5 = 1'b1;
                        3'b110: en_6 = 1'b1;
                        3'b111: en_7 = 1'b1;
                    endcase
                end
                done = 1'b1;
            end
        endcase
    end

endmodule