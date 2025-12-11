--[[
    PronounBuddy - World of Warcraft Addon
    Allows players to set and display their pronouns in-game
    Version: 2.0
    Author: Sophia
]]--

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

PronounBuddy = PronounBuddy or {}
local addonName = "PronounBuddy"
local VERSION = "1.0"

-- Constants
local MAX_PRONOUN_LENGTH = 50
local COLOR_SUCCESS = "|cff00ff00"
local COLOR_ERROR = "|cffff0000"
local COLOR_WARNING = "|cffff8800"
local COLOR_INFO = "|cffffff00"
local COLOR_GOLD = "|cffffd700"
local COLOR_END = "|r"

-- ============================================================================
-- SAVED VARIABLES
-- ============================================================================

-- Initialize saved variables with defaults
PronounBuddyDB = PronounBuddyDB or {
    pronouns = {},  -- Stores player pronouns: [playerName] = "pronouns"
    settings = {
        showNotifications = true,
        showInChat = true,
        showInTargetFrame = true,
        enableAutoSync = true
    }
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Prints a formatted message to chat
--- @param msg string The message to print
--- @param color string Optional color code
local function Print(msg, color)
    color = color or COLOR_INFO
    print(color .. "[PronounBuddy]" .. COLOR_END .. " " .. msg)
end

--- Validates pronoun input
--- @param text string The pronoun text to validate
--- @return boolean, string Success status and error message if any
local function ValidatePronouns(text)
    if not text or text == "" then
        return false, "Pronouns cannot be empty"
    end
    
    -- Trim whitespace
    text = text:match("^%s*(.-)%s*$")
    
    if text == "" then
        return false, "Pronouns cannot be empty"
    end
    
    if #text > MAX_PRONOUN_LENGTH then
        return false, "Pronouns too long (max " .. MAX_PRONOUN_LENGTH .. " characters)"
    end
    
    -- Check for control characters
    if text:match("[%c%z]") then
        return false, "Pronouns contain invalid characters"
    end
    
    return true, text
end

--- Gets a clean player name without server suffix
--- @param fullName string The full player name
--- @return string The cleaned player name
local function GetCleanName(fullName)
    return Ambiguate(fullName, "short")
end

--- Safely broadcasts a message to a channel
--- @param message string The message to broadcast
--- @param channel string The channel to broadcast to
--- @return boolean Success status
local function SafeBroadcast(message, channel)
    local success, err = pcall(function()
        C_ChatInfo.SendAddonMessage(addonName, message, channel)
    end)
    
    if not success then
        Print("Failed to broadcast to " .. channel .. ": " .. tostring(err), COLOR_ERROR)
        return false
    end
    
    return true
end

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

--- Sets the player's pronouns
--- @param pronouns string The pronouns to set
function PronounBuddy.SetPronouns(pronouns)
    local valid, result = ValidatePronouns(pronouns)
    
    if not valid then
        Print(result, COLOR_ERROR)
        return false
    end
    
    local playerName = UnitName("player")
    PronounBuddyDB.pronouns[playerName] = result
    
    Print("Your pronouns have been set to: " .. COLOR_GOLD .. result .. COLOR_END, COLOR_SUCCESS)
    
    -- Broadcast to guild if enabled and in guild
    if PronounBuddyDB.settings.enableAutoSync then
        PronounBuddy.BroadcastPronouns()
    end
    
    return true
end

--- Clears the player's pronouns
function PronounBuddy.ClearPronouns()
    local playerName = UnitName("player")
    PronounBuddyDB.pronouns[playerName] = nil
    Print("Your pronouns have been cleared.", COLOR_SUCCESS)
    
    -- Optionally broadcast the removal
    if IsInGuild() and PronounBuddyDB.settings.enableAutoSync then
        SafeBroadcast("__CLEAR__", "GUILD")
    end
end

--- Broadcasts the player's pronouns to available channels
function PronounBuddy.BroadcastPronouns()
    local playerName = UnitName("player")
    local pronouns = PronounBuddyDB.pronouns[playerName]
    
    if not pronouns then
        Print("You haven't set your pronouns yet. Use /pronouns [your pronouns]", COLOR_WARNING)
        return
    end
    
    local broadcasted = false
    
    -- Try guild first
    if IsInGuild() then
        if SafeBroadcast(pronouns, "GUILD") then
            broadcasted = true
        end
    end
    
    if not broadcasted then
        Print("You must be in a guild to share pronouns with others.", COLOR_WARNING)
    end
end

--- Handles incoming pronoun messages from other players
--- @param message string The pronoun message
--- @param sender string The sender's name
function PronounBuddy.HandleIncomingPronouns(message, sender)
    local playerName = GetCleanName(sender)
    
    -- Handle clear command
    if message == "__CLEAR__" then
        PronounBuddyDB.pronouns[playerName] = nil
        if PronounBuddyDB.settings.showNotifications then
            Print(COLOR_INFO .. playerName .. COLOR_END .. " cleared their pronouns.")
        end
        return
    end
    
    -- Validate received pronouns
    local valid, result = ValidatePronouns(message)
    if not valid then
        return  -- Silently ignore invalid data
    end
    
    -- Update database
    PronounBuddyDB.pronouns[playerName] = result
    
    -- Notify if enabled
    if PronounBuddyDB.settings.showNotifications then
        Print(COLOR_INFO .. playerName .. COLOR_END .. " set their pronouns to: " .. COLOR_GOLD .. result .. COLOR_END)
    end
end

--- Gets pronouns for a player
--- @param playerName string The player's name
--- @return string|nil The player's pronouns or nil
function PronounBuddy.GetPronouns(playerName)
    playerName = GetCleanName(playerName)
    return PronounBuddyDB.pronouns[playerName]
end

--- Formats a player name with pronouns
--- @param playerName string The player's name
--- @return string The formatted name with pronouns
local function FormatNameWithPronouns(playerName)
    local pronouns = PronounBuddy.GetPronouns(playerName)
    if pronouns then
        return playerName .. " (" .. pronouns .. ")"
    end
    return playerName
end

-- ============================================================================
-- UI INTEGRATION
-- ============================================================================

--- Updates a unit frame to show pronouns
--- @param unitFrame table The unit frame to update
--- @param unit string The unit ID
local function UpdateFrameWithPronouns(unitFrame, unit)
    if not PronounBuddyDB.settings.showInTargetFrame then
        return
    end
    
    if unit and UnitIsPlayer(unit) then
        local name = UnitName(unit)
        if name then
            local formattedName = FormatNameWithPronouns(name)
            if unitFrame.name then
                unitFrame.name:SetText(formattedName)
            end
        end
    end
end

--- Chat message filter to append pronouns to player names
--- @return boolean, string, string, ... Modified message data
local function ChatMessageFilter(self, event, message, author, ...)
    if not PronounBuddyDB.settings.showInChat then
        return false, message, author, ...
    end
    
    local playerName = GetCleanName(author)
    local formattedName = FormatNameWithPronouns(playerName)
    
    return false, message, formattedName, ...
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Register addon message prefix
            C_ChatInfo.RegisterAddonMessagePrefix(addonName)
            
            -- Welcome message
            Print("Loaded! Use " .. COLOR_INFO .. "/pronouns [your pronouns]" .. COLOR_END .. " to set them.", COLOR_SUCCESS)
            
            -- Show current pronouns if set
            local playerName = UnitName("player")
            if PronounBuddyDB.pronouns[playerName] then
                Print("Your current pronouns: " .. COLOR_GOLD .. PronounBuddyDB.pronouns[playerName] .. COLOR_END)
            end
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Broadcast pronouns on login/zone change (only once per session)
        if not PronounBuddy.hasAutoSynced and PronounBuddyDB.settings.enableAutoSync then
            PronounBuddy.hasAutoSynced = true
            local playerName = UnitName("player")
            if PronounBuddyDB.pronouns[playerName] and IsInGuild() then
                C_TimerAfter(3, function()  -- Delay to ensure guild roster is loaded
                    PronounBuddy.BroadcastPronouns()
                end)
            end
        end
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == addonName then
            PronounBuddy.HandleIncomingPronouns(message, sender)
        end
    end
end)

