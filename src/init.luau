--!strict
--[=[
    @class qrgen

    QR code generation for Lune and Roblox.

    ```lua
    local qrgen = require("@packages/qrgen")
    local qr = qrgen.encodeText("Hello", qrgen.ecc.medium)
    print(qrgen.toString(qr))
    ```
]=]

local bitBuffer = require(script.bitBuffer)
local qrCode = require(script.qrCode)
local qrSegment = require(script.qrSegment)
local reedSolomon = require(script.reedSolomon)
local svgRenderer = require(script.svgRenderer)
local types = require(script.types)
local frameRenderer = require(script.frameRenderer)

export type ErrorCorrectionLevel = types.ErrorCorrectionLevel
export type Mode = types.Mode
export type QrSegment = qrSegment.QrSegment
export type QrCode = qrCode.QrCode
export type SvgOptions = svgRenderer.SvgOptions
export type FrameRenderOptions = frameRenderer.RenderOptions

export type RenderOptions = {
	darkColor: Color3?,
	lightColor: Color3?,
	border: number?,
	moduleSize: number?,
}

local qrgen = {}

--[=[
    @prop ecc { low: ErrorCorrectionLevel, medium: ErrorCorrectionLevel, quartile: ErrorCorrectionLevel, high: ErrorCorrectionLevel }
    @within qrgen

    Error correction levels. Higher = more recovery, larger code.
    - `low`: ~7%
    - `medium`: ~15%
    - `quartile`: ~25%
    - `high`: ~30%
]=]
qrgen.ecc = types.ecc

--[=[
    @prop mode { numeric: Mode, alphanumeric: Mode, byte: Mode, kanji: Mode, eci: Mode }
    @within qrgen

    Encoding modes for segments.
]=]
qrgen.mode = types.mode

--[=[
    @prop minVersion number
    @within qrgen
    @readonly

    Minimum QR code version (1).
]=]
qrgen.minVersion = types.minVersion

--[=[
    @prop maxVersion number
    @within qrgen
    @readonly

    Maximum QR code version (40).
]=]
qrgen.maxVersion = types.maxVersion

--[=[
    @prop segment QrSegment
    @within qrgen
    Segment creation. See [QrSegment].
]=]
qrgen.segment = qrSegment

--[=[
    @prop code QrCode
    @within qrgen
    Low-level QR code access. See [QrCode].
]=]
qrgen.code = qrCode

--[=[
    @prop svg SvgRenderer
    @within qrgen
    SVG output. See [svgRenderer].
]=]
qrgen.svg = svgRenderer

--[=[
    @prop frame FrameRenderer?
    @within qrgen
    Roblox Frame renderer. Nil outside Roblox. See [frameRenderer].
]=]
qrgen.frame = frameRenderer

-- internal helpers (not documented)
qrgen.internal = {
	bitBuffer = bitBuffer,
	reedSolomon = reedSolomon,
	types = types,
}

--[=[
    Encode text into a QR code. Auto-selects optimal mode.

    @param text -- Text to encode
    @param ecc -- Error correction level
    @return QrCode
]=]
function qrgen.encodeText(text: string, ecc: ErrorCorrectionLevel): QrCode
	return qrCode.encodeText(text, ecc)
end

--[=[
    Encode binary data (bytes 0-255).

    @param data -- Byte array
    @param ecc -- Error correction level
    @return QrCode
]=]
function qrgen.encodeBinary(data: { number }, ecc: ErrorCorrectionLevel): QrCode
	return qrCode.encodeBinary(data, ecc)
end

--[=[
    Encode segments with full control.

    @param segs -- Segments to encode
    @param ecc -- Error correction level
    @param minVersion -- Min version 1-40 (default 1)
    @param maxVersion -- Max version 1-40 (default 40)
    @param mask -- Mask pattern -1 to 7 (-1 = auto)
    @param boostEcl -- Boost ECC if possible (default true)
    @return QrCode
]=]
function qrgen.encodeSegments(
	segs: { QrSegment },
	ecc: ErrorCorrectionLevel,
	minVersion: number?,
	maxVersion: number?,
	mask: number?,
	boostEcl: boolean?
): QrCode
	return qrCode.encodeSegments(segs, ecc, minVersion, maxVersion, mask, boostEcl)
