local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
    Action = "PushUp", Interval = 0.1, AutoStart = false,
    AutoRebirth = false, AutoRebirthDelay = 3, AntiAfk = true,
    AutoReset = false, AutoResetInterval = 300, SaveSettings = true,
    Notifications = true, MinimizeOnStart = false, TotalReps = 0,
    Fly = false, FlySpeed = 50, WalkSpeed = 16,
    AutoRebirthCount = 0, AutoRebirthDone = 0,
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }
local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10
local MIN_W, MIN_H, MAX_W, MAX_H = 600, 300, 1500, 720
local COLLAPSED = 56
local IS_TOUCH = UserInputService.TouchEnabled

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

local T = {
    BG0 = Color3.fromRGB(10, 11, 16),
    BG1 = Color3.fromRGB(20, 22, 32),
    BG2 = Color3.fromRGB(14, 15, 22),
    Panel = Color3.fromRGB(26, 28, 38),
    PanelAlt = Color3.fromRGB(38, 41, 54),
    PanelHi = Color3.fromRGB(48, 52, 68),
    Stroke = Color3.fromRGB(58, 62, 80),
    Text = Color3.fromRGB(240, 242, 250),
    TextDim = Color3.fromRGB(130, 136, 155),
    TextSub = Color3.fromRGB(100, 105, 125),
    Accent = Color3.fromRGB(245, 179, 61),
    Accent2 = Color3.fromRGB(255, 210, 120),
    AccentDark = Color3.fromRGB(190, 130, 30),
    Success = Color3.fromRGB(74, 222, 128),
    SuccessDark = Color3.fromRGB(40, 180, 90),
    Danger = Color3.fromRGB(248, 113, 113),
    DangerDark = Color3.fromRGB(200, 60, 80),
    Purple = Color3.fromRGB(167, 139, 250),
    Info = Color3.fromRGB(96, 165, 250),
    Pink = Color3.fromRGB(244, 114, 182),
    F = Enum.Font.Gotham, FB = Enum.Font.GothamBold, FM = Enum.Font.GothamMedium,
}

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end

local function stroke(p, c, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Stroke; s.Thickness = t or 1
    s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end

local function padding(p, x, y)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, y or x); pad.PaddingBottom = UDim.new(0, y or x)
    pad.PaddingLeft = UDim.new(0, x); pad.PaddingRight = UDim.new(0, x)
    pad.Parent = p; return pad
end

local function gradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2); g.Rotation = rot or 90; g.Parent = p; return g
end

local function gradientMulti(p, list, rot)
    local g = Instance.new("UIGradient")
    local cs = {}
    for _, c in ipairs(list) do table.insert(cs, ColorSequenceKeypoint.new(c[1], c[2])) end
    g.Color = ColorSequence.new(cs)
    g.Rotation = rot or 90
    g.Parent = p
    return g
end

local function tween(o, props, dur, style, dir)
    local tw = TweenService:Create(
        o,
        TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play(); return tw
end

local function fmt(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end

local isTraining, trainThread = false, nil
local trainCount, totalCount = 0, tonumber(Config.TotalReps) or 0
local startTime, isCollapsed, savedSize = 0, false, nil
local strengthSource, strengthAttr = nil, nil
local sessionStartStrength = nil
local flying, flyBV, flyBG = false, nil, nil
local flySpeed = Config.FlySpeed or 50
local startAutoTrain, stopAutoTrain, updateStatus, updateStartBtn, collapse, expand
local startFly, stopFly, applyWalkSpeed

local MobileInput = { Forward = false, Back = false, Left = false, Right = false, Up = false, Down = false }

local STRENGTH_NAMES = { "Strength", "Power", "Str", "StrengthValue", "力量", "TotalStrength", "CrownStrength" }

local function refreshStrengthSource()
    if strengthSource and strengthSource.Parent then return true end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs(STRENGTH_NAMES) do
            local v = ls:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                strengthSource, strengthAttr = v, nil
                if sessionStartStrength == nil then sessionStartStrength = tonumber(v.Value) or 0 end
                return true
            end
        end
    end
    for _, n in ipairs(STRENGTH_NAMES) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v) == "number" then
            strengthSource, strengthAttr = nil, n
            if sessionStartStrength == nil then sessionStartStrength = v end
            return true
        end
    end
    for _, n in ipairs(STRENGTH_NAMES) do
        local direct = LocalPlayer:FindFirstChild(n)
        if direct and (direct:IsA("IntValue") or direct:IsA("NumberValue")) then
            strengthSource, strengthAttr = direct, nil
            if sessionStartStrength == nil then sessionStartStrength = tonumber(direct.Value) or 0 end
            return true
        end
    end
    return false
end

local function getStrength()
    if strengthSource and strengthSource.Parent then return tonumber(strengthSource.Value) or 0 end
    if strengthAttr then return tonumber(LocalPlayer:GetAttribute(strengthAttr)) or 0 end
    return 0
end

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

local W, H = 1060, 460

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(0, 40, 0.5, -H / 2)
Main.BackgroundColor3 = T.BG0
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local mainCorner = corner(Main, 18)

local bgGrad = gradientMulti(Main, {
    {0, T.BG1}, {0.5, T.BG0}, {1, T.BG2},
}, 135)

local mainStroke = stroke(Main, T.Accent, 1.2, 0.55)

local innerHighlight = Instance.new("Frame")
innerHighlight.Size = UDim2.new(1, 0, 0, 100)
innerHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
innerHighlight.BackgroundTransparency = 0.96
innerHighlight.BorderSizePixel = 0
innerHighlight.ZIndex = 1
innerHighlight.Parent = Main
gradient(innerHighlight, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), 90)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = T.Accent
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 5
accentBar.Parent = Main
gradientMulti(accentBar, {
    {0, T.Accent},
    {0.5, T.Pink},
    {1, T.Purple},
}, 0)

