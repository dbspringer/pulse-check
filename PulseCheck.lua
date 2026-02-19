-- ============================================================================
-- PulseCheck — Battle Res & Bloodlust Tracking
-- ============================================================================

local ADDON_NAME = ...
local L = PC_L

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local BRES_SPELL_ID = 20484
local BRES_CLASS_SPELLS = {
    20484,   -- Rebirth (Druid)
    61999,   -- Raise Ally (Death Knight)
    20707,   -- Soulstone (Warlock)
    391054,  -- Intercession (Paladin)
}

local BLOODLUST_IDS = {
    2825, 32182, 80353, 90355, 178207, 230935, 256740, 160452,
    275200, 272678, 204276, 146555, 309658, 292686, 264667,
    390386, 381301, 441076, 444257, 466904,
}

local SATED_IDS = { 57723, 57724, 80354, 264689, 390435 }

local SATED_LOOKUP = {}
for _, id in ipairs(SATED_IDS) do
    SATED_LOOKUP[id] = true
end

local BRES_GCD_THRESHOLD    = 2     -- ignore cooldowns at or below GCD length
local LUST_HASTE_MULTIPLIER = 1.25  -- 25% multiplicative haste increase to infer lust
local LUST_HASTE_MIN_DELTA  = 20    -- minimum absolute haste increase to infer lust
local LUST_ASSUMED_DURATION = 40

local ICON_SIZE = 48
local ICON_GAP = 6
local ICON_BRES = 136080
local ICON_LUST = 136012

local BUILTIN_SOUNDS = {
    ["None"]            = false,
    ["Alarm Clock"]     = 12867,
    ["BNet Toast"]      = 18019,
    ["LFG Role Check"]  = 17317,
    ["Map Ping"]        = 3175,
    ["PvP Queue"]       = 8459,
    ["Raid Boss Emote"] = 12197,
    ["Raid Warning"]    = 8959,
    ["Ready Check"]     = 8960,
}

-- Preferred LSM sounds per alert, tried in order; first registered match wins.
-- BigWigs registers its sounds with LSM; DBM does not.
-- SharedMedia_Causese uses color-coded names (|cFFFF0000Name|r).
local LSM_PREFERRED = {
    lustActiveSound = { "|cFFFF0000Bloodlust|r", "BigWigs: Alert", "BigWigs: Alarm" },
    lustReadySound  = { "|cFFFF0000Ready|r", "BigWigs: Long", "BigWigs: Victory" },
    bresUsedSound   = { "|cFFFF0000Charge|r", "BigWigs: Info", "BigWigs: Beware" },
}

local DEFAULTS = {
    position    = nil,
    orientation = "horizontal",
    scale       = 1.0,
    visibility = {
        dungeons       = true,
        raids          = true,
        scenarios      = true,
        battlegrounds  = false,
        openWorld      = false,
        solo           = false,
    },
    sound = {
        lustActive      = true,
        lustActiveSound = "Alarm Clock",
        lustReady       = true,
        lustReadySound  = "LFG Role Check",
        bresUsed        = false,
        bresUsedSound   = "Raid Boss Emote",
    },
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local state = {
    lustActive           = false,
    lustExpiration       = 0,
    lustDuration         = 0,
    sated                = false,
    satedExpiration      = 0,
    satedDuration        = 0,
    raidSated            = false,
    bresCharges          = 0,
    bresMaxCharges       = 0,
    bresCooldownStart    = 0,
    bresCooldownDuration = 0,
    bresActive           = false,
}

local auraFallbackTicker = nil
local lustPollTicker     = nil
local lastHaste          = 0
local peakHaste          = 0
local lustHasteExpiration = 0
local bresPollTicker     = nil
local raidSatedTicker    = nil
local useAuraFallback    = false
local frameUnlocked      = false
local frameSelected      = false
local settingsDialog     = nil
local settingsCategory   = nil
local settingsPanel      = nil
local wasDragged         = false
local soundPickerOpen    = false
local soundPickerTimer   = nil
local dialogOnLeft       = false

local SNAP_GRID_SIZE = 10  -- pixels; snap frame position on drag release

-- Frame references (assigned during UI construction)
local mainFrame, bresIcon, lustIcon

-- ---------------------------------------------------------------------------
-- Utility Functions
-- ---------------------------------------------------------------------------

local function MergeDefaults(saved, defaults)
    if type(saved) ~= "table" then return CopyTable(defaults) end
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = v
        elseif type(v) == "table" and type(saved[k]) == "table" then
            MergeDefaults(saved[k], v)
        end
    end
    return saved
end

local function IsInInstancedContent()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "raid"
        or instanceType == "scenario" or instanceType == "pvp"
        or instanceType == "arena"
end

local function ShouldShow()
    local vis = PulseCheckDB.visibility
    local _, instanceType = GetInstanceInfo()

    if instanceType == "party" then
        return vis.dungeons
    elseif instanceType == "raid" then
        return vis.raids
    elseif instanceType == "scenario" then
        return vis.scenarios
    elseif instanceType == "pvp" or instanceType == "arena" then
        return vis.battlegrounds
    elseif IsInGroup() then
        return vis.openWorld
    else
        return vis.solo
    end
end

local function FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", seconds / 60, seconds % 60)
    elseif seconds >= 10 then
        return string.format("%d", seconds)
    else
        return string.format("%.1f", seconds)
    end
end

local function CreateCheckbox(parent, label, x, y, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(getValue())
    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
    end)
    return cb
end

local function CreateSlider(parent, label, x, y, minVal, maxVal, step, getValue, setValue)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getValue())
    slider.Low:SetText(minVal)
    slider.High:SetText(maxVal)
    slider.Text:SetText(label .. ": " .. string.format("%.1f", getValue()))
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.Text:SetText(label .. ": " .. string.format("%.1f", value))
        setValue(value)
    end)
    return slider
end

local function GetLSM()
    if LibStub then
        return LibStub("LibSharedMedia-3.0", true)
    end
    return nil
end

