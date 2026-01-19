-- NPC Interaction Module
-- Handles NPC dialogue camera and menu system

local currentPed = nil
local currentCamera = nil
local currentCallback = nil

-- Random greeting sounds
local greetingSounds = {
    "GENERIC_HI",
    "GENERIC_HOWS_IT_GOING",
    "CHAT_RESP"
}

--[[
    Open the NPC interaction menu
    @param ped - The NPC ped entity
    @param header - Menu header text
    @param dialogueData - Dialogue configuration (question, answers, etc.)
    @param callback - Callback function for responses
--]]
exports("openPedInteractionMenu", function(ped, header, dialogueData, callback)
    -- Calculate camera position
    local cameraOffset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.9, 0.55)
    local pedCoords = GetEntityCoords(ped)
    
    -- Create and position camera
    currentCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(currentCamera, cameraOffset.x, cameraOffset.y, cameraOffset.z)
    PointCamAtCoord(currentCamera, pedCoords.x, pedCoords.y, pedCoords.z + 0.4)
    RenderScriptCams(true, true, 1000, true, true)
    
    Wait(500)
    
    -- Play random greeting sound
    local soundIndex = math.random(#greetingSounds)
    local sound = greetingSounds[soundIndex]
    PlayPedAmbientSpeechNative(ped, sound, "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
    
    -- Show NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "show_npc",
        header = header,
        question = dialogueData.question,
        answers = dialogueData.answers,
        answerItems = dialogueData.answerItems,
        answerNumberInput = dialogueData.answerNumberInput
    })
    
    currentPed = ped
    currentCallback = callback
end)

-- NUI Callback: Handle NPC response
RegisterNUICallback("npc_response", function(data, cb)
    -- Validate state
    if not currentCallback or not currentPed or not currentCamera then
        return cb({})
    end
    
    -- Process response
    local responseType = data.type or data
    local response = nil
    
    if responseType == "escape" or not data then
        response = nil
    else
        response = data
    end
    
    -- Call the callback
    local nextDialogue = currentCallback(response)
    
    if nextDialogue then
        -- Continue to next question
        if data.type ~= "escape" then
            SendNUIMessage({
                action = "next_question",
                question = nextDialogue.question,
                answers = nextDialogue.answers,
                answerItems = nextDialogue.answerItems,
                answerNumberInput = nextDialogue.answerNumberInput
            })
        end
    else
        -- Close dialogue
        if data.type ~= "escape" then
            SendNUIMessage({ action = "hide_npc" })
        end
        
        SetNuiFocus(false, false)
        SetCamActive(currentCamera, false)
        RenderScriptCams(false, true, 1000, true, true)
        
        currentCallback = nil
    end
    
    cb({})
end)
