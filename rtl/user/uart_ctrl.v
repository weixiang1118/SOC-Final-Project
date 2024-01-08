module ctrl(
    input wire        rst_n,
    input wire        clk,
    input wire        i_wb_valid,
    input wire [31:0] i_wb_adr,
    input wire        i_wb_we,
    input wire [31:0] i_wb_dat,
    input wire [3:0]  i_wb_sel,
    output reg        o_wb_ack,
    output reg [31:0] o_wb_dat, 
     
    input wire [7:0]  i_rx,
    input wire        i_irq,
    input wire        i_rx_busy,
    input wire        i_frame_err,
    output reg        o_rx_finish,
    input wire        done,
    
    output reg [7:0]  o_tx,
    input wire        i_tx_start_clear,
    input wire        i_tx_busy,
    output reg        o_tx_start,
    
    // tx fifo 
    output reg [31:0] tx_fifo_wdata,
    output reg         tx_wr_en,
    output reg 	   tx_rd_en,
    input  wire [31:0] tx_fifo_rdata,
    input wire 	   tx_full,
    input wire    	   tx_empty,
    
    //rx fifo 
    output reg [31:0] rx_fifo_wdata,
    output reg         rx_wr_en,
    output reg 	   rx_rd_en,
    input  wire [31:0] rx_fifo_rdata,
    input wire 	   rx_full,
    input wire    	   rx_empty
);

// Declare the UART memory mapped registers address
localparam RX_DATA  = 32'h3000_0000;

localparam TX_DATA	= 32'h3000_0004;

localparam STAT_REG = 32'h3000_0008;

//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|RX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|TX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|STAT_REG|  RESERVERD  |  Frame Err  |  Overrun Err  |  Tx_full  |  Tx_empty  |  Rx_full  |  Rx_empty |
//|        |    31-6     |  5          |  4            |  3        |  2         |  1        |  0        |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+

reg [31:0] rx_buffer;
reg [31:0] tx_buffer;
reg [31:0] stat_reg;    
reg tx_start_local;
reg [31:0] fifo_rx_buffer;
wire read;
wire write;
reg rd_buffer;
reg [1:0] count;
assign read = (i_wb_adr==TX_DATA && i_wb_valid && i_wb_we)? 1: 0;
assign write = (i_wb_adr==RX_DATA && i_wb_valid && !i_wb_we)? 1: 0;

always@(posedge clk or negedge rst_n)begin
	if(!rst_n) 
		count <= 0;
	else if (i_irq) count<= 0;
	else if (rx_rd_en) 
		count <= count +1;
	else    count <= count;



