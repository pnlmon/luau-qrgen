--!strict
--[[
    qr code generator story for ui labs.
]]

local qrgen = require("../.")

local uiLabs = nil
pcall(function()
	uiLabs = require(script.Parent.Parent.Packages.ui_labs)
end)

type ControlValues = {
	Text: string,
	ErrorCorrection: string,
	ModuleSize: number,
	Border: number,
	DarkColor: Color3,
	LightColor: Color3,
}

local controls: { [string]: any }

if uiLabs then
	controls = {
		Text = "Hello, World!",
		ErrorCorrection = uiLabs.EnumList({
			LOW = "LOW",
			MEDIUM = "MEDIUM",
			QUARTILE = "QUARTILE",
			HIGH = "HIGH",
		}, "MEDIUM"),
		ModuleSize = uiLabs.Slider(4, 1, 10, 1),
		Border = uiLabs.Slider(4, 0, 8, 1),
		DarkColor = Color3.fromRGB(0, 0, 0),
		LightColor = Color3.fromRGB(255, 255, 255),
	}
else
	controls = {
		Text = "Hello, World!",
		ErrorCorrection = "MEDIUM",
		ModuleSize = 4,
		Border = 4,
		DarkColor = Color3.fromRGB(0, 0, 0),
		LightColor = Color3.fromRGB(255, 255, 255),
	}
end

local story = {
	name = "QR Code Generator",
	summary = "Generate QR codes with customizable text, error correction, and styling options.",
	controls = controls,
	render = function(props: {
		target: Frame,
		controls: ControlValues,
		subscribe: (listener: (values: ControlValues, infos: any) -> ()) -> () -> (),
	})
		local container = Instance.new("Frame")
		container.Name = "qrCodeContainer"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.Parent = props.target

		local qrWrapper = Instance.new("Frame")
		qrWrapper.Name = "qrWrapper"
		qrWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
		qrWrapper.Position = UDim2.fromScale(0.5, 0.5)
		qrWrapper.Size = UDim2.fromOffset(300, 300)
		qrWrapper.BackgroundTransparency = 1
		qrWrapper.LayoutOrder = 1
		qrWrapper.Parent = container

		local infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "infoLabel"
		infoLabel.Size = UDim2.new(1, 0, 0, 50)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLabel.TextSize = 14
		infoLabel.Font = Enum.Font.Code
		infoLabel.Text = ""
		infoLabel.LayoutOrder = 2
		infoLabel.Parent = container

		local centerLayout = Instance.new("UIListLayout")
		centerLayout.FillDirection = Enum.FillDirection.Vertical
		centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		centerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		centerLayout.Parent = container

		local function getEcc(eccName: string)
			local eccMap = {
				LOW = qrgen.ecc.low,
				MEDIUM = qrgen.ecc.medium,
				QUARTILE = qrgen.ecc.quartile,
				HIGH = qrgen.ecc.high,
			}
			return eccMap[eccName] or qrgen.ecc.medium
		end

		local function renderQR(values: ControlValues)
			for _, child in qrWrapper:GetChildren() do
				if child:IsA("Frame") and child.Name ~= "UIListLayout" then
					child:Destroy()
				end
			end

			if values.Text == "" then
				infoLabel.Text = "Enter text to generate QR code"
				infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				return
			end

			local success, result = pcall(function()
				return qrgen.encodeText(values.Text, getEcc(values.ErrorCorrection))
			end)

			if not success then
				infoLabel.Text = "Error: " .. tostring(result)
				infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				return
			end

			local qr = result
			local border = values.Border
			local totalSize = (qr.size + border * 2)

			qrWrapper.Size = UDim2.fromOffset(math.min(totalSize * 10, 400), math.min(totalSize * 10, 400))

			infoLabel.Text = string.format(
				"Version %d | %dx%d modules | ECC: %s (~%d%% recovery)",
				qr.version,
				qr.size,
				qr.size,
				values.ErrorCorrection,
				({ LOW = 7, MEDIUM = 15, QUARTILE = 25, HIGH = 30 })[values.ErrorCorrection] or 15
			)
			infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

			local qrFrame = qrgen.renderToFrame(qr, {
				darkColor = values.DarkColor,
				lightColor = values.LightColor,
				border = border,
			})
			qrFrame.Size = UDim2.fromScale(1, 1)
			qrFrame.Parent = qrWrapper
		end

		renderQR(props.controls)

		local unsubscribe = props.subscribe(function(values, _infos)
			renderQR(values)
		end)

		return function()
			unsubscribe()
			container:Destroy()
		end
	end,
}

return story
