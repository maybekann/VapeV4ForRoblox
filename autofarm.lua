repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local queue_on_teleport = queue_on_teleport or syn and syn.queue_on_teleport or function() end
local WebhookURL = "https://discord.com/api/webhooks/1454499333784338629/OD7P0Gs4gD7rNlLleUefu1K4x9Bo2Wl6uRIdpdAvCfToOt_wtW20USUKLGOLGF596slX"
local CHEST_NAME = "chest"
local HEIGHT_TOLERANCE = 2
local CHECK_INTERVAL = 0.05
local hasTriggered = false
local isProcessing = false
local lastGamesPlayed = 0
local queueLoop
local gameMonitor
local heightMonitor

local function notify(title, message, duration)
    print("[" .. title .. "] " .. message)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = title,
        Text = message,
        Duration = duration or 5
    })
end

local function sendWebhook()
    local playerLevel = player:GetAttribute("PlayerLevel") or 0
    local battlePassXP = player:GetAttribute("BattlePassXP") or 0
    local gamesPlayed = player:GetAttribute("GamesPlayed") or 0
    
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(player.UserId) .. "&width=150&height=150&format=png"
    
    local data = {
        ["content"] = "@everyone",
        ["embeds"] = {{
            ["title"] = "hey ur account is still grinding",
            ["description"] = "just wanted to let you know whats going on with your stats",
            ["color"] = 5814783,
            ["thumbnail"] = {
                ["url"] = avatarUrl
            },
            ["fields"] = {
                {
                    ["name"] = "Username",
                    ["value"] = player.Name,
                    ["inline"] = true
                },
                {
                    ["name"] = "Display Name",
                    ["value"] = player.DisplayName,
                    ["inline"] = true
                },
                {
                    ["name"] = "Level",
                    ["value"] = tostring(playerLevel),
                    ["inline"] = true
                },
                {
                    ["name"] = "Battle Pass XP",
                    ["value"] = tostring(battlePassXP),
                    ["inline"] = true
                },
                {
                    ["name"] = "Games Played",
                    ["value"] = tostring(gamesPlayed),
                    ["inline"] = true
                }
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
            ["footer"] = {
                ["text"] = "your autofarmer is running"
            }
        }}
    }
    
    pcall(function()
        request({
            Url = WebhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function findNearestChest()
    local character = player.Character
    if not character then return nil end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    local playerPos = rootPart.Position
    local nearestChest = nil
    local nearestDistance = math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if obj.Name:lower():find(CHEST_NAME:lower()) then
                local chestPos
                if obj:IsA("Model") then
                    local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        chestPos = primary.Position
                    end
                elseif obj:IsA("BasePart") then
                    chestPos = obj.Position
                end
                
                if chestPos then
                    local distance = (playerPos - chestPos).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestChest = obj
                    end
                end
            end
        end
    end
    
    return nearestChest, nearestDistance
end

local function getObjectHeight(obj)
    if obj:IsA("Model") then
        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if primary then
            return primary.Position.Y
        end
    elseif obj:IsA("BasePart") then
        return obj.Position.Y
    end
    return nil
end

local function fastReset()
    if hasTriggered or isProcessing then return end
    hasTriggered = true
    isProcessing = true
    
    pcall(function()
        notify("AutoFarm", "height matched resetting...", 3)
        
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
        task.wait(0.3)
        
        notify("AutoFarm", "teleporting to new server...", 3)
        
        local data = TeleportService:GetLocalPlayerTeleportData()
        task.wait(0.25)
        TeleportService:Teleport(game.PlaceId, player, data)
    end)
end

local function isAtChestHeight()
    local character = player.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local chests = workspace:FindFirstChild("Chests")
    if not chests then return false end
    
    local playerY = rootPart.Position.Y
    
    for _, chest in pairs(chests:GetChildren()) do
        if chest:IsA("Model") or chest:IsA("Part") then
            local chestY = chest:IsA("Model") and chest:GetPrimaryPartCFrame().Position.Y or chest.Position.Y
            
            if math.abs(playerY - chestY) <= HEIGHT_TOLERANCE then
                return true
            end
        end
    end
    
    return false
end

local teleportConnection
teleportConnection = player.OnTeleport:Connect(function()
    queue_on_teleport([[
        repeat task.wait() until game:IsLoaded()
        task.wait(1)
        loadstring(game:HttpGet('https://raw.githubusercontent.com/maybekann/VapeV4ForRoblox/main/autofarm.lua', true))()
    ]])
end)

notify("AutoFarm", "script loaded! starting in one sec...", 3)
task.wait(1)

lastGamesPlayed = player:GetAttribute("GamesPlayed") or 0

if game.PlaceId == 6872265039 then
    notify("AutoFarm", "in lobby..starting queue spam", 5)
    
    queueLoop = task.spawn(function()
        while true do
            pcall(function()
                local events = ReplicatedStorage:WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events", 5)
				task.wait(3)
                if events then
                    local joinQueue = events:FindFirstChild("joinQueue")
                    if joinQueue then
                        joinQueue:FireServer({
                            queueType = "skywars_to2"
                        })
                    end
                end
            end)
            task.wait(5)
        end
    end)
    
    gameMonitor = task.spawn(function()
        while true do
            local currentGames = player:GetAttribute("GamesPlayed") or 0
            local gamesPlayed = currentGames - lastGamesPlayed
            
            if gamesPlayed >= 2 then
                notify("AutoFarm", "played 2 games, sending a webhook", 3)
                sendWebhook()
                lastGamesPlayed = currentGames
            end
            
            task.wait(5)
        end
    end)
else
    notify("AutoFarm", "not in lobby (PlaceId: " .. game.PlaceId .. ")", 5)
end

heightMonitor = task.spawn(function()
    while true do
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local nearestChest = findNearestChest()
                
                if nearestChest then
                    local playerHeight = rootPart.Position.Y
                    local chestHeight = getObjectHeight(nearestChest)
                    
                    if chestHeight then
                        local heightDiff = math.abs(playerHeight - chestHeight)
                        
                        if heightDiff <= HEIGHT_TOLERANCE then
                            fastReset()
                            break
                        end
                    end
                end
                
                if isAtChestHeight() then
                    fastReset()
                    break
                end
            end
        end
        task.wait(CHECK_INTERVAL)
    end
end)

notify("AutoFarm", "everything loaded n ready", 3)
