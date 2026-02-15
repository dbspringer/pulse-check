# PulseCheck Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a single-file WoW addon that tracks battle res charges and bloodlust/sated status with Edit Mode integration.

**Architecture:** Event-driven state detection with polling fallback for 12.0 secret values. Two icon frames in a draggable container. Settings via modern Settings API + slash commands.

**Tech Stack:** Lua 5.1 (WoW embedded), WoW API (retail 12.0+, Interface 120001)

**Note:** WoW addons cannot be unit tested locally. Verification steps use `luac -p` for syntax checking where available, and describe expected in-game behavior for manual testing. Each task adds to the same `PulseCheck.lua` file progressively.

---

### Task 1: TOC File + Lua Scaffold (Constants, State, Utilities)

**Files:**
- Create: `PulseCheck.toc`
- Create: `PulseCheck.lua`

**Step 1: Create the TOC file**

```toc
## Interface: 120001
## Title: PulseCheck
## Notes: Battle res and bloodlust cooldown tracking
## Author: KidMoxie
## Version: 1.0.0
## SavedVariables: PulseCheckDB

PulseCheck.lua
```

**Step 2: Create PulseCheck.lua with constants, state, and utility functions**

```lua
-- ============================================================================
-- PulseCheck — Battle Res & Bloodlust Tracking
-- ============================================================================

local ADDON_NAME = ...

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local BRES_SPELL_ID = 20484

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

local ICON_SIZE = 48
local ICON_GAP = 6
local ICON_BRES = 136080
local ICON_LUST = 136012

local SOUND_LUST_ACTIVE = 8959   -- Raid warning
local SOUND_LUST_READY  = 8960   -- Ready check
local SOUND_BRES_USED   = 3175   -- Map ping

local DEFAULTS = {
    position    = nil,
    orientation = "horizontal",
    scale       = 1.0,
    showAlways  = false,
    sound = {
        lustActive = true,
        lustReady  = true,
        bresUsed   = false,
    },
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local state = {
    lustActive           = false,
    lustExpiration       = 0,
    sated                = false,
    satedExpiration      = 0,
    raidSated            = false,
    bresCharges          = 0,
    bresMaxCharges       = 0,
    bresCooldownStart    = 0,
    bresCooldownDuration = 0,
    bresActive           = false,
}

local auraFallbackTicker = nil
local bresPollTicker     = nil
local raidSatedTicker    = nil
local useAuraFallback    = false
local frameUnlocked      = false

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

local function ShouldShow()
    if PulseCheckDB.showAlways then return true end
    return IsInGroup() or IsInInstance()
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
```

**Step 3: Verify syntax**

Run: `luac -p PulseCheck.lua` (if available) or review for syntax errors.
Expected: No output (clean parse). If `luac` is not installed, skip.

**Step 4: Commit**

```bash
git add PulseCheck.toc PulseCheck.lua
git commit -m "Add TOC and Lua scaffold with constants and utilities"
```

---

### Task 2: Detection Functions

**Files:**
- Modify: `PulseCheck.lua` — append after the Utility Functions section

**Step 1: Add detection functions**

Append this code after the `FormatTime` function:

