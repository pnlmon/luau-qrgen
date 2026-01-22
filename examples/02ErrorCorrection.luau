--!strict
--[[
    example 2: error correction levels.
    l=7%, m=15%, q=25%, h=30% recovery
]]

local qrgen = require("../src")

local text = "Test Data"

print("Level   | Version | Size")
print("--------|---------|------")

local qrLow = qrgen.encodeText(text, qrgen.ecc.low)
print(string.format("LOW     | %7d | %dx%d", qrLow.version, qrLow.size, qrLow.size))

local qrMed = qrgen.encodeText(text, qrgen.ecc.medium)
print(string.format("MEDIUM  | %7d | %dx%d", qrMed.version, qrMed.size, qrMed.size))

local qrHigh = qrgen.encodeText(text, qrgen.ecc.high)
print(string.format("HIGH    | %7d | %dx%d", qrHigh.version, qrHigh.size, qrHigh.size))
