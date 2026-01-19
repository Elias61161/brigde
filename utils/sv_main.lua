-- Server Utilities Module
-- Provides utility functions for server-side operations

local Utils = {}
local utilsRetrieved = false
local resourceName = GetCurrentResourceName()

--[[
    Get the Utils object (one-time retrieval)
    @return table - The Utils object
--]]
function GetUtils()
    if not utilsRetrieved then
        utilsRetrieved = true
        return Utils
    end
end

-- Generate unique ID for validation
Utils.id = tonumber(tostring(GetUtils):sub(11), 16)

--[[
    Check if two positions are within a maximum distance
    @param pos1 - First position (vector3, source, or entity)
    @param pos2 - Second position (vector3, source, or entity)
    @param maxDistance - Maximum allowed distance
    @return boolean - True if within distance
--]]
function Utils.distanceCheck(pos1, pos2, maxDistance)
    maxDistance = maxDistance or Config.MaxDistance
    
    -- Convert player source to coords
    if type(pos1) == "number" or type(pos1) == "string" then
        local ped = GetPlayerPed(pos1)
        if ped == 0 then
            return false
        end
        pos1 = GetEntityCoords(ped)
    end
    
    if type(pos2) == "number" or type(pos2) == "string" then
        local ped = GetPlayerPed(pos2)
        if ped == 0 then
            return false
        end
        pos2 = GetEntityCoords(ped)
    end
    
    local distance = #(pos1.xyz - pos2.xyz)
    return maxDistance >= distance
end

