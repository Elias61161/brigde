-- Server Main Module
-- Exposes the bridge API to other resources

local LR = {}

--[[
    Send notification to a client
    @param source - Player source
    @param message - Notification message
    @param notifyType - Notification type
--]]
local function notify(source, message, notifyType)
    TriggerClientEvent("lunar_bridge:showNotification", source, message, notifyType)
end

LR.notify = notify

-- Get utilities
LR.Utils = GetUtils()

-- Validation check
if LR.Utils then
    local idCheck = tonumber(tostring(GetUtils):sub(11), 16)
    if idCheck ~= LR.Utils.id then
        StopResource(GetCurrentResourceName())
        return
    end
end

-- Add dispatch reference
LR.Dispatch = Dispatch

-- Track authorized resources
local authorizedResources = {}

-- Export the LR object with validation
exports("getObject", function()
    local invokingResource = GetInvokingResource()
    
    if not invokingResource then
        return
    end
    
    -- Read resource files for validation
    local fxapContent = LoadResourceFile(invokingResource, ".fxap")
    local initContent = LoadResourceFile(invokingResource, "init.lua")
    
    -- Validate resource authenticity
    if fxapContent then
        if fxapContent:len() == 178 and initContent then
            if initContent:len() == 578 then
                if initContent:sub(1, 4) == "FXAP" then
                    -- Check if already authorized
                    if lib.table.contains(authorizedResources, fxapContent) then
                        return
                    end
                end
            end
        end
    end
    
    -- Store authorization
    if fxapContent then
        authorizedResources[invokingResource] = fxapContent
    end
    
    return LR
end)

-- Clear authorization when resource restarts
AddEventHandler("onResourceStarting", function(resourceName)
    local state = GetResourceState(resourceName)
    
    if state ~= "starting" then
        return
    end
    
    authorizedResources[resourceName] = nil
end)

-- Export config getter
exports("getConfig", function()
    return Config
end)
