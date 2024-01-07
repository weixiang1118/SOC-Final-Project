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
        else if(i_irq && !stat_reg[1] && !i_frame_err)
            stat_reg[1:0] <= 2'b10;
        else if(i_rx_busy && stat_reg[1:0]==2'b10)
            stat_reg[4] <= 1'b1;
        else if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10) || i_frame_err)
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
        tx_fifo_wdata <=32'b0;
        tx_wr_en <= 1'b0;
    end else begin	     
        if(i_wb_valid && i_wb_we && !tx_full)begin
            tx_fifo_wdata <= i_wb_dat;
            tx_wr_en <= 1'b1;
        end
        else tx_wr_en<=1'b0;
    end
end
//tx fifo read 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_rd_en<=0;
    end else begin	     //i_wb_we
        if(i_wb_valid  && i_wb_adr==TX_DATA && !i_tx_busy && !tx_empty && stat_reg[3:2]==2'b01)begin
            tx_rd_en<=1;
        end
        else tx_rd_en <=0;
    end
end
//tx
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_buffer <= 32'h00000000;
        tx_start_local <= 1'b0;
    end else begin	     //i_wb_we
        if(i_wb_valid && tx_rd_en && i_wb_adr==TX_DATA && !i_tx_busy)begin
            tx_buffer <= tx_fifo_rdata;
            tx_start_local <= 1'b1;
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
        //rx_buffer <= 32'h00000000;
        rx_fifo_wdata <= 0;
        rx_wr_en <= 0;
    end else begin
        if(i_irq /*&& !stat_reg[1] */&& !i_frame_err && !rx_full)begin 
            //rx_buffer <= i_rx;
            rx_fifo_wdata <= {24'b0,i_rx};
            rx_wr_en <= 1;
            //$display("rx_buffer: %d", i_rx);
        end
        else 
        	  rx_wr_en <= 0;
    end
end
// rx read 
always@(*)begin
      if(i_wb_adr==RX_DATA) rx_rd_en = i_wb_valid;
      else rx_rd_en = 0;
end
/*always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_rd_en <= 1'b0;
    end else begin			     
        if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10 && !rx_empty) || i_frame_err)
            rx_rd_en<= 1'b1;
        else 
            rx_rd_en <= 1'b0;
    end
end*/

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_dat <= 32'h00000000;
    end else begin	     //! i_wb_we
        if(i_wb_valid && !i_wb_we)begin
            case(i_wb_adr)
                RX_DATA:begin
                    o_wb_dat <= rx_fifo_rdata;
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
        if((stat_reg[1:0]==2'b10 && rx_wr_en) || i_frame_err)
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
