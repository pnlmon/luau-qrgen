--!strict
--[[
    test runner for luau-qrgen.
]]

local qrCode = require("../src/qrCode")
local types = require("../src/types")
local svgRenderer = require("../src/svgRenderer")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

type TestInput = {
	data: string?,
	errorCorrection: string?,
	isBinary: boolean?,
	binaryData: { number }?,
}

local function readJson(path: string): TestInput
	local content = fs.readFile(path)
	return serde.decode("json", content) :: TestInput
end

local function writeJson(path: string, value: any): ()
	fs.writeFile(path, serde.encode("json", value, true))
end

local function getEcl(level: string?): types.ErrorCorrectionLevel
	if level == "L" then
		return types.ecc.low
	elseif level == "M" then
		return types.ecc.medium
	elseif level == "Q" then
		return types.ecc.quartile
	elseif level == "H" then
		return types.ecc.high
	else
		return types.ecc.medium
	end
end

local function main(args: { string })
	if #args < 2 then
		print("Usage: lune run tests/runTest.luau <input.json> <output.json>")
		return
	end

	local inputPath = args[1]
	local outputPath = args[2]

	local input = readJson(inputPath)
	local data = input.data or ""
	local ecl = getEcl(input.errorCorrection)

	local success, result = pcall(function()
		if input.isBinary == true and input.binaryData ~= nil then
			return qrCode.encodeBinary(input.binaryData, ecl)
		end
		return qrCode.encodeText(data, ecl)
	end)

	if not success then
		local output = {
			success = false,
			error = tostring(result),
		}
		writeJson(outputPath, output)
		print("Error generating QR code: " .. tostring(result))
		return
	end

	local qr = result

	local matrix: { { number } } = {}
	for y = 0, qr.size - 1 do
		local row: { number } = {}
		for x = 0, qr.size - 1 do
			table.insert(row, qr:getModule(x, y) and 1 or 0)
		end
		table.insert(matrix, row)
	end

	local svg = svgRenderer.render(qr, { scale = 5, border = 2 })

	local output = {
		success = true,
		version = qr.version,
		size = qr.size,
		errorCorrectionLevel = input.errorCorrection or "M",
		matrix = matrix,
		svg = svg,
	}

	writeJson(outputPath, output)

	-- Also write SVG file
	local svgPath = outputPath:gsub(".json$", ".svg")
	fs.writeFile(svgPath, svg)

	print("Successfully generated QR code")
	print("  Version: " .. qr.version)
	print("  Size: " .. qr.size .. "x" .. qr.size)
end

main(process.args)