local accentGlow = Instance.new("Frame")
accentGlow.Size = UDim2.new(1, 0, 0, 12)
accentGlow.Position = UDim2.new(0, 0, 0, 0)
accentGlow.BackgroundColor3 = T.Accent
accentGlow.BackgroundTransparency = 0.85
accentGlow.BorderSizePixel = 0
accentGlow.ZIndex = 4
accentGlow.Parent = Main
gradient(accentGlow, T.Accent, T.Purple, 0)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 62)
Header.BackgroundColor3 = T.Panel
Header.BackgroundTransparency = 0.15
Header.BorderSizePixel = 0
Header.ZIndex = 3
Header.Parent = Main

local HeaderGlow = Instance.new("Frame")
HeaderGlow.Size = UDim2.new(1, 0, 1, 0)
HeaderGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderGlow.BackgroundTransparency = 0.94
HeaderGlow.BorderSizePixel = 0
HeaderGlow.ZIndex = 3
HeaderGlow.Parent = Header
gradientMulti(HeaderGlow, {
    {0, T.Accent},
    {0.5, T.Pink},
    {1, T.Purple},
}, 25)

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = T.Accent
HeaderLine.BackgroundTransparency = 0.6
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 4
HeaderLine.Parent = Header
gradient(HeaderLine, T.Accent, T.Purple, 0)

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 36, 0, 36)
Logo.Position = UDim2.new(0, 18, 0.5, -18)
Logo.BackgroundColor3 = T.Accent
Logo.BorderSizePixel = 0
Logo.ZIndex = 5
Logo.Parent = Header
corner(Logo, 11)
gradientMulti(Logo, {
    {0, T.Accent2},
    {1, T.AccentDark},
}, 135)

stroke(Logo, T.Accent2, 1, 0.4)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "力"
LogoText.TextColor3 = Color3.fromRGB(30, 20, 0)
LogoText.Font = T.FB
LogoText.TextSize = 18
LogoText.ZIndex = 6
LogoText.Parent = Logo

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 300, 0, 20)
TitleLbl.Position = UDim2.new(0, 64, 0, 12)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "力量之冠"
TitleLbl.TextColor3 = T.Text
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Font = T.FB
TitleLbl.TextSize = 15
TitleLbl.ZIndex = 5
TitleLbl.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 300, 0, 14)
SubTitle.Position = UDim2.new(0, 64, 0, 32)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "AUTO TRAINER   ·   v1.0"
SubTitle.TextColor3 = T.TextDim
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.FM
SubTitle.TextSize = 10
SubTitle.ZIndex = 5
SubTitle.Parent = Header

local HeaderDotGlow = Instance.new("Frame")
HeaderDotGlow.Size = UDim2.new(0, 16, 0, 16)
HeaderDotGlow.Position = UDim2.new(1, -116, 0.5, -8)
HeaderDotGlow.BackgroundColor3 = T.Danger
HeaderDotGlow.BackgroundTransparency = 0.7
HeaderDotGlow.BorderSizePixel = 0
HeaderDotGlow.ZIndex = 4
HeaderDotGlow.Parent = Header
corner(HeaderDotGlow, 8)

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 8, 0, 8)
HeaderDot.Position = UDim2.new(1, -112, 0.5, -4)
HeaderDot.BackgroundColor3 = T.Danger
HeaderDot.BorderSizePixel = 0
HeaderDot.ZIndex = 5
HeaderDot.Parent = Header
corner(HeaderDot, 4)

local function headerButton(text, base, xOff, hoverColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 30, 0, 30)
    b.Position = UDim2.new(1, xOff, 0.5, -15)
    b.BackgroundColor3 = base
    b.BackgroundTransparency = 0.5
    b.Text = text
    b.TextColor3 = T.Text
    b.Font = T.FB
    b.TextSize = 16
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.ZIndex = 5
    b.Parent = Header
    corner(b, 8)
    stroke(b, T.Stroke, 1, 0.5)
    b.MouseEnter:Connect(function()
        tween(b, { BackgroundTransparency = 0.15, BackgroundColor3 = hoverColor or base }, 0.15)
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundTransparency = 0.5, BackgroundColor3 = base }, 0.15)
    end)
    return b
end

