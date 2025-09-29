module iic_mst_ctrl (
    input [6:0]  addr_slv,
    input [7:0]  addr_reg,
    input        rwn,
    input [4:0]  rw_len,
    input        mst_start_pulse,
    output reg   mst_trans_done,
    input [7:0]  wdata,
    output       wdy,
    output reg [7:0] rdata,
    output       rdy,
    output reg   mst_trans_err,

//IIC port
    output reg       IIC_start,
    output reg       IIC_continue_pulse,
    input            IIC_ack_check,
    input            IIC_ack_check_valid,
    input            IIC_byte_done,
    input            IIC_trans_done,
    input            IIC_trans_err,
    input [7:0]      IIC_rdata,
    output reg [7:0] IIC_wdata,
//======================
    input clk,
    input rstn



);
localparam IDLE      = 3'd0;
localparam ADDR_SLV  = 3'd1;
localparam SLV_CHECK = 3'd2;
localparam ADDR_REG  = 3'd3;
localparam REG_CHECK = 3'd4;
localparam DATA      = 3'd5;
localparam DATA_CHECK= 3'd6;
localparam DONE      = 3'd7;


reg start;
reg continue_pulse;
reg rw_flag;
reg[2:0] state;
reg [2:0] next_state;
reg [4:0] rw_cnt;
reg re_start_flag;
reg rw_done;
wire rw_last;
assign rw_last = rw_cnt==5'd0;

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
    IDLE      :     next_state = mst_start_pulse ? ADDR_SLV : IDLE;
    ADDR_SLV  :     next_state = IIC_byte_done ? SLV_CHECK  : ADDR_SLV  ;
    SLV_CHECK : begin
        if(IIC_ack_check_valid) begin
            next_state = IIC_ack_check ? ((~re_start_flag&rw_flag) ?  DATA : ADDR_REG ) 
                                       : DONE; 
        end
        else begin
            next_state = SLV_CHECK;
        end
    end
    ADDR_REG  :     next_state = IIC_byte_done ? REG_CHECK : ADDR_REG; 
    REG_CHECK : begin
        if(IIC_ack_check_valid) begin
            next_state = IIC_ack_check ? (re_start_flag&rw_flag ?   ADDR_SLV : DATA)
                                       : DONE;
        end     
        else begin
            next_state = REG_CHECK;
        end
    end 
    DATA      :   next_state = IIC_byte_done ? DATA_CHECK : DATA;
    DATA_CHECK: begin
        if(rw_flag) begin
            next_state = rw_done ? DONE : DATA;
        end
        else begin
            if(IIC_ack_check_valid) begin
                next_state = IIC_ack_check&(~rw_done) ? DATA :DONE;
            end
            else begin
                next_state = DATA_CHECK;
            end
        end
    end
    DONE  :   next_state = IDLE;
    default : next_state = IDLE;
    endcase
end

always @(posedge clk) begin
    case(state)
    IDLE : begin
        rw_flag        <= 1'b0;
        start          <= 1'b0;
        re_start_flag  <= 1'b0;
        continue_pulse <= 1'b0;
        rw_cnt         <= 5'd0;
        IIC_wdata      <= 8'd0;
    end
    ADDR_SLV:begin
        rw_flag         <= rwn;
        start           <= 1'b1;
        re_start_flag   <= re_start_flag ?  (rw)
        rw_cnt          <= rw_len;
        continue_pulse  <= 1'b0;
        IIC_wdata       <= {addr_slv,1'b1};
        
    end

    endcase
end





endmodule
