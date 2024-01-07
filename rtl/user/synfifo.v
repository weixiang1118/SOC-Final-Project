module synfifo#(
	parameter depth = 8
)(
	input clk,
	input rst,
	input wr_en,
	input rd_en,
	input [31:0] wr_data,
	output reg [31:0] rd_data,
	output wire fifo_full,
	output wire fifo_empty
);

	reg [31:0] mem [depth-1:0];
	reg [2:0] wr_ptr;
	reg [2:0] rd_ptr;
	reg [2:0] cnt;
	
	integer i;
	// write pointer 
	always@(posedge clk or negedge rst)begin
		if(!rst) wr_ptr <= 0;
		//else if(fifo_empty) wr_ptr<= 0;
		else if (wr_en && !fifo_full) wr_ptr <= wr_ptr +1'b1;
		else wr_ptr <= wr_ptr;	
	
	end
	// read pointer
	always@(posedge clk or negedge rst)begin
		if(!rst) rd_ptr <= 0;
		//else if(fifo_empty) rd_ptr<= 0;
		else if (rd_en && !fifo_empty) rd_ptr <= rd_ptr +1'b1;
		else rd_ptr <= rd_ptr;	
	end
	// data write in fifo
	always@(posedge clk or negedge rst)begin
		if(!rst) begin
			for(i=0;i<depth;i=i+1) mem[i] <= 32'b0;
		end
		else if(wr_en) mem[wr_ptr] <= wr_data;
		else mem[wr_ptr] <= mem[wr_ptr];
	end
	// data read from fifo
	always@(posedge clk or negedge rst)begin
		if(!rst) rd_data <= 32'b0;
		else if(rd_en) rd_data <= mem[rd_ptr];
		else rd_data <= rd_data;
	end
	// determining whether it is empty or full
	always@(posedge clk or negedge rst)begin
		if(!rst) cnt <= 3'b0;
		else if(wr_en && !rd_en && !fifo_full) cnt <= cnt +1'b1;
		else if(!wr_en && rd_en && !fifo_empty) cnt <= cnt -1'b1;
		else cnt <= cnt;
	end
	
	assign fifo_full = (cnt==depth) ? 1 : 0;
	assign fifo_empty = (cnt==0) ? 1 : 0;
	
	
	
	
	
endmodule 


