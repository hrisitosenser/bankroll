--!nocheck
-- Bankroll UI Library
-- A dependency-free Luau port of the bankroll ImGui menu for Roblox Studio.
-- The module intentionally contains UI only: it does not run gameplay code or
-- make requests to third-party services.

local Bankroll = {}
Bankroll.__index = Bankroll

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0.0"
local MENU_W, MENU_H, TITLE_H, TAB_H = 448, 420, 22, 26
local PADDING, LEFT_W, GAP = 10, 200, 14
local RIGHT_X, RIGHT_W = PADDING + LEFT_W + GAP, MENU_W - (PADDING + LEFT_W + GAP) - PADDING

local Colors = {
    Bg = Color3.fromRGB(9, 9, 9),
    TitleBg = Color3.fromRGB(7, 7, 7),
    Text = Color3.fromRGB(168, 165, 178),
    TextBright = Color3.fromRGB(205, 202, 215),
    TextDim = Color3.fromRGB(82, 79, 95),
    TextBind = Color3.fromRGB(64, 61, 75),
    Section = Color3.fromRGB(78, 74, 90),
    Accent = Color3.fromRGB(188, 130, 187),
    AccentHover = Color3.fromRGB(205, 148, 204),
    AccentDark = Color3.fromRGB(60, 38, 60),
    CbBg = Color3.fromRGB(18, 16, 20),
    CbBorder = Color3.fromRGB(52, 49, 60),
    SliderTrack = Color3.fromRGB(26, 24, 30),
    DropdownBg = Color3.fromRGB(16, 14, 18),
    DropdownBorder = Color3.fromRGB(50, 47, 58),
    SectionBorder = Color3.fromRGB(22, 22, 22),
    TabBg = Color3.fromRGB(13, 13, 13),
}

Bankroll.Colors = Colors
Bankroll.Version = VERSION

local function newSignal()
    local signal = { _handlers = {} }

    function signal:Connect(callback)
        assert(type(callback) == "function", "Signal callback must be a function")
        local record = { Callback = callback, Connected = true }
        table.insert(self._handlers, record)
        return {
            Connected = true,
            Disconnect = function(connection)
                if not connection.Connected then
                    return
                end
                connection.Connected = false
                record.Connected = false
            end,
        }
    end

    function signal:Fire(...)
        local args = table.pack(...)
        for _, record in ipairs(self._handlers) do
            if record.Connected then
                task.spawn(function()
                    record.Callback(table.unpack(args, 1, args.n))
                end)
            end
        end
    end

    return signal
end

local function tween(instance, duration, properties, style, direction)
    local info = TweenInfo.new(
        duration or 0.14,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

local function setProps(instance, properties)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function make(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 2) }, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function gradient(parent, top, bottom, rotation)
    return make("UIGradient", {
        Color = ColorSequence.new(top, bottom),
        Rotation = rotation or 90,
    }, parent)
end