local function GetSoundList()
    local names = {}
    for name in pairs(BUILTIN_SOUNDS) do
        if name ~= "None" then
            names[#names + 1] = name
        end
    end

    local lsm = GetLSM()
    if lsm then
        local lsmSounds = lsm:List("sound")
        for _, name in ipairs(lsmSounds) do
            if not BUILTIN_SOUNDS[name] then
                names[#names + 1] = name
            end
        end
    end

    table.sort(names)
    table.insert(names, 1, "None")
    return names
end

local function PlayAlertSound(soundName, fallbackKey)
    if not soundName or soundName == "None" then return end

    local kitID = BUILTIN_SOUNDS[soundName]
    if kitID then
        PlaySound(kitID)
        return
    end

    local lsm = GetLSM()
    if lsm then
        local path = lsm:Fetch("sound", soundName)
        if path then
            PlaySoundFile(path, "Master")
            return
        end
    end

    -- LSM sound missing (addon removed?) — fall back to built-in default
    if fallbackKey then
        local defaultName = DEFAULTS.sound[fallbackKey]
        local defaultID = defaultName and BUILTIN_SOUNDS[defaultName]
        if defaultID then
            PlaySound(defaultID)
        end
    end
end

local function CreateSoundPicker(parent, x, y, getValue, setValue)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    container:SetSize(210, 22)

    -- Dropdown button
    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    btn:SetPoint("TOPLEFT")
    btn:SetSize(180, 22)
    btn:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetText(getValue())

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface/ChatFrame/ChatFrameExpandArrow")
    arrow:SetRotation(-math.pi / 2)

    btn:SetScript("OnClick", function(self)
        soundPickerOpen = true
        if soundPickerTimer then soundPickerTimer:Cancel() end
        local sounds = GetSoundList()
        local selectedIndex = 1
        local current = getValue()
        for i, name in ipairs(sounds) do
            if name == current then
                selectedIndex = i
                break
            end
        end
        local menu = MenuUtil.CreateContextMenu(self, function(_, rootDescription)
            rootDescription:SetScrollMode(400)
            for _, name in ipairs(sounds) do
                rootDescription:CreateRadio(
                    name,
                    function() return getValue() == name end,
                    function()
                        setValue(name)
                        label:SetText(name)
                        PlayAlertSound(name)
                    end
                )
            end
        end)
        if menu then
            -- Scroll to center the selected item
            local scrollBox = menu.ScrollBox
            if scrollBox and #sounds > 0 then
                local fraction = math.max(0, math.min(1,
                    (selectedIndex - 1) / math.max(1, #sounds - 1)))
                scrollBox:SetScrollPercentage(fraction)
            end
            local menuWidth = menu:GetWidth()
            if menuWidth and menuWidth > 0 then
                menu:ClearAllPoints()
                if dialogOnLeft then
                    menu:SetPoint("RIGHT", self, "LEFT", -2, 0)
                else
                    local btnScale = self:GetEffectiveScale()
                    local menuScale = menu:GetEffectiveScale()
                    local btnRightPx = self:GetRight() * btnScale
                    local menuWidthPx = menuWidth * menuScale
                    if btnRightPx + menuWidthPx > GetScreenWidth() then
                        menu:SetPoint("RIGHT", self, "LEFT", -2, 0)
                    else
                        menu:SetPoint("LEFT", self, "RIGHT", 2, 0)
                    end
                end
            end
            soundPickerTimer = C_Timer.NewTicker(0.2, function()
                if not menu:IsShown() then
                    soundPickerOpen = false
                    soundPickerTimer:Cancel()
                    soundPickerTimer = nil
                end
            end)
        end
    end)

    -- Preview button
    local preview = CreateFrame("Button", nil, container, "BackdropTemplate")
    preview:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    preview:SetSize(22, 22)
    preview:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    preview:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    preview:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local playIcon = preview:CreateTexture(nil, "OVERLAY")
    playIcon:SetPoint("CENTER")
    playIcon:SetSize(12, 12)
    playIcon:SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")

    preview:SetScript("OnClick", function()
        PlayAlertSound(getValue())
    end)

    function container.SetDisplayText(text)
        label:SetText(text)
    end

    return container
end

-- ---------------------------------------------------------------------------
-- Detection Functions
-- ---------------------------------------------------------------------------

local function UpdateBloodlustState()
    local oldLustActive = state.lustActive
    local oldLustExpiration = state.lustExpiration
    local oldLustDuration = state.lustDuration
    local oldSated = state.sated
    local oldSatedExpiration = state.satedExpiration
    local oldSatedDuration = state.satedDuration

    state.lustActive = false
    state.lustExpiration = 0
    state.lustDuration = 0

    for _, id in ipairs(BLOODLUST_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then
            state.lustActive = true
            state.lustExpiration = aura.expirationTime
            state.lustDuration = aura.duration or LUST_ASSUMED_DURATION
            break
        end
    end

    -- Fallback: if aura API is blocked, use haste delta to detect lust
    local currentHaste = GetHaste()
    if not state.lustActive then
        if oldLustActive and oldLustExpiration > 0 and GetTime() < oldLustExpiration then
            -- Lust was active and hasn't expired; API is unreliable
            state.lustActive = true
            state.lustExpiration = oldLustExpiration
            state.lustDuration = oldLustDuration
        elseif lustHasteExpiration > 0 and GetTime() < lustHasteExpiration then
            -- Previously inferred via haste, still within expected duration
            state.lustActive = true
            state.lustExpiration = lustHasteExpiration
            state.lustDuration = LUST_ASSUMED_DURATION
        elseif lastHaste > 0
               and currentHaste > peakHaste
               and currentHaste > lastHaste * LUST_HASTE_MULTIPLIER
               and (currentHaste - lastHaste) >= LUST_HASTE_MIN_DELTA then
            -- Large upward haste spike — infer lust activation
            lustHasteExpiration = GetTime() + LUST_ASSUMED_DURATION
            state.lustActive = true
            state.lustExpiration = lustHasteExpiration
            state.lustDuration = LUST_ASSUMED_DURATION
        end
    else
        -- Aura API confirmed lust; clear haste inference
        lustHasteExpiration = 0
    end
    lastHaste = currentHaste
    if oldLustActive and not state.lustActive then
        -- Lust just ended; reset peak so next lust can be detected
        peakHaste = currentHaste
    elseif currentHaste > peakHaste then
        peakHaste = currentHaste
    end

    state.sated = false
    state.satedExpiration = 0
    state.satedDuration = 0

    for _, id in ipairs(SATED_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then
            state.sated = true
            state.satedExpiration = aura.expirationTime
            state.satedDuration = aura.duration or 600
            break
        end
    end

    -- Aura API may return nil during combat (secret values / taint) or zone
    -- transitions.  Validate against the known expiration time before trusting
    -- a sated→false transition.
    if oldSated and not state.sated
       and oldSatedExpiration > 0 and GetTime() < oldSatedExpiration then
        state.sated = true
        state.satedExpiration = oldSatedExpiration
        state.satedDuration = oldSatedDuration
    end

    -- Sound on state transitions
    if state.lustActive and not oldLustActive and PulseCheckDB.sound.lustActive then
        PlayAlertSound(PulseCheckDB.sound.lustActiveSound, "lustActiveSound")
    end
    if oldSated and not state.sated and PulseCheckDB.sound.lustReady then
        PlayAlertSound(PulseCheckDB.sound.lustReadySound, "lustReadySound")
    end

    return (state.lustActive ~= oldLustActive) or (state.sated ~= oldSated)
end

local function UpdateBresState()
    local oldCharges = state.bresCharges

    local chargeInfo = C_Spell.GetSpellCharges(BRES_SPELL_ID)
    if chargeInfo then
        -- Encounter charge system active
        state.bresActive = true
        state.bresCharges = chargeInfo.currentCharges
        state.bresMaxCharges = chargeInfo.maxCharges
        state.bresCooldownStart = chargeInfo.cooldownStartTime
        state.bresCooldownDuration = chargeInfo.cooldownDuration
    else
        -- No encounter charges; check personal brez cooldown
        state.bresActive = false
        state.bresCharges = 0
        state.bresMaxCharges = 0
        state.bresCooldownStart = 0
        state.bresCooldownDuration = 0

        for _, id in ipairs(BRES_CLASS_SPELLS) do
            if IsPlayerSpell(id) then
                state.bresActive = true
                state.bresMaxCharges = 1
                local cooldownInfo = C_Spell.GetSpellCooldown(id)
                if cooldownInfo and cooldownInfo.duration > BRES_GCD_THRESHOLD then
                    state.bresCharges = 0
                    state.bresCooldownStart = cooldownInfo.startTime
                    state.bresCooldownDuration = cooldownInfo.duration
                elseif cooldownInfo then
                    state.bresCharges = 1
                end
                break
            end
        end
    end

    if oldCharges > 0 and state.bresCharges < oldCharges and PulseCheckDB.sound.bresUsed then
        PlayAlertSound(PulseCheckDB.sound.bresUsedSound, "bresUsedSound")
    end

    return state.bresCharges ~= oldCharges
end

local function ScanRaidSated()
    if state.sated or not IsInGroup() then
        state.raidSated = false
        return
    end

    local prefix, count
    if IsInRaid() then
        prefix = "raid"
        count = GetNumGroupMembers()
    else
        prefix = "party"
        count = GetNumGroupMembers() - 1
    end

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local index = 1
            while true do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL")
                if not aura then break end
                if SATED_LOOKUP[aura.spellId] then
                    state.raidSated = true
                    return
                end
                index = index + 1
            end
        end
    end

    state.raidSated = false
end

local function CheckSecretValues()
    if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
        useAuraFallback = C_Secrets.ShouldSpellAuraBeSecret(2825)
    else
        useAuraFallback = false
    end
end

-- ---------------------------------------------------------------------------
-- UI Construction
-- ---------------------------------------------------------------------------

local function CreateIconFrame(name, parent, iconID)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconID)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- trim default icon border
    frame.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(true)
    cooldown:SetHideCountdownNumbers(true)
    frame.cooldown = cooldown

    local timer = frame:CreateFontString(nil, "OVERLAY")
    timer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    timer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    timer:SetTextColor(1, 1, 1, 1)
    timer:Hide()
    frame.timer = timer

    return frame
end

local function ApplyLayout()
    if not mainFrame then return end

    local orientation = PulseCheckDB.orientation
    local scale = PulseCheckDB.scale
    local padding = 8  -- inset from backdrop edge

    mainFrame:SetScale(scale)

    bresIcon:ClearAllPoints()
    bresIcon:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", padding, -padding)

    lustIcon:ClearAllPoints()
    if orientation == "vertical" then
        lustIcon:SetPoint("TOPLEFT", bresIcon, "BOTTOMLEFT", 0, -ICON_GAP)
        mainFrame:SetSize(
            ICON_SIZE + padding * 2,
            ICON_SIZE * 2 + ICON_GAP + padding * 2
        )
    else
        lustIcon:SetPoint("TOPLEFT", bresIcon, "TOPRIGHT", ICON_GAP, 0)
        mainFrame:SetSize(
            ICON_SIZE * 2 + ICON_GAP + padding * 2,
            ICON_SIZE + padding * 2
        )
    end

    -- Restore saved position or default to center.
    -- Migrate old TOPLEFT-anchored positions by discarding them (pre-release only).
    local pos = PulseCheckDB.position
    if pos and pos.point == "TOPLEFT" then
        PulseCheckDB.position = nil
        pos = nil
    end
    mainFrame:ClearAllPoints()
    if pos then
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SnapToGrid(value)
    return math.floor(value / SNAP_GRID_SIZE + 0.5) * SNAP_GRID_SIZE
end

-- Update scale and re-layout. Adjust stored offset so the visual center
-- stays fixed: visual = offset * scale, so new_offset = old_offset * old/new.
local function SetScale(newScale)
    local oldScale = PulseCheckDB.scale
    PulseCheckDB.scale = newScale
    if PulseCheckDB.position then
        local pos = PulseCheckDB.position
        pos.x = pos.x * oldScale / newScale
        pos.y = pos.y * oldScale / newScale
    end
    ApplyLayout()
end

local function CreateUI()
    -- Parent container with backdrop
    mainFrame = CreateFrame("Frame", "PulseCheckFrame", UIParent, "BackdropTemplate")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.46)
    mainFrame:SetBackdropBorderColor(1, 1, 1, 1)
    mainFrame:SetFrameStrata("MEDIUM")

    -- Battle Res icon
    bresIcon = CreateIconFrame("PulseCheckBresIcon", mainFrame, ICON_BRES)

    -- Charge count text (top-right)
    local chargeText = bresIcon:CreateFontString(nil, "OVERLAY")
    chargeText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    chargeText:SetPoint("TOPRIGHT", bresIcon, "TOPRIGHT", -2, -2)
    chargeText:SetTextColor(1, 1, 1, 1)
    bresIcon.chargeText = chargeText

    -- Bloodlust icon
    lustIcon = CreateIconFrame("PulseCheckLustIcon", mainFrame, ICON_LUST)

    -- Edit Mode overlays on the whole frame (blue = unlocked, gold = selected)
    -- Uses BackdropTemplate frames with glow-style edges, extending beyond bounds
    local GLOW_INSET = 6
    local glowBackdrop = {
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    }

    local highlight = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    highlight:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -GLOW_INSET, GLOW_INSET)
    highlight:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", GLOW_INSET, -GLOW_INSET)
    highlight:SetBackdrop(glowBackdrop)
    highlight:SetBackdropColor(0, 0.5, 1, 0.25)
    highlight:SetBackdropBorderColor(0, 0.5, 1, 0.8)
    highlight:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    highlight:EnableMouse(false)
    highlight:Hide()
    mainFrame.editHighlight = highlight

    local selected = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    selected:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -GLOW_INSET, GLOW_INSET)
    selected:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", GLOW_INSET, -GLOW_INSET)
    selected:SetBackdrop(glowBackdrop)
    selected:SetBackdropColor(1, 0.82, 0, 0.25)
    selected:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    selected:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    selected:EnableMouse(false)
    selected:Hide()
    mainFrame.editSelected = selected

    ApplyLayout()
end

-- ---------------------------------------------------------------------------
-- UI Update Functions
-- ---------------------------------------------------------------------------

local function BresOnUpdate(self)
    local remaining = (state.bresCooldownStart + state.bresCooldownDuration) - GetTime()
    if remaining > 0 then
        self.timer:SetText(FormatTime(remaining))
        self.timer:Show()
    else
        self.timer:Hide()
        self:SetScript("OnUpdate", nil)
    end
end

local function LustActiveOnUpdate(self)
    local remaining = state.lustExpiration - GetTime()
    if remaining > 0 then
        self.timer:SetText(FormatTime(remaining))
        self.timer:Show()
    else
        self.timer:Hide()
        self:SetScript("OnUpdate", nil)
    end
end

local function LustSatedOnUpdate(self)
    local remaining = state.satedExpiration - GetTime()
    if remaining > 0 then
        self.timer:SetText(FormatTime(remaining))
        self.timer:Show()
    else
        self.timer:Hide()
        self:SetScript("OnUpdate", nil)
    end
end

local function RefreshBresIcon()
    if not bresIcon then return end

    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(bresIcon)
    end

    if not state.bresActive then
        bresIcon.icon:SetDesaturated(true)
        bresIcon.chargeText:SetText("")
        bresIcon.timer:Hide()
        bresIcon.cooldown:Clear()
        bresIcon:SetScript("OnUpdate", nil)
        return
    end

    bresIcon.icon:SetDesaturated(false)
    bresIcon.chargeText:SetText(state.bresCharges)

    if state.bresCharges > 0 and ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(bresIcon)
    end

    if state.bresCooldownDuration > 0 and state.bresCooldownStart > 0 then
        bresIcon.cooldown:SetCooldown(state.bresCooldownStart, state.bresCooldownDuration)
        bresIcon:SetScript("OnUpdate", BresOnUpdate)
    else
        bresIcon.cooldown:Clear()
        bresIcon.timer:Hide()
        bresIcon:SetScript("OnUpdate", nil)
    end
end

local function RefreshLustIcon()
    if not lustIcon then return end

    -- Clear previous glow
    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(lustIcon)
    end

    if state.lustActive then
        -- Active: glow + duration timer
        lustIcon.icon:SetDesaturated(false)
        lustIcon:SetAlpha(1)
        if ActionButton_ShowOverlayGlow then
            ActionButton_ShowOverlayGlow(lustIcon)
        end
        local lustDur = state.lustDuration > 0 and state.lustDuration or 40
        lustIcon.cooldown:SetCooldown(
            state.lustExpiration - lustDur,
            lustDur
        )
        lustIcon:SetScript("OnUpdate", LustActiveOnUpdate)

    elseif state.sated then
        -- Sated (personal): desaturated + lockout timer
        lustIcon.icon:SetDesaturated(true)
        lustIcon:SetAlpha(1)
        local satedDur = state.satedDuration > 0 and state.satedDuration or 600
        lustIcon.cooldown:SetCooldown(
            state.satedExpiration - satedDur,
            satedDur
        )
        lustIcon:SetScript("OnUpdate", LustSatedOnUpdate)

    elseif state.raidSated then
        -- Sated (raid fallback): dimmed, no timer
        lustIcon.icon:SetDesaturated(false)
        lustIcon:SetAlpha(0.5)
        lustIcon.cooldown:Clear()
        lustIcon.timer:Hide()
        lustIcon:SetScript("OnUpdate", nil)

    else
        -- Ready: normal
        lustIcon.icon:SetDesaturated(false)
        lustIcon:SetAlpha(1)
        lustIcon.cooldown:Clear()
        lustIcon.timer:Hide()
        lustIcon:SetScript("OnUpdate", nil)
    end
end

local function RefreshVisibility()
    if not mainFrame then return end
    local panelOpen = (settingsDialog and settingsDialog:IsShown()) or (SettingsPanel and SettingsPanel:IsShown())
    if frameUnlocked or ShouldShow() or panelOpen then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end
end

local function RefreshAll()
    UpdateBloodlustState()
    UpdateBresState()
    RefreshBresIcon()
    RefreshLustIcon()
    RefreshVisibility()
end

-- ---------------------------------------------------------------------------
-- Edit Mode Integration
-- ---------------------------------------------------------------------------


local function RepositionDialog()
    if not settingsDialog or not settingsDialog:IsShown() then return end
    local scale = mainFrame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local top = mainFrame:GetTop() * scale / uiScale
    local right = mainFrame:GetRight() * scale / uiScale
    local left = mainFrame:GetLeft() * scale / uiScale
    local dialogWidth = settingsDialog:GetWidth() * settingsDialog:GetEffectiveScale() / uiScale
    local screenWidth = GetScreenWidth() * uiScale / uiScale

    settingsDialog:ClearAllPoints()
    if right + 8 + dialogWidth > screenWidth then
        dialogOnLeft = true
        settingsDialog:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 8, top)
    else
        dialogOnLeft = false
        settingsDialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 8, top)
    end
end

local function CreateEditModeDialog()
    local dialog = CreateFrame("Frame", "PulseCheckEditDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(250, 520)
    dialog:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dialog:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    dialog:SetBackdropBorderColor(1, 0.82, 0, 1)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetClampedToScreen(true)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("PulseCheck")

    -- Layout
    local vertCB = CreateCheckbox(dialog, L.VERTICAL_ORIENTATION, 12, -36,
        function() return PulseCheckDB.orientation == "vertical" end,
        function(val)
            PulseCheckDB.orientation = val and "vertical" or "horizontal"
            ApplyLayout()
            RepositionDialog()
        end
    )

    local scaleRepositionTicker = nil
    local scaleSlider = CreateSlider(dialog, L.SCALE, 16, -72, 0.5, 2.0, 0.1,
        function() return PulseCheckDB.scale end,
        function(val)
            SetScale(val)
            if scaleRepositionTicker then scaleRepositionTicker:Cancel() end
            scaleRepositionTicker = C_Timer.NewTicker(1, function()
                scaleRepositionTicker = nil
                RepositionDialog()
            end, 1)
        end
    )

    -- Visibility header
    local visHeader = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", 12, -110)
    visHeader:SetText(L.HEADER_VISIBILITY)

    local visCB = {}
    local visOptions = {
        { key = "dungeons",       label = L.VIS_DUNGEONS,       y = -128 },
        { key = "raids",          label = L.VIS_RAIDS,          y = -154 },
        { key = "scenarios",      label = L.VIS_SCENARIOS,      y = -180 },
        { key = "battlegrounds",  label = L.VIS_BATTLEGROUNDS,  y = -206 },
        { key = "openWorld",      label = L.VIS_OPEN_WORLD,     y = -232 },
        { key = "solo",           label = L.VIS_SOLO,           y = -258 },
    }
    for _, opt in ipairs(visOptions) do
        visCB[opt.key] = CreateCheckbox(dialog, opt.label, 12, opt.y,
            function() return PulseCheckDB.visibility[opt.key] end,
            function(val)
                PulseCheckDB.visibility[opt.key] = val
                RefreshVisibility()
            end
        )
    end

    -- Sounds header
    local soundHeader = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", 12, -288)
    soundHeader:SetText(L.HEADER_SOUNDS)

    local lustActiveCB = CreateCheckbox(dialog, L.SOUND_LUST_ACTIVE, 12, -306,
        function() return PulseCheckDB.sound.lustActive end,
        function(val) PulseCheckDB.sound.lustActive = val end
    )
    local lustActivePicker = CreateSoundPicker(dialog, 30, -332,
        function() return PulseCheckDB.sound.lustActiveSound end,
        function(val) PulseCheckDB.sound.lustActiveSound = val end
    )

    local lustReadyCB = CreateCheckbox(dialog, L.SOUND_LUST_READY, 12, -358,
        function() return PulseCheckDB.sound.lustReady end,
        function(val) PulseCheckDB.sound.lustReady = val end
    )
    local lustReadyPicker = CreateSoundPicker(dialog, 30, -384,
        function() return PulseCheckDB.sound.lustReadySound end,
        function(val) PulseCheckDB.sound.lustReadySound = val end
    )

    local bresUsedCB = CreateCheckbox(dialog, L.SOUND_BRES_USED, 12, -410,
        function() return PulseCheckDB.sound.bresUsed end,
        function(val) PulseCheckDB.sound.bresUsed = val end
    )
    local bresUsedPicker = CreateSoundPicker(dialog, 30, -436,
        function() return PulseCheckDB.sound.bresUsedSound end,
        function(val) PulseCheckDB.sound.bresUsedSound = val end
    )

    -- Reset Defaults button
    local resetBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 12, -478)
    resetBtn:SetPoint("RIGHT", dialog, "RIGHT", -12, 0)
    resetBtn:SetHeight(24)
    resetBtn:SetText(L.RESET_DEFAULTS)
    resetBtn:SetScript("OnClick", function()
        PulseCheckDB = CopyTable(DEFAULTS)
        ApplyLayout()
        RepositionDialog()
        RefreshVisibility()
        -- Refresh dialog widgets
        vertCB:SetChecked(PulseCheckDB.orientation == "vertical")
        scaleSlider:SetValue(PulseCheckDB.scale)
        for _, opt in ipairs(visOptions) do
            visCB[opt.key]:SetChecked(PulseCheckDB.visibility[opt.key])
        end
        lustActiveCB:SetChecked(PulseCheckDB.sound.lustActive)
        lustActivePicker.SetDisplayText(PulseCheckDB.sound.lustActiveSound)
        lustReadyCB:SetChecked(PulseCheckDB.sound.lustReady)
        lustReadyPicker.SetDisplayText(PulseCheckDB.sound.lustReadySound)
        bresUsedCB:SetChecked(PulseCheckDB.sound.bresUsed)
        bresUsedPicker.SetDisplayText(PulseCheckDB.sound.bresUsedSound)
        print("|cff00ccffPulseCheck:|r " .. L.MSG_RESET)
    end)

    dialog:SetScript("OnShow", function()
        vertCB:SetChecked(PulseCheckDB.orientation == "vertical")
        scaleSlider:SetValue(PulseCheckDB.scale)
        for _, opt in ipairs(visOptions) do
            visCB[opt.key]:SetChecked(PulseCheckDB.visibility[opt.key])
        end
        lustActiveCB:SetChecked(PulseCheckDB.sound.lustActive)
        lustActivePicker.SetDisplayText(PulseCheckDB.sound.lustActiveSound)
        lustReadyCB:SetChecked(PulseCheckDB.sound.lustReady)
        lustReadyPicker.SetDisplayText(PulseCheckDB.sound.lustReadySound)
        bresUsedCB:SetChecked(PulseCheckDB.sound.bresUsed)
        bresUsedPicker.SetDisplayText(PulseCheckDB.sound.bresUsedSound)
    end)

    dialog:Hide()
    return dialog
end

local function SetFrameSelected(selected)
    if not selected and soundPickerOpen then return end
    frameSelected = selected
    if not mainFrame then return end

    if selected then
        -- Swap from blue highlight to gold selected
        mainFrame.editHighlight:Hide()
        mainFrame.editSelected:Show()
        -- Clear Blizzard's selection so ours doesn't conflict
        if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
            EditModeManagerFrame:ClearSelectedSystem()
        end
        -- Lazily create the settings dialog
        if not settingsDialog then
            settingsDialog = CreateEditModeDialog()
        end
        settingsDialog:Show()
        RepositionDialog()
    else
        -- Revert to blue highlight if still in Edit Mode
        mainFrame.editSelected:Hide()
        if frameUnlocked then mainFrame.editHighlight:Show() end
        if settingsDialog then
            settingsDialog:Hide()
        end
    end
end

local function SetFrameUnlocked(unlocked)
    frameUnlocked = unlocked
    if not mainFrame then return end

    if unlocked then
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:EnableMouse(true)
        mainFrame.editHighlight:Show()
        RefreshVisibility()
    else
        SetFrameSelected(false)
        mainFrame:RegisterForDrag()
        mainFrame:EnableMouse(false)
        mainFrame.editHighlight:Hide()
        RefreshVisibility()
    end
end

local function SetupEditMode()
    if not mainFrame then return end

    mainFrame:SetScript("OnMouseDown", function()
        wasDragged = false
    end)

    mainFrame:SetScript("OnDragStart", function(self)
        if frameUnlocked then
            wasDragged = true
            self:StartMoving()
        end
    end)

    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Snap the frame's center to the grid. SetPoint offsets are in
        -- UIParent coords so GetCenter() values can be used directly.
        local cx, cy = self:GetCenter()
        local snappedCX = SnapToGrid(cx)
        local snappedCY = SnapToGrid(cy)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", snappedCX, snappedCY)
        PulseCheckDB.position = {
            point = "CENTER",
            relativePoint = "BOTTOMLEFT",
            x = snappedCX,
            y = snappedCY,
        }
        RepositionDialog()
    end)

    mainFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and frameUnlocked and not wasDragged then
            SetFrameSelected(not frameSelected)
        end
    end)

    -- Deselect when clicking outside the frame or dialog
    mainFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mainFrame:HookScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" and frameSelected then
            if not mainFrame:IsMouseOver()
               and not (settingsDialog and settingsDialog:IsMouseOver()) then
                SetFrameSelected(false)
            end
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        SetFrameUnlocked(true)
    end, ADDON_NAME)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        SetFrameUnlocked(false)
    end, ADDON_NAME)
