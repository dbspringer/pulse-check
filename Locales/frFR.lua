-- Auto-translated — pull requests with improved translations are welcome!
if GetLocale() ~= "frFR" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Suivi de la résurrection de combat et de la Furie sanguinaire"
L.EDIT_MODE_HINT          = "La position se configure en mode Édition (Échap > Mode Édition)"
L.VERSION_LABEL           = "Version %s | Langue : %s"

-- Section headers
L.HEADER_VISIBILITY       = "Visibilité"
L.HEADER_SOUNDS           = "Sons"

-- Layout
L.VERTICAL_ORIENTATION    = "Orientation verticale"
L.SCALE                   = "Échelle"

-- Visibility options
L.VIS_DUNGEONS            = "Donjons"
L.VIS_RAIDS               = "Raids"
L.VIS_SCENARIOS           = "Scénarios / Profondeurs"
L.VIS_BATTLEGROUNDS       = "Champs de bataille / Arène"
L.VIS_OPEN_WORLD          = "Groupes en extérieur"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes
L.SOUND_LUST_ACTIVE       = "Furie sanguinaire activée"
L.SOUND_LUST_READY        = "Furie sanguinaire prête (rassasié expiré)"
L.SOUND_BRES_USED         = "Charge de résurrection utilisée"

-- Buttons
L.RESET_DEFAULTS          = "Réinitialiser"

-- Slash command output
L.MSG_RESET               = "Paramètres réinitialisés."
L.MSG_UNLOCKED            = "Cadre déverrouillé. Faites glisser pour repositionner."
L.MSG_LOCKED              = "Cadre verrouillé."
L.MSG_ORIENTATION         = "Orientation : %s."
L.MSG_SCALE               = "Échelle : %s."
L.MSG_SCALE_USAGE         = "Utilisation : /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "Sons %s %s."
L.MSG_SOUND_USAGE         = "Utilisation : /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "Visibilité %s %s."
L.MSG_VIS_ALL             = "Toute visibilité %s."
L.MSG_VIS_USAGE           = "Utilisation : /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Commande inconnue '%s'."

-- Help text
L.HELP_HEADER             = "Commandes PulseCheck :"
L.HELP_OPEN               = "  /plc \226\128\148 Ouvrir les paramètres"
L.HELP_HELP               = "  /plc help \226\128\148 Afficher cette aide"
L.HELP_LOCK               = "  /plc lock|unlock \226\128\148 Verrouiller/déverrouiller le cadre"
L.HELP_ORIENTATION        = "  /plc orientation \226\128\148 Basculer l'orientation"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> \226\128\148 Définir l'échelle"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> \226\128\148 Activer/désactiver les sons"
L.HELP_SHOW               = "  /plc show <type|all> <on|off> \226\128\148 Activer/désactiver la visibilité"
L.HELP_RESET              = "  /plc reset \226\128\148 Réinitialiser"
