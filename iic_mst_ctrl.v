module iic_mst_ctrl (
// application  ports
    input [6:0]      addr_slv,
    input [7:0]      addr_reg,
    input            rwn,
    input [4:0]      rw_len,
    input            mst_start_pulse,
    output reg       mst_trans_done,
    input [7:0]      mst_wdata,
    output           mst_wdy,
    output reg [7:0] mst_rdata,
    output reg       mst_rdy,
    output reg       mst_trans_err,

//IIC ports
    output reg       IIC_start,
    output reg       IIC_continue_flag,
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



reg rw_flag;
reg[2:0] state;
reg [2:0] next_state;
reg [4:0] rw_cnt;
reg re_start_flag;
reg rw_done;
reg reg_addr_done;
reg wdy_flag;
reg wdy_flag_dy1;
wire rw_last;
assign rw_last = rw_cnt==5'd0;
assign mst_wdy = wdy_flag&~wdy_flag_dy1;



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
            next_state = IIC_ack_check ? (rw_flag ?   ADDR_SLV : DATA)
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
    DONE  :   next_state = IIC_trans_done ? IDLE : DONE;
    default : next_state = IDLE;
    endcase
end

always @(posedge clk ) begin
    case(state)
    IDLE: wdy_flag_dy1 <=1'b0;
    default : wdy_flag_dy1 <= wdy_flag;
    endcase
end
always @(posedge clk ) begin
    case(state)
    IDLE    : mst_trans_err  <= 1'b0;
    default : mst_trans_err  <= IIC_trans_done ? IIC_trans_err : mst_trans_err ;
    endcase
end
always @(posedge clk ) begin
    case(state)
    IDLE    : mst_trans_done  <= 1'b0;
    default : mst_trans_done  <= IIC_trans_done;
    endcase
end

always @(posedge clk) begin
    case(state)
    IDLE: begin
        rw_flag             <= 1'b0;
        IIC_start           <= 1'b0;
        re_start_flag       <= 1'b0;
        reg_addr_done       <= 1'b0;        
    end
    ADDR_SLV: begin
        rw_flag             <= rwn;
        IIC_start           <= reg_addr_done ? IIC_start : 1'b1;
        re_start_flag       <= reg_addr_done ? 1'b0 : rwn ;                   
        reg_addr_done       <= 1'b0;
    end
    SLV_CHECK: IIC_start    <= 1'b0;
    REG_CHECK: begin
        reg_addr_done       <= 1'b1 ;
        IIC_start           <= re_start_flag ;
    end
    DONE: begin
        rw_flag             <= 1'b0;
        IIC_start           <= 1'b0;
        re_start_flag       <= 1'b0;
        reg_addr_done       <= 1'b0;
    end
    endcase
end

always @(posedge clk) begin
    case(state)
    IDLE: begin
        IIC_continue_flag   <= 1'b0;
        rw_cnt          <= 5'd0;
        rw_done         <= 1'b0;
    end
    ADDR_SLV: begin
        rw_cnt          <= rw_len;
        IIC_continue_flag   <= 1'b1;
    end
    DATA: begin
        if(IIC_byte_done) begin
            rw_cnt        <= rw_last ? rw_cnt : rw_cnt - 1'b1;
            IIC_continue_flag <= rw_last ? 1'b0 : 1'b1;
            rw_done       <= rw_last ; 
        end
    end
    DONE : begin
        IIC_continue_flag   <= 1'b0;
        rw_cnt          <= 5'd0;
        rw_done         <= 1'b0;
    end
    endcase
end

always @(posedge clk) begin
    case(state)
    IDLE: begin
        IIC_wdata <= 8'd0;
        mst_rdata <= 8'd0;
        mst_rdy   <= 1'b0;
        wdy_flag  <= 1'b0;
    end
    ADDR_SLV: begin
        IIC_wdata <= reg_addr_done ?  {addr_slv,1'b1} : {addr_slv,1'b0};
    end
    SLV_CHECK: ;
    ADDR_REG: begin
        IIC_wdata <= {addr_reg,1'b0};
    end
    REG_CHECK: begin
        wdy_flag <= IIC_ack_check ? ~rw_flag : 1'b0; 
    end
    DATA: begin
        if(rw_flag) begin
            mst_rdata <= IIC_byte_done ? IIC_rdata : mst_rdata;
            mst_rdy   <= IIC_byte_done;
        end
        else begin
            IIC_wdata <=  wdy_flag ? mst_wdata : IIC_wdata;
            wdy_flag  <= 1'b0;
        end
    end
    DATA_CHECK: begin
        wdy_flag <= IIC_ack_check ? ~rw_flag : 1'b0;
    end
    DONE: begin
        wdy_flag <= 1'b0;
        mst_rdy  <= 1'b0;
    end
    endcase
end




endmodule
