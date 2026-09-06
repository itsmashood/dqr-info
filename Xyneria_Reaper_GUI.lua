-- Xyneria Dungeon Quest interface
-- ReaperX-inspired layout with explicit UI-only hooks for unmapped game remotes.

return function(api)
    assert(type(api) == "table", "Xyneria GUI requires an API table")

    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Lighting = game:GetService("Lighting")
    local GuiService = game:GetService("GuiService")
    local VirtualUser = game:GetService("VirtualUser")

    local player = Players.LocalPlayer
    local env = (getgenv and getgenv()) or _G

    local COLORS = {
        Window = Color3.fromRGB(10, 10, 12),
        Sidebar = Color3.fromRGB(9, 9, 11),
        Panel = Color3.fromRGB(18, 18, 22),
        Row = Color3.fromRGB(15, 15, 18),
        RowHover = Color3.fromRGB(23, 21, 25),
        Input = Color3.fromRGB(17, 17, 20),
        Border = Color3.fromRGB(31, 31, 36),
        Text = Color3.fromRGB(232, 232, 236),
        Muted = Color3.fromRGB(151, 151, 160),
        Faint = Color3.fromRGB(92, 92, 100),
        Red = Color3.fromRGB(245, 48, 58),
        RedDark = Color3.fromRGB(110, 0, 7),
        RedSoft = Color3.fromRGB(55, 13, 18),
        Green = Color3.fromRGB(88, 220, 75),
        Yellow = Color3.fromRGB(226, 217, 52),
        White = Color3.fromRGB(255, 255, 255)
    }

    local connections = {}
    local utilityConnections = {}
    local destroyed = false

    local function connect(signal, callback, bucket)
        local connection = signal:Connect(callback)
        table.insert(bucket or connections, connection)
        return connection
    end

    local function disconnectBucket(bucket)
        for _, connection in ipairs(bucket) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        table.clear(bucket)
    end

    local function create(className, properties, parent)
        local object = Instance.new(className)

        for property, value in pairs(properties or {}) do
            object[property] = value
        end

        object.Parent = parent
        return object
    end

    local function addCorner(object, radius)
        return create("UICorner", {
            CornerRadius = UDim.new(0, radius or 4)
        }, object)
    end

    local function addStroke(object, color, thickness, transparency)
        return create("UIStroke", {
            Color = color or COLORS.Border,
            Thickness = thickness or 1,
            Transparency = transparency or 0
        }, object)
    end

    local function addPadding(object, left, right, top, bottom)
        return create("UIPadding", {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or left or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or top or 0)
        }, object)
    end

    local function addList(object, padding)
        return create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, padding or 6)
        }, object)
    end

    local function tween(object, properties, duration)
        local animation = TweenService:Create(
            object,
            TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
        animation:Play()
        return animation
    end

    local parent = nil
    pcall(function()
        local getHui = rawget(env, "gethui") or rawget(_G, "gethui")
        parent = getHui and getHui() or nil
    end)
    parent = parent or game:GetService("CoreGui")

    pcall(function()
        local old = parent:FindFirstChild("XyneriaDQR")
        if old then
            old:Destroy()
        end
    end)

    local screen = create("ScreenGui", {
        Name = "XyneriaDQR",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, parent)

    pcall(function()
        local syn = rawget(env, "syn")
        if syn and syn.protect_gui then
            syn.protect_gui(screen)
        end
    end)

    local main = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(820, 590),
        BackgroundColor3 = COLORS.Window,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Active = true
    }, screen)
    addCorner(main, 5)
    addStroke(main, Color3.fromRGB(22, 22, 26), 1, 0)

    local scale = create("UIScale", {
        Scale = 1
    }, main)

    local function updateScale()
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min(viewport.X / 850, viewport.Y / 620), 0.68, 1)
    end
    updateScale()

    if Workspace.CurrentCamera then
        connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 188, 1, 0),
        BackgroundColor3 = COLORS.Sidebar,
        BorderSizePixel = 0
    }, main)
    addCorner(sidebar, 5)

    create("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Color3.fromRGB(20, 20, 24),
        BorderSizePixel = 0
    }, sidebar)

    local sidebarScroll = create("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, sidebar)
    addPadding(sidebarScroll, 10, 10, 4, 8)
    addList(sidebarScroll, 5)

    local hotkeyHint = create("TextLabel", {
        Position = UDim2.new(0, 14, 1, -26),
        Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1,
        Text = "RightShift  •  show / hide",
        TextColor3 = COLORS.Faint,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left
    }, sidebar)

    local header = create("Frame", {
        Name = "Header",
        Position = UDim2.fromOffset(188, 0),
        Size = UDim2.new(1, -188, 0, 58),
        BackgroundColor3 = COLORS.Window,
        BorderSizePixel = 0,
        Active = true
    }, main)

    local brandIcon = create("TextLabel", {
        Position = UDim2.fromOffset(16, 11),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        Text = "⚔",
        TextColor3 = COLORS.Red,
        TextSize = 24,
        Font = Enum.Font.GothamBold
    }, header)

    local brandTitle = create("TextLabel", {
        Position = UDim2.fromOffset(50, 10),
        Size = UDim2.new(1, -190, 0, 20),
        BackgroundTransparency = 1,
        Text = tostring(api.Title or "Xyneria (Made by Radia)"),
        TextColor3 = COLORS.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, header)

    local brandSubtitle = create("TextLabel", {
        Position = UDim2.fromOffset(50, 29),
        Size = UDim2.new(1, -190, 0, 17),
        BackgroundTransparency = 1,
        Text = tostring(api.Subtitle or "Dungeon Quest"),
        TextColor3 = COLORS.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, header)

    local function headerButton(textValue, order)
        local button = create("TextButton", {
            Position = UDim2.new(1, -(42 * order), 0, 10),
            Size = UDim2.fromOffset(34, 34),
            BackgroundColor3 = Color3.fromRGB(14, 14, 17),
            BorderSizePixel = 0,
            Text = textValue,
            TextColor3 = COLORS.Muted,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false
        }, header)
        addCorner(button, 6)
        connect(button.MouseEnter, function()
            tween(button, {BackgroundColor3 = COLORS.RowHover, TextColor3 = COLORS.Text})
        end)
        connect(button.MouseLeave, function()
            tween(button, {BackgroundColor3 = Color3.fromRGB(14, 14, 17), TextColor3 = COLORS.Muted})
        end)
        return button
    end

    local settingsButton = headerButton("⚙", 3)
    local searchButton = headerButton("⌕", 2)
    local closeButton = headerButton("×", 1)

    local searchBox = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -132, 0, 10),
        Size = UDim2.fromOffset(230, 34),
        BackgroundColor3 = COLORS.Input,
        BorderSizePixel = 0,
        PlaceholderText = "Search this page...",
        PlaceholderColor3 = COLORS.Faint,
        Text = "",
        TextColor3 = COLORS.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false
    }, header)
    addCorner(searchBox, 6)
    addStroke(searchBox, COLORS.Border, 1, 0)
    addPadding(searchBox, 10, 10, 0, 0)

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(188, 58),
        Size = UDim2.new(1, -188, 1, -58),
        BackgroundTransparency = 1,
        ClipsDescendants = true
    }, main)

    local reopen = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(54, 54),
        BackgroundColor3 = COLORS.RedDark,
        BorderSizePixel = 0,
        Text = "DQ",
        TextColor3 = COLORS.White,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        Visible = false,
        AutoButtonColor = false
    }, screen)
    addCorner(reopen, 27)
    addStroke(reopen, COLORS.Red, 2, 0.12)

    local toastHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(310, 250),
        BackgroundTransparency = 1
    }, screen)
    local toastList = addList(toastHolder, 7)
    toastList.VerticalAlignment = Enum.VerticalAlignment.Bottom

    local function notify(titleText, message, kind)
        if destroyed then
            return
        end

        local color = kind == "success" and COLORS.Green
            or kind == "warning" and COLORS.Yellow
            or kind == "error" and COLORS.Red
            or COLORS.Red

        local toast = create("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            BackgroundTransparency = 0.03
        }, toastHolder)
        addCorner(toast, 6)
        addStroke(toast, COLORS.Border, 1, 0)

        create("Frame", {
            Size = UDim2.fromOffset(3, 62),
            BackgroundColor3 = color,
            BorderSizePixel = 0
        }, toast)

        create("TextLabel", {
            Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(1, -22, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(titleText or "Xyneria"),
            TextColor3 = COLORS.Text,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, toast)

        create("TextLabel", {
            Position = UDim2.fromOffset(12, 27),
            Size = UDim2.new(1, -22, 0, 28),
            BackgroundTransparency = 1,
            Text = tostring(message or ""),
            TextColor3 = COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top
        }, toast)

        toast.Position = UDim2.fromOffset(330, 0)
        tween(toast, {Position = UDim2.fromOffset(0, 0)}, 0.18)

        task.delay(4, function()
            if toast and toast.Parent then
                tween(toast, {
                    Position = UDim2.fromOffset(330, 0),
                    BackgroundTransparency = 1
                }, 0.18)
                task.wait(0.2)
                if toast and toast.Parent then
                    toast:Destroy()
                end
            end
        end)
    end

    local function setWindowVisible(value)
        main.Visible = value
        reopen.Visible = not value
    end

    connect(closeButton.Activated, function()
        setWindowVisible(false)
    end)
    connect(reopen.Activated, function()
        setWindowVisible(true)
    end)
    connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            setWindowVisible(not main.Visible)
        end
    end)

    local dragging = false
    local dragStart = nil
    local startPosition = nil

    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = (input.Position - dragStart) / scale.Scale
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local resizeHandle = create("TextButton", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(22, 22),
        BackgroundTransparency = 1,
        Text = "◢",
        TextColor3 = COLORS.Muted,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false
    }, main)

    local resizing = false
    local resizeStart = nil
    local startSize = nil

    connect(resizeHandle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = main.AbsoluteSize / scale.Scale
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if resizing and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = (input.Position - resizeStart) / scale.Scale
            main.Size = UDim2.fromOffset(
                math.clamp(startSize.X + delta.X, 720, 1000),
                math.clamp(startSize.Y + delta.Y, 500, 720)
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)

    local values = {}
    for key, value in pairs(api.Initial or {}) do
        values[key] = value
    end

    local controls = {}
    local localHandlers = {}
    local localSupported = {
        WhiteScreen = true,
        LowQuality = true,
        FPSLock = true,
        FPSLimit = true,
        StreamerMode = true,
        AntiAFK = true,
        AutoRejoin = true,
        WebhookEnabled = true,
        WebhookURL = true,
        ServerBrowser = true,
        ServerMaxPlayers = true,
        ServerCode = true,
        ConfigAutoLoad = true
    }

    local function isSupported(key)
        return key == nil
            or localSupported[key] == true
            or (api.Supported and api.Supported[key] == true)
    end

    local function registerControl(key, control, default)
        if values[key] == nil then
            values[key] = default
        end
        controls[key] = controls[key] or {}
        table.insert(controls[key], control)
        control:_render(values[key])
        return control
    end

    local function applyValue(key, value, source, userInitiated)
        values[key] = value

        for _, control in ipairs(controls[key] or {}) do
            if control ~= source then
                control:_render(value)
            end
        end

        local ok = true
        local accepted = true
        local detail = nil

        if localHandlers[key] then
            ok, detail = pcall(localHandlers[key], value)
            accepted = ok
        elseif api.Set then
            ok, accepted, detail = pcall(api.Set, key, value)
        end

        if userInitiated and (not ok or accepted == false) then
            notify(
                "UI control ready",
                tostring(detail or "The game remote for this control has not been mapped yet."),
                "warning"
            )
        end

        return ok and accepted ~= false
    end

    local pages = {}
    local pageButtons = {}
    local searchItems = {}
    local currentPageName = nil
    local buildingPageName = nil

    local function registerSearch(object, textValue)
        if not buildingPageName then
            return
        end
        searchItems[buildingPageName] = searchItems[buildingPageName] or {}
        table.insert(searchItems[buildingPageName], {
            Object = object,
            Text = string.lower(tostring(textValue or ""))
        })
    end

    local function makeScroll(parentFrame, position, size)
        local scrolling = create("ScrollingFrame", {
            Position = position,
            Size = size,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.Red,
            ScrollingDirection = Enum.ScrollingDirection.Y
        }, parentFrame)
        addPadding(scrolling, 7, 7, 7, 12)
        addList(scrolling, 10)
        return scrolling
    end

    local function makePage(name)
        local page = create("Frame", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false
        }, content)

        local left = makeScroll(
            page,
            UDim2.fromOffset(0, 0),
            UDim2.new(0.5, -3, 1, 0)
        )

        local right = makeScroll(
            page,
            UDim2.new(0.5, 3, 0, 0),
            UDim2.new(0.5, -3, 1, 0)
        )

        pages[name] = {
            Root = page,
            Left = left,
            Right = right
        }
        return pages[name]
    end

    local function addUiTag(parentObject)
        local tag = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -30, 0.5, 0),
            Size = UDim2.fromOffset(25, 15),
            BackgroundColor3 = COLORS.RedSoft,
            BorderSizePixel = 0,
            Text = "UI",
            TextColor3 = Color3.fromRGB(255, 121, 127),
            TextSize = 9,
            Font = Enum.Font.GothamBold
        }, parentObject)
        addCorner(tag, 4)
        return tag
    end

    local function makeSwitch(parentObject, key, default)
        local button = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(23, 14),
            BackgroundColor3 = COLORS.Red,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false
        }, parentObject)
        addCorner(button, 7)

        local knob = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, -7, 0.5, 0),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = COLORS.White,
            BorderSizePixel = 0
        }, button)
        addCorner(knob, 4)

        local control = {}
        function control:_render(value)
            local enabled = value == true
            tween(button, {
                BackgroundColor3 = enabled and COLORS.Red or Color3.fromRGB(31, 31, 36)
            }, 0.11)
            tween(knob, {
                Position = enabled and UDim2.new(1, -7, 0.5, 0)
                    or UDim2.new(0, 7, 0.5, 0)
            }, 0.11)
        end
        function control:Set(value, userInitiated)
            self:_render(value == true)
            applyValue(key, value == true, self, userInitiated == true)
        end
        function control:Get()
            return values[key] == true
        end

        registerControl(key, control, default == true)
        connect(button.Activated, function()
            control:Set(not control:Get(), true)
        end)
        return control
    end

    local function addSection(parentObject, titleText, description, icon, key, default)
        local group = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1
        }, parentObject)
        addList(group, 7)
        registerSearch(group, titleText .. " " .. tostring(description or ""))

        local sectionHeader = create("Frame", {
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0
        }, group)
        addCorner(sectionHeader, 3)

        create("TextLabel", {
            Position = UDim2.fromOffset(10, 8),
            Size = UDim2.fromOffset(30, 36),
            BackgroundTransparency = 1,
            Text = tostring(icon or "»"),
            TextColor3 = COLORS.Red,
            TextSize = 19,
            Font = Enum.Font.GothamBold
        }, sectionHeader)

        create("TextLabel", {
            Position = UDim2.fromOffset(43, 8),
            Size = UDim2.new(1, -86, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(titleText),
            TextColor3 = COLORS.Text,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, sectionHeader)

        create("TextLabel", {
            Position = UDim2.fromOffset(43, 25),
            Size = UDim2.new(1, -86, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(description or ""),
            TextColor3 = COLORS.Muted,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, sectionHeader)

        if key then
            if not isSupported(key) then
                addUiTag(sectionHeader)
            end
            makeSwitch(sectionHeader, key, default)
        end

        local body = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1
        }, group)
        addList(body, 6)
        return body, group
    end

    local function addToggle(parentObject, key, titleText, description, default)
        local height = description and 45 or 34
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = COLORS.Row,
            BorderSizePixel = 0
        }, parentObject)
        addCorner(row, 3)
        registerSearch(row, titleText .. " " .. tostring(description or ""))

        create("Frame", {
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(0, 2, 1, -12),
            BackgroundColor3 = COLORS.RedDark,
            BorderSizePixel = 0
        }, row)

        create("TextLabel", {
            Position = UDim2.fromOffset(10, description and 7 or 0),
            Size = UDim2.new(1, -52, 0, description and 17 or height),
            BackgroundTransparency = 1,
            Text = tostring(titleText),
            TextColor3 = description and COLORS.Text or COLORS.Muted,
            TextSize = 11,
            Font = description and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)

        if description then
            create("TextLabel", {
                Position = UDim2.fromOffset(10, 23),
                Size = UDim2.new(1, -52, 0, 15),
                BackgroundTransparency = 1,
                Text = tostring(description),
                TextColor3 = COLORS.Muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)
        end

        local check = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -9, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.fromRGB(27, 27, 31),
            BorderSizePixel = 0,
            Text = "",
            TextColor3 = COLORS.White,
            TextSize = 12,
            Font = Enum.Font.GothamBold
        }, row)
        addCorner(check, 3)

        if not isSupported(key) then
            addUiTag(row)
        end

        local hitbox = create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false
        }, row)

        local control = {}
        function control:_render(value)
            local enabled = value == true
            check.BackgroundColor3 = enabled and COLORS.Red or Color3.fromRGB(27, 27, 31)
            check.Text = enabled and "✓" or ""
        end
        function control:Set(value, userInitiated)
            self:_render(value == true)
            applyValue(key, value == true, self, userInitiated == true)
        end
        function control:Get()
            return values[key] == true
        end

        registerControl(key, control, default == true)
        connect(hitbox.Activated, function()
            control:Set(not control:Get(), true)
        end)
        connect(hitbox.MouseEnter, function()
            tween(row, {BackgroundColor3 = COLORS.RowHover})
        end)
        connect(hitbox.MouseLeave, function()
            tween(row, {BackgroundColor3 = COLORS.Row})
        end)
        return control
    end

    local function addParagraph(parentObject, textValue, color)
        local label = create("TextLabel", {
            Size = UDim2.new(1, -12, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = tostring(textValue),
            TextColor3 = color or COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top
        }, parentObject)
        addPadding(label, 10, 3, 2, 2)
        registerSearch(label, textValue)
        return label
    end

    local function addStatus(parentObject, textValue, color)
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = COLORS.Row,
            BorderSizePixel = 0
        }, parentObject)
        addCorner(row, 3)
        local label = create("TextLabel", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(textValue),
            TextColor3 = color or COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)
        registerSearch(row, textValue)
        return label
    end

    local function addButton(parentObject, titleText, callback, options)
        options = options or {}
        local button = create("TextButton", {
            Size = UDim2.new(1, 0, 0, options.Height or 36),
            BackgroundColor3 = options.Danger and COLORS.Red or COLORS.Row,
            BorderSizePixel = 0,
            Text = tostring(titleText),
            TextColor3 = options.Danger and COLORS.White or COLORS.Muted,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            AutoButtonColor = false
        }, parentObject)
        addCorner(button, 3)
        registerSearch(button, titleText)

        if options.Supported == false then
            addUiTag(button)
        end

        connect(button.MouseEnter, function()
            tween(button, {
                BackgroundColor3 = options.Danger and Color3.fromRGB(255, 66, 74) or COLORS.RowHover,
                TextColor3 = COLORS.White
            })
        end)
        connect(button.MouseLeave, function()
            tween(button, {
                BackgroundColor3 = options.Danger and COLORS.Red or COLORS.Row,
                TextColor3 = options.Danger and COLORS.White or COLORS.Muted
            })
        end)
        connect(button.Activated, function()
            local ok, accepted, detail = pcall(callback or function()
                return false
            end)
            if not ok or accepted == false then
                notify(
                    options.UnsupportedTitle or "UI control ready",
                    tostring(detail or accepted or "The game remote for this button has not been mapped yet."),
                    "warning"
                )
            end
        end)
        return button
    end

    local function addInput(parentObject, key, placeholder, default, secret)
        local box = create("TextBox", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = COLORS.Input,
            BorderSizePixel = 0,
            PlaceholderText = tostring(placeholder or ""),
            PlaceholderColor3 = COLORS.Faint,
            Text = tostring(values[key] or default or ""),
            TextColor3 = COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false
        }, parentObject)
        addCorner(box, 3)
        addPadding(box, 10, 10, 0, 0)
        registerSearch(box, placeholder)

        local control = {}
        function control:_render(value)
            if not box:IsFocused() then
                box.Text = tostring(value or "")
            end
        end
        function control:Set(value, userInitiated)
            self:_render(value)
            applyValue(key, tostring(value or ""), self, userInitiated == true)
        end
        function control:Get()
            return tostring(values[key] or "")
        end

        registerControl(key, control, tostring(default or ""))
        connect(box.FocusLost, function()
            control:Set(box.Text, true)
        end)

        if secret then
            box:SetAttribute("SensitiveValue", true)
        end
        return box, control
    end

    local openDropdown = nil

    local function addDropdown(parentObject, key, titleText, options, default)
        options = options or {}
        local maxVisible = math.min(#options, 6)
        local menuHeight = maxVisible * 28 + 4

        local holder = create("Frame", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundTransparency = 1,
            ClipsDescendants = true
        }, parentObject)
        registerSearch(holder, titleText .. " " .. table.concat(options, " "))

        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = COLORS.Row,
            BorderSizePixel = 0
        }, holder)
        addCorner(row, 3)

        create("Frame", {
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(0, 2, 1, -12),
            BackgroundColor3 = COLORS.RedDark,
            BorderSizePixel = 0
        }, row)

        create("TextLabel", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(0.42, -10, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(titleText),
            TextColor3 = COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)

        local selector = create("TextButton", {
            Position = UDim2.new(0.42, 0, 0, 5),
            Size = UDim2.new(0.58, -7, 1, -10),
            BackgroundColor3 = Color3.fromRGB(26, 26, 30),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false
        }, row)
        addCorner(selector, 3)

        local selectedLabel = create("TextLabel", {
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -28, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, selector)

        create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -7, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            Text = "⌄",
            TextColor3 = COLORS.Faint,
            TextSize = 12,
            Font = Enum.Font.GothamBold
        }, selector)

        if not isSupported(key) then
            addUiTag(row)
            selector.Size = UDim2.new(0.58, -39, 1, -10)
        end

        local menu = create("ScrollingFrame", {
            Position = UDim2.fromOffset(0, 39),
            Size = UDim2.new(1, 0, 0, menuHeight),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.Red,
            CanvasSize = UDim2.fromOffset(0, #options * 28),
            Visible = false
        }, holder)
        addCorner(menu, 3)
        addStroke(menu, COLORS.Border, 1, 0)
        local optionLayout = addList(menu, 0)
        optionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local control = {
            Open = false
        }

        function control:_render(value)
            selectedLabel.Text = tostring(value or "")
        end

        function control:Set(value, userInitiated)
            self:_render(value)
            applyValue(key, value, self, userInitiated == true)
        end

        function control:Get()
            return values[key]
        end

        function control:Close()
            self.Open = false
            menu.Visible = false
            holder.Size = UDim2.new(1, 0, 0, 35)
            if openDropdown == self then
                openDropdown = nil
            end
        end

        function control:OpenMenu()
            if openDropdown and openDropdown ~= self then
                openDropdown:Close()
            end
            self.Open = true
            openDropdown = self
            menu.Visible = true
            holder.Size = UDim2.new(1, 0, 0, 39 + menuHeight)
        end

        registerControl(key, control, default or options[1] or "")

        for _, option in ipairs(options) do
            local optionButton = create("TextButton", {
                Size = UDim2.new(1, -4, 0, 28),
                BackgroundColor3 = COLORS.Panel,
                BorderSizePixel = 0,
                Text = "  " .. tostring(option),
                TextColor3 = COLORS.Muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false
            }, menu)
            connect(optionButton.MouseEnter, function()
                optionButton.BackgroundColor3 = COLORS.RowHover
                optionButton.TextColor3 = COLORS.Text
            end)
            connect(optionButton.MouseLeave, function()
                optionButton.BackgroundColor3 = COLORS.Panel
                optionButton.TextColor3 = COLORS.Muted
            end)
            connect(optionButton.Activated, function()
                control:Set(option, true)
                control:Close()
            end)
        end

        connect(selector.Activated, function()
            if control.Open then
                control:Close()
            else
                control:OpenMenu()
            end
        end)
        return control
    end

    local function addSlider(parentObject, key, titleText, minimum, maximum, default, step, suffix)
        minimum = tonumber(minimum) or 0
        maximum = tonumber(maximum) or 100
        step = tonumber(step) or 1

        local holder = create("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundColor3 = COLORS.Row,
            BorderSizePixel = 0
        }, parentObject)
        addCorner(holder, 3)
        registerSearch(holder, titleText)

        create("Frame", {
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.new(0, 2, 1, -14),
            BackgroundColor3 = COLORS.Red,
            BorderSizePixel = 0
        }, holder)

        create("TextLabel", {
            Position = UDim2.fromOffset(10, 4),
            Size = UDim2.new(0.65, -10, 0, 22),
            BackgroundTransparency = 1,
            Text = tostring(titleText),
            TextColor3 = COLORS.Text,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, holder)

        local valueLabel = create("TextLabel", {
            Position = UDim2.new(0.65, 0, 0, 4),
            Size = UDim2.new(0.35, -10, 0, 22),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Right
        }, holder)

        local minus = create("TextButton", {
            Position = UDim2.fromOffset(9, 31),
            Size = UDim2.fromOffset(18, 22),
            BackgroundTransparency = 1,
            Text = "-",
            TextColor3 = COLORS.Muted,
            TextSize = 12,
            Font = Enum.Font.GothamBold
        }, holder)

        local plus = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 31),
            Size = UDim2.fromOffset(18, 22),
            BackgroundTransparency = 1,
            Text = "+",
            TextColor3 = COLORS.Muted,
            TextSize = 12,
            Font = Enum.Font.GothamBold
        }, holder)

        local bar = create("Frame", {
            Position = UDim2.fromOffset(30, 40),
            Size = UDim2.new(1, -60, 0, 5),
            BackgroundColor3 = Color3.fromRGB(27, 27, 31),
            BorderSizePixel = 0
        }, holder)
        addCorner(bar, 3)

        local fill = create("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = COLORS.Red,
            BorderSizePixel = 0
        }, bar)
        addCorner(fill, 3)

        local knob = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = Color3.fromRGB(192, 192, 198),
            BorderSizePixel = 0
        }, bar)
        addCorner(knob, 3)

        if not isSupported(key) then
            addUiTag(holder)
        end

        local control = {}
        function control:_normalize(value)
            value = math.clamp(tonumber(value) or minimum, minimum, maximum)
            value = math.floor(((value - minimum) / step) + 0.5) * step + minimum
            return math.clamp(value, minimum, maximum)
        end
        function control:_render(value)
            value = self:_normalize(value)
            local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            local display = math.floor(value) == value and tostring(math.floor(value))
                or string.format("%.1f", value)
            valueLabel.Text = display .. tostring(suffix or "")
        end
        function control:Set(value, userInitiated)
            value = self:_normalize(value)
            self:_render(value)
            applyValue(key, value, self, userInitiated == true)
        end
        function control:Get()
            return self:_normalize(values[key])
        end

        registerControl(key, control, default)

        local sliding = false
        local function updateFromPosition(x)
            local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            control:Set(minimum + (maximum - minimum) * alpha, true)
        end

        connect(bar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                updateFromPosition(input.Position.X)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if sliding and (
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            ) then
                updateFromPosition(input.Position.X)
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end)
        connect(minus.Activated, function()
            control:Set(control:Get() - step, true)
        end)
        connect(plus.Activated, function()
            control:Set(control:Get() + step, true)
        end)
        return control
    end

    local function addListBox(parentObject, height)
        local listFrame = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, height or 120),
            BackgroundColor3 = COLORS.Row,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.Red
        }, parentObject)
        addCorner(listFrame, 3)
        addPadding(listFrame, 4, 4, 4, 4)
        addList(listFrame, 3)
        return listFrame
    end

    local function clearListBox(listFrame)
        for _, child in ipairs(listFrame:GetChildren()) do
            if not child:IsA("UIListLayout")
                and not child:IsA("UIPadding")
                and not child:IsA("UICorner") then
                child:Destroy()
            end
        end
    end

    local function callAction(name, payload)
        if not api.Action then
            return false, "No action bridge is available."
        end
        return api.Action(name, payload)
    end

    local qualityBackup = setmetatable({}, {__mode = "k"})
    local lightingBackup = nil

    local function applyLowQuality(enabled)
        if enabled then
            lightingBackup = lightingBackup or {
                GlobalShadows = Lighting.GlobalShadows,
                EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
                EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
            }
            Lighting.GlobalShadows = false
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0

            for _, object in ipairs(Workspace:GetDescendants()) do
                if object:IsA("BasePart") then
                    if not qualityBackup[object] then
                        qualityBackup[object] = {Material = object.Material}
                    end
                    object.Material = Enum.Material.SmoothPlastic
                elseif object:IsA("ParticleEmitter")
                    or object:IsA("Trail")
                    or object:IsA("Beam") then
                    if not qualityBackup[object] then
                        qualityBackup[object] = {Enabled = object.Enabled}
                    end
                    object.Enabled = false
                end
            end
        else
            for object, backup in pairs(qualityBackup) do
                if object and object.Parent then
                    for property, value in pairs(backup) do
                        pcall(function()
                            object[property] = value
                        end)
                    end
                end
                qualityBackup[object] = nil
            end
            if lightingBackup then
                for property, value in pairs(lightingBackup) do
                    pcall(function()
                        Lighting[property] = value
                    end)
                end
                lightingBackup = nil
            end
        end
    end

    local function applyStreamerMode(enabled)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid:GetAttribute("XyneriaOldDisplayDistanceType") == nil then
                humanoid:SetAttribute(
                    "XyneriaOldDisplayDistanceType",
                    humanoid.DisplayDistanceType.Name
                )
            end
            humanoid.DisplayDistanceType = enabled
                and Enum.HumanoidDisplayDistanceType.None
                or Enum.HumanoidDisplayDistanceType.Viewer
        end
    end

    localHandlers.WhiteScreen = function(enabled)
        RunService:Set3dRenderingEnabled(not enabled)
    end

    localHandlers.LowQuality = applyLowQuality

    localHandlers.FPSLock = function(enabled)
        local setCap = rawget(env, "setfpscap") or rawget(_G, "setfpscap")
        if not setCap then
            error("This executor does not expose setfpscap.")
        end
        setCap(enabled and tonumber(values.FPSLimit or 60) or 999)
    end

    localHandlers.FPSLimit = function(limit)
        if values.FPSLock then
            local setCap = rawget(env, "setfpscap") or rawget(_G, "setfpscap")
            if setCap then
                setCap(tonumber(limit) or 60)
            end
        end
    end

    localHandlers.StreamerMode = applyStreamerMode

    localHandlers.AntiAFK = function(enabled)
        disconnectBucket(utilityConnections)
        if enabled then
            connect(player.Idled, function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end, utilityConnections)
        end
    end

    localHandlers.AutoRejoin = function()
        -- The persistent listener below reads the current toggle value.
    end

    localHandlers.WebhookEnabled = function() end
    localHandlers.WebhookURL = function() end
    localHandlers.ServerMaxPlayers = function() end
    localHandlers.ServerCode = function() end
    localHandlers.ConfigAutoLoad = function() end

    connect(player.CharacterAdded, function()
        task.wait(0.2)
        if values.StreamerMode then
            applyStreamerMode(true)
        end
    end)

    connect(GuiService.ErrorMessageChanged, function(message)
        if not values.AutoRejoin or tostring(message or "") == "" then
            return
        end
        task.delay(2, function()
            if values.AutoRejoin and not destroyed then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                end)
            end
        end)
    end)

    local function getRequestFunction()
        local syn = rawget(env, "syn")
        return rawget(env, "request")
            or rawget(env, "http_request")
            or (syn and syn.request)
            or rawget(_G, "request")
            or rawget(_G, "http_request")
    end

    local function sendWebhook(titleText, description)
        local url = tostring(values.WebhookURL or "")
        if url == "" then
            return false, "Enter a webhook URL first."
        end

        local requestFunction = getRequestFunction()
        if not requestFunction then
            return false, "This executor does not expose an HTTP request function."
        end

        local statusCode = nil
        local ok, response = pcall(requestFunction, {
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                username = "Xyneria",
                embeds = {{
                    title = tostring(titleText),
                    description = tostring(description),
                    color = 16068666,
                    footer = {
                        text = "Xyneria Dungeon Quest"
                    }
                }}
            })
        })

        if type(response) == "table" then
            statusCode = response.StatusCode or response.Status
        end

        if not ok or (statusCode and statusCode >= 400) then
            return false, "Webhook request failed" .. (statusCode and " (" .. statusCode .. ")" or ".")
        end

        return true
    end

    local dungeonOptions = api.Dungeons or {
        "Egg Island",
        "Desert Temple",
        "Winter Outpost",
        "Pirate Island",
        "King's Castle",
        "The Underworld",
        "Samurai Palace",
        "The Canals",
        "Ghastly Harbor",
        "Steampunk Sewers",
        "Orbital Outpost",
        "Volcanic Chambers",
        "Aquatic Temple",
        "Enchanted Forest",
        "Northern Lands",
        "Gilded Skies"
    }

    local difficultyOptions = api.Difficulties or {"Insane", "Nightmare"}
    local rarityOptions = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}
    local categoryOptions = {"Weapons", "Armors", "Skills", "Helmets"}
    local raidTierOptions = {"Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5"}

    local autoFarm = makePage("Auto Farm")
    buildingPageName = "Auto Farm"

    local combatBody = addSection(autoFarm.Left, "Combat", "Dungeon Farming", "⚔", "AutoFarm", values.AutoFarm ~= false)
    addToggle(combatBody, "AutoFarm", "Auto Farm", nil, values.AutoFarm ~= false)
    addToggle(combatBody, "AutoAttack", "Auto Attack", nil, false)

    local abilitiesBody = addSection(autoFarm.Left, "Abilities", "Skill automation", "☆", "AutoSkills", values.AutoSkills ~= false)
    addParagraph(abilitiesBody, "This function will use Buff skill first before use another skill.")
    addToggle(abilitiesBody, "AutoSkills", "Auto Skills", nil, values.AutoSkills ~= false)
    addSlider(
        abilitiesBody,
        "AttackRange",
        "Attack Range",
        tonumber(api.MinimumAttackRange) or 39,
        80,
        tonumber(values.AttackRange) or 48,
        1,
        " Studs"
    )
    addToggle(abilitiesBody, "SpamSpells", "Spam Spells", "Retry ready Q/E inputs immediately", values.SpamSpells == true)
    addButton(abilitiesBody, "Cast Q + E Now", function()
        return callAction("CastBoth")
    end, {Supported = true})

    local restartBody = addSection(autoFarm.Left, "Auto Restart", "Restart game after seconds.", "↻", "AutoRestart", false)
    addToggle(restartBody, "AutoRestart", "Auto Restart", nil, false)
    addSlider(restartBody, "RestartInterval", "Restart Interval", 5, 120, 30, 5, "/s")

    local pathBody = addSection(autoFarm.Left, "Pathfinding", "Navigation and hazard avoidance", "⌁", "AdaptiveModel", values.AdaptiveModel == true)
    addToggle(pathBody, "WallsNoclip", "Walls-only Noclip", "Floors and platforms remain solid", values.WallsNoclip ~= false)
    addToggle(pathBody, "AdaptiveModel", "Adaptive Model", "Utility AI chooses movement and spell timing", values.AdaptiveModel == true)
    addToggle(pathBody, "AdaptiveBossRange", "Adaptive Boss Casting", "Uses spell reach and boss body size", values.AdaptiveBossRange ~= false)

    local launchBody = addSection(autoFarm.Right, "Launch", "Create a Dungeon", "▷", "AutoStart", values.AutoStart == true)
    addToggle(launchBody, "AutoStart", "Auto Start", nil, values.AutoStart == true)
    addToggle(launchBody, "AutoSelectBestDungeon", "Auto Select Best Dungeon", nil, false)
    addDropdown(
        launchBody,
        "Dungeon",
        "Dungeon",
        dungeonOptions,
        values.Dungeon or dungeonOptions[1]
    )
    addDropdown(
        launchBody,
        "Difficulty",
        "Difficulty",
        difficultyOptions,
        values.Difficulty or difficultyOptions[#difficultyOptions]
    )
    addToggle(launchBody, "Hardcore", "Hardcore", nil, false)

    local loopBody = addSection(
        autoFarm.Right,
        "Loop",
        "Repeat dungeon runs",
        "↻",
        "AutoReplay",
        values.AutoReplay == true
    )
    local replayStatus = addStatus(
        loopBody,
        "↻ Current Replayed: " .. tostring(values.ReplayCount or 0) .. " Times",
        COLORS.Muted
    )
    addToggle(loopBody, "AutoReplay", "Auto Replay", nil, values.AutoReplay == true)
    addToggle(loopBody, "AutoBackLobby", "Auto Back to Lobby", nil, values.AutoBackLobby == true)
    addSlider(
        loopBody,
        "BackToLobbyAfter",
        "Back to Lobby After",
        1,
        30,
        tonumber(values.BackToLobbyAfter) or 5,
        1,
        " Times"
    )

    local liveBody = addSection(autoFarm.Right, "Live Status", "Combat and route telemetry", "◎", nil)
    local liveStatus = addParagraph(liveBody, "Combat Pilot is starting...")

    local autoRaids = makePage("Auto Raids")
    buildingPageName = "Auto Raids"

    local raidCombatBody = addSection(autoRaids.Left, "Combat", "Raid Farming", "⚔", "RaidCombat", false)
    addParagraph(raidCombatBody, "✦ This feature will use settings in Auto Farm tab", COLORS.Green)
    addToggle(raidCombatBody, "RaidAutoFarm", "Auto Farm", nil, false)

    local raidActionBody = addSection(autoRaids.Left, "Action", "Do action after raid ended", "≡", "RaidActionEnabled", false)
    addToggle(raidActionBody, "RaidAutoReady", "Auto Ready", nil, false)
    addToggle(raidActionBody, "RaidAutoReplay", "Auto Replay / Next Tier", nil, false)
    addDropdown(raidActionBody, "RaidAction", "Action", {"Next Tier", "Replay", "Back To Lobby"}, "Next Tier")
    addParagraph(raidActionBody, "Whitelist Party", COLORS.Yellow)
    addParagraph(raidActionBody, "Wait for all players to join before starting the dungeon.")
    addParagraph(raidActionBody, "use , for separate\ne.g. x2Swiftz, ReaperXProHacker")
    local raidPartyInput = addInput(raidActionBody, "RaidPartyUsers", "Enter Username ...", "")

    local raidLaunchBody = addSection(autoRaids.Right, "Launch", "Create a Boss Raids", "▷", "RaidLaunch", false)
    addToggle(raidLaunchBody, "RaidAutoStart", "Auto Start", nil, false)
    addToggle(raidLaunchBody, "RaidAutoLatestTier", "Auto Select Latest Tier", nil, false)
    addDropdown(raidLaunchBody, "RaidTier", "Raid Tier", raidTierOptions, raidTierOptions[1])

    local raidWhitelistBody = addSection(autoRaids.Right, "Whitelist", "Manage player whitelist", "♢", "RaidWhitelist", false)
    local raidWhitelistInput = addInput(raidWhitelistBody, "RaidWhitelistName", "Enter Username...", "")
    addToggle(raidWhitelistBody, "RaidAutoWhitelist", "Auto Whitelist", nil, false)
    addButton(raidWhitelistBody, "Add Player to Whitelist", nil, {Supported = false})
    addButton(raidWhitelistBody, "Remove All Players", nil, {Supported = false})

    local raidAcceptBody = addSection(autoRaids.Right, "Accept Request", "Auto accept join request", "☑", "RaidAcceptEnabled", false)
    local raidAcceptInput = addInput(raidAcceptBody, "RaidAcceptName", "Enter Username...", "")
    addToggle(raidAcceptBody, "RaidAutoAccept", "Auto Accept", nil, false)

    local autoParty = makePage("Auto Party")
    buildingPageName = "Auto Party"

    local partyWhitelist = {}
    local partyWhitelistBody = addSection(autoParty.Left, "Whitelist", "Manage player whitelist", "♢", "PartyWhitelistEnabled", false)
    local partyWhitelistInput = addInput(partyWhitelistBody, "PartyWhitelistName", "Enter Username", "")
    addToggle(partyWhitelistBody, "PartyAutoWhitelist", "Auto Whitelist", nil, false)
    addButton(partyWhitelistBody, "Add Player to Whitelist", function()
        local username = tostring(partyWhitelistInput.Text or ""):match("^%s*(.-)%s*$")
        if username == "" then
            return false, "Enter a username first."
        end
        partyWhitelist[string.lower(username)] = username
        notify("Whitelist", username .. " added locally.", "success")
        return true
    end, {Supported = true})
    addButton(partyWhitelistBody, "Remove All Whitelist", function()
        table.clear(partyWhitelist)
        notify("Whitelist", "Local whitelist cleared.", "success")
        return true
    end, {Danger = true, Supported = true})

    local joinPartyBody = addSection(autoParty.Left, "Join Party", "Auto Join Party", "♙", "JoinPartyEnabled", false)
    local joinPartyInput = addInput(joinPartyBody, "JoinPartyName", "Enter Username", "")
    addToggle(joinPartyBody, "AutoJoinParty", "Auto Join Party", nil, false)

    local startPartyBody = addSection(autoParty.Left, "Start Party / Dungeon", "Auto Start Party & Dungeon", "$", "StartPartyEnabled", false)
    addParagraph(startPartyBody, "Wait for all players to join before starting the dungeon.")

    local sendRequestBody = addSection(autoParty.Right, "Send Join Request", "Auto send join request", "▣", "SendJoinEnabled", false)
    addParagraph(sendRequestBody, "✦ Working with dungeons & boss raids", COLORS.Green)
    local sendJoinInput = addInput(sendRequestBody, "SendJoinName", "Enter username", "")
    addToggle(sendRequestBody, "AutoSendJoinRequest", "Auto Send Join Request", nil, false)
    addButton(sendRequestBody, "Send Join Request", nil, {Supported = false})

    local acceptRequestBody = addSection(autoParty.Right, "Accept Request", "Auto accept join request", "☑", "AcceptJoinEnabled", false)
    local acceptJoinInput = addInput(acceptRequestBody, "AcceptJoinName", "Enter Username...", "")
    addToggle(acceptRequestBody, "AutoAcceptRequests", "Auto Accept Requests", nil, false)

    local autoSell = makePage("Auto Sell")
    buildingPageName = "Auto Sell"

    local sellBody = addSection(autoSell.Left, "Auto Sell", "Manage item selling", "$", "AutoSellEnabled", false)
    addParagraph(sellBody, "💸 Sell by Rarity", COLORS.Muted)
    addDropdown(sellBody, "SellRarity", "Rarity", rarityOptions, "Rare")
    addDropdown(sellBody, "SellCategory", "Category", categoryOptions, "Weapons")
    addParagraph(sellBody, "✅ Keep Items", COLORS.Muted)
    addDropdown(sellBody, "KeepSkills", "Keep Skills", {"None", "Buff Skills", "Legendary+", "All"}, "Buff Skills")
    addToggle(sellBody, "AutoSell", "Auto Sell", nil, false)
    addButton(sellBody, "Sell", nil, {Supported = false})

    local sellListBody = addSection(autoSell.Right, "Sell List", "Items will selling", "≡", "SellListEnabled", false)
    addParagraph(sellListBody, "⚔ Weapons (0)", COLORS.Text)
    addParagraph(sellListBody, "🛡 Armors (0)", COLORS.Text)
    addParagraph(sellListBody, "🔥 Skills (0)", COLORS.Text)
    addParagraph(sellListBody, "🗡 Helmet (0)", COLORS.Text)

    local autoCrates = makePage("Auto Crates")
    buildingPageName = "Auto Crates"

    local rollBody = addSection(autoCrates.Left, "Auto Roll", "Rolling on Crates", "»", "AutoRollEnabled", false)
    local rewardStatus = addStatus(rollBody, "🎁 Reward: Waiting for reward . . .", COLORS.Muted)
    addToggle(rollBody, "AutoRoll", "Enabled", nil, false)
    addDropdown(rollBody, "CrateRarity", "Crates", rarityOptions, "Rare")

    local rollbackBody = addSection(autoCrates.Right, "Data Rollback", "Rolling doesn't cost Gems", "▣", "DataRollbackEnabled", false)
    addToggle(rollbackBody, "DataRollback", "DataRollback", nil, false)
    addDropdown(rollbackBody, "RollbackReward", "Rewards", rarityOptions, "Legendary")
    addButton(rollbackBody, "Clear All Selected", function()
        values.RollbackReward = nil
        rewardStatus.Text = "🎁 Reward: Waiting for reward . . ."
        return true
    end, {Supported = true})
    addParagraph(rollbackBody, "How Rollback works", COLORS.Yellow)
    addParagraph(
        rollbackBody,
        "Ticked reward: you keep it.\nAny other reward: the script rejoins before the roll ends, so no gems are spent."
    )
    addParagraph(rollbackBody, "How to use", COLORS.Yellow)
    addParagraph(
        rollbackBody,
        "1. Turn on \"Data Rollback\" and tick the rewards you want to lock in \"Rewards\".\n2. Turn on \"Enabled\" so Auto Roll opens crates for you, or open the crates yourself.\n3. If you get a ticked reward the script lets you keep it. If not, the script rejoins."
    )
    addParagraph(rollbackBody, "Warning", COLORS.Red)
    addParagraph(
        rollbackBody,
        "This panel is layout-only until the crate result and persistence signals are mapped. It will not guess or rejoin on an unknown result."
    )

    local webhookPage = makePage("Webhook")
    buildingPageName = "Webhook"

    local webhookBody = addSection(webhookPage.Left, "Webhook", "Dungeon results", "»", "WebhookEnabled", false)
    addToggle(webhookBody, "WebhookEnabled", "Enabled", nil, false)
    local webhookInput = addInput(webhookBody, "WebhookURL", "Enter Webhook Url", "", true)
    addButton(webhookBody, "Test Webhook", function()
        local ok, detail = sendWebhook(
            "Webhook test",
            "Xyneria is connected for **" .. tostring(player.Name) .. "**."
        )
        if ok then
            notify("Webhook", "Test message sent.", "success")
        end
        return ok, detail
    end, {Danger = true, Supported = true})
    addParagraph(
        webhookBody,
        "When enabled, one result message is sent when the completion screen first appears. The URL is never included in saved configs."
    )

    local utilities = makePage("Utilities")
    buildingPageName = "Utilities"

    local performanceBody = addSection(utilities.Left, "Performance", "Boost your game's performance", "»", "PerformanceEnabled", false)
    addToggle(performanceBody, "WhiteScreen", "White Screen", nil, false)
    addToggle(performanceBody, "LowQuality", "Low Quality", nil, false)
    addToggle(performanceBody, "FPSLock", "FPS Lock  ⚙", nil, false)
    addSlider(performanceBody, "FPSLimit", "FPS Limit", 30, 240, tonumber(values.FPSLimit) or 60, 10, " FPS")

    local miscBody = addSection(utilities.Right, "Misc", "Other general functions.", "⌘", "MiscEnabled", false)
    addToggle(miscBody, "StreamerMode", "Streamer Mode (Hide Name)", nil, false)
    addToggle(miscBody, "AntiAFK", "Anti AFK", nil, false)
    addToggle(miscBody, "AutoRejoin", "Auto Rejoin", nil, false)

    local servers = makePage("Servers")
    buildingPageName = "Servers"

    local serverRefresh = nil
    local selectedServer = nil
    local serverData = {}

    local browserBody = addSection(servers.Left, "Server Browser", "Search for and join available servers.", "◯", "ServerBrowser", false)
    local serverSearch = addInput(browserBody, "ServerSearch", "Search...", "")
    local serverList = addListBox(browserBody, 330)

    local serverInfoBody = addSection(servers.Right, "Server Info", "Current Server Details.", "ⓘ", "ServerInfoEnabled", true)
    local serverInfo = addParagraph(
        serverInfoBody,
        "GameId: " .. tostring(game.GameId)
            .. "\n\nPlaceId: " .. tostring(game.PlaceId)
            .. "\n\nJob:\n" .. tostring(game.JobId)
    )

    local hopBody = addSection(servers.Right, "Server Hop", "Instantly join a different server", "⛓", "ServerHopEnabled", false)
    local maximumPlayers = math.max(1, tonumber(Players.MaxPlayers) or 20)
    addSlider(
        hopBody,
        "ServerMaxPlayers",
        "Maximum Players",
        1,
        maximumPlayers,
        math.min(5, maximumPlayers),
        1,
        " Player(s)"
    )

    local function joinServer(jobId)
        jobId = tostring(jobId or "")
        if jobId == "" then
            return false, "Select or enter a server code first."
        end
        local ok, detail = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
        end)
        return ok, ok and nil or tostring(detail)
    end

    local function renderServers()
        clearListBox(serverList)
        local query = string.lower(tostring(serverSearch.Text or ""))
        local shown = 0
        local playerLimit = tonumber(values.ServerMaxPlayers) or maximumPlayers

        for _, server in ipairs(serverData) do
            local blob = string.lower(
                tostring(server.id or "")
                    .. " " .. tostring(server.playing or "")
                    .. " " .. tostring(server.maxPlayers or "")
            )
            if server.id ~= game.JobId
                and (tonumber(server.playing) or 0) <= playerLimit
                and (query == "" or blob:find(query, 1, true)) then
                shown = shown + 1
                local label = string.format(
                    "%d/%d players  •  %s",
                    tonumber(server.playing) or 0,
                    tonumber(server.maxPlayers) or 0,
                    tostring(server.id):sub(1, 13) .. "..."
                )
                local button = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 31),
                    BackgroundColor3 = COLORS.Input,
                    BorderSizePixel = 0,
                    Text = "  " .. label,
                    TextColor3 = selectedServer == server.id and COLORS.White or COLORS.Muted,
                    TextSize = 10,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false
                }, serverList)
                addCorner(button, 3)
                if selectedServer == server.id then
                    addStroke(button, COLORS.Red, 1, 0)
                end
                connect(button.Activated, function()
                    selectedServer = server.id
                    renderServers()
                end)
            end
        end

        if shown == 0 then
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundTransparency = 1,
                Text = "No matching servers.\nToggle Server Browser to refresh.",
                TextColor3 = COLORS.Faint,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextWrapped = true
            }, serverList)
        end
    end

    serverRefresh = function()
        notify("Server Browser", "Refreshing public servers...", "info")
        local ok, result = pcall(function()
            local url = "https://games.roblox.com/v1/games/"
                .. tostring(game.PlaceId)
                .. "/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not ok or type(result) ~= "table" then
            notify("Server Browser", "Could not fetch the public server list.", "error")
            return false
        end

        serverData = result.data or {}
        renderServers()
        notify("Server Browser", tostring(#serverData) .. " servers loaded.", "success")
        return true
    end

    localHandlers.ServerBrowser = function(enabled)
        if enabled then
            task.spawn(serverRefresh)
        end
    end
    localHandlers.ServerMaxPlayers = function()
        renderServers()
    end

    connect(serverSearch:GetPropertyChangedSignal("Text"), renderServers)

    addButton(browserBody, "Join", function()
        return joinServer(selectedServer)
    end, {Supported = true})

    addButton(hopBody, "Server Hop", function()
        if #serverData == 0 then
            serverRefresh()
        end
        local candidates = {}
        local limit = tonumber(values.ServerMaxPlayers) or maximumPlayers
        for _, server in ipairs(serverData) do
            if server.id ~= game.JobId
                and (tonumber(server.playing) or 0) <= limit
                and (tonumber(server.playing) or 0) < (tonumber(server.maxPlayers) or 0) then
                table.insert(candidates, server.id)
            end
        end
        if #candidates == 0 then
            return false, "No matching server is available. Refresh and try again."
        end
        return joinServer(candidates[math.random(1, #candidates)])
    end, {Supported = true})

    local serverCodeInput = addInput(hopBody, "ServerCode", "Input Server Code.", "")
    addButton(hopBody, "Join", function()
        return joinServer(serverCodeInput.Text)
    end, {Supported = true})
    addButton(hopBody, "Copy Server-Code", function()
        local setClipboard = rawget(env, "setclipboard") or rawget(_G, "setclipboard")
        if not setClipboard then
            return false, "This executor does not expose setclipboard."
        end
        setClipboard(game.JobId)
        notify("Server Info", "Current JobId copied.", "success")
        return true
    end, {Supported = true})

    renderServers()

    local settings = makePage("Settings")
    buildingPageName = "Settings"

    local configBody = addSection(settings.Left, "Configs", "Configuration management system.", "◯", "ConfigsEnabled", true)
    local configSearch = addInput(configBody, "ConfigSearch", "Search...", "")
    local configList = addListBox(configBody, 125)
    local configNameInput = addInput(configBody, "ConfigName", "Input Name.", "")

    local autoLoadBody = addSection(settings.Right, "Auto Load", "Auto-load selected config.", "»", "AutoLoadPanel", true)
    local autoLoadSearch = addInput(autoLoadBody, "AutoLoadSearch", "Search...", "")
    local autoLoadList = addListBox(autoLoadBody, 125)
    local autoLoadToggle = addToggle(autoLoadBody, "ConfigAutoLoad", "Auto Load", nil, false)

    local readFile = rawget(env, "readfile") or rawget(_G, "readfile")
    local writeFile = rawget(env, "writefile") or rawget(_G, "writefile")
    local listFiles = rawget(env, "listfiles") or rawget(_G, "listfiles")
    local deleteFile = rawget(env, "delfile") or rawget(_G, "delfile")
    local isFile = rawget(env, "isfile") or rawget(_G, "isfile")
    local isFolder = rawget(env, "isfolder") or rawget(_G, "isfolder")
    local makeFolder = rawget(env, "makefolder") or rawget(_G, "makefolder")
    local configFolder = "Xyneria_DungeonQuest/Configs"
    local autoLoadPath = "Xyneria_DungeonQuest/autoload.txt"
    local selectedConfig = nil
    local configPaths = {}

    local function ensureConfigFolder()
        if not makeFolder then
            return false
        end
        pcall(function()
            if isFolder and not isFolder("Xyneria_DungeonQuest") then
                makeFolder("Xyneria_DungeonQuest")
            end
            if isFolder and not isFolder(configFolder) then
                makeFolder(configFolder)
            elseif not isFolder then
                makeFolder("Xyneria_DungeonQuest")
                makeFolder(configFolder)
            end
        end)
        return true
    end

    local function configAvailable()
        return readFile and writeFile and listFiles and makeFolder
    end

    local function cleanConfigName(name)
        name = tostring(name or ""):match("^%s*(.-)%s*$")
        name = name:gsub("[^%w%s_%-]", "")
        name = name:gsub("%s+", "_")
        return name:sub(1, 40)
    end

    local function snapshotConfig()
        local data = {}
        local excluded = {
            WebhookURL = true,
            ServerCode = true,
            ConfigSearch = true,
            AutoLoadSearch = true,
            ConfigName = true
        }
        for key, value in pairs(values) do
            if not excluded[key] then
                local kind = type(value)
                if kind == "string" or kind == "number" or kind == "boolean" then
                    data[key] = value
                end
            end
        end
        return data
    end

    local function applyConfig(data)
        if type(data) ~= "table" then
            return false
        end
        for key, value in pairs(data) do
            if controls[key] then
                applyValue(key, value, nil, false)
            else
                values[key] = value
            end
        end
        return true
    end

    local function basename(path)
        return tostring(path):match("([^/\\]+)$") or tostring(path)
    end

    local function renderConfigList()
        clearListBox(configList)
        clearListBox(autoLoadList)

        local queryA = string.lower(tostring(configSearch.Text or ""))
        local queryB = string.lower(tostring(autoLoadSearch.Text or ""))

        local function addConfigEntry(target, path, query)
            local name = basename(path):gsub("%.json$", "")
            if query ~= "" and not string.lower(name):find(query, 1, true) then
                return
            end
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = selectedConfig == path and COLORS.RedSoft or COLORS.Input,
                BorderSizePixel = 0,
                Text = "  " .. name,
                TextColor3 = selectedConfig == path and COLORS.White or COLORS.Muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false
            }, target)
            addCorner(button, 3)
            connect(button.Activated, function()
                selectedConfig = path
                renderConfigList()
            end)
        end

        for _, path in ipairs(configPaths) do
            addConfigEntry(configList, path, queryA)
            addConfigEntry(autoLoadList, path, queryB)
        end

        if #configPaths == 0 then
            for _, target in ipairs({configList, autoLoadList}) do
                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundTransparency = 1,
                    Text = configAvailable()
                        and "No configs yet."
                        or "File functions are unavailable.",
                    TextColor3 = COLORS.Faint,
                    TextSize = 10,
                    Font = Enum.Font.Gotham
                }, target)
            end
        end
    end

    local function refreshConfigs()
        configPaths = {}
        if configAvailable() and ensureConfigFolder() then
            local ok, paths = pcall(listFiles, configFolder)
            if ok and type(paths) == "table" then
                for _, path in ipairs(paths) do
                    if tostring(path):lower():sub(-5) == ".json" then
                        table.insert(configPaths, path)
                    end
                end
                table.sort(configPaths)
            end
        end
        renderConfigList()
    end

    local function saveConfig(path)
        if not configAvailable() then
            return false, "This executor does not expose file functions."
        end
        ensureConfigFolder()
        local ok, detail = pcall(writeFile, path, HttpService:JSONEncode(snapshotConfig()))
        return ok, ok and nil or tostring(detail)
    end

    local function loadConfig(path)
        if not path then
            return false, "Select a config first."
        end
        if not readFile then
            return false, "This executor does not expose readfile."
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readFile(path))
        end)
        if not ok or not applyConfig(data) then
            return false, "Could not load the selected config."
        end
        notify("Configs", basename(path) .. " loaded.", "success")
        return true
    end

    addButton(configBody, "Create", function()
        local name = cleanConfigName(configNameInput.Text)
        if name == "" then
            return false, "Enter a config name first."
        end
        local path = configFolder .. "/" .. name .. ".json"
        local ok, detail = saveConfig(path)
        if ok then
            selectedConfig = path
            refreshConfigs()
            notify("Configs", name .. " created.", "success")
        end
        return ok, detail
    end, {Supported = true})

    addButton(configBody, "Delete", function()
        if not selectedConfig then
            return false, "Select a config first."
        end
        if not deleteFile then
            return false, "This executor does not expose delfile."
        end
        local name = basename(selectedConfig)
        local ok, detail = pcall(deleteFile, selectedConfig)
        if ok then
            selectedConfig = nil
            refreshConfigs()
            notify("Configs", name .. " deleted.", "success")
        end
        return ok, ok and nil or tostring(detail)
    end, {Supported = true})

    addButton(configBody, "Load", function()
        return loadConfig(selectedConfig)
    end, {Supported = true})

    addButton(configBody, "Save", function()
        if not selectedConfig then
            return false, "Select a config first."
        end
        local ok, detail = saveConfig(selectedConfig)
        if ok then
            notify("Configs", basename(selectedConfig) .. " saved.", "success")
        end
        return ok, detail
    end, {Supported = true})

    addButton(configBody, "Refresh", function()
        refreshConfigs()
        return true
    end, {Supported = true})

    connect(configSearch:GetPropertyChangedSignal("Text"), renderConfigList)
    connect(autoLoadSearch:GetPropertyChangedSignal("Text"), renderConfigList)

    localHandlers.ConfigAutoLoad = function(enabled)
        if not writeFile then
            error("This executor does not expose writefile.")
        end
        if enabled then
            if not selectedConfig then
                error("Select a config before enabling Auto Load.")
            end
            ensureConfigFolder()
            writeFile(autoLoadPath, selectedConfig)
        elseif deleteFile and isFile and isFile(autoLoadPath) then
            deleteFile(autoLoadPath)
        end
    end

    refreshConfigs()

    task.defer(function()
        if readFile and isFile and isFile(autoLoadPath) then
            local ok, path = pcall(readFile, autoLoadPath)
            if ok and path and isFile(path) then
                selectedConfig = path
                renderConfigList()
                loadConfig(path)
                autoLoadToggle:Set(true, false)
            end
        end
    end)

    buildingPageName = nil

    local navDefinitions = {
        {"General", nil, nil},
        {"Auto Farm", "⚔", "Auto Farm"},
        {"Auto Raids", "☠", "Auto Raids"},
        {"Auto Party", "♙", "Auto Party"},
        {"Auto Sell", "▾", "Auto Sell"},
        {"Auto Crates", "◇", "Auto Crates"},
        {"Webhook", "♧", "Webhook"},
        {"Utilities", nil, nil},
        {"Utilities", "◎", "Utilities"},
        {"Servers", "▤", "Servers"},
        {"Settings", "⚙", "Settings"}
    }

    local function selectPage(pageName)
        if openDropdown then
            openDropdown:Close()
        end

        currentPageName = pageName
        searchBox.Text = ""

        for name, page in pairs(pages) do
            page.Root.Visible = name == pageName
        end

        for name, nav in pairs(pageButtons) do
            local selected = name == pageName
            nav.Button.BackgroundColor3 = selected and COLORS.RedSoft or COLORS.Sidebar
            nav.Icon.TextColor3 = selected and Color3.fromRGB(255, 73, 81) or COLORS.Red
            nav.Label.TextColor3 = selected and COLORS.White or COLORS.Text
        end
    end

    local navOrder = 0
    for _, definition in ipairs(navDefinitions) do
        local titleText, icon, pageName = definition[1], definition[2], definition[3]
        if not pageName then
            local sectionLabel = create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text = titleText,
                TextColor3 = COLORS.Muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left
            }, sidebarScroll)
            sectionLabel.LayoutOrder = navOrder
        else
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 42),
                BackgroundColor3 = COLORS.Sidebar,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false
            }, sidebarScroll)
            button.LayoutOrder = navOrder
            addCorner(button, 4)

            local iconLabel = create("TextLabel", {
                Position = UDim2.fromOffset(7, 0),
                Size = UDim2.fromOffset(27, 42),
                BackgroundTransparency = 1,
                Text = icon,
                TextColor3 = COLORS.Red,
                TextSize = 17,
                Font = Enum.Font.GothamBold
            }, button)

            local textLabel = create("TextLabel", {
                Position = UDim2.fromOffset(38, 0),
                Size = UDim2.new(1, -43, 1, 0),
                BackgroundTransparency = 1,
                Text = titleText,
                TextColor3 = COLORS.Text,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left
            }, button)

            pageButtons[pageName] = {
                Button = button,
                Icon = iconLabel,
                Label = textLabel
            }

            connect(button.Activated, function()
                selectPage(pageName)
            end)
        end
        navOrder = navOrder + 1
    end

    local function showPage(name)
        if pageButtons[name] then
            selectPage(name)
        end
    end

    connect(settingsButton.Activated, function()
        showPage("Settings")
    end)

    connect(searchButton.Activated, function()
        searchBox.Visible = not searchBox.Visible
        settingsButton.Visible = not searchBox.Visible
        searchButton.Text = searchBox.Visible and "×" or "⌕"
        if searchBox.Visible then
            searchBox:CaptureFocus()
        else
            searchBox.Text = ""
        end
    end)

    connect(searchBox.FocusLost, function(enterPressed)
        if enterPressed and searchBox.Text == "" then
            searchBox.Visible = false
            settingsButton.Visible = true
            searchButton.Text = "⌕"
        end
    end)

    connect(searchBox:GetPropertyChangedSignal("Text"), function()
        local query = string.lower(searchBox.Text)
        for _, item in ipairs(searchItems[currentPageName] or {}) do
            if item.Object and item.Object.Parent then
                item.Object.Visible = query == "" or item.Text:find(query, 1, true) ~= nil
            end
        end
    end)

    showPage("Auto Farm")

    local completionLatched = false
    local statusElapsed = 0

    connect(RunService.Heartbeat, function(dt)
        statusElapsed = statusElapsed + dt
        if statusElapsed < 0.5 then
            return
        end
        statusElapsed = 0

        local status = {}
        if api.GetStatus then
            local ok, result = pcall(api.GetStatus)
            if ok and type(result) == "table" then
                status = result
            end
        end

        brandSubtitle.Text = tostring(
            status.Subtitle
                or api.Subtitle
                or "Dungeon Quest"
        )

        replayStatus.Text = "↻ Current Replayed: "
            .. tostring(status.ReplayCount or values.ReplayCount or 0)
            .. " Times"

        liveStatus.Text = table.concat({
            "Mode: " .. tostring(status.Mode or "IDLE"),
            "Target: " .. tostring(status.Target or "NONE")
                .. "  •  Distance: " .. tostring(status.Distance or "-"),
            "Enemies: " .. tostring(status.Enemies or 0)
                .. "  •  Hazards: " .. tostring(status.Hazards or 0),
            "Path: " .. tostring(status.Path or "NO")
                .. "  •  Route: " .. tostring(status.Route or "0/0"),
            "Profile: " .. tostring(status.Profile or api.CurrentDungeon or "Universal")
        }, "\n")

        local completed = status.Completed == true
        if completed and not completionLatched and values.WebhookEnabled then
            local ok, detail = sendWebhook(
                "Dungeon complete",
                "**Profile:** " .. tostring(status.Profile or "Universal")
                    .. "\n**Replayed:** " .. tostring(status.ReplayCount or 0)
                    .. "\n**Player:** " .. tostring(player.Name)
            )
            if not ok then
                notify("Webhook", detail, "error")
            end
        end
        completionLatched = completed
    end)

    local controller = {}

    function controller:Notify(titleText, message, kind)
        notify(titleText, message, kind)
    end

    function controller:Set(key, value)
        if controls[key] then
            applyValue(key, value, nil, false)
            return true
        end
        return false
    end

    function controller:Get(key)
        return values[key]
    end

    function controller:Destroy()
        if destroyed then
            return
        end
        destroyed = true
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        pcall(function()
            applyLowQuality(false)
        end)
        disconnectBucket(utilityConnections)
        disconnectBucket(connections)
        if screen and screen.Parent then
            screen:Destroy()
        end
    end

    notify(
        "Xyneria",
        "Reaper-style layout loaded. Controls marked UI need their game remote mapped.",
        "success"
    )

    return controller
end
