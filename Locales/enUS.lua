PC_L = {}
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Battle res and bloodlust cooldown tracking"
L.EDIT_MODE_HINT          = "Position is configured in HUD Edit Mode (Esc > Edit Mode)"

-- Section headers
L.HEADER_VISIBILITY       = "Visibility"
L.HEADER_SOUNDS           = "Sounds"

-- Layout
L.VERTICAL_ORIENTATION    = "Vertical orientation"
L.SCALE                   = "Scale"

-- Visibility options
L.VIS_DUNGEONS            = "Dungeons"
L.VIS_RAIDS               = "Raids"
L.VIS_SCENARIOS           = "Scenarios / Delves"
L.VIS_BATTLEGROUNDS       = "Battlegrounds / Arena"
L.VIS_OPEN_WORLD          = "Open world groups"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes (shared between dialog and panel)
L.SOUND_LUST_ACTIVE       = "Bloodlust activated"
L.SOUND_LUST_READY        = "Bloodlust ready (sated expired)"
L.SOUND_BRES_USED         = "Battle res charge used"

-- Buttons
L.RESET_DEFAULTS          = "Reset Defaults"

-- Slash command output (use string.format with these)
L.MSG_RESET               = "Settings reset to defaults."
L.MSG_UNLOCKED            = "Frame unlocked. Drag to reposition."
L.MSG_LOCKED              = "Frame locked."
L.MSG_ORIENTATION         = "Orientation set to %s."
L.MSG_SCALE               = "Scale set to %s."
L.MSG_SCALE_USAGE         = "Usage: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "%s sounds %s."
L.MSG_SOUND_USAGE         = "Usage: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "%s visibility %s."
L.MSG_VIS_ALL             = "All visibility %s."
L.MSG_VIS_USAGE           = "Usage: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Unknown command '%s'."

-- Help text
L.HELP_HEADER             = "PulseCheck commands:"
L.HELP_OPEN               = "  /plc — Open settings"
L.HELP_HELP               = "  /plc help — Show this help"
L.HELP_LOCK               = "  /plc lock|unlock — Lock/unlock frame position"
L.HELP_ORIENTATION        = "  /plc orientation — Toggle horizontal/vertical"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> — Set icon scale"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> — Toggle sounds"
L.HELP_SHOW               = "  /plc show <type|all> <on|off> — Toggle visibility"
L.HELP_RESET              = "  /plc reset — Reset to defaults"