end

--[=[
    Render QR code to Roblox Frame. Roblox only.

    @param qr -- QR code to render
    @param options -- Render options
    @return Frame
    @tag Roblox
]=]
function qrgen.renderToFrame(qr: QrCode, options: RenderOptions?): Frame
	return frameRenderer.render(qr, options)
end

--[=[
    Create Frame container with aspect ratio constraint. Roblox only.

    @param parent -- Parent GuiObject
    @param size -- Size (default 1x1 scale)
    @param position -- Position (default 0,0)
    @return Frame
    @tag Roblox
]=]
function qrgen.createContainer(parent: GuiObject, size: UDim2?, position: UDim2?): Frame
	return frameRenderer.createContainer(parent, size, position)
end

--[=[
    Render a QR code as an SVG string.

    ```lua
    local svg = qrgen.toSvg(qr, {
        border = 4,
        darkColor = "#000000",
        lightColor = "#FFFFFF",
    })
    ```

    @param qr -- QR code
    @param options -- SVG options
    @return string -- SVG markup
]=]
function qrgen.toSvg(qr: QrCode, options: SvgOptions?): string
	return svgRenderer.render(qr, options)
end

--[=[
    Render QR code as minimal path-based SVG.

    @param qr -- QR code
    @param border -- Border size (default 4)
    @return string -- SVG markup
]=]
function qrgen.toSvgMinimal(qr: QrCode, border: number?): string
	return svgRenderer.renderMinimal(qr, border)
end

--[=[
    Convert SVG to data URI.

    @param svg -- SVG string
    @return string -- Data URI
]=]
function qrgen.svgToDataUri(svg: string): string
	return svgRenderer.toDataUri(svg)
end

--[=[
    Convert QR code to ASCII string.

    @param qr -- QR code
    @param darkChar -- Dark char (default "██")
    @param lightChar -- Light char (default "  ")
    @return string
]=]
function qrgen.toString(qr: QrCode, darkChar: string?, lightChar: string?): string
	local dark = darkChar or "██"
	local light = lightChar or "  "
	local lines = table.create(qr.size)

	for y = 0, qr.size - 1 do
		local line = table.create(qr.size)
		for x = 0, qr.size - 1 do
			line[x + 1] = if qr:getModule(x, y) then dark else light
		end
		lines[y + 1] = table.concat(line)
	end

	return table.concat(lines, "\n")
end

--[=[
    Get matrix as 2D boolean table.

    @param qr -- QR code
    @return { { boolean } }
]=]
function qrgen.getMatrix(qr: QrCode): { { boolean } }
	return qr:getMatrix()
end

--[=[
    Get matrix as flat array of 0s and 1s.

    @param qr -- QR code
    @return { number }
]=]
function qrgen.getMatrixFlat(qr: QrCode): { number }
	local result = table.create(qr.size * qr.size)
	local index = 1
	for y = 0, qr.size - 1 do
		for x = 0, qr.size - 1 do
			result[index] = if qr:getModule(x, y) then 1 else 0
			index += 1
		end
	end
	return result
end

--[=[
    Get QR code as JSON-compatible table.

    @param qr -- QR code
    @return table
]=]
function qrgen.toTable(qr: QrCode): {
	version: number,
	size: number,
	mask: number,
	errorCorrectionLevel: string,
	matrix: { { number } },
}
	local matrix: { { number } } = table.create(qr.size)
	for y = 0, qr.size - 1 do
		local row: { number } = table.create(qr.size)
		for x = 0, qr.size - 1 do
			row[x + 1] = if qr:getModule(x, y) then 1 else 0
		end
		matrix[y + 1] = row
	end

	local eclNames = { [0] = "L", [1] = "M", [2] = "Q", [3] = "H" }

	return {
		version = qr.version,
		size = qr.size,
		mask = qr.mask,
		errorCorrectionLevel = eclNames[qr.errorCorrectionLevel.ordinal] or "?",
		matrix = matrix,
	}
end

return qrgen
