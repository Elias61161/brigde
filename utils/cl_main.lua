-- Client Utilities Module
-- Provides utility functions for client-side operations

local Utils = {}
local utilsRetrieved = false

-- Track created entities and blips by resource
local createdEntities = {}
local createdBlips = {}

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

-- Default NPC scenarios
local defaultScenarios = {
    "WORLD_HUMAN_AA_COFFEE",
    "WORLD_HUMAN_AA_SMOKE",
    "WORLD_HUMAN_SMOKING"
}

--[[
    Create a ped with automatic spawn/despawn based on distance
    @param coords - Spawn coordinates (vector4)
    @param pedData - Ped configuration (model, scenario, offset, heading)
    @param options - Interaction options
    @param targetOptions - Target system options
    @return table - Ped controller object
--]]
function Utils.createPed(coords, pedData, options, targetOptions)
    -- Normalize pedData
    if type(pedData) ~= "table" then
        pedData = { model = pedData }
    end
    
    -- Validate model
    if not IsModelValid(pedData.model) then
        error("Invalid ped model: %s", pedData.model)
    end
    
    local pedController = {}
    
    -- Create distance-based spawn point
    local point = lib.points.new({
        coords = coords.xyz,
        distance = Config.SpawnDistance or 100.0,
        
        onEnter = function()
            -- Request and create ped
            lib.requestModel(pedData.model)
            
            local spawnZ = coords.z - 1.0
            local heading = (coords.w or 0.0) + 0.0
            
            pedController.value = CreatePed(4, pedData.model, coords.x, coords.y, spawnZ, heading, false, false)
            
            -- Configure ped
            SetEntityInvincible(pedController.value, true)
            SetBlockingOfNonTemporaryEvents(pedController.value, true)
            
            -- Play scenario
            local scenario = pedData.scenario or Utils.randomFromTable(defaultScenarios)
            TaskStartScenarioInPlace(pedController.value, scenario)
            
            FreezeEntityPosition(pedController.value, true)
            
            -- Apply offset if specified
            if pedData.offset then
                local offsetCoords = GetOffsetFromEntityInWorldCoords(
                    pedController.value,
                    pedData.offset.x,
                    pedData.offset.y,
                    pedData.offset.z
                )
                SetEntityCoords(pedController.value, offsetCoords.x, offsetCoords.y, offsetCoords.z - 1.0)
            end
            
            -- Apply heading if specified
            if pedData.heading then
                local finalHeading = coords.w or (0.0 + pedData.heading + 0.0)
                SetEntityHeading(pedController.value, finalHeading)
            end
            
            -- Create interaction point if options provided
            if options or pedController.options then
                pedController.zone = Utils.createEntityPoint({
                    entity = pedController.value,
                    bone = 24816,
                    radius = 2.0,
                    options = options or pedController.options
                }, targetOptions or pedController.target)
            end
        end,
        
        onExit = function()
            if pedController.value then
                DeleteEntity(pedController.value)
                pedController.value = nil
                
                if pedController.zone then
                    pedController.zone:remove()
                    pedController.zone = nil
                end
            end
            
            SetModelAsNoLongerNeeded(pedData.model)
        end
    })
    
    -- Controller methods
    function pedController.remove()
        point:onExit()
        point:remove()
    end
    
    function pedController.addOptions(newOptions, newTarget)
        pedController.options = newOptions
        pedController.target = newTarget
        
        if pedController.value then
            pedController.zone = Utils.createEntityPoint({
                entity = pedController.value,
                radius = 2.0,
                options = pedController.options
            }, pedController.target)
        end
        
        return pedController
    end
    
    function pedController.disableOptions()
        if pedController.zone then
            pedController.zone:remove()
            pedController.zone = nil
        end
    end
    
    function pedController.free()
        if pedController.zone then
            pedController.zone:remove()
            pedController.zone = nil
        end
        
        SetEntityInvincible(pedController.value, false)
        SetBlockingOfNonTemporaryEvents(pedController.value, false)
        FreezeEntityPosition(pedController.value, false)
        SetEntityAsNoLongerNeeded(pedController.value)
        point:remove()
    end
    
    function pedController.markAsNotNeeded()
        pedController.disableOptions()
        
        local originalOnExit = point.onExit
        point.onExit = function()
            originalOnExit()
            point:remove()
        end
    end
    
    function pedController.get()
        return pedController.value
    end
    
    -- Track by invoking resource
    local invokingResource = GetInvokingResource()
    if not createdEntities[invokingResource] then
        createdEntities[invokingResource] = {}
    end
    table.insert(createdEntities[invokingResource], pedController)
    
    return pedController
