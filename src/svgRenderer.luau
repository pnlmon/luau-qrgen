--!strict
--[=[
    @class svgRenderer

    SVG output for QR codes.

    ```lua
    local svg = SvgRenderer.render(qr, { border = 4 })
    local uri = SvgRenderer.toDataUri(svg)
    ```
]=]

local qrCode = require("./qrCode")

--[=[
    @interface SvgOptions
    @within svgRenderer
    .border number?
    .lightColor string?
    .darkColor string?
    .moduleSize number?
]=]
export type SvgOptions = {
	border: number?,
	lightColor: string?,
	darkColor: string?,
	moduleSize: number?,
}

local svgRenderer = {}

local function generatePath(qr: qrCode.QrCode, border: number): string
	local size = qr.size
	local parts = table.create(math.floor(size * size / 4))
	local partCount = 0

	for y = 0, size - 1 do
		for x = 0, size - 1 do
			if qr:getModule(x, y) then
				partCount += 1
				local px = x + border
				local py = y + border
				parts[partCount] = string.format("M%d %dh1v1h-1z", px, py)
			end
		end
	end

	return table.concat(parts, "")
end

--[=[
    Render QR code as SVG.

    @param qr QrCode
    @param options SvgOptions?
    @return string
]=]
function svgRenderer.render(qr: qrCode.QrCode, options: SvgOptions?): string
	local border = 4
	local lightColor = "#FFFFFF"
	local darkColor = "#000000"
	local moduleSize = 1

	if options then
		border = options.border or border
		lightColor = options.lightColor or lightColor
		darkColor = options.darkColor or darkColor
		moduleSize = options.moduleSize or moduleSize
	end

	local fullSize = qr.size + border * 2
	local viewBox = string.format("0 0 %d %d", fullSize, fullSize)
	local pixelSize = fullSize * moduleSize

	local path = generatePath(qr, border)

	return string.format(
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s" width="%d" height="%d" shape-rendering="crispEdges">'
			.. '<rect width="100%%" height="100%%" fill="%s"/>'
			.. '<path d="%s" fill="%s"/>'
			.. "</svg>",
		viewBox,
		pixelSize,
		pixelSize,
		lightColor,
		path,
		darkColor
	)
end

--[=[
    Render QR code as minimal path-based SVG.

    @param qr QrCode
    @param border number?
    @return string
]=]
function svgRenderer.renderMinimal(qr: qrCode.QrCode, border: number?): string
	local b = border or 4
	local fullSize = qr.size + b * 2
	local viewBox = string.format("0 0 %d %d", fullSize, fullSize)
	local path = generatePath(qr, b)

	return string.format(
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s">' .. '<path d="%s"/>' .. "</svg>",
		viewBox,
		path
	)
end

--[=[
    Convert SVG to data URI.

    @param svg string
    @return string
]=]
function svgRenderer.toDataUri(svg: string): string
	local encoded = svg:gsub("%%", "%%25")
		:gsub("#", "%%23")
		:gsub("<", "%%3C")
		:gsub(">", "%%3E")
		:gsub('"', "'")
		:gsub("\n", "")
		:gsub(" +", " ")

	return "data:image/svg+xml," .. encoded
end

return svgRenderer