local CloseBtn = headerButton("×", T.Danger, -42, T.Danger)
local MinBtn = headerButton("◎", T.PanelAlt, -78, T.AccentDark)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -62 - 68)
Content.Position = UDim2.new(0, 0, 0, 62)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = T.Accent
Content.ScrollBarImageTransparency = 0.3
Content.ScrollingDirection = Enum.ScrollingDirection.X
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.X
Content.ZIndex = 2
Content.Parent = Main
padding(Content, 16)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.FillDirection = Enum.FillDirection.Horizontal
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ContentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
ContentLayout.Padding = UDim.new(0, 14)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

local function card(width, layoutOrder, accentColor)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, width, 1, 0)
    f.BackgroundColor3 = T.Panel
    f.BackgroundTransparency = 0.08
    f.BorderSizePixel = 0
    f.LayoutOrder = layoutOrder or 0
    f.Parent = Content
    corner(f, 14)

    stroke(f, accentColor or T.Stroke, 1, 0.35)

    local hl = Instance.new("Frame")
    hl.Size = UDim2.new(1, 0, 0, 60)
    hl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hl.BackgroundTransparency = 0.96
    hl.BorderSizePixel = 0
    hl.ZIndex = 1
    hl.Parent = f
    gradient(hl, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), 90)

    if accentColor then
        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1, 0, 0, 2)
        topBar.BackgroundColor3 = accentColor
        topBar.BorderSizePixel = 0
        topBar.ZIndex = 3
        topBar.Parent = f
        gradient(topBar, accentColor, Color3.fromRGB(
            math.floor(accentColor.R * 255 * 0.6),
            math.floor(accentColor.G * 255 * 0.6),
            math.floor(accentColor.B * 255 * 0.6)
        ), 0)
    end

    padding(f, 14, 12)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 9)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = f
    return f
end

local function cardTitle(parent, text, accentColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 14)
    bar.Position = UDim2.new(0, 0, 0.5, -7)
    bar.BackgroundColor3 = accentColor or T.Accent
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 2)

    local barGlow = Instance.new("Frame")
    barGlow.Size = UDim2.new(0, 6, 0, 14)
    barGlow.Position = UDim2.new(0, -2, 0.5, -7)
    barGlow.BackgroundColor3 = accentColor or T.Accent
    barGlow.BackgroundTransparency = 0.7
    barGlow.BorderSizePixel = 0
    barGlow.Parent = row
    corner(barGlow, 3)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = accentColor or T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FB
    lbl.TextSize = 12
    lbl.Parent = row
end

local function notify(text, color)
    if not Config.Notifications or not ScreenGui.Parent then return end
    color = color or T.Accent

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 280, 0, 44)
    toast.Position = UDim2.new(0.5, -140, 0, -60)
    toast.BackgroundColor3 = T.Panel
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = ScreenGui
    corner(toast, 12)
    stroke(toast, color, 1.2, 0.3)

    local acc = Instance.new("Frame")
    acc.Size = UDim2.new(0, 4, 0, 26)
    acc.Position = UDim2.new(0, 10, 0.5, -13)
    acc.BackgroundColor3 = color
    acc.BorderSizePixel = 0
    acc.Parent = toast
    corner(acc, 2)

    local accGlow = Instance.new("Frame")
    accGlow.Size = UDim2.new(0, 8, 0, 26)
    accGlow.Position = UDim2.new(0, 8, 0.5, -13)
    accGlow.BackgroundColor3 = color
    accGlow.BackgroundTransparency = 0.7
    accGlow.BorderSizePixel = 0
    accGlow.Parent = toast
    corner(accGlow, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -32, 1, 0)
    lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.Font = T.FM
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = toast

    tween(toast, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -140, 0, 20) }, 0.3, Enum.EasingStyle.Back)
    task.delay(2.6, function()
        if not toast.Parent then return end
        tween(toast, { BackgroundTransparency = 1, Position = UDim2.new(0.5, -140, 0, -40) }, 0.3)
        task.wait(0.4)
        if toast.Parent then toast:Destroy() end
    end)
end

local function toggleRow(parent, labelText, key, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FM
    lbl.TextSize = 13
    lbl.Parent = row

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 46, 0, 26)
    switch.Position = UDim2.new(1, -46, 0.5, -13)
    switch.BackgroundColor3 = Config[key] and T.Success or T.PanelAlt
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 13)
    stroke(switch, Config[key] and T.SuccessDark or T.Stroke, 1, 0.4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = Config[key] and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 10)

    local function refresh()
        local on = Config[key]
        tween(switch, { BackgroundColor3 = on and T.Success or T.PanelAlt }, 0.2)
        tween(knob, { Position = on and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10) }, 0.2)
    end

    switch.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        if key == "AutoRebirth" and Config[key] and not RebirthEvent then
            Config[key] = false
            notify("未找到重生事件", T.Danger)
        end
        refresh()
        if onToggle then onToggle(Config[key]) end
        saveConfig()
    end)
end