local function centeredText(instance, text, size, color)
    setProps(instance, {
        Text = text or "",
        Font = Enum.Font.Arial,
        TextSize = size or 11,
        TextColor3 = color or Colors.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    return instance
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function formatValue(value, format)
    if format then
        local ok, result = pcall(string.format, format, value)
        if ok then
            return result
        end
    end
    if math.abs(value - math.floor(value)) < 0.00001 then
        return tostring(math.floor(value))
    end
    return string.format("%.1f", value)
end

local function normalizeColor(value, fallback)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "table" and value.R and value.G and value.B then
        return Color3.new(value.R, value.G, value.B)
    end
    return fallback or Color3.new(1, 1, 1)
end

local function safeName(value)
    local result = tostring(value or "widget"):lower():gsub("[^%w]+", "_")
    return result:gsub("^_+", ""):gsub("_+$", "")
end

local function inputName(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then return "M1" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "M2" end
    if input.UserInputType == Enum.UserInputType.MouseButton3 then return "M3" end
    if input.UserInputType == Enum.UserInputType.MouseButton4 then return "M4" end
    if input.UserInputType == Enum.UserInputType.MouseButton5 then return "M5" end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return nil end

    local name = input.KeyCode.Name
    local aliases = {
        LeftAlt = "ALT", RightAlt = "ALT",
        LeftControl = "CTRL", RightControl = "CTRL",
        LeftShift = "SHIFT", RightShift = "SHIFT",
        LeftSuper = "WIN", RightSuper = "WIN",
    }
    return aliases[name] or string.upper(name)
end

local function inputMatches(input, binding)
    if not binding or binding == "" then
        return false
    end
    return inputName(input) == string.upper(tostring(binding))
end

local function addGradientLine(parent, position)
    local line = make("Frame", {
        Position = position,
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Colors.Accent,
        BackgroundTransparency = 0,
        ZIndex = 5,
    }, parent)
    local g = make("UIGradient", {
        Color = ColorSequence.new(Colors.Accent),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, line)
    return line, g
end

local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local ConfigPanel = {}
ConfigPanel.__index = ConfigPanel

local function resolveParent(options)
    if options and options.Parent then
        return options.Parent
    end
    local player = Players.LocalPlayer
    assert(player, "Bankroll must be created from a LocalScript")
    return player:WaitForChild("PlayerGui")
end

function Library.new(options)
    options = options or {}
    local self = setmetatable({}, Library)
    self.Options = options
    self.Windows = {}
    self._destroyed = false
    return self
end

function Library:_createWindow(options)
    options = options or {}
    local window = setmetatable({}, Window)
    window.Library = self
    window.Options = options
    window.Title = options.Title or "bankroll mafia"
    window.Accent = normalizeColor(options.Accent, Colors.Accent)
    window.ToggleKey = options.ToggleKey or Enum.KeyCode.Insert
    window._connections = {}
    window._tabs = {}
    window._widgets = {}
    window._registry = {}
    window._flagCounter = 0
    window._activeBind = nil
    window._activeSlider = nil
    window._activePopup = nil
    window._visible = true
    window.OnChanged = newSignal()
    window.OnVisibilityChanged = newSignal()

    local parent = resolveParent(options)
    window.ScreenGui = make("ScreenGui", {
        Name = options.Name or "BankrollUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)

    window.Gui = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.Position or UDim2.fromScale(0.5, 0.5),
        Size = options.Size or UDim2.fromOffset(MENU_W, MENU_H + TAB_H),
        BackgroundColor3 = Colors.Bg,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = false,
        ZIndex = 1,
    }, window.ScreenGui)
    corner(window.Gui, 4)

    window.Header = make("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, TITLE_H),
        BackgroundColor3 = Colors.TitleBg,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 2,
    }, window.Gui)
    corner(window.Header, 4)
    gradient(window.Header, Color3.fromRGB(20, 20, 20), Color3.fromRGB(7, 7, 7), 90)
    addGradientLine(window.Gui, UDim2.new(0, 0, 0, TITLE_H))

    window.TitleLabel = centeredText(make("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.new(1, -8, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    }, window.Header), window.Title, 11, Color3.fromRGB(185, 182, 196))

    window.Content = make("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(0, TITLE_H),
        Size = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, window.Gui)

    window.PopupLayer = make("Frame", {
        Name = "PopupLayer",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 100,
    }, window.ScreenGui)

    window.TabBar = make("Frame", {
        Name = "Tabs",
        Position = UDim2.new(0, 0, 1, -TAB_H),
        Size = UDim2.new(1, 0, 0, TAB_H),
        BackgroundColor3 = Colors.TabBg,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, window.Gui)
    addGradientLine(window.TabBar, UDim2.fromOffset(0, 0))

    window._connections[#window._connections + 1] = window.Header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        window._dragging = true
        window._dragStart = input.Position
        window._startPosition = window.Gui.Position
    end)
    window._connections[#window._connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if window._dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - window._dragStart
            window.Gui.Position = UDim2.new(
                window._startPosition.X.Scale,
                window._startPosition.X.Offset + delta.X,
                window._startPosition.Y.Scale,
                window._startPosition.Y.Offset + delta.Y
            )
        end
        if window._activeSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            window:_setSliderFromX(window._activeSlider, input.Position.X)
        end
    end)
    window._connections[#window._connections + 1] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            window._dragging = false
            window._activeSlider = nil
            window._activeColorPart = nil
        end
    end)
    window._connections[#window._connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
        window:_handleInput(input, processed)
    end)

    if options.ToggleKey ~= false then
        window._connections[#window._connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and window:_isToggleInput(input) then
                window:Toggle()
            end
        end)
    end

    self.Windows[#self.Windows + 1] = window
    window.Configs = window:_newConfigStore(options.Persistence)
    if options.StartHidden then
        window:SetVisible(false, true)
    end
    return window
end

function Library:CreateWindow(options)
    return self:_createWindow(options)
end

function Bankroll.new(options)
    return Library.new(options)
end

function Bankroll:CreateWindow(options)
    self._defaultLibrary = self._defaultLibrary or Library.new()
    return self._defaultLibrary:CreateWindow(options)
end

function Window:_nextFlag(label, explicit)
    if explicit and explicit ~= "" then
        return explicit
    end
    self._flagCounter += 1
    return safeName(label) .. "_" .. tostring(self._flagCounter)
end

function Window:_register(widget, flag)
    local key = self:_nextFlag(widget.Label or widget.Name, flag)
    widget.Flag = key
    self._registry[key] = widget
    self._widgets[#self._widgets + 1] = widget
    return key
end

function Window:_themeColor(multiplier)
    local c = self.Accent
    return Color3.new(clamp(c.R * multiplier, 0, 1), clamp(c.G * multiplier, 0, 1), clamp(c.B * multiplier, 0, 1))
end

function Window:SetAccent(color)
    self.Accent = normalizeColor(color, self.Accent)
    for _, callback in ipairs(self._themeCallbacks or {}) do
        callback(self.Accent)
    end
    self.OnChanged:Fire("accent", self.Accent)
end

function Window:SetTitle(title)
    self.Title = tostring(title or "")
    self.TitleLabel.Text = self.Title
end

function Window:SetToggleKey(key)
    self.ToggleKey = key
end

function Window:_onTheme(callback)
    self._themeCallbacks = self._themeCallbacks or {}
    table.insert(self._themeCallbacks, callback)
    callback(self.Accent)
end

function Window:_isToggleInput(input)
    if typeof(self.ToggleKey) == "EnumItem" then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.ToggleKey
    end
    return inputMatches(input, self.ToggleKey)
end

function Window:_handleInput(input, processed)
    if self._activeBind then
        if input.UserInputType == Enum.UserInputType.MouseButton1 and self._activeBind._captureMouse then
            self._activeBind:SetKey("M1")
            self._activeBind = nil
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
            self._activeBind:SetWaiting(false)
            self._activeBind = nil
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:match("MouseButton") then
            local name = inputName(input)
            if name then
                self._activeBind:SetKey(name)
                self._activeBind = nil
                return
            end
        end
    end

    if self._activePopup and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local popup = self._activePopup.Popup
        local origin = self._activePopup.Origin
        local point = input.Position
        local function inside(guiObject)
            local p, s = guiObject.AbsolutePosition, guiObject.AbsoluteSize
            return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
        end
        if not inside(popup) and (not origin or not inside(origin)) then
            self:_closePopup()
        end
    end

    if not processed and not self._activeBind and input.UserInputType == Enum.UserInputType.Keyboard then
        local pressed = inputName(input)
        if pressed then
            for _, widget in ipairs(self._widgets) do
                if widget._bind and widget._toggle and widget._bind.Key == pressed then
                    widget._toggle:SetValue(not widget._toggle.Value)
                end
            end
        end
    end
end

function Window:_closePopup()
    if not self._activePopup then
        return
    end
    local popup = self._activePopup.Popup
    self._activePopup = nil
    tween(popup, 0.1, { Size = UDim2.fromOffset(popup.AbsoluteSize.X, 0) })
    task.delay(0.11, function()
        if popup and popup.Parent then
            popup:Destroy()
        end
    end)
end

function Window:_setSliderFromX(slider, x)
    if not slider or not slider._track then
        return
    end
    local p = slider._track.AbsolutePosition.X
    local width = slider._track.AbsoluteSize.X
    local alpha = clamp((x - p) / math.max(width, 1), 0, 1)
    slider:SetValue(slider.Min + alpha * (slider.Max - slider.Min))
end

function Window:_openDropdown(dropdown)
    self:_closePopup()
    local origin = dropdown._button
    local p = origin.AbsolutePosition
    local width = origin.AbsoluteSize.X
    local itemHeight = 16
    local height = #dropdown.Values * itemHeight + 4
    local popup = make("Frame", {
        Name = "DropdownPopup",
        Position = UDim2.fromOffset(p.X, p.Y + origin.AbsoluteSize.Y),
        Size = UDim2.fromOffset(width, 0),
        BackgroundColor3 = Colors.Bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 110,
    }, self.PopupLayer)
    corner(popup, 3)
    stroke(popup, Colors.SectionBorder, 1)
    local scale = make("UIScale", { Scale = 0.97 }, popup)
    local list = make("Frame", {
        Position = UDim2.fromOffset(1, 2),
        Size = UDim2.new(1, -2, 1, -4),
        BackgroundTransparency = 1,
        ZIndex = 111,
    }, popup)
    local layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, list)

    for index, value in ipairs(dropdown.Values) do
        local item = make("TextButton", {
            Name = "Item_" .. tostring(index),
            Size = UDim2.new(1, 0, 0, itemHeight),
            BackgroundColor3 = Colors.Bg,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = tostring(value),
            Font = Enum.Font.Arial,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = index == dropdown.Index and self.Accent or Colors.Text,
            ZIndex = 112,
            LayoutOrder = index,
        }, list)
        make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, item)
        item.MouseEnter:Connect(function()
            tween(item, 0.08, { BackgroundColor3 = Color3.fromRGB(35, 32, 44), TextColor3 = Colors.TextBright })
        end)
        item.MouseLeave:Connect(function()
            tween(item, 0.08, { BackgroundColor3 = Colors.Bg, TextColor3 = index == dropdown.Index and self.Accent or Colors.Text })
        end)
        item.Activated:Connect(function()
            dropdown:SetValue(index)
            self:_closePopup()
        end)
    end

    self._activePopup = { Popup = popup, Origin = origin, Type = "Dropdown" }
    tween(popup, 0.12, { Size = UDim2.fromOffset(width, height) })
    tween(scale, 0.12, { Scale = 1 })
end

function Window:_openColorPicker(picker)
    self:_closePopup()
    local origin = picker._swatch
    local p = origin.AbsolutePosition
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local x = clamp(p.X + 9, 2, math.max(2, viewport.X - 222))
    local y = clamp(p.Y + 6, 2, math.max(2, viewport.Y - 222))
    local size = 220
    local popup = make("Frame", {
        Name = "ColorPickerPopup",
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(size, 0),
        BackgroundColor3 = Colors.Bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 110,
    }, self.PopupLayer)
    corner(popup, 4)
    stroke(popup, Color3.fromRGB(22, 22, 22), 1.5)
    local scale = make("UIScale", { Scale = 0.96 }, popup)
    local inner = make("Frame", {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(200, 200),
        BackgroundTransparency = 1,
        ZIndex = 111,
    }, popup)

    local hue, saturation, value = picker.Value:ToHSV()
    picker._pickerHue, picker._pickerSaturation, picker._pickerValue = hue, saturation, value
    picker._pickerAlpha = picker.Alpha

    local sv = make("Frame", {
        Size = UDim2.fromOffset(180, 180),
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 112,
    }, inner)
    local svWhite = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 113,
    }, sv)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
    }, svWhite)
    local svBlack = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 114,
    }, sv)
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(0, 0, 0)),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
    }, svBlack)
    local svButton = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 115,
    }, sv)
    local svCursor = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 116,
    }, sv)
    corner(svCursor, 8)
    stroke(svCursor, Color3.new(0, 0, 0), 1.5)

    local hueBar = make("Frame", {
        Position = UDim2.fromOffset(188, 0),
        Size = UDim2.fromOffset(14, 180),
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 112,
    }, inner)
    local hueGradient = make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
    }, hueBar)
    local hueButton = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 115,
    }, hueBar)
    local hueCursor = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1, 4, 0, 4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 116,
    }, hueBar)
    stroke(hueCursor, Color3.new(0, 0, 0), 1.5)

    local alphaBar = make("Frame", {
        Position = UDim2.fromOffset(0, 188),
        Size = UDim2.fromOffset(180, 14),
        BackgroundColor3 = picker.Value,
        BorderSizePixel = 0,
        ZIndex = 112,
    }, inner)
    local alphaGradient = make("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
    }, alphaBar)
    local alphaButton = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 115,
    }, alphaBar)
    local alphaCursor = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 4, 1, 4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 116,
    }, alphaBar)
    stroke(alphaCursor, Color3.new(0, 0, 0), 1.5)

    local function apply()
        local c = Color3.fromHSV(picker._pickerHue, picker._pickerSaturation, picker._pickerValue)
        picker:SetColor(c, picker._pickerAlpha)
        sv.BackgroundColor3 = Color3.fromHSV(picker._pickerHue, 1, 1)
        alphaBar.BackgroundColor3 = c
        svCursor.Position = UDim2.fromScale(picker._pickerSaturation, 1 - picker._pickerValue)
        hueCursor.Position = UDim2.new(0.5, 0, picker._pickerHue, 0)
        alphaCursor.Position = UDim2.new(picker._pickerAlpha, 0, 0.5, 0)
    end

    local function updateFrom(input, part)
        local point = input.Position
        if part == "SV" then
            local ap = sv.AbsolutePosition
            picker._pickerSaturation = clamp((point.X - ap.X) / sv.AbsoluteSize.X, 0, 1)
            picker._pickerValue = 1 - clamp((point.Y - ap.Y) / sv.AbsoluteSize.Y, 0, 1)
        elseif part == "Hue" then
            local ap = hueBar.AbsolutePosition
            picker._pickerHue = clamp((point.Y - ap.Y) / hueBar.AbsoluteSize.Y, 0, 1)
        else
            local ap = alphaBar.AbsolutePosition
            picker._pickerAlpha = clamp((point.X - ap.X) / alphaBar.AbsoluteSize.X, 0, 1)
        end
        apply()
    end

    local function begin(button, part)
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self._activeColorPart = { Picker = picker, Part = part, Update = updateFrom }
                updateFrom(input, part)
            end
        end)
    end
    begin(svButton, "SV")
    begin(hueButton, "Hue")
    begin(alphaButton, "Alpha")
    self._connections[#self._connections + 1] = UserInputService.InputChanged:Connect(function(input)
        local active = self._activeColorPart
        if active and active.Picker == picker and input.UserInputType == Enum.UserInputType.MouseMovement then
            active.Update(input, active.Part)
        end
    end)

    self._activePopup = { Popup = popup, Origin = origin, Type = "ColorPicker" }
    apply()
    tween(popup, 0.12, { Size = UDim2.fromOffset(size, size) })
    tween(scale, 0.12, { Scale = 1 })
