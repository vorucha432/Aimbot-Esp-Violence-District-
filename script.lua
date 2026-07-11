--[[
    Violence District – ESP + Silent Aim + Object ESP + FullBright [PROSTO]
    – Player ESP: игроки подсвечены (выжившие зелёным, убийца красным) + Ники над головами
    – Object ESP: только генераторы, палетки, места для перелезания (Vault) и для подвешивания (Hooks)
    – Подсветка объектов через чистые цветные Highlights (без надписей и текста)
    – Настройка цвета каждого объекта через палитру Rayfield по твоему выбору
    – FullBright: убирает туман, тени и делает мир светлым
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==============================
-- ПРОСТОЙ ПОИСК БЛИЖАЙШЕГО ИГРОКА
-- ==============================
local function GetClosestPlayer()
    local closest, minDist
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local pr = plr.Character:FindFirstChild("HumanoidRootPart")
            if pr then
                local d = (pr.Position - root.Position).Magnitude
                if not minDist or d < minDist then
                    minDist = d
                    closest = plr
                end
            end
        end
    end
    return closest
end

-- ==============================
-- НАСТРОЙКИ И ПЕРЕМЕННЫЕ
-- ==============================
local espEnabled = false
local showNames = false
local silentAim = false
local aimSmooth = 0.3
local fullBrightEnabled = false

-- Настройки Object ESP
local objectEspEnabled = false
local colors = {
    Generator = Color3.fromRGB(0, 180, 255),
    Pallet = Color3.fromRGB(255, 200, 0),
    Vault = Color3.fromRGB(0, 255, 100),
    Hook = Color3.fromRGB(255, 50, 50)
}

local Connections = {}
local Cache = {} 
local ObjectCache = {}

-- Переменные для бэкапа оригинального освещения
local origBrightness = Lighting.Brightness
local origClockTime = Lighting.ClockTime
local origFogEnd = Lighting.FogEnd
local origGlobalShadows = Lighting.GlobalShadows

-- ==============================
-- ОЧИСТКА ESP И ОБЪЕКТОВ
-- ==============================
local function ClearESP()
    -- Чистим игроков
    for char, elements in pairs(Cache) do
        if elements.Highlight then elements.Highlight:Destroy() end
        if elements.Billboard then elements.Billboard:Destroy() end
    end
    table.clear(Cache)
    
    -- Чистим объекты
    for _, hl in pairs(ObjectCache) do
        if hl then hl:Destroy() end
    end
    table.clear(ObjectCache)
    
    -- Чистка остатков
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character then
            local hl = plr.Character:FindFirstChild("VD_ESP")
            if hl then hl:Destroy() end
            local head = plr.Character:FindFirstChild("Head")
            local bill = head and head:FindFirstChild("VD_Name")
            if bill then bill:Destroy() end
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "VD_ObjESP" then
            obj:Destroy()
        end
    end
end

local function StopLoop(name)
    if Connections[name] then
        Connections[name]:Disconnect()
        Connections[name] = nil
    end
end

-- ==============================
-- PLAYER ESP
-- ==============================
local function ESPLoop()
    StopLoop("ESP")
    if not espEnabled then 
        for char, elements in pairs(Cache) do
            if elements.Highlight then elements.Highlight:Destroy(); elements.Highlight = nil end
            if elements.Billboard then elements.Billboard:Destroy(); elements.Billboard = nil end
        end
        return 
    end

    Connections.ESP = RunService.Heartbeat:Connect(function()
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head")
                
                if hum and hum.Health > 0 then
                    local isKiller = false
                    if plr.Team and plr.Team.Name == "Killer" then isKiller = true end
                    if plr:GetAttribute("Role") == "Killer" then isKiller = true end
                    if plr.Name:lower():find("killer") or plr.Name:lower():find("slasher") then isKiller = true end

                    local color = isKiller and Color3.new(1,0,0) or Color3.new(0,1,0)

                    if not Cache[char] then
                        Cache[char] = {}
                    end

                    local hl = Cache[char].Highlight or char:FindFirstChild("VD_ESP")
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "VD_ESP"
                        hl.Parent = char
                        Cache[char].Highlight = hl
                    end
                    hl.Adornee = char
                    hl.FillColor = color
                    hl.OutlineColor = color
                    hl.FillTransparency = 0.5

                    if showNames and head then
                        local bill = Cache[char].Billboard or head:FindFirstChild("VD_Name")
                        if not bill then
                            bill = Instance.new("BillboardGui")
                            bill.Name = "VD_Name"
                            bill.Size = UDim2.new(0, 150, 0, 30)
                            bill.StudsOffset = Vector3.new(0, 2.5, 0)
                            bill.AlwaysOnTop = true
                            
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1,0,1,0)
                            label.BackgroundTransparency = 1
                            label.TextStrokeColor3 = Color3.new(0,0,0)
                            label.TextStrokeTransparency = 0
                            label.Font = Enum.Font.GothamBold
                            label.TextSize = 14
                            label.Parent = bill
                            
                            bill.Parent = head
                            Cache[char].Billboard = bill
                        end
                        bill.TextLabel.Text = plr.Name
                        bill.TextLabel.TextColor3 = color
                    else
                        if Cache[char].Billboard then
                            Cache[char].Billboard:Destroy()
                            Cache[char].Billboard = nil
                        end
                    end
                else
                    if Cache[char] then
                        if Cache[char].Highlight then Cache[char].Highlight:Destroy() end
                        if Cache[char].Billboard then Cache[char].Billboard:Destroy() end
                        Cache[char] = nil
                    end
                end
            end
        end
        
        for char, _ in pairs(Cache) do
            if not char or not char.Parent then
                Cache[char] = nil
            end
        end
    end)
end

-- ==============================
-- OBJECT ESP (Генераторы, Палетки, Окна, Крюки)
-- ==============================
local function GetObjectType(obj)
    local name = obj.Name:lower()
    
    if name:find("generator") then
        return "Generator"
    elseif name:find("pallet") or name:find("board") then
        return "Pallet"
    elseif name:find("vault") or name:find("window") or name:find("obstacle") then
        return "Vault"
    elseif name:find("hook") or name:find("hanger") or name:find("suspend") then
        return "Hook"
    end
    return nil
end

local function ApplyObjectESP(obj)
    if not objectEspEnabled then return end
    
    local objType = GetObjectType(obj)
    if objType then
        local color = colors[objType]
        local target = (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))) or (obj:IsA("BasePart") and obj)
        
        if target and not ObjectCache[obj] then
            local hl = Instance.new("Highlight")
            hl.Name = "VD_ObjESP"
            hl.Adornee = obj
            hl.FillColor = color
            hl.OutlineColor = color
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.Parent = obj
            
            ObjectCache[obj] = hl
        end
    end
