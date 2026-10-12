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
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }
local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10
local MIN_W, MIN_H, MAX_W, MAX_H = 260, 320, 640, 900
local COLLAPSED = 56

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
    BG = Color3.fromRGB(15, 16, 21), Panel = Color3.fromRGB(24, 26, 34),
    PanelAlt = Color3.fromRGB(34, 37, 47), Stroke = Color3.fromRGB(46, 50, 64),
    Text = Color3.fromRGB(232, 234, 240), TextDim = Color3.fromRGB(122, 127, 145),
    Accent = Color3.fromRGB(245, 179, 61), AccentDark = Color3.fromRGB(196, 136, 30),
    Success = Color3.fromRGB(74, 222, 128), Danger = Color3.fromRGB(248, 113, 113),
    Purple = Color3.fromRGB(167, 139, 250), Info = Color3.fromRGB(96, 165, 250),
    F = Enum.Font.Gotham, FB = Enum.Font.GothamBold, FM = Enum.Font.GothamMedium,
}

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end

local function stroke(p, c, t)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Stroke; s.Thickness = t or 1
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

local function tween(o, props, dur)
    local tw = TweenService:Create(o, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
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

local W, H = 340, 700

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(0, 40, 0.5, -H / 2)
Main.BackgroundColor3 = T.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local mainCorner = corner(Main, 16)
stroke(Main, T.Stroke, 1)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 2)
accentBar.BackgroundColor3 = T.Accent
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 5
accentBar.Parent = Main
gradient(accentBar, T.Accent, T.Purple, 0)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 56)
Header.BackgroundColor3 = T.Panel
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderGlow = Instance.new("Frame")
HeaderGlow.Size = UDim2.new(1, 0, 1, 0)
HeaderGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderGlow.BackgroundTransparency = 0.95
HeaderGlow.BorderSizePixel = 0
HeaderGlow.Parent = Header
gradient(HeaderGlow, T.Accent, T.Purple, 25)

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = T.Stroke
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Header

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 30, 0, 30)
Logo.Position = UDim2.new(0, 16, 0.5, -15)
Logo.BackgroundColor3 = T.Accent
Logo.BorderSizePixel = 0
Logo.Parent = Header
corner(Logo, 9)
gradient(Logo, T.Accent, T.AccentDark, 90)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "力"
LogoText.TextColor3 = Color3.fromRGB(30, 20, 0)
LogoText.Font = T.FB
LogoText.TextSize = 16
LogoText.Parent = Logo

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -160, 0, 18)
TitleLbl.Position = UDim2.new(0, 56, 0, 10)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "力量之冠"
TitleLbl.TextColor3 = T.Text
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Font = T.FB
TitleLbl.TextSize = 13
TitleLbl.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -160, 0, 14)
SubTitle.Position = UDim2.new(0, 56, 0, 28)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "自动训练器  ·  v1.0"
SubTitle.TextColor3 = T.TextDim
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.F
SubTitle.TextSize = 10
SubTitle.Parent = Header

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 8, 0, 8)
HeaderDot.Position = UDim2.new(1, -104, 0.5, -4)
HeaderDot.BackgroundColor3 = T.Danger
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
    b.TextColor3 = T.Text
    b.Font = T.FB
    b.TextSize = 15
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = Header
    corner(b, 7)
    b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.25 }, 0.15) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0.55 }, 0.15) end)
    return b
end

local CloseBtn = headerButton("×", T.Danger, -40)
local MinBtn = headerButton("◎", T.PanelAlt, -74)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -120)
Content.Position = UDim2.new(0, 0, 0, 56)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = T.Stroke
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
    bar.BackgroundColor3 = T.Accent
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = T.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FB
    lbl.TextSize = 11
    lbl.Parent = row
end

local function card(height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = T.Panel
    f.BorderSizePixel = 0
    f.Parent = Content
    corner(f, 12)
    stroke(f, T.Stroke, 1)
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
    toast.BackgroundColor3 = T.Panel
    toast.BackgroundTransparency = 1
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = ScreenGui
    corner(toast, 10)
    stroke(toast, color or T.Accent, 1)

    local acc = Instance.new("Frame")
    acc.Size = UDim2.new(0, 3, 0, 20)
    acc.Position = UDim2.new(0, 8, 0.5, -10)
    acc.BackgroundColor3 = color or T.Accent
    acc.BorderSizePixel = 0
    acc.Parent = toast
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -26, 1, 0)
    lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.Font = T.FM
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

