module IIC_master
#(
    parameter FCLK = 200e6,
    parameter FSCL = 100e3
) 
(
    output reg       SCL,
    inout            SDA,

    input [7:0]      data_in,
    output reg [7:0] data_out,
    output reg       byte_done,
    output reg       ack_check,
    output reg       ack_check_vd,
    output reg       trans_done,
    output reg       trans_err, // if ack no receive
    input            start_flag,
    input            continue_flag,

    input            clk,
    input            rstn
    

);
//=====note======
//only 'state' reg has rst pin ,while ohthers do not
// Need sync release and sync reset
localparam IDLE  = 3'd0;
localparam START = 3'd1;
localparam DATA  = 3'd2;
localparam ACK   = 3'd3;
localparam STOP  = 3'd4;

localparam TRANS = 1'b0;
localparam RECV  = 1'b1;
localparam CNT_MAX = FCLK/(FSCL*2);

reg sda_out;
reg rw_flag; // 1:read 0:wirte
reg sda_out_en; // when master write  this value should be 1  
assign SDA = sda_out_en ? sda_out : 1'bz;

wire tx_trig;
wire rx_trig;
wire sta_trig;
wire cnt_clr;
assign cnt_clr  = cnt == CNT_MAX;
assign tx_trig  = (cnt == CNT_MAX/2-1) & (~SCL);
assign rx_trig  = (cnt == CNT_MAX/2-1) &   SCL ;
assign sta_trig = cnt_clr & SCL ;

reg [13:0] cnt;
reg [2:0] state; 
reg [2:0] bit_cnt;
reg [2:0] next_state;
reg trans_state;
reg first_ack;
wire byte_last;
assign byte_last = bit_cnt == 3'd0;
// ============ counter
always @(posedge clk ) begin   
    case(state)
    IDLE: cnt <= 14'd0;
    default: begin
        if(cnt_clr) begin
            cnt <= 14'd0;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end
    endcase
end
//=================================
//state machine=====================
always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        state <=  IDLE;
    end
    else begin
        state <= next_state;
    end
end
always @(*) begin
    case(state)
    IDLE : begin
        if(start_flag) begin
            next_state = START;
        end
        else begin
            next_state = IDLE;
        end
    end
    START: begin
        next_state = sta_trig ? DATA : START;
    end
    DATA : begin
        next_state = (byte_last&sta_trig) ? ACK : DATA;
    end
    ACK: begin
        case(trans_state)
        TRANS : begin
            if(sta_trig) begin
                next_state = continue_flag ? DATA : STOP; 
            end
        end
        RECV : begin
            if(sta_trig) begin
                if(ack_check) begin
                    next_state = start_flag ? START : (continue_flag ? DATA : STOP) ;
                end
                else begin
                    next_state = STOP;
                end
            end
        end
        endcase
    end 
    STOP:begin
        if(sta_trig)begin
            next_state = IDLE;
        end
    end
    default : next_state = IDLE;
    endcase
end




//===============================

//===============state out
always @(posedge clk) begin
    case(state)
    IDLE : rw_flag <= 1'b0;
    START: rw_flag <= 1'b0;
    DATA : rw_flag <= byte_last&sta_trig ? sda_out : rw_flag;
    endcase
end

always @(posedge clk) begin
    case(state)
    IDLE : first_ack <= 1'b1;
    START: first_ack <= 1'b1;
    ACK: begin
        first_ack <= sta_trig ? 1'b0: first_ack;
    end
    endcase
end
always @(posedge clk) begin
    case(state)
    IDLE: begin 
        ack_check    <=  1'b0; 
        ack_check_vd <=  1'b0;
    end
    ACK: begin
        ack_check    <= (trans_state==RECV)&rx_trig&(~SDA) ? 1'b1 : ack_check;
        ack_check_vd <= (trans_state==RECV)&rx_trig        ? 1'b1 : ack_check_vd;
    end       
    default : begin
        ack_check    <=  1'b0;
        ack_check_vd <=  1'b0;
    end 
    endcase
