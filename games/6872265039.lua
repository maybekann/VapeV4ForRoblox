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
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Minigames:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)
	

run(function()
    local DuelsGrinder
    local AutoQueue
    local AutoReset
    local SendWebhook
    local WebhookURL = "https://discord.com/api/webhooks/1454499333784338629/OD7P0Gs4gD7rNlLleUefu1K4x9Bo2Wl6uRIdpdAvCfToOt_wtW20USUKLGOLGF596slX"
    
    local CHEST_NAME = "chest"
    local HEIGHT_TOLERANCE = 2
    local CHECK_INTERVAL = 0.05
    local hasTriggered = false
    local isProcessing = false
    local queueLoop
    local webhookLoop
    local heightMonitor
    
    local function sendWebhookNotification()
        if not SendWebhook.Enabled then return end
        
        local lvl = lplr:GetAttribute("PlayerLevel") or 0
        local data = {
            ["embeds"] = {{
                ["title"] = "Duels Grinder - Level Update",
                ["description"] = "Current player level: **" .. tostring(lvl) .. "**",
                ["color"] = 3447003,
                ["fields"] = {
                    {
                        ["name"] = "Username",
                        ["value"] = lplr.Name,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "User ID",
                        ["value"] = tostring(lplr.UserId),
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Job ID",
                        ["value"] = game.JobId,
                        ["inline"] = false
                    }
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
            }}
        }
        
        pcall(function()
            request({
                Url = WebhookURL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode(data)
            })
        end)
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
            vape:CreateNotification("Duels Grinder", "Height matched! Resetting...", 3)
            
            if entitylib.isAlive then
                local humanoid = entitylib.character.Humanoid
                if humanoid then
                    humanoid.Health = 0
                end
            end
            task.wait(0.3)
            
            vape:CreateNotification("Duels Grinder", "Teleporting to new server...", 3)
            
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
    
    DuelsGrinder = vape.Categories.Utility:CreateModule({
        Name = 'DuelsGrinder',
        Function = function(callback)
            if callback then
                vape:CreateNotification("Duels Grinder", "Starting auto grinder...", 3)
                hasTriggered = false
                isProcessing = false
                
                if game.PlaceId == 6872265039 then
                    vape:CreateNotification("Duels Grinder", "In lobby - starting queue spam", 5)
                    
                    if AutoQueue.Enabled then
                        queueLoop = task.spawn(function()
                            while DuelsGrinder.Enabled and AutoQueue.Enabled do
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
                        webhookLoop = task.spawn(function()
                            while DuelsGrinder.Enabled and SendWebhook.Enabled do
                                sendWebhookNotification()
                                task.wait(5)
                            end
                        end)
                    end
                else
                    vape:CreateNotification("Duels Grinder", "Not in lobby (PlaceId: " .. game.PlaceId .. ")", 5)
                end
                
                if AutoReset.Enabled then
                    heightMonitor = task.spawn(function()
                        while DuelsGrinder.Enabled and AutoReset.Enabled do
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
                vape:CreateNotification("Duels Grinder", "Stopped auto grinder", 3)
                
                if queueLoop then
                    pcall(function() task.cancel(queueLoop) end)
                    queueLoop = nil
                end
                
                if webhookLoop then
                    pcall(function() task.cancel(webhookLoop) end)
                    webhookLoop = nil
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
    
    AutoQueue = DuelsGrinder:CreateToggle({
        Name = 'Auto Queue',
        Default = true,
        Tooltip = 'Automatically queues for skywars_to2'
    })
    
    AutoReset = DuelsGrinder:CreateToggle({
        Name = 'Auto Reset',
        Default = true,
        Tooltip = 'Resets and teleports when at chest height'
    })
    
    SendWebhook = DuelsGrinder:CreateToggle({
        Name = 'Send Webhook',
        Default = false,
        Tooltip = 'Sends level updates to Discord webhook'
    })
end)