end

-- ---------------------------------------------------------------------------
-- Polling Tickers
-- ---------------------------------------------------------------------------

local function StartAuraFallbackTicker()
    if auraFallbackTicker then return end
    auraFallbackTicker = C_Timer.NewTicker(0.5, function()
        -- Re-check if auras are still secret
        if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
           and not C_Secrets.ShouldSpellAuraBeSecret(2825) then
            useAuraFallback = false
            auraFallbackTicker:Cancel()
            auraFallbackTicker = nil
            return
        end
        if UpdateBloodlustState() then
            RefreshLustIcon()
        end
    end)
end

local function StopAuraFallbackTicker()
    if auraFallbackTicker then
        auraFallbackTicker:Cancel()
        auraFallbackTicker = nil
    end
end

local function StartLustPollTicker()
    if lustPollTicker then return end
    lustPollTicker = C_Timer.NewTicker(1, function()
        if UpdateBloodlustState() then
            RefreshLustIcon()
        end
    end)
end

local function StopLustPollTicker()
    if lustPollTicker then
        lustPollTicker:Cancel()
        lustPollTicker = nil
    end
end

local function StartBresPollTicker()
    if bresPollTicker then return end
    bresPollTicker = C_Timer.NewTicker(0.5, function()
        UpdateBresState()
        RefreshBresIcon()
    end)
