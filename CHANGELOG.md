# Changelog

## 1.8.0

- Fix `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'PulseCheck'` in 12.1 — the patch made aura lookups by index, slot, or aura instance ID raise a Lua error when an addon calls them while auras are secret, so the 3-second raid-sated scan threw on every tick in raid/M+ combat. The scan now looks each sated ID up with `C_UnitAuras.GetUnitAuraBySpellID`, which carries no such restriction, so it keeps working *through* encounters rather than merely avoiding the crash
- Detect bloodlust from the Sated debuff instead of haste spikes. Blizzard flagged the Sated/Exhaustion family never-secret (the Bloodlust buff itself is still secret), and sated is applied by the same effect that grants lust, to exactly the targets that receive it — so its application time is the lust start time. Lust timing is now derived rather than inferred:
  - **Drums are detected.** Their 15% haste sat below the old 25% inference threshold, so they only ever showed up when the aura API was readable
  - **No false positives.** The 8-entry haste exclusion list for Power Infusion, Icy Veins, Crusade, Ascendance and friends is gone — nothing but a bloodlust effect applies sated
  - **Reloading mid-encounter is correct.** A sated debuff applied nine minutes ago now resolves to "lust long over" instead of firing a phantom alert, fixing the 1.7.0 known limitation
  - The activation alert now also drives the icon glow and countdown; previously the sated-transition fallback fired the sound alone
- Only infer lust where the Bloodlust buff is actually unreadable. Secrecy is decided per spell, so out of combat a nil lookup is proof of absence rather than a blocked read — sated outlives a buff that was cancelled, purged, or lost on death, and inferring from it there showed a countdown for something the player didn't have. Dead players derive no lust either (Spirit of Redemption still counts as alive)
- Fix a false "brez used" alert when the encounter charge pool gives way to a personal cooldown at `ENCOUNTER_END`. The charge count was compared across that boundary, so any charges still remaining read as a resurrection. Alerts now fire only between two samples from the same source. **Pre-existing before 1.8.0**, surfaced while reviewing the changes above
- Remove the haste-delta inference and its supporting machinery (`HASTE_EXCLUSIONS`, `SafeGetHaste`, haste baselines, the pending sated-gate). It had been dormant since 12.0.5, when `GetHaste()` began returning secrets whenever auras are secret
- Fix `UNIT_AURA` updates being skipped in raid combat — the handler was gated on `useAuraFallback`, which is derived from Bloodlust's secrecy and is therefore true in every encounter. That suppressed the event precisely when it carried a readable sated update. The flag and its polling ticker are removed
- Harden battle res tracking against secret cooldown values — `SpellChargeInfo` marks only `maxCharges` and `isActive` never-secret, so `currentCharges`, `cooldownStartTime` and `cooldownDuration` can arrive as secrets that throw on the comparisons in `UpdateBresState`/`RefreshBresIcon` and the per-frame arithmetic in `BresOnUpdate`. These now go through `SafeNumber`, and unreadable data reports no charges rather than keeping the last reading — a retained value can describe a different context entirely (a personal cooldown from before the encounter began), which would leave the icon glowing a brez that doesn't exist. The used-alert only fires between two readable samples, so a brez spent inside a blind window goes unannounced instead of alerting late. Pre-emptive: no such error has been reported
- Bump Interface to 120100 for patch 12.1

Cast-based detection is retained as a fallback: the never-secret classification is set per patch and has already changed twice, so if Sated is ever re-secreted, lust detection degrades to the cast path rather than stopping.

## 1.7.2

- Bump Interface to 120007 for patch 12.0.7 — verified compatible, no code changes

## 1.7.1

- Fix "attempted to index a table that cannot be indexed with secret keys" error fired by `UNIT_SPELLCAST_SUCCEEDED` for non-player units in 12.0.5 raids/M+ — `spellID` can be a secret value for tainted units, so the `BLOODLUST_LOOKUP` table check now uses `pcall(rawget, ...)` (matching the existing `ScanRaidSated` pattern)
- Add sated-transition→sound trigger as a detection fallback for when both the lust aura and the cast event's `spellID` are secret-gated in 12.0.5 — sated debuff lands at the same moment as lust, so its appearance is a reliable activation signal when the canonical paths can't read the spell
- Suppress the sated-transition sound for 3 seconds after `PLAYER_ENTERING_WORLD` so zoning into an instance while sated from a prior pull doesn't play a phantom alert

## 1.7.0

- Add cast-based bloodlust detection via `UNIT_SPELLCAST_SUCCEEDED` — fires the lust sound and updates the icon in raids/Mythic dungeons where 12.0.5 secret-value restrictions block the aura API, `GetHaste()`, and `GetAuraDataByIndex` (the prior detection paths)
- Listen to all group members' casts so any shaman/mage/hunter triggering lust now reliably surfaces, regardless of which APIs are tainted
- Gate cast fallback on sated lockout, active lust window, and player alive state — `useAuraFallback` is intentionally *not* checked because that flag only updates on zone-in and the fallback ticker, so it can be stale when secrets activate mid-encounter. Duplicate-call guards prevent double-fires when the aura path also detects the cast
- Tag cast-inferred lust with `state.lustFromCast` so the existing sated-fallback inference in `UpdateBloodlustState` skips it — prevents a phantom 10-minute sated lockout (from out-of-range or unconfirmed lust) suppressing the next real lust alert
- Known limitation: if the player `/reloads` while sated in raids/M+ with secret values active, the in-memory sated state is lost and the next group lust cast may briefly play the alert sound. Wait the remaining sated window (~10 min from the original cast) and the next real lust will play correctly

## 1.6.0

- Fix error when `GetHaste()` returns a secret value under tainted execution in 12.0.5 — haste-delta inference now safely skips the tick instead of throwing on arithmetic
- Reset haste baselines on `ENCOUNTER_END` so stale readings from long tainted windows can't trip a false spike on the next encounter
- Bump Interface to 120005 for patch 12.0.5

## 1.5.0

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
