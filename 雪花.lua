local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
    Action = "PushUp",
    Interval = 0.1,
    AutoStart = false,
    AutoRebirth = false,
    AutoRebirthDelay = 3,
    AntiAfk = true,
    AutoReset = false,
    AutoResetInterval = 300,
    SaveSettings = true,
    Notifications = true,
    MinimizeOnStart = false,
    TotalReps = 0,
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10

local function findRemote(name, alt)
    local list = { ReplicatedStorage }
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if folder then table.insert(list, folder) end
    for _, p in ipairs(list) do
        local r = p:FindFirstChild(name) or (alt and p:FindFirstChild(alt))
        if r then return r end
    end
end

local TrainEvent = findRemote("TrainEvent", "Train")
local RebirthEvent = findRemote("RebirthEvent", "Rebirth")

local function saveConfig()
    if not Config.SaveSettings or type(writefile) ~= "function" then return end
    pcall(function()
        local d = {}
        for k, v in pairs(Config) do
            if type(v) ~= "table" and type(v) ~= "function" then d[k] = v end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(d))
    end)
end

local function loadConfig()
    if not Config.SaveSettings or type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(CONFIG_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then Config[k] = v end
        end
    end
end
loadConfig()

local Theme = {
    Background = Color3.fromRGB(15, 16, 21),
    Panel = Color3.fromRGB(24, 26, 34),
    PanelAlt = Color3.fromRGB(34, 37, 47),
    Stroke = Color3.fromRGB(46, 50, 64),
    Text = Color3.fromRGB(232, 234, 240),
    TextDim = Color3.fromRGB(122, 127, 145),
    Accent = Color3.fromRGB(245, 179, 61),
    AccentDark = Color3.fromRGB(196, 136, 30),
    Success = Color3.fromRGB(74, 222, 128),
    Danger = Color3.fromRGB(248, 113, 113),
    Purple = Color3.fromRGB(167, 139, 250),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontMed = Enum.Font.GothamMedium,
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, c, t)
    local s = Instance.new("UIStroke")
    s.Color = c or Theme.Stroke
    s.Thickness = t or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function padding(p, x, y)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, y or x)
    pad.PaddingBottom = UDim.new(0, y or x)
    pad.PaddingLeft = UDim.new(0, x)
    pad.PaddingRight = UDim.new(0, x)
    pad.Parent = p
    return pad
end

local function gradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 90
    g.Parent = p
    return g
end

local function tween(o, props, dur)
    local t = TweenService:Create(o, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local isTraining = false
local trainThread = nil
local trainCount = 0
local totalCount = tonumber(Config.TotalReps) or 0
local startTime = 0
local isMinimized = false
local startAutoTrain, stopAutoTrain, updateStatus, updateStartBtn

local parentGui
pcall(function()
    if type(gethui) == "function" then parentGui = gethui() end
end)
if not parentGui then parentGui = PlayerGui end

local old = parentGui:FindFirstChild("CrownStrengthUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CrownStrengthUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = parentGui

local W, H = 340, 600

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(0, 40, 0.5, -H / 2)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 16)
stroke(Main, Theme.Stroke, 1)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 2)
accentBar.BackgroundColor3 = Theme.Accent
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 5
accentBar.Parent = Main
gradient(accentBar, Theme.Accent, Theme.Purple, 0)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 56)
Header.BackgroundColor3 = Theme.Panel
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderGlow = Instance.new("Frame")
HeaderGlow.Size = UDim2.new(1, 0, 1, 0)
HeaderGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderGlow.BackgroundTransparency = 0.95
HeaderGlow.BorderSizePixel = 0
HeaderGlow.Parent = Header
gradient(HeaderGlow, Theme.Accent, Theme.Purple, 25)

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Theme.Stroke
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Header

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 30, 0, 30)
Logo.Position = UDim2.new(0, 16, 0.5, -15)
Logo.BackgroundColor3 = Theme.Accent
Logo.BorderSizePixel = 0
Logo.Parent = Header
corner(Logo, 9)
gradient(Logo, Theme.Accent, Theme.AccentDark, 90)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "C"
LogoText.TextColor3 = Color3.fromRGB(30, 20, 0)
LogoText.Font = Theme.FontBold
LogoText.TextSize = 16
LogoText.Parent = Logo

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -160, 0, 18)
TitleLbl.Position = UDim2.new(0, 56, 0, 10)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "CROWN OF STRENGTH"
TitleLbl.TextColor3 = Theme.Text
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Font = Theme.FontBold
TitleLbl.TextSize = 13
TitleLbl.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -160, 0, 14)
SubTitle.Position = UDim2.new(0, 56, 0, 28)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "Auto Trainer  ·  v2.1"
SubTitle.TextColor3 = Theme.TextDim
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = Theme.Font
SubTitle.TextSize = 10
SubTitle.Parent = Header

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 8, 0, 8)
HeaderDot.Position = UDim2.new(1, -104, 0.5, -4)
HeaderDot.BackgroundColor3 = Theme.Danger
HeaderDot.BorderSizePixel = 0
HeaderDot.Parent = Header
corner(HeaderDot, 4)

