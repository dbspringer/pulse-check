# Changelog

## 1.4.2

- Add sated-gate to haste-delta bloodlust inference — haste spikes without a sated debuff are no longer treated as bloodlust
- Expand haste exclusion list: Power Infusion, Metamorphosis (Havoc DH), Icy Veins (Frost Mage), Crusade (Ret Paladin), Surging Elements (Enh Shaman), Ascendance (Resto/Ele Shaman with Preeminence)

## 1.4.1

- Add Russian (ruRU) locale with full translation of all UI strings, panel labels, commands, and help text (thanks @Hollicsh!)
- Add localized Category metadata for addon browser in all supported WoW client languages

## 1.4.0

- Add Void-Touched Drums (spell 1243972) to bloodlust buff detection — drums now show as an active glowing icon with countdown timer instead of skipping straight to the sated lockout
- Harden aura field access with pcall(rawget) and issecretvalue checks — tainted aura objects in 12.0 can throw on field access, not just return secret placeholders
- Add missing sated debuff IDs: Insanity (95809) from Ancient Hysteria and Fatigued (160455) from Netherwinds
- Refresh all state when aura fallback ticker detects API recovery, clearing stale fallback timers
- Organize BLOODLUST_IDS so class/pet abilities are checked first, giving real lust display priority over drums

## 1.3.0

- Add independent toggles to show/hide the main frame background and border
- Fix ScanRaidSated crash when ShouldSpellAuraBeSecret disagrees with actual aura taint — use pcall(rawget) instead of pre-check
- Add background and border toggle translations for all supported locales (deDE, esES, frFR, itIT, ptBR)

## 1.2.0

- Replace Temporal Burst suppression with generic, table-driven haste exclusion system
- Only suppress the initial activation spike of non-lust haste buffs — real bloodlust is still detected even while Temporal Burst is already active
- Three-tier exclusion detection: aura API, cooldown fallback, and UNIT_SPELLCAST_SUCCEEDED for full coverage under 12.0 secret values
- Fix secret value errors that halted bloodlust detection during combat (secret number comparisons, secret table keys)
- Fix ScanRaidSated crash from secret spellId values in GetAuraDataByIndex

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
