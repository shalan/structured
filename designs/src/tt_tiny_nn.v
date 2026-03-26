// tt_tiny_nn.v — Single-file TT design wrapped for SASIC fabric
`default_nettype none
module fp_add (
	op_a_i,
	op_b_i,
	result_o
);
	reg _sv2v_0;
	localparam tiny_nn_pkg_FPExpWidth = 8;
	localparam tiny_nn_pkg_FPMantWidth = 7;
	input wire [15:0] op_a_i;
	input wire [15:0] op_b_i;
	output reg [15:0] result_o;
	reg [15:0] op_x;
	reg [15:0] op_y;
	localparam FPMantWidthExt = 11;
	wire [10:0] op_x_full_mant;
	wire [10:0] op_y_full_mant;
	wire [10:0] op_y_full_mant_signed;
	wire [10:0] op_x_full_mant_signed;
	wire signed [10:0] foo;
	wire [10:0] op_y_full_mant_signed_shifted;
	reg [6:0] op_y_dropped_bits;
	wire [7:0] full_mant_shift;
	wire [2:0] mant_shift;
	wire [10:0] mant_add_signed;
	reg [10:0] mant_add;
	wire mant_add_sign;
	wire [tiny_nn_pkg_FPMantWidth:0] mant_add_norm_all [0:9];
	reg [tiny_nn_pkg_FPMantWidth:0] mant_add_norm;
	wire [6:0] mant_final;
	reg [2:0] exp_change;
	wire [6:0] result_mant;
	wire [7:0] result_exp;
	always @(*) begin
		if (_sv2v_0)
			;
		if (op_a_i[14-:8] >= op_b_i[14-:8]) begin
			op_x = op_a_i;
			op_y = op_b_i;
		end
		else begin
			op_x = op_b_i;
			op_y = op_a_i;
		end
	end
	assign op_x_full_mant = {3'b001, op_x[6-:tiny_nn_pkg_FPMantWidth], 1'b0};
	assign op_y_full_mant = {3'b001, op_y[6-:tiny_nn_pkg_FPMantWidth], 1'b0};
	assign full_mant_shift = op_x[14-:8] - op_y[14-:8];
	assign mant_shift = full_mant_shift[2:0];
	assign op_x_full_mant_signed = (op_x[15] ? ~(op_x_full_mant - 1'b1) : op_x_full_mant);
	assign op_y_full_mant_signed = (op_y[15] ? ~(op_y_full_mant - 1'b1) : op_y_full_mant);
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		op_y_dropped_bits = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < tiny_nn_pkg_FPMantWidth; i = i + 1)
				if (mant_shift >= sv2v_cast_3_signed(i + 1))
					op_y_dropped_bits[i] = op_y_full_mant_signed[i];
		end
	end
	assign foo = $signed(op_y_full_mant_signed) >>> mant_shift;
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	assign op_y_full_mant_signed_shifted = (full_mant_shift <= sv2v_cast_8_signed(tiny_nn_pkg_FPMantWidth) ? $unsigned(foo) : {FPMantWidthExt {1'b0}});
	assign mant_add_signed = op_x_full_mant_signed + $unsigned(op_y_full_mant_signed_shifted);
	assign mant_add_sign = mant_add_signed[10];
	always @(*) begin
		if (_sv2v_0)
			;
		if (mant_add_sign) begin
			if (|op_y_dropped_bits && (full_mant_shift <= sv2v_cast_8_signed(tiny_nn_pkg_FPMantWidth)))
				mant_add = ~mant_add_signed;
			else
				mant_add = ~mant_add_signed + 1'b1;
		end
		else
			mant_add = mant_add_signed;
	end
	genvar _gv_i_norm_1;
	generate
		for (_gv_i_norm_1 = 0; _gv_i_norm_1 < 10; _gv_i_norm_1 = _gv_i_norm_1 + 1) begin : g_norm
			localparam i_norm = _gv_i_norm_1;
			if (i_norm == 9) begin : genblk1
				assign mant_add_norm_all[i_norm] = mant_add[i_norm:2];
			end
			else if (i_norm == 8) begin : genblk1
				assign mant_add_norm_all[i_norm] = mant_add[i_norm:1];
			end
			else begin : genblk1
				localparam [31:0] BottomFillWidth = tiny_nn_pkg_FPMantWidth - i_norm;
				assign mant_add_norm_all[i_norm] = {mant_add[i_norm:0], {BottomFillWidth {1'b0}}};
			end
		end
	endgenerate
	always @(*) begin
		if (_sv2v_0)
			;
		exp_change = 1'sb0;
		mant_add_norm = 1'sb0;
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < 10; i = i + 1)
				if (mant_add[i]) begin
					mant_add_norm = mant_add_norm_all[i];
					if (i <= tiny_nn_pkg_FPMantWidth)
						exp_change = sv2v_cast_3_signed(tiny_nn_pkg_FPMantWidth - i);
				end
		end
	end
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign result_exp = (mant_add[9] ? op_x[14-:8] + 1'b1 : (mant_add[8] ? op_x[14-:8] : (op_x[14-:8] - 1'b1) - sv2v_cast_8(exp_change)));
	assign result_mant = mant_add_norm[6:0];
	function automatic [7:0] sv2v_cast_1B4FD;
		input reg [7:0] inp;
		sv2v_cast_1B4FD = inp;
	endfunction
	function automatic [6:0] sv2v_cast_938D1;
		input reg [6:0] inp;
		sv2v_cast_938D1 = inp;
	endfunction
	localparam [15:0] tiny_nn_pkg_FPNegInf = {1'b1, sv2v_cast_1B4FD(1'sb1), sv2v_cast_938D1(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPPosInf = {1'b0, sv2v_cast_1B4FD(1'sb1), sv2v_cast_938D1(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPStdNaN = {1'b1, sv2v_cast_1B4FD(1'sb1), sv2v_cast_938D1(1'sb1)};
	localparam [15:0] tiny_nn_pkg_FPZero = {1'b0, sv2v_cast_1B4FD(1'sb0), sv2v_cast_938D1(1'sb0)};
	function tiny_nn_pkg_is_inf;
		input reg [15:0] x;
		tiny_nn_pkg_is_inf = (x == tiny_nn_pkg_FPPosInf) || (x == tiny_nn_pkg_FPNegInf);
	endfunction
	function tiny_nn_pkg_is_nan;
		input reg [15:0] x;
		if (x[14-:8] == {8 {1'sb0}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else if (x[15] == 1'b1)
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else if (x[14-:8] == {8 {1'sb1}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else
			tiny_nn_pkg_is_nan = 1'b0;
	endfunction
	function automatic [7:0] sv2v_cast_76516;
		input reg [7:0] inp;
		sv2v_cast_76516 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_5FAF8;
		input reg [6:0] inp;
		sv2v_cast_5FAF8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (tiny_nn_pkg_is_nan(op_a_i) || tiny_nn_pkg_is_nan(op_b_i))
			result_o = tiny_nn_pkg_FPStdNaN;
		else if (tiny_nn_pkg_is_inf(op_a_i) && tiny_nn_pkg_is_inf(op_b_i)) begin
			if (op_a_i[15] != op_b_i[15])
				result_o = tiny_nn_pkg_FPStdNaN;
			else
				result_o = op_a_i;
		end
		else if (tiny_nn_pkg_is_inf(op_a_i))
			result_o = op_a_i;
		else if (tiny_nn_pkg_is_inf(op_b_i))
			result_o = op_b_i;
		else if (op_a_i == tiny_nn_pkg_FPZero)
			result_o = op_b_i;
		else if (op_b_i == tiny_nn_pkg_FPZero)
			result_o = op_a_i;
		else if (mant_add_signed == {11 {1'sb0}})
			result_o = tiny_nn_pkg_FPZero;
		else if (mant_add[9] && (op_x[14-:8] == (tiny_nn_pkg_FPPosInf[14-:8] - 1'b1)))
			result_o = (mant_add_sign ? tiny_nn_pkg_FPNegInf : tiny_nn_pkg_FPPosInf);
		else if ((mant_add[8+:2] == {2 {1'sb0}}) && ((1'b1 + sv2v_cast_8(exp_change)) >= op_x[14-:8]))
			result_o = tiny_nn_pkg_FPZero;
		else
			result_o = {mant_add_sign, sv2v_cast_76516(result_exp), sv2v_cast_5FAF8(result_mant)};
	end
	initial _sv2v_0 = 0;
endmodule
module fp_mul (
	op_a_i,
	op_b_i,
	result_o
);
	reg _sv2v_0;
	localparam tiny_nn_pkg_FPExpWidth = 8;
	localparam tiny_nn_pkg_FPMantWidth = 7;
	input wire [15:0] op_a_i;
	input wire [15:0] op_b_i;
	output reg [15:0] result_o;
	wire [tiny_nn_pkg_FPMantWidth:0] op_a_full_mant;
	wire [tiny_nn_pkg_FPMantWidth:0] op_b_full_mant;
	wire [15:0] mant_mul;
	wire [tiny_nn_pkg_FPExpWidth:0] exp_add;
	wire [tiny_nn_pkg_FPExpWidth:0] exp_add_raw;
	wire [6:0] result_mant;
	wire [7:0] result_exp;
	wire result_sgn;
	wire shift_output_mant;
	assign op_a_full_mant = {1'b1, op_a_i[6-:tiny_nn_pkg_FPMantWidth]};
	assign op_b_full_mant = {1'b1, op_b_i[6-:tiny_nn_pkg_FPMantWidth]};
	assign mant_mul = op_a_full_mant * op_b_full_mant;
	assign exp_add_raw = (op_a_i[14-:8] + op_b_i[14-:8]) + (shift_output_mant ? {{tiny_nn_pkg_FPExpWidth {1'b0}}, 1'b1} : {9 {1'sb0}});
	assign exp_add = exp_add_raw - {2'b00, {7 {1'b1}}};
	assign shift_output_mant = mant_mul[15];
	assign result_mant = (shift_output_mant ? mant_mul[14:8] : mant_mul[13:tiny_nn_pkg_FPMantWidth]);
	assign result_exp = exp_add[7:0];
	assign result_sgn = op_a_i[15] ^ op_b_i[15];
	function automatic [7:0] sv2v_cast_47BAE;
		input reg [7:0] inp;
		sv2v_cast_47BAE = inp;
	endfunction
	function automatic [6:0] sv2v_cast_53328;
		input reg [6:0] inp;
		sv2v_cast_53328 = inp;
	endfunction
	localparam [15:0] tiny_nn_pkg_FPNegInf = {1'b1, sv2v_cast_47BAE(1'sb1), sv2v_cast_53328(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPPosInf = {1'b0, sv2v_cast_47BAE(1'sb1), sv2v_cast_53328(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPStdNaN = {1'b1, sv2v_cast_47BAE(1'sb1), sv2v_cast_53328(1'sb1)};
	localparam [15:0] tiny_nn_pkg_FPZero = {1'b0, sv2v_cast_47BAE(1'sb0), sv2v_cast_53328(1'sb0)};
	function tiny_nn_pkg_is_inf;
		input reg [15:0] x;
		tiny_nn_pkg_is_inf = (x == tiny_nn_pkg_FPPosInf) || (x == tiny_nn_pkg_FPNegInf);
	endfunction
	function tiny_nn_pkg_is_nan;
		input reg [15:0] x;
		if (x[14-:8] == {8 {1'sb0}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else if (x[15] == 1'b1)
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else if (x[14-:8] == {8 {1'sb1}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else
			tiny_nn_pkg_is_nan = 1'b0;
	endfunction
	function automatic [7:0] sv2v_cast_76516;
		input reg [7:0] inp;
		sv2v_cast_76516 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_5FAF8;
		input reg [6:0] inp;
		sv2v_cast_5FAF8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = tiny_nn_pkg_FPStdNaN;
		if (tiny_nn_pkg_is_nan(op_a_i) || tiny_nn_pkg_is_nan(op_b_i))
			result_o = tiny_nn_pkg_FPStdNaN;
		else if ((op_a_i == tiny_nn_pkg_FPZero) || (op_b_i == tiny_nn_pkg_FPZero))
			result_o = tiny_nn_pkg_FPZero;
		else if (tiny_nn_pkg_is_inf(op_a_i) || tiny_nn_pkg_is_inf(op_b_i))
			result_o = (result_sgn ? tiny_nn_pkg_FPNegInf : tiny_nn_pkg_FPPosInf);
		else if (exp_add_raw <= {2'b00, {7 {1'b1}}})
			result_o = tiny_nn_pkg_FPZero;
		else if (exp_add >= {1'b0, {tiny_nn_pkg_FPExpWidth {1'b1}}})
			result_o = (result_sgn ? tiny_nn_pkg_FPNegInf : tiny_nn_pkg_FPPosInf);
		else
			result_o = {result_sgn, sv2v_cast_76516(result_exp), sv2v_cast_5FAF8(result_mant)};
	end
	initial _sv2v_0 = 0;
endmodule
module fp_cmp (
	op_a_i,
	op_b_i,
	op_a_greater_o,
	invalid_nan_o
);
	reg _sv2v_0;
	localparam tiny_nn_pkg_FPExpWidth = 8;
	localparam tiny_nn_pkg_FPMantWidth = 7;
	input wire [15:0] op_a_i;
	input wire [15:0] op_b_i;
	output reg op_a_greater_o;
	output reg invalid_nan_o;
	function automatic [7:0] sv2v_cast_56368;
		input reg [7:0] inp;
		sv2v_cast_56368 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_0AB16;
		input reg [6:0] inp;
		sv2v_cast_0AB16 = inp;
	endfunction
	localparam [15:0] tiny_nn_pkg_FPZero = {1'b0, sv2v_cast_56368(1'sb0), sv2v_cast_0AB16(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPNegInf = {1'b1, sv2v_cast_56368(1'sb1), sv2v_cast_0AB16(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPPosInf = {1'b0, sv2v_cast_56368(1'sb1), sv2v_cast_0AB16(1'sb0)};
	function tiny_nn_pkg_is_inf;
		input reg [15:0] x;
		tiny_nn_pkg_is_inf = (x == tiny_nn_pkg_FPPosInf) || (x == tiny_nn_pkg_FPNegInf);
	endfunction
	function tiny_nn_pkg_is_nan;
		input reg [15:0] x;
		if (x[14-:8] == {8 {1'sb0}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else if (x[15] == 1'b1)
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else if (x[14-:8] == {8 {1'sb1}}) begin
			if (x[6-:tiny_nn_pkg_FPMantWidth] != {7 {1'sb0}})
				tiny_nn_pkg_is_nan = 1'b1;
			else
				tiny_nn_pkg_is_nan = 1'b0;
		end
		else
			tiny_nn_pkg_is_nan = 1'b0;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		op_a_greater_o = 1'b0;
		invalid_nan_o = 1'b0;
		if (tiny_nn_pkg_is_nan(op_a_i) || tiny_nn_pkg_is_nan(op_b_i))
			invalid_nan_o = 1'b1;
		else if (op_a_i == op_b_i)
			op_a_greater_o = 1'b0;
		else if (tiny_nn_pkg_is_inf(op_a_i))
			op_a_greater_o = (op_a_i[15] ? 1'b0 : 1'b1);
		else if (tiny_nn_pkg_is_inf(op_b_i))
			op_a_greater_o = (op_b_i[15] ? 1'b1 : 1'b0);
		else if (op_a_i == tiny_nn_pkg_FPZero)
			op_a_greater_o = (op_b_i[15] ? 1'b1 : 1'b0);
		else if (op_b_i == tiny_nn_pkg_FPZero)
			op_a_greater_o = (op_a_i[15] ? 1'b0 : 1'b1);
		else if (op_a_i[15] != op_b_i[15])
			op_a_greater_o = (op_a_i[15] ? 1'b0 : 1'b1);
		else if (op_a_i[14-:8] > op_b_i[14-:8])
			op_a_greater_o = (op_a_i[15] ? 1'b0 : 1'b1);
		else if (op_a_i[14-:8] < op_b_i[14-:8])
			op_a_greater_o = (op_a_i[15] ? 1'b1 : 1'b0);
		else if (op_a_i[6-:tiny_nn_pkg_FPMantWidth] > op_b_i[6-:tiny_nn_pkg_FPMantWidth])
			op_a_greater_o = (op_a_i[15] ? 1'b0 : 1'b1);
	end
	initial _sv2v_0 = 0;
endmodule
module tiny_nn_core (
	clk_i,
	rst_ni,
	val_i,
	val_shift_i,
	param_i,
	param_write_i,
	mul_row_sel_i,
	mul_en_i,
	accumulate_loopback_i,
	accumulate_out_relu_i,
	mul_add_op_a_din_i,
	mul_add_op_b_din_i,
	mul_add_op_a_en_i,
	mul_add_op_b_en_i,
	accumulate_level_0_din_i,
	accumulate_level_0_en_i,
	accumulate_mode_0_en_i,
	accumulate_mode_1_en_i,
	accumulate_mode_2_en_i,
	accumulate_o
);
	reg _sv2v_0;
	parameter [31:0] ValArrayWidth = 4;
	parameter [31:0] ValArrayHeight = 2;
	input clk_i;
	input rst_ni;
	localparam tiny_nn_pkg_FPExpWidth = 8;
	localparam tiny_nn_pkg_FPMantWidth = 7;
	input wire [15:0] val_i;
	input wire [ValArrayHeight - 1:0] val_shift_i;
	input wire [15:0] param_i;
	input wire [(ValArrayHeight * ValArrayWidth) - 1:0] param_write_i;
	input wire mul_row_sel_i;
	input wire mul_en_i;
	input wire accumulate_loopback_i;
	input wire accumulate_out_relu_i;
	input wire [15:0] mul_add_op_a_din_i;
	input wire [15:0] mul_add_op_b_din_i;
	input wire mul_add_op_a_en_i;
	input wire mul_add_op_b_en_i;
	input wire [15:0] accumulate_level_0_din_i;
	input accumulate_level_0_en_i;
	input wire [1:0] accumulate_mode_0_en_i;
	input wire [1:0] accumulate_mode_1_en_i;
	input wire [1:0] accumulate_mode_2_en_i;
	output wire [15:0] accumulate_o;
	reg [15:0] mul_val_op_q [0:ValArrayWidth - 1][0:ValArrayHeight - 1];
	reg [15:0] param_val_op_q [0:ValArrayWidth - 1][0:ValArrayHeight - 1];
	genvar _gv_y_1;
	generate
		for (_gv_y_1 = 0; _gv_y_1 < ValArrayHeight; _gv_y_1 = _gv_y_1 + 1) begin : genblk1
			localparam y = _gv_y_1;
			genvar _gv_x_1;
			for (_gv_x_1 = 0; _gv_x_1 < ValArrayWidth; _gv_x_1 = _gv_x_1 + 1) begin : genblk1
				localparam x = _gv_x_1;
				always @(posedge clk_i)
					if (param_write_i[(x * ValArrayHeight) + y])
						param_val_op_q[x][y] <= param_i;
				if (x == (ValArrayWidth - 1)) begin : genblk1
					always @(posedge clk_i)
						if (val_shift_i[y])
							mul_val_op_q[x][y] <= val_i;
				end
				else begin : genblk1
					always @(posedge clk_i)
						if (val_shift_i[y])
							mul_val_op_q[x][y] <= mul_val_op_q[x + 1][y];
				end
			end
		end
	endgenerate
	wire [15:0] mul_op_a [0:ValArrayWidth - 1];
	wire [15:0] mul_op_b [0:ValArrayWidth - 1];
	wire [15:0] mul_result [0:ValArrayWidth - 1];
	genvar _gv_x_2;
	generate
		for (_gv_x_2 = 0; _gv_x_2 < ValArrayWidth; _gv_x_2 = _gv_x_2 + 1) begin : genblk2
			localparam x = _gv_x_2;
			assign mul_op_a[x] = (mul_row_sel_i ? mul_val_op_q[x][0] : mul_val_op_q[x][1]);
			assign mul_op_b[x] = (mul_row_sel_i ? param_val_op_q[x][0] : param_val_op_q[x][1]);
			fp_mul u_mul(
				.op_a_i(mul_op_a[x]),
				.op_b_i(mul_op_b[x]),
				.result_o(mul_result[x])
			);
		end
	endgenerate
	wire [(ValArrayWidth / 2) - 1:0] mul_add_op_a_en;
	wire [(ValArrayWidth / 2) - 1:0] mul_add_op_b_en;
	reg [15:0] mul_add_op_a_q [0:(ValArrayWidth / 2) - 1];
	wire [15:0] mul_add_op_a_d [0:(ValArrayWidth / 2) - 1];
	reg [15:0] mul_add_op_b_q [0:(ValArrayWidth / 2) - 1];
	wire [15:0] mul_add_op_b_d [0:(ValArrayWidth / 2) - 1];
	wire [15:0] mul_add_op_a [0:(ValArrayWidth / 2) - 1];
	wire [15:0] mul_add_result [0:(ValArrayWidth / 2) - 1];
	wire [(ValArrayWidth / 2) - 1:0] accumulate_level_0_en;
	reg [15:0] accumulate_level_0_q [0:(ValArrayWidth / 2) - 1];
	wire [15:0] accumulate_level_0_d [0:(ValArrayWidth / 2) - 1];
	genvar _gv_x_3;
	generate
		for (_gv_x_3 = 0; _gv_x_3 < (ValArrayWidth / 2); _gv_x_3 = _gv_x_3 + 1) begin : g_accumulate_level_0_inner
			localparam x = _gv_x_3;
			if (x == 1) begin : genblk1
				assign mul_add_op_a_d[x] = (mul_add_op_a_en_i ? mul_add_op_a_din_i : mul_result[x * 2]);
				assign mul_add_op_b_d[x] = (mul_add_op_b_en_i ? mul_add_op_b_din_i : mul_result[(x * 2) + 1]);
				assign mul_add_op_a_en[x] = mul_en_i | mul_add_op_a_en_i;
				assign mul_add_op_b_en[x] = mul_en_i | mul_add_op_b_en_i;
				assign mul_add_op_a[x] = (accumulate_loopback_i ? accumulate_level_0_q[x] : mul_add_op_a_q[x]);
			end
			else begin : genblk1
				assign mul_add_op_a_d[x] = mul_result[x * 2];
				assign mul_add_op_b_d[x] = mul_result[(x * 2) + 1];
				assign mul_add_op_a_en[x] = mul_en_i;
				assign mul_add_op_b_en[x] = mul_en_i;
				assign mul_add_op_a[x] = mul_add_op_a_q[x];
			end
			always @(posedge clk_i)
				if (mul_add_op_a_en[x])
					mul_add_op_a_q[x] <= mul_add_op_a_d[x];
			always @(posedge clk_i)
				if (mul_add_op_b_en[x])
					mul_add_op_b_q[x] <= mul_add_op_b_d[x];
			fp_add u_add(
				.op_a_i(mul_add_op_a[x]),
				.op_b_i(mul_add_op_b_q[x]),
				.result_o(mul_add_result[x])
			);
			if (x == 0) begin : genblk2
				assign accumulate_level_0_en[x] = accumulate_level_0_en_i | accumulate_mode_0_en_i[0];
				assign accumulate_level_0_d[x] = (accumulate_level_0_en_i ? accumulate_level_0_din_i : mul_add_result[x]);
			end
			else begin : genblk2
				assign accumulate_level_0_en[x] = (accumulate_mode_2_en_i[0] | accumulate_mode_1_en_i[0]) | accumulate_mode_0_en_i[0];
				assign accumulate_level_0_d[x] = mul_add_result[x];
			end
			always @(posedge clk_i)
				if (accumulate_level_0_en[x])
					accumulate_level_0_q[x] <= accumulate_level_0_d[x];
		end
	endgenerate
	wire [15:0] accumulate_level_0_result;
	reg [15:0] accumulate_level_1_q [0:ValArrayHeight - 1];
	wire [ValArrayHeight - 1:0] accumulate_level_1_en;
	fp_add u_add(
		.op_a_i(accumulate_level_0_q[0]),
		.op_b_i(accumulate_level_0_q[1]),
		.result_o(accumulate_level_0_result)
	);
	genvar _gv_y_2;
	generate
		for (_gv_y_2 = 0; _gv_y_2 < ValArrayHeight; _gv_y_2 = _gv_y_2 + 1) begin : genblk4
			localparam y = _gv_y_2;
			assign accumulate_level_1_en[y] = accumulate_mode_0_en_i[0] & (mul_row_sel_i == y);
			always @(posedge clk_i)
				if (accumulate_level_1_en[y])
					accumulate_level_1_q[y] <= accumulate_level_0_result;
		end
	endgenerate
	reg [15:0] accumulate_final_q;
	reg [15:0] accumulate_final_d;
	wire [15:0] accumulate_final_result;
	wire accumulate_final_en;
	fp_add u_add_accumulate_final(
		.op_a_i(accumulate_level_1_q[0]),
		.op_b_i(accumulate_level_1_q[1]),
		.result_o(accumulate_final_result)
	);
	function automatic [7:0] sv2v_cast_F6E28;
		input reg [7:0] inp;
		sv2v_cast_F6E28 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_F0E0A;
		input reg [6:0] inp;
		sv2v_cast_F0E0A = inp;
	endfunction
	localparam [15:0] tiny_nn_pkg_FPZero = {1'b0, sv2v_cast_F6E28(1'sb0), sv2v_cast_F0E0A(1'sb0)};
	always @(*) begin
		if (_sv2v_0)
			;
		if (accumulate_mode_1_en_i[1]) begin
			if (accumulate_out_relu_i && accumulate_level_0_result[15])
				accumulate_final_d = tiny_nn_pkg_FPZero;
			else
				accumulate_final_d = accumulate_level_0_result;
		end
		else if (accumulate_mode_2_en_i[1])
			accumulate_final_d = mul_add_result[1];
		else
			accumulate_final_d = accumulate_final_result;
	end
	assign accumulate_final_en = (accumulate_mode_0_en_i[1] | accumulate_mode_1_en_i[1]) | accumulate_mode_2_en_i[1];
	always @(posedge clk_i)
		if (accumulate_final_en)
			accumulate_final_q <= accumulate_final_d;
	assign accumulate_o = accumulate_final_q;
	initial _sv2v_0 = 0;
endmodule
module tiny_nn_top (
	clk_i,
	rst_ni,
	data_i,
	data_o
);
	reg _sv2v_0;
	parameter [31:0] ValArrayWidth = 4;
	parameter [31:0] ValArrayHeight = 2;
	input clk_i;
	input rst_ni;
	input wire [15:0] data_i;
	output wire [7:0] data_o;
	localparam [31:0] ValArraySize = ValArrayWidth * ValArrayHeight;
	localparam [31:0] CountWidth = 8;
	reg phase_q;
	reg phase_d;
	reg [7:0] counter_q;
	reg [7:0] counter_d;
	reg [7:0] start_count_q;
	reg [7:0] start_count_d;
	reg [ValArraySize - 1:0] param_write_q;
	reg [ValArraySize - 1:0] param_write_d;
	reg relu_q;
	reg relu_d;
	reg convolve_run;
	localparam tiny_nn_pkg_FPExpWidth = 8;
	localparam tiny_nn_pkg_FPMantWidth = 7;
	reg [15:0] max_val_q;
	reg [15:0] max_val_d;
	reg [7:0] max_val_skid_q;
	reg [7:0] max_val_skid_d;
	reg [ValArrayHeight - 1:0] core_val_shift;
	reg core_mul_row_sel;
	reg core_mul_en;
	wire [15:0] core_accumulate_result;
	reg core_mul_add_op_a_en;
	reg core_mul_add_op_b_en;
	reg [1:0] core_accumulate_mode_0_en;
	reg [1:0] core_accumulate_mode_1_en;
	reg [1:0] core_accumulate_mode_2_en;
	reg core_accumulate_loopback;
	reg core_accumulate_out_relu;
	reg core_accumulate_level_0_en;
	wire data_i_q_is_greater;
	reg [15:0] data_i_q;
	reg [7:0] data_o_d;
	reg [7:0] data_o_q;
	reg [4:0] state_q;
	reg [4:0] state_d;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			data_i_q <= 1'sb0;
		else
			data_i_q <= data_i;
	localparam [3:0] tiny_nn_pkg_CmdOpAccumulate = 4'h2;
	localparam [3:0] tiny_nn_pkg_CmdOpConvolve = 4'h1;
	localparam [3:0] tiny_nn_pkg_CmdOpFixedMulAcc = 4'h4;
	localparam [3:0] tiny_nn_pkg_CmdOpMaxPool = 4'h5;
	localparam [3:0] tiny_nn_pkg_CmdOpMulAcc = 4'h3;
	localparam [3:0] tiny_nn_pkg_CmdOpTest = 4'hf;
	function automatic [7:0] sv2v_cast_6BBDD;
		input reg [7:0] inp;
		sv2v_cast_6BBDD = inp;
	endfunction
	function automatic [6:0] sv2v_cast_EE239;
		input reg [6:0] inp;
		sv2v_cast_EE239 = inp;
	endfunction
	localparam [15:0] tiny_nn_pkg_FPNegInf = {1'b1, sv2v_cast_6BBDD(1'sb1), sv2v_cast_EE239(1'sb0)};
	localparam [15:0] tiny_nn_pkg_FPStdNaN = {1'b1, sv2v_cast_6BBDD(1'sb1), sv2v_cast_EE239(1'sb1)};
	function automatic [7:0] sv2v_cast_C2D44;
		input reg [7:0] inp;
		sv2v_cast_C2D44 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		state_d = state_q;
		counter_d = counter_q;
		start_count_d = start_count_q;
		phase_d = 1'b0;
		param_write_d = param_write_q;
		convolve_run = 1'b0;
		relu_d = relu_q;
		max_val_d = max_val_q;
		core_val_shift = 1'sb0;
		core_mul_row_sel = 1'b0;
		core_mul_en = 1'b0;
		core_mul_add_op_a_en = 1'b0;
		core_mul_add_op_b_en = 1'b0;
		core_accumulate_mode_0_en = 1'sb0;
		core_accumulate_mode_1_en = 1'sb0;
		core_accumulate_mode_2_en = 1'sb0;
		core_accumulate_loopback = 1'b0;
		core_accumulate_out_relu = 1'b0;
		core_accumulate_level_0_en = 1'b0;
		case (state_q)
			5'h00:
				case (data_i_q[15:12])
					tiny_nn_pkg_CmdOpConvolve: begin
						state_d = 5'h01;
						param_write_d = 1'sb0;
						param_write_d[0] = 1'b1;
					end
					tiny_nn_pkg_CmdOpAccumulate: begin
						start_count_d = data_i_q[7:0];
						counter_d = sv2v_cast_C2D44(1'b1);
						state_d = 5'h04;
						relu_d = data_i_q[8];
					end
					tiny_nn_pkg_CmdOpTest:
						case (data_i_q[11:8])
							4'hf: begin
								state_d = 5'h1f;
								counter_d = 8'd3;
							end
							4'h1: begin
								state_d = 5'h1d;
								counter_d = data_i_q[7:0];
							end
							4'h0: begin
								state_d = 5'h1e;
								counter_d = 8'd1;
							end
							default:
								;
						endcase
					tiny_nn_pkg_CmdOpMulAcc: begin
						state_d = 5'h07;
						relu_d = data_i_q[8];
						phase_d = 1'b0;
						counter_d = sv2v_cast_C2D44(2'd3);
					end
					tiny_nn_pkg_CmdOpFixedMulAcc: begin
						start_count_d = data_i_q[7:0];
						counter_d = sv2v_cast_C2D44(2'd2);
						state_d = 5'h0a;
						param_write_d[6] = 1'b1;
					end
					tiny_nn_pkg_CmdOpMaxPool: begin
						max_val_d = tiny_nn_pkg_FPNegInf;
						start_count_d = data_i_q[7:0];
						counter_d = data_i_q[7:0];
						state_d = 5'h0d;
					end
					default:
						;
				endcase
			5'h01:
				if (param_write_q[ValArraySize - 1]) begin
					param_write_d = 1'sb0;
					state_d = 5'h02;
				end
				else
					param_write_d = {param_write_q[ValArraySize - 2:0], 1'b0};
			5'h02, 5'h03: begin
				phase_d = ~phase_q;
				convolve_run = 1'b1;
				core_val_shift[0] = ~phase_q;
				core_val_shift[1] = phase_q;
				core_mul_row_sel = phase_q;
				core_mul_en = 1'b1;
				core_accumulate_mode_0_en[0] = 1'b1;
				core_accumulate_mode_0_en[1] = phase_q;
				if (state_q == 5'h02) begin
					if (data_i_q == tiny_nn_pkg_FPStdNaN) begin
						state_d = 5'h03;
						counter_d = 8'd4;
					end
				end
				else if (counter_q != {8 {1'sb0}})
					counter_d = counter_q - 1'b1;
				else
					state_d = 5'h00;
			end
			5'h04: begin
				core_accumulate_level_0_en = 1'b1;
				state_d = 5'h05;
			end
			5'h05: begin
				core_accumulate_mode_1_en[0] = 1'b1;
				core_accumulate_out_relu = relu_q;
				core_mul_add_op_b_en = 1'b1;
				if (counter_q == {8 {1'sb0}}) begin
					core_accumulate_mode_1_en[1] = 1'b1;
					core_accumulate_loopback = 1'b0;
					counter_d = start_count_q;
				end
				else begin
					if (counter_q == sv2v_cast_C2D44(1'b1))
						core_mul_add_op_a_en = 1'b1;
					core_accumulate_loopback = 1'b1;
					counter_d = counter_q - 1'b1;
					if (data_i_q == tiny_nn_pkg_FPStdNaN) begin
						state_d = 5'h06;
						counter_d = 8'd2;
					end
				end
			end
			5'h06: begin
				core_accumulate_out_relu = relu_q;
				if (counter_q == 8'd2)
					core_accumulate_mode_1_en[1] = 1'b1;
				else if (counter_q == {8 {1'sb0}})
					state_d = 5'h00;
				counter_d = counter_q - 1'b1;
			end
			5'h07: begin
				core_accumulate_level_0_en = 1'b1;
				core_mul_add_op_a_en = 1'b1;
				state_d = 5'h08;
			end
			5'h08: begin
				phase_d = ~phase_q;
				core_mul_row_sel = 1'b1;
				if (phase_q) begin
					core_val_shift[0] = 1'b0;
					param_write_d[6] = 1'b0;
					core_accumulate_mode_1_en[0] = 1'b1;
					core_accumulate_loopback = counter_q == {8 {1'sb0}};
				end
				else begin
					core_val_shift[0] = 1'b1;
					param_write_d[6] = 1'b1;
					core_mul_en = counter_q != sv2v_cast_C2D44(2'd3);
					if (counter_q != {8 {1'sb0}})
						counter_d = counter_q - 1'b1;
					if (data_i_q == tiny_nn_pkg_FPStdNaN) begin
						state_d = 5'h09;
						counter_d = 8'd3;
					end
				end
			end
			5'h09: begin
				if (counter_q == 8'd3) begin
					core_accumulate_loopback = 1'b1;
					core_accumulate_mode_1_en[0] = 1'b1;
				end
				else if (counter_q == 8'd2) begin
					core_accumulate_mode_1_en[1] = 1'b1;
					core_accumulate_out_relu = relu_q;
				end
				else if (counter_q == {8 {1'sb0}})
					state_d = 5'h00;
				counter_d = counter_q - 1'b1;
			end
			5'h0a: begin
				param_write_d[6] = 1'b0;
				state_d = 5'h0b;
			end
			5'h0b: begin
				core_mul_en = 1'b1;
				core_accumulate_mode_2_en[0] = 1'b1;
				core_val_shift[0] = 1'b1;
				core_mul_row_sel = 1'b1;
				if (counter_q == 8'd0)
					counter_d = start_count_q;
				else begin
					core_accumulate_loopback = 1'b1;
					counter_d = counter_q - 1'b1;
					if (counter_q == sv2v_cast_C2D44(1'b1)) begin
						core_accumulate_mode_2_en[1] = 1'b1;
						core_mul_add_op_a_en = 1'b1;
					end
					else if (counter_q == sv2v_cast_C2D44(2'd2)) begin
						if (data_i_q == tiny_nn_pkg_FPStdNaN) begin
							counter_d = sv2v_cast_C2D44(2'd3);
							state_d = 5'h0c;
						end
					end
				end
			end
			5'h0c: begin
				if (counter_q == 8'd2) begin
					core_mul_row_sel = 1'b1;
					core_accumulate_mode_2_en[1] = 1'b1;
					core_accumulate_loopback = 1'b1;
				end
				else if (counter_q == {8 {1'sb0}})
					state_d = 5'h00;
				counter_d = counter_q - 1'b1;
			end
			5'h0d: begin
				if (data_i_q == tiny_nn_pkg_FPStdNaN)
					state_d = 5'h0e;
				if (counter_q == 8'd0) begin
					counter_d = start_count_q;
					max_val_d = tiny_nn_pkg_FPNegInf;
				end
				else begin
					counter_d = counter_q - 1'b1;
					if (data_i_q_is_greater)
						max_val_d = data_i_q;
				end
			end
			5'h0e: state_d = 5'h00;
			5'h1f:
				if (data_i_q[15:8] == 8'hff) begin
					if (counter_q == 0)
						counter_d = 8'd3;
					else
						counter_d = counter_q - 1'b1;
				end
				else
					state_d = 5'h00;
			5'h1e:
				if (data_i_q[15:8] == 8'hf0)
					counter_d = counter_q - 1'b1;
				else
					state_d = 5'h00;
			5'h1d:
				if (counter_q == {8 {1'sb0}})
					state_d = 5'h00;
				else
					counter_d = counter_q - 1'b1;
			default:
				;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			state_q <= 5'h00;
		else
			state_q <= state_d;
	always @(posedge clk_i) begin
		counter_q <= counter_d;
		start_count_q <= start_count_d;
		phase_q <= phase_d;
		param_write_q <= param_write_d;
		relu_q <= relu_d;
		max_val_q <= max_val_d;
	end
	function automatic [15:0] sv2v_cast_0825D;
		input reg [15:0] inp;
		sv2v_cast_0825D = inp;
	endfunction
	localparam sv2v_uu_u_core_tiny_nn_pkg_FPExpWidth = 8;
	localparam sv2v_uu_u_core_tiny_nn_pkg_FPMantWidth = 7;
	localparam [15:0] sv2v_uu_u_core_ext_mul_add_op_a_din_i_0 = 1'sb0;
	tiny_nn_core #(
		.ValArrayWidth(ValArrayWidth),
		.ValArrayHeight(ValArrayHeight)
	) u_core(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.val_i(sv2v_cast_0825D(data_i_q)),
		.val_shift_i(core_val_shift),
		.param_i(sv2v_cast_0825D(data_i_q)),
		.param_write_i(param_write_q),
		.mul_row_sel_i(core_mul_row_sel),
		.mul_en_i(core_mul_en),
		.accumulate_loopback_i(core_accumulate_loopback),
		.accumulate_out_relu_i(core_accumulate_out_relu),
		.mul_add_op_a_din_i(sv2v_uu_u_core_ext_mul_add_op_a_din_i_0),
		.mul_add_op_b_din_i(sv2v_cast_0825D(data_i_q)),
		.mul_add_op_a_en_i(core_mul_add_op_a_en),
		.mul_add_op_b_en_i(core_mul_add_op_b_en),
		.accumulate_level_0_din_i(sv2v_cast_0825D(data_i_q)),
		.accumulate_level_0_en_i(core_accumulate_level_0_en),
		.accumulate_mode_0_en_i(core_accumulate_mode_0_en),
		.accumulate_mode_1_en_i(core_accumulate_mode_1_en),
		.accumulate_mode_2_en_i(core_accumulate_mode_2_en),
		.accumulate_o(core_accumulate_result)
	);
	fp_cmp u_fp_cmp(
		.op_a_i(data_i_q),
		.op_b_i(max_val_q),
		.op_a_greater_o(data_i_q_is_greater),
		.invalid_nan_o()
	);
	reg [7:0] test_out;
	always @(*) begin
		if (_sv2v_0)
			;
		test_out = 1'sb0;
		case (state_q)
			5'h1f:
				case (counter_q)
					8'd3: test_out = 8'h54;
					8'd2: test_out = 8'h2d;
					8'd0, 8'd1: test_out = 8'h4e;
					default: test_out = 1'sb0;
				endcase
			5'h1e: test_out = (counter_q[0] ? 8'b10101010 : 8'b01010101);
			5'h1d: test_out = counter_q;
			default:
				;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		data_o_d = 1'sb1;
		max_val_skid_d = max_val_skid_q;
		case (state_q)
			5'h02, 5'h03: data_o_d = (phase_q ? core_accumulate_result[15:8] : core_accumulate_result[7:0]);
			5'h05, 5'h0b:
				if (counter_q == start_count_q)
					data_o_d = core_accumulate_result[7:0];
				else
					data_o_d = core_accumulate_result[15:8];
			5'h06, 5'h09, 5'h0c: data_o_d = (counter_q[0] ? core_accumulate_result[7:0] : core_accumulate_result[15:8]);
			5'h1f, 5'h1e, 5'h1d: data_o_d = test_out;
			5'h0d:
				if (counter_q == {8 {1'sb0}}) begin
					if (data_i_q_is_greater) begin
						data_o_d = data_i_q[7:0];
						max_val_skid_d = data_i_q[15:8];
					end
					else begin
						data_o_d = max_val_q[7:0];
						max_val_skid_d = max_val_q[15:8];
					end
				end
				else
					data_o_d = max_val_skid_q;
			5'h0e: data_o_d = max_val_skid_q;
			default:
				;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			data_o_q <= 1'sb1;
		else
			data_o_q <= data_o_d;
	always @(posedge clk_i) max_val_skid_q <= max_val_skid_d;
	assign data_o = data_o_q;
	initial _sv2v_0 = 0;
endmodule
/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_gregac_tiny_nn (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  tiny_nn_top u_tiny_nn_top (
    .clk_i(clk),
    .rst_ni(rst_n),
    .data_i({ui_in, uio_in}),
    .data_o(uo_out)
  );

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena};
endmodule

module sasic_top (
    input  wire clk, input  wire rst_n,
    input  wire in_0,  input  wire in_1,  input  wire in_2,  input  wire in_3,
    input  wire in_4,  input  wire in_5,  input  wire in_6,  input  wire in_7,
    input  wire in_8,  input  wire in_9,  input  wire in_10, input  wire in_11,
    input  wire in_12, input  wire in_13, input  wire in_14, input  wire in_15,
    input  wire in_16, input  wire in_17, input  wire in_18, input  wire in_19,
    input  wire in_20, input  wire in_21, input  wire in_22, input  wire in_23,
    input  wire in_24, input  wire in_25, input  wire in_26, input  wire in_27,
    input  wire in_28, input  wire in_29, input  wire in_30, input  wire in_31,
    input  wire in_32, input  wire in_33, input  wire in_34, input  wire in_35,
    input  wire in_36, input  wire in_37, input  wire in_38, input  wire in_39,
    output wire oeb_0,  output wire oeb_1,  output wire oeb_2,  output wire oeb_3,
    output wire oeb_4,  output wire oeb_5,  output wire oeb_6,  output wire oeb_7,
    output wire oeb_8,  output wire oeb_9,  output wire oeb_10, output wire oeb_11,
    output wire oeb_12, output wire oeb_13, output wire oeb_14, output wire oeb_15,
    output wire oeb_16, output wire oeb_17, output wire oeb_18, output wire oeb_19,
    output wire oeb_20, output wire oeb_21, output wire oeb_22, output wire oeb_23,
    output wire oeb_24, output wire oeb_25, output wire oeb_26, output wire oeb_27,
    output wire oeb_28, output wire oeb_29, output wire oeb_30, output wire oeb_31,
    output wire oeb_32, output wire oeb_33, output wire oeb_34, output wire oeb_35,
    output wire oeb_36, output wire oeb_37, output wire oeb_38, output wire oeb_39,
    output wire out_0,  output wire out_1,  output wire out_2,  output wire out_3,
    output wire out_4,  output wire out_5,  output wire out_6,  output wire out_7,
    output wire out_8,  output wire out_9,  output wire out_10, output wire out_11,
    output wire out_12, output wire out_13, output wire out_14, output wire out_15,
    output wire out_16, output wire out_17, output wire out_18, output wire out_19,
    output wire out_20, output wire out_21, output wire out_22, output wire out_23,
    output wire out_24, output wire out_25, output wire out_26, output wire out_27,
    output wire out_28, output wire out_29, output wire out_30, output wire out_31,
    output wire out_32, output wire out_33, output wire out_34, output wire out_35,
    output wire out_36, output wire out_37, output wire out_38, output wire out_39
);
    wire [7:0] ui_in  = {in_7,in_6,in_5,in_4,in_3,in_2,in_1,in_0};
    wire [7:0] uio_in = {in_15,in_14,in_13,in_12,in_11,in_10,in_9,in_8};
    wire [7:0] uo_out, uio_out, uio_oe;
    tt_um_gregac_tiny_nn tt_inst (
        .ui_in(ui_in),.uo_out(uo_out),.uio_in(uio_in),
        .uio_out(uio_out),.uio_oe(uio_oe),
        .ena(1'b1),.clk(clk),.rst_n(rst_n)
    );
    assign {out_7,out_6,out_5,out_4,out_3,out_2,out_1,out_0} = uo_out;
    assign {out_15,out_14,out_13,out_12,out_11,out_10,out_9,out_8} = uio_out;
    assign {out_39,out_38,out_37,out_36,out_35,out_34,out_33,out_32,out_31,out_30,out_29,out_28,out_27,out_26,out_25,out_24,out_23,out_22,out_21,out_20,out_19,out_18,out_17,out_16} = 24'd0;
    assign {oeb_7,oeb_6,oeb_5,oeb_4,oeb_3,oeb_2,oeb_1,oeb_0} = 8'hFF;
    assign {oeb_15,oeb_14,oeb_13,oeb_12,oeb_11,oeb_10,oeb_9,oeb_8} = ~uio_oe;
    assign {oeb_39,oeb_38,oeb_37,oeb_36,oeb_35,oeb_34,oeb_33,oeb_32,oeb_31,oeb_30,oeb_29,oeb_28,oeb_27,oeb_26,oeb_25,oeb_24,oeb_23,oeb_22,oeb_21,oeb_20,oeb_19,oeb_18,oeb_17,oeb_16} = 24'hFFFFFF;
endmodule
