//	dtg.v - Horizontal & Vertical Display Timing & Sync generator for VESA timing
//	1024 * 768 working
//	Version:		2.0	
//	Author:			Srivatsa Yogendra, John Lynch & Roy Kravitz
//	Last Modified:	20-Sep-2017
//	
//	 Revision History
//	 ----------------
//	 02-Feb-06		JDL	Added video_on output; simplified counter logic
//	 25-Oct-12		Modified for kcpsm6 and Nexys3
//   20-Sep-17		Modified the design, to produce signals for 1024*768 resolution
//
//	Description:
//	------------
//	 This circuit provides pixel location and horizontal and 
//	 vertical sync for a 1024 x 768 video image. 
//	
//	 Inputs:
//			clock           - 75MHz Clock
//			rst             - Active-high synchronous reset
//	 Outputs:
//			horiz_sync_out	- Horizontal sync signal to display
//			vert_sync_out	- Vertical sync signal to display
//			Pixel_row		- (12 bits) current pixel row address
//			Pixel_column	- (12 bits) current pixel column address
//			video_on        - 1 = in active video area; 0 = blanking;
//			
//////////

module dtg(
	input				clock, rst,
	output	reg			horiz_sync, vert_sync, video_on,		
	output	reg	[11:0]	pixel_row, pixel_column
);

// Timing parameters (for 75MHz pixel clock and 1024 x 768 display)

parameter
		HORIZ_PIXELS = 1024,  HCNT_MAX  = 1327, 		
		HSYNC_START  = 1053,  HSYNC_END = 1189,

		VERT_PIXELS  = 768,  VCNT_MAX  = 805,
		VSYNC_START  = 773,  VSYNC_END = 779;
			
// generate video signals and pixel counts
always @(posedge clock) begin
	if (rst) begin
		pixel_column <= 0;
		pixel_row    <= 0;
		horiz_sync   <= 0;
		vert_sync    <= 0;
		video_on     <= 0;
	end
	else begin
		// increment horizontal sync counter.  Wrap if at end of row
		if (pixel_column == HCNT_MAX)	
			pixel_column <= 12'd0;
		else	
			pixel_column <= pixel_column + 12'd1;
			
		// increment vertical sync ounter.  Wrap if at end of display.  Increment if end of row
		if ((pixel_row >= VCNT_MAX) && (pixel_column >= HCNT_MAX))
			pixel_row <= 12'd0;
		else if (pixel_column == HCNT_MAX)
			pixel_row <= pixel_row + 12'd1;
									
		// generate active-low horizontal sync pulse
		horiz_sync <=  ~((pixel_column >= HSYNC_START) && (pixel_column <= HSYNC_END));
			
		// generate active-low vertical sync pulse
		vert_sync <= ~((pixel_row >= VSYNC_START) && (pixel_row <= VSYNC_END));
			
		// generate the video_on signals and the pixel counts
		video_on <= ((pixel_column < HORIZ_PIXELS) && (pixel_row < VERT_PIXELS));
	end
	
	
end // always
	
endmodule