local function numberInput(parent, labelText, key, minV, maxV, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FM
    lbl.TextSize = 12
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -80, 1, 0)
    box.Position = UDim2.new(0, 80, 0, 0)
    box.BackgroundColor3 = T.PanelAlt
    box.Text = tostring(Config[key])
    box.TextColor3 = T.Text
    box.PlaceholderColor3 = T.TextDim
    box.Font = T.FM
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = row
    corner(box, 8)
    stroke(box, T.Stroke, 1, 0.4)

    box.Focused:Connect(function()
        tween(box, { BackgroundColor3 = T.PanelHi }, 0.15)
    end)
    box.FocusLost:Connect(function()
        tween(box, { BackgroundColor3 = T.PanelAlt }, 0.15)
        local n = tonumber(box.Text)
        if n and n >= minV and n <= maxV then
            box.Text = tostring(n)
            Config[key] = n
            if onChange then onChange(n) end
            saveConfig()
        else
            box.Text = tostring(Config[key])
            notify(string.format("需在 %d ~ %d 之间", minV, maxV), T.Danger)
        end
    end)
end

local FlyControls = Instance.new("Frame")
FlyControls.Size = UDim2.new(0, 260, 0, 160)
FlyControls.Position = UDim2.new(0.5, -130, 1, -180)
FlyControls.BackgroundColor3 = T.Panel
FlyControls.BackgroundTransparency = 0.25
FlyControls.Visible = false
FlyControls.ZIndex = 30
FlyControls.Parent = ScreenGui
corner(FlyControls, 20)
stroke(FlyControls, T.Accent, 1.2, 0.4)

local function flyButton(text, x, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 52, 0, 52)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color or T.PanelAlt
    b.BackgroundTransparency = 0.1
    b.Text = text
    b.TextColor3 = T.Text
    b.Font = T.FB
    b.TextSize = 22
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = FlyControls
    corner(b, 14)
    stroke(b, color or T.Accent, 1, 0.4)
    return b
end

local BtnUp    = flyButton("▲", 62, 6, T.Info)
local BtnDown  = flyButton("▼", 62, 108, T.Purple)
local BtnLeft  = flyButton("◀", 8, 57, T.PanelAlt)
local BtnRight = flyButton("▶", 116, 57, T.PanelAlt)
local BtnRise  = flyButton("＋", 178, 6, T.Success)
local BtnFall  = flyButton("－", 178, 108, T.Danger)

local function bindHold(btn, key)
    local function set(v)
        MobileInput[key] = v
        tween(btn, { BackgroundTransparency = v and 0.45 or 0.1 }, 0.1)
    end
    btn.MouseButton1Down:Connect(function() set(true) end)
    btn.MouseButton1Up:Connect(function() set(false) end)
    btn.MouseLeave:Connect(function() set(false) end)
end

bindHold(BtnUp, "Forward")
bindHold(BtnDown, "Back")
bindHold(BtnLeft, "Left")
bindHold(BtnRight, "Right")
bindHold(BtnRise, "Up")
bindHold(BtnFall, "Down")

local function clearMobileInput()
    for k in pairs(MobileInput) do MobileInput[k] = false end
    for _, b in ipairs({ BtnUp, BtnDown, BtnLeft, BtnRight, BtnRise, BtnFall }) do
        tween(b, { BackgroundTransparency = 0.1 }, 0.1)
    end
end

local powerCard = card(230, 1, T.Accent)
cardTitle(powerCard, "力量数据", T.Accent)

local function powerRow(parent, label, color)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 26)
    r.BackgroundColor3 = T.PanelAlt
    r.BackgroundTransparency = 0.6
    r.Parent = parent
    corner(r, 8)
    stroke(r, T.Stroke, 1, 0.7)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, -12, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.FM
    l.TextSize = 12
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.5, -12, 1, 0)
    v.Position = UDim2.new(0.5, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "—"
    v.TextColor3 = color or T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = T.FB
    v.TextSize = 13
    v.Parent = r
    return v
end

local rowStrength = powerRow(powerCard, "当前力量", T.Accent2)
local rowSession  = powerRow(powerCard, "本次增长", T.Success)
local rowBefore   = powerRow(powerCard, "训练前力量", T.Info)
local rowPerRep   = powerRow(powerCard, "每次增量", T.Purple)

local trainCard = card(250, 2, T.Success)
cardTitle(trainCard, "训练", T.Success)

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 32)
actionRow.BackgroundTransparency = 1
actionRow.Parent = trainCard

local actionLbl = Instance.new("TextLabel")
actionLbl.Size = UDim2.new(0, 70, 1, 0)
actionLbl.BackgroundTransparency = 1
actionLbl.Text = "动作"
actionLbl.TextColor3 = T.TextDim
actionLbl.TextXAlignment = Enum.TextXAlignment.Left
actionLbl.Font = T.FM
actionLbl.TextSize = 12
actionLbl.Parent = actionRow

local actionBtn = Instance.new("TextButton")
actionBtn.Size = UDim2.new(1, -70, 1, 0)
actionBtn.Position = UDim2.new(0, 70, 0, 0)
actionBtn.BackgroundColor3 = T.PanelAlt
actionBtn.Text = ActionNames[Config.Action] or Config.Action
actionBtn.TextColor3 = T.Text
actionBtn.Font = T.FM
actionBtn.TextSize = 12
actionBtn.AutoButtonColor = false
actionBtn.BorderSizePixel = 0
actionBtn.Parent = actionRow
corner(actionBtn, 8)
stroke(actionBtn, T.Stroke, 1, 0.4)

