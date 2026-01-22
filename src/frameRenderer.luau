--!strict
--[=[
    @class frameRenderer

    Roblox Frame-based rendering. Uses greedy row batching to minimize Frame count.

    :::caution Roblox Only
    Not available outside Roblox.
    :::

    ```lua
    local container = FrameRenderer.createContainer(screenGui, UDim2.fromOffset(200, 200))
    FrameRenderer.render(qr, container, { border = 4 })
    ```
    
    @tag Roblox
]=]

local qrCode = require(script.Parent.qrCode)

type QrCodeType = qrCode.QrCode

--[=[
    @interface RenderOptions
    @within frameRenderer
    .darkColor Color3?
    .lightColor Color3?
    .border number?
    .moduleSize number?
]=]
export type RenderOptions = {
	darkColor: Color3?,
	lightColor: Color3?,
	border: number?,
	moduleSize: number?,
}

local frameRenderer = {}

local defaultDarkColor = Color3.new(0, 0, 0)
local defaultLightColor = Color3.new(1, 1, 1)
local defaultBorder = 4

--[=[
    Render QR code with greedy row batching.

    @param qr QrCode
    @param options RenderOptions?
    @return Frame
]=]
function frameRenderer.render(qr: QrCodeType, options: RenderOptions?): Frame
	local opts = (options or {}) :: RenderOptions
	local darkColor = opts.darkColor or defaultDarkColor
	local lightColor = opts.lightColor or defaultLightColor
	local border = opts.border or defaultBorder

	local container = Instance.new("Frame")
	container.Name = "qrCodeRenderer"
	container.BackgroundColor3 = lightColor
	container.BorderSizePixel = 0

	local totalSize = qr.size + border * 2
	local moduleScale = 1 / totalSize

	for y = 0, qr.size - 1 do
		local x = 0
		while x < qr.size do
			if qr:getModule(x, y) then
				local startX = x
				while x < qr.size and qr:getModule(x, y) do
					x += 1
				end
				local width = x - startX

				local frame = Instance.new("Frame")
				frame.Name = string.format("module-%d-%d", startX, y)
				frame.BackgroundColor3 = darkColor
				frame.BorderSizePixel = 0
				frame.Position = UDim2.fromScale((border + startX) * moduleScale, (border + y) * moduleScale)
				frame.Size = UDim2.fromScale(width * moduleScale, moduleScale)
				frame.Parent = container
			else
				x += 1
			end
		end
	end

	return container
end

--[=[
    Render QR code with one Frame per module.

    @param qr QrCode
    @param options RenderOptions?
    @return Frame
]=]
function frameRenderer.renderSimple(qr: QrCodeType, options: RenderOptions?): Frame
	local opts = (options or {}) :: RenderOptions
	local darkColor = opts.darkColor or defaultDarkColor
	local lightColor = opts.lightColor or defaultLightColor
	local border = opts.border or defaultBorder

	local container = Instance.new("Frame")
	container.Name = "qrCodeRenderer"
	container.BackgroundColor3 = lightColor
	container.BorderSizePixel = 0
	local totalSize = qr.size + border * 2
	local moduleScale = 1 / totalSize

	container.BackgroundColor3 = lightColor

	for y = 0, qr.size - 1 do
		for x = 0, qr.size - 1 do
			if qr:getModule(x, y) then
				local frame = Instance.new("Frame")
				frame.Name = string.format("module-%d-%d", x, y)
				frame.BackgroundColor3 = darkColor
				frame.BorderSizePixel = 0
				frame.Position = UDim2.fromScale((border + x) * moduleScale, (border + y) * moduleScale)
				frame.Size = UDim2.fromScale(moduleScale, moduleScale)
				frame.Parent = container
			end
		end
	end

	return container
end

--[=[
    Create a 1:1 aspect ratio container Frame.

    @param parent GuiObject
    @param size UDim2?
    @param position UDim2?
    @return Frame
]=]
function frameRenderer.createContainer(parent: GuiObject, size: UDim2?, position: UDim2?): Frame
	local container = Instance.new("Frame")
	container.Name = "qrCodeContainer"
	container.Size = size or UDim2.fromScale(1, 1)
	container.Position = position or UDim2.fromScale(0, 0)
	container.BackgroundColor3 = Color3.new(1, 1, 1)
	container.BorderSizePixel = 0
	container.ClipsDescendants = true

	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1
	aspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	aspectRatio.DominantAxis = Enum.DominantAxis.Width
	aspectRatio.Parent = container

	container.Parent = parent
	return container
end

return frameRenderer
