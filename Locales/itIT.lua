if GetLocale() ~= "itIT" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Tracciamento di resurrezione in combattimento e Brama di Sangue"
L.EDIT_MODE_HINT          = "La posizione si configura nella Modalità Modifica (Esc > Modalità Modifica)"
L.VERSION_LABEL           = "Versione %s | Lingua: %s"

-- Section headers
L.HEADER_VISIBILITY       = "Visibilità"
L.HEADER_SOUNDS           = "Suoni"

-- Layout
L.VERTICAL_ORIENTATION    = "Orientamento verticale"
L.SCALE                   = "Scala"

-- Visibility options
L.VIS_DUNGEONS            = "Spedizioni"
L.VIS_RAIDS               = "Incursioni"
L.VIS_SCENARIOS           = "Scenari / Profondità"
L.VIS_BATTLEGROUNDS       = "Campi di battaglia / Arena"
L.VIS_OPEN_WORLD          = "Gruppi nel mondo aperto"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes
L.SOUND_LUST_ACTIVE       = "Brama di Sangue attivata"
L.SOUND_LUST_READY        = "Brama di Sangue pronta (sazio scaduto)"
L.SOUND_BRES_USED         = "Carica di resurrezione usata"

-- Buttons
L.RESET_DEFAULTS          = "Ripristina"

-- Slash command output
L.MSG_RESET               = "Impostazioni ripristinate."
L.MSG_UNLOCKED            = "Riquadro sbloccato. Trascina per riposizionare."
L.MSG_LOCKED              = "Riquadro bloccato."
L.MSG_ORIENTATION         = "Orientamento: %s."
L.MSG_SCALE               = "Scala: %s."
L.MSG_SCALE_USAGE         = "Uso: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "Suoni %s %s."
L.MSG_SOUND_USAGE         = "Uso: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "Visibilità %s %s."
L.MSG_VIS_ALL             = "Tutta la visibilità %s."
L.MSG_VIS_USAGE           = "Uso: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Comando sconosciuto '%s'."

-- Help text
L.HELP_HEADER             = "Comandi di PulseCheck:"
L.HELP_OPEN               = "  /plc \226\128\148 Apri impostazioni"
L.HELP_HELP               = "  /plc help \226\128\148 Mostra questo aiuto"
L.HELP_LOCK               = "  /plc lock|unlock \226\128\148 Blocca/sblocca il riquadro"
L.HELP_ORIENTATION        = "  /plc orientation \226\128\148 Cambia orientamento"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> \226\128\148 Imposta scala"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> \226\128\148 Attiva/disattiva suoni"
L.HELP_SHOW               = "  /plc show <tipo|all> <on|off> \226\128\148 Attiva/disattiva visibilità"
L.HELP_RESET              = "  /plc reset \226\128\148 Ripristina impostazioni"