end

function Window:_newConfigStore(adapter)
    local store = { Window = self, Adapter = adapter, _memory = {}, _selected = nil }
    store.Changed = newSignal()

    function store:List()
        local names, seen = {}, {}
        if self.Adapter and self.Adapter.List then
            local ok, result = pcall(self.Adapter.List)
            if ok and type(result) == "table" then
                for _, name in ipairs(result) do
                    name = tostring(name)
                    if not seen[name] then
                        seen[name] = true
                        names[#names + 1] = name
                    end
                end
            end
        end
        for name in pairs(self._memory) do
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
        table.sort(names)
        return names
    end

    function store:Create(name)
        name = tostring(name or ""):gsub("[%c]", ""):sub(1, 48)
        if name == "" then return false end
        if not self._memory[name] then
            self._memory[name] = {}
        end
        self._selected = name
        self.Changed:Fire("create", name)
        return true
    end

    function store:Save(name)
        name = name or self._selected
        if not name or name == "" then return false end
        local data = self.Window:_exportConfig()
        if self.Adapter and self.Adapter.Save then
            local ok = pcall(self.Adapter.Save, name, data)
            if not ok then return false end
        else
            self._memory[name] = data
        end
        self._selected = name
        self.Changed:Fire("save", name)
        return true
    end

    function store:Load(name)
        name = name or self._selected
        if not name or name == "" then return false end
        local data
        if self.Adapter and self.Adapter.Load then
            local ok, result = pcall(self.Adapter.Load, name)
            if not ok then return false end
            data = result
        else
            data = self._memory[name]
        end
        if type(data) ~= "table" then return false end
        self.Window:_importConfig(data)
        self._selected = name
        self.Changed:Fire("load", name)
        return true
    end

    function store:OpenDirectory()
        if self.Adapter and self.Adapter.OpenDirectory then
            local ok = pcall(self.Adapter.OpenDirectory)
            return ok
        end
        if self.Window.Options.OnOpenDirectory then
            local ok = pcall(self.Window.Options.OnOpenDirectory)
            return ok
        end
        return false
    end

    return store
end

function Window:_exportConfig()
    local result = {}
    for flag, widget in pairs(self._registry) do
        if widget.Export then
            result[flag] = widget:Export()
        end
    end
    return result
end

function Window:_importConfig(data)
    for flag, value in pairs(data or {}) do
        local widget = self._registry[flag]
        if widget and widget.Import then
            widget:Import(value)
        end
    end
end

function Window:Notify(options)
    options = type(options) == "table" and options or { Content = tostring(options) }
    local note = make("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(options.Width or 220, 44),
        BackgroundColor3 = Colors.Bg,
        BorderSizePixel = 0,
        ZIndex = 200,
    }, self.ScreenGui)
    corner(note, 3)
    stroke(note, self.Accent, 1)
    centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(8, 4),
        Size = UDim2.new(1, -16, 0, 16),
        ZIndex = 201,
    }, note), options.Title or self.Title, 11, self.Accent)
    centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(8, 20),
        Size = UDim2.new(1, -16, 0, 18),
        TextWrapped = true,
        ZIndex = 201,
    }, note), options.Content or "", 10, Colors.Text)
    task.delay(options.Duration or 3, function()
        if note.Parent then
            tween(note, 0.15, { BackgroundTransparency = 1, Position = UDim2.new(1, 10, 0, 16) })
            task.delay(0.16, function()
                if note.Parent then note:Destroy() end
            end)
        end
    end)
    return note