local function headerButton(text, base, xOff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(1, xOff, 0.5, -14)
    b.BackgroundColor3 = base
    b.BackgroundTransparency = 0.55
    b.Text = text
    b.TextColor3 = Theme.Text
    b.Font = Theme.FontBold
    b.TextSize = 15
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = Header
    corner(b, 7)
    b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.25 }, 0.15) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0.55 }, 0.15) end)
    return b
end

local CloseBtn = headerButton("x", Theme.Danger, -40)
local MinBtn = headerButton("-", Theme.PanelAlt, -74)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -120)
Content.Position = UDim2.new(0, 0, 0, 56)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Theme.Stroke
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main
padding(Content, 14)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 12)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

local function sectionTitle(text)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.Parent = Content

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 12)
    bar.Position = UDim2.new(0, 0, 0.5, -6)
    bar.BackgroundColor3 = Theme.Accent
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.upper(text)
    lbl.TextColor3 = Theme.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Theme.FontBold
    lbl.TextSize = 11
    lbl.Parent = row
end

local function card(height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = Theme.Panel
    f.BorderSizePixel = 0
    f.Parent = Content
    corner(f, 12)
    stroke(f, Theme.Stroke, 1)
    padding(f, 12)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = f
    return f
end

local function notify(text, color)
    if not Config.Notifications or not ScreenGui.Parent then return end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 260, 0, 38)
    toast.Position = UDim2.new(0.5, -130, 0, -50)
    toast.BackgroundColor3 = Theme.Panel
    toast.BackgroundTransparency = 1
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = ScreenGui
    corner(toast, 10)
    stroke(toast, color or Theme.Accent, 1)

    local acc = Instance.new("Frame")
    acc.Size = UDim2.new(0, 3, 0, 20)
    acc.Position = UDim2.new(0, 8, 0.5, -10)
    acc.BackgroundColor3 = color or Theme.Accent
    acc.BorderSizePixel = 0
    acc.Parent = toast
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -26, 1, 0)
    lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.Font = Theme.FontMed
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = toast

    tween(toast, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -130, 0, 20) }, 0.25)
    task.delay(2.6, function()
        if not toast.Parent then return end
        tween(toast, { BackgroundTransparency = 1, Position = UDim2.new(0.5, -130, 0, -30) }, 0.25)
        task.wait(0.3)
        if toast.Parent then toast:Destroy() end
    end)
end

sectionTitle("Trainer")
local trainCard = card(160)

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 30)
actionRow.BackgroundTransparency = 1
actionRow.Parent = trainCard

