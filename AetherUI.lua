--[[
    AetherUI v1.0.0
    A client-side Roblox UI library for Roblox Studio.

    Install:
      1. Put this ModuleScript in ReplicatedStorage and name it "AetherUI".
      2. Require it from a LocalScript.

    This library uses standard Roblox client APIs only. It does not use
    executor functions, loadstring, getgenv, or exploit-only APIs.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Library = {
    Name = "AetherUI",
    Version = "1.0.0",
}

local Theme = {
    Background = Color3.fromRGB(14, 16, 23),
    Surface = Color3.fromRGB(20, 23, 33),
    SurfaceAlt = Color3.fromRGB(27, 31, 43),
    SurfaceHover = Color3.fromRGB(35, 40, 55),
    Border = Color3.fromRGB(48, 54, 72),
    Text = Color3.fromRGB(239, 242, 250),
    Muted = Color3.fromRGB(148, 156, 177),
    Accent = Color3.fromRGB(133, 112, 255),
    AccentDark = Color3.fromRGB(91, 74, 205),
    Success = Color3.fromRGB(92, 205, 151),
    Danger = Color3.fromRGB(236, 98, 112),
}

local WindowMethods = {}
WindowMethods.__index = WindowMethods
local TabMethods = {}
TabMethods.__index = TabMethods
local SectionMethods = {}
SectionMethods.__index = SectionMethods

local function copyTheme(custom)
    local result = {}
    for key, value in pairs(Theme) do
        result[key] = value
    end
    if type(custom) == "table" then
        for key, value in pairs(custom) do
            if result[key] ~= nil and typeof(value) == "Color3" then
                result[key] = value
            end
        end
    end
    return result
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
    }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
    }, parent)
end

local function tween(object, duration, properties)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[AetherUI] Callback error: " .. tostring(err))
    end
end