end

function Window:SetVisible(value, immediate)
    value = not not value
    self._visible = value
    if not value then
        self:_closePopup()
    end
    self.Gui.Visible = value
    self.PopupLayer.Visible = value
    if value and not immediate then
        self.Gui.Position = self.Options.Position or UDim2.fromScale(0.5, 0.5)
    end
    self.OnVisibilityChanged:Fire(value)
end

function Window:IsVisible()
    return self._visible
end

function Window:Toggle()
    self:SetVisible(not self._visible)
end

function Window:GetTab(name)
    for _, tab in ipairs(self._tabs) do
        if tab.Name == name then return tab end
    end
end

function Window:CreateTab(options)
    options = type(options) == "string" and { Name = options } or (options or {})
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = options.Name or ("tab_" .. tostring(#self._tabs + 1))
    tab._subtabs = {}
    tab._activeSubtab = nil
    tab._pages = {}
    tab._buttons = {}
    tab.Page = make("Frame", {
        Name = safeName(tab.Name),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = #self._tabs == 0,
        ZIndex = 3,
    }, self.Content)
    self._tabs[#self._tabs + 1] = tab

    local index = #self._tabs
    local button = make("TextButton", {
        Name = "TabButton_" .. tostring(index),
        Position = UDim2.new((index - 1) / math.max(index, 1), 0, 0, 0),
        Size = UDim2.new(1 / math.max(index, 1), 0, 1, 0),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = tab.Name,
        Font = Enum.Font.Arial,
        TextSize = 11,
        TextColor3 = index == 1 and Colors.TextBright or Colors.TextDim,
        ZIndex = 25,
    }, self.TabBar)
    tab._button = button
    self._themeCallbacks = self._themeCallbacks or {}
    table.insert(self._themeCallbacks, function(accent)
        button.TextColor3 = tab.Page.Visible and Colors.TextBright or Colors.TextDim
    end)
    button.MouseEnter:Connect(function()
        if not tab.Page.Visible then tween(button, 0.12, { TextColor3 = Colors.Text }) end
    end)
    button.MouseLeave:Connect(function()
        if not tab.Page.Visible then tween(button, 0.12, { TextColor3 = Colors.TextDim }) end
    end)
    button.Activated:Connect(function()
        self:SelectTab(tab)
    end)
    self:_onTheme(function()
        button.TextColor3 = tab.Page.Visible and Colors.TextBright or Colors.TextDim
    end)
    local tabCount = #self._tabs
    for i, item in ipairs(self._tabs) do
        item._button.Position = UDim2.new((i - 1) / tabCount, 0, 0, 0)
        item._button.Size = UDim2.new(1 / tabCount, 0, 1, 0)
    end
    return tab
end

Window.AddTab = Window.CreateTab

function Window:SelectTab(tabOrName)
    local selected = tabOrName
    if type(tabOrName) == "string" then
        selected = self:GetTab(tabOrName)
    end
    if not selected then return end
    for _, tab in ipairs(self._tabs) do
        local active = tab == selected
        tab.Page.Visible = active
        tab._button.TextColor3 = active and Colors.TextBright or Colors.TextDim
    end
    self._selectedTab = selected
end

function Tab:_makePage(parent, top)
    local page = make("Frame", {
        Position = UDim2.fromOffset(0, top or 10),
        Size = UDim2.new(1, 0, 1, -(top or 10)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 4,
    }, parent)
    local left = make("Frame", {
        Position = UDim2.fromOffset(PADDING, 0),
        Size = UDim2.fromOffset(LEFT_W, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, page)
    local right = make("Frame", {
        Position = UDim2.fromOffset(RIGHT_X, 0),
        Size = UDim2.fromOffset(RIGHT_W, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, page)
    for _, column in ipairs({ left, right }) do
        make("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }, column)
    end
    local record = { Page = page, Left = left, Right = right }
    self._pages[#self._pages + 1] = record
    return record
end

function Tab:_currentPage()
    if self._activeSubtab then
        return self._activeSubtab._record
    end
    if not self._defaultRecord and self._subtabs and #self._subtabs == 0 then
        self._defaultRecord = self:_makePage(self.Page, 10)
    end
    return self._defaultRecord
end

function Tab:CreateGroupbox(options)
    options = type(options) == "string" and { Name = options } or (options or {})
    local record = self:_currentPage()
    assert(record, "CreateGroupbox must be called after a tab has been created")
    local parent = (options.Side or "Left"):lower() == "right" and record.Right or record.Left
    local section = Section.new(self.Window, parent, options.Name or "section", options)
    return section
end

Tab.AddGroupbox = Tab.CreateGroupbox

function Tab:AddSubTab(name)
    local subtab = setmetatable({}, Tab)
    subtab.ParentTab = self
    subtab.Window = self.Window
    subtab.Name = type(name) == "table" and name.Name or tostring(name)
    subtab._pages = {}
    subtab._subtabs = nil
    subtab.Page = self.Page
    subtab._record = nil
    if #self._subtabs == 0 then
        self._defaultRecord = nil
        self._subtabsBar = make("Frame", {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 29),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 8,
        }, self.Page)
    end
    subtab._record = self:_makePage(self.Page, 29)
    subtab._defaultRecord = subtab._record
    subtab._record.Page.Visible = #self._subtabs == 0
    local index = #self._subtabs + 1
    local x = 10
    for _, item in ipairs(self._subtabs) do
        x += item._button.Size.X.Offset + 20
    end
    local button = make("TextButton", {
        Position = UDim2.fromOffset(x, 4),
        Size = UDim2.fromOffset(math.max(20, #subtab.Name * 7 + 2), 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = subtab.Name,
        Font = Enum.Font.Arial,
        TextSize = 11,
        TextColor3 = index == 1 and self.Window.Accent or Colors.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9,
    }, self._subtabsBar)
    subtab._button = button
    button.MouseEnter:Connect(function()
        if not subtab._record.Page.Visible then tween(button, 0.12, { TextColor3 = Colors.Text }) end
    end)
    button.MouseLeave:Connect(function()
        if not subtab._record.Page.Visible then tween(button, 0.12, { TextColor3 = Colors.TextDim }) end
    end)
    button.Activated:Connect(function()
        self:SelectSubTab(subtab)
    end)
    self._subtabs[#self._subtabs + 1] = subtab
    if index == 1 then self._activeSubtab = subtab end
    return subtab
end

Tab.CreateSubTab = Tab.AddSubTab

function Tab:SelectSubTab(subtab)
    for _, item in ipairs(self._subtabs or {}) do
        local active = item == subtab
        item._record.Page.Visible = active
        item._button.TextColor3 = active and self.Window.Accent or Colors.TextDim
    end
    self._activeSubtab = subtab
end

function Tab:CreateConfigPanel(options)
    options = options or {}
    local record = self:_currentPage()
    local parent = (options.Side or "Right"):lower() == "left" and record.Left or record.Right
    return ConfigPanel.new(self.Window, parent, options.Name or "configs", options)
end

function Section.new(window, parent, name, options)
    local self = setmetatable({}, Section)
    self.Window = window
    self.Name = name
    self.Options = options or {}
    self._widgets = {}
    self._rowCounter = 0
    self.Frame = make("Frame", {
        Name = safeName(name),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = self.Options.LayoutOrder or 0,
        ZIndex = 6,
    }, parent)
    self.Border = make("Frame", {
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, self.Frame)
    corner(self.Border, 2)
    stroke(self.Border, Colors.SectionBorder, 1)
    self.TitleLabel = centeredText(make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 8),
        Size = UDim2.fromOffset(math.max(30, #tostring(name) * 7 + 10), 14),
        ZIndex = 8,
    }, self.Frame), name, 11, Colors.Section)
    self.TitleLabel.BackgroundColor3 = Colors.Bg
    self.TitleLabel.BackgroundTransparency = 0
    self.Content = make("Frame", {
        Position = UDim2.fromOffset(6, 14),
        Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, self.Frame)
    self.Layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }, self.Content)
    self._layoutConnection = self.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local height = math.max(28, self.Layout.AbsoluteContentSize.Y + 20)
        self.Frame.Size = UDim2.new(1, 0, 0, height)
        self.Border.Size = UDim2.new(1, 0, 0, height - 8)
    end)
    return self
end

function Section:_addRow(height, name)
    self._rowCounter += 1
    local row = make("Frame", {
        Name = safeName(name or "row"),
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = self._rowCounter,
        ZIndex = 8,
    }, self.Content)
    return row
end

function Section:_register(widget, flag)
    self._widgets[#self._widgets + 1] = widget
    self.Window:_register(widget, flag)
    return widget
end

function Section:AddToggle(label, options)
    options = options or {}
    local row = self:_addRow(16, label)
    local widget = {
        Class = "Toggle",
        Label = label,
        Value = options.Default == nil and false or not not options.Default,
        Changed = newSignal(),
        _callback = options.Callback,
        _window = self.Window,
        _row = row,
    }
    function widget:GetValue() return self.Value end
    function widget:SetValue(value, silent)
        self.Value = not not value
        self._fill.Visible = self.Value
        if self._fill then
            tween(self._fill, 0.13, {
                BackgroundColor3 = self.Value and self._window.Accent or Colors.CbBg,
                BackgroundTransparency = self.Value and 0 or 0.3,
            })
        end
        if not silent then
            self.Changed:Fire(self.Value)
            if self._callback then task.spawn(self._callback, self.Value) end
            self._window.OnChanged:Fire(self.Flag, self.Value)
        end
    end
    function widget:Export()
        local colors = {}
        for i, picker in ipairs(self._colors or {}) do
            colors[i] = { R = picker.Value.R, G = picker.Value.G, B = picker.Value.B, A = picker.Alpha }
        end
        return { Value = self.Value, Colors = colors, Keybind = self._bind and self._bind.Key or nil }
    end
    function widget:Import(data)
        if type(data) ~= "table" then return end
        if data.Value ~= nil then self:SetValue(data.Value) end
        if data.Keybind and self._bind then self._bind:SetKey(data.Keybind) end
        for i, color in ipairs(data.Colors or {}) do
            if self._colors and self._colors[i] then
                self._colors[i]:SetColor(normalizeColor(color), color.A or 1)
            end
        end
    end

    local fillSize = 9
    local check = make("Frame", {
        Position = UDim2.fromOffset(0, 3),
        Size = UDim2.fromOffset(fillSize, fillSize),
        BackgroundColor3 = Colors.CbBg,
        BorderSizePixel = 0,
        ZIndex = 10,
    }, row)
    corner(check, 2)
    stroke(check, Colors.CbBorder, 1)
    widget._fill = make("Frame", {
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        BackgroundColor3 = self.Window.Accent,
        BorderSizePixel = 0,
        Visible = widget.Value,
        ZIndex = 11,
    }, check)
    corner(widget._fill, 1)

    local colors = options.Colors or options.Color
    if typeof(colors) == "Color3" then colors = { colors } end
    if type(colors) ~= "table" then colors = {} end
    local colorList = {}
    for _, color in ipairs(colors) do
        if typeof(color) == "Color3" or (type(color) == "table" and color.R) then
            colorList[#colorList + 1] = normalizeColor(color)
        end
    end
    local bindOption = options.Keybind
    local bindDefault
    local bindCallback
    if type(bindOption) == "table" then
        bindDefault = bindOption.Default or bindOption.Key
        bindCallback = bindOption.Callback
    else
        bindDefault = bindOption
    end
    local bindWidth = bindDefault and math.max(32, #tostring(bindDefault) * 6 + 8) or 0
    local controlWidth = bindWidth + (#colorList * 22)
    local labelObject = centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(15, 0),
        Size = UDim2.new(1, -15 - controlWidth - 2, 1, 0),
        ZIndex = 9,
    }, row), label, 11, Colors.Text)
    widget._labelObject = labelObject

    local click = make("TextButton", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -controlWidth - 2, 1, 0),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 12,
    }, row)
    click.MouseEnter:Connect(function()
        tween(labelObject, 0.1, { TextColor3 = Colors.TextBright })
        tween(check, 0.1, { BackgroundColor3 = Colors.CbBg:Lerp(self.Window.Accent, 0.18) })
    end)
    click.MouseLeave:Connect(function()
        tween(labelObject, 0.1, { TextColor3 = Colors.Text })
        tween(check, 0.1, { BackgroundColor3 = Colors.CbBg })
    end)
    click.Activated:Connect(function()
        widget:SetValue(not widget.Value)
    end)

    widget._colors = {}
    local offset = bindWidth
    for index = #colorList, 1, -1 do
        local swatch = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -offset, 0, 2),
            Size = UDim2.fromOffset(18, 12),
            BackgroundColor3 = colorList[index],
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 14,
        }, row)
        corner(swatch, 2)
        stroke(swatch, Colors.SectionBorder, 1)
        local picker = self:_makeColorPicker(label .. "_color_" .. tostring(index), colorList[index], options.Alpha or 1, swatch)
        widget._colors[index] = picker
        picker._row = row
        swatch.Activated:Connect(function() self.Window:_openColorPicker(picker) end)
        offset += 22
    end

    if bindDefault then
        local bind = self.Window:_makeBind(label, bindDefault, row, bindWidth, nil, bindCallback)
        widget._bind = bind
        bind._toggle = widget
    end

    self.Window:_onTheme(function(accent)
        if widget._fill then widget._fill.BackgroundColor3 = widget.Value and accent or Colors.CbBg end
    end)
    return self:_register(widget, options.Flag)
end

Section.AddCheckbox = Section.AddToggle

function Window:_makeBind(label, default, row, width, flag, callback)
    local bind = {
        Class = "Keybind",
        Label = label,
        Key = tostring(default or ""),
        Waiting = false,
        Changed = newSignal(),
        _callback = callback,
        _window = self,
    }
    function bind:GetValue() return self.Key end
    function bind:SetWaiting(value)
        self.Waiting = value
        self._button.Text = value and "press key" or "[" .. self.Key .. "]"
        self._button.TextColor3 = value and self._window.Accent or Colors.TextBind
    end
    function bind:SetKey(value, silent)
        self.Key = tostring(value or "")
        self:SetWaiting(false)
        if not silent then
            self.Changed:Fire(self.Key)
            if self._callback then task.spawn(self._callback, self.Key) end
        end
    end
    function bind:SetValue(value, silent) self:SetKey(value, silent) end
    function bind:Export() return self.Key end
    function bind:Import(value) self:SetKey(value) end

    local button = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(width, 16),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "[" .. tostring(default) .. "]",
        Font = Enum.Font.Arial,
        TextSize = 10,
        TextColor3 = Colors.TextBind,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 15,
    }, row)
    bind._button = button
    button.MouseEnter:Connect(function()
        if not bind.Waiting then tween(button, 0.1, { TextColor3 = Colors.Text }) end
    end)
    button.MouseLeave:Connect(function()
        if not bind.Waiting then tween(button, 0.1, { TextColor3 = Colors.TextBind }) end
    end)
    button.Activated:Connect(function()
        if bind.Waiting then
            bind:SetWaiting(false)
            self._activeBind = nil
        else
            for _, widget in ipairs(self._widgets) do
                if widget._bind and widget._bind ~= bind then widget._bind:SetWaiting(false) end
            end
            bind._captureMouse = false
            bind:SetWaiting(true)
            self._activeBind = bind
        end
    end)
    self:_register(bind, flag)
    return bind
end

function Section:AddKeybind(label, options)
    options = options or {}
    local row = self:_addRow(16, label)
    centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -58, 1, 0),
        ZIndex = 9,
    }, row), label, 11, Colors.Text)
    local default = options.Default or options.Key or ""
    local width = math.max(38, #tostring(default) * 6 + 8)
    return self.Window:_makeBind(label, default, row, width, options.Flag, options.Callback)
end

function Section:_makeColorPicker(label, value, alpha, swatch)
    local picker = {
        Class = "ColorPicker",
        Label = label,
        Value = normalizeColor(value),
        Alpha = alpha or 1,
        Changed = newSignal(),
        _swatch = swatch,
        _window = self.Window,
    }
    function picker:GetValue() return self.Value, self.Alpha end
    function picker:SetColor(color, newAlpha, silent)
        self.Value = normalizeColor(color, self.Value)
        if newAlpha ~= nil then self.Alpha = clamp(newAlpha, 0, 1) end
        if self._swatch then self._swatch.BackgroundColor3 = self.Value end
        if not silent then
            self.Changed:Fire(self.Value, self.Alpha)
            if self._callback then task.spawn(self._callback, self.Value, self.Alpha) end
            self._window.OnChanged:Fire(self.Flag, self.Value)
        end
    end
    function picker:SetValue(color, silent) self:SetColor(color, nil, silent) end
    function picker:Export()
        return { R = self.Value.R, G = self.Value.G, B = self.Value.B, A = self.Alpha }
    end
    function picker:Import(value)
        if type(value) == "table" then self:SetColor(normalizeColor(value), value.A or 1) end
    end
    self.Window:_onTheme(function(accent)
        if picker._swatch then
            local outline = picker._swatch:FindFirstChildOfClass("UIStroke")
            if outline then outline.Color = Colors.SectionBorder end
        end
    end)
    return picker
end

function Section:AddColorPicker(label, options)
    options = options or {}
    local row = self:_addRow(16, label)
    local picker
    local swatch = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 2),
        Size = UDim2.fromOffset(18, 12),
        BackgroundColor3 = normalizeColor(options.Default or options.Color, Color3.new(1, 1, 1)),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 14,
    }, row)
    corner(swatch, 2)
    stroke(swatch, Colors.SectionBorder, 1)
    picker = self:_makeColorPicker(label, swatch.BackgroundColor3, options.Alpha or 1, swatch)
    picker._callback = options.Callback
    swatch.Activated:Connect(function() self.Window:_openColorPicker(picker) end)
    centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        ZIndex = 9,
    }, row), label, 11, Colors.Text)
    return self:_register(picker, options.Flag)
