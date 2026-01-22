--!strict
--[=[
    @class QrCode

    QR code generation and data access.

    ```lua
    local qr = QrCode.encodeText("Hello", types.ecc.medium)
    print(qr.version, qr.size)
    ```
]=]

local qrSegment = require("./qrSegment")
local reedSolomon = require("./reedSolomon")
local types = require("./types")

type ErrorCorrectionLevel = types.ErrorCorrectionLevel
type QrSegmentType = qrSegment.QrSegment

local QrCode = {}
QrCode.__index = QrCode

export type QrCode = typeof(setmetatable(
	{} :: {
		version: number,
		size: number,
		errorCorrectionLevel: ErrorCorrectionLevel,
		mask: number,
		modules: { { boolean } },
		isFunction: { { boolean } },
	},
	QrCode
))

-- helper: get bit at position i of value x
local function getBit(x: number, i: number): boolean
	return bit32.band(bit32.rshift(x, i), 1) ~= 0
end

-- helper: append bits to a bit array
local function appendBits(val: number, len: number, bb: { number }): ()
	if len < 0 or len > 31 then
		error("Bit length out of range")
	end
	for i = len - 1, 0, -1 do
		table.insert(bb, bit32.band(bit32.rshift(val, i), 1))
	end
end

-- returns the number of data bits available in a qr code of the given version
local function getNumRawDataModules(ver: number): number
	if ver < types.minVersion or ver > types.maxVersion then
		error("Version number out of range")
	end

	local result = (16 * ver + 128) * ver + 64
	if ver >= 2 then
		local numAlign = math.floor(ver / 7) + 2
		result -= (25 * numAlign - 10) * numAlign - 55
		if ver >= 7 then
			result -= 36
		end
	end
	return result
end

-- returns the number of data codewords for a given version and error correction level
local function getNumDataCodewords(ver: number, ecl: ErrorCorrectionLevel): number
	local eccPerBlock = types.eccCodewordsPerBlock[ecl.ordinal + 1][ver + 1]
	local numBlocks = types.numErrorCorrectionBlocks[ecl.ordinal + 1][ver + 1]
	return math.floor(getNumRawDataModules(ver) / 8) - eccPerBlock * numBlocks
end

function QrCode.encodeText(text: string, ecl: ErrorCorrectionLevel): QrCode
	local segs = qrSegment.makeSegments(text)
	return QrCode.encodeSegments(segs, ecl, types.minVersion, types.maxVersion, -1, true)
end

function QrCode.encodeBinary(data: { number }, ecl: ErrorCorrectionLevel): QrCode
	local seg = qrSegment.makeBytes(data)
	return QrCode.encodeSegments({ seg }, ecl, types.minVersion, types.maxVersion, -1, true)
end