actionBtn.MouseEnter:Connect(function()
    tween(actionBtn, { BackgroundColor3 = T.PanelHi }, 0.15)
end)
actionBtn.MouseLeave:Connect(function()
    tween(actionBtn, { BackgroundColor3 = T.PanelAlt }, 0.15)
end)

local actionIndex = 1
for i, v in ipairs(Actions) do
    if v == Config.Action then actionIndex = i break end
end

actionBtn.MouseButton1Click:Connect(function()
    actionIndex = actionIndex % #Actions + 1
    Config.Action = Actions[actionIndex]
    actionBtn.Text = ActionNames[Config.Action] or Config.Action
    saveConfig()
    updateStatus()
end)

local intervalRow = Instance.new("Frame")
intervalRow.Size = UDim2.new(1, 0, 0, 32)
intervalRow.BackgroundTransparency = 1
intervalRow.Parent = trainCard

local intervalLbl = Instance.new("TextLabel")
intervalLbl.Size = UDim2.new(0, 70, 1, 0)
intervalLbl.BackgroundTransparency = 1
intervalLbl.Text = "间隔(秒)"
intervalLbl.TextColor3 = T.TextDim
intervalLbl.TextXAlignment = Enum.TextXAlignment.Left
intervalLbl.Font = T.FM
intervalLbl.TextSize = 12
intervalLbl.Parent = intervalRow

local intervalBox = Instance.new("TextBox")
intervalBox.Size = UDim2.new(1, -70, 1, 0)
intervalBox.Position = UDim2.new(0, 70, 0, 0)
intervalBox.BackgroundColor3 = T.PanelAlt
intervalBox.Text = tostring(Config.Interval)
intervalBox.TextColor3 = T.Text
intervalBox.PlaceholderText = "0.1"
intervalBox.PlaceholderColor3 = T.TextDim
intervalBox.Font = T.FM
intervalBox.TextSize = 12
intervalBox.ClearTextOnFocus = false
intervalBox.BorderSizePixel = 0
intervalBox.Parent = intervalRow
corner(intervalBox, 8)
stroke(intervalBox, T.Stroke, 1, 0.4)

intervalBox.Focused:Connect(function() tween(intervalBox, { BackgroundColor3 = T.PanelHi }, 0.15) end)
intervalBox.FocusLost:Connect(function()
    tween(intervalBox, { BackgroundColor3 = T.PanelAlt }, 0.15)
    local n = tonumber(intervalBox.Text)
    if n and n >= MIN_INTERVAL and n <= MAX_INTERVAL then
        Config.Interval = n
        intervalBox.Text = tostring(n)
        saveConfig()
    else
        intervalBox.Text = tostring(Config.Interval)
        notify(string.format("间隔需在 %.2f ~ %d 之间", MIN_INTERVAL, MAX_INTERVAL), T.Danger)
    end
end)

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 0, 46)
startBtn.BackgroundColor3 = T.Success
startBtn.Text = "开始训练"
startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
startBtn.Font = T.FB
startBtn.TextSize = 14
startBtn.AutoButtonColor = false
startBtn.BorderSizePixel = 0
startBtn.Parent = trainCard
corner(startBtn, 12)
local startGrad = gradientMulti(startBtn, {
    {0, Color3.fromRGB(140, 245, 175)},
    {1, Color3.fromRGB(40, 180, 90)},
}, 90)

updateStartBtn = function()
    if isTraining then
        startBtn.Text = "停止训练"
        startBtn.TextColor3 = Color3.fromRGB(40, 10, 14)
        startGrad.Color = ColorSequence.new(
            Color3.fromRGB(255, 170, 170),
            Color3.fromRGB(210, 60, 80)
        )
    else
        startBtn.Text = "开始训练"
        startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
        startGrad.Color = ColorSequence.new(
            Color3.fromRGB(140, 245, 175),
            Color3.fromRGB(40, 180, 90)
        )
    end
end

startBtn.MouseEnter:Connect(function() tween(startBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, { BackgroundTransparency = 0 }, 0.15) end)

local autoCard = card(230, 3, T.Purple)
cardTitle(autoCard, "自动化", T.Purple)

toggleRow(autoCard, "自动重生", "AutoRebirth")
toggleRow(autoCard, "反挂机", "AntiAfk")
toggleRow(autoCard, "自动重置角色", "AutoReset")
toggleRow(autoCard, "通知提示", "Notifications")

local rebirthProgress = Instance.new("TextLabel")
rebirthProgress.Size = UDim2.new(1, 0, 0, 20)
rebirthProgress.BackgroundColor3 = T.PanelAlt
rebirthProgress.BackgroundTransparency = 0.6
rebirthProgress.Text = "进度 0 / ∞"
rebirthProgress.TextColor3 = T.Purple
rebirthProgress.TextXAlignment = Enum.TextXAlignment.Center
rebirthProgress.Font = T.FB
rebirthProgress.TextSize = 11
rebirthProgress.Parent = autoCard
corner(rebirthProgress, 7)
stroke(rebirthProgress, T.Purple, 1, 0.6)