end

--[[
    Create a prop with automatic spawn/despawn based on distance
    @param coords - Spawn coordinates (vector4)
    @param propData - Prop configuration (model, offset, rotation)
    @param options - Interaction options
    @param targetOptions - Target system options
    @return table - Prop controller object
--]]
function Utils.createProp(coords, propData, options, targetOptions)
    -- Validate model
    if not IsModelValid(propData.model) then
        error(string.format("Invalid prop model: %s", propData.model))
    end
    
    -- Ensure coords is vector4
    coords = vector4(coords.x, coords.y, coords.z, coords.w or 0.0)
    
    local propController = {}
    
    -- Create distance-based spawn point
    local point = lib.points.new({
        coords = coords.xyz,
        distance = Config.SpawnDistance or 100.0,
        
        onEnter = function()
            lib.requestModel(propData.model)
            
            propController.value = CreateObjectNoOffset(propData.model, coords.x, coords.y, coords.z, false, false)
            FreezeEntityPosition(propController.value, true)
            
            -- Apply heading
            if coords.w then
                SetEntityHeading(propController.value, coords.w + 0.0)
            end
            
            -- Apply offset
            if propData.offset then
                local offsetCoords = Utils.offsetCoords(coords, propData.offset.x, propData.offset.y, propData.offset.z)
                SetEntityCoordsNoOffset(propController.value, offsetCoords.x, offsetCoords.y, offsetCoords.z)
            end
            
            -- Apply rotation
            if propData.rotation then
                SetEntityRotation(
                    propController.value,
                    propData.rotation.x,
                    propData.rotation.y,
                    (coords.w + 0.0) + propData.rotation.z
                )
            end
            
            -- Create interaction point if options provided
            if options or propController.options then
                propController.zone = Utils.createInteractionPoint({
                    coords = coords,
                    radius = 2.0,
                    options = options or propController.options
                }, targetOptions or propController.target)
            end
        end,
        
        onExit = function()
            if propController.value then
                DeleteEntity(propController.value)
                propController.value = nil
                
                if propController.zone then
                    propController.zone:remove()
                    propController.zone = nil
                end
            end
            
            SetModelAsNoLongerNeeded(propData.model)
        end
    })
    
    -- Controller methods
    function propController.remove()
        point:onExit()
        point:remove()
    end
    
    function propController.addOptions(newOptions, newTarget)
        propController.options = newOptions
        propController.target = newTarget
        
        if propController.value then
            propController.zone = Utils.createInteractionPoint({
                coords = coords,
                radius = 2.0,
                options = propController.options
            }, propController.target)
        end
        
        return propController
    end
    
    function propController.disableOptions()
        if propController.zone then
            propController.zone:remove()
            propController.zone = nil
        end
    end
    
    function propController.get()
        return propController.value
    end
    
    -- Track by invoking resource
    local invokingResource = GetInvokingResource()
    if not createdEntities[invokingResource] then
        createdEntities[invokingResource] = {}
    end
    table.insert(createdEntities[invokingResource], propController)
    
    return propController
end

