-- Auto-translated — pull requests with improved translations are welcome!
if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Seguimiento de resurrección de combate y Ansia de sangre"
L.EDIT_MODE_HINT          = "La posición se configura en el modo Edición (Esc > Modo Edición)"
L.VERSION_LABEL           = "Versión %s | Idioma: %s"

-- Section headers
L.HEADER_VISIBILITY       = "Visibilidad"
L.HEADER_SOUNDS           = "Sonidos"

-- Layout
L.VERTICAL_ORIENTATION    = "Orientación vertical"
L.SCALE                   = "Escala"

-- Visibility options
L.VIS_DUNGEONS            = "Mazmorras"
L.VIS_RAIDS               = "Bandas"
L.VIS_SCENARIOS           = "Escenarios / Profundidades"
L.VIS_BATTLEGROUNDS       = "Campos de batalla / Arena"
L.VIS_OPEN_WORLD          = "Grupos en mundo abierto"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes
L.SOUND_LUST_ACTIVE       = "Ansia de sangre activada"
L.SOUND_LUST_READY        = "Ansia de sangre lista (saciado expirado)"
L.SOUND_BRES_USED         = "Carga de resurrección usada"

-- Buttons
L.RESET_DEFAULTS          = "Restablecer"

-- Slash command output
L.MSG_RESET               = "Ajustes restablecidos."
L.MSG_UNLOCKED            = "Marco desbloqueado. Arrastra para reposicionar."
L.MSG_LOCKED              = "Marco bloqueado."
L.MSG_ORIENTATION         = "Orientación: %s."
L.MSG_SCALE               = "Escala: %s."
L.MSG_SCALE_USAGE         = "Uso: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "Sonidos de %s %s."
L.MSG_SOUND_USAGE         = "Uso: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "Visibilidad de %s %s."
L.MSG_VIS_ALL             = "Toda la visibilidad %s."
L.MSG_VIS_USAGE           = "Uso: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Comando desconocido '%s'."

-- Help text
L.HELP_HEADER             = "Comandos de PulseCheck:"
L.HELP_OPEN               = "  /plc \226\128\148 Abrir ajustes"
L.HELP_HELP               = "  /plc help \226\128\148 Mostrar esta ayuda"
L.HELP_LOCK               = "  /plc lock|unlock \226\128\148 Bloquear/desbloquear el marco"
L.HELP_ORIENTATION        = "  /plc orientation \226\128\148 Cambiar orientación"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> \226\128\148 Establecer escala"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> \226\128\148 Activar/desactivar sonidos"
L.HELP_SHOW               = "  /plc show <tipo|all> <on|off> \226\128\148 Activar/desactivar visibilidad"
L.HELP_RESET              = "  /plc reset \226\128\148 Restablecer ajustes"
