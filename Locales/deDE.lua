-- Auto-translated — pull requests with improved translations are welcome!
if GetLocale() ~= "deDE" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Kampfwiederbelebungs- und Kampfrausch-Tracking"
L.EDIT_MODE_HINT          = "Position wird im HUD-Bearbeitungsmodus konfiguriert (Esc > Bearbeitungsmodus)"
L.VERSION_LABEL           = "Version %s | Sprache: %s"

-- Section headers
L.HEADER_VISIBILITY       = "Sichtbarkeit"
L.HEADER_SOUNDS           = "Sounds"

-- Layout
L.VERTICAL_ORIENTATION    = "Vertikale Ausrichtung"
L.SCALE                   = "Skalierung"

-- Visibility options
L.VIS_DUNGEONS            = "Dungeons"
L.VIS_RAIDS               = "Schlachtzüge"
L.VIS_SCENARIOS           = "Szenarien / Tiefen"
L.VIS_BATTLEGROUNDS       = "Schlachtfelder / Arena"
L.VIS_OPEN_WORLD          = "Offene-Welt-Gruppen"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes
L.SOUND_LUST_ACTIVE       = "Kampfrausch aktiviert"
L.SOUND_LUST_READY        = "Kampfrausch bereit (Erschöpfung abgelaufen)"
L.SOUND_BRES_USED         = "Wiederbelebungsladung verbraucht"

-- Buttons
L.RESET_DEFAULTS          = "Standardwerte"

-- Slash command output
L.MSG_RESET               = "Einstellungen zurückgesetzt."
L.MSG_UNLOCKED            = "Rahmen entsperrt. Zum Verschieben ziehen."
L.MSG_LOCKED              = "Rahmen gesperrt."
L.MSG_ORIENTATION         = "Ausrichtung: %s."
L.MSG_SCALE               = "Skalierung: %s."
L.MSG_SCALE_USAGE         = "Nutzung: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "%s-Sounds %s."
L.MSG_SOUND_USAGE         = "Nutzung: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "%s-Sichtbarkeit %s."
L.MSG_VIS_ALL             = "Gesamte Sichtbarkeit %s."
L.MSG_VIS_USAGE           = "Nutzung: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Unbekannter Befehl '%s'."

-- Help text
L.HELP_HEADER             = "PulseCheck-Befehle:"
L.HELP_OPEN               = "  /plc \226\128\148 Einstellungen \195\182ffnen"
L.HELP_HELP               = "  /plc help \226\128\148 Diese Hilfe anzeigen"
L.HELP_LOCK               = "  /plc lock|unlock \226\128\148 Rahmen sperren/entsperren"
L.HELP_ORIENTATION        = "  /plc orientation \226\128\148 Ausrichtung umschalten"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> \226\128\148 Skalierung setzen"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> \226\128\148 Sounds umschalten"
L.HELP_SHOW               = "  /plc show <Typ|all> <on|off> \226\128\148 Sichtbarkeit umschalten"
L.HELP_RESET              = "  /plc reset \226\128\148 Standardwerte wiederherstellen"