numberInput(autoCard, "重生次数", "AutoRebirthCount", 0, 99999, function(v)
    if v == 0 then
        rebirthProgress.Text = string.format("进度 %d / ∞", Config.AutoRebirthDone)
    else
        rebirthProgress.Text = string.format("进度 %d / %d", Config.AutoRebirthDone, v)
    end
end)

local resetRebirthBtn = Instance.new("TextButton")
resetRebirthBtn.Size = UDim2.new(1, 0, 0, 28)
resetRebirthBtn.BackgroundColor3 = T.PanelAlt
resetRebirthBtn.Text = "重置重生计数"
resetRebirthBtn.TextColor3 = T.Text
resetRebirthBtn.Font = T.FM
resetRebirthBtn.TextSize = 12
resetRebirthBtn.AutoButtonColor = false
resetRebirthBtn.BorderSizePixel = 0
resetRebirthBtn.Parent = autoCard
corner(resetRebirthBtn, 8)
stroke(resetRebirthBtn, T.Stroke, 1, 0.4)

resetRebirthBtn.MouseEnter:Connect(function()
    tween(resetRebirthBtn, { BackgroundColor3 = T.PanelHi }, 0.15)
end)
resetRebirthBtn.MouseLeave:Connect(function()
    tween(resetRebirthBtn, { BackgroundColor3 = T.PanelAlt }, 0.15)
end)

resetRebirthBtn.MouseButton1Click:Connect(function()
    Config.AutoRebirthDone = 0
    saveConfig()
    if Config.AutoRebirthCount == 0 then
        rebirthProgress.Text = "进度 0 / ∞"
    else
        rebirthProgress.Text = string.format("进度 0 / %d", Config.AutoRebirthCount)
    end
    notify("已重置重生计数", T.Info)
end)

if Config.AutoRebirthCount == 0 then
    rebirthProgress.Text = string.format("进度 %d / ∞", Config.AutoRebirthDone)
else
    rebirthProgress.Text = string.format("进度 %d / %d", Config.AutoRebirthDone, Config.AutoRebirthCount)
end

local moveCard = card(230, 4, T.Info)
cardTitle(moveCard, "移动", T.Info)

applyWalkSpeed = function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Config.WalkSpeed end
end

startFly = function()
    if flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 3000
    flyBG.D = 500
    flyBG.Parent = hrp

    flying = true
end

stopFly = function()
    if not flying then return end
    flying = false
    clearMobileInput()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    applyWalkSpeed()
end

RunService.RenderStepped:Connect(function()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then stopFly() return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBV or not flyBG then return end

    local cam = workspace.CurrentCamera
    local dir = Vector3.zero

    local fwd = UserInputService:IsKeyDown(Enum.KeyCode.W) or MobileInput.Forward
    local bck = UserInputService:IsKeyDown(Enum.KeyCode.S) or MobileInput.Back
    local lft = UserInputService:IsKeyDown(Enum.KeyCode.A) or MobileInput.Left
    local rgt = UserInputService:IsKeyDown(Enum.KeyCode.D) or MobileInput.Right
    local up  = UserInputService:IsKeyDown(Enum.KeyCode.Space) or MobileInput.Up
    local dn  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or MobileInput.Down

    if fwd then dir = dir + cam.CFrame.LookVector end
    if bck then dir = dir - cam.CFrame.LookVector end
    if lft then dir = dir - cam.CFrame.RightVector end
    if rgt then dir = dir + cam.CFrame.RightVector end
    if up  then dir = dir + Vector3.new(0, 1, 0) end
    if dn  then dir = dir - Vector3.new(0, 1, 0) end

    if dir.Magnitude > 0 then dir = dir.Unit * flySpeed end
    flyBV.Velocity = dir
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    applyWalkSpeed()
    if flying then
        flying = false
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if Config.Fly then startFly() end
    end
end)

toggleRow(moveCard, "飞行模式", "Fly", function(on)
    if on then
        startFly()
        if IS_TOUCH then FlyControls.Visible = true end
        if IS_TOUCH then
            notify("飞行已开启，使用屏幕方向键控制", T.Info)
        else
            notify("飞行已开启（空格上升 / 左Ctrl下降）", T.Info)
        end
    else
        stopFly()
        FlyControls.Visible = false
        notify("飞行已关闭", T.Danger)
    end
end)

numberInput(moveCard, "步行速度", "WalkSpeed", 16, 500, function(v)
    Config.WalkSpeed = v
    applyWalkSpeed()
end)

numberInput(moveCard, "飞行速度", "FlySpeed", 10, 500, function(v)
    flySpeed = v
end)

local statCard = card(210, 5, T.Pink)
cardTitle(statCard, "统计", T.Pink)

