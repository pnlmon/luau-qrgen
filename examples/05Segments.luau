--!strict
--[[
    example 5: manual segments.
]]

local qrgen = require("../src")

local segments = {
	qrgen.segment.makeNumeric("12345"),
	qrgen.segment.makeAlphanumeric(" ITEMS"),
}

local qr = qrgen.encodeSegments(segments, qrgen.ecc.medium)
print("Mixed segments -> Version", qr.version)
