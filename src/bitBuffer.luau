--!strict
--[[
    bit buffer utilities.
]]

local bitBuffer = {}
bitBuffer.__index = bitBuffer

export type BitBuffer = typeof(setmetatable(
	{} :: {
		bits: { number },
	},
	bitBuffer
))

function bitBuffer.new(): BitBuffer
	local self = setmetatable({
		bits = {} :: { number },
	}, bitBuffer)
	return self
end

function bitBuffer.appendBits(self: BitBuffer, val: number, len: number): ()
	if len < 0 or len > 31 then
		error("Bit length out of range: " .. tostring(len))
	end
	if val < 0 or (len < 31 and val >= bit32.lshift(1, len)) then
		error("Value out of range for bit length")
	end

	for i = len - 1, 0, -1 do
		local bit = bit32.band(bit32.rshift(val, i), 1)
		table.insert(self.bits, bit)
	end
end

function bitBuffer.getBits(self: BitBuffer): { number }
	local result = table.clone(self.bits)
	return result
end

return bitBuffer
