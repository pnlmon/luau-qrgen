--!strict
--[[
    example 1: basic qr code.
]]

local qrgen = require("../src")

local qr = qrgen.encodeText("Hello, World!", qrgen.ecc.medium)

print("Version:", qr.version, "| Size:", qr.size .. "x" .. qr.size)
print()

for y = 0, qr.size - 1 do
	local line = ""
	for x = 0, qr.size - 1 do
		line ..= qr:getModule(x, y) and "██" or "  "
	end
	print(line)
end