local actionLbl = Instance.new("TextLabel")
actionLbl.Size = UDim2.new(0, 70, 1, 0)
actionLbl.BackgroundTransparency = 1
actionLbl.Text = "Action"
actionLbl.TextColor3 = Theme.TextDim
actionLbl.TextXAlignment = Enum.TextXAlignment.Left
actionLbl.Font = Theme.FontMed
actionLbl.TextSize = 12
actionLbl.Parent = actionRow

local actionBtn = Instance.new("TextButton")
actionBtn.Size = UDim2.new(1, -70, 1, 0)
actionBtn.Position = UDim2.new(0, 70, 0, 0)
actionBtn.BackgroundColor3 = Theme.PanelAlt
actionBtn.Text = Config.Action
actionBtn.TextColor3 = Theme.Text
actionBtn.Font = Theme.FontMed
actionBtn.TextSize = 12
actionBtn.AutoButtonColor = false
actionBtn.BorderSizePixel = 0
actionBtn.Parent = actionRow
corner(actionBtn, 7)
stroke(actionBtn, Theme.Stroke, 1)

actionBtn.MouseEnter:Connect(function() tween(actionBtn, { BackgroundColor3 = Color3.fromRGB(44, 48, 60) }, 0.15) end)
actionBtn.MouseLeave:Connect(function() tween(actionBtn, { BackgroundColor3 = Theme.PanelAlt }, 0.15) end)

local actionIndex = 1
for i, v in ipairs(Actions) do
    if v == Config.Action then actionIndex = i break end
end

actionBtn.MouseButton1Click:Connect(function()
    actionIndex = actionIndex % #Actions + 1
    Config.Action = Actions[actionIndex]
    actionBtn.Text = Config.Action
    saveConfig()
    updateStatus()
end)

local intervalRow = Instance.new("Frame")
intervalRow.Size = UDim2.new(1, 0, 0, 30)
intervalRow.BackgroundTransparency = 1
intervalRow.Parent = trainCard

local intervalLbl = Instance.new("TextLabel")
intervalLbl.Size = UDim2.new(0, 70, 1, 0)
intervalLbl.BackgroundTransparency = 1
intervalLbl.Text = "Interval (s)"
intervalLbl.TextColor3 = Theme.TextDim
intervalLbl.TextXAlignment = Enum.TextXAlignment.Left
intervalLbl.Font = Theme.FontMed
intervalLbl.TextSize = 12
intervalLbl.Parent = intervalRow

local intervalBox = Instance.new("TextBox")
intervalBox.Size = UDim2.new(1, -70, 1, 0)
intervalBox.Position = UDim2.new(0, 70, 0, 0)
intervalBox.BackgroundColor3 = Theme.PanelAlt
intervalBox.Text = tostring(Config.Interval)
intervalBox.TextColor3 = Theme.Text
intervalBox.PlaceholderText = "0.1"
intervalBox.PlaceholderColor3 = Theme.TextDim
intervalBox.Font = Theme.FontMed
intervalBox.TextSize = 12
intervalBox.ClearTextOnFocus = false
intervalBox.BorderSizePixel = 0
intervalBox.Parent = intervalRow
corner(intervalBox, 7)
stroke(intervalBox, Theme.Stroke, 1)

intervalBox.FocusLost:Connect(function()
    local n = tonumber(intervalBox.Text)
    if n and n >= MIN_INTERVAL and n <= MAX_INTERVAL then
        Config.Interval = n
        intervalBox.Text = tostring(n)
        saveConfig()
    else
        intervalBox.Text = tostring(Config.Interval)
        notify(string.format("Interval: %.2f ~ %d", MIN_INTERVAL, MAX_INTERVAL), Theme.Danger)
    end
end)

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 0, 40)
startBtn.BackgroundColor3 = Theme.Success
startBtn.Text = "START TRAINING"
startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
startBtn.Font = Theme.FontBold
startBtn.TextSize = 14
startBtn.AutoButtonColor = false
startBtn.BorderSizePixel = 0
startBtn.Parent = trainCard
corner(startBtn, 9)
local startGrad = gradient(startBtn, Color3.fromRGB(110, 231, 152), Color3.fromRGB(52, 190, 100), 90)