```lua
-- ---------------------------------------------------------------------------
-- Detection Functions
-- ---------------------------------------------------------------------------

local function UpdateBloodlustState()
    local oldLustActive = state.lustActive
    local oldSated = state.sated

    state.lustActive = false
    state.lustExpiration = 0

    for _, id in ipairs(BLOODLUST_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then
            state.lustActive = true
            state.lustExpiration = aura.expirationTime
            break
        end
    end

    state.sated = false
    state.satedExpiration = 0

    for _, id in ipairs(SATED_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then
            state.sated = true
            state.satedExpiration = aura.expirationTime
            break
        end
    end

    -- Sound on state transitions
    if state.lustActive and not oldLustActive and PulseCheckDB.sound.lustActive then
        PlaySound(SOUND_LUST_ACTIVE)
    end
    if oldSated and not state.sated and PulseCheckDB.sound.lustReady then
        PlaySound(SOUND_LUST_READY)
    end

    return (state.lustActive ~= oldLustActive) or (state.sated ~= oldSated)
end

local function UpdateBresState()
    local oldCharges = state.bresCharges

    local chargeInfo = C_Spell.GetSpellCharges(BRES_SPELL_ID)
    if chargeInfo then
        state.bresActive = true
        state.bresCharges = chargeInfo.currentCharges
        state.bresMaxCharges = chargeInfo.maxCharges
        state.bresCooldownStart = chargeInfo.cooldownStartTime
        state.bresCooldownDuration = chargeInfo.cooldownDuration
    else
        state.bresActive = false
        state.bresCharges = 0
        state.bresMaxCharges = 0
        state.bresCooldownStart = 0
        state.bresCooldownDuration = 0
    end

    if oldCharges > 0 and state.bresCharges < oldCharges and PulseCheckDB.sound.bresUsed then
        PlaySound(SOUND_BRES_USED)
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
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add bloodlust, bres, and raid sated detection functions"
```

---

### Task 3: UI Frame Construction

**Files:**
- Modify: `PulseCheck.lua` — append after the Detection Functions section

**Step 1: Add UI construction code**

```lua
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

    -- Edit Mode highlight overlay
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0, 0.5, 1, 0.3)
    highlight:Hide()
    frame.editHighlight = highlight

    return frame
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

    ApplyLayout()
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

    -- Restore saved position or default to center
    if PulseCheckDB.position then
        local pos = PulseCheckDB.position
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add UI frame construction with icon, cooldown, and text elements"
```

---

### Task 4: UI Update Functions

**Files:**
- Modify: `PulseCheck.lua` — append after the UI Construction section

**Step 1: Add UI update functions**

```lua
-- ---------------------------------------------------------------------------
-- UI Update Functions
-- ---------------------------------------------------------------------------

local function RefreshBresIcon()
    if not bresIcon then return end

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

    if state.bresCooldownDuration > 0 and state.bresCooldownStart > 0 then
        bresIcon.cooldown:SetCooldown(state.bresCooldownStart, state.bresCooldownDuration)
        bresIcon:SetScript("OnUpdate", function(self, elapsed)
            local remaining = (state.bresCooldownStart + state.bresCooldownDuration) - GetTime()
            if remaining > 0 then
                self.timer:SetText(FormatTime(remaining))
                self.timer:Show()
            else
                self.timer:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
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
        lustIcon.cooldown:SetCooldown(
            state.lustExpiration - 40,  -- bloodlust is 40s duration
            40
        )
        lustIcon:SetScript("OnUpdate", function(self, elapsed)
            local remaining = state.lustExpiration - GetTime()
            if remaining > 0 then
                self.timer:SetText(FormatTime(remaining))
                self.timer:Show()
            else
                self.timer:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)

    elseif state.sated then
        -- Sated (personal): desaturated + lockout timer
        lustIcon.icon:SetDesaturated(true)
        lustIcon:SetAlpha(1)
        lustIcon.cooldown:SetCooldown(
            state.satedExpiration - 600,  -- sated is 10 min
            600
        )
        lustIcon:SetScript("OnUpdate", function(self, elapsed)
            local remaining = state.satedExpiration - GetTime()
            if remaining > 0 then
                self.timer:SetText(FormatTime(remaining))
                self.timer:Show()
            else
                self.timer:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)

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
    if ShouldShow() then
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
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add UI update functions for bres, lust, and visibility"
```

---

### Task 5: Edit Mode Integration + Drag Handling

**Files:**
- Modify: `PulseCheck.lua` — append after the UI Update Functions section

**Step 1: Add Edit Mode and drag code**