--[[
    Check if two positions are within a maximum distance
    @param pos1 - First position (vector3 or entity)
    @param pos2 - Second position (vector3 or entity)
    @param maxDistance - Maximum allowed distance
    @return boolean - True if within distance
--]]
function Utils.distanceCheck(pos1, pos2, maxDistance)
    maxDistance = maxDistance or Config.MaxDistance
    
    -- Convert entity to coords if needed
    if type(pos1) == "number" then
        pos1 = GetEntityCoords(pos1)
    end
    
    if type(pos2) == "number" then
        pos2 = GetEntityCoords(pos2)
    end
    
    if not pos1 or not pos2 then
        return false
    end
    
    local distance = #(pos1.xyz - pos2.xyz)
    return maxDistance >= distance
end

--[[
    Wait until player is within distance of a position
    @param coords - Target coordinates
    @param maxDistance - Distance threshold
--]]
function Utils.distanceWait(coords, maxDistance)
    while true do
        local playerCoords = GetEntityCoords(cache.ped)
        local distance = #(playerCoords - coords.xyz)
        
        if distance <= maxDistance then
            break
        end
        
        Wait(200)
    end
end

--[[
    Create a blip at coordinates
    @param coords - Blip coordinates
    @param blipData - Blip configuration (Sprite, Size, Color, Name)
    @return table - Blip controller object
--]]
function Utils.createBlip(coords, blipData)
    local blipController = {
        value = 0
    }
    
    blipController.remove = function()
        RemoveBlip(blipController.value)
    end
    
    if not blipData then
        return blipController
    end
    
    blipController.value = AddBlipForCoord(coords.x, coords.y)
    
    SetBlipSprite(blipController.value, blipData.Sprite or blipData.sprite)
    SetBlipDisplay(blipController.value, 4)
    SetBlipScale(blipController.value, (blipData.Size or blipData.size) + 0.0)
    SetBlipColour(blipController.value, blipData.Color or blipData.color)
    SetBlipAsShortRange(blipController.value, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipData.Name or blipData.name)
    EndTextCommandSetBlipName(blipController.value)
    
    -- Track by invoking resource
    local invokingResource = GetInvokingResource()
    if invokingResource then
        if not createdBlips[invokingResource] then
            createdBlips[invokingResource] = {}
        end
        table.insert(createdBlips[invokingResource], blipController)
    end
    
    return blipController
end

--[[
    Create a radius blip
    @param coords - Center coordinates
    @param name - Blip name
    @param radius - Blip radius
    @param color - Blip color
    @return table - Blip controller object
--]]
function Utils.createRadiusBlip(coords, name, radius, color)
    local blipController = {}
    
    blipController.remove = function()
        RemoveBlip(blipController.value)
    end
    
    blipController.value = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    
    SetBlipDisplay(blipController.value, 4)
    SetBlipScale(blipController.value, radius)
    SetBlipColour(blipController.value, color)
    SetBlipAsShortRange(blipController.value, true)
    SetBlipAlpha(blipController.value, 150)
    
    -- Track by invoking resource
    local invokingResource = GetInvokingResource()
    if invokingResource then
        if not createdBlips[invokingResource] then
            createdBlips[invokingResource] = {}
        end
        table.insert(createdBlips[invokingResource], blipController)
    end
    
    return blipController
end

--[[
    Create a blip attached to an entity
    @param entity - Target entity
    @param blipData - Blip configuration
    @return table - Blip controller object
--]]
function Utils.createEntityBlip(entity, blipData)
    local blipController = {}
    
    blipController.remove = function()
        RemoveBlip(blipController.value)
    end
    
    blipController.value = AddBlipForEntity(entity)
    
    SetBlipSprite(blipController.value, blipData.Sprite or blipData.sprite)
    SetBlipDisplay(blipController.value, 4)
    SetBlipScale(blipController.value, blipData.Size or blipData.size)
    SetBlipColour(blipController.value, blipData.Color or blipData.color)
    SetBlipAsShortRange(blipController.value, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipData.Name or blipData.name)
    EndTextCommandSetBlipName(blipController.value)
    
    -- Track by invoking resource
    local invokingResource = GetInvokingResource()
    if invokingResource then
        if not createdBlips[invokingResource] then
            createdBlips[invokingResource] = {}
        end
        table.insert(createdBlips[invokingResource], blipController)
    end
    
    return blipController
