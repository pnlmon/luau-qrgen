--!strict
--[[
    example 4: binary data.
]]

local qrgen = require("../src")

local bytes = { 0x48, 0x65, 0x6C, 0x6C, 0x6F }
local qr = qrgen.encodeBinary(bytes, qrgen.ecc.medium)

print("Encoded", #bytes, "bytes -> Version", qr.version)
