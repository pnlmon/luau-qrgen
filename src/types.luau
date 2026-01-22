--!strict
--[=[
    @class Types

    Type definitions and QR spec constants.
]=]

--[=[
    @interface ErrorCorrectionLevel
    @within Types
    .ordinal number
    .formatBits number
]=]
export type ErrorCorrectionLevel = {
	ordinal: number,
	formatBits: number,
}

--[=[
    @interface Mode
    @within Types
    .modeBits number
    .numBitsCharCount { number }
]=]
export type Mode = {
	modeBits: number,
	numBitsCharCount: { number },
}

--[=[
    @interface QrSegmentData
    @within Types
    .mode Mode
    .numChars number
    .bitData { number }
]=]
export type QrSegmentData = {
	mode: Mode,
	numChars: number,
	bitData: { number },
}

--[=[
    @interface QrCodeData
    @within Types
    .version number
    .size number
    .errorCorrectionLevel ErrorCorrectionLevel
    .mask number
    .modules { { boolean } }
]=]
export type QrCodeData = {
	version: number,
	size: number,
	errorCorrectionLevel: ErrorCorrectionLevel,
	mask: number,
	modules: { { boolean } },
}

local types = {}

types.ecc = {
	low = { ordinal = 0, formatBits = 1 } :: ErrorCorrectionLevel,
	medium = { ordinal = 1, formatBits = 0 } :: ErrorCorrectionLevel,
	quartile = { ordinal = 2, formatBits = 3 } :: ErrorCorrectionLevel,
	high = { ordinal = 3, formatBits = 2 } :: ErrorCorrectionLevel,
}

types.mode = {
	numeric = { modeBits = 0x1, numBitsCharCount = { 10, 12, 14 } } :: Mode,
	alphanumeric = { modeBits = 0x2, numBitsCharCount = { 9, 11, 13 } } :: Mode,
	byte = { modeBits = 0x4, numBitsCharCount = { 8, 16, 16 } } :: Mode,
	kanji = { modeBits = 0x8, numBitsCharCount = { 8, 10, 12 } } :: Mode,
	eci = { modeBits = 0x7, numBitsCharCount = { 0, 0, 0 } } :: Mode,
}

types.minVersion = 1
types.maxVersion = 40

types.penaltyN1 = 3
types.penaltyN2 = 3
types.penaltyN3 = 40
types.penaltyN4 = 10

types.alphanumericCharset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

types.eccCodewordsPerBlock = {
	{
		-1,
		7,
		10,
		15,
		20,
		26,
		18,
		20,
		24,
		30,
		18,
		20,
		24,
		26,
		30,
		22,
		24,
		28,
		30,
		28,
		28,
		28,
		28,
		30,
		30,
		26,
		28,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
	},
	{
		-1,
		10,
		16,
		26,
		18,
		24,
		16,
		18,
		22,
		22,
		26,
		30,
		22,
		22,
		24,
		24,
		28,
		28,
		26,
		26,
		26,
		26,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
		28,
	},
	{
		-1,
		13,
		22,
		18,
		26,
		18,
		24,
		18,
		22,
		20,
		24,
		28,
		26,
		24,
		20,
		30,
		24,
		28,
		28,
		26,
		30,
		28,
		30,
		30,
		30,
		30,
		28,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
	},
	{
		-1,
		17,
		28,
		22,
		16,
		22,
		28,
		26,
		26,
		24,
		28,
		24,
		28,
		22,
		24,
		24,
		30,
		28,
		28,
		26,
		28,
		30,
		24,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
		30,
	},
}

types.numErrorCorrectionBlocks = {
	{
		-1,
		1,
		1,
		1,
		1,
		1,
		2,
		2,
		2,
		2,
		4,
		4,
		4,
		4,
		4,
		6,
		6,
		6,
		6,
		7,
		8,
		8,
		9,
		9,
		10,
		12,
		12,
		12,
		13,
		14,
		15,
		16,
		17,
		18,
		19,
		19,
		20,
		21,
		22,
		24,
		25,
	},
	{
		-1,
		1,
		1,
		1,
		2,
		2,
		4,
		4,
		4,
		5,
		5,
		5,
		8,
		9,
		9,
		10,
		10,
		11,
		13,
		14,
		16,
		17,
		17,
		18,
		20,
		21,
		23,
		25,
		26,
		28,
		29,
		31,
		33,
		35,
		37,
		38,
		40,
		43,
		45,
		47,
		49,
	},
	{
		-1,
		1,
		1,
		2,
		2,
		4,
		4,
		6,
		6,
		8,
		8,
		8,
		10,
		12,
		16,
		12,
		17,
		16,
		18,
		21,
		20,
		23,
		23,
		25,
		27,
		29,
		34,
		34,
		35,
		38,
		40,
		43,
		45,
		48,
		51,
		53,
		56,
		59,
		62,
		65,
		68,
	},
	{
		-1,
		1,
		1,
		2,
		4,
		4,
		4,
		5,
		6,
		8,
		8,
		11,
		11,
		16,
		16,
		18,
		16,
		19,
		21,
		25,
		25,
		25,
		34,
		30,
		32,
		35,
		37,
		40,
		42,
		45,
		48,
		51,
		54,
		57,
		60,
		63,
		66,
		70,
		74,
		77,
		81,
	},
}

function types.getNumCharCountBits(mode: Mode, version: number): number
	local index: number
	if version <= 9 then
		index = 1
	elseif version <= 26 then
		index = 2
	else
		index = 3
	end
	return mode.numBitsCharCount[index]
end

return types
