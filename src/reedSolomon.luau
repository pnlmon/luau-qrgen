--!strict
--[[
    reed-solomon error correction helpers.
]]

local reedSolomon = {}

local expTable = table.create(512) :: { number }
local logTable = table.create(256) :: { number }

do
	local x = 1
	for i = 0, 254 do
		expTable[i] = x
		expTable[i + 255] = x
		logTable[x] = i
		x = bit32.lshift(x, 1)
		if x >= 256 then
			x = bit32.bxor(x, 0x11D)
		end
	end
	logTable[0] = 0
end

function reedSolomon.multiply(x: number, y: number): number
	if x == 0 or y == 0 then
		return 0
	end
	return expTable[logTable[x] + logTable[y]]
end

function reedSolomon.computeDivisor(degree: number): { number }
	if degree < 1 or degree > 255 then
		error("Degree out of range: " .. tostring(degree))
	end

	local result = {} :: { number }
	for i = 1, degree - 1 do
		result[i] = 0
	end
	result[degree] = 1

	local root = 1
	for _ = 0, degree - 1 do
		for j = 1, #result do
			result[j] = reedSolomon.multiply(result[j], root)
			if j + 1 <= #result then
				result[j] = bit32.bxor(result[j], result[j + 1])
			end
		end
		root = reedSolomon.multiply(root, 0x02)
	end

	return result
end

function reedSolomon.computeRemainder(data: { number }, divisor: { number }): { number }
	local result = {} :: { number }
	for i = 1, #divisor do
		result[i] = 0
	end

	for _, b in data do
		local factor = bit32.bxor(b, table.remove(result, 1) :: number)
		table.insert(result, 0)
		for i = 1, #divisor do
			result[i] = bit32.bxor(result[i], reedSolomon.multiply(divisor[i], factor))
		end
	end

	return result
end

return reedSolomon