function QrCode.encodeSegments(
	segs: { QrSegmentType },
	ecl: ErrorCorrectionLevel,
	minVersion: number?,
	maxVersion: number?,
	mask: number?,
	boostEcl: boolean?
): QrCode
	local minVer = minVersion or types.minVersion
	local maxVer = maxVersion or types.maxVersion
	local msk = mask or -1
	local boost = if boostEcl == nil then true else boostEcl

	if minVer < types.minVersion or minVer > maxVer or maxVer > types.maxVersion then
		error("Invalid version range")
	end
	if msk < -1 or msk > 7 then
		error("Invalid mask value")
	end

	local version: number = minVer
	local dataUsedBits: number = 0

	while true do
		local dataCapacityBits = getNumDataCodewords(version, ecl) * 8
		local usedBits = qrSegment.getTotalBits(segs, version)

		if usedBits <= dataCapacityBits then
			dataUsedBits = usedBits
			break
		end

		if version >= maxVer then
			error("Data too long for QR Code capacity")
		end
		version += 1
	end

	if boost then
		for _, newEcl in { types.ecc.medium, types.ecc.quartile, types.ecc.high } do
			if dataUsedBits <= getNumDataCodewords(version, newEcl) * 8 then
				ecl = newEcl
			end
		end
	end

	local bb: { number } = {}
	for _, seg in segs do
		appendBits(seg.mode.modeBits, 4, bb)
		appendBits(seg.numChars, types.getNumCharCountBits(seg.mode, version), bb)
		for _, bit in seg:getData() do
			table.insert(bb, bit)
		end
	end

	local dataCapacityBits = getNumDataCodewords(version, ecl) * 8
	appendBits(0, math.min(4, dataCapacityBits - #bb), bb)
	appendBits(0, (8 - #bb % 8) % 8, bb)

	local padByte = 0xEC
	while #bb < dataCapacityBits do
		appendBits(padByte, 8, bb)
		padByte = bit32.bxor(padByte, bit32.bxor(0xEC, 0x11))
	end

	local dataCodewords: { number } = {}
	local byteCount = math.ceil(#bb / 8)
	for i = 1, byteCount do
		dataCodewords[i] = 0
	end
	for i, bit in bb do
		local byteIndex = math.floor((i - 1) / 8) + 1
		local bitIndex = 7 - ((i - 1) % 8)
		dataCodewords[byteIndex] = bit32.bor(dataCodewords[byteIndex], bit32.lshift(bit, bitIndex))
	end

	return QrCode.new(version, ecl, dataCodewords, msk)
end

function QrCode.new(version: number, ecl: ErrorCorrectionLevel, dataCodewords: { number }, msk: number): QrCode
	if version < types.minVersion or version > types.maxVersion then
		error("Version out of range")
	end
	if msk < -1 or msk > 7 then
		error("Mask value out of range")
	end

	local size = version * 4 + 17

	local modules: { { boolean } } = table.create(size)
	local isFunction: { { boolean } } = table.create(size)

	for y = 1, size do
		modules[y] = table.create(size, false)
		isFunction[y] = table.create(size, false)
	end

	local self = setmetatable({
		version = version,
		size = size,
		errorCorrectionLevel = ecl,
		mask = -1, -- set later
		modules = modules,
		isFunction = isFunction,
	}, QrCode)

	self:drawFunctionPatterns()

	local allCodewords = self:addEccAndInterleave(dataCodewords)

	self:drawCodewords(allCodewords)

	if msk == -1 then
		local minPenalty = 1000000000
		for i = 0, 7 do
			self:applyMask(i)
			self:drawFormatBits(i)
			local penalty = self:getPenaltyScore()
			if penalty < minPenalty then
				msk = i
				minPenalty = penalty
			end
			self:applyMask(i) -- undo mask
		end
	end

	self.mask = msk
	self:applyMask(msk)
	self:drawFormatBits(msk)

	self.isFunction = {}

	return self
end

function QrCode.getModule(self: QrCode, x: number, y: number): boolean
	local xi = x + 1
	local yi = y + 1

	if xi >= 1 and xi <= self.size and yi >= 1 and yi <= self.size then
		return self.modules[yi][xi]
	end
	return false
end

function QrCode.getMatrix(self: QrCode): { { boolean } }
	local result: { { boolean } } = {}
	for y = 1, self.size do
		result[y] = {}
		for x = 1, self.size do
			result[y][x] = self.modules[y][x]
		end
	end
	return result
end

-- draw all function patterns on the qr code
function QrCode.drawFunctionPatterns(self: QrCode): ()
	-- draw horizontal and vertical timing patterns
	for i = 0, self.size - 1 do
		self:setFunctionModule(6, i, i % 2 == 0)
		self:setFunctionModule(i, 6, i % 2 == 0)
	end

	-- draw 3 finder patterns
	self:drawFinderPattern(3, 3)
	self:drawFinderPattern(self.size - 4, 3)
	self:drawFinderPattern(3, self.size - 4)

	-- draw alignment patterns
	local alignPatPos = self:getAlignmentPatternPositions()
	local numAlign = #alignPatPos

	for i = 1, numAlign do
		for j = 1, numAlign do
			-- don't draw on the three finder corners
			if not ((i == 1 and j == 1) or (i == 1 and j == numAlign) or (i == numAlign and j == 1)) then
				self:drawAlignmentPattern(alignPatPos[i], alignPatPos[j])
			end
		end
	end

	-- draw format bits (placeholder) and version bits
	self:drawFormatBits(0)
	self:drawVersion()
end

-- draw the format information (error correction level and mask)
function QrCode.drawFormatBits(self: QrCode, mask: number): ()
	-- calculate error correction code
	local data = bit32.bor(bit32.lshift(self.errorCorrectionLevel.formatBits, 3), mask)
	local rem = data
	for _ = 1, 10 do
		rem = bit32.bxor(bit32.lshift(rem, 1), bit32.band(bit32.rshift(rem, 9), 1) * 0x537)
	end
	local bits = bit32.bxor(bit32.bor(bit32.lshift(data, 10), rem), 0x5412)

	-- draw first copy
	for i = 0, 5 do
		self:setFunctionModule(8, i, getBit(bits, i))
	end
	self:setFunctionModule(8, 7, getBit(bits, 6))
	self:setFunctionModule(8, 8, getBit(bits, 7))
	self:setFunctionModule(7, 8, getBit(bits, 8))
	for i = 9, 14 do
		self:setFunctionModule(14 - i, 8, getBit(bits, i))
	end

	-- draw second copy
	for i = 0, 7 do
		self:setFunctionModule(self.size - 1 - i, 8, getBit(bits, i))
	end
	for i = 8, 14 do
		self:setFunctionModule(8, self.size - 15 + i, getBit(bits, i))
	end
	self:setFunctionModule(8, self.size - 8, true) -- always dark
end

-- draw the version information (for version 7+)
function QrCode.drawVersion(self: QrCode): ()
	if self.version < 7 then
		return
	end

	-- calculate error correction code
	local rem = self.version
	for _ = 1, 12 do
		rem = bit32.bxor(bit32.lshift(rem, 1), bit32.band(bit32.rshift(rem, 11), 1) * 0x1F25)
	end
	local bits = bit32.bor(bit32.lshift(self.version, 12), rem)

	-- draw two copies
	for i = 0, 17 do
		local color = getBit(bits, i)
		local a = self.size - 11 + (i % 3)
		local b = math.floor(i / 3)
		self:setFunctionModule(a, b, color)
		self:setFunctionModule(b, a, color)
	end
end

-- draw a 9x9 finder pattern including border separator
function QrCode.drawFinderPattern(self: QrCode, x: number, y: number): ()
	for dy = -4, 4 do
		for dx = -4, 4 do
			local dist = math.max(math.abs(dx), math.abs(dy))
			local xx = x + dx
			local yy = y + dy
			if xx >= 0 and xx < self.size and yy >= 0 and yy < self.size then
				self:setFunctionModule(xx, yy, dist ~= 2 and dist ~= 4)
			end
		end
	end
end

-- draw a 5x5 alignment pattern
function QrCode.drawAlignmentPattern(self: QrCode, x: number, y: number): ()
	for dy = -2, 2 do
		for dx = -2, 2 do
			self:setFunctionModule(x + dx, y + dy, math.max(math.abs(dx), math.abs(dy)) ~= 1)
		end
	end
end

-- set a module and mark it as a function module
function QrCode.setFunctionModule(self: QrCode, x: number, y: number, isDark: boolean): ()
	-- convert to 1-indexed
	local xi = x + 1
	local yi = y + 1

	if xi >= 1 and xi <= self.size and yi >= 1 and yi <= self.size then
		self.modules[yi][xi] = isDark
		self.isFunction[yi][xi] = true
	end
end

-- get alignment pattern positions
function QrCode.getAlignmentPatternPositions(self: QrCode): { number }
	if self.version == 1 then
		return {}
	end

	local numAlign = math.floor(self.version / 7) + 2
	local step: number
	if self.version == 32 then
		step = 26
	else
		step = math.floor((self.version * 8 + numAlign * 3 + 5) / (numAlign * 4 - 4)) * 2
	end

	local result = { 6 }
	local pos = self.size - 7
	while #result < numAlign do
		table.insert(result, 2, pos)
		pos -= step
	end

	return result
end

function QrCode.addEccAndInterleave(self: QrCode, data: { number }): { number }
	local ver = self.version
	local ecl = self.errorCorrectionLevel

	local numBlocks = types.numErrorCorrectionBlocks[ecl.ordinal + 1][ver + 1]
	local blockEccLen = types.eccCodewordsPerBlock[ecl.ordinal + 1][ver + 1]
	local rawCodewords = math.floor(getNumRawDataModules(ver) / 8)
	local numShortBlocks = numBlocks - rawCodewords % numBlocks
	local shortBlockLen = math.floor(rawCodewords / numBlocks)

	-- split data into blocks and compute ecc
	local blocks: { { number } } = {}
	local rsDiv = reedSolomon.computeDivisor(blockEccLen)
	local k = 1

	for i = 0, numBlocks - 1 do
		local datLen = shortBlockLen - blockEccLen + (if i < numShortBlocks then 0 else 1)
		local dat: { number } = {}
		for j = 1, datLen do
			dat[j] = data[k]
			k += 1
		end

		local ecc = reedSolomon.computeRemainder(dat, rsDiv)

		if i < numShortBlocks then
			table.insert(dat, 0)
		end

		for _, eccByte in ecc do
			table.insert(dat, eccByte)
		end

		table.insert(blocks, dat)
	end

	-- interleave bytes from all blocks
	local result: { number } = {}
	for i = 1, #blocks[1] do
		for j, block in blocks do
			-- skip padding byte in short blocks
			if i ~= shortBlockLen - blockEccLen + 1 or j > numShortBlocks then
				table.insert(result, block[i])
			end
		end
	end

	return result
end

function QrCode.drawCodewords(self: QrCode, data: { number }): ()
	local i = 0 -- bit index
	local size = self.size
	local modules = self.modules
	local isFunction = self.isFunction
	local dataBits = #data * 8

	-- zigzag scan
	local right = size - 1
	while right >= 1 do
		if right == 6 then
			right = 5
		end

		for vert = 0, size - 1 do
			for j = 0, 1 do
				local x = right - j
				local upward = bit32.band(right + 1, 2) == 0
				local y = if upward then size - 1 - vert else vert

				-- convert to 1-indexed
				local xi = x + 1
				local yi = y + 1

				local rowIsFunction = isFunction[yi]
				if rowIsFunction[xi] == false and i < dataBits then
					local byteIndex = math.floor(i / 8) + 1
					local bitIndex = 7 - (i % 8)
					modules[yi][xi] = getBit(data[byteIndex], bitIndex)
					i += 1
				end
			end
		end

		right -= 2
	end
end

-- mask pattern functions (returns true if module should be inverted)
local maskFunctions = {
	[0] = function(x: number, y: number): boolean
		return (x + y) % 2 == 0
	end,
	[1] = function(_x: number, y: number): boolean
		return y % 2 == 0
	end,
	[2] = function(x: number, _y: number): boolean
		return x % 3 == 0
	end,
	[3] = function(x: number, y: number): boolean
		return (x + y) % 3 == 0
	end,
	[4] = function(x: number, y: number): boolean
		return (math.floor(x / 3) + math.floor(y / 2)) % 2 == 0
	end,
	[5] = function(x: number, y: number): boolean
		local xy = x * y
		return xy % 2 + xy % 3 == 0
	end,
	[6] = function(x: number, y: number): boolean
		local xy = x * y
		return (xy % 2 + xy % 3) % 2 == 0
	end,
	[7] = function(x: number, y: number): boolean
		local xy = x * y
		return ((x + y) % 2 + xy % 3) % 2 == 0
	end,
}

function QrCode.applyMask(self: QrCode, mask: number): ()
	if mask < 0 or mask > 7 then
		error("Mask value out of range")
	end

	local size = self.size
	local modules = self.modules
	local isFunction = self.isFunction
	local maskFn = maskFunctions[mask]

	for y = 0, size - 1 do
		local yi = y + 1
		local row = modules[yi]
		local rowIsFunction = isFunction[yi]

		for x = 0, size - 1 do
			local xi = x + 1

			if rowIsFunction[xi] == false and maskFn(x, y) then
				row[xi] = not row[xi]
			end
		end
	end
end

--[[
    Penalty scoring - Optimized for performance
]]

-- inlined penalty helper: add to history
local function finderPenaltyAddHistory(currentRunLength: number, runHistory: { number }, size: number): ()
	local len = currentRunLength
	if runHistory[1] == 0 then
		len += size
	end
	-- shift history manually (faster than table.remove/insert)
	runHistory[7] = runHistory[6]
	runHistory[6] = runHistory[5]
	runHistory[5] = runHistory[4]
	runHistory[4] = runHistory[3]
	runHistory[3] = runHistory[2]
	runHistory[2] = runHistory[1]
	runHistory[1] = len
end

-- inlined penalty helper: count patterns (optimized)
local function finderPenaltyCountPatterns(runHistory: { number }): number
	local n = runHistory[2]
	if n <= 0 then
		return 0
	end

	local h1, h3, h4, h5, h6, h7 =
		runHistory[1], runHistory[3], runHistory[4], runHistory[5], runHistory[6], runHistory[7]

	-- check core pattern: 1:1:3:1:1 ratio
	if h3 ~= n or h4 ~= n * 3 or h5 ~= n or h6 ~= n then
		return 0
	end

	-- count matches with 4+ quiet zone on either side
	local count = 0
	local n4 = n * 4
	if h1 >= n4 and h7 >= n then
		count = 1
	end
	if h7 >= n4 and h1 >= n then
		count += 1
	end
	return count
end

function QrCode.getPenaltyScore(self: QrCode): number
	local result = 0
	local size = self.size
	local modules = self.modules
	local penaltyN1 = types.penaltyN1
	local penaltyN2 = types.penaltyN2
	local penaltyN3 = types.penaltyN3
	local penaltyN4 = types.penaltyN4

	-- adjacent modules in row having same color
	for y = 1, size do
		local runColor = false
		local runX = 0
		local runHistory = { 0, 0, 0, 0, 0, 0, 0 }
		local row = modules[y]

		for x = 1, size do
			if row[x] == runColor then
				runX += 1
				if runX == 5 then
					result += penaltyN1
				elseif runX > 5 then
					result += 1
				end
			else
				finderPenaltyAddHistory(runX, runHistory, size)
				if runColor == false then
					result += finderPenaltyCountPatterns(runHistory) * penaltyN3
				end
				runColor = row[x]
				runX = 1
			end
		end
		-- terminate row
		if runColor then
			finderPenaltyAddHistory(runX, runHistory, size)
			runX = 0
		end
		finderPenaltyAddHistory(runX + size, runHistory, size)
		result += finderPenaltyCountPatterns(runHistory) * penaltyN3
	end

	-- adjacent modules in column having same color
	for x = 1, size do
		local runColor = false
		local runY = 0
		local runHistory = { 0, 0, 0, 0, 0, 0, 0 }

		for y = 1, size do
			local mod = modules[y][x]
			if mod == runColor then
				runY += 1
				if runY == 5 then
					result += penaltyN1
				elseif runY > 5 then
					result += 1
				end
			else
				finderPenaltyAddHistory(runY, runHistory, size)
				if runColor == false then
					result += finderPenaltyCountPatterns(runHistory) * penaltyN3
				end
				runColor = mod
				runY = 1
			end
		end
		-- terminate column
		if runColor then
			finderPenaltyAddHistory(runY, runHistory, size)
			runY = 0
		end
		finderPenaltyAddHistory(runY + size, runHistory, size)
		result += finderPenaltyCountPatterns(runHistory) * penaltyN3
	end

	-- 2x2 blocks of modules having same color
	for y = 1, size - 1 do
		local row = modules[y]
		local rowNext = modules[y + 1]
		for x = 1, size - 1 do
			local color = row[x]
			if color == row[x + 1] and color == rowNext[x] and color == rowNext[x + 1] then
				result += penaltyN2
			end
		end
	end

	-- balance of dark and light modules
	local dark = 0
	for y = 1, size do
		local row = modules[y]
		for x = 1, size do
			if row[x] then
				dark += 1
			end
		end
	end
	local total = size * size
	local k = math.ceil(math.abs(dark * 20 - total * 10) / total) - 1
	result += k * penaltyN4

	return result
end

-- legacy methods kept for api compatibility but now unused internally
function QrCode.finderPenaltyCountPatterns(_self: QrCode, runHistory: { number }): number
	return finderPenaltyCountPatterns(runHistory)
end

function QrCode.finderPenaltyTerminateAndCount(
	self: QrCode,
	currentRunColor: boolean,
	currentRunLength: number,
	runHistory: { number }
): number
	local runLen = currentRunLength
	if currentRunColor then
		finderPenaltyAddHistory(runLen, runHistory, self.size)
		runLen = 0
	end
	runLen += self.size
	finderPenaltyAddHistory(runLen, runHistory, self.size)
	return finderPenaltyCountPatterns(runHistory)
end

function QrCode.finderPenaltyAddHistory(self: QrCode, currentRunLength: number, runHistory: { number }): ()
	finderPenaltyAddHistory(currentRunLength, runHistory, self.size)
end

return QrCode
