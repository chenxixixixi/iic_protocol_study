module iic_mst_ctrl (
    input [6:0]  addr_slv,
    input [7:0]  addr_reg,
    input        rwn,
    input [4:0]  rw_len,
    input        mst_start_pulse,
    output reg   mst_trans_done,
    input [7:0]  wdata,
    output       wdy,
    output [7:0] rdata,
    output       rdy,
    output reg   mst_trans_err,

//IIC port
    output reg       IIC_start_pulse,
    output reg       IIC_continue_pulse,
    input            IIC_w_byte_done,
    input            IIC_trans_done,
    input            IIC_trans_err,
    input            IIC_r_byte_rdy,
    input [7:0]      IIC_rdata,
    output reg [7:0] IIC_wdata,
//======================
    input clk,
    input rstn



);
localparam IDLE  = 3'd0;
localparam START = 3'd1;
localparam ADDR  = 3'd2;
localparam DATA  = 3'd4;
localparam STOP  = 3'd5;

reg start_pulse;
reg continue_pulse;
reg rw_flag;
reg[2:0] state;
reg [2:0] next_state;

always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end
always @(*) begin
    case(state)
    IDLE  :  next_state = mst_start_pulse ? ADDR : IDLE;
    ADDR  : begin
        next_state = IIC_start_pulse ? DATA : ADDR;
    end
    DATA  : begin
        
    end
    endcase
end







endmodule