end

local function StopBresPollTicker()
    if bresPollTicker then
        bresPollTicker:Cancel()
        bresPollTicker = nil
    end
end

local function StartRaidSatedTicker()
    if raidSatedTicker then return end
    raidSatedTicker = C_Timer.NewTicker(3, function()
        local oldRaidSated = state.raidSated
        ScanRaidSated()
        if state.raidSated ~= oldRaidSated then
            RefreshLustIcon()
        end
    end)
end

local function StopRaidSatedTicker()
    if raidSatedTicker then
        raidSatedTicker:Cancel()
        raidSatedTicker = nil
    end
end

local function UpdateInstancePolling()
    if IsInInstancedContent() then
        StartLustPollTicker()
        StartBresPollTicker()
        StartRaidSatedTicker()
    else
        StopLustPollTicker()
        StopBresPollTicker()
        StopRaidSatedTicker()
        state.raidSated = false
        lastHaste = 0
        peakHaste = 0
        lustHasteExpiration = 0
        UpdateBresState()
        RefreshBresIcon()
    end
end

-- ---------------------------------------------------------------------------
-- Settings Panel
-- ---------------------------------------------------------------------------

local function BuildOptionsPanel()
    settingsPanel = CreateFrame("Frame")
    settingsPanel.name = "PulseCheck"

    if SettingsPanel then
        SettingsPanel:HookScript("OnHide", function()
            RefreshVisibility()
        end)
    end

    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PulseCheck")

    local subtitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText(L.ADDON_SUBTITLE)

    local hint = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -4)
    hint:SetText(L.EDIT_MODE_HINT)

    -- Orientation
    local vertCB = CreateCheckbox(settingsPanel, L.VERTICAL_ORIENTATION, 16, -72,
        function() return PulseCheckDB.orientation == "vertical" end,
        function(val)
            PulseCheckDB.orientation = val and "vertical" or "horizontal"
            ApplyLayout()
        end
    )

    -- Scale
    local scaleSlider = CreateSlider(settingsPanel, L.SCALE, 20, -110, 0.5, 2.0, 0.1,
        function() return PulseCheckDB.scale end,
        function(val)
            SetScale(val)
        end
    )

    -- Visibility
    local visHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", 16, -160)
    visHeader:SetText(L.HEADER_VISIBILITY)

    local panelVisOptions = {
        { key = "dungeons",       label = L.VIS_DUNGEONS,       col = 1, row = 1 },
        { key = "raids",          label = L.VIS_RAIDS,          col = 2, row = 1 },
        { key = "scenarios",      label = L.VIS_SCENARIOS,      col = 1, row = 2 },
        { key = "battlegrounds",  label = L.VIS_BATTLEGROUNDS,  col = 2, row = 2 },
        { key = "openWorld",      label = L.VIS_OPEN_WORLD,     col = 1, row = 3 },
        { key = "solo",           label = L.VIS_SOLO,           col = 2, row = 3 },
    }
    local visBaseY = -180
    local visRowH = 30
    local visCol1X = 16
    local visCol2X = 250
    local visCB = {}
    for _, opt in ipairs(panelVisOptions) do
        local x = opt.col == 1 and visCol1X or visCol2X
        local y = visBaseY - (opt.row - 1) * visRowH
        visCB[opt.key] = CreateCheckbox(settingsPanel, opt.label, x, y,
            function() return PulseCheckDB.visibility[opt.key] end,
            function(val)
                PulseCheckDB.visibility[opt.key] = val
                RefreshVisibility()
            end
        )
    end

    -- Sounds header
    local soundHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", 16, -270)
    soundHeader:SetText(L.HEADER_SOUNDS)

    local lustActiveCB = CreateCheckbox(settingsPanel, L.SOUND_LUST_ACTIVE, 16, -290,
        function() return PulseCheckDB.sound.lustActive end,
        function(val) PulseCheckDB.sound.lustActive = val end
    )
    local lustActivePicker = CreateSoundPicker(settingsPanel, 34, -316,
        function() return PulseCheckDB.sound.lustActiveSound end,
        function(val) PulseCheckDB.sound.lustActiveSound = val end
    )

    local lustReadyCB = CreateCheckbox(settingsPanel, L.SOUND_LUST_READY, 16, -342,
        function() return PulseCheckDB.sound.lustReady end,
        function(val) PulseCheckDB.sound.lustReady = val end
    )
    local lustReadyPicker = CreateSoundPicker(settingsPanel, 34, -368,
        function() return PulseCheckDB.sound.lustReadySound end,
        function(val) PulseCheckDB.sound.lustReadySound = val end
    )

    local bresUsedCB = CreateCheckbox(settingsPanel, L.SOUND_BRES_USED, 16, -394,
        function() return PulseCheckDB.sound.bresUsed end,
        function(val) PulseCheckDB.sound.bresUsed = val end
    )
    local bresUsedPicker = CreateSoundPicker(settingsPanel, 34, -420,
        function() return PulseCheckDB.sound.bresUsedSound end,
        function(val) PulseCheckDB.sound.bresUsedSound = val end
    )

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 16, -470)
    resetBtn:SetSize(120, 24)
    resetBtn:SetText(L.RESET_DEFAULTS)
    resetBtn:SetScript("OnClick", function()
        PulseCheckDB = CopyTable(DEFAULTS)
        ApplyLayout()
        RefreshVisibility()
        if settingsCategory then
            Settings.OpenToCategory(settingsCategory:GetID())
        end
        print("|cff00ccffPulseCheck:|r " .. L.MSG_RESET)
    end)

    settingsPanel:SetScript("OnShow", function()
        if mainFrame then mainFrame:Show() end
        vertCB:SetChecked(PulseCheckDB.orientation == "vertical")
        scaleSlider:SetValue(PulseCheckDB.scale)
        for _, opt in ipairs(panelVisOptions) do
            visCB[opt.key]:SetChecked(PulseCheckDB.visibility[opt.key])
        end
        lustActiveCB:SetChecked(PulseCheckDB.sound.lustActive)
        lustActivePicker.SetDisplayText(PulseCheckDB.sound.lustActiveSound)
        lustReadyCB:SetChecked(PulseCheckDB.sound.lustReady)
        lustReadyPicker.SetDisplayText(PulseCheckDB.sound.lustReadySound)
        bresUsedCB:SetChecked(PulseCheckDB.sound.bresUsed)
        bresUsedPicker.SetDisplayText(PulseCheckDB.sound.bresUsedSound)
    end)

    -- Version and locale info
    local versionText = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOMLEFT", 16, 16)
    versionText:SetText(string.format(L.VERSION_LABEL,
        C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"), GetLocale()))

    settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, "PulseCheck")
    Settings.RegisterAddOnCategory(settingsCategory)
end

-- ---------------------------------------------------------------------------
-- Slash Commands
-- ---------------------------------------------------------------------------

local function HandleSlashCommand(msg)
    local args = {}
    for word in msg:lower():gmatch("%S+") do
        table.insert(args, word)
    end

    local cmd = args[1]

    if not cmd then
        -- Open options panel
        if settingsCategory then
            Settings.OpenToCategory(settingsCategory:GetID())
        end
        return
    end

    if cmd == "unlock" then
        SetFrameUnlocked(true)
        print("|cff00ccffPulseCheck:|r " .. L.MSG_UNLOCKED)
        return
    end

    if cmd == "lock" then
        SetFrameUnlocked(false)
        print("|cff00ccffPulseCheck:|r " .. L.MSG_LOCKED)
        return
    end

    if cmd == "orientation" then
        if PulseCheckDB.orientation == "horizontal" then
            PulseCheckDB.orientation = "vertical"
        else
            PulseCheckDB.orientation = "horizontal"
        end
        ApplyLayout()
        print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_ORIENTATION, PulseCheckDB.orientation))
        return
    end

    if cmd == "scale" then
        local val = tonumber(args[2])
        if val and val >= 0.5 and val <= 2.0 then
            SetScale(val)
            print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_SCALE, val))
        else
            print("|cff00ccffPulseCheck:|r " .. L.MSG_SCALE_USAGE)
        end
        return
    end

    if cmd == "sound" then
        local target = args[2]
        local value = args[3]
        if target == "lust" and (value == "on" or value == "off") then
            local enabled = value == "on"
            PulseCheckDB.sound.lustActive = enabled
            PulseCheckDB.sound.lustReady = enabled
            print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_SOUND_TOGGLE, "Bloodlust", value))
        elseif target == "bres" and (value == "on" or value == "off") then
            PulseCheckDB.sound.bresUsed = value == "on"
            print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_SOUND_TOGGLE, "Battle res", value))
        else
            print("|cff00ccffPulseCheck:|r " .. L.MSG_SOUND_USAGE)
        end
        return
    end

    if cmd == "show" then
        local VISIBILITY_KEYS = {
            dungeons = L.VIS_DUNGEONS, raids = L.VIS_RAIDS,
            scenarios = L.VIS_SCENARIOS, battlegrounds = L.VIS_BATTLEGROUNDS,
            openworld = L.VIS_OPEN_WORLD, solo = L.VIS_SOLO,
        }
        local target = args[2]
        local value = args[3]
        -- Normalize "openworld" to the DB key "openWorld"
        local dbKey = target == "openworld" and "openWorld" or target
        if target and VISIBILITY_KEYS[target] and (value == "on" or value == "off") then
            PulseCheckDB.visibility[dbKey] = value == "on"
            print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_VIS_TOGGLE, VISIBILITY_KEYS[target], value))
        elseif target == "all" and (value == "on" or value == "off") then
            local enabled = value == "on"
            for key in pairs(PulseCheckDB.visibility) do
                PulseCheckDB.visibility[key] = enabled
            end
            print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_VIS_ALL, value))
        else
            print("|cff00ccffPulseCheck:|r " .. L.MSG_VIS_USAGE)
        end
        RefreshVisibility()
        return
    end

    if cmd == "reset" then
        PulseCheckDB = CopyTable(DEFAULTS)
        ApplyLayout()
        RefreshVisibility()
        print("|cff00ccffPulseCheck:|r " .. L.MSG_RESET)
        return
    end

    if cmd ~= "help" then
        print("|cff00ccffPulseCheck:|r " .. string.format(L.MSG_UNKNOWN_CMD, cmd))
    end
    print("|cff00ccff" .. L.HELP_HEADER .. "|r")
    print(L.HELP_OPEN)
    print(L.HELP_HELP)
    print(L.HELP_LOCK)
    print(L.HELP_ORIENTATION)
    print(L.HELP_SCALE)
    print(L.HELP_SOUND)
    print(L.HELP_SHOW)
    print(L.HELP_RESET)
end

SLASH_PULSECHECK1 = "/pulsecheck"
SLASH_PULSECHECK2 = "/plc"
SlashCmdList["PULSECHECK"] = HandleSlashCommand

-- ---------------------------------------------------------------------------
-- Event Handler
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        PulseCheckDB = MergeDefaults(PulseCheckDB, DEFAULTS)

        -- Migrate from old showAlways boolean to visibility table
        if PulseCheckDB.showAlways ~= nil then
            if PulseCheckDB.showAlways then
                for key in pairs(PulseCheckDB.visibility) do
                    PulseCheckDB.visibility[key] = true
                end
            end
            PulseCheckDB.showAlways = nil
        end

        CreateUI()
        SetupEditMode()
        BuildOptionsPanel()

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Apply preferred LSM sounds once if available (must run here,
        -- not ADDON_LOADED, because LSM sounds aren't registered yet at load time)
        if not PulseCheckDB.lsmDefaultsApplied then
            local lsm = GetLSM()
            if lsm then
                PulseCheckDB.lsmDefaultsApplied = true
                for key, candidates in pairs(LSM_PREFERRED) do
                    if PulseCheckDB.sound[key] == DEFAULTS.sound[key] then
                        for _, name in ipairs(candidates) do
                            if lsm:IsValid("sound", name) then
                                PulseCheckDB.sound[key] = name
                                break
                            end
                        end
                    end
                end
            end
        end

        CheckSecretValues()
        if useAuraFallback then
            StartAuraFallbackTicker()
        end
        UpdateInstancePolling()
        RefreshAll()

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
        if not useAuraFallback then
            if UpdateBloodlustState() then
                RefreshLustIcon()
            end
        end

    elseif event == "SPELL_UPDATE_CHARGES" then
        UpdateBresState()
        RefreshBresIcon()

    elseif event == "ENCOUNTER_START" or event == "CHALLENGE_MODE_START" then
        RefreshAll()

    elseif event == "ENCOUNTER_END" or event == "CHALLENGE_MODE_COMPLETED" then
        state.raidSated = false
        RefreshAll()

    elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateInstancePolling()
        RefreshVisibility()
        UpdateBresState()
        RefreshBresIcon()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