local function toggleRow(parent, labelText, key, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FM
    lbl.TextSize = 12
    lbl.Parent = row

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 44, 0, 24)
    switch.Position = UDim2.new(1, -44, 0.5, -12)
    switch.BackgroundColor3 = Config[key] and T.Success or T.PanelAlt
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 12)
    stroke(switch, T.Stroke, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = Config[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 9)

    local function refresh()
        local on = Config[key]
        tween(switch, { BackgroundColor3 = on and T.Success or T.PanelAlt }, 0.15)
        tween(knob, { Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, 0.15)
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
    row.Size = UDim2.new(1, 0, 0, 30)
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
    corner(box, 7)
    stroke(box, T.Stroke, 1)

    box.FocusLost:Connect(function()
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

sectionTitle("力量数据")
local powerCard = card(140)

local function powerRow(label, color)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 22)
    r.BackgroundTransparency = 1
    r.Parent = powerCard

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.FM
    l.TextSize = 12
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.5, 0, 1, 0)
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

local rowStrength = powerRow("当前力量", T.Accent)
local rowSession  = powerRow("本次增长", T.Success)
local rowBefore   = powerRow("训练前力量", T.Info)
local rowPerRep   = powerRow("每次增量", T.Purple)

sectionTitle("训练")
local trainCard = card(160)

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 30)
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
corner(actionBtn, 7)
stroke(actionBtn, T.Stroke, 1)

actionBtn.MouseEnter:Connect(function() tween(actionBtn, { BackgroundColor3 = Color3.fromRGB(44, 48, 60) }, 0.15) end)
actionBtn.MouseLeave:Connect(function() tween(actionBtn, { BackgroundColor3 = T.PanelAlt }, 0.15) end)

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
intervalRow.Size = UDim2.new(1, 0, 0, 30)
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
corner(intervalBox, 7)
stroke(intervalBox, T.Stroke, 1)

intervalBox.FocusLost:Connect(function()
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
startBtn.Size = UDim2.new(1, 0, 0, 40)
startBtn.BackgroundColor3 = T.Success
startBtn.Text = "开始训练"
startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
startBtn.Font = T.FB
startBtn.TextSize = 14
startBtn.AutoButtonColor = false
startBtn.BorderSizePixel = 0
startBtn.Parent = trainCard
corner(startBtn, 9)
local startGrad = gradient(startBtn, Color3.fromRGB(110, 231, 152), Color3.fromRGB(52, 190, 100), 90)

updateStartBtn = function()
    if isTraining then
        startBtn.Text = "停止训练"
        startBtn.BackgroundColor3 = T.Danger
        startBtn.TextColor3 = Color3.fromRGB(40, 10, 14)
        startGrad.Color = ColorSequence.new(Color3.fromRGB(255, 160, 160), Color3.fromRGB(210, 70, 90))
    else
        startBtn.Text = "开始训练"
        startBtn.BackgroundColor3 = T.Success
        startBtn.TextColor3 = Color3.fromRGB(10, 20, 14)
        startGrad.Color = ColorSequence.new(Color3.fromRGB(110, 231, 152), Color3.fromRGB(52, 190, 100))
    end
end

startBtn.MouseEnter:Connect(function() tween(startBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, { BackgroundTransparency = 0 }, 0.15) end)

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

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

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

sectionTitle("自动化")
local autoCard = card(172)

toggleRow(autoCard, "自动重生", "AutoRebirth")
toggleRow(autoCard, "反挂机", "AntiAfk")
toggleRow(autoCard, "自动重置角色", "AutoReset")
toggleRow(autoCard, "通知提示", "Notifications")

sectionTitle("移动")
local moveCard = card(130)

toggleRow(moveCard, "飞行模式", "Fly", function(on)
    if on then
        startFly()
        notify("飞行已开启（空格上升 / 左Ctrl下降）", T.Info)
    else
        stopFly()
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

sectionTitle("统计")
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
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.FM
    l.TextSize = 12
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.4, 0, 1, 0)
    v.Position = UDim2.new(0.6, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "0"
    v.TextColor3 = T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = T.FB
    v.TextSize = 12
    v.Parent = r
    return v
end

local statSession = statRow("本次训练")
local statTotal = statRow("累计训练")
local statRate = statRow("每秒平均")

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, 0, 0, 64)
Bottom.Position = UDim2.new(0, 0, 1, -64)
Bottom.BackgroundColor3 = T.Panel
Bottom.BorderSizePixel = 0
Bottom.Parent = Main

local bottomLine = Instance.new("Frame")
bottomLine.Size = UDim2.new(1, 0, 0, 1)
bottomLine.BackgroundColor3 = T.Stroke
bottomLine.BorderSizePixel = 0
bottomLine.Parent = Bottom

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 16, 0, 18)
statusDot.BackgroundColor3 = T.Danger
statusDot.BorderSizePixel = 0
statusDot.Parent = Bottom
corner(statusDot, 4)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -50, 0, 20)
statusLbl.Position = UDim2.new(0, 32, 0, 12)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "空闲"
statusLbl.TextColor3 = T.Text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = T.FM
statusLbl.TextSize = 12
statusLbl.Parent = Bottom

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -60, 0, 16)
hintLbl.Position = UDim2.new(0, 16, 0, 36)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = "拖动标题移动 · 右下角缩放 · ◎ 收缩"
hintLbl.TextColor3 = T.TextDim
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Font = T.F
hintLbl.TextSize = 10
hintLbl.Parent = Bottom

