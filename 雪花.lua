local function prop(v)
    if type(v) == "string" then
        return string.format("%q", v)
    elseif typeof(v) == "UDim2" then
        return string.format("UDim2.new(%f, %d, %f, %d)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif typeof(v) == "UDim" then
        return string.format("UDim.new(%f, %d)", v.Scale, v.Offset)
    elseif typeof(v) == "Vector2" then
        return string.format("Vector2.new(%f, %f)", v.X, v.Y)
    elseif typeof(v) == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5))
    elseif typeof(v) == "EnumItem" then
        return "Enum." .. tostring(v.EnumType) .. "." .. v.Name
    else
        return tostring(v)
    end
end

local output = {"-- UI \233\135\141\229\187\186\228\187\163\231\160\129", ""}

local function walk(inst, indent)
    local i = string.rep("    ", indent)
    local props = ""
    local nameVar = "V_" .. indent .. "_" .. inst.ClassName .. "_" .. tostring(math.random(10000, 99999))

    if inst:IsA("GuiObject") then
        props = props .. "\n" .. i .. "    Size = " .. prop(inst.Size)
        props = props .. ",\n" .. i .. "    Position = " .. prop(inst.Position)
        props = props .. ",\n" .. i .. "    AnchorPoint = " .. prop(inst.AnchorPoint)
        props = props .. ",\n" .. i .. "    BackgroundColor3 = " .. prop(inst.BackgroundColor3)
        props = props .. ",\n" .. i .. "    BackgroundTransparency = " .. inst.BackgroundTransparency
        props = props .. ",\n" .. i .. "    BorderSizePixel = " .. inst.BorderSizePixel
        props = props .. ",\n" .. i .. "    Visible = " .. tostring(inst.Visible)
        props = props .. ",\n" .. i .. "    ZIndex = " .. inst.ZIndex
        props = props .. ",\n" .. i .. "    ClipsDescendants = " .. tostring(inst.ClipsDescendants)
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            props = props .. ",\n" .. i .. "    Text = " .. prop(inst.Text)
            props = props .. ",\n" .. i .. "    TextColor3 = " .. prop(inst.TextColor3)
            props = props .. ",\n" .. i .. "    TextSize = " .. inst.TextSize
            props = props .. ",\n" .. i .. "    Font = " .. prop(inst.Font)
            props = props .. ",\n" .. i .. "    TextXAlignment = " .. prop(inst.TextXAlignment)
            props = props .. ",\n" .. i .. "    TextYAlignment = " .. prop(inst.TextYAlignment)
            if inst:IsA("TextBox") then
                props = props .. ",\n" .. i .. "    PlaceholderText = " .. prop(inst.PlaceholderText)
            end
        end
        if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
            props = props .. ",\n" .. i .. "    Image = " .. prop(inst.Image)
        end
    end

    table.insert(output, i .. "local " .. nameVar .. " = Instance.new(" .. prop(inst.ClassName) .. ")")
    table.insert(output, i .. nameVar .. ".Name = " .. prop(inst.Name))
    if props ~= "" then
        table.insert(output, i .. nameVar .. props)
    end

    if inst.Parent and inst.Parent ~= game then
        table.insert(output, i .. nameVar .. ".Parent = " .. (inst.Parent.Name or "game"))
    end

    for _, child in ipairs(inst:GetChildren()) do
        if not child:IsA("Script") and not child:IsA("LocalScript") and not child:IsA("ModuleScript") then
            walk(child, indent + 1)
        end
    end
    table.insert(output, "")
end

for _, root in ipairs({game:GetService("Players").LocalPlayer.PlayerGui, game:GetService("CoreGui")}) do
    for _, gui in ipairs(root:GetChildren()) do
        if gui:IsA("ScreenGui") then
            table.insert(output, "-- " .. gui.Name .. " (\229\156\168 " .. root.Name .. ")")
            walk(gui, 0)
        end
    end
end

local text = table.concat(output, "\n")

local ok = false
if type(writefile) == "function" then
    ok = pcall(function()
        writefile("ui_source.txt", text)
    end)
end

if ok then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "\230\136\144\229\138\159",
            Text = "\229\183\178\228\191\157\229\173\152\229\136\176 ui_source.txt",
            Duration = 10,
        })
    end)
else
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "\229\164\177\232\180\165",
            Text = "\230\151\160\230\179\149\229\134\153\229\133\165\230\150\135\228\187\182\239\188\140\232\175\183\231\156\139\230\142\167\229\136\182\229\143\176",
            Duration = 10,
        })
    end)
    print(text)
end