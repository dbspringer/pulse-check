# Background & Border Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add two independent toggles to show/hide the main frame's background and border.

**Architecture:** Two new saved-variable booleans (`showBackground`, `showBorder`) control backdrop alpha values. A helper function `ApplyBackdropStyle()` reads the DB and calls `SetBackdropColor`/`SetBackdropBorderColor` with alpha 0 (hidden) or the default value (shown). Checkboxes are added to both the Edit Mode dialog and the options panel.

**Tech Stack:** WoW Lua 5.1, BackdropTemplate API

---

### Task 1: Add locale strings

**Files:**
- Modify: `Locales/enUS.lua:13-15`

**Step 1: Add two new strings after the existing Layout section**

In `Locales/enUS.lua`, add after `L.SCALE` (line 15):

```lua
L.SHOW_BACKGROUND         = "Show background"
L.SHOW_BORDER             = "Show border"
```

**Step 2: Commit**

```bash
git add Locales/enUS.lua
git commit -m "Add locale strings for background and border toggles"
```

---

### Task 2: Add saved variable defaults and helper function

**Files:**
- Modify: `PulseCheck.lua:74-94` (DEFAULTS table)
- Modify: `PulseCheck.lua` (new helper function near CreateUI)

**Step 1: Add defaults**

In the `DEFAULTS` table (line 77, after `scale`), add:

```lua
    showBackground = true,
    showBorder     = true,
```

**Step 2: Add `ApplyBackdropStyle()` helper**

Place this as a new local function before `CreateUI()` (before line 723). It reads the DB and applies the correct alpha values:

```lua
local function ApplyBackdropStyle()
    if not mainFrame then return end
    local bgAlpha = PulseCheckDB.showBackground and 0.46 or 0
    local borderAlpha = PulseCheckDB.showBorder and 1 or 0
    mainFrame:SetBackdropColor(0, 0, 0, bgAlpha)
    mainFrame:SetBackdropBorderColor(1, 1, 1, borderAlpha)
end
```

**Step 3: Call `ApplyBackdropStyle()` in `CreateUI()`**

In `CreateUI()`, replace the two hardcoded color lines (lines 734-735):

```lua
    mainFrame:SetBackdropColor(0, 0, 0, 0.46)
    mainFrame:SetBackdropBorderColor(1, 1, 1, 1)
```

with:

```lua
    ApplyBackdropStyle()
```

**Step 4: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add showBackground/showBorder defaults and ApplyBackdropStyle helper"
```

---

### Task 3: Add checkboxes to Edit Mode dialog

**Files:**
- Modify: `PulseCheck.lua:970-990` (CreateEditModeDialog)

**Step 1: Add two checkboxes after `vertCB` (line 977), before `scaleSlider` (line 980)**

The vertical orientation checkbox is at y=-36. Place the two new checkboxes below it. Then shift the scale slider down to make room.

```lua
    local bgCB = CreateCheckbox(dialog, L.SHOW_BACKGROUND, 12, -62,
        function() return PulseCheckDB.showBackground end,
        function(val)
            PulseCheckDB.showBackground = val
            ApplyBackdropStyle()
        end
    )

    local borderCB = CreateCheckbox(dialog, L.SHOW_BORDER, 12, -88,
        function() return PulseCheckDB.showBorder end,
        function(val)
            PulseCheckDB.showBorder = val
            ApplyBackdropStyle()
        end
    )
```

**Step 2: Shift all subsequent y-offsets down by 52px**

Every element below the old scale slider position needs its y-offset decreased by 52. This affects:
- `scaleSlider`: -72 → -124
- `visHeader`: -110 → -162
- All `visOptions` y values: subtract 52 from each
- `soundHeader`: -288 → -340
- All sound checkboxes and pickers: subtract 52 from each y
- `resetBtn`: -478 → -530
- Dialog height: 520 → 572

**Step 3: Add reset logic for the new checkboxes**

In the `resetBtn` OnClick handler, after `vertCB:SetChecked(...)`, add:

```lua
        bgCB:SetChecked(PulseCheckDB.showBackground)
        borderCB:SetChecked(PulseCheckDB.showBorder)
        ApplyBackdropStyle()
```

**Step 4: Add OnShow refresh for the new checkboxes**

In the dialog's `OnShow` handler, add:

```lua
        bgCB:SetChecked(PulseCheckDB.showBackground)
        borderCB:SetChecked(PulseCheckDB.showBorder)
```

**Step 5: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add background and border toggles to Edit Mode dialog"
```

---

### Task 4: Add checkboxes to Options Panel

**Files:**
- Modify: `PulseCheck.lua:1320-1335` (BuildOptionsPanel)

**Step 1: Add two checkboxes on the same row as the vertical orientation checkbox**

The vertical checkbox is at x=16, y=-72. Place the two new ones to the right on the same row:

```lua
    local bgCB = CreateCheckbox(settingsPanel, L.SHOW_BACKGROUND, 200, -72,
        function() return PulseCheckDB.showBackground end,
        function(val)
            PulseCheckDB.showBackground = val
            ApplyBackdropStyle()
        end
    )

    local borderCB = CreateCheckbox(settingsPanel, L.SHOW_BORDER, 380, -72,
        function() return PulseCheckDB.showBorder end,
        function(val)
            PulseCheckDB.showBorder = val
            ApplyBackdropStyle()
        end
    )
```

**Note:** These share the same y=-72 as `vertCB`, so no other offsets need to change in the options panel.

**Step 2: Add OnShow refresh**

In the panel's `OnShow` handler (line 1414), add:

```lua
        bgCB:SetChecked(PulseCheckDB.showBackground)
        borderCB:SetChecked(PulseCheckDB.showBorder)
```

**Step 3: Add reset logic**

The options panel reset button (line 1404) resets by calling `CopyTable(DEFAULTS)` then reopens the panel, which triggers `OnShow` and refreshes all widgets. Since `OnShow` already refreshes the new checkboxes (Step 2), and `ApplyBackdropStyle()` will be called by `ApplyLayout()` … actually, reset doesn't call `ApplyBackdropStyle()` explicitly. Add it after `RefreshVisibility()` in the reset handler:

```lua
        ApplyBackdropStyle()
```

**Step 4: Commit**

```bash
git add PulseCheck.lua
git commit -m "Add background and border toggles to options panel"
```

---

### Task 5: Verify and final commit

**Step 1: Review all changes**

Run `git diff main` and verify:
- `DEFAULTS` has `showBackground` and `showBorder`
- `ApplyBackdropStyle()` exists and is called from `CreateUI()`, both checkbox handlers, and both reset handlers
- Edit Mode dialog has the two checkboxes after vertical orientation, before scale
- Options panel has the two checkboxes on the same row as vertical orientation
- Locale file has both new strings
- All y-offsets in the Edit Mode dialog are shifted correctly

**Step 2: Verify no globals leaked**

Search for any new unlocalized references: `showBackground` and `showBorder` should only appear inside `PulseCheckDB.*` and `DEFAULTS.*`.