-- ============================================================================
-- HOOKS AND FILTERS
-- ============================================================================

-- Hook target frame updates
hooksecurefunc("TargetFrame_Update", function(self)
    UpdateFrameWithPronouns(TargetFrame, "target")
end)

-- Register chat filters
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatMessageFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatMessageFilter)

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

--- Main pronouns command handler
SLASH_PRONOUNBUDDY1 = "/pronouns"
SLASH_PRONOUNBUDDY2 = "/pronoun"
SlashCmdList["PRONOUNBUDDY"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""  -- Trim whitespace
    
    if msg == "" then
        -- Show help
        Print("Usage:")
        print("  " .. COLOR_INFO .. "/pronouns [text]" .. COLOR_END .. " - Set your pronouns")
        print("  " .. COLOR_INFO .. "/pronouns clear" .. COLOR_END .. " - Clear your pronouns")
        print("  " .. COLOR_INFO .. "/pronouns show" .. COLOR_END .. " - Show your current pronouns")
        print("  " .. COLOR_INFO .. "/pronouns list" .. COLOR_END .. " - List all known pronouns")
        print("  " .. COLOR_INFO .. "/pronouns help" .. COLOR_END .. " - Show this help")
        return
    end
    
    local command = msg:lower()
    
    if command == "clear" or command == "remove" then
        PronounBuddy.ClearPronouns()
        
    elseif command == "show" then
        local playerName = UnitName("player")
        local pronouns = PronounBuddyDB.pronouns[playerName]
        if pronouns then
            Print("Your pronouns: " .. COLOR_GOLD .. pronouns .. COLOR_END)
        else
            Print("You haven't set your pronouns yet.", COLOR_WARNING)
        end
        
    elseif command == "list" then
        local count = 0
        Print("Known pronouns:")
        for name, pronouns in pairs(PronounBuddyDB.pronouns) do
            print("  " .. COLOR_INFO .. name .. COLOR_END .. ": " .. COLOR_GOLD .. pronouns .. COLOR_END)
            count = count + 1
        end
        if count == 0 then
            print("  No pronouns recorded yet.")
        end
        
    elseif command == "help" then
        Print("PronounBuddy v" .. VERSION)
        print("Set and display pronouns in-game.")
        print("Examples: she/her, he/him, they/them, any pronouns")
        print("Use " .. COLOR_INFO .. "/pronouns" .. COLOR_END .. " for command list")
        
    else
        -- Set pronouns
        PronounBuddy.SetPronouns(msg)
    end
end

--- Sync command handler
SLASH_PRONOUNBUDDY_SYNC1 = "/pronounsync"
SlashCmdList["PRONOUNBUDDY_SYNC"] = function()
    PronounBuddy.BroadcastPronouns()
end

--- Settings command handler
SLASH_PRONOUNBUDDY_SETTINGS1 = "/pronounsettings"
SlashCmdList["PRONOUNBUDDY_SETTINGS"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    
    if msg == "" then
        Print("Current Settings:")
        print("  Notifications: " .. (PronounBuddyDB.settings.showNotifications and "ON" or "OFF"))
        print("  Show in Chat: " .. (PronounBuddyDB.settings.showInChat and "ON" or "OFF"))
        print("  Show in Target Frame: " .. (PronounBuddyDB.settings.showInTargetFrame and "ON" or "OFF"))
        print("  Auto-sync on Login: " .. (PronounBuddyDB.settings.enableAutoSync and "ON" or "OFF"))
        print("")
        print("Usage: " .. COLOR_INFO .. "/pronounsettings [setting] [on|off]" .. COLOR_END)
        print("Settings: notifications, chat, targetframe, autosync")
        return
    end
    
    local setting, value = msg:match("^(%S+)%s+(%S+)$")
    if not setting or not value then
        Print("Usage: /pronounsettings [setting] [on|off]", COLOR_ERROR)
        return
    end
    
    local enabled = value:lower() == "on"
    setting = setting:lower()
    
    if setting == "notifications" then
        PronounBuddyDB.settings.showNotifications = enabled
        Print("Notifications: " .. (enabled and "ON" or "OFF"))
    elseif setting == "chat" then
        PronounBuddyDB.settings.showInChat = enabled
        Print("Show in Chat: " .. (enabled and "ON" or "OFF"))
    elseif setting == "targetframe" then
        PronounBuddyDB.settings.showInTargetFrame = enabled
        Print("Show in Target Frame: " .. (enabled and "ON" or "OFF"))
    elseif setting == "autosync" then
        PronounBuddyDB.settings.enableAutoSync = enabled
        Print("Auto-sync on Login: " .. (enabled and "ON" or "OFF"))
    else
        Print("Unknown setting: " .. setting, COLOR_ERROR)
    end
end

-- ============================================================================
-- END OF FILE
-- ============================================================================