--[[
    Get the size of a table (including non-sequential keys)
    @param tbl - The table to count
    @return number - Number of entries
--]]
function Utils.getTableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--[[
    Get a random element from a table
    @param tbl - The table to pick from
    @return any - Random element
--]]
function Utils.randomFromTable(tbl)
    local index = math.random(1, #tbl)
    return tbl[index]
end

--[[
    Log a message to Discord webhook
    @param source - Player source
    @param webhook - Discord webhook URL
    @param message - Log message
--]]
function Utils.logToDiscord(source, webhook, message)
    local invokingResource = GetInvokingResource() or "lunar_bridge"
    
    local player = Framework.getPlayerFromId(source)
    if not player then
        return
    end
    
    -- Use custom logging if configured
    if Config.Logging == "custom" then
        CustomLogging(player, invokingResource, message)
    end
    
    -- Build Discord embed
    local embeds = {
        {
            color = "16768885",
            title = GetPlayerName(source) .. " (" .. player:getIdentifier() .. ")",
            description = message,
            footer = {
                text = os.date("%H:%M - %d. %m. %Y", os.time()),
                icon_url = "https://cdn.discordapp.com/attachments/793081015433560075/1048643072952647700/lunar.png"
            }
        }
    }
    
    PerformHttpRequest(webhook, function(statusCode, response, headers) end, "POST", json.encode({
        username = invokingResource,
        embeds = embeds
    }), {
        ["Content-Type"] = "application/json"
    })
end

--[[
    Create a cancellable timeout
    @param duration - Timeout duration in ms
    @param callback - Function to call after timeout
    @return table - Timeout controller with cancel method
--]]
function Utils.setTimeout(duration, callback)
    local active = true
    
    local controller = {
        cancel = function()
            active = false
        end
    }
    
    SetTimeout(duration, function()
        if active then
            callback()
        end
    end)
    
    return controller
end

--[[
    Get count of players with specific job(s)
    @param jobs - Job name, table of job names, or nil for all
    @return number - Count of players with the job(s)
--]]
function Utils.getJobCount(jobs)
    local jobLookup = nil
    
    if type(jobs) == "table" then
        jobLookup = {}
        for _, job in ipairs(jobs) do
            jobLookup[job] = true
        end
    elseif type(jobs) == "string" then
        jobLookup = { [jobs] = true }
    end
    
    local players = Framework.getPlayers()
    local count = 0
    
    for _, player in pairs(players) do
        -- Get job name (handle different data structures)
        local jobName = player.job and player.job.name or player.PlayerData.job.name
        
        -- Get on-duty status
        local onDuty = player.job and true or player.PlayerData.job.onduty
        
        if jobName ~= nil and onDuty then
            if jobLookup[jobName] == true then
                count = count + 1
            end
        end
    end
    
    return count
end

--[[
    Get count of police officers on duty
    @return number - Count of police officers
--]]
function Utils.getPoliceCount()
    return Utils.getJobCount(Config.Dispatch.Jobs)
end

--[[
    Check if a player has any of the specified jobs
    @param source - Player source
    @param jobs - Job name or table of job names
    @return boolean - True if player has one of the jobs
--]]
function Utils.hasJobs(source, jobs)
    local player = Framework.getPlayerFromId(source)
    
    if not player then
        return false
    end
    
    if type(jobs) == "string" then
        jobs = { jobs }
    end
    
    for _, job in ipairs(jobs) do
        if player:getJob() == job then
            return true
        end
    end
    
    return false
end

--[[
    Check if a player is police
    @param source - Player source
    @return boolean - True if player is police
--]]
function Utils.isPolice(source)
    return Utils.hasJobs(source, Config.Dispatch.Jobs)
end

--[[
    Get resource version from metadata
    @param resource - Resource name
    @return string - Version string
--]]
local function getResourceVersion(resource)
    local version = GetResourceMetadata(resource, "version", 0)
    
    if version then
        version = version:match("%d+%.%d+%.%d+")
    end
    
    if not version then
        error(string.format("Unable to determine %s version.", resource))
    end
    
    return version
end

--[[
    Check for resource updates
    @param resource - Resource name to check
--]]
function Utils.checkVersion(resource)
    CreateThread(function()
        local url = string.format("https://raw.githubusercontent.com/Lunar-Scripts/versions/main/%s", resource)
        
        Wait(5000)
        
        PerformHttpRequest(url, function(statusCode, response, headers)
            local currentVersion = getResourceVersion(resource)
            
            if not response then
                warn(string.format("Couldn't check version for resource: %s", resource))
                return
            end
            
            local latestVersion = response:sub(1, 5)
            
            if currentVersion ~= latestVersion then
                print(string.format("^0[^3WARNING^0] %s is outdated and should be updated!", resource))
                print(string.format("^0[^3WARNING^0] Download the latest version ^5%s^0 through keymaster.", latestVersion))
            else
                print(string.format("^0[^2INFO^0] %s is up-to-date.", resource))
            end
        end, "GET")
    end)
end

-- Check version on startup
CreateThread(function()
    Utils.checkVersion("lunar_bridge")
end)

-- Item labels cache
local itemLabels = nil
local itemLabelsLoaded = false

-- Load item labels
CreateThread(function()
    while true do
        if itemLabels and Utils.getTableSize(itemLabels) ~= 0 then
            break
        end
        
        local items = Framework.getItems()
        local labels = {}
        
        for key, item in pairs(items) do
            local name = item.name or key
            local label = item.label or "NULL"
            labels[name] = label
        end
        
        itemLabels = labels
        Wait(100)
    end
    
    itemLabelsLoaded = true
end)

-- Callback: Get item labels
lib.callback.register("lunar_bridge:getItemLabels", function()
    while not itemLabelsLoaded do
        Wait(100)
    end
    
    return itemLabels
end)

--[[
    Get label for an item
    @param itemName - Item name
    @return string - Item label
--]]
function Utils.getItemLabel(itemName)
    local label = itemLabels[itemName]
    
    if not label then
        label = itemLabels[itemName:upper()]
        if not label then
            label = "ITEM_NOT_FOUND"
        end
    end
    
    return label
end

--[[
    Get image URL for an item
    @param itemName - Item name
    @return string - Image URL
--]]
function Utils.getImageUrl(itemName)
    return string.format("https://lunar-scripts.com/%s", itemName)
end

--[[
    Calculate offset coordinates from a position
    @param coords - Base coordinates (vector4)
    @param offsetX - X offset
    @param offsetY - Y offset
    @param offsetZ - Z offset
    @param headingOffset - Optional heading offset
    @return vector4 - Offset coordinates
--]]
function Utils.offsetCoords(coords, offsetX, offsetY, offsetZ, headingOffset)
    local heading = math.rad(coords.w)
    
    local cosHeading = math.cos(heading)
    local sinHeading = math.sin(heading)
    
    local newX = (offsetX * cosHeading) - (offsetY * sinHeading)
    local newY = (offsetX * sinHeading) + (offsetY * cosHeading)
    local newZ = offsetZ
    
    local finalX = coords.x + newX
    local finalY = coords.y + newY
    local finalZ = coords.z + newZ
    local finalHeading = coords.w + (headingOffset or 0.0)
    
    return vector4(finalX, finalY, finalZ, finalHeading)
end

--[[
    Create a vehicle on the server
    @param model - Vehicle model hash
    @param coords - Spawn coordinates (vector4)
    @param vehicleType - Vehicle type string
    @return number - Vehicle entity handle
--]]
function Utils.createVehicle(model, coords, vehicleType)
    local vehicle = CreateVehicleServerSetter(model, vehicleType, coords.x, coords.y, coords.z - 0.7, coords.w)
    
    -- Remove any NPC peds in the vehicle
    for seatIndex = -1, 6 do
        local ped = GetPedInVehicleSeat(vehicle, seatIndex)
        local popType = GetEntityPopulationType(ped)
        
        if popType > 0 and popType < 6 then
            DeleteEntity(ped)
        end
    end
    
    return vehicle
end
