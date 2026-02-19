# Changelog

## 1.1.0

- Fix false bloodlust alerts from temporary haste buffs and debuff recovery (e.g. Cinderbrew Meadery)
- Add peak haste tracking to prevent debuff-to-normal haste swings from triggering lust detection
- Add minimum absolute haste delta (20%) for haste-based lust inference
- Fix battle res charge flickering from 1 to 0 on GCD when solo
- Infer sated debuff when lust ends and aura API is blocked during combat

## 1.0.0

- Battle resurrection charge tracking with cooldown timer
- Personal brez cooldown tracking for Druid, DK, Warlock, Paladin when outside encounters
- Bloodlust/sated detection across 20 buff spell IDs and 5 sated debuff IDs
- Haste-delta fallback for bloodlust detection when aura API is blocked by secret values
- Raid-wide sated scan as fallback when player missed bloodlust
- Four bloodlust visual states: ready, active (glow), sated (desaturated), raid sated (dimmed)
- Instance-based polling — tickers start/stop automatically based on content type
- Edit Mode integration for frame positioning with snap-to-grid
- Settings panel in Interface > AddOns with version/locale info
- Inline Edit Mode dialog with orientation, scale, visibility, and sound settings
- Slash commands: /pulsecheck, /plc
- Configurable sounds for bloodlust and battle res events
- Optional LibSharedMedia sound picker with BigWigs/SharedMedia_Causese integration
- Locale system for future translation support
- 12.0 secret values fallback via polling and time-based expiration validation