```lua
-- ---------------------------------------------------------------------------
-- Edit Mode Integration
-- ---------------------------------------------------------------------------

local function SetFrameUnlocked(unlocked)
    frameUnlocked = unlocked
    if not mainFrame then return end

    if unlocked then
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:EnableMouse(true)
        if bresIcon then bresIcon.editHighlight:Show() end
        if lustIcon then lustIcon.editHighlight:Show() end
    else
        mainFrame:RegisterForDrag()
        mainFrame:EnableMouse(false)
        if bresIcon then bresIcon.editHighlight:Hide() end
        if lustIcon then lustIcon.editHighlight:Hide() end
    end
end

local function SetupEditMode()
    if not mainFrame then return end

    mainFrame:SetScript("OnDragStart", function(self)
        if frameUnlocked then
            self:StartMoving()
        end
    end)

    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        PulseCheckDB.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        SetFrameUnlocked(true)
    end, ADDON_NAME)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        SetFrameUnlocked(false)
    end, ADDON_NAME)
end
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add Edit Mode integration with drag handling and position persistence"
```

---

### Task 6: Fallback Polling + Raid Sated Scan Tickers

**Files:**
- Modify: `PulseCheck.lua` — append after the Edit Mode section

**Step 1: Add ticker management code**

```lua
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
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add polling tickers for aura fallback, bres, and raid sated scan"
```

---

### Task 7: Event Handler + Startup Lifecycle

**Files:**
- Modify: `PulseCheck.lua` — append after the Polling Tickers section

**Step 1: Add event handler and initialization code**

```lua
-- ---------------------------------------------------------------------------
-- Event Handler
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        PulseCheckDB = MergeDefaults(PulseCheckDB, DEFAULTS)

        CreateUI()
        SetupEditMode()

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckSecretValues()
        if useAuraFallback then
            StartAuraFallbackTicker()
        end
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

    elseif event == "ENCOUNTER_START" then
        StartBresPollTicker()
        StartRaidSatedTicker()
        UpdateBresState()
        RefreshBresIcon()

    elseif event == "ENCOUNTER_END" then
        StopBresPollTicker()
        StopRaidSatedTicker()
        state.raidSated = false
        RefreshLustIcon()

    elseif event == "CHALLENGE_MODE_START" then
        StartBresPollTicker()
        StartRaidSatedTicker()
        UpdateBresState()
        RefreshBresIcon()

    elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
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
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add event handler and startup lifecycle"
```

**In-game verification at this point:** The addon should load, display two icons at screen center, respond to bloodlust/sated aura changes, track bres charges during encounters, and be draggable during Edit Mode. This is the core functionality milestone.

---

### Task 8: Slash Commands

**Files:**
- Modify: `PulseCheck.lua` — insert before the Event Handler section (after Polling Tickers, before the `local eventFrame = CreateFrame("Frame")` line)

**Step 1: Add slash command handler**

```lua
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
        Settings.OpenToCategory("PulseCheck")
        return
    end

    if cmd == "unlock" then
        SetFrameUnlocked(true)
        print("|cff00ccffPulseCheck:|r Frame unlocked. Drag to reposition.")
        return
    end

    if cmd == "lock" then
        SetFrameUnlocked(false)
        print("|cff00ccffPulseCheck:|r Frame locked.")
        return
    end

    if cmd == "orientation" then
        if PulseCheckDB.orientation == "horizontal" then
            PulseCheckDB.orientation = "vertical"
        else
            PulseCheckDB.orientation = "horizontal"
        end
        ApplyLayout()
        print("|cff00ccffPulseCheck:|r Orientation set to " .. PulseCheckDB.orientation .. ".")
        return
    end

    if cmd == "scale" then
        local val = tonumber(args[2])
        if val and val >= 0.5 and val <= 2.0 then
            PulseCheckDB.scale = val
            ApplyLayout()
            print("|cff00ccffPulseCheck:|r Scale set to " .. val .. ".")
        else
            print("|cff00ccffPulseCheck:|r Usage: /plc scale <0.5-2.0>")
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
            print("|cff00ccffPulseCheck:|r Bloodlust sounds " .. value .. ".")
        elseif target == "bres" and (value == "on" or value == "off") then
            PulseCheckDB.sound.bresUsed = value == "on"
            print("|cff00ccffPulseCheck:|r Battle res sounds " .. value .. ".")
        else
            print("|cff00ccffPulseCheck:|r Usage: /plc sound <lust|bres> <on|off>")
        end
        return
    end

    if cmd == "show" then
        local mode = args[2]
        if mode == "always" then
            PulseCheckDB.showAlways = true
            print("|cff00ccffPulseCheck:|r Always visible.")
        elseif mode == "group" then
            PulseCheckDB.showAlways = false
            print("|cff00ccffPulseCheck:|r Visible in groups only.")
        else
            print("|cff00ccffPulseCheck:|r Usage: /plc show <always|group>")
        end
        RefreshVisibility()
        return
    end

    if cmd == "reset" then
        PulseCheckDB = CopyTable(DEFAULTS)
        ApplyLayout()
        RefreshVisibility()
        print("|cff00ccffPulseCheck:|r Settings reset to defaults.")
        return
    end

    -- Help / unknown command
    print("|cff00ccffPulseCheck commands:|r")
    print("  /plc — Open settings")
    print("  /plc lock|unlock — Lock/unlock frame position")
    print("  /plc orientation — Toggle horizontal/vertical")
    print("  /plc scale <0.5-2.0> — Set icon scale")
    print("  /plc sound <lust|bres> <on|off> — Toggle sounds")
    print("  /plc show <always|group> — Set visibility")
    print("  /plc reset — Reset to defaults")
end

SLASH_PULSECHECK1 = "/pulsecheck"
SLASH_PULSECHECK2 = "/plc"
SlashCmdList["PULSECHECK"] = HandleSlashCommand
```

