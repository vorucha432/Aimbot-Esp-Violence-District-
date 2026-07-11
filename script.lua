--[[
    Violence District – ESP + Silent Aim [PROSTO] - FIXED
    – Исправлены критические утечки памяти в ESP
    – Оптимизирован поиск игроков и наведение аима
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera -- Исправлено на Workspace с большой буквы

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
-- ПЕРЕМЕННЫЕ
-- ==============================
local espEnabled = false
local showNames = false
local silentAim = false
local aimSmooth = 0.3

local Connections = {}
local Cache = {} -- Новый кеш для хранения объектов ESP без спавна каждую секунду

-- ==============================
-- ОЧИСТКА ESP (ОПТИМИЗИРОВАННАЯ)
-- ==============================
local function ClearESP()
    for char, elements in pairs(Cache) do
        if elements.Highlight then elements.Highlight:Destroy() end
        if elements.Billboard then elements.Billboard:Destroy() end
    end
    table.clear(Cache)
    
    -- Чистка остатков по именам (на всякий случай, без GetDescendants на весь Workspace)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character then
            local hl = plr.Character:FindFirstChild("VD_ESP")
            if hl then hl:Destroy() end
            local head = plr.Character:FindFirstChild("Head")
            local bill = head and head:FindFirstChild("VD_Name")
            if bill then bill:Destroy() end
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
-- ESP (БЕЗ СПАМА И ЛАГОВ)
-- ==============================
local function ESPLoop()
    StopLoop("ESP")
    if not espEnabled then ClearESP() return end

    Connections.ESP = RunService.Heartbeat:Connect(function()
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head")
                
                if hum and hum.Health > 0 then
                    -- Определение роли
                    local isKiller = false
                    if plr.Team and plr.Team.Name == "Killer" then isKiller = true end
                    if plr:GetAttribute("Role") == "Killer" then isKiller = true end
                    if plr.Name:lower():find("killer") or plr.Name:lower():find("slasher") then isKiller = true end

                    local color = isKiller and Color3.new(1,0,0) or Color3.new(0,1,0)

                    -- Инициализация кеша для персонажа
                    if not Cache[char] then
                        Cache[char] = {}
                    end

                    -- Отрисовка Highlight
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

                    -- Отрисовка Имени
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
                    -- Если игрок мертв, убираем его элементы
                    if Cache[char] then
                        if Cache[char].Highlight then Cache[char].Highlight:Destroy() end
                        if Cache[char].Billboard then Cache[char].Billboard:Destroy() end
                        Cache[char] = nil
                    end
                end
            end
        end
        
        -- Очистка кеша для вышедших игроков
        for char, _ in pairs(Cache) do
            if not char or not char.Parent then
                Cache[char] = nil
            end
        end
    end)
end

-- ==============================
-- SILENT AIM (ПЛАВНЫЙ И НАДЕЖНЫЙ)
-- ==============================
local function SilentLoop()
    StopLoop("Silent")
    if not silentAim then return end
    
    -- Переведено на RenderStepped для исключения тряски камеры
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

local ESPTab = Window:CreateTab("👁 ESP")
local AimTab = Window:CreateTab("🎯 Aim")
local MiscTab = Window:CreateTab("⚙️ Misc")

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

MiscTab:CreateButton({
    Name = "❌ Close Script",
    Callback = function()
        StopLoop("ESP")
        StopLoop("Silent")
        ClearESP()
        pcall(function() Rayfield:Destroy() end)
        print("[GOOD] Скрипт закрыт.")
    end
})

Rayfield:Notify({
    Title = "VD ESP + Aim",
    Content = "Загружено. Ошибки исправлены.",
    Duration = 3
})

print("[GOOD] Простой ESP + Silent Aim загружен.")
