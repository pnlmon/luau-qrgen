--!strict
--[[
    example 3: svg rendering.
]]

local qrgen = require("../src")
local fs = require("@lune/fs")

local qr = qrgen.encodeText("https://github.com", qrgen.ecc.medium)

-- default svg
local svg = qrgen.toSvg(qr)
fs.writeFile("qrcode.svg", svg)
print("Saved: qrcode.svg")

-- custom colors
local custom = qrgen.toSvg(qr, {
	border = 2,
	darkColor = "#2E86AB",
	lightColor = "#FFFFFF",
})
fs.writeFile("qrcode_custom.svg", custom)
print("Saved: qrcode_custom.svg")
