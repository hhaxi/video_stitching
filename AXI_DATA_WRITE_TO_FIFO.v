module axi_write_ctrl#(
//===========================================================================================================
//参数设置
//===========================================================================================================
parameter AXI_DATA_WIDTH = 128
)
(
//===========================================================================================================
//端口声明
//===========================================================================================================



input  wire                        M_AXI_CLK,
input  wire                        M_AXI_RESETN,

input  wire                        cam_pclk,
input  wire                        cam_rst_n,
input  wire                        cam_vsync,
input  wire                        cam_href,
input  wire [23:0]                 cam_data,
input  wire                        cam_data_valid,

output reg                         fifo_enable,       


output wire [AXI_DATA_WIDTH-1:0]     M_AXI_AWDATA_OUT,
output reg                           M_AXI_BURST_VALID,
input  wire                          M_AXI_BURST_READY



);


//=============================================================================================================
// Module implementation goes here
//=============================================================================================================

reg [AXI_DATA_WIDTH-1:0]     cam_data_buffer;
reg [2:0]                    buf_cnt;
reg                          cam_href_d1 ;
reg                          cam_href_d2 ;
reg                          cam_vsync_d1;
reg                          cam_vsync_d2;

assign M_AXI_AWDATA_OUT   =   cam_data_buffer;


//将rgb888的数据补充成32位后转128位的axi数据宽度
always @(posedge cam_pclk or negedge cam_rst_n) begin
    if(!cam_rst_n) begin
        buf_cnt    <=  0;
    end
    else if(cam_data_valid) begin
        buf_cnt    <=  (buf_cnt == (AXI_DATA_WIDTH / 32) -1) ? 0 : buf_cnt + 1;
    end
end

always@(posedge cam_pclk or negedge cam_rst_n) begin
    if(!cam_rst_n) begin
        cam_data_buffer    <=  0;
    end
    else if(cam_data_valid) begin
        cam_data_buffer    <=  {cam_data_buffer[AXI_DATA_WIDTH-32-1:0],8'hff,cam_data};
    end
end

//生成fifo_enable信号
always@(posedge cam_pclk or negedge cam_rst_n) begin
    if(!cam_rst_n) begin
        fifo_enable    <=  0;
    end
    else if(cam_data_valid & (buf_cnt == (AXI_DATA_WIDTH / 32) -1)) begin
        fifo_enable    <=  1;
    end
    else begin
        fifo_enable    <=  0;
    end
end

//生成M_AXI_BURST_VALID信号

//生成数据有效信号的时序对齐
reg                          cam_data_valid_d1;
reg                          cam_data_valid_d2;
always@(posedge M_AXI_CLK or negedge M_AXI_RESETN) begin
    if(!M_AXI_RESETN) begin
        cam_href_d1 <=  0;
        cam_href_d2 <=  0;
        cam_data_valid_d1 <=  0;
        cam_data_valid_d2 <=  0;

    end 
    else begin
        cam_href_d1 <=  cam_href;
        cam_href_d2 <=  cam_href_d1;
        cam_data_valid_d1 <=  cam_data_valid;
        cam_data_valid_d2 <=  cam_data_valid_d1;
    end

end

//有效信号生成
reg                         data_valid_flag;

always @(posedge M_AXI_CLK or negedge M_AXI_RESETN ) begin
    if (!M_AXI_RESETN) begin
        data_valid_flag <=  0;
    end 
    else if(cam_data_valid_d2)begin
        data_valid_flag <=  1;
    end
    //在一帧数据结束时清除data_valid_flag
    else if({cam_href_d1,cam_href_d2} == 2'b01) begin
        data_valid_flag <=  0;
    end

end

//生成M_AXI_BURST_VALID信号
always@(posedge M_AXI_CLK or negedge M_AXI_RESETN) begin
    if (!M_AXI_RESETN) begin
        M_AXI_BURST_VALID <=  0;
    end 
    //在一帧数据结束时产生突发传输有效信号
    else if(({cam_href_d1,cam_href_d2} == 2'b01) & data_valid_flag)begin
        M_AXI_BURST_VALID <=  1;
    end
    //在突发传输被接受后清除突发有效信号
    else if(M_AXI_BURST_VALID & M_AXI_BURST_READY) begin
        M_AXI_BURST_VALID <=  0;
    end
end

endmodule