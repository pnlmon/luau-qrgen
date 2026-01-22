--!strict
--[[
    performance benchmark for luau-qrgen.
]]

local qrCode = require("../src/qrCode")
local qrSegment = require("../src/qrSegment")
local types = require("../src/types")

local function measure(name: string, iterations: number, fn: () -> ())
	-- warmup
	for _ = 1, math.min(10, iterations) do
		fn()
	end

	local start = os.clock()
	for _ = 1, iterations do
		fn()
	end
	local elapsed = os.clock() - start

	local avgMs = (elapsed / iterations) * 1000
	print(string.format("%-40s %8d iterations, %8.3f ms total, %8.4f ms/iter", name, iterations, elapsed * 1000, avgMs))

	return avgMs
end

print("=== luau-qrgen Performance Benchmark ===\n")
print("Testing QR code generation performance...\n")

-- test different input sizes and types
local testCases = {
	{ name = "Short numeric (5 chars)", data = "12345", ecl = types.ecc.low, iters = 1000 },
	{ name = "Short alphanumeric (11 chars)", data = "HELLO WORLD", ecl = types.ecc.medium, iters = 1000 },
	{ name = "Short text (13 chars)", data = "Hello, World!", ecl = types.ecc.medium, iters = 1000 },
	{ name = "URL (18 chars)", data = "https://roblox.com", ecl = types.ecc.quartile, iters = 500 },
	{ name = "Medium text (50 chars)", data = string.rep("A", 50), ecl = types.ecc.medium, iters = 200 },
	{ name = "Long text (200 chars)", data = string.rep("A", 200), ecl = types.ecc.low, iters = 100 },
	{ name = "Very long text (500 chars)", data = string.rep("Test ", 100), ecl = types.ecc.low, iters = 50 },
	{ name = "Max Low ECC (~2953 bytes)", data = string.rep("A", 2900), ecl = types.ecc.low, iters = 10 },
}

print(string.format("%-40s %8s %18s %12s", "Test Case", "Iters", "Total (ms)", "Avg (ms)"))
print(string.rep("-", 85))

local totalTime = 0
for _, tc in testCases do
	local ms = measure(tc.name, tc.iters, function()
		qrCode.encodeText(tc.data, tc.ecl)
	end)
	totalTime += ms * tc.iters
end

print(string.rep("-", 85))
print(string.format("\nTotal benchmark time: %.2f ms", totalTime))

-- test different ecc levels impact
print("\n\n=== ECC Level Performance Impact ===\n")
local testData = "Hello, World! This is a QR code test."

print(string.format("%-20s %12s", "ECC Level", "Avg (ms)"))
print(string.rep("-", 35))

local eccLevels: { { name: string, level: types.ErrorCorrectionLevel } } = {
	{ name = "LOW", level = types.ecc.low },
	{ name = "MEDIUM", level = types.ecc.medium },
	{ name = "QUARTILE", level = types.ecc.quartile },
	{ name = "HIGH", level = types.ecc.high },
}

for _, ecl in eccLevels do
	measure(ecl.name, 200, function()
		qrCode.encodeText(testData, ecl.level)
	end)
end

-- test specific mask patterns
print("\n\n=== Mask Pattern Selection Impact ===\n")
print("Comparing auto mask (-1) vs specific masks (0-7)\n")

print(string.format("%-20s %12s", "Mask", "Avg (ms)"))
print(string.rep("-", 35))

local segs = qrSegment.makeSegments("Hello, World!")

-- auto mask selection
measure("Auto mask (-1)", 200, function()
	qrCode.encodeSegments(segs, types.ecc.medium, 1, 40, -1, true)
end)

-- specific mask patterns
for mask = 0, 7 do
	measure("Mask " .. mask, 200, function()
		qrCode.encodeSegments(segs, types.ecc.medium, 1, 40, mask, true)
	end)
end

print("\n=== Benchmark Complete ===")