local function statRow(parent, label)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 26)
    r.BackgroundColor3 = T.PanelAlt
    r.BackgroundTransparency = 0.6
    r.Parent = parent
    corner(r, 8)
    stroke(r, T.Stroke, 1, 0.7)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, -12, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.FM
    l.TextSize = 12
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.4, -12, 1, 0)
    v.Position = UDim2.new(0.6, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "0"
    v.TextColor3 = T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = T.FB
    v.TextSize = 13
    v.Parent = r
    return v
end

local statSession = statRow(statCard, "本次训练")
local statTotal = statRow(statCard, "累计训练")
local statRate = statRow(statCard, "每秒平均")

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, 0, 0, 68)
Bottom.Position = UDim2.new(0, 0, 1, -68)
Bottom.BackgroundColor3 = T.Panel
Bottom.BackgroundTransparency = 0.1
Bottom.BorderSizePixel = 0
Bottom.ZIndex = 3
Bottom.Parent = Main

local bottomLine = Instance.new("Frame")
bottomLine.Size = UDim2.new(1, 0, 0, 1)
bottomLine.BackgroundColor3 = T.Accent
bottomLine.BackgroundTransparency = 0.6
bottomLine.BorderSizePixel = 0
bottomLine.ZIndex = 4
bottomLine.Parent = Bottom
gradient(bottomLine, T.Accent, T.Purple, 0)

local statusDotGlow = Instance.new("Frame")
statusDotGlow.Size = UDim2.new(0, 16, 0, 16)
statusDotGlow.Position = UDim2.new(0, 18, 0, 20)
statusDotGlow.BackgroundColor3 = T.Danger
statusDotGlow.BackgroundTransparency = 0.7
statusDotGlow.BorderSizePixel = 0
statusDotGlow.ZIndex = 4
statusDotGlow.Parent = Bottom
corner(statusDotGlow, 8)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 22, 0, 24)
statusDot.BackgroundColor3 = T.Danger
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 5
statusDot.Parent = Bottom
corner(statusDot, 4)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -50, 0, 20)
statusLbl.Position = UDim2.new(0, 42, 0, 18)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "空闲"
statusLbl.TextColor3 = T.Text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = T.FB
statusLbl.TextSize = 13
statusLbl.ZIndex = 5
statusLbl.Parent = Bottom

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -60, 0, 16)
hintLbl.Position = UDim2.new(0, 42, 0, 40)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = IS_TOUCH and "拖动标题移动 · 触摸方向键飞行" or "拖动标题移动 · 右下角缩放 · ◎ 收缩 · Insert 隐藏 · RShift 开始/停止"
hintLbl.TextColor3 = T.TextSub
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Font = T.F
hintLbl.TextSize = 10
hintLbl.ZIndex = 5
hintLbl.Parent = Bottom

local ResizeGrip = Instance.new("Frame")
ResizeGrip.Size = UDim2.new(0, 18, 0, 18)
ResizeGrip.Position = UDim2.new(1, -22, 1, -22)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.ZIndex = 20
ResizeGrip.Parent = Main

for i = 1, 3 do
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 3, 0, 3)
    dot.Position = UDim2.new(0, 15 - i * 5, 0, 15 - i * 5)
    dot.BackgroundColor3 = T.Accent
    dot.BorderSizePixel = 0
    dot.Parent = ResizeGrip
    corner(dot, 2)
end

local ResizeBtn = Instance.new("TextButton")
ResizeBtn.Size = UDim2.new(1, 0, 1, 0)
ResizeBtn.BackgroundTransparency = 1
ResizeBtn.Text = ""
ResizeBtn.AutoButtonColor = false
ResizeBtn.Parent = ResizeGrip

local BallBtn = Instance.new("TextButton")
BallBtn.Size = UDim2.new(1, 0, 1, 0)
BallBtn.BackgroundTransparency = 1
BallBtn.Text = "力"
BallBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
BallBtn.Font = T.FB
BallBtn.TextSize = 24
BallBtn.AutoButtonColor = false
BallBtn.Visible = false
BallBtn.ZIndex = 25
BallBtn.Parent = Main

updateStatus = function()
    if isTraining then
        statusDot.BackgroundColor3 = T.Success
        statusDotGlow.BackgroundColor3 = T.Success
        HeaderDot.BackgroundColor3 = T.Success
        HeaderDotGlow.BackgroundColor3 = T.Success
        statusLbl.Text = "训练中  ·  " .. (ActionNames[Config.Action] or Config.Action)
        if isCollapsed then Main.BackgroundColor3 = T.Success end
    else
        statusDot.BackgroundColor3 = T.Danger
        statusDotGlow.BackgroundColor3 = T.Danger
        HeaderDot.BackgroundColor3 = T.Danger
        HeaderDotGlow.BackgroundColor3 = T.Danger
        statusLbl.Text = "空闲"
        if isCollapsed then Main.BackgroundColor3 = T.Danger end
    end
end

collapse = function()
    if isCollapsed then return end
    savedSize = Main.Size
    isCollapsed = true
    accentBar.Visible = false
    accentGlow.Visible = false
    Header.Visible = false
    Content.Visible = false
    Bottom.Visible = false
    ResizeGrip.Visible = false
    innerHighlight.Visible = false
    mainCorner.CornerRadius = UDim.new(1, 0)
    mainStroke.Transparency = 0.2
    bgGrad.Color = ColorSequence.new(
        isTraining and T.Success or T.Danger,
        isTraining and T.SuccessDark or T.DangerDark
    )
    tween(Main, {
        Size = UDim2.new(0, COLLAPSED, 0, COLLAPSED),
        BackgroundColor3 = isTraining and T.Success or T.Danger,
    }, 0.3, Enum.EasingStyle.Back)
    BallBtn.Visible = true