**Step 2: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 3: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add slash commands for all settings"
```

---

### Task 9: Settings Panel

**Files:**
- Modify: `PulseCheck.lua` — insert before the Slash Commands section

**Step 1: Add options panel code**

This uses the modern `Settings.RegisterCanvasLayoutCategory` API introduced in 11.0. The panel is a manually built canvas with controls.

```lua
-- ---------------------------------------------------------------------------
-- Settings Panel
-- ---------------------------------------------------------------------------

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
    slider.Text:SetText(label .. ": " .. getValue())
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.Text:SetText(label .. ": " .. string.format("%.1f", value))
        setValue(value)
    end)
    return slider
end

local function BuildOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "PulseCheck"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PulseCheck")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Battle res and bloodlust cooldown tracking")

    -- Visibility
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    visHeader:SetText("Visibility")

    CreateCheckbox(panel, "Show when not in a group", 16, -90,
        function() return PulseCheckDB.showAlways end,
        function(val) PulseCheckDB.showAlways = val; RefreshVisibility() end
    )

    -- Orientation
    CreateCheckbox(panel, "Vertical orientation", 16, -120,
        function() return PulseCheckDB.orientation == "vertical" end,
        function(val)
            PulseCheckDB.orientation = val and "vertical" or "horizontal"
            ApplyLayout()
        end
    )

    -- Scale
    CreateSlider(panel, "Scale", 20, -170, 0.5, 2.0, 0.1,
        function() return PulseCheckDB.scale end,
        function(val)
            PulseCheckDB.scale = val
            ApplyLayout()
        end
    )

    -- Sounds header
    local soundHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", 16, -220)
    soundHeader:SetText("Sounds")

    CreateCheckbox(panel, "Bloodlust activated", 16, -240,
        function() return PulseCheckDB.sound.lustActive end,
        function(val) PulseCheckDB.sound.lustActive = val end
    )

    CreateCheckbox(panel, "Bloodlust ready (sated expired)", 16, -270,
        function() return PulseCheckDB.sound.lustReady end,
        function(val) PulseCheckDB.sound.lustReady = val end
    )

    CreateCheckbox(panel, "Battle res charge used", 16, -300,
        function() return PulseCheckDB.sound.bresUsed end,
        function(val) PulseCheckDB.sound.bresUsed = val end
    )

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 16, -350)
    resetBtn:SetSize(120, 24)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        PulseCheckDB = CopyTable(DEFAULTS)
        ApplyLayout()
        RefreshVisibility()
        print("|cff00ccffPulseCheck:|r Settings reset to defaults.")
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "PulseCheck")
    Settings.RegisterAddOnCategory(category)
