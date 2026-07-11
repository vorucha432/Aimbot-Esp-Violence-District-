--[[
    Violence District – ESP + Silent Aim + Item ESP [PROSTO] - UPDATED
    – Исправлены утечки памяти и лаги
    – Добавлен полноценный Item ESP (генераторы, лут, оружие)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
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
-- ПЕРЕМЕННЫЕ
-- ==============================
local espEnabled = false
local showNames = false
local silentAim = false
local aimSmooth = 0.3
local itemEspEnabled = false

local Connections = {}
local Cache = {} 
local ItemCache = {}

-- ==============================
-- ОЧИСТКА ВСЕХ ВИДОВ ESP
-- ==============================
local function ClearESP()
    for char, elements in pairs(Cache) do
        if elements.Highlight then elements.Highlight:Destroy() end
        if elements.Billboard then elements.Billboard:Destroy() end
    end
    table.clear(Cache)
    
    for _, bill in pairs(ItemCache) do
        if bill then bill:Destroy() end
    end
    table.clear(ItemCache)
    
    -- Чистка остатков в Workspace
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
        if obj.Name == "VD_ItemESP" then
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
-- ITEM ESP (Генераторы, Лут, Оружие)
-- ==============================
local function ItemESPLoop()
    StopLoop("ItemESP")
    for _, bill in pairs(ItemCache) do
        if bill then bill:Destroy() end
    end
    table.clear(ItemCache)

    if not itemEspEnabled then return end

    local function checkAndApplyESP(obj)
        if not obj:IsA("BasePart") and not obj:IsA("Model") then return end
        
        local name = obj.Name:lower()
        local displayName = nil
        local color = Color3.new(1, 1, 1)

        -- Настройки обнаружения предметов по имени
        if name:find("generator") then
            displayName = "Генератор"
            color = Color3.fromRGB(0, 180, 255)
        elseif name:find("medkit") or name:find("bandage") or name:find("heal") then
            displayName = "Аптечка"
            color = Color3.fromRGB(0, 255, 100)
        elseif name:find("gun") or name:find("pistol") or name:find("rifle") or name:find("shotgun") or name:find("ammo") then
            displayName = "Оружие/Патроны"
            color = Color3.fromRGB(255, 200, 0)
        elseif name:find("chest") or name:find("crate") or name:find("loot") then
            displayName = "Ящик с лутом"
            color = Color3.fromRGB(150, 0, 255)
        end

        if displayName then
            local targetPart = obj:IsA("Model") and (obj:FindFirstChild("Engine") or obj:FindFirstChild("Main") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
            if targetPart and not ItemCache[obj] then
                local bill = Instance.new("BillboardGui")
                bill.Name = "VD_ItemESP"
                bill.Size = UDim2.new(0, 120, 0, 30)
                bill.AlwaysOnTop = true
                bill.StudsOffset = Vector3.new(0, 1.5, 0)
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = displayName
                label.TextColor3 = color
                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                label.TextStrokeTransparency = 0
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.Parent = bill

                bill.Parent = targetPart
                ItemCache[obj] = bill
            end
        end
    end

    -- Сканируем существующие объекты
    for _, obj in pairs(Workspace:GetDescendants()) do
        checkAndApplyESP(obj)
    end

    -- Отслеживаем новые спавны предметов на карте
    Connections.ItemESP = Workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.2) -- Небольшая пауза для полной прогрузки объекта
        if itemEspEnabled then
            checkAndApplyESP(obj)
        end
    end)
end

-- ==============================
-- SILENT AIM (ПЛАВНЫЙ)
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

ESPTab:CreateToggle({
    Name = "Item ESP",
    CurrentValue = false,
    Callback = function(v)
        itemEspEnabled = v
        ItemESPLoop()
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
        StopLoop("ItemESP")
        ClearESP()
        pcall(function() Rayfield:Destroy() end)
        print("[GOOD] Скрипт закрыт.")
    end
})

Rayfield:Notify({
    Title = "VD ESP + Aim",
    Content = "Загружено с Item ESP!",
    Duration = 3
})

print("[GOOD] Скрипт с Item ESP успешно инициализирован.")

