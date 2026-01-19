-- Prompts API Module
-- Provides API for creating interaction points and entity prompts

-- Create API table with automatic export
API = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, value)
        exports(key, value)
    end
})

--[[
    Format icon strings for Font Awesome
    @param options - Table of options with icon fields
--]]
local function formatIcons(options)
    for _, option in ipairs(options) do
        if option.icon and option.icon ~= "" then
            option.icon = string.format("fa-solid fa-%s fw", option.icon)
        end
    end
end

--[[
    Create a lib.points wrapper with validity tracking
    @param pointData - Point configuration
    @return table - Point object with validity tracking
--]]
local function createPoint(pointData)
    local point = lib.points.new(pointData)
    point.valid = true
    
    local originalRemove = point.remove
    
    function point:remove()
        self.valid = false
        originalRemove(self)
    end
    
    return point
end

--[[
    Add a coordinate-based interaction point
    @param pointData - Point configuration with coords, distance, options
    @return table - Point controller object
--]]
API.addPoint = function(pointData)
    formatIcons(pointData.options)
    return createPoint(pointData)
end

--[[
    Add an entity-based interaction point
    @param entityData - Entity configuration with entity, bone/offset, radius, options
    @return table - Entity controller object
--]]
API.addLocalEntity = function(entityData)
    formatIcons(entityData.options)
    entityData.valid = true
    
    -- Set up coordinate getter based on bone or offset
    if entityData.bone then
        local boneIndex = GetPedBoneIndex(entityData.entity, entityData.bone)
        
        entityData.getCoords = function()
            return GetWorldPositionOfEntityBone(entityData.entity, boneIndex)
        end
    elseif entityData.offset then
        local offset = entityData.offset
        
        entityData.getCoords = function()
            return GetOffsetFromEntityInWorldCoords(entityData.entity, offset.x, offset.y, offset.z)
        end
    else
        entityData.getCoords = function()
            return GetEntityCoords(entityData.entity)
        end
    end
    
    -- Add to entity tracking
    local entityId = AddEntity(entityData)
    
    local controller = {
        remove = function()
            entityData.valid = false
            RemoveEntity(entityId)
        end
    }
    
    return controller
end