local ResizeGrip = Instance.new("Frame")
ResizeGrip.Size = UDim2.new(0, 16, 0, 16)
ResizeGrip.Position = UDim2.new(1, -18, 1, -18)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.ZIndex = 20
ResizeGrip.Parent = Main

for i = 1, 3 do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 2, 0, 2)
    line.Position = UDim2.new(0, 14 - i * 4, 0, 14 - i * 4)
    line.BackgroundColor3 = T.TextDim
    line.BorderSizePixel = 0
    line.Parent = ResizeGrip
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
        HeaderDot.BackgroundColor3 = T.Success
        statusLbl.Text = "训练中  ·  " .. (ActionNames[Config.Action] or Config.Action)
        if isCollapsed then Main.BackgroundColor3 = T.Success end
    else
        statusDot.BackgroundColor3 = T.Danger
        HeaderDot.BackgroundColor3 = T.Danger
        statusLbl.Text = "空闲"
        if isCollapsed then Main.BackgroundColor3 = T.Danger end
    end
end

collapse = function()
    if isCollapsed then return end
    savedSize = Main.Size
    isCollapsed = true
    accentBar.Visible = false
    Header.Visible = false
    Content.Visible = false
    Bottom.Visible = false
    ResizeGrip.Visible = false
    mainCorner.CornerRadius = UDim.new(1, 0)
    tween(Main, {
        Size = UDim2.new(0, COLLAPSED, 0, COLLAPSED),
        BackgroundColor3 = isTraining and T.Success or T.Danger,
    }, 0.25)
    BallBtn.Visible = true
end

expand = function()
    if not isCollapsed then return end
    isCollapsed = false
    mainCorner.CornerRadius = UDim.new(0, 16)
    tween(Main, {
        Size = savedSize or UDim2.new(0, W, 0, H),
        BackgroundColor3 = T.BG,
    }, 0.25)
    accentBar.Visible = true
    Header.Visible = true
    Content.Visible = true
    Bottom.Visible = true
    ResizeGrip.Visible = true
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
            pcall(function() RebirthEvent:FireServer("Start") end)
            task.wait(0.5)
            pcall(function() RebirthEvent:FireServer("Update") end)
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
    task.defer(startFly)
end

if Config.MinimizeOnStart then
    task.defer(collapse)
end

notify("力量之冠 v1.0 已加载", T.Accent)