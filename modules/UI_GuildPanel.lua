--[[
    UI_GuildPanel.lua
    Guild calendars panel and category legend

    Displays:
    - Guild subscription toggles with colored dots
    - Sync button for guild event refresh
    - Category legend (Raid, Party, Training, Meeting, Personal)
]]

local TC = TamrielCalendar
local SM = TC.SyncManager

TC.GuildPanel = {}
local GP = TC.GuildPanel

-------------------------------------------------
-- Constants
-------------------------------------------------

local MAX_GUILDS = 5
local GUILD_TAG_HEIGHT = 24
local GUILD_TAG_SPACING = 4

-- Guild colors (for differentiation)
local GUILD_COLORS = {
    {0.8, 0.4, 0.4, 1},  -- Reddish
    {0.4, 0.6, 0.8, 1},  -- Bluish
    {0.5, 0.8, 0.5, 1},  -- Greenish
    {0.8, 0.7, 0.4, 1},  -- Goldish
    {0.7, 0.5, 0.8, 1},  -- Purplish
}

-- Category colors (from GUI spec)
local CATEGORY_COLORS = {
    Raid = {74/255, 32/255, 32/255, 1},
    Party = {32/255, 58/255, 74/255, 1},
    Training = {32/255, 74/255, 40/255, 1},
    Meeting = {74/255, 64/255, 32/255, 1},
    Personal = {56/255, 32/255, 74/255, 1},
}

local CATEGORY_ORDER = {"Raid", "Party", "Training", "Meeting", "Personal"}

-- Colors
local COLORS = {
    mutedText = {139/255, 115/255, 85/255, 1},
    bodyText = {232/255, 220/255, 200/255, 1},
    headerGold = {212/255, 175/255, 55/255, 1},
    checkmark = {197/255, 165/255, 82/255, 1},
}

-------------------------------------------------
-- State
-------------------------------------------------

GP.guildTags = {}       -- Guild tag controls
GP.legendItems = {}     -- Legend item controls
GP.initialized = false

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Initialize the guild panel
function GP:Initialize()
    if self.initialized then return end

    self:CreateGuildTags()
    self:CreateLegend()
    self:RefreshGuilds()

    self.initialized = true
    TC:Debug("GuildPanel: Initialized")
end

--- Create guild tag controls
function GP:CreateGuildTags()
    local tagsContainer = TamCalWindowContentLegendGuildItems
    if not tagsContainer then
        TC:Debug("GuildPanel: GuildItems container not found (TamCalWindowContentLegendGuildItems)")
        return
    end

    local xOffset = 0

    for i = 1, MAX_GUILDS do
        local tag = CreateControlFromVirtual(
            "TamCalGuildTag" .. i,
            tagsContainer,
            "TamCal_GuildTag_Template"
        )

        tag:SetAnchor(TOPLEFT, tagsContainer, TOPLEFT, xOffset, 0)
        tag:SetHidden(true)
        tag.guildIndex = i
        tag.guildId = nil
        tag.subscribed = false

        -- Get child controls
        local bg = tag:GetNamedChild("BG")
        local check = tag:GetNamedChild("Check")
        local colorDot = tag:GetNamedChild("ColorDot")
        local nameLabel = tag:GetNamedChild("Name")

        -- Style the background
        if bg then
            bg:SetCenterColor(30/255, 28/255, 25/255, 0.8)
            bg:SetEdgeColor(58/255, 53/255, 48/255, 1)
        end

        -- Style the check
        if check then
            check:SetColor(unpack(COLORS.checkmark))
            check:SetText("")
        end

        -- Style the color dot
        if colorDot then
            local guildColor = GUILD_COLORS[i] or GUILD_COLORS[1]
            colorDot:SetColor(unpack(guildColor))
        end

        -- Style the name label
        if nameLabel then
            nameLabel:SetColor(unpack(COLORS.bodyText))
        end

        tag.bg = bg
        tag.check = check
        tag.colorDot = colorDot
        tag.nameLabel = nameLabel

        self.guildTags[i] = tag
    end
end

--- Create category legend
function GP:CreateLegend()
    local legend = TamCalWindowContentLegend
    if not legend then
        TC:Debug("GuildPanel: Legend control not found (TamCalWindowContentLegend)")
        return
    end

    local legendWidth = legend:GetWidth()
    local itemWidth = legendWidth / #CATEGORY_ORDER
    local xOffset = 0

    for i, category in ipairs(CATEGORY_ORDER) do
        local item = CreateControlFromVirtual(
            "TamCalLegendItem" .. i,
            legend,
            "TamCal_LegendItem_Template"
        )

        item:SetAnchor(TOPLEFT, legend, TOPLEFT, xOffset, 0)
        item:SetWidth(itemWidth)

        local colorBox = item:GetNamedChild("ColorBox")
        local label = item:GetNamedChild("Label")

        if colorBox then
            local color = CATEGORY_COLORS[category] or {0.5, 0.5, 0.5, 1}
            colorBox:SetColor(unpack(color))
        end

        if label then
            label:SetText(category)
            label:SetColor(unpack(COLORS.mutedText))
        end

        item.category = category
        self.legendItems[i] = item

        xOffset = xOffset + itemWidth
    end
end

-------------------------------------------------
-- Guild Management
-------------------------------------------------

--- Refresh guild list and subscriptions
function GP:RefreshGuilds()
    local numGuilds = GetNumGuilds()

    -- Hide all tags first
    for i = 1, MAX_GUILDS do
        local tag = self.guildTags[i]
        if tag then
            tag:SetHidden(true)
        end
    end

    if numGuilds == 0 then
        return
    end

    -- Get subscriptions from saved vars
    local subscriptions = {}
    if TC.savedVars then
        subscriptions = TC.savedVars.guildSubscriptions or {}
    end

    local xOffset = 0
    local tagsContainer = TamCalWindowGuildPanelTags
    local containerWidth = tagsContainer and tagsContainer:GetWidth() or 600
    local maxTagWidth = 120 -- Max width per tag to fit 5 guilds

    for i = 1, numGuilds do
        local guildId = GetGuildId(i)
        local guildName = GetGuildName(guildId)
        local tag = self.guildTags[i]

        if tag and guildName and guildName ~= "" then
            -- Calculate tag width based on name, capped to max
            local estimatedWidth = math.min(self:CalculateTagWidth(guildName), maxTagWidth)

            -- Skip if tag would overflow container
            if xOffset + estimatedWidth > containerWidth then
                tag:SetHidden(true)
            else
                -- Position tag
                tag:ClearAnchors()
                tag:SetAnchor(TOPLEFT, tagsContainer, TOPLEFT, xOffset, 0)
                tag:SetWidth(estimatedWidth)
                tag:SetHidden(false)

                -- Store guild info
                tag.guildId = guildId
                tag.guildIndex = i

                -- Update name
                if tag.nameLabel then
                    -- Truncate more aggressively to fit
                    local displayName = guildName
                    local maxChars = math.floor((estimatedWidth - 50) / 6) -- Adjust for padding
                    if #displayName > maxChars then
                        displayName = displayName:sub(1, maxChars - 2) .. ".."
                    end
                    tag.nameLabel:SetText(displayName)
                end

                -- Update color dot
                if tag.colorDot then
                    local guildColor = GUILD_COLORS[i] or GUILD_COLORS[1]
                    tag.colorDot:SetColor(unpack(guildColor))
                end

                -- Update subscription state
                local isSubscribed = subscriptions[guildId] == true
                tag.subscribed = isSubscribed
                self:UpdateTagCheckmark(tag, isSubscribed)

                xOffset = xOffset + estimatedWidth + GUILD_TAG_SPACING
            end
        end
    end
end

--- Calculate tag width based on guild name
--- @param name string Guild name
--- @return number Estimated width
function GP:CalculateTagWidth(name)
    -- Base width (check + dot + padding)
    local baseWidth = 50
    -- Estimate text width (roughly 7px per character)
    local textWidth = math.min(#name * 7, 140)
    return baseWidth + textWidth
end

--- Update the checkmark display for a tag
--- @param tag control The guild tag control
--- @param subscribed boolean Whether subscribed
function GP:UpdateTagCheckmark(tag, subscribed)
    if tag.check then
        if subscribed then
            tag.check:SetText("X")
            tag.check:SetColor(unpack(COLORS.checkmark))
        else
            tag.check:SetText("")
        end
    end

    if tag.bg then
        if subscribed then
            tag.bg:SetEdgeColor(unpack(COLORS.headerGold))
        else
            tag.bg:SetEdgeColor(58/255, 53/255, 48/255, 1)
        end
    end
end

--- Toggle subscription for a guild
--- @param guildId number Guild ID
function GP:ToggleSubscription(guildId)
    if not TC.savedVars then return end

    TC.savedVars.guildSubscriptions = TC.savedVars.guildSubscriptions or {}
    local current = TC.savedVars.guildSubscriptions[guildId] == true
    TC.savedVars.guildSubscriptions[guildId] = not current

    -- Update visual
    for _, tag in ipairs(self.guildTags) do
        if tag.guildId == guildId then
            tag.subscribed = not current
            self:UpdateTagCheckmark(tag, not current)
            break
        end
    end

    local guildName = GetGuildName(guildId)
    if not current then
        d("[TamCal] Subscribed to " .. guildName)
        -- Sync immediately when subscribing
        if SM and SM.RequestEvents then
            SM:RequestEvents(guildId)
        end
    else
        d("[TamCal] Unsubscribed from " .. guildName)
    end

    PlaySound(SOUNDS.POSITIVE_CLICK)
end

-------------------------------------------------
-- Event Handlers
-------------------------------------------------

--- Handle guild tag clicked (called from XML)
function TC:OnGuildTagClicked(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end

    local guildId = control.guildId
    if guildId then
        GP:ToggleSubscription(guildId)
    end
end

--- Handle sync button clicked
function TC:OnSyncClicked()
    if not SM then
        d("[TamCal] Sync not available")
        return
    end

    if not SM:IsAvailable() then
        d("[TamCal] Guild sync not available - missing libraries")
        return
    end

    -- Sync all subscribed guilds
    local synced = 0
    if TC.savedVars and TC.savedVars.guildSubscriptions then
        for guildId, subscribed in pairs(TC.savedVars.guildSubscriptions) do
            if subscribed then
                SM:RequestEvents(guildId)
                synced = synced + 1
            end
        end
    end

    if synced > 0 then
        d("[TamCal] Syncing " .. synced .. " guild(s)...")
    else
        d("[TamCal] No guilds subscribed. Click a guild to subscribe.")
    end

    PlaySound(SOUNDS.POSITIVE_CLICK)
end

-------------------------------------------------
-- Utility
-------------------------------------------------

--- Get the color for a specific guild
--- @param guildId number Guild ID
--- @return table RGBA color
function GP:GetGuildColor(guildId)
    for i, tag in ipairs(self.guildTags) do
        if tag.guildId == guildId then
            return GUILD_COLORS[i] or GUILD_COLORS[1]
        end
    end
    return GUILD_COLORS[1]
end

--- Check if a guild is subscribed
--- @param guildId number Guild ID
--- @return boolean True if subscribed
function GP:IsSubscribed(guildId)
    if not TC.savedVars or not TC.savedVars.guildSubscriptions then
        return false
    end
    return TC.savedVars.guildSubscriptions[guildId] == true
end

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

-- Initialize when UI is ready
local function OnPlayerActivated()
    zo_callLater(function()
        GP:Initialize()
    end, 400) -- After other UI modules
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_GuildPanel", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-- Refresh when guild membership changes
EVENT_MANAGER:RegisterForEvent(TC.name .. "_GuildPanel_GuildSelf", EVENT_GUILD_SELF_JOINED_GUILD, function()
    if GP.initialized then
        GP:RefreshGuilds()
    end
end)

EVENT_MANAGER:RegisterForEvent(TC.name .. "_GuildPanel_GuildLeft", EVENT_GUILD_SELF_LEFT_GUILD, function()
    if GP.initialized then
        GP:RefreshGuilds()
    end
end)
