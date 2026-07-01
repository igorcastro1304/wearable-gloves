`timescale 1ns/1ps

module deadzone_filter_tb;
    reg signed [7:0] raw_axis;
    reg [1:0] dpi_multiplier;
    wire signed [7:0] filtered_axis;

    deadzone_filter uut (
        .raw_axis(raw_axis),
        .dpi_multiplier(dpi_multiplier),
        .filtered_axis(filtered_axis)
    );

    initial begin
        $monitor("Time = %0t | Raw = %d | DPI_Multiplier = %d | Filtered = %d", $time, raw_axis, dpi_multiplier, filtered_axis);

        dpi_multiplier = 2'b01;

        raw_axis = 8'sd5;
        #10;

        raw_axis = -8'sd4;
        #10;

        raw_axis = 8'sd0;
        #10;

        raw_axis = 8'sd12;
        #10;
        
        raw_axis = -8'sd12;
        #10;

        dpi_multiplier = 2'b10;
        
        raw_axis = 8'sd12;
        #10;
    
        raw_axis = -8'sd12;
        #10;

        $finish;
    end
endmodule