--[[
    Violence District – ESP + Silent Aim + Object ESP + FullBright [PROSTO] - FIXED & IMPROVED
    – Player ESP: игроки подсвечены (выжившие зелёным, убийца красным) + Ники над головами
    – Object ESP: только генераторы, палетки, проёмы для перелезания (Vault) и для подвешивания (Hooks)
    – ИСПРАВЛЕНО: Полностью переработан поиск окон (Vault/Obstacles), теперь они гарантированно подсвечиваются.
    – ДОБАВЛЕНО: Динамическое отслеживание починки генераторов в процентах (%) над каждым из них в реальном времени.
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
local GeneratorUIs = {}

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
    
    -- Чистим UI процентов генераторов
    for _, ui in pairs(GeneratorUIs) do
        if ui then ui:Destroy() end
    end
    table.clear(GeneratorUIs)
    
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
        if obj.Name == "VD_ObjESP" or obj.Name == "VD_GenPercent" then
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
-- OBJECT ESP (Оптимизированное под проёмы перелезания и генераторы)
-- ==============================
local function GetObjectType(obj)
    local name = obj.Name:lower()
    
    -- Проверка на генераторы
    if name:find("generator") then
        return "Generator"
    end
    
    -- Проверка на палетки (доски)
    if name:find("pallet") or name:find("board") then
        return "Pallet"
    end
    
    -- Исключаем огромные модели стекол, витрин, стеклянных перегородок зданий
    if name:find("glass") or name:find("window_large") or name:find("pane") or name:find("wall") then
        return nil
    end
    
    -- Улучшенный и максимально точный поиск проёмов для перелезания (Vault Windows/Spots/Walls)
    if name:find("vault") or name:find("window") or name:find("obstacle") or obj:FindFirstChild("Vault") or obj:FindFirstChild("VaultSpot") then
        -- Дополнительный фильтр по размеру, чтобы не подсвечивать здания целиком
        if obj:IsA("Model") and obj:GetExtentsSize().Magnitude > 25 then
            return nil
        end
        return "Vault"
    end
    
    -- Крюки для подвешивания игроков
    if name:find("hook") or name:find("hanger") or name:find("suspend") then
        return "Hook"
    end
    
    return nil
end

-- Получить процент починки генератора
local function GetGeneratorProgress(gen)
    -- Ищем атрибуты прогресса
    local progress = gen:GetAttribute("Progress") or gen:GetAttribute("Percent") or gen:GetAttribute("Repair")
    if progress then
        return math.floor(progress)
    end
    
    -- Проверяем дочерние значения
    for _, v in pairs(gen:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local vn = v.Name:lower()
            if vn:find("progress") or vn:find("percent") or vn:find("repair") or vn:find("value") then
                -- Если значение от 0 до 1, умножаем на 100
                if v.Value <= 1 and v.Value > 0 then
                    return math.floor(v.Value * 100)
                end
                return math.floor(v.Value)
            end
        end
    end
    return 0
end

local function ApplyObjectESP(obj)
    if not objectEspEnabled then return end
    
    local objType = GetObjectType(obj)
    if objType then
        local color = colors[objType]
        
        if obj:IsA("Model") or obj:IsA("BasePart") then
            -- Highlight подсветка
            local hl = ObjectCache[obj] or obj:FindFirstChild("VD_ObjESP")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "VD_ObjESP"
                hl.Parent = obj
                ObjectCache[obj] = hl
            end
            hl.Adornee = obj
            hl.FillColor = color
            hl.OutlineColor = color
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            
            -- Если это генератор, вешаем поверх BillboardGui для отслеживания % починки
            if objType == "Generator" then
                local targetPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
                if targetPart and not GeneratorUIs[obj] then
                    local bill = Instance.new("BillboardGui")
                    bill.Name = "VD_GenPercent"
                    bill.Size = UDim2.new(0, 100, 0, 30)
                    bill.AlwaysOnTop = true
                    bill.StudsOffset = Vector3.new(0, 3, 0)
                    
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Text = "0%"
                    label.TextColor3 = colors.Generator
                    label.TextStrokeColor3 = Color3.new(0, 0, 0)
                    label.TextStrokeTransparency = 0
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 14
                    label.Parent = bill
                    
                    bill.Parent = targetPart
                    GeneratorUIs[obj] = bill
                end
            end
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
                
                -- Обновим цвет текста над генератором
                if objType == "Generator" and GeneratorUIs[obj] then
                    GeneratorUIs[obj].TextLabel.TextColor3 = colors.Generator
                end
            end
        else
            ObjectCache[obj] = nil
        end
    end
end

local function ObjectESPLoop()
    StopLoop("ObjectESP")
    
    -- Очистка старых
    for _, hl in pairs(ObjectCache) do
        if hl then hl:Destroy() end
    end
    table.clear(ObjectCache)
    
    for _, ui in pairs(GeneratorUIs) do
        if ui then ui:Destroy() end
    end
    table.clear(GeneratorUIs)

    if not objectEspEnabled then return end

    -- Первоначальный скан всей карты
    for _, obj in pairs(Workspace:GetDescendants()) do
        ApplyObjectESP(obj)
    end

    -- Отслеживание динамического спавна/стриминга (чтобы подсветка не обрывалась)
    Connections.ObjectESP = Workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.3)
        if objectEspEnabled then
            ApplyObjectESP(obj)
        end
    end)
    
    -- Сервисный цикл: обновляем % починки генераторов и исправляем "исчезновения" из-за Roblox StreamingEnabled
    task.spawn(function()
        while objectEspEnabled do
            for _, obj in pairs(Workspace:GetDescendants()) do
                local objType = GetObjectType(obj)
                if objType then
                    if not ObjectCache[obj] then
                        ApplyObjectESP(obj)
                    end
                    
                    -- Обновляем проценты генератора
                    if objType == "Generator" and GeneratorUIs[obj] then
                        local progress = GetGeneratorProgress(obj)
                        GeneratorUIs[obj].TextLabel.Text = tostring(progress) .. "%"
                    end
                end
            end
            task.wait(1)
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

