--!strict
--[=[
    @class QrSegment

    Segment creation for different encoding modes.

    ```lua
    local numSeg = QrSegment.makeNumeric("12345")
    local alphaSeg = QrSegment.makeAlphanumeric("HELLO")
    local autoSegs = QrSegment.makeSegments("Hello, World!")
    ```
]=]

local bitBuffer = require("./bitBuffer")
local types = require("./types")

type Mode = types.Mode

local qrSegment = {}
qrSegment.__index = qrSegment

export type QrSegment = typeof(setmetatable(
	{} :: {
		mode: Mode,
		numChars: number,
		bitData: { number },
	},
	qrSegment
))

function qrSegment.new(mode: Mode, numChars: number, bitData: { number }): QrSegment
	if numChars < 0 then
		error("Invalid numChars: must be non-negative")
	end

	local self = setmetatable({
		mode = mode,
		numChars = numChars,
		bitData = table.clone(bitData),
	}, qrSegment)
	return self
end

function qrSegment.makeBytes(data: { number }): QrSegment
	local bb = bitBuffer.new()
	for _, b in data do
		if b < 0 or b > 255 then
			error("Byte value out of range: " .. tostring(b))
		end
		bb:appendBits(b, 8)
	end
	return qrSegment.new(types.mode.byte, #data, bb:getBits())
end

function qrSegment.makeNumeric(digits: string): QrSegment
	if not qrSegment.isNumeric(digits) then
		error("String contains non-numeric characters")
	end

	local bb = bitBuffer.new()
	local i = 1
	while i <= #digits do
		local n = math.min(#digits - i + 1, 3)
		local chunk = string.sub(digits, i, i + n - 1)
		local value = tonumber(chunk) :: number
		bb:appendBits(value, n * 3 + 1)
		i += n
	end
	return qrSegment.new(types.mode.numeric, #digits, bb:getBits())
end

function qrSegment.makeAlphanumeric(text: string): QrSegment
	if not qrSegment.isAlphanumeric(text) then
		error("String contains unencodable characters in alphanumeric mode")
	end

	local bb = bitBuffer.new()
	local charset = types.alphanumericCharset
	local i = 1

	while i + 1 <= #text do
		local char1 = string.sub(text, i, i)
		local char2 = string.sub(text, i + 1, i + 1)
		local idx1 = string.find(charset, char1, 1, true)
		local idx2 = string.find(charset, char2, 1, true)

		if idx1 == nil or idx2 == nil then
			error("Character not found in alphanumeric charset")
		end

		local value = (idx1 - 1) * 45 + (idx2 - 1)
		bb:appendBits(value, 11)
		i += 2
	end

	if i <= #text then
		local char = string.sub(text, i, i)
		local idx = string.find(charset, char, 1, true)
		if idx == nil then
			error("Character not found in alphanumeric charset")
		end
		bb:appendBits(idx - 1, 6)
	end

	return qrSegment.new(types.mode.alphanumeric, #text, bb:getBits())
end

function qrSegment.makeEci(assignVal: number): QrSegment
	local bb = bitBuffer.new()

	if assignVal < 0 or assignVal >= 1000000 then
		error("ECI assignment value out of range")
	elseif assignVal < 128 then
		bb:appendBits(assignVal, 8)
	elseif assignVal < 16384 then
		bb:appendBits(2, 2)
		bb:appendBits(assignVal, 14)
	else
		bb:appendBits(6, 3)
		bb:appendBits(assignVal, 21)
	end

	return qrSegment.new(types.mode.eci, 0, bb:getBits())
end

function qrSegment.makeSegments(text: string): { QrSegment }
	if text == "" then
		return {}
	elseif qrSegment.isNumeric(text) then
		return { qrSegment.makeNumeric(text) }
	elseif qrSegment.isAlphanumeric(text) then
		return { qrSegment.makeAlphanumeric(text) }
	else
		return { qrSegment.makeBytes(qrSegment.toUtf8ByteArray(text)) }
	end
end

function qrSegment.isNumeric(text: string): boolean
	return string.match(text, "^%d*$") ~= nil
end

function qrSegment.isAlphanumeric(text: string): boolean
	local charset = types.alphanumericCharset
	for i = 1, #text do
		local char = string.sub(text, i, i)
		if string.find(charset, char, 1, true) == nil then
			return false
		end
	end
	return true
end

function qrSegment.toUtf8ByteArray(str: string): { number }
	local result = table.create(#str) :: { number }
	for i = 1, #str do
		local byte = string.byte(str, i)
		if byte ~= nil then
			table.insert(result, byte)
		end
	end
	return result
end

function qrSegment.getData(self: QrSegment): { number }
	return table.clone(self.bitData)
end

function qrSegment.getTotalBits(segs: { QrSegment }, version: number): number
	local result = 0
	for _, seg in segs do
		local ccbits = types.getNumCharCountBits(seg.mode, version)
		if seg.numChars >= bit32.lshift(1, ccbits) then
			return math.huge
		end
		result += 4 + ccbits + #seg.bitData
	end
	return result
end

return qrSegment
