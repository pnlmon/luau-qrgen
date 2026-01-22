--!strict
--[[
    standalone test suite for luau-qrgen.
]]

local bitBuffer = require("../src/bitBuffer")
local qrCode = require("../src/qrCode")
local qrSegment = require("../src/qrSegment")
local reedSolomon = require("../src/reedSolomon")
local types = require("../src/types")

type QrCodeType = qrCode.QrCode

-- test utilities
local passCount = 0
local failCount = 0

local function test(name: string, fn: () -> boolean)
	local success, result = pcall(fn)

	if success and result then
		passCount = passCount + 1
		print("✓ " .. name)
	else
		failCount = failCount + 1
		if success then
			print("✗ " .. name .. " - Test returned false")
		else
			print("✗ " .. name .. " - Error: " .. tostring(result))
		end
	end
end

local function _assertEqual<T>(actual: T, expected: T, message: string?): boolean
	if actual == expected then
		return true
	else
		print("  Expected: " .. tostring(expected))
		print("  Actual: " .. tostring(actual))
		if message then
			print("  " .. message)
		end
		return false
	end
end

local function assertNotNil<T>(value: T?, message: string?): boolean
	if value ~= nil then
		return true
	else
		print("  Value is nil")
		if message then
			print("  " .. message)
		end
		return false
	end
end

-- bit buffer tests
print("\n=== bit buffer tests ===")

test("bitBuffer: create and append bits", function()
	local bb = bitBuffer.new()
	bb:appendBits(5, 3) -- binary: 101
	bb:appendBits(3, 2) -- binary: 11
	-- result should be: {1, 0, 1, 1, 1}
	local bits = bb:getBits()
	return #bits == 5 and bits[1] == 1 and bits[2] == 0 and bits[3] == 1 and bits[4] == 1 and bits[5] == 1
end)

test("bitBuffer: append many bits", function()
	local bb = bitBuffer.new()
	bb:appendBits(0xFF, 8)
	bb:appendBits(0x00, 8)
	local bits = bb:getBits()
	-- 0xFF = 11111111, 0x00 = 00000000
	return #bits == 16 and bits[1] == 1 and bits[8] == 1 and bits[9] == 0 and bits[16] == 0
end)

-- reed-solomon tests
print("\n=== reed-solomon tests ===")

test("reedSolomon: multiply", function()
	-- gf(2^8) multiplication tests
	return reedSolomon.multiply(0, 0) == 0
		and reedSolomon.multiply(1, 1) == 1
		and reedSolomon.multiply(0, 100) == 0
		and reedSolomon.multiply(100, 0) == 0
end)

test("reedSolomon: compute divisor", function()
	local div = reedSolomon.computeDivisor(1)
	return #div == 1
end)

test("reedSolomon: compute divisor degree 10", function()
	local div = reedSolomon.computeDivisor(10)
	return #div == 10
end)

-- qr segment tests
print("\n=== qr segment tests ===")

test("qrSegment: isNumeric", function()
	return qrSegment.isNumeric("0123456789")
		and not qrSegment.isNumeric("012345A")
		and not qrSegment.isNumeric("hello")
		and qrSegment.isNumeric("")
end)

test("qrSegment: isAlphanumeric", function()
	return qrSegment.isAlphanumeric("HELLO WORLD")
		and qrSegment.isAlphanumeric("0123456789")
		and qrSegment.isAlphanumeric("ABC123")
		and not qrSegment.isAlphanumeric("hello")
		and not qrSegment.isAlphanumeric("Hello")
end)

test("qrSegment: makeNumeric", function()
	local seg = qrSegment.makeNumeric("12345")
	return assertNotNil(seg) and seg.mode == types.mode.numeric
end)

test("qrSegment: makeAlphanumeric", function()
	local seg = qrSegment.makeAlphanumeric("HELLO")
	return assertNotNil(seg) and seg.mode == types.mode.alphanumeric
end)

test("qrSegment: makeBytes", function()
	local seg = qrSegment.makeBytes({ 72, 101, 108, 108, 111 })
	return assertNotNil(seg) and seg.mode == types.mode.byte
end)

test("qrSegment: makeSegments auto-detect numeric", function()
	local segs = qrSegment.makeSegments("12345")
	return #segs == 1 and segs[1].mode == types.mode.numeric
end)

test("qrSegment: makeSegments auto-detect alphanumeric", function()
	local segs = qrSegment.makeSegments("HELLO")
	return #segs == 1 and segs[1].mode == types.mode.alphanumeric
end)

test("qrSegment: makeSegments auto-detect byte", function()
	local segs = qrSegment.makeSegments("Hello")
	return #segs == 1 and segs[1].mode == types.mode.byte
end)

-- qr code generation tests
print("\n=== qr code generation tests ===")

test("qrCode: encodeText simple", function()
	local qr = qrCode.encodeText("Hello", types.ecc.medium)
	return assertNotNil(qr) and qr.version >= 1 and qr.version <= 40 and qr.size == 17 + qr.version * 4
end)

test("qrCode: encodeText numeric", function()
	local qr = qrCode.encodeText("12345", types.ecc.low)
	return assertNotNil(qr) and qr.version == 1
end)

test("qrCode: encodeText alphanumeric", function()
	local qr = qrCode.encodeText("HELLO WORLD", types.ecc.medium)
	return assertNotNil(qr) and qr.version >= 1
end)

test("qrCode: encodeText longer text", function()
	local qr = qrCode.encodeText("Hello, World! This is a test of the QR code generator.", types.ecc.medium)
	return assertNotNil(qr) and qr.version >= 1
end)

test("qrCode: encodeText all error correction levels", function()
	local textL = qrCode.encodeText("Test", types.ecc.low)
	local textM = qrCode.encodeText("Test", types.ecc.medium)
	local textQ = qrCode.encodeText("Test", types.ecc.quartile)
	local textH = qrCode.encodeText("Test", types.ecc.high)
	return assertNotNil(textL) and assertNotNil(textM) and assertNotNil(textQ) and assertNotNil(textH)
end)

test("qrCode: encodeBinary", function()
	local qr = qrCode.encodeBinary({ 72, 101, 108, 108, 111 }, types.ecc.medium)
	return assertNotNil(qr) and qr.version >= 1
end)

test("qrCode: getModule returns booleans", function()
	local qr = qrCode.encodeText("Test", types.ecc.medium)
	if not qr then
		return false
	end

	-- check corners (should be finder patterns = black)
	local topLeft = qr:getModule(0, 0)
	local topRight = qr:getModule(qr.size - 1, 0)
	local bottomLeft = qr:getModule(0, qr.size - 1)

	return type(topLeft) == "boolean" and type(topRight) == "boolean" and type(bottomLeft) == "boolean"
end)

test("qrCode: finder pattern at top-left", function()
	local qr = qrCode.encodeText("Test", types.ecc.low)
	if not qr then
		return false
	end

	-- finder pattern is 7x7, all black on the outer edge
	-- top row should be all black (7 modules)
	for x = 0, 6 do
		if not qr:getModule(x, 0) then
			return false
		end
	end
	return true
end)

test("qrCode: finder pattern at top-right", function()
	local qr = qrCode.encodeText("Test", types.ecc.low)
	if not qr then
		return false
	end

	-- finder pattern at top-right
	for x = qr.size - 7, qr.size - 1 do
		if not qr:getModule(x, 0) then
			return false
		end
	end
	return true
end)

test("qrCode: finder pattern at bottom-left", function()
	local qr = qrCode.encodeText("Test", types.ecc.low)
	if not qr then
		return false
	end

	-- finder pattern at bottom-left
	for x = 0, 6 do
		if not qr:getModule(x, qr.size - 1) then
			return false
		end
	end
	return true
end)

-- version selection tests
print("\n=== version selection tests ===")

test("qrCode: version 1 for short data", function()
	local qr = qrCode.encodeText("Hi", types.ecc.low)
	return assertNotNil(qr) and qr.version == 1
end)

test("qrCode: larger version for longer data", function()
	local longText = string.rep("A", 100)
	local qr = qrCode.encodeText(longText, types.ecc.low)
	return assertNotNil(qr) and qr.version > 1
end)

-- matrix output tests
print("\n=== matrix output tests ===")

test("qrCode: getMatrix returns valid table", function()
	local qr = qrCode.encodeText("Test", types.ecc.low)
	if not qr then
		return false
	end

	local matrix = {}
	for y = 0, qr.size - 1 do
		local row = {}
		for x = 0, qr.size - 1 do
			table.insert(row, qr:getModule(x, y) and 1 or 0)
		end
		table.insert(matrix, row)
	end

	return #matrix == qr.size and #matrix[1] == qr.size
end)

-- output test qr codes for external verification
print("\n=== generating test qr codes for external verification ===")

local function outputQrAsAscii(qr: QrCodeType, name: string)
	print("\n" .. name .. " (Version " .. qr.version .. ", " .. qr.size .. "x" .. qr.size .. "):")
	for y = 0, qr.size - 1 do
		local line = ""
		for x = 0, qr.size - 1 do
			line = line .. (qr:getModule(x, y) and "██" or "  ")
		end
		print(line)
	end
end

local function outputQrAsMatrix(qr: QrCodeType)
	local rows = {}
	for y = 0, qr.size - 1 do
		local row = {}
		for x = 0, qr.size - 1 do
			table.insert(row, qr:getModule(x, y) and 1 or 0)
		end
		table.insert(rows, "[" .. table.concat(row, ",") .. "]")
	end
	print('{"version":' .. qr.version .. ',"size":' .. qr.size .. ',"matrix":[' .. table.concat(rows, ",") .. "]}")
end

type Sample = {
	text: string,
	ecl: types.ErrorCorrectionLevel,
}

-- generate sample qr codes
local samples: { Sample } = {
	{ text = "Hello, World!", ecl = types.ecc.medium },
	{ text = "12345", ecl = types.ecc.low },
	{ text = "HELLO WORLD", ecl = types.ecc.medium },
	{ text = "https://roblox.com", ecl = types.ecc.quartile },
	{ text = "https://www.youtube.com/watch?v=dQw4w9WgXcQ", ecl = types.ecc.medium },
}

for _, sample in samples do
	local text = sample.text
	local ecl = sample.ecl

	local success, qr = pcall(function()
		return qrCode.encodeText(text, ecl)
	end)

	if success and qr then
		outputQrAsAscii(qr, text)
		print("\nJSON output:")
		outputQrAsMatrix(qr)
	else
		print("Failed to generate QR code for: " .. text)
		if not success then
			print("Error: " .. tostring(qr))
		end
	end
end

-- print summary
print("\n=== test summary ===")
print("Passed: " .. passCount)
print("Failed: " .. failCount)
print("Total: " .. (passCount + failCount))

if failCount > 0 then
	error("Test suite failed")
end