end
```

**Step 2: Wire BuildOptionsPanel into initialization**

In the `ADDON_LOADED` handler (Task 7), add a call to `BuildOptionsPanel()` after `SetupEditMode()`:

Find this block in the ADDON_LOADED handler:
```lua
        CreateUI()
        SetupEditMode()

        self:UnregisterEvent("ADDON_LOADED")
```

Replace with:
```lua
        CreateUI()
        SetupEditMode()
        BuildOptionsPanel()

        self:UnregisterEvent("ADDON_LOADED")
```

**Step 3: Verify syntax**

Run: `luac -p PulseCheck.lua`

**Step 4: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add settings panel in Interface > AddOns"
```

---

### Task 10: CHANGELOG + Final Review

**Files:**
- Create: `CHANGELOG.md`
- Modify: `PulseCheck.lua` — any final fixes from review

**Step 1: Create CHANGELOG.md**

```markdown
# Changelog

## 1.0.0

- Initial release
- Battle resurrection charge tracking with cooldown timer
- Bloodlust/sated detection across 20 buff spell IDs and 5 sated debuff IDs
- Raid-wide sated scan as fallback when player missed bloodlust
- Four bloodlust visual states: ready, active (glow), sated (desaturated), raid sated (dimmed)
- Edit Mode integration for frame positioning
- Settings panel in Interface > AddOns
- Slash commands: /pulsecheck, /plc
- Configurable sounds for bloodlust and battle res events
- 12.0 secret values fallback via polling
```

**Step 2: Review complete PulseCheck.lua**

Read through the entire file and verify:
- All forward references are resolved (functions called before they're defined should be declared as locals at the top, or reorder as needed)
- No accidental globals (all variables and functions are `local` except saved variables and slash command globals)
- Consistent formatting

**Known forward reference issues to fix:**
- `ApplyLayout()` is called in `CreateUI()` but defined after it — move `ApplyLayout` above `CreateUI`, or declare `local ApplyLayout` at the top and assign later
- `RefreshLustIcon()` is referenced in `StartAuraFallbackTicker()` and `StartRaidSatedTicker()` — these are called after the function is defined in the event flow, so this is fine at runtime, but for clarity consider forward-declaring
- `RefreshAll()` calls `UpdateBloodlustState()`, `UpdateBresState()`, etc. — these are defined above, so no issue

**Step 3: Fix any forward reference issues found in review**

Ensure `ApplyLayout` is either:
- Defined before `CreateUI`, or
- Forward-declared at the top of the file: `local ApplyLayout` and then assigned: `ApplyLayout = function() ... end`

**Step 4: Verify syntax one final time**

Run: `luac -p PulseCheck.lua`

**Step 5: Commit**

```bash
git add CHANGELOG.md PulseCheck.lua
git commit -m "Add CHANGELOG and fix forward references"
```

---

## In-Game Testing Checklist

After all tasks are complete, test in WoW:

1. **Addon loads** — `/plc` opens settings panel, two icons visible at screen center
2. **Edit Mode** — enter Edit Mode, icons show blue highlight, drag to reposition, exit Edit Mode locks position
3. **Slash commands** — test `/plc orientation`, `/plc scale 1.5`, `/plc sound lust off`, `/plc show always`, `/plc reset`
4. **Battle res** — enter a raid encounter, verify charge count updates, cooldown swipe shows during recharge, icon desaturates when not in encounter
5. **Bloodlust active** — have someone cast bloodlust, verify glow + timer, hear raid warning sound
6. **Sated** — after lust expires, verify desaturated icon + 10-minute timer
7. **Sated expired** — when sated falls off, verify ready check sound plays, icon returns to normal
8. **Raid sated fallback** — die during bloodlust, get rezzed after lust ends, verify icon shows dimmed (raid sated) state
9. **Visibility** — leave group, verify icons hide. `/plc show always` makes them visible solo
10. **Reload/relog** — verify position and settings persist