end

local function UpdateObjectColors()
    for obj, hl in pairs(ObjectCache) do
        if hl and hl.Parent then
            local objType = GetObjectType(obj)
            if objType then
                hl.FillColor = colors[objType]
                hl.OutlineColor = colors[objType]
            end
        end
    end
end

local function ObjectESPLoop()
    StopLoop("ObjectESP")
    for _, hl in pairs(ObjectCache) do
        if hl then hl:Destroy() end
    end
    table.clear(ObjectCache)

    if not objectEspEnabled then return end

    for _, obj in pairs(Workspace:GetDescendants()) do
        ApplyObjectESP(obj)
    end

    Connections.ObjectESP = Workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.2)
        if objectEspEnabled then
            ApplyObjectESP(obj)
        end
    end)
end

-- ==============================
-- SILENT AIM
-- ==============================
local function SilentLoop()
    StopLoop("Silent")
    if not silentAim then return end
    
    Connections.Silent = RunService.RenderStepped:Connect(function()
        local target = GetClosestPlayer()
        if target and target.Character then
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local targetPos = tr.Position
                local camPos = Camera.CFrame.Position
                local direction = (targetPos - camPos).Unit
                local newCF = CFrame.new(camPos, camPos + direction)
                Camera.CFrame = Camera.CFrame:Lerp(newCF, aimSmooth)
            end
        end
    end)