end

function Section:AddSlider(label, options)
    options = options or {}
    local minimum = options.Min == nil and 0 or options.Min
    local maximum = options.Max == nil and 100 or options.Max
    local value = clamp(options.Default == nil and minimum or options.Default, minimum, maximum)
    local row = self:_addRow(26, label)
    local widget = {
        Class = "Slider",
        Label = label,
        Value = value,
        Min = minimum,
        Max = maximum,
        Suffix = options.Suffix or "",
        Format = options.Format or "%.0f",
        Changed = newSignal(),
        _callback = options.Callback,
        _window = self.Window,
    }
    function widget:GetValue() return self.Value end
    function widget:SetValue(newValue, silent)
        self.Value = clamp(tonumber(newValue) or self.Min, self.Min, self.Max)
        local percent = (self.Max > self.Min) and ((self.Value - self.Min) / (self.Max - self.Min)) or 0
        self._fill.Size = UDim2.new(percent, 0, 1, 0)
        self._valueLabel.Text = formatValue(self.Value, self.Format) .. self.Suffix
        self._valueLabel.Position = UDim2.new(percent, 0, 0, 0)
        if not silent then
            self.Changed:Fire(self.Value)
            if self._callback then task.spawn(self._callback, self.Value) end
            self._window.OnChanged:Fire(self.Flag, self.Value)
        end
    end
    function widget:Export() return self.Value end
    function widget:Import(newValue) self:SetValue(newValue) end

    centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 14),
        ZIndex = 9,
    }, row), label, 11, Colors.TextDim)
    local minus = centeredText(make("TextButton", {
        Position = UDim2.fromOffset(0, 13),
        Size = UDim2.fromOffset(12, 12),
        AutoButtonColor = false,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 14,
    }, row), "-", 11, Colors.TextBind)
    minus.Activated:Connect(function() widget:SetValue(widget.Value - (maximum - minimum) * 0.01) end)

    local trackButton = make("TextButton", {
        Position = UDim2.fromOffset(18, 14),
        Size = UDim2.new(1, -54, 0, 10),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 13,
    }, row)
    widget._track = make("Frame", {
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(16, 16, 16),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, trackButton)
    local trackGradient = gradient(widget._track, Color3.fromRGB(23, 23, 23), Color3.fromRGB(16, 16, 16), 90)
    widget._fill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = self.Window.Accent,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, widget._track)
    gradient(widget._fill, self.Window:_themeColor(0.62), self.Window.Accent, 90)
    trackButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Window._activeSlider = widget
            self.Window:_setSliderFromX(widget, input.Position.X)
        end
    end)

    widget._valueLabel = centeredText(make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0, 0, 0, 14),
        Size = UDim2.fromOffset(40, 13),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 15,
    }, trackButton), "", 10, Colors.TextBright)
    local plus = centeredText(make("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 13),
        Size = UDim2.fromOffset(12, 12),
        AutoButtonColor = false,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 14,
    }, row), "+", 11, Colors.TextBind)
    plus.Activated:Connect(function() widget:SetValue(widget.Value + (maximum - minimum) * 0.01) end)
    self.Window:_onTheme(function(accent)
        widget._fill.BackgroundColor3 = accent
    end)
    widget:SetValue(value, true)
    return self:_register(widget, options.Flag)
