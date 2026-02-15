# Changelog

## 1.1.0

- Extract all user-facing strings into locale system (`Locales/enUS.lua`) for future translation support
- Fix scale changes shifting icon position (CENTER anchor with offset adjustment)
- Add version and locale info to settings panel
- Remove unnecessary scroll frame from settings panel
- Sync settings state between Edit Mode dialog and settings panel
- Full-width reset button in Edit Mode dialog
- Fix frame showing on reload when solo visibility is disabled
- Fix scale slider label displaying "1" instead of "1.0"
- Route all scale changes through centralized `SetScale()` function

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