end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        stat_reg <= 32'h0000_0005; //0101  tx rx empty
    end else begin
        if(i_wb_valid && !i_wb_we)begin  	//
            if(i_wb_adr==STAT_REG)
                stat_reg[5:4] <= 2'b00;
        end

        if(i_tx_busy)
            stat_reg[3:2] <= 2'b10;
        else
            stat_reg[3:2] <= 2'b01;

        if(i_frame_err && i_rx_busy)
            stat_reg[5] <= 1'b1;
        else if(done && !stat_reg[1] && !i_frame_err) // 01
            stat_reg[1:0] <= 2'b10;
        else if((/*i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we*/ i_rx_busy && stat_reg[1:0]==2'b10) || i_frame_err)
            stat_reg[1:0] <= 2'b01;
        else if(i_rx_busy && stat_reg[1:0]==2'b10)
            stat_reg[4] <= 1'b1;
        else if((/*i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we*/ i_rx_busy && stat_reg[1:0]==2'b10) || i_frame_err)
            stat_reg[1:0] <= 2'b01;
    end
end
/*  
    ******************************************
    ******************************************
	TX FIFO 
    ******************************************
    ******************************************                  
*/
//tx fifo write
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rd_buffer<= 0;
    end else begin	     
        if(i_wb_valid && rx_rd_en)
            rd_buffer <= 1;
        else
            rd_buffer <= 0;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        tx_fifo_wdata <=32'b0;
        tx_wr_en <= 1'b0;
    end else begin	     
        if(rd_buffer && !tx_full)begin
            tx_fifo_wdata <= rx_fifo_rdata;
            tx_wr_en <= 1'b1;
        end
        else begin
            tx_fifo_wdata <= tx_fifo_wdata;
            tx_wr_en<=1'b0;
        end
    end
end
/*always@(*)begin
    if(!rst_n)begin
        tx_fifo_wdata <=32'b0;
        tx_wr_en <= 1'b0;
    end else begin	     
        if(rx_rd_en /*&& i_wb_we && !tx_full)begin
            tx_fifo_wdata <= rx_fifo_rdata;
            tx_wr_en <= 1'b1;
        end
        else begin
            tx_fifo_wdata <= tx_fifo_wdata;
            tx_wr_en<=1'b0;
        end
    end
end*/
//tx fifo read 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_rd_en<=0;
    end else begin
        if (tx_rd_en) tx_rd_en <= 0;	     
        else if(/*i_wb_valid && i_wb_we && i_wb_adr==TX_DATA &&*/ !i_tx_busy && !tx_empty && stat_reg[3:2]==2'b01 && !tx_start_local )begin
            tx_rd_en<=1;
        end
        else tx_rd_en <=0;
    end
end
//tx
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_start_local <= 1'b0;
    end else begin	     //i_wb_we
        if(tx_rd_en  && !i_tx_busy)begin
            tx_start_local <= 1'b1;
        end
    end 
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_buffer <= 32'h00000000;
    end else begin	     
        if(tx_start_local)begin
            tx_buffer <= tx_fifo_rdata;
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        o_tx <= 8'b0;
        o_tx_start <= 1'b0;
    end else begin
        o_tx <= tx_buffer[7:0];
        o_tx_start <= tx_start_local;
    end
end
/*
   ********************************************
   ********************************************
   	RX FIFO
   ********************************************
   ********************************************
*/


// RX write in rx fifo
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_fifo_wdata <= 0;
        rx_wr_en <= 0;
    end else begin
        if(done && !stat_reg[1] && !i_frame_err && !rx_full)begin   //rx can write in fifo rx finish
            rx_fifo_wdata <= {24'b0,i_rx};
            rx_wr_en <= 1;
            //$display("rx_buffer: %d", i_rx);
        end
        else 
            rx_wr_en <= 0;
    end
end
// rx read 
/*always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_rd_en <= 1'b0;
    end else begin			     
        if((o_rx_finish && stat_reg[1:0]==2'b10 && !rx_empty) || i_frame_err)
            rx_rd_en<= 1'b1;
        else 
            rx_rd_en <= 1'b0;
    end
end*/
/*always@(*)begin
    if(!rst_n)
        rx_rd_en = 1'b0;
    else if (rx_rd_en) rx_rd_en = 0;
    else if(!rx_empty)rx_rd_en = i_wb_valid;
    else rx_rd_en = 1'b0;

end*/
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_rd_en <= 1'b0;
    end else begin
    	if(rx_rd_en) rx_rd_en <= 1'b0;			     
        else if(i_wb_valid && !rx_empty && count !=2)
            rx_rd_en<= 1'b1;
        else 
            rx_rd_en <= 1'b0;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fifo_rx_buffer <= 0;
    end else begin	
    	fifo_rx_buffer <= rx_fifo_rdata;
    end
end


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_dat <= 32'h00000000;
    end else begin	     //! i_wb_we
        if(i_wb_valid && !i_wb_we)begin
            case(i_wb_adr)
                RX_DATA:begin
                    o_wb_dat <= fifo_rx_buffer;
                end
                STAT_REG:begin
                	o_wb_dat <=stat_reg;
                end
                default:begin 
                    o_wb_dat <= 32'h00000000;
                end
            endcase
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_rx_finish <= 1'b0;
    end else begin			     
        if((stat_reg[1:0]==2'b10 && rx_wr_en && !i_rx_busy)  || i_frame_err)
            o_rx_finish <= 1'b1;
        else 
            o_rx_finish <= 1'b0;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_ack <= 1'b0;
    end else begin
        if(i_wb_valid)  
            o_wb_ack <= 1'b1;
        else            
            o_wb_ack <= 1'b0;
    end
end

endmodule
