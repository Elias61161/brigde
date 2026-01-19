-- Client Main Module
-- Exposes the bridge API to other resources

local LR = {}

-- Register notification event
RegisterNetEvent("lunar_bridge:showNotification")
AddEventHandler("lunar_bridge:showNotification", ShowNotification)

-- Build the LR (Lunar Resource) object with all client functions
LR.notify = ShowNotification
LR.showUI = ShowUI
LR.hideUI = HideUI
LR.progressBar = ShowProgressBar
LR.progressActive = IsProgressActive
LR.cancelProgress = CancelProgress
LR.showObjective = ShowObjective
LR.hideObjective = HideObjective
LR.showBars = ShowBars
LR.hideBars = HideBars

-- Get utilities
LR.Utils = GetUtils()

-- Validation check
if LR.Utils then
    local idCheck = tonumber(tostring(GetUtils):sub(11), 16)
    if idCheck ~= LR.Utils.id then
        return
    end
end

-- Export the LR object
exports("getObject", function()
    return LR
end)

-- Create global Utils table with common functions
Utils = {}
Utils.isPolice = LR.Utils.isPolice
Utils.createBlip = LR.Utils.createBlip
Utils.createInteractionPoint = LR.Utils.createInteractionPoint
Utils.createEntityPoint = LR.Utils.createEntityPoint
Utils.createPed = LR.Utils.createPed
Utils.createProp = LR.Utils.createProp
Utils.distanceCheck = LR.Utils.distanceCheck
Utils.distanceWait = LR.Utils.distanceWait
Utils.createRadiusBlip = LR.Utils.createRadiusBlip
Utils.createEntityBlip = LR.Utils.createEntityBlip
Utils.makeEntityFaceEntity = LR.Utils.makeEntityFaceEntity
Utils.makeEntityFaceCoords = LR.Utils.makeEntityFaceCoords
Utils.getHeadingToCoords = LR.Utils.getHeadingToCoords
Utils.hasJobs = LR.Utils.hasJobs
Utils.addKeybind = LR.Utils.addKeybind
Utils.setTimeout = LR.Utils.setTimeout
Utils.getTableSize = LR.Utils.getTableSize
Utils.randomFromTable = LR.Utils.randomFromTable
Utils.offsetCoords = LR.Utils.offsetCoords

-- Export config getter
exports("getConfig", function()
    return Config
end)