end

Section.AddSliderFloat = Section.AddSlider

function Section:AddDropdown(label, options)
    options = options or {}
    local values = options.Values or options.Items or {}
    local normalized = {}
    for _, value in ipairs(values) do normalized[#normalized + 1] = tostring(value) end
    local index = options.Default
    if type(index) == "string" then
        for i, value in ipairs(normalized) do if value == index then index = i break end end
    end
    index = clamp(tonumber(index) or 1, 1, math.max(1, #normalized))
    local row = self:_addRow(17, label)
    local widget = {
        Class = "Dropdown",
        Label = label,
        Values = normalized,
        Index = index,
        Changed = newSignal(),
        _callback = options.Callback,
        _window = self.Window,
    }
    function widget:GetValue() return self.Values[self.Index], self.Index end
    function widget:SetValue(newValue, silent)
        local newIndex = tonumber(newValue)
        if not newIndex then
            for i, value in ipairs(self.Values) do if value == tostring(newValue) then newIndex = i break end end
        end
        self.Index = clamp(newIndex or self.Index, 1, math.max(1, #self.Values))
        self._label.Text = self.Values[self.Index] or ""
        if not silent then
            self.Changed:Fire(self.Values[self.Index], self.Index)
            if self._callback then task.spawn(self._callback, self.Values[self.Index], self.Index) end
            self._window.OnChanged:Fire(self.Flag, self.Values[self.Index])
        end
    end
    function widget:Export() return { Index = self.Index, Value = self.Values[self.Index] } end
    function widget:Import(data)
        if type(data) == "table" then self:SetValue(data.Index or data.Value) else self:SetValue(data) end
    end

    local button = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Colors.Bg,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 12,
    }, row)
    corner(button, 2)
    widget._button = button
    gradient(button, Color3.fromRGB(20, 20, 20), Color3.fromRGB(9, 9, 9), 90)
    widget._label = centeredText(make("TextLabel", {
        Position = UDim2.fromOffset(7, 0),
        Size = UDim2.new(1, -26, 1, 0),
        ZIndex = 14,
    }, button), "", 11, Colors.Text)
    local arrow = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.fromOffset(10, 17),
        BackgroundTransparency = 1,
        Text = "▼",
        Font = Enum.Font.Arial,
        TextSize = 8,
        TextColor3 = Colors.TextBind,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 14,
    }, button)
    button.MouseEnter:Connect(function()
        tween(button, 0.1, { BackgroundColor3 = Color3.fromRGB(16, 14, 18) })
        tween(arrow, 0.1, { TextColor3 = Colors.Text })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.1, { BackgroundColor3 = Colors.Bg })
        if not self.Window._activePopup then tween(arrow, 0.1, { TextColor3 = Colors.TextBind }) end
    end)
    button.Activated:Connect(function() self.Window:_openDropdown(widget) end)
    widget:SetValue(index, true)
    return self:_register(widget, options.Flag)
