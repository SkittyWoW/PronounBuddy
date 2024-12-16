-- Initialize the addon
PronounBuddy = {}
local addonName = "PronounBuddy"

-- Saved variables
PronounBuddyDB = PronounBuddyDB or {}

-- Register addon events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print("PronounBuddy loaded! Use /pronouns to set your pronouns.")
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == addonName then
            -- Handle incoming pronoun messages
            local pronounData = string.match(message, "^(.*)$")
            if pronounData then
                PronounBuddyDB[sender] = pronounData
            end
        end
    end
end)

-- Slash command for setting pronouns
SLASH_PRONOUNBUDDY1 = "/pronouns"
SlashCmdList["PRONOUNBUDDY"] = function(msg)
    if msg and msg ~= "" then
        PronounBuddyDB[UnitName("player")] = msg
        print("Your pronouns have been set to: " .. msg)
        -- Broadcast to others
        C_ChatInfo.SendAddonMessage(addonName, msg, "GUILD")
    else
        print("Usage: /pronouns [your pronouns]")
    end
end

-- Function to display pronouns
local function AddPronounsToFrame(unitFrame, unit)
    if unit and UnitIsPlayer(unit) then
        local name = UnitName(unit)
        if name and PronounBuddyDB[name] then
            unitFrame.name:SetText(name .. " (" .. PronounBuddyDB[name] .. ")")
        end
    end
end

-- Hook into the target frame
hooksecurefunc("TargetFrame_Update", function(self)
    AddPronounsToFrame(self, "target")
end)

-- Hook into chat messages
local function AppendPronounsToChat(self, event, message, author, ...)
    -- Remove the server name from the author (e.g., "Player-Server")
    local playerName = Ambiguate(author, "short")
    
    -- Check if the player has set pronouns
    if PronounBuddyDB[playerName] then
        local pronouns = PronounBuddyDB[playerName]
        -- Append the pronouns to the player's name
        playerName = playerName .. " (" .. pronouns .. ")"
    end

    -- Return the modified chat message
    return false, message, playerName, ...
end

-- Register the chat filter for guild chat
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", AppendPronounsToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", AppendPronounsToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", AppendPronounsToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", AppendPronounsToChat)

-- Register the addon message prefix
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print("|cff00ff00PronounBuddy|r loaded! Use |cffffff00/pronouns [your pronouns]|r to set them.")
        C_ChatInfo.RegisterAddonMessagePrefix(addonName) -- Register addon prefix
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == addonName then
            -- Handle incoming pronoun messages
            PronounBuddy.HandleIncomingPronouns(message, sender)
        end
    end
end)

function PronounBuddy.HandleIncomingPronouns(message, sender)
    -- Remove server name from the sender
    local playerName = Ambiguate(sender, "short")
    -- Update the local database
    PronounBuddyDB[playerName] = message
    print("|cffffff00" .. playerName .. "|r set their pronouns to: |cffffd700" .. message .. "|r")
end

SlashCmdList["PRONOUNBUDDY"] = function(msg)
    if msg and msg ~= "" then
        -- Save the player's pronouns
        local playerName = UnitName("player")
        PronounBuddyDB[playerName] = msg
        print("|cff00ff00Your pronouns have been set to:|r |cffffd700" .. msg .. "|r")

        -- Broadcast to others in the guild
        C_ChatInfo.SendAddonMessage(addonName, msg, "GUILD")
        -- Optionally, send to other channels:
        -- C_ChatInfo.SendAddonMessage(addonName, msg, "PARTY")
        -- C_ChatInfo.SendAddonMessage(addonName, msg, "RAID")
    else
        print("|cff00ff00Usage:|r |cffffff00/pronouns [your pronouns]|r")
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print("|cff00ff00PronounBuddy|r loaded! Use |cffffff00/pronouns [your pronouns]|r to set them.")
        C_ChatInfo.RegisterAddonMessagePrefix(addonName) -- Register addon prefix
        
        -- Broadcast saved pronouns on login
        local playerName = UnitName("player")
        if PronounBuddyDB[playerName] then
            C_ChatInfo.SendAddonMessage(addonName, PronounBuddyDB[playerName], "GUILD")
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == addonName then
            -- Handle incoming pronoun messages
            PronounBuddy.HandleIncomingPronouns(message, sender)
        end
    end
end)

SlashCmdList["PRONOUNBUDDY_SYNC"] = function()
    -- Broadcast your pronouns to the guild
    local playerName = UnitName("player")
    if PronounBuddyDB[playerName] then
        C_ChatInfo.SendAddonMessage(addonName, PronounBuddyDB[playerName], "GUILD")
    end
end
SLASH_PRONOUNBUDDY_SYNC1 = "/pronounsync"