local function formatNumber(value)
    if math.abs(value - math.round(value)) < 0.000001 then
        return tostring(math.round(value))
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function addConnection(window, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(window._connections, connection)
    return connection
end

local function makeText(parent, text, size, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = color,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

function Library.CreateWindow(options)
    options = options or {}

    local player = Players.LocalPlayer
    if not player then
        error("AetherUI must be required from a client LocalScript.", 2)
    end

    local playerGui = player:WaitForChild("PlayerGui")
    local theme = copyTheme(options.Theme)

    local self = setmetatable({
        _theme = theme,
        _connections = {},
        _tabs = {},
        _notifications = {},
        _destroyed = false,
        _visible = true,
        _minimized = false,
        _keybindCapture = nil,
        _toggleKey = options.ToggleKey == nil and Enum.KeyCode.RightControl or options.ToggleKey,
        _title = options.Title or "AetherUI",
        _subtitle = options.Subtitle or "Client Interface",
    }, WindowMethods)

    local gui = make("ScreenGui", {
        Name = "AetherUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.DisplayOrder or 20,
    }, playerGui)
    self._gui = gui

    local shadow = make("Frame", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(3, 7),
        Size = UDim2.fromScale(0.92, 0.82),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, gui)
    corner(shadow, 16)

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.92, 0.82),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
    }, gui)
    corner(root, 16)
    stroke(root, theme.Border, 0.08, 1)
    make("UISizeConstraint", {
        MinSize = Vector2.new(290, 280),
        MaxSize = Vector2.new(760, 560),
    }, root)
    self._root = root
    self._shadow = shadow
    self._openSize = root.Size

    local function syncShadowSize()
        if root.Parent and shadow.Parent then
            shadow.Size = UDim2.fromOffset(root.AbsoluteSize.X, root.AbsoluteSize.Y)
        end
    end
    addConnection(self, root:GetPropertyChangedSignal("AbsoluteSize"), syncShadowSize)
    task.defer(syncShadowSize)

    local header = make("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, root)
    self._header = header

    local accentLine = make("Frame", {
        Name = "AccentLine",
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, header)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.AccentDark),
            ColorSequenceKeypoint.new(0.55, theme.Accent),
            ColorSequenceKeypoint.new(1, theme.Success),
        }),
    }, accentLine)

    local title = makeText(header, self._title, 15, theme.Text, Enum.Font.GothamBold)
    title.Name = "Title"
    title.Position = UDim2.fromOffset(19, 9)
    title.Size = UDim2.new(1, -112, 0, 23)
    self._titleLabel = title

    local subtitle = makeText(header, self._subtitle, 10, theme.Muted, Enum.Font.GothamMedium)
    subtitle.Name = "Subtitle"
    subtitle.Position = UDim2.fromOffset(20, 32)
    subtitle.Size = UDim2.new(1, -112, 0, 17)

    local minimizeButton = make("TextButton", {
        Name = "Minimize",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -47, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = theme.SurfaceAlt,
        Text = "−",
        TextColor3 = theme.Muted,
        TextSize = 19,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, header)
    corner(minimizeButton, 8)

    local closeButton = make("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = theme.SurfaceAlt,
        Text = "×",
        TextColor3 = theme.Danger,
        TextSize = 19,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, header)
    corner(closeButton, 8)

    local body = make("Frame", {
        Name = "Body",
        Position = UDim2.fromOffset(0, 62),
        Size = UDim2.new(1, 0, 1, -62),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, root)
    self._body = body

    local sidebar = make("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 156, 1, 0),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
    }, body)
    self._sidebar = sidebar

    local sidebarEdge = make("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
    }, sidebar)

    local navList = make("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(8, 10),
        Size = UDim2.new(1, -16, 1, -20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, sidebar)
    self._navList = navList
    local navLayout = make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, navList)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 4),
    }, navList)

    local pageHost = make("Frame", {
        Name = "PageHost",
        Position = UDim2.new(0, 156, 0, 0),
        Size = UDim2.new(1, -156, 1, 0),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, body)
    self._pageHost = pageHost

    local notificationHolder = make("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(290, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 50,
    }, gui)
    self._notificationHolder = notificationHolder
    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, notificationHolder)

    local dragState = nil
    addConnection(self, header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragState = {
                Input = input,
                Start = input.Position,
                Position = root.Position,
            }
        end
    end)

    addConnection(self, UserInputService.InputChanged, function(input)
        if not dragState then
            return
        end
        local isDragInput = input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        if isDragInput then
            local delta = input.Position - dragState.Start
            root.Position = UDim2.new(
                dragState.Position.X.Scale,
                dragState.Position.X.Offset + delta.X,
                dragState.Position.Y.Scale,
                dragState.Position.Y.Offset + delta.Y
            )
            shadow.Position = root.Position + UDim2.fromOffset(3, 7)
        end
    end)

    addConnection(self, UserInputService.InputEnded, function(input)
        if dragState and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragState = nil
        end
    end)

    addConnection(self, minimizeButton.Activated, function()
        self:SetMinimized(not self._minimized)
    end)
    addConnection(self, closeButton.Activated, function()
        self:Destroy()
    end)

    addConnection(self, minimizeButton.MouseEnter, function()
        tween(minimizeButton, 0.12, { BackgroundColor3 = theme.SurfaceHover })
    end)
    addConnection(self, minimizeButton.MouseLeave, function()
        tween(minimizeButton, 0.12, { BackgroundColor3 = theme.SurfaceAlt })
    end)
    addConnection(self, closeButton.MouseEnter, function()
        tween(closeButton, 0.12, { BackgroundColor3 = Color3.fromRGB(65, 34, 46) })
    end)
    addConnection(self, closeButton.MouseLeave, function()
        tween(closeButton, 0.12, { BackgroundColor3 = theme.SurfaceAlt })
    end)

    addConnection(self, UserInputService.InputBegan, function(input, gameProcessed)
        if self._destroyed or gameProcessed or UserInputService:GetFocusedTextBox() then
            return
        end

        if self._keybindCapture then
            if input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode ~= Enum.KeyCode.Unknown then
                local target = self._keybindCapture
                self._keybindCapture = nil
                target:SetKey(input.KeyCode)
            end
            return
        end

        if self._toggleKey and input.KeyCode == self._toggleKey then
            self:SetVisible(not self._visible)
            return
        end

        for _, tab in ipairs(self._tabs) do
            for _, section in ipairs(tab._sections) do
                for _, control in ipairs(section._controls) do
                    if control._kind == "Keybind" and control._key == input.KeyCode then
                        safeCall(control._callback, input.KeyCode)
                    end
                end
            end
        end
    end)

    local function updateResponsiveLayout()
        if self._destroyed then
            return
        end
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        local compact = viewport and viewport.X < 560
        if compact then
            sidebar.Position = UDim2.fromOffset(0, 0)
            sidebar.Size = UDim2.new(1, 0, 0, 48)
            sidebarEdge.Position = UDim2.new(0, 0, 1, -1)
            sidebarEdge.Size = UDim2.new(1, 0, 0, 1)
            navList.Position = UDim2.fromOffset(8, 5)
            navList.Size = UDim2.new(1, -16, 1, -10)
            navList.ScrollingDirection = Enum.ScrollingDirection.X
            navLayout.FillDirection = Enum.FillDirection.Horizontal
            pageHost.Position = UDim2.fromOffset(0, 48)
            pageHost.Size = UDim2.new(1, 0, 1, -48)
            for _, tab in ipairs(self._tabs) do
                tab._navButton.Size = UDim2.fromOffset(112, 34)
            end
        else
            sidebar.Position = UDim2.fromOffset(0, 0)
            sidebar.Size = UDim2.new(0, 156, 1, 0)
            sidebarEdge.Position = UDim2.new(1, -1, 0, 0)
            sidebarEdge.Size = UDim2.new(0, 1, 1, 0)
            navList.Position = UDim2.fromOffset(8, 10)
            navList.Size = UDim2.new(1, -16, 1, -20)
            navList.ScrollingDirection = Enum.ScrollingDirection.Y
            navLayout.FillDirection = Enum.FillDirection.Vertical
            pageHost.Position = UDim2.new(0, 156, 0, 0)
            pageHost.Size = UDim2.new(1, -156, 1, 0)
            for _, tab in ipairs(self._tabs) do
                tab._navButton.Size = UDim2.new(1, -2, 0, 42)
            end
        end
        navList.CanvasSize = UDim2.fromOffset(
            navLayout.AbsoluteContentSize.X,
            navLayout.AbsoluteContentSize.Y + 8
        )
    end
    self._updateResponsiveLayout = updateResponsiveLayout

    if workspace.CurrentCamera then
        addConnection(self, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateResponsiveLayout)
    end
    addConnection(self, navLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        navList.CanvasSize = UDim2.fromOffset(
            navLayout.AbsoluteContentSize.X + 8,
            navLayout.AbsoluteContentSize.Y + 8
        )
    end)
    updateResponsiveLayout()

    return self
end

function WindowMethods:CreateTab(name)
    assert(not self._destroyed, "Cannot create a tab on a destroyed window.")
    name = tostring(name or ("Tab " .. tostring(#self._tabs + 1)))

    local theme = self._theme
    local index = #self._tabs + 1

    local page = make("ScrollingFrame", {
        Name = "Page_" .. tostring(index),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.Accent,
        CanvasSize = UDim2.new(),
        Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, self._pageHost)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    }, page)
    local pageLayout = make("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    local navButton = make("TextButton", {
        Name = "TabButton_" .. tostring(index),
        Size = UDim2.new(1, -2, 0, 42),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = index,
    }, self._navList)
    corner(navButton, 9)

    local indicator = make("Frame", {
        Name = "ActiveIndicator",
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(0, 3, 1, -16),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, navButton)
    corner(indicator, 3)

    local navText = makeText(navButton, name, 12, theme.Muted, Enum.Font.GothamMedium)
    navText.Position = UDim2.fromOffset(13, 0)
    navText.Size = UDim2.new(1, -21, 1, 0)
    navText.TextXAlignment = Enum.TextXAlignment.Left

    local tab = setmetatable({
        _window = self,
        _name = name,
        _page = page,
        _navButton = navButton,
        _indicator = indicator,
        _navText = navText,
        _sections = {},
        _selected = false,
    }, TabMethods)
    table.insert(self._tabs, tab)

    addConnection(self, navButton.Activated, function()
        self:SelectTab(tab)
    end)
    addConnection(self, navButton.MouseEnter, function()
        if not tab._selected then
            tween(navButton, 0.12, { BackgroundTransparency = 0.35, BackgroundColor3 = theme.SurfaceAlt })
            tween(navText, 0.12, { TextColor3 = theme.Text })
        end
    end)
    addConnection(self, navButton.MouseLeave, function()
        if not tab._selected then
            tween(navButton, 0.12, { BackgroundTransparency = 1 })
            tween(navText, 0.12, { TextColor3 = theme.Muted })
        end
    end)

    if #self._tabs == 1 then
        self:SelectTab(tab)
    end
    if self._updateResponsiveLayout then
        self._updateResponsiveLayout()
    end
    return tab
end

function WindowMethods:SelectTab(target)
    if self._destroyed then
        return
    end
    local selected = target
    if type(target) == "string" then
        selected = nil
        for _, tab in ipairs(self._tabs) do
            if tab._name == target then
                selected = tab
                break
            end
        end
    end

    for _, tab in ipairs(self._tabs) do
        local active = tab == selected
        tab._selected = active
        tab._page.Visible = active
        tween(tab._navButton, 0.14, {
            BackgroundTransparency = active and 0 or 1,
            BackgroundColor3 = active and self._theme.SurfaceAlt or self._theme.Surface,
        })
        tween(tab._indicator, 0.14, {
            BackgroundTransparency = active and 0 or 1,
        })
        tween(tab._navText, 0.14, {
            TextColor3 = active and self._theme.Text or self._theme.Muted,
        })
    end
end

function WindowMethods:SetVisible(visible)
    if self._destroyed then
        return
    end
    self._visible = visible == true
    self._gui.Enabled = self._visible
end

function WindowMethods:Toggle()
    self:SetVisible(not self._visible)
end

function WindowMethods:SetToggleKey(key)
    if key == nil or (typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode) then
        self._toggleKey = key
    else
        warn("[AetherUI] SetToggleKey expects an Enum.KeyCode or nil.")
    end
end

function WindowMethods:SetMinimized(minimized)
    if self._destroyed then
        return
    end
    minimized = minimized == true
    if self._minimized == minimized then
        return
    end
    self._minimized = minimized
    local constraint = self._root:FindFirstChildOfClass("UISizeConstraint")
    local button = self._header:FindFirstChild("Minimize")

    if minimized then
        self._body.Visible = false
        if constraint then
            constraint.MinSize = Vector2.new(0, 0)
        end
        tween(self._root, 0.2, {
            Size = UDim2.new(self._openSize.X.Scale, self._openSize.X.Offset, 0, 62),
        })
        if button then button.Text = "+" end
    else
        if constraint then
            constraint.MinSize = Vector2.new(290, 280)
        end
        self._body.Visible = true
        tween(self._root, 0.2, { Size = self._openSize })
        if button then button.Text = "−" end
    end
end

function WindowMethods:SetTitle(title, subtitle)
    if self._destroyed then
        return
    end
    self._title = tostring(title or self._title)
    self._titleLabel.Text = self._title
    if subtitle ~= nil then
        self._subtitle = tostring(subtitle)
        local label = self._header:FindFirstChild("Subtitle")
        if label then label.Text = self._subtitle end
    end
end

function WindowMethods:Notify(title, message, duration)
    if self._destroyed then
        return
    end
    local theme = self._theme
    local holder = self._notificationHolder

    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 51,
    }, holder)
    corner(card, 11)
    stroke(card, theme.Border, 0.05, 1)

    local bar = make("Frame", {
        Size = UDim2.new(0, 3, 1, -18),
        Position = UDim2.fromOffset(0, 9),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, card)
    corner(bar, 2)

    local titleLabel = makeText(card, title or "Notification", 12, theme.Text, Enum.Font.GothamBold)
    titleLabel.Position = UDim2.fromOffset(14, 8)
    titleLabel.Size = UDim2.new(1, -25, 0, 20)
    titleLabel.ZIndex = 52

    local messageLabel = makeText(card, message or "", 10, theme.Muted, Enum.Font.Gotham)
    messageLabel.Position = UDim2.fromOffset(14, 30)
    messageLabel.Size = UDim2.new(1, -25, 0, 29)
    messageLabel.TextWrapped = true
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.TextTruncate = Enum.TextTruncate.None
    messageLabel.ZIndex = 52

    card.BackgroundTransparency = 1
    card.Position = UDim2.fromOffset(18, 0)
    tween(card, 0.18, {
        BackgroundTransparency = 0.04,
        Position = UDim2.fromOffset(0, 0),
    })

    table.insert(self._notifications, card)
    task.delay(duration or 3.5, function()
        if self._destroyed or not card.Parent then
            return
        end
        tween(card, 0.18, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 0),
        })
        task.wait(0.2)
        if card.Parent then
            card:Destroy()
        end
    end)
end

function WindowMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    for _, connection in ipairs(self._connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    table.clear(self._connections)
    if self._gui then
        self._gui:Destroy()
    end
end

function TabMethods:CreateSection(title)
    local window = self._window
    assert(not window._destroyed, "Cannot create a section on a destroyed window.")
    local theme = window._theme

    local sectionFrame = make("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    }, self._page)
    corner(sectionFrame, 11)
    stroke(sectionFrame, theme.Border, 0.3, 1)

    local heading = makeText(sectionFrame, title or "Section", 12, theme.Text, Enum.Font.GothamBold)
    heading.Position = UDim2.fromOffset(13, 8)
    heading.Size = UDim2.new(1, -26, 0, 22)

    local content = make("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(12, 34),
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, sectionFrame)
    local contentLayout = make("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)
    make("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
    }, content)

    local section = setmetatable({
        _window = window,
        _frame = sectionFrame,
        _content = content,
        _layout = contentLayout,
        _controls = {},
    }, SectionMethods)
    table.insert(self._sections, section)
    return section
end

local function addControl(section, control)
    table.insert(section._controls, control)
    return control
end

function SectionMethods:CreateButton(text, callback, description)
    local theme = self._window._theme
    local row = make("TextButton", {
        Size = UDim2.new(1, 0, 0, description and 54 or 42),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, self._content)
    corner(row, 8)

    local label = makeText(row, text or "Button", 11, theme.Text, Enum.Font.GothamMedium)
    label.Position = UDim2.fromOffset(12, description and 6 or 0)
    label.Size = UDim2.new(1, -42, 0, description and 20 or 42)
    if description then
        local detail = makeText(row, description, 9, theme.Muted, Enum.Font.Gotham)
        detail.Position = UDim2.fromOffset(12, 27)
        detail.Size = UDim2.new(1, -24, 0, 17)
    end

    local arrow = makeText(row, "›", 21, theme.Muted, Enum.Font.Gotham)
    arrow.TextXAlignment = Enum.TextXAlignment.Center
    arrow.Position = UDim2.new(1, -34, 0, 0)
    arrow.Size = UDim2.fromOffset(22, 42)

    addConnection(self._window, row.MouseEnter, function()
        tween(row, 0.12, { BackgroundColor3 = theme.SurfaceHover })
    end)
    addConnection(self._window, row.MouseLeave, function()
        tween(row, 0.12, { BackgroundColor3 = theme.SurfaceAlt })
    end)
    addConnection(self._window, row.Activated, function()
        safeCall(callback)
    end)

    return addControl(self, { _kind = "Button", Instance = row })
end

function SectionMethods:CreateToggle(text, default, callback)
    local theme = self._window._theme
    local value = default == true

    local row = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, self._content)

    local label = makeText(row, text or "Toggle", 11, theme.Text, Enum.Font.GothamMedium)
    label.Size = UDim2.new(1, -64, 1, 0)
    label.Position = UDim2.fromOffset(1, 0)

    local switch = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(39, 22),
        BackgroundColor3 = value and theme.AccentDark or theme.SurfaceHover,
        BorderSizePixel = 0,
    }, row)
    corner(switch, 20)
    local knob = make("Frame", {
        Position = value and UDim2.new(1, -19, 0, 3) or UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.fromRGB(245, 246, 251),
        BorderSizePixel = 0,
    }, switch)
    corner(knob, 20)

    local control = { _kind = "Toggle", _value = value, Instance = row }
    function control:SetValue(nextValue, silent)
        self._value = nextValue == true
        tween(switch, 0.14, {
            BackgroundColor3 = self._value and theme.AccentDark or theme.SurfaceHover,
        })
        tween(knob, 0.14, {
            Position = self._value and UDim2.new(1, -19, 0, 3) or UDim2.fromOffset(3, 3),
        })
        if not silent then
            safeCall(callback, self._value)
        end
    end
    function control:GetValue()
        return self._value
    end

    addConnection(self._window, row.Activated, function()
        control:SetValue(not control._value)
    end)
    addControl(self, control)
    return control
end

function SectionMethods:CreateSlider(text, minimum, maximum, default, callback, step)
    local theme = self._window._theme
    minimum = tonumber(minimum) or 0
    maximum = tonumber(maximum) or 100
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    step = tonumber(step) or 1
    if step <= 0 then step = 1 end

    local function normalize(value)
        value = math.clamp(tonumber(value) or minimum, minimum, maximum)
        value = minimum + math.round((value - minimum) / step) * step
        return math.clamp(value, minimum, maximum)
    end

    local value = normalize(default == nil and minimum or default)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 59),
        BackgroundTransparency = 1,
    }, self._content)

    local label = makeText(row, text or "Slider", 11, theme.Text, Enum.Font.GothamMedium)
    label.Position = UDim2.fromOffset(1, 0)
    label.Size = UDim2.new(1, -65, 0, 22)

    local valueLabel = makeText(row, formatNumber(value), 10, theme.Accent, Enum.Font.GothamBold)
    valueLabel.Position = UDim2.new(1, -62, 0, 0)
    valueLabel.Size = UDim2.fromOffset(60, 22)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local track = make("Frame", {
        Position = UDim2.fromOffset(1, 34),
        Size = UDim2.new(1, -2, 0, 6),
        BackgroundColor3 = theme.SurfaceHover,
        BorderSizePixel = 0,
    }, row)
    corner(track, 8)
    local ratio = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
    local fill = make("Frame", {
        Size = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 8)
    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(ratio, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = theme.Text,
        BorderSizePixel = 0,
    }, track)
    corner(knob, 20)
    stroke(knob, theme.Accent, 0, 2)

    local hitbox = make("TextButton", {
        Position = UDim2.fromOffset(-5, 24),
        Size = UDim2.new(1, 10, 0, 26),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local dragging = false
    local control = { _kind = "Slider", _value = value, Instance = row }
    local function updateFromX(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        control:SetValue(minimum + (maximum - minimum) * alpha)
    end
    function control:SetValue(nextValue, silent)
        self._value = normalize(nextValue)
        local currentRatio = maximum == minimum and 0 or (self._value - minimum) / (maximum - minimum)
        valueLabel.Text = formatNumber(self._value)
        tween(fill, 0.08, { Size = UDim2.new(currentRatio, 0, 1, 0) })
        tween(knob, 0.08, { Position = UDim2.new(currentRatio, 0, 0.5, 0) })
        if not silent then
            safeCall(callback, self._value)
        end
    end
    function control:GetValue()
        return self._value
    end

    addConnection(self._window, hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    addConnection(self._window, UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    addConnection(self._window, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    addControl(self, control)
    return control
end

function SectionMethods:CreateDropdown(text, options, default, callback)
    local theme = self._window._theme
    options = type(options) == "table" and options or {}

    local outer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, self._content)

    local label = makeText(outer, text or "Dropdown", 11, theme.Text, Enum.Font.GothamMedium)
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.fromOffset(1, 0)

    local selectedValue = default
    local selector = make("TextButton", {
        Position = UDim2.fromOffset(0, 23),
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, outer)
    corner(selector, 8)
    local selectedLabel = makeText(selector, selectedValue == nil and "Select an option" or tostring(selectedValue), 10, selectedValue == nil and theme.Muted or theme.Text, Enum.Font.Gotham)
    selectedLabel.Position = UDim2.fromOffset(11, 0)
    selectedLabel.Size = UDim2.new(1, -38, 1, 0)
    local arrow = makeText(selector, "⌄", 16, theme.Muted, Enum.Font.Gotham)
    arrow.Position = UDim2.new(1, -28, 0, 0)
    arrow.Size = UDim2.fromOffset(20, 35)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local optionList = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 63),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        CanvasSize = UDim2.new(),
        Visible = false,
        ClipsDescendants = true,
    }, outer)
    corner(optionList, 8)
    local optionLayout = make("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, optionList)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
    }, optionList)

    local control = { _kind = "Dropdown", _value = selectedValue, Instance = outer }
    local expanded = false
    local function setExpanded(state)
        expanded = state
        optionList.Visible = expanded
        local total = math.min(optionLayout.AbsoluteContentSize.Y + 10, 132)
        optionList.Size = UDim2.new(1, 0, 0, expanded and total or 0)
        outer.Size = UDim2.new(1, 0, 0, expanded and (63 + total) or 62)
        arrow.Text = expanded and "⌃" or "⌄"
    end

    local function addOption(option)
        local optionText = tostring(option)
        local optionButton = make("TextButton", {
            Size = UDim2.new(1, -2, 0, 29),
            BackgroundColor3 = theme.SurfaceAlt,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = optionText,
            TextColor3 = theme.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        }, optionList)
        corner(optionButton, 6)
        make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, optionButton)
        addConnection(self._window, optionButton.MouseEnter, function()
            tween(optionButton, 0.1, {
                BackgroundTransparency = 0,
                BackgroundColor3 = theme.SurfaceHover,
                TextColor3 = theme.Text,
            })
        end)
        addConnection(self._window, optionButton.MouseLeave, function()
            tween(optionButton, 0.1, {
                BackgroundTransparency = 1,
                TextColor3 = theme.Muted,
            })
        end)
        addConnection(self._window, optionButton.Activated, function()
            control:SetValue(option)
            setExpanded(false)
        end)
    end

    for _, option in ipairs(options) do
        addOption(option)
    end
    optionList.CanvasSize = UDim2.fromOffset(0, optionLayout.AbsoluteContentSize.Y + 8)
    addConnection(self._window, optionLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        optionList.CanvasSize = UDim2.fromOffset(0, optionLayout.AbsoluteContentSize.Y + 8)
        if expanded then setExpanded(true) end
    end)

    function control:SetValue(nextValue, silent)
        self._value = nextValue
        selectedLabel.Text = nextValue == nil and "Select an option" or tostring(nextValue)
        selectedLabel.TextColor3 = nextValue == nil and theme.Muted or theme.Text
        if not silent then
            safeCall(callback, nextValue)
        end
    end
    function control:GetValue()
        return self._value
    end
    function control:SetOptions(newOptions)
        for _, child in ipairs(optionList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, option in ipairs(newOptions or {}) do
            addOption(option)
        end
        optionList.CanvasSize = UDim2.fromOffset(0, optionLayout.AbsoluteContentSize.Y + 8)
    end

    addConnection(self._window, selector.Activated, function()
        setExpanded(not expanded)
    end)
    addControl(self, control)
    return control
end

function SectionMethods:CreateInput(text, placeholder, callback)
    local theme = self._window._theme
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 59),
        BackgroundTransparency = 1,
    }, self._content)

    local label = makeText(row, text or "Input", 11, theme.Text, Enum.Font.GothamMedium)
    label.Position = UDim2.fromOffset(1, 0)
    label.Size = UDim2.new(1, 0, 0, 20)

    local box = make("TextBox", {
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder or "Type here...",
        PlaceholderColor3 = theme.Muted,
        Text = "",
        TextColor3 = theme.Text,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    corner(box, 8)
    stroke(box, theme.Border, 0.25, 1)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, box)

    local control = { _kind = "Input", Instance = row, TextBox = box }
    function control:SetValue(value, silent)
        box.Text = tostring(value or "")
        if not silent then safeCall(callback, box.Text, false) end
    end
    function control:GetValue()
        return box.Text
    end

    addConnection(self._window, box.Focused, function()
        tween(box, 0.12, { BackgroundColor3 = theme.SurfaceHover })
    end)
    addConnection(self._window, box.FocusLost, function(enterPressed)
        tween(box, 0.12, { BackgroundColor3 = theme.SurfaceAlt })
        safeCall(callback, box.Text, enterPressed)
    end)
    addControl(self, control)
    return control
end

function SectionMethods:CreateKeybind(text, defaultKey, callback)
    local theme = self._window._theme
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
    }, self._content)
    local label = makeText(row, text or "Keybind", 11, theme.Text, Enum.Font.GothamMedium)
    label.Size = UDim2.new(1, -110, 1, 0)
    label.Position = UDim2.fromOffset(1, 0)

    local keyButton = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(100, 30),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(keyButton, 7)
    local keyLabel = makeText(keyButton, "", 9, theme.Accent, Enum.Font.GothamBold)
    keyLabel.Size = UDim2.fromScale(1, 1)
    keyLabel.TextXAlignment = Enum.TextXAlignment.Center

    local control = {
        _kind = "Keybind",
        _key = typeof(defaultKey) == "EnumItem" and defaultKey or Enum.KeyCode.Unknown,
        _callback = callback,
        Instance = row,
    }
    function control:SetKey(key)
        if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then
            return
        end
        self._key = key
        keyLabel.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
    end
    function control:GetKey()
        return self._key
    end
    control:SetKey(control._key)

    addConnection(self._window, keyButton.Activated, function()
        if self._window._keybindCapture then
            return
        end
        self._window._keybindCapture = control
        keyLabel.Text = "Press a key..."
    end)
    addControl(self, control)
    return control
end

function SectionMethods:CreateLabel(text)
    local theme = self._window._theme
    local label = makeText(self._content, text or "Label", 10, theme.Muted, Enum.Font.Gotham)
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.None
    local control = {
        _kind = "Label",
        Instance = label,
        SetText = function(_, value)
            label.Text = tostring(value or "")
        end,
    }
    return addControl(self, control)
end

function SectionMethods:CreateParagraph(title, body)
    local theme = self._window._theme
    local wrapper = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, self._content)
    local titleLabel = makeText(wrapper, title or "Information", 10, theme.Text, Enum.Font.GothamBold)
    titleLabel.Size = UDim2.new(1, 0, 0, 18)
    titleLabel.Position = UDim2.fromOffset(0, 0)
    local bodyLabel = makeText(wrapper, body or "", 10, theme.Muted, Enum.Font.Gotham)
    bodyLabel.Position = UDim2.fromOffset(0, 20)
    bodyLabel.Size = UDim2.new(1, 0, 0, 0)
    bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
    bodyLabel.TextWrapped = true
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
    bodyLabel.TextTruncate = Enum.TextTruncate.None

    local control = {
        _kind = "Paragraph",
        Instance = wrapper,
        SetTitle = function(_, value) titleLabel.Text = tostring(value or "") end,
        SetText = function(_, value) bodyLabel.Text = tostring(value or "") end,
    }
    return addControl(self, control)
end

function SectionMethods:CreateDivider()
    local theme = self._window._theme
    local line = make("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, self._content)
    return addControl(self, { _kind = "Divider", Instance = line })
end

-- Short aliases make the API comfortable to use in small scripts.
SectionMethods.Button = SectionMethods.CreateButton
SectionMethods.Toggle = SectionMethods.CreateToggle
SectionMethods.Slider = SectionMethods.CreateSlider
SectionMethods.Dropdown = SectionMethods.CreateDropdown
SectionMethods.Input = SectionMethods.CreateInput
SectionMethods.Keybind = SectionMethods.CreateKeybind
SectionMethods.Label = SectionMethods.CreateLabel
SectionMethods.Paragraph = SectionMethods.CreateParagraph
SectionMethods.Divider = SectionMethods.CreateDivider
TabMethods.Section = TabMethods.CreateSection
WindowMethods.Tab = WindowMethods.CreateTab

return Library