end

Section.AddCombo = Section.AddDropdown

function Section:AddButton(label, callback, options)
    options = options or {}
    if type(callback) == "table" then options, callback = callback, callback.Callback end
    local row = self:_addRow(18, label)
    local button = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(22, 20, 26),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = label,
        Font = Enum.Font.Arial,
        TextSize = 11,
        TextColor3 = Colors.Text,
        ZIndex = 12,
    }, row)
    corner(button, 2)
    local buttonGradient = gradient(button, Color3.fromRGB(22, 20, 26), Color3.fromRGB(10, 9, 11), 90)
    stroke(button, Color3.fromRGB(22, 22, 22), 1)
    button.MouseEnter:Connect(function()
        tween(button, 0.1, { BackgroundColor3 = Color3.fromRGB(30, 27, 35), TextColor3 = Colors.TextBright })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.1, { BackgroundColor3 = Color3.fromRGB(22, 20, 26), TextColor3 = Colors.Text })
    end)
    button.Activated:Connect(function()
        if callback then task.spawn(callback) end
    end)
    return button
end

function Section:AddInput(label, options)
    options = options or {}
    local row = self:_addRow(options.Height or 17, label)
    local input = make("TextBox", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(20, 18, 23),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = options.Placeholder or "...",
        Text = options.Default or "",
        Font = Enum.Font.Arial,
        TextSize = 11,
        TextColor3 = Colors.TextBright,
        PlaceholderColor3 = Colors.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, row)
    corner(input, 2)
    stroke(input, Colors.CbBorder, 1)
    make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 4) }, input)
    input.Focused:Connect(function() tween(input:FindFirstChildOfClass("UIStroke"), 0.1, { Color = self.Window.Accent }) end)
    input.FocusLost:Connect(function(enterPressed)
        local outline = input:FindFirstChildOfClass("UIStroke")
        if outline then tween(outline, 0.1, { Color = Colors.CbBorder }) end
        if options.Callback then task.spawn(options.Callback, input.Text, enterPressed) end
    end)
    local widget = {
        Class = "Input",
        Label = label,
        Input = input,
        Changed = newSignal(),
    }
    function widget:GetValue() return self.Input.Text end
    function widget:SetValue(value, silent)
        self.Input.Text = tostring(value or "")
        if not silent then self.Changed:Fire(self.Input.Text) end
    end
    function widget:Export() return self.Input.Text end
    function widget:Import(value) self:SetValue(value) end
    return self:_register(widget, options.Flag)
end

function Section:AddSeparator(label)
    local row = self:_addRow(17, label or "")
    local line = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Colors.SectionBorder,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, row)
    local text = centeredText(make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(math.max(30, #tostring(label or "") * 7 + 10), 14),
        ZIndex = 9,
    }, row), label or "", 11, Colors.Section)
    text.BackgroundColor3 = Colors.Bg
    text.BackgroundTransparency = 0
    return row
end

function ConfigPanel.new(window, parent, name, options)
    local self = setmetatable({}, ConfigPanel)
    self.Window = window
    self.Name = name
    self.Options = options
    self.Frame = make("Frame", {
        Name = safeName(name),
        Size = UDim2.new(1, 0, 0, 380),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = options.LayoutOrder or 0,
        ZIndex = 6,
    }, parent)
    self.Border = make("Frame", {
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, self.Frame)
    corner(self.Border, 2)
    stroke(self.Border, Colors.SectionBorder, 1)
    local title = centeredText(make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 8),
        Size = UDim2.fromOffset(#name * 7 + 10, 14),
        ZIndex = 8,
    }, self.Frame), name, 11, Colors.Section)
    title.BackgroundColor3 = Colors.Bg
    title.BackgroundTransparency = 0

    self.Inner = make("Frame", {
        Position = UDim2.fromOffset(6, 14),
        Size = UDim2.new(1, -12, 1, -20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, self.Frame)
    local listHeight = 254
    self.ListFrame = make("Frame", {
        Size = UDim2.new(1, 0, 0, listHeight),
        BackgroundColor3 = Color3.fromRGB(6, 5, 7),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 8,
    }, self.Inner)
    corner(self.ListFrame, 3)
    stroke(self.ListFrame, Colors.SectionBorder, 1)
    self.ListLayout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, self.ListFrame)
    self.Input = make("TextBox", {
        Position = UDim2.fromOffset(0, listHeight + 4),
        Size = UDim2.new(1, 0, 0, 17),
        BackgroundColor3 = Color3.fromRGB(20, 18, 23),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "...",
        Font = Enum.Font.Arial,
        TextSize = 11,
        TextColor3 = Colors.TextBright,
        PlaceholderColor3 = Colors.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 10,
    }, self.Inner)
    corner(self.Input, 2)
    stroke(self.Input, Colors.CbBorder, 1)
    make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, self.Input)

    local function addButton(text, y, callback)
        local button = make("TextButton", {
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundColor3 = Color3.fromRGB(22, 20, 26),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = text,
            Font = Enum.Font.Arial,
            TextSize = 11,
            TextColor3 = Colors.Text,
            ZIndex = 10,
        }, self.Inner)
        corner(button, 2)
        gradient(button, Color3.fromRGB(22, 20, 26), Color3.fromRGB(10, 9, 11), 90)
        button.MouseEnter:Connect(function() tween(button, 0.1, { BackgroundColor3 = Color3.fromRGB(30, 27, 35), TextColor3 = Colors.TextBright }) end)
        button.MouseLeave:Connect(function() tween(button, 0.1, { BackgroundColor3 = Color3.fromRGB(22, 20, 26), TextColor3 = Colors.Text }) end)
        button.Activated:Connect(callback)
        return button
    end
    local y = listHeight + 25
    self.CreateButton = addButton("create", y, function() self:Create() end)
    y += 21
    self.SaveButton = addButton("save", y, function() self:Save() end)
    y += 21
    self.LoadButton = addButton("load", y, function() self:Load() end)
    y += 21
    self.OpenButton = addButton("open directory", y, function() self:OpenDirectory() end)
    self.Selected = nil
    self:Refresh()
    return self
end

function ConfigPanel:Refresh()
    for _, child in ipairs(self.ListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local names = self.Window.Configs:List()
    for index, name in ipairs(names) do
        local selected = self.Selected == name or self.Window.Configs._selected == name
        local button = make("TextButton", {
            Size = UDim2.new(1, -2, 0, 17),
            Position = UDim2.fromOffset(1, 0),
            BackgroundColor3 = selected and Color3.fromRGB(35, 32, 44) or Color3.fromRGB(6, 5, 7),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = name,
            Font = Enum.Font.Arial,
            TextSize = 11,
            TextColor3 = selected and self.Window.Accent or Colors.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = index,
            ZIndex = 10,
        }, self.ListFrame)
        make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, button)
        button.MouseEnter:Connect(function() tween(button, 0.08, { BackgroundColor3 = Color3.fromRGB(22, 20, 27), TextColor3 = Colors.TextBright }) end)
        button.MouseLeave:Connect(function()
            local active = self.Selected == name or self.Window.Configs._selected == name
            tween(button, 0.08, { BackgroundColor3 = active and Color3.fromRGB(35, 32, 44) or Color3.fromRGB(6, 5, 7), TextColor3 = active and self.Window.Accent or Colors.Text })
        end)
        button.Activated:Connect(function()
            self.Selected = name
            self.Window.Configs._selected = name
            self:Refresh()
        end)
    end
end

function ConfigPanel:Create()
    local name = self.Input.Text
    if self.Window.Configs:Create(name) then
        self.Selected = name
        self.Input.Text = ""
        self:Refresh()
    end
end

function ConfigPanel:Save()
    if self.Window.Configs:Save(self.Selected) then
        self.Window:Notify({ Title = "configs", Content = "saved " .. tostring(self.Selected), Duration = 1.5 })
    end
end

function ConfigPanel:Load()
    if self.Window.Configs:Load(self.Selected) then
        self.Window:Notify({ Title = "configs", Content = "loaded " .. tostring(self.Selected), Duration = 1.5 })
    end
end

function ConfigPanel:OpenDirectory()
    if not self.Window.Configs:OpenDirectory() then
        self.Window:Notify({ Title = "configs", Content = "filesystem access is not available in Roblox", Duration = 2.5 })
    end
end

function Window:Destroy()
    for _, connection in ipairs(self._connections) do
        if connection and connection.Disconnect then connection:Disconnect() end
    end
    self._connections = {}
    if self.ScreenGui then self.ScreenGui:Destroy() end
    self._visible = false
end

function Library:Destroy()
    for _, window in ipairs(self.Windows) do
        window:Destroy()
    end
    self.Windows = {}
end

Bankroll.Library = Library
Bankroll.Window = Window
Bankroll.Tab = Tab
Bankroll.Section = Section
Bankroll.ConfigPanel = ConfigPanel

return Bankroll
