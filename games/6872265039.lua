--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local Client = require(replicatedStorage.TS.remotes).default.Client

	bedwars = setmetatable({
		Client = Client,
		CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for _, v in vape.Modules do
	if v.Category == 'Combat' or v.Category == 'Minigames' then
		vape:Remove(i)
	end
end

run(function()
    local AutoFarm
    local AutoQueue
    local AutoReset
    local SendWebhook
    local TestWebhookButton
    local WebhookURL = "https://discord.com/api/webhooks/1454499333784338629/OD7P0Gs4gD7rNlLleUefu1K4x9Bo2Wl6uRIdpdAvCfToOt_wtW20USUKLGOLGF596slX"
    
    local CHEST_NAME = "chest"
    local HEIGHT_TOLERANCE = 2
    local CHECK_INTERVAL = 0.05
    local hasTriggered = false
    local isProcessing = false
    local queueLoop
    local gameMonitor
    local heightMonitor
    local lastWebhookTime = 0
    local WEBHOOK_COOLDOWN = 3
    local lastGamesPlayed = 0
    
    local function sendWebhookNotification()
        local playerLevel = lplr:GetAttribute("PlayerLevel") or 0
        local battlePassXP = lplr:GetAttribute("BattlePassXP") or 0
        local gamesPlayed = lplr:GetAttribute("GamesPlayed") or 0
        
        local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(lplr.UserId) .. "&width=150&height=150&format=png"
        
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
                        ["value"] = lplr.Name,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Display Name",
                        ["value"] = lplr.DisplayName,
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
        
        local success = pcall(function()
            request({
                Url = WebhookURL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode(data)
            })
        end)
        
        return success
    end
    
    local function sendTestWebhook()
        local currentTime = tick()
        if currentTime - lastWebhookTime < WEBHOOK_COOLDOWN then
            vape:CreateNotification("AutoFarm", "Wait " .. math.ceil(WEBHOOK_COOLDOWN - (currentTime - lastWebhookTime)) .. " seconds before sending another webhook", 2)
            return
        end
        
        lastWebhookTime = currentTime
        vape:CreateNotification("AutoFarm", "Sending test webhook...", 2)
        local success = sendWebhookNotification()
        if success then
            vape:CreateNotification("AutoFarm", "Webhook sent successfully!", 3)
        else
            vape:CreateNotification("AutoFarm", "Failed to send webhook", 3, "error")
        end
    end
    
    local function findNearestChest()
        if not entitylib.isAlive then return nil end
        
        local humanoidRootPart = entitylib.character.RootPart
        if not humanoidRootPart then return nil end
        
        local playerPos = humanoidRootPart.Position
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
        if hasTriggered or isProcessing or not AutoReset.Enabled then return end
        hasTriggered = true
        isProcessing = true
        
        pcall(function()
            vape:CreateNotification("AutoFarm", "Height matched! Resetting...", 3)
            
            if entitylib.isAlive then
                local humanoid = entitylib.character.Humanoid
                if humanoid then
                    humanoid.Health = 0
                end
            end
            task.wait(0.3)
            
            vape:CreateNotification("AutoFarm", "Teleporting to new server...", 3)
            
            local data = game:GetService("TeleportService"):GetLocalPlayerTeleportData()
            task.wait(0.25)
            game:GetService("TeleportService"):Teleport(game.PlaceId, lplr, data)
        end)
    end
    
    local function isAtChestHeight()
        if not entitylib.isAlive then return false end
        
        local rootPart = entitylib.character.RootPart
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
    
    AutoFarm = vape.Categories.Utility:CreateModule({
        Name = 'AutoFarm',
        Function = function(callback)
            if callback then
                vape:CreateNotification("AutoFarm", "Starting auto farm...", 3)
                hasTriggered = false
                isProcessing = false
                
                lastGamesPlayed = lplr:GetAttribute("GamesPlayed") or 0
                
                if game.PlaceId == 6872265039 then
                    vape:CreateNotification("AutoFarm", "In lobby - starting queue spam", 5)
                    
                    if AutoQueue.Enabled then
                        queueLoop = task.spawn(function()
                            while AutoFarm.Enabled and AutoQueue.Enabled do
                                pcall(function()
                                    local events = game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events", 5)
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
                    end
                    
                    if SendWebhook.Enabled then
                        gameMonitor = task.spawn(function()
                            while AutoFarm.Enabled and SendWebhook.Enabled do
                                local currentGames = lplr:GetAttribute("GamesPlayed") or 0
                                local gamesPlayed = currentGames - lastGamesPlayed
                                
                                if gamesPlayed >= 2 then
                                    vape:CreateNotification("AutoFarm", "2 games played! Sending webhook...", 3)
                                    sendWebhookNotification()
                                    lastGamesPlayed = currentGames
                                end
                                
                                task.wait(5)
                            end
                        end)
                    end
                else
                    vape:CreateNotification("AutoFarm", "Not in lobby (PlaceId: " .. game.PlaceId .. ")", 5)
                end
                
                if AutoReset.Enabled then
                    heightMonitor = task.spawn(function()
                        while AutoFarm.Enabled and AutoReset.Enabled do
                            if entitylib.isAlive then
                                local humanoidRootPart = entitylib.character.RootPart
                                if humanoidRootPart then
                                    local nearestChest, distance = findNearestChest()
                                    
                                    if nearestChest then
                                        local playerHeight = humanoidRootPart.Position.Y
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
                end
            else
                vape:CreateNotification("AutoFarm", "Stopped auto farm", 3)
                
                if queueLoop then
                    pcall(function() task.cancel(queueLoop) end)
                    queueLoop = nil
                end
                
                if gameMonitor then
                    pcall(function() task.cancel(gameMonitor) end)
                    gameMonitor = nil
                end
                
                if heightMonitor then
                    pcall(function() task.cancel(heightMonitor) end)
                    heightMonitor = nil
                end
                
                hasTriggered = false
                isProcessing = false
            end
        end,
        Tooltip = 'Auto queue and grind duels\nResets when at chest height'
    })
    
    AutoQueue = AutoFarm:CreateToggle({
        Name = 'Auto Queue',
        Default = true,
        Tooltip = 'Automatically queues for skywars_to2'
    })
    
    AutoReset = AutoFarm:CreateToggle({
        Name = 'Auto Reset',
        Default = true,
        Tooltip = 'Resets and teleports when at chest height'
    })
    
    SendWebhook = AutoFarm:CreateToggle({
        Name = 'Send Webhook',
        Default = false,
        Tooltip = 'Sends stats every 2 games played'
    })
    
    TestWebhookButton = AutoFarm:CreateButton({
        Name = "Test Webhook",
        Function = function()
            sendTestWebhook()
        end,
        Tooltip = "Send ONE test webhook (3 second cooldown)"
    })
end)