end

--[[
    Make an entity face another entity
    @param entity - Entity to rotate
    @param targetEntity - Entity to face
--]]
function Utils.makeEntityFaceEntity(entity, targetEntity)
    local entityCoords = GetEntityCoords(entity, true)
    local targetCoords = GetEntityCoords(targetEntity, true)
    
    local dx = targetCoords.x - entityCoords.x
    local dy = targetCoords.y - entityCoords.y
    
    local heading = GetHeadingFromVector_2d(dx, dy)
    SetEntityHeading(entity, heading)
end

--[[
    Make an entity face coordinates
    @param entity - Entity to rotate
    @param coords - Coordinates to face
--]]
function Utils.makeEntityFaceCoords(entity, coords)
    local entityCoords = GetEntityCoords(entity, true)
    
    local dx = coords.x - entityCoords.x
    local dy = coords.y - entityCoords.y
    
    local heading = GetHeadingFromVector_2d(dx, dy)
    SetEntityHeading(entity, heading)
end

--[[
    Get heading from entity to coordinates
    @param entity - Source entity
    @param coords - Target coordinates
    @return number - Heading angle
--]]
function Utils.getHeadingToCoords(entity, coords)
    local entityCoords = GetEntityCoords(entity, true)
    
    local dx = coords.x - entityCoords.x
    local dy = coords.y - entityCoords.y
    
    return GetHeadingFromVector_2d(dx, dy)
end

--[[
    Check if player has any of the specified jobs
    @param jobs - Job name or table of job names
    @return boolean - True if player has one of the jobs
--]]
function Utils.hasJobs(jobs)
    if type(jobs) == "string" then
        jobs = { jobs }
    end
    
    for _, job in ipairs(jobs) do
        if Framework.getJob() == job then
            return true
        end
    end
    
    return false
end

--[[
    Check if player is police (has dispatch job)
    @return boolean - True if player is police
--]]
function Utils.isPolice()
    return Utils.hasJobs(Config.Dispatch.Jobs)
end

--[[
    Add a keybind with listener support
    @param keybindData - Keybind configuration
    @return table - Keybind controller object
--]]
function Utils.addKeybind(keybindData)
    local keybind = lib.addKeybind(keybindData)
    local listeners = {}
    
    function keybind.addListener(name, callback)
        listeners[name] = function(args)
            CreateThread(function()
                callback(args)
            end)
        end
    end
    
    function keybind.removeListener(name)
        listeners[name] = nil
    end
    
    function keybind.onReleased(args)
        for _, listener in pairs(listeners) do
            listener()
        end
    end
    
    keybind.getCurrentKey = keybind.getCurrentKey
    
    return keybind
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
    Create a coordinate-based interaction point
    @param data - Point configuration with coords, radius, options
    @param useTarget - Whether to use ox_target (optional)
    @return table - Point controller object with remove() method
--]]
function Utils.createInteractionPoint(data, useTarget)
    -- Default to Config.Target if useTarget is nil (Inherit global)
    if useTarget == nil then
        useTarget = Config.Target
    end

    local coords = data.coords
    local radius = data.radius or 1.5
    local options = data.options or {}
    
    -- Format icons for options
    for _, opt in ipairs(options) do
        if opt.icon and opt.icon ~= "" and not opt.icon:find("fa-") then
            opt.icon = string.format("fa-solid fa-%s fw", opt.icon)
        end
    end
    
    if useTarget and GetResourceState('ox_target') == 'started' then
        -- Use ox_target sphere zone
        local targetOptions = {}
        for _, opt in ipairs(options) do
            table.insert(targetOptions, {
                name = opt.label,
                icon = opt.icon,
                label = opt.label,
                onSelect = opt.onSelect,
                canInteract = opt.canInteract,
                args = opt.args
            })
        end
        
        local sphereId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = radius,
            options = targetOptions,
            debug = false
        })
        
        return {
            remove = function()
                exports.ox_target:removeZone(sphereId)
            end,
            get = function()
                return sphereId
            end
        }
    else
        -- Use lib.points with API integration
        local point = lib.points.new({
            coords = coords.xyz or coords,
            distance = radius,
            options = options
        })
        point.valid = true
        
        local originalRemove = point.remove
        function point.remove()
            point.valid = false
            originalRemove(point)
        end
        
        return point
    end