end

expand = function()
    if not isCollapsed then return end
    isCollapsed = false
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainStroke.Transparency = 0.55
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T.BG1),
        ColorSequenceKeypoint.new(0.5, T.BG0),
        ColorSequenceKeypoint.new(1, T.BG2),
    })
    tween(Main, {
        Size = savedSize or UDim2.new(0, W, 0, H),
        BackgroundColor3 = T.BG0,
    }, 0.3, Enum.EasingStyle.Back)
    accentBar.Visible = true
    accentGlow.Visible = true
    Header.Visible = true
    Content.Visible = true
    Bottom.Visible = true
    ResizeGrip.Visible = true
    innerHighlight.Visible = true
    BallBtn.Visible = false
end

startAutoTrain = function()
    if isTraining then return end
    if not TrainEvent then notify("未找到训练事件", T.Danger) return end
    isTraining = true
    trainCount = 0
    startTime = tick()
    if refreshStrengthSource() then sessionStartStrength = getStrength() end
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
    updateStatus()
end

stopAutoTrain = function()
    if not isTraining then return end
    isTraining = false
    if trainThread then
        pcall(task.cancel, trainThread)
        trainThread = nil
    end
    saveConfig()
    updateStatus()
end

startBtn.MouseButton1Click:Connect(function()
    if isTraining then
        stopAutoTrain()
        notify("已停止训练", T.Danger)
    else
        startAutoTrain()
        if isTraining then notify("已开始自动训练", T.Success) end
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

do
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    BallBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if not moved then expand() end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then moved = true end
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

do
    local resizing = false
    local resizeStart, startSize
    ResizeBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = Main.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - resizeStart
            local nw = math.clamp(startSize.X + delta.X, MIN_W, MAX_W)
            local nh = math.clamp(startSize.Y + delta.Y, MIN_H, MAX_H)
            Main.Size = UDim2.new(0, nw, 0, nh)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                savedSize = Main.Size
            end
        end
    end)
end

MinBtn.MouseButton1Click:Connect(function() collapse() end)

local Connections = {}
local function track(c)
    if c then table.insert(Connections, c) end
    return c
end

CloseBtn.MouseButton1Click:Connect(function()
    stopAutoTrain()
    stopFly()
    saveConfig()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    tween(Main, { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 }, 0.3)
    task.wait(0.35)
    if ScreenGui.Parent then ScreenGui:Destroy() end
end)

task.spawn(function()
    while ScreenGui.Parent do
        local elapsed = isTraining and (tick() - startTime) or 0
        local aps = elapsed > 0 and (trainCount / elapsed) or 0
        statSession.Text = tostring(trainCount)
        statTotal.Text = tostring(totalCount)
        statRate.Text = string.format("%.2f", aps)

        refreshStrengthSource()
        local cur = getStrength()
        if sessionStartStrength == nil then sessionStartStrength = cur end
        local gain = cur - sessionStartStrength

        rowStrength.Text = fmt(cur)
        rowSession.Text = (gain >= 0 and "+" or "") .. fmt(gain)
        rowBefore.Text = fmt(sessionStartStrength)
        rowSession.TextColor3 = gain > 0 and T.Success or (gain < 0 and T.Danger or T.Text)

        if trainCount > 0 and gain > 0 then
            rowPerRep.Text = string.format("%.2f", gain / trainCount)
        else
            rowPerRep.Text = "—"
        end

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
            local target = Config.AutoRebirthCount
            local done = Config.AutoRebirthDone
            if target > 0 and done >= target then
                if Config.AutoRebirth then
                    Config.AutoRebirth = false
                    saveConfig()
                    notify("已达成重生目标 " .. target .. " 次", T.Success)
                end
            else
                pcall(function() RebirthEvent:FireServer("Start") end)
                task.wait(0.5)
                pcall(function() RebirthEvent:FireServer("Update") end)
                Config.AutoRebirthDone = done + 1
                saveConfig()
                if target == 0 then
                    rebirthProgress.Text = string.format("进度 %d / ∞", Config.AutoRebirthDone)
                else
                    rebirthProgress.Text = string.format("进度 %d / %d", Config.AutoRebirthDone, target)
                end
            end
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
            notify("已停止训练", T.Danger)
        else
            startAutoTrain()
            if isTraining then notify("已开始自动训练", T.Success) end
        end
        updateStartBtn()
        updateStatus()
    end
end))

updateStartBtn()
updateStatus()
refreshStrengthSource()
applyWalkSpeed()

if Config.AutoStart then
    startAutoTrain()
    updateStartBtn()
    updateStatus()
end

if Config.Fly then
    task.defer(function()
        startFly()
        if IS_TOUCH then FlyControls.Visible = true end
    end)
end

if Config.MinimizeOnStart then
    task.defer(collapse)
end

notify("力量之冠 v1.0 已加载", T.Accent)