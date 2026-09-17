//
// FX 68K
//
// M68K cycle accurate, fully synchronous
// Copyright (c) 2018 by Jorge Cwik
//
// ALU
//

`timescale 1 ns / 1 ns

localparam MASK_NBITS = 5;

localparam
		OP_AND = 1,
		OP_SUB = 2, OP_SUBX = 3, OP_ADD = 4,
		OP_EXT = 5, OP_SBCD = 6, OP_SUB0 = 7,
		OP_OR = 8, OP_EOR = 9,
		OP_SUBC = 10, OP_ADDC = 11, OP_ADDX = 12,
		OP_ASL = 13,
		OP_ASR = 14,
		OP_LSL = 15,
		OP_LSR = 16,
		OP_ROL = 17,
		OP_ROR = 18,
		OP_ROXL = 19,
		OP_ROXR = 20,
		OP_SLAA = 21,
		OP_ABCD = 22;

module fx68kAlu ( input clk, pwrUp, enT1, enT3, enT4,
	input [15:0] ird,
	input [2:0] aluColumn,
	input [1:0] aluDataCtrl,
	input aluAddrCtrl, alueClkEn, ftu2Ccr, init, finish, aluIsByte,
	input [15:0] ftu,
	input [15:0] alub,
	input [15:0] iDataBus, input [15:0] iAddrBus,
	output ze,
	output reg [15:0] alue,
	output reg [7:0] ccr,
	output [15:0] aluOut);

`define ALU_ROW_01		16'h0002
`define ALU_ROW_02		16'h0004
`define ALU_ROW_03		16'h0008
`define ALU_ROW_04		16'h0010
`define ALU_ROW_05		16'h0020
`define ALU_ROW_06		16'h0040
`define ALU_ROW_07		16'h0080
`define ALU_ROW_08		16'h0100
`define ALU_ROW_09		16'h0200
`define ALU_ROW_10		16'h0400
`define ALU_ROW_11		16'h0800
`define ALU_ROW_12		16'h1000
`define ALU_ROW_13		16'h2000
`define ALU_ROW_14		16'h4000
`define ALU_ROW_15		16'h8000

	localparam CF = 0, VF = 1, ZF = 2, NF = 3, XF = 4;

	reg [15:0] aluLatch;
	reg [4:0] pswCcr;
	reg [4:0] ccrCore;

	logic [15:0] result;
	logic [4:0] ccrTemp;
	reg coreH;

	logic [15:0] subResult;
	logic subHcarry;
	logic subCout, subOv;

	assign aluOut = aluLatch;
	assign ze = ~ccrCore[ ZF];

	reg [15:0] row;
	reg isArX;
	reg noCcrEn;
	reg isByte;

	reg [4:0] ccrMask;
	reg [4:0] oper;

	logic [15:0] aOperand, dOperand;
	wire isCorf = ( aluDataCtrl == 2'b10);

	wire [15:0] cRow;
	wire cIsArX;
	wire cNoCcrEn;
	rowDecoder rowDecoder( .ird( ird), .row( cRow), .noCcrEn( cNoCcrEn), .isArX( cIsArX));

	wire [4:0] cMask;
	wire [4:0] aluOp;

	aluGetOp aluGetOp( .row, .col( aluColumn), .isCorf, .aluOp);
	ccrTable ccrTable( .col( aluColumn), .row( row), .finish, .ccrMask( cMask));

	wire shftIsMul = row[7];
	wire shftIsDiv = row[1];

	wire [31:0] shftResult;
	reg [7:0] bcdLatch;
	reg bcdCarry, bcdOverf;

	reg isLong;
	reg rIrd8;
	logic isShift;
	logic shftCin, shftRight, addCin;

	always_ff @( posedge clk) begin
		if( enT3) begin
			row <= cRow;
			isArX <= cIsArX;
			noCcrEn <= cNoCcrEn;
			rIrd8 <= ird[8];
			isByte <= aluIsByte;
		end

		if( enT4) begin

			isLong <= (ird[7] & ~ird[6]) | shftIsMul | shftIsDiv;

			ccrMask <= cMask;
			oper <= aluOp;
		end
	end

	always_comb begin

		aOperand = (aluAddrCtrl ? alub : iAddrBus);

		case( aluDataCtrl)
			2'b00:				dOperand = iDataBus;
			2'b01:				dOperand = 'h0000;
			2'b11:				dOperand = 'hffff;

			2'b10:				dOperand = 'X;
		endcase
	end

	wire shftMsb = isLong ? alue[15] : (isByte ? aOperand[7] : aOperand[15]);

	aluShifter shifter( .data( { alue, aOperand}),
		.swapWords( shftIsMul | shftIsDiv),
		.cin( shftCin), .dir( shftRight), .isByte( isByte), .isLong( isLong),
		.result( shftResult));

	wire [7:0] bcdResult;
	wire bcdC, bcdV;
	aluCorf aluCorf( .binResult( aluLatch[7:0]), .hCarry( coreH),
		.bAdd( (oper != OP_SBCD) ), .cin( pswCcr[ XF]),
		.bcdResult( bcdResult), .dC( bcdC), .ov( bcdV));

	always_ff @( posedge clk)
		if( enT1) begin
			bcdLatch <= bcdResult;
			bcdCarry <= bcdC;
			bcdOverf <= bcdV;
		end

	always_comb
	begin
		case( oper)
			OP_ADD, OP_SUB:   addCin = 1'b0;
			OP_SUB0:          addCin = 1'b1;
			OP_ADDC,OP_SUBC:  addCin = ccrCore[ CF];
			OP_ADDX,OP_SUBX:  addCin = pswCcr[ XF];
			default: addCin = 1'bX;
		endcase
	end

	always_comb begin
		case( oper)
		OP_LSL, OP_ASL, OP_ROL, OP_ROXL, OP_SLAA:   shftRight = 1'b0;
		OP_LSR, OP_ASR, OP_ROR, OP_ROXR:            shftRight = 1'b1;
		default:									shftRight = 1'bX;
		endcase

		case( oper)
		OP_LSR,
		OP_ASL,
		OP_LSL:		shftCin = 1'b0;
		OP_ROL,
		OP_ASR:		shftCin = shftMsb;
		OP_ROR:		shftCin = aOperand[0];
		OP_ROXL,
		OP_ROXR:
			if( shftIsMul)
				shftCin = rIrd8 ? pswCcr[NF] ^ pswCcr[VF] : pswCcr[ CF];
			else
				shftCin = pswCcr[ XF];

		OP_SLAA:	shftCin = aluColumn[1];
		default:	shftCin = 'X;
		endcase
	end

	always_comb begin

		mySubber( aOperand, dOperand, addCin,
			(oper == OP_ADD) | (oper == OP_ADDC) | (oper == OP_ADDX),
			isByte, subResult, subCout, subOv);

		isShift = 1'b0;
		case( oper)
		OP_AND: result = aOperand & dOperand;
		OP_OR:  result = aOperand | dOperand;
		OP_EOR: result = aOperand ^ dOperand;

		OP_EXT: result = { {8{aOperand[7]}}, aOperand[7:0]};

		OP_SLAA,
		OP_ASL, OP_ASR,
		OP_LSL, OP_LSR,
		OP_ROL, OP_ROR,
		OP_ROXL, OP_ROXR:
			begin
				result = shftResult[15:0];
				isShift = 1'b1;
			end

		OP_ADD,
		OP_ADDC,
		OP_ADDX,
		OP_SUB,
		OP_SUBC,
		OP_SUB0,
		OP_SUBX:	result = subResult;

		OP_ABCD,
		OP_SBCD:	result = { 8'hXX, bcdLatch};

		default:	result = 'X;
		endcase
	end

	task mySubber;
		input [15:0] inpa, inpb;
		input cin, bAdd, isByte;
		output reg [15:0] result;
		output cout, ov;

		logic [16:0] rtemp;
		logic rm,sm,dm,tsm;

		begin
			if( isByte)
			begin
				rtemp = bAdd ? { 1'b0, inpb[7:0]} + { 1'b0, inpa[7:0]} + cin:
								{ 1'b0, inpb[7:0] } - { 1'b0, inpa[7:0]} - cin;
				result = { {8{ rtemp[7]}}, rtemp[7:0]};
				cout = rtemp[8];
			end
			else begin
				rtemp = bAdd ? { 1'b0, inpb } + { 1'b0, inpa} + cin:
								{ 1'b0, inpb } - { 1'b0, inpa} - cin;
				result = rtemp[ 15:0];
				cout = rtemp[16];
			end

			rm  = isByte ? rtemp[7] : rtemp[15];
			dm  = isByte ? inpb[ 7] : inpb[ 15];
			tsm = isByte ? inpa[ 7] : inpa[ 15];
			sm  = bAdd ? tsm : ~tsm;

			ov = (sm & dm & ~rm) | (~sm & ~dm & rm);

			subHcarry = inpa[4] ^ inpb[4] ^ rtemp[4];

		end
	endtask

	always_comb begin

		ccrTemp[XF] = pswCcr[XF];     ccrTemp[CF] = 0;     ccrTemp[VF] = 0;

		ccrTemp[ ZF] = isByte ? ~(| result[7:0]) : ~(| result);
		ccrTemp[ NF] = isByte ? result[7] : result[15];

		unique case( oper)

		OP_EXT:

			if( aluColumn == 5) begin
				ccrTemp[VF] = 1'b1;
				ccrTemp[NF] = 1'b1;				ccrTemp[ ZF] = 1'b0;
			end

		OP_SUB0,
		OP_OR,
		OP_EOR:
			begin
				ccrTemp[CF] = 0;      ccrTemp[VF] = 0;
			end

		OP_AND:
			begin

				if( (aluColumn == 1) & (row[11] | row[8]))
					ccrTemp[CF] = pswCcr[XF];
				else
					ccrTemp[CF] = 0;
				ccrTemp[VF] = 0;
			end

		OP_SLAA:   ccrTemp[ CF] = aOperand[15];

		OP_LSL,OP_ROXL:
			begin
				ccrTemp[ CF] = shftMsb;
				ccrTemp[ XF] = shftMsb;
				ccrTemp[ VF] = 1'b0;
			end

		OP_LSR,OP_ROXR:
			begin

				ccrTemp[ CF] = shftIsMul ? 1'b0 : aOperand[0];
				ccrTemp[ XF] = aOperand[0];

				ccrTemp[ VF] = 0;

			end

		OP_ASL:
			begin
				ccrTemp[ XF] = shftMsb;			ccrTemp[ CF] = shftMsb;

				ccrTemp[ VF] = pswCcr[VF] | (shftMsb ^
					(isLong ? alue[15-1] : (isByte ? aOperand[7-1] : aOperand[15-1])) );
			end
		OP_ASR:
			begin
				ccrTemp[ XF] = aOperand[0];		ccrTemp[ CF] = aOperand[0];
				ccrTemp[ VF] = 0;
			end

		OP_ROL:		ccrTemp[ CF] = shftMsb;
		OP_ROR:		ccrTemp[ CF] = aOperand[0];

		OP_ADD,
		OP_ADDC,
		OP_ADDX,
		OP_SUB,
		OP_SUBC,
		OP_SUBX:
			begin
				ccrTemp[ CF] = subCout;
				ccrTemp[ XF] = subCout;
				ccrTemp[ VF] = subOv;
			end

		OP_ABCD,
		OP_SBCD:
			begin
				ccrTemp[ XF] = bcdCarry;
				ccrTemp[ CF] = bcdCarry;
				ccrTemp[ VF] = bcdOverf;
			end

		endcase

	end

	logic [4:0] ccrMasked;
	always_comb begin
		ccrMasked = (ccrTemp & ccrMask) | (pswCcr & ~ccrMask);

		if( finish | isArX)
			ccrMasked[ ZF] = ccrTemp[ ZF] & pswCcr[ ZF];
	end

	always_ff @( posedge clk) begin
		if( enT3) begin

			if( (| aluColumn)) begin
				aluLatch <= result;

				coreH <= subHcarry;

				if( (| aluColumn))
					ccrCore <= ccrTemp;
			end

			if( alueClkEn)
				alue <= iDataBus;
			else if( isShift & (| aluColumn))
				alue <= shftResult[31:16];
		end

		if( pwrUp)
			pswCcr <= '0;
		else if( enT3 & ftu2Ccr)
			pswCcr <= ftu[4:0];
		else if( enT3 &	~noCcrEn & (finish | init))
			pswCcr <= ccrMasked;
	end
	assign ccr = { 3'b0, pswCcr};

endmodule

module aluCorf( input [7:0] binResult, input bAdd, input cin, input hCarry,
	output [7:0] bcdResult, output dC, output logic ov);

	reg [8:0] htemp;
	reg [4:0] hNib;

	wire lowC  = hCarry | (bAdd ? gt9( binResult[ 3:0]) : 1'b0);
	wire highC = cin	| (bAdd ? (gt9( htemp[7:4]) | htemp[8]) : 1'b0);

	always_comb begin
		if( bAdd) begin
			htemp = { 1'b0, binResult} + (lowC  ? 4'h6 : 4'h0);
			hNib  = htemp[8:4] + (highC ? 4'h6 : 4'h0);
			ov = hNib[3] & ~binResult[7];
		end
		else begin
			htemp = { 1'b0, binResult} - (lowC  ? 4'h6 : 4'h0);
			hNib  = htemp[8:4] - (highC ? 4'h6 : 4'h0);
			ov = ~hNib[3] & binResult[7];
		end
	end

	assign bcdResult = { hNib[ 3:0], htemp[3:0]};
	assign dC = hNib[4] | cin;

	function gt9 (input [3:0] nib);
	begin
		gt9 = nib[3] & (nib[2] | nib[1]);
	end
	endfunction

endmodule

module aluShifter( input [31:0] data,
	input isByte, input isLong, swapWords,
	input dir, input cin,
	output logic [31:0] result);

	logic [31:0] tdata;

	always_comb begin
		tdata = data;
		if( isByte & dir)
			tdata[8] = cin;
		else if( !isLong & dir)
			tdata[16] = cin;
	end

	always_comb begin

		if( swapWords & dir)
			result = { tdata[0], tdata[31:17], cin, tdata[15:1]};
		else if( swapWords)
			result = { tdata[30:16], cin, tdata[14:0], tdata[31]};

		else if( dir)
			result = { cin, tdata[31:1]};
		else
			result = { tdata[30:0], cin};
	end

endmodule

module aluGetOp( input [15:0] row, input [2:0] col, input isCorf,
	output logic [4:0] aluOp);

	always_comb begin
		aluOp = 'X;
		unique case( col)
		1:   aluOp = OP_AND;
		5:   aluOp = OP_EXT;

		default:
			unique case( 1'b1)
				row[1]:
					unique case( col)
					2: aluOp = OP_SUB;
					3: aluOp = OP_SUBC;
					4,6: aluOp = OP_SLAA;
					endcase

				row[2]:
					unique case( col)
					2: aluOp = OP_ADD;
					3: aluOp = OP_ADDC;
					4: aluOp = OP_ASR;
					endcase

				row[3]:
					unique case( col)
					2: aluOp = OP_ADDX;
					3: aluOp = isCorf ? OP_ABCD : OP_ADD;
					4: aluOp = OP_ASL;
					endcase

				row[4]:
					aluOp = ( col == 4) ? OP_LSL : OP_AND;

				row[5],
				row[6]:
					unique case( col)
					2: aluOp = OP_SUB;
					3: aluOp = OP_SUBC;
					4: aluOp = OP_LSR;
					endcase

				row[7]:
					unique case( col)
					2: aluOp = OP_SUB;
					3: aluOp = OP_ADD;
					4: aluOp = OP_ROXR;
					endcase

				row[8]:

					unique case( col)
					2: aluOp = OP_EXT;
					3: aluOp = OP_AND;
					4: aluOp = OP_ROXR;
					endcase

				row[9]:
					unique case( col)
					2: aluOp = OP_SUBX;
					3: aluOp = OP_SBCD;
					4: aluOp = OP_ROL;
					endcase

				row[10]:
					unique case( col)
					2: aluOp = OP_SUBX;
					3: aluOp = OP_SUBC;
					4: aluOp = OP_ROR;
					endcase

				row[11]:
					unique case( col)
					2: aluOp = OP_SUB0;
					3: aluOp = OP_SUB0;
					4: aluOp = OP_ROXL;
					endcase

				row[12]:	aluOp = OP_ADDX;
				row[13]:	aluOp = OP_EOR;
				row[14]:	aluOp = (col == 4) ? OP_EOR : OP_OR;
				row[15]:	aluOp = (col == 3) ? OP_ADD : OP_OR;

			endcase
		endcase
	end
endmodule

module rowDecoder( input [15:0] ird,
	output logic [15:0] row, output noCcrEn, output logic isArX);

	wire eaRdir = (ird[ 5:4] == 2'b00);

	wire eaAdir = (ird[ 5:3] == 3'b001);
	wire size11 = ird[7] & ird[6];

	always_comb begin
		case( ird[15:12])
		'h4,
		'h9,
		'hd:
			isArX = row[10] | row[12];
		default:
			isArX = 1'b0;
		endcase
	end

	always_comb begin
		unique case( ird[15:12])

		'h4:  begin
				if( ird[8])
					row = `ALU_ROW_06;
				else case( ird[11:9])
					'b000: row = `ALU_ROW_10;
					'b001: row = `ALU_ROW_04;
					'b010: row = `ALU_ROW_05;
					'b011: row = `ALU_ROW_11;
					'b100: row = (ird[7]) ? `ALU_ROW_08 : `ALU_ROW_09;
					'b101: row = `ALU_ROW_15;
					default: row = 0;
				endcase
			end

		'h0: begin
				if( ird[8])
					row = ird[7] ? `ALU_ROW_14 : `ALU_ROW_13;
				else case( ird[ 11:9])
					'b000:   row = `ALU_ROW_14;
					'b001:   row = `ALU_ROW_04;
					'b010:   row = `ALU_ROW_05;
					'b011:   row = `ALU_ROW_02;
					'b100:   row = ird[7] ? `ALU_ROW_14 : `ALU_ROW_13;
					'b101:   row = `ALU_ROW_13;
					'b110:   row = `ALU_ROW_06;
					default: row = 0;
					endcase
				end

		'h1,'h2,'h3:   row = `ALU_ROW_02;

		'h5:
			if( size11)
               row = `ALU_ROW_15;
			else
				row = ird[8] ? `ALU_ROW_05 : `ALU_ROW_02;
		'h6:	row = 0;
		'h7:	row = `ALU_ROW_02;
		'h8:
			if( size11)
				row = `ALU_ROW_01;
			else if( ird[8] & eaRdir)
				row = `ALU_ROW_09;
			else
				row = `ALU_ROW_14;
		'h9:
			if( ird[8] & ~size11 & eaRdir)
				row = `ALU_ROW_10;
			else
				row = `ALU_ROW_05;
		'hb:
			if( ird[8] & ~size11 & ~eaAdir)
				row = `ALU_ROW_13;
			else
				row = `ALU_ROW_06;
		'hc:
			if( size11)
				row = `ALU_ROW_07;
			else if( ird[8] & eaRdir)
				row = `ALU_ROW_03;
			else
				row = `ALU_ROW_04;
		'hd:
			if( ird[8] & ~size11 & eaRdir)
				row = `ALU_ROW_12;
			else
				row = `ALU_ROW_02;
		'he:
			begin
				reg [1:0] stype;

				if( size11)
					stype = ird[ 10:9];
				else
					stype = ird[ 4:3];

				case( {stype, ird[8]})
				0: row = `ALU_ROW_02;
				1: row = `ALU_ROW_03;
				2: row = `ALU_ROW_05;
				3: row = `ALU_ROW_04;
				4: row = `ALU_ROW_08;
				5: row = `ALU_ROW_11;
				6: row = `ALU_ROW_10;
				7: row = `ALU_ROW_09;
				endcase
			end

		default:	row = 0;
		endcase
	end

	assign noCcrEn =

		( ird[15] & ~ird[13] & ird[12] & size11) |

		( (ird[15:12] == 4'h5) & eaAdir) |

		( (~ird[15] & ~ird[14] & ird[13]) & ird[8:6] == 3'b001);

endmodule

module ccrTable(
	input [2:0] col, input [15:0] row, input finish,
	output logic [MASK_NBITS-1:0] ccrMask);

	localparam
		KNZ00 = 5'b01111,
		KKZKK = 5'b00100,
		KNZKK = 5'b01100,
		KNZ10 = 5'b01111,
		KNZ0C = 5'b01111,

		KNZVC	= 5'b01111,
		XNKVC	= 5'b11011,

		CUPDALL = 5'b11111,
		CUNUSED = 5'bxxxxx;

	logic [MASK_NBITS-1:0] ccrMask1;

	always_comb begin
		unique case( col)
		1:			ccrMask = ccrMask1;

		2,3:
			unique case( 1'b1)
			row[1]:		ccrMask = KNZ0C;

			row[3],
			row[9]:
						ccrMask = (col == 2) ? XNKVC : CUPDALL;

			row[2],
			row[5],
			row[10],
			row[12]:	ccrMask = CUPDALL;

			row[6],
			row[7],
			row[11]:	ccrMask = KNZVC;
			row[4],
			row[8],
			row[13],
			row[14]:	ccrMask = KNZ00;
			row[15]:	ccrMask = 5'b0;

			endcase

		4:
			unique case( row)

			`ALU_ROW_02,
			`ALU_ROW_03,
			`ALU_ROW_04,
			`ALU_ROW_05:	ccrMask = CUPDALL;

			`ALU_ROW_07:	ccrMask = KNZ00;
			`ALU_ROW_09,
			`ALU_ROW_10:	ccrMask = KNZ00;
			`ALU_ROW_08,
			`ALU_ROW_11:	ccrMask = CUPDALL;
			default:	ccrMask = CUNUSED;
			endcase

		5:			ccrMask = row[1] ? KNZ10 : 5'b0;
		default:	ccrMask = CUNUSED;
		endcase
	end

	always_comb begin
		if( finish)
			ccrMask1 = row[7] ? KNZ00 : KNZKK;
		else
			ccrMask1 = row[13] | row[14] ? KKZKK : KNZ00;
	end

endmodule
