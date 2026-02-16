if GetLocale() ~= "ptBR" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Rastreamento de ressurreição de combate e Sede de Sangue"
L.EDIT_MODE_HINT          = "A posição é configurada no Modo de Edição (Esc > Modo de Edição)"
L.VERSION_LABEL           = "Versão %s | Idioma: %s"

-- Section headers
L.HEADER_VISIBILITY       = "Visibilidade"
L.HEADER_SOUNDS           = "Sons"

-- Layout
L.VERTICAL_ORIENTATION    = "Orientação vertical"
L.SCALE                   = "Escala"

-- Visibility options
L.VIS_DUNGEONS            = "Masmorras"
L.VIS_RAIDS               = "Raides"
L.VIS_SCENARIOS           = "Cenários / Profundezas"
L.VIS_BATTLEGROUNDS       = "Campos de batalha / Arena"
L.VIS_OPEN_WORLD          = "Grupos no mundo aberto"
L.VIS_SOLO                = "Solo"

-- Sound checkboxes
L.SOUND_LUST_ACTIVE       = "Sede de Sangue ativada"
L.SOUND_LUST_READY        = "Sede de Sangue pronta (saciado expirado)"
L.SOUND_BRES_USED         = "Carga de ressurreição usada"

-- Buttons
L.RESET_DEFAULTS          = "Restaurar padrões"

-- Slash command output
L.MSG_RESET               = "Configurações restauradas."
L.MSG_UNLOCKED            = "Quadro desbloqueado. Arraste para reposicionar."
L.MSG_LOCKED              = "Quadro bloqueado."
L.MSG_ORIENTATION         = "Orientação: %s."
L.MSG_SCALE               = "Escala: %s."
L.MSG_SCALE_USAGE         = "Uso: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "Sons de %s %s."
L.MSG_SOUND_USAGE         = "Uso: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "Visibilidade de %s %s."
L.MSG_VIS_ALL             = "Toda a visibilidade %s."
L.MSG_VIS_USAGE           = "Uso: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Comando desconhecido '%s'."

-- Help text
L.HELP_HEADER             = "Comandos do PulseCheck:"
L.HELP_OPEN               = "  /plc \226\128\148 Abrir configurações"
L.HELP_HELP               = "  /plc help \226\128\148 Mostrar esta ajuda"
L.HELP_LOCK               = "  /plc lock|unlock \226\128\148 Bloquear/desbloquear o quadro"
L.HELP_ORIENTATION        = "  /plc orientation \226\128\148 Alternar orientação"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> \226\128\148 Definir escala"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> \226\128\148 Ativar/desativar sons"
L.HELP_SHOW               = "  /plc show <tipo|all> <on|off> \226\128\148 Ativar/desativar visibilidade"
L.HELP_RESET              = "  /plc reset \226\128\148 Restaurar padrões"
