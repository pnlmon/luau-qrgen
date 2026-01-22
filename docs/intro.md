---
sidebar_position: 1
---

# Getting Started

QR code generation for Luau and Roblox.

## Install

```bash
pesde add luau_qrgen/qrgen
```

Or copy `src` folder into your project.

## Quick Start

```luau
local qrgen = require("@packages/qrgen")

local qr = qrgen.encodeText("Hello, World!", qrgen.ecc.medium)

print("Version:", qr.version)
print("Size:", qr.size)
print(qrgen.toString(qr))
```

## Error Correction

| Level | Recovery | Notes |
|-------|----------|-------|
| `ecc.low` | ~7% | Max capacity |
| `ecc.medium` | ~15% | General use |
| `ecc.quartile` | ~25% | Industrial |
| `ecc.high` | ~30% | Critical |

## Roblox Frame

```luau
local qr = qrgen.encodeText("https://roblox.com", qrgen.ecc.medium)

local container = qrgen.createContainer(screenGui, UDim2.fromOffset(200, 200))

qrgen.renderToFrame(qr, container, {
    darkColor = Color3.fromRGB(0, 0, 0),
    lightColor = Color3.fromRGB(255, 255, 255),
    border = 4,
})
```

## SVG

```luau
local qr = qrgen.encodeText("Hello", qrgen.ecc.medium)

local svg = qrgen.toSvg(qr, {
    border = 4,
    darkColor = "#000000",
    lightColor = "#FFFFFF",
    moduleSize = 10,
})

local dataUri = qrgen.svgToDataUri(svg)
```

## Binary

```luau
local bytes = {72, 101, 108, 108, 111}
local qr = qrgen.encodeBinary(bytes, qrgen.ecc.medium)
```

## Custom Segments

Mixed content for better efficiency:

```luau
local segs = {
    qrgen.segment.makeAlphanumeric("INVOICE-"),
    qrgen.segment.makeNumeric("123456789"),
}
local qr = qrgen.encodeSegments(segs, qrgen.ecc.medium)
```

## Encoding Modes

Auto-selected based on content:

| Mode | Characters | Bits/Char |
|------|------------|-----------|
| Numeric | 0-9 | 3.33 |
| Alphanumeric | 0-9, A-Z, space, $%*+-./:  | 5.5 |
| Byte | Any | 8 |
