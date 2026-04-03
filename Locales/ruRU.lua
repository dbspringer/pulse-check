if GetLocale() ~= "ruRU" then return end
local L = PC_L

-- Panel
L.ADDON_SUBTITLE          = "Отслеживание времени восстановления боевого воскрешения и жажды крови"
L.EDIT_MODE_HINT          = "Положение настраивается в режиме редактирования HUD (Esc > Режим редактирования)."
L.VERSION_LABEL           = "Версия %s | Язык: %s"

-- Section headers
L.HEADER_VISIBILITY       = "Видимость"
L.HEADER_SOUNDS           = "Звуки"

-- Layout
L.VERTICAL_ORIENTATION    = "Вертикальная ориентация"
L.SCALE                   = "Масштаб"
L.SHOW_BACKGROUND         = "Показывать фон"
L.SHOW_BORDER             = "Показывать границу"

-- Visibility options
L.VIS_DUNGEONS            = "Подземелья"
L.VIS_RAIDS               = "Рейды"
L.VIS_SCENARIOS           = "Сценарии и Вылазки"
L.VIS_BATTLEGROUNDS       = "Поле боя и Арена"
L.VIS_OPEN_WORLD          = "Группы в открытом мире"
L.VIS_SOLO                = "Соло"

-- Sound checkboxes (shared between dialog and panel)
L.SOUND_LUST_ACTIVE       = "Героизм/Неистовство активировано"
L.SOUND_LUST_READY        = "Героизм/Неистовство готово (пресыщение прошло)"
L.SOUND_BRES_USED         = "Боевое воскрешение использовано"

-- Buttons
L.RESET_DEFAULTS          = "Сбросить настройки по умолчанию"

-- Slash command output (use string.format with these)
L.MSG_RESET               = "Настройки сброшены до значений по умолчанию."
L.MSG_UNLOCKED            = "Окно разблокировано. Перетащите для изменения положения."
L.MSG_LOCKED              = "Окно заблокировано."
L.MSG_ORIENTATION         = "Ориентация установлена: %s."
L.MSG_SCALE               = "Масштаб установлен: %s."
L.MSG_SCALE_USAGE         = "Использование: /plc scale <0.5-2.0>"
L.MSG_SOUND_TOGGLE        = "Звуки %s: %s."
L.MSG_SOUND_USAGE         = "Использование: /plc sound <lust|bres> <on|off>"
L.MSG_VIS_TOGGLE          = "Видимость %s: %s."
L.MSG_VIS_ALL             = "Общая видимость: %s."
L.MSG_VIS_USAGE           = "Использование: /plc show <dungeons|raids|scenarios|battlegrounds|openworld|solo|all> <on|off>"
L.MSG_UNKNOWN_CMD         = "Неизвестная команда '%s'."

-- Help text
L.HELP_HEADER             = "Команды PulseCheck:"
L.HELP_OPEN               = "  /plc — Открыть настройки"
L.HELP_HELP               = "  /plc help — Показать эту справку"
L.HELP_LOCK               = "  /plc lock|unlock — Заблокировать/разблокировать положение окна"
L.HELP_ORIENTATION        = "  /plc orientation — Переключить горизонтальную/вертикальную ориентацию"
L.HELP_SCALE              = "  /plc scale <0.5-2.0> — Установить масштаб иконок"
L.HELP_SOUND              = "  /plc sound <lust|bres> <on|off> — Включить/выключить звуки"
L.HELP_SHOW               = "  /plc show <тип|all> <on|off> — Включить/выключить видимость"
L.HELP_RESET              = "  /plc reset — Сбросить настройки по умолчанию"
