-- EggHeist | Client/Screens/UIFactory.luau
-- Theme + widget builders for a consistent premium UI.

local UserInputService = game:GetService("UserInputService")

local UIFactory = {}

UIFactory.Theme = {
	Background = Color3.fromRGB(18, 20, 32),
	Panel = Color3.fromRGB(28, 31, 48),
	Card = Color3.fromRGB(38, 42, 64),
	Accent = Color3.fromRGB(255, 200, 80),
	AccentDark = Color3.fromRGB(200, 140, 40),
	Success = Color3.fromRGB(80, 220, 120),
	Warning = Color3.fromRGB(255, 170, 60),
	Error = Color3.fromRGB(255, 90, 90),
	Text = Color3.fromRGB(245, 245, 250),
	TextDim = Color3.fromRGB(170, 175, 195),
	Button = Color3.fromRGB(58, 64, 100),
	ButtonHover = Color3.fromRGB(76, 84, 130),
	Stroke = Color3.fromRGB(70, 76, 110),
	Font = Enum.Font.GothamBold,
	FontRegular = Enum.Font.Gotham,
	Corner = 10,
}

local Theme = UIFactory.Theme

function UIFactory.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UIFactory.ScreenGui(name, displayOrder)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder or 10
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

function UIFactory.Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Corner)
	c.Parent = parent
	return c
end

function UIFactory.Stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIFactory.Padding(parent, pixels)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.Parent = parent
	return p
end

function UIFactory.Label(text, size, color, fontSize)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or Theme.Text
	label.Font = Theme.Font
	label.TextSize = fontSize or 16
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if size then
		label.Size = size
	else
		label.Size = UDim2.new(1, 0, 0, 24)
	end
	return label
end

function UIFactory.Button(text, onClick)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Button
	button.TextColor3 = Theme.Text
	button.Font = Theme.Font
	button.TextSize = 15
	button.Text = text or ""
	button.AutoButtonColor = true
	UIFactory.Corner(button, 8)
	UIFactory.Stroke(button, Theme.Stroke, 1)
	if onClick then
		button.MouseButton1Click:Connect(function()
			pcall(onClick)
		end)
	end
	return button
end

function UIFactory.PrimaryButton(text, onClick)
	local button = UIFactory.Button(text, onClick)
	button.BackgroundColor3 = Theme.Accent
	button.TextColor3 = Color3.fromRGB(30, 25, 10)
	return button
end

function UIFactory.CloseButton(onClick)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 32, 0, 32)
	button.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Theme.Font
	button.TextSize = 18
	button.Text = "X"
	UIFactory.Corner(button, 8)
	if onClick then
		button.MouseButton1Click:Connect(function()
			pcall(onClick)
		end)
	end
	return button
end

-- Standard draggable window with title bar. Returns { frame, content, SetVisible }
function UIFactory.Window(parent, title, size)
	size = size or UDim2.new(0, 480, 0, 420)
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.Size = size
	frame.Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
	frame.BackgroundColor3 = Theme.Panel
	frame.BorderSizePixel = 0
	frame.Visible = false
	UIFactory.Corner(frame, 12)
	UIFactory.Stroke(frame, Theme.Stroke, 2)
	frame.Parent = parent

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(620, 560)
	sizeConstraint.MinSize = Vector2.new(300, 280)
	sizeConstraint.Parent = frame

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 44)
	titleBar.BackgroundColor3 = Theme.Background
	titleBar.BorderSizePixel = 0
	titleBar.Parent = frame
	UIFactory.Corner(titleBar, 12)

	-- fix bottom corners of title bar (square them)
	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 12)
	titleFix.Position = UDim2.new(0, 0, 1, -12)
	titleFix.BackgroundColor3 = Theme.Background
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	local titleLabel = UIFactory.Label(title or "", UDim2.new(1, -60, 1, 0), Theme.Accent, 18)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 0, 0, 48)
	content.Size = UDim2.new(1, 0, 1, -56)
	content.BackgroundTransparency = 1
	content.Parent = frame
	UIFactory.Padding(content, 10)

	local window = { Frame = frame, Content = content, Title = titleLabel }

	local close = UIFactory.CloseButton(function()
		frame.Visible = false
	end)
	close.Position = UDim2.new(1, -38, 0, 6)
	close.Parent = titleBar

	-- dragging (mouse + touch)
	local dragging = false
	local dragStart = nil
	local startPos = nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	function window.SetVisible(visible)
		frame.Visible = visible
		if visible then
			frame:TweenPosition(
				UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2),
				Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
		end
	end

	function window.Toggle()
		window.SetVisible(not frame.Visible)
	end

	function window.IsVisible()
		return frame.Visible
	end

	return window
end

function UIFactory.ScrollingList(parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Stroke
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll
	return scroll, layout
end

function UIFactory.Grid(parent, cellSize, padding)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Stroke
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize or UDim2.new(0, 140, 0, 170)
	grid.CellPadding = UDim2.new(0, padding or 8, 0, padding or 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	return scroll, grid
end

function UIFactory.Card(height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height or 64)
	card.BackgroundColor3 = Theme.Card
	card.BorderSizePixel = 0
	UIFactory.Corner(card, 8)
	UIFactory.Padding(card, 8)
	return card
end

function UIFactory.ProgressBar(parent, height, fillColor)
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, height or 10)
	back.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	back.BorderSizePixel = 0
	UIFactory.Corner(back, 6)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = fillColor or Theme.Success
	fill.BorderSizePixel = 0
	UIFactory.Corner(fill, 6)
	fill.Parent = back
	return back, fill
end

function UIFactory.SetProgress(fill, fraction)
	fraction = math.max(0, math.min(1, fraction or 0))
	fill:TweenSize(UDim2.new(fraction, 0, 1, 0),
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true)
end

function UIFactory.Toggle(initial, onChanged)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 56, 0, 30)
	button.BackgroundColor3 = initial and Theme.Success or Color3.fromRGB(70, 74, 95)
	button.Text = initial and "ON" or "OFF"
	button.TextColor3 = Theme.Text
	button.Font = Theme.Font
	button.TextSize = 13
	UIFactory.Corner(button, 15)
	local state = initial == true
	button.MouseButton1Click:Connect(function()
		state = not state
		button.BackgroundColor3 = state and Theme.Success or Color3.fromRGB(70, 74, 95)
		button.Text = state and "ON" or "OFF"
		if onChanged then
			pcall(onChanged, state)
		end
	end)
	return button, function()
		return state
	end
end

function UIFactory.ClearChildren(instance, keepLayout)
	for _, child in ipairs(instance:GetChildren()) do
		if not keepLayout or (not child:IsA("UIListLayout") and not child:IsA("UIGridLayout")
			and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke")) then
			child:Destroy()
		end
	end
end

return UIFactory