end

-- ==============================
-- FULLBRIGHT
-- ==============================
local function ToggleFullBright(state)
    fullBrightEnabled = state
    StopLoop("FullBright")
    
    if state then
        -- Сохраняем оригинал
        origBrightness = Lighting.Brightness
        origClockTime = Lighting.ClockTime
        origFogEnd = Lighting.FogEnd
        origGlobalShadows = Lighting.GlobalShadows
        
        Connections.FullBright = RunService.Heartbeat:Connect(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 999999
            Lighting.GlobalShadows = false
        end)
    else
        -- Возвращаем исходные настройки
        Lighting.Brightness = origBrightness
        Lighting.ClockTime = origClockTime
        Lighting.FogEnd = origFogEnd
        Lighting.GlobalShadows = origGlobalShadows
    end
end

-- ==============================
-- GUI (Rayfield)
-- ==============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "VD ESP + Aim [PROSTO]",
    LoadingTitle = "ESP & Silent Aim",
    LoadingSubtitle = "by goodlooking",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local ESPTab = Window:CreateTab("👁 Players")
local ObjTab = Window:CreateTab("📦 Object ESP")
local AimTab = Window:CreateTab("🎯 Aim")
local MiscTab = Window:CreateTab("⚙️ Misc")

-- Players Tab
ESPTab:CreateToggle({
    Name = "ESP Players",
    CurrentValue = false,
    Callback = function(v)
        espEnabled = v
        ESPLoop()
    end
})

ESPTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = false,
    Callback = function(v)
        showNames = v
        if espEnabled then ESPLoop() end
    end
})

-- Object ESP Tab
ObjTab:CreateToggle({
    Name = "Enable Object ESP",
    CurrentValue = false,
    Callback = function(v)
        objectEspEnabled = v
        ObjectESPLoop()
    end
})

ObjTab:CreateColorPicker({
    Name = "Generators (Генераторы)",
    Color = colors.Generator,
    Callback = function(color)
        colors.Generator = color
        UpdateObjectColors()
    end
})

ObjTab:CreateColorPicker({
    Name = "Pallets (Палетки)",
    Color = colors.Pallet,
    Callback = function(color)
        colors.Pallet = color
        UpdateObjectColors()
    end
})

ObjTab:CreateColorPicker({
    Name = "Vaulting (Перелезание)",
    Color = colors.Vault,
    Callback = function(color)
        colors.Vault = color
        UpdateObjectColors()
    end
})

ObjTab:CreateColorPicker({
    Name = "Hooks (Подвешивание)",
    Color = colors.Hook,
    Callback = function(color)
        colors.Hook = color
        UpdateObjectColors()
    end
})

-- Aim Tab
AimTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Callback = function(v)
        silentAim = v
        SilentLoop()
    end
})

AimTab:CreateSlider({
    Name = "Smoothness",
    Range = {0.01, 1},
    Increment = 0.01,
    CurrentValue = 0.3,
    Callback = function(v)
        aimSmooth = v
    end
})

-- Misc Tab
MiscTab:CreateToggle({
    Name = "FullBright (Освещение карты)",
    CurrentValue = false,
    Callback = function(v)
        ToggleFullBright(v)
    end
})

MiscTab:CreateButton({
    Name = "❌ Close Script",
    Callback = function()
        StopLoop("ESP")
        StopLoop("Silent")
        StopLoop("ObjectESP")
        StopLoop("FullBright")
        ToggleFullBright(false)
        ClearESP()
        pcall(function() Rayfield:Destroy() end)
        print("[GOOD] Скрипт закрыт.")
    end
})

Rayfield:Notify({
    Title = "VD ESP + Aim",
    Content = "Загружено успешно!",
    Duration = 3
})

print("[GOOD] Скрипт успешно инициализирован.")