updateStartBtn = function()
    if isTraining then
        startBtn.Text = "STOP TRAINING"
        startBtn.BackgroundColor3 = Theme.Danger
        startBtn.TextColor3 = Color3.fromRGB(40, 10, 14)
        startGrad.Color = ColorSequence.new(Color3.fromRGB(255, 160, 160), Color3.fromRGB(210, 70, 90))
    else
        startBtn.Text = "START TRAINING"
        startBtn.BackgroundColor3 = Theme.Success
        startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
        startGrad.Color = ColorSequence.new(Color3.fromRGB(110, 231, 152), Color3.fromRGB(52, 190, 100))
    end
end

startBtn.MouseEnter:Connect(function() tween(startBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, { BackgroundTransparency = 0 }, 0.15) end)

sectionTitle("Automation")
local autoCard = card(172)

local function toggleRow(labelText, key, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = autoCard

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Theme.FontMed
    lbl.TextSize = 12
    lbl.Parent = row

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 44, 0, 24)
    switch.Position = UDim2.new(1, -44, 0.5, -12)
    switch.BackgroundColor3 = Config[key] and Theme.Success or Theme.PanelAlt
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 12)
    stroke(switch, Theme.Stroke, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = Config[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 9)

    local function refresh()
        local on = Config[key]
        tween(switch, { BackgroundColor3 = on and Theme.Success or Theme.PanelAlt }, 0.15)
        tween(knob, { Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, 0.15)
    end

    switch.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        if key == "AutoRebirth" and Config[key] and not RebirthEvent then
            Config[key] = false
            notify("RebirthEvent not found", Theme.Danger)
        end
        refresh()
        if onChange then onChange(Config[key]) end
        saveConfig()
    end)
end

toggleRow("Auto Rebirth", "AutoRebirth")
toggleRow("Anti-AFK", "AntiAfk")
toggleRow("Auto Reset Character", "AutoReset")
toggleRow("Notifications", "Notifications")

sectionTitle("Statistics")
local statCard = card(112)

local function statRow(label)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 22)
    r.BackgroundTransparency = 1
    r.Parent = statCard

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Theme.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Theme.FontMed
    l.TextSize = 12
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.4, 0, 1, 0)
    v.Position = UDim2.new(0.6, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "0"
    v.TextColor3 = Theme.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = Theme.FontBold
    v.TextSize = 12
    v.Parent = r
    return v
end

local statSession = statRow("Session Reps")
local statTotal = statRow("Total Reps")
local statRate = statRow("Avg / Second")

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, 0, 0, 64)
Bottom.Position = UDim2.new(0, 0, 1, -64)
Bottom.BackgroundColor3 = Theme.Panel
Bottom.BorderSizePixel = 0
Bottom.Parent = Main

local bottomLine = Instance.new("Frame")
bottomLine.Size = UDim2.new(1, 0, 0, 1)
bottomLine.BackgroundColor3 = Theme.Stroke
bottomLine.BorderSizePixel = 0
bottomLine.Parent = Bottom

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 16, 0, 18)
statusDot.BackgroundColor3 = Theme.Danger
statusDot.BorderSizePixel = 0
statusDot.Parent = Bottom
corner(statusDot, 4)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -50, 0, 20)
statusLbl.Position = UDim2.new(0, 32, 0, 12)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Idle"
statusLbl.TextColor3 = Theme.Text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = Theme.FontMed
statusLbl.TextSize = 12
statusLbl.Parent = Bottom

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -32, 0, 16)
hintLbl.Position = UDim2.new(0, 16, 0, 36)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = "Insert: hide  ·  RightShift: start/stop"
hintLbl.TextColor3 = Theme.TextDim
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Font = Theme.Font
hintLbl.TextSize = 10
hintLbl.Parent = Bottom

updateStatus = function()
    if isTraining then
        statusDot.BackgroundColor3 = Theme.Success
        HeaderDot.BackgroundColor3 = Theme.Success
        statusLbl.Text = "Training  ·  " .. Config.Action
    else
        statusDot.BackgroundColor3 = Theme.Danger
        HeaderDot.BackgroundColor3 = Theme.Danger
        statusLbl.Text = "Idle"
    end
end

startAutoTrain = function()
    if isTraining then return end
    if not TrainEvent then notify("TrainEvent not found", Theme.Danger) return end
    isTraining = true
    trainCount = 0
    startTime = tick()
    trainThread = task.spawn(function()
        while isTraining and ScreenGui.Parent do
            local ok = pcall(function() TrainEvent:FireServer(Config.Action) end)
            if ok then
                trainCount = trainCount + 1
                totalCount = totalCount + 1
                Config.TotalReps = totalCount
            end
            task.wait(Config.Interval)
        end
        if isTraining then isTraining = false end
    end)
end

stopAutoTrain = function()
    if not isTraining then return end
    isTraining = false
    if trainThread then
        pcall(task.cancel, trainThread)
        trainThread = nil
    end
    saveConfig()
end

startBtn.MouseButton1Click:Connect(function()
    if isTraining then
        stopAutoTrain()
        notify("Training stopped", Theme.Danger)
    else
        startAutoTrain()
        if isTraining then notify("Auto training started", Theme.Success) end
    end
    updateStartBtn()
    updateStatus()
end)

do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local Connections = {}
local function track(c)
    if c then table.insert(Connections, c) end
    return c
end

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    tween(Main, { Size = UDim2.new(0, W, 0, isMinimized and 56 or H) }, 0.25)
    MinBtn.Text = isMinimized and "+" or "-"
end)

CloseBtn.MouseButton1Click:Connect(function()
    stopAutoTrain()
    saveConfig()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    tween(Main, { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 }, 0.25)
    task.wait(0.3)
    if ScreenGui.Parent then ScreenGui:Destroy() end
end)

task.spawn(function()
    while ScreenGui.Parent do
        local elapsed = isTraining and (tick() - startTime) or 0
        local aps = elapsed > 0 and (trainCount / elapsed) or 0
        statSession.Text = tostring(trainCount)
        statTotal.Text = tostring(totalCount)
        statRate.Text = string.format("%.2f", aps)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        updateStatus()
        task.wait(1)
    end
end)

local function fireAntiAfk()
    if not Config.AntiAfk then return end
    if pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, true, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, false, false, game)
    end) then return end
    if pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end) then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

track(LocalPlayer.Idled:Connect(fireAntiAfk))

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(60)
        if Config.AntiAfk then fireAntiAfk() end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(Config.AutoRebirthDelay)
        if Config.AutoRebirth and RebirthEvent then
            pcall(function() RebirthEvent:FireServer() end)
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(Config.AutoResetInterval)
        if Config.AutoReset then
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 else char:BreakJoints() end
                end
            end)
        end
    end
end)

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        Main.Visible = not Main.Visible
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        if isTraining then
            stopAutoTrain()
            notify("Training stopped", Theme.Danger)
        else
            startAutoTrain()
            if isTraining then notify("Auto training started", Theme.Success) end
        end
        updateStartBtn()
        updateStatus()
    end
end))

updateStartBtn()
updateStatus()

if Config.AutoStart then
    startAutoTrain()
    updateStartBtn()
    updateStatus()
end

if Config.MinimizeOnStart then
    isMinimized = true
    Main.Size = UDim2.new(0, W, 0, 56)
    MinBtn.Text = "+"
end

notify("CrownStrength v2.1 loaded", Theme.Accent)