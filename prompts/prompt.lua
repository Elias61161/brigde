-- Prompt UI Module
-- Handles the DUI-based prompt interface

local Prompt = {}

-- DUI Configuration
local DUI_SIZE = 700
local dui = CreateDui(
    string.format("https://cfx-nui-%s/web/index.html", cache.resource),
    DUI_SIZE,
    DUI_SIZE
)

-- Create runtime texture
local duiHandle = GetDuiHandle(dui)
local txd = CreateRuntimeTxd("lunar_prompt")
CreateRuntimeTextureFromDuiHandle(txd, "main", duiHandle)

-- Reload DUI on player load
Framework.onPlayerLoaded(function()
    SetDuiUrl(dui, string.format("https://cfx-nui-%s/web/index.html", cache.resource))
end)

-- State
local currentOptions = {}
local currentIndex = 1
local visibleCount = 1
local canInteractCache = {}

--[[
    Send a message to the DUI
    @param data - Data to send
--]]
local function sendMessage(data)
    SendDuiMessage(dui, json.encode(data))
end

--[[
    Set the available options
    @param options - Table of interaction options
--]]
function Prompt.setOptions(options)
    local formattedOptions = {}
    
    for _, option in ipairs(options) do
        table.insert(formattedOptions, {
            label = option.label,
            icon = option.icon ~= "" and option.icon
        })
    end
    
    sendMessage({
        action = "set_options",
        options = formattedOptions
    })
    
    currentOptions = options
    visibleCount = 1
end

--[[
    Update option visibility based on canInteract
--]]
function Prompt.updateOptions()
    table.wipe(canInteractCache)
    
    local visibleOptions = 0
    
    for i, option in ipairs(currentOptions) do
        local canInteract = not option.canInteract or option.canInteract()
        table.insert(canInteractCache, canInteract)
        
        if canInteract then
            visibleOptions = visibleOptions + 1
        end
    end
    
    sendMessage({
        action = "update_options",
        canInteract = canInteractCache
    })
    
    -- Adjust index if needed
    if visibleOptions < visibleCount then
        Prompt.setIndex(visibleOptions)
    else
        Prompt.setIndex(currentIndex)
    end
    
    visibleCount = visibleOptions
end

--[[
    Set the currently selected option index
    @param index - Option index (1-based)
--]]
function Prompt.setIndex(index)
    if index <= 0 or index > visibleCount then
        return
    end
    
    currentIndex = index
    
    sendMessage({
        action = "set_index",
        index = currentIndex - 1  -- Convert to 0-based for JS
    })
end

--[[
    Show the prompt UI
--]]
function Prompt.show()
    sendMessage({ action = "show" })
end

--[[
    Hide the prompt UI
--]]
function Prompt.hide()
    sendMessage({ action = "hide" })
    currentOptions = {}
    currentIndex = 1
end

--[[
    Draw the prompt sprite
--]]
function Prompt.draw()
    local width = 0.28
    local height = 0.28 * GetAspectRatio(false)
    
    DrawSprite(
        "lunar_prompt",
        "main",
        0.0, 0.0,
        width, height,
        0.0,
        255, 255, 255, 255
    )
end

-- Keybind: Main interaction
lib.addKeybind({
    name = "interact_prompt",
    description = "Main interaction keybind",
    defaultMapper = "keyboard",
    defaultKey = "E",
    onReleased = function()
        if not currentOptions then
            return
        end
        
        local visibleIndex = 0
        
        for i, option in ipairs(currentOptions) do
            if canInteractCache[i] then
                visibleIndex = visibleIndex + 1
                
                if visibleIndex == currentIndex then
                    option.onSelect(option.args)
                    return
                end
            end
        end
    end
})

-- Command: Scroll up
RegisterCommand("interact_scroll_up", function()
    if not currentOptions then
        return
    end
    
    Prompt.setIndex(currentIndex - 1)
end)

-- Command: Scroll down
RegisterCommand("interact_scroll_down", function()
    if not currentOptions then
        return
    end
    
    Prompt.setIndex(currentIndex + 1)
end)

-- Key mappings for scroll
RegisterKeyMapping("interact_scroll_up", "Interaction scroll up", "MOUSE_WHEEL", "IOM_WHEEL_UP")
RegisterKeyMapping("interact_scroll_down", "Interaction scroll down", "MOUSE_WHEEL", "IOM_WHEEL_DOWN")

--[[
    Get the Prompt object
    @return table - Prompt controller
--]]
function GetPrompt()
    return Prompt
end