end
//transmission direction flag
always @(posedge clk ) begin
    case(state)
    IDLE : trans_state <= TRANS;
    START: trans_state <= TRANS;
    DATA : begin
        trans_state <= sta_trig&byte_last ? ~trans_state : trans_state;
    end
    ACK : begin
        if(first_ack) begin
            trans_state <= sta_trig ? (rw_flag ?  RECV : TRANS) : trans_state;
        end
        else begin
            trans_state <= sta_trig ? ~trans_state : trans_state;
        end
    end
    STOP:begin
        trans_state <= TRANS;
    end
    endcase
end
//==========================
always @(posedge clk) begin
    case(state)
    DATA: begin
        bit_cnt <= sta_trig ? bit_cnt - 1'b1 : bit_cnt;
    end
    default : bit_cnt <= 3'd7;
    endcase
end

// SCL output
always @(posedge clk ) begin
    case(state)
    IDLE : SCL <= 1'b1;
    STOP : SCL <= 1'b1 ? SCL : (cnt_clr ? ~SCL : SCL);
    default : SCL <= cnt_clr ? ~SCL : SCL ;
    endcase
end

// SDA inout logic
always @(posedge clk ) begin
    case(state)
    IDLE: begin 
        sda_out_en <= 1'b0;
        sda_out    <= 1'b1;
    end                          // SDA pin = z
    START : begin
        if(tx_trig) begin
           sda_out_en <= 1'b1; 
           sda_out    <= 1'b1; 
        end
        else if(rx_trig) begin  
            sda_out_en <= 1'b1; 
            sda_out    <= 1'b0; 
        end
    end
    DATA: begin
        case(trans_state)
        TRANS : begin
            if(tx_trig) begin
                sda_out_en <= 1'b1;
                sda_out    <= data_in[bit_cnt];
            end
            else if(sta_trig&byte_last) begin
                sda_out_en <= 1'b0;
            end
        end
        RECV: begin
            if(rx_trig) begin
                // sda_out_en        <=  1'b0;
                data_out[bit_cnt] <=  SDA;
            end
        end
        endcase
    end
    ACK:begin
        if(trans_state==TRANS) begin
            if(tx_trig) begin
                sda_out_en <=1'b1;
                sda_out    <= continue_flag ?   1'b0 : 1'b1;
            end
            else if(sta_trig) begin
                sda_out_en <=  continue_flag ?  1'b0 : sda_out_en;
            end
        end
    end
    STOP: begin
        if(tx_trig) begin
           sda_out_en <= 1'b1;
           sda_out    <= 1'b0; 
        end
        else if(rx_trig) begin
            sda_out    <= 1'b1;
        end
    end
    endcase
end

//for IIC controller 

always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        byte_done    <= 1'b0;
        trans_err    <= 1'b0;
        trans_done   <= 1'b0; 
    end
    else begin
        case(state)
        IDLE: begin
               byte_done    <= 1'b0;
               trans_err    <= 1'b0;
               trans_done   <= 1'b0; 
        end
        DATA : begin
            trans_done      <= 1'b0;
            trans_err       <= trans_err;
            byte_done       <= byte_last&sta_trig ? 1'b1 : byte_done;

        end
        ACK : begin
            byte_done    <= 1'b0;
            // drdy      <= 1'b0;
            trans_done<= 1'b0;
            if(trans_state==RECV) begin
                trans_err <= sta_trig&ack_check ? 1'b0 :  1'b1;
            end
        end
        STOP: begin
            byte_done     <= 1'b0;
            trans_done    <= sta_trig ? 1'b1 : 1'b0;
            trans_err     <= trans_err;
        end
        default: begin
            byte_done    <= 1'b0;
            trans_err    <= 1'b0;
            trans_done   <= 1'b0; 
        end    
        endcase
    end 
end


endmodule