end

--[[
    Create an entity-based interaction point
    @param data - Entity configuration with entity, bone/offset, radius, options
    @param useTarget - Whether to use ox_target (optional)
    @return table - Entity controller object with remove() method
--]]
function Utils.createEntityPoint(data, useTarget)
    -- Default to Config.Target if useTarget is nil (Inherit global)
    if useTarget == nil then
        useTarget = Config.Target
    end

    local entity = data.entity
    local radius = data.radius or 2.0
    local options = data.options or {}
    
    -- Format icons for options
    for _, opt in ipairs(options) do
        if opt.icon and opt.icon ~= "" and not opt.icon:find("fa-") then
            opt.icon = string.format("fa-solid fa-%s fw", opt.icon)
        end
    end
    
    if useTarget and GetResourceState('ox_target') == 'started' then
        -- Use ox_target for entity
        local targetOptions = {}
        for _, opt in ipairs(options) do
            table.insert(targetOptions, {
                name = opt.label,
                icon = opt.icon,
                label = opt.label,
                onSelect = opt.onSelect,
                canInteract = opt.canInteract,
                args = opt.args
            })
        end
        
        local targetId = exports.ox_target:addLocalEntity(entity, targetOptions)
        
        return {
            remove = function()
                exports.ox_target:removeLocalEntity(entity, targetId)
            end,
            get = function()
                return targetId
            end
        }
    else
        -- Use prompts API for entity tracking
        local entityData = {
            entity = entity,
            bone = data.bone,
            offset = data.offset,
            radius = radius,
            options = options,
            valid = true
        }
        
        -- Set up coordinate getter based on bone or offset
        if data.bone then
            local boneIndex = GetPedBoneIndex(entity, data.bone)
            entityData.getCoords = function()
                return GetWorldPositionOfEntityBone(entity, boneIndex)
            end
        elseif data.offset then
            local offset = data.offset
            entityData.getCoords = function()
                return GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
            end
        else
            entityData.getCoords = function()
                return GetEntityCoords(entity)
            end
        end
        
        -- Try to use the prompts API if available
        if API and API.addLocalEntity then
            return API.addLocalEntity(entityData)
        end
        
        -- Fallback: create a simple point at entity coords
        local point = lib.points.new({
            coords = entityData.getCoords(),
            distance = radius,
            options = options
        })
        point.valid = true
        
        local originalRemove = point.remove
        function point.remove()
            point.valid = false
            originalRemove(point)
        end
        
        return point
    end
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

-- Keybind management
local keybinds = {}
local resourceName = GetCurrentResourceName():gsub(" ", "") .. "interact"

--[[
    Get or create interaction keybind
    @param index - Keybind index
--]]
local function getOrCreateKeybind(index)
    local currentCount = #keybinds
    local needed = index - currentCount
    
    if needed > 0 then
        for i = 1, needed do
            local keybindIndex = currentCount + i
            local isPressed = false
            
            local keybind = lib.addKeybind({
                name = resourceName .. keybindIndex,
                defaultKey = Config.Keybinds[keybindIndex],
                description = "Interaction key",
                onPressed = function()
                    isPressed = true
                end,
                onReleased = function()
                    isPressed = false
                end
            })
            
            keybind.isPressed = function()
                return isPressed
            end
            
            table.insert(keybinds, keybind)
        end
    end
end

-- Initialize keybinds
getOrCreateKeybind(#Config.Keybinds)

-- Export keybinds
Binds = keybinds
