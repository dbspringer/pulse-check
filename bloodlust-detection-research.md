# Detecting Bloodlust & Sated in WoW Addons

Research notes — February 2026

## Spell IDs

### Bloodlust Buffs (30% haste, 40s duration)

| Spell            | ID     | Source              |
| ---------------- | ------ | ------------------- |
| Bloodlust        | 2825   | Shaman (Horde)      |
| Heroism          | 32182  | Shaman (Alliance)   |
| Time Warp        | 80353  | Mage                |
| Primal Rage      | 264667 | Hunter pet          |
| Fury of the Aspects | 390386 | Evoker           |

### Battle Resurrection — Class Spells

| Spell         | ID     | Class        |
| ------------- | ------ | ------------ |
| Rebirth       | 20484  | Druid        |
| Raise Ally    | 61999  | Death Knight |
| Soulstone     | 20707  | Warlock      |
| Intercession  | 391054 | Paladin      |

During encounters, all class brez spells consume charges from the shared encounter system (tracked via `C_Spell.GetSpellCharges(20484)`). Outside encounters, each class spell has its own independent cooldown (tracked via `C_Spell.GetSpellCooldown(id)` + `IsPlayerSpell(id)`).

### Sated / Lockout Debuffs (10 min duration)

| Debuff                 | ID     | Applied by              |
| ---------------------- | ------ | ----------------------- |
| Sated                  | 57724  | Bloodlust / Primal Rage |
| Exhaustion             | 57723  | Heroism                 |
| Temporal Displacement  | 80354  | Time Warp               |
| Fatigued               | 264689 | Primal Rage (alternate) |
| Exhaustion (Evoker)    | 390435 | Fury of the Aspects     |

## Approach 1: Direct Spell ID Query

The modern API is `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` (added in 10.0). Returns an `AuraData` table or `nil`.

```lua
local SATED_IDS = {57724, 57723, 80354, 264689, 390435}
local LUST_IDS  = {2825, 32182, 80353, 264667, 390386}

local function HasSated()
    for _, id in ipairs(SATED_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then return true, aura.expirationTime end
    end
    return false
end

local function HasBloodlust()
    for _, id in ipairs(LUST_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura then return true, aura.expirationTime end
    end
    return false
end
```

This is the cleanest method and works perfectly outside tainted execution paths.

## Approach 2: Haste Delta Detection

`GetHaste()` returns the player's total haste percentage and is **not** restricted by secret values. A sudden ≥25% jump strongly suggests bloodlust was applied. Haste is multiplicative in WoW, so the actual delta from a 30% lust buff is always ≥30% of your base — a 25% threshold is conservative and avoids false positives from trinket procs.

```lua
local LUST_HASTE_THRESHOLD = 25
local LUST_ASSUMED_DURATION = 40
local lastHaste = 0
local lustHasteExpiration = 0

-- Called on a 1s poll ticker:
local currentHaste = GetHaste()
if not state.lustActive then
    if lustHasteExpiration > 0 and GetTime() < lustHasteExpiration then
        -- Previously inferred via haste, still within expected duration
        state.lustActive = true
        state.lustExpiration = lustHasteExpiration
        state.lustDuration = LUST_ASSUMED_DURATION
    elseif lastHaste > 0
           and (currentHaste - lastHaste) >= LUST_HASTE_THRESHOLD then
        -- Large haste spike — infer lust activation
        lustHasteExpiration = GetTime() + LUST_ASSUMED_DURATION
        state.lustActive = true
        state.lustExpiration = lustHasteExpiration
        state.lustDuration = LUST_ASSUMED_DURATION
    end
else
    -- Aura API confirmed lust; clear haste inference
    lustHasteExpiration = 0
end
lastHaste = currentHaste
```

**Pros:** Not affected by secret value restrictions. Self-clears when aura API resumes working.

**Cons:** Heuristic — cannot detect sated (no haste change). Expiration time is estimated (assumes 40s). Requires polling (not event-driven).

## Approach 3: Layered Detection (PulseCheck's Solution for 12.0+)

Three detection layers, checked in priority order:

1. **Aura API** — `C_UnitAuras.GetPlayerAuraBySpellID` for all known lust/sated spell IDs. Fastest and most accurate when it works.
2. **Time-based expiration validation** (Approach 4) — if a buff/debuff was previously detected and hasn't expired, keep it active even if the API returns nil. Handles both combat taint and zone transitions.
3. **Haste delta** (Approach 2) — `GetHaste()` is unrestricted; a ≥25% spike infers lust activation with a 40s estimated timer. Handles the case where the aura API is blocked from the start and lust is never detected via spell IDs.

All three run inside `UpdateBloodlustState()`, called both by `UNIT_AURA` events (fast path) and a 1s `C_Timer.NewTicker` (safety net in instanced content).

~~Optionally use `COMBAT_LOG_EVENT_UNFILTERED` with `SPELL_AURA_APPLIED`~~ — **this is no longer viable in 12.0**. `COMBAT_LOG_EVENT_UNFILTERED` is a protected event; registering for it triggers `ADDON_ACTION_FORBIDDEN`.

## Approach 4: Time-Based Expiration Validation

When the aura API returns nil for a buff/debuff that was previously active, we can't trust the transition. This happens during combat (secret values / taint) and zone transitions (loading screens). Compare `GetTime()` against the previously saved expiration:

```lua
-- Applied to both lust and sated in UpdateBloodlustState():
if oldLustActive and not state.lustActive
   and oldLustExpiration > 0 and GetTime() < oldLustExpiration then
    state.lustActive = true
    state.lustExpiration = oldLustExpiration
    state.lustDuration = oldLustDuration
end

if oldSated and not state.sated
   and oldSatedExpiration > 0 and GetTime() < oldSatedExpiration then
    state.sated = true
    state.satedExpiration = oldSatedExpiration
    state.satedDuration = oldSatedDuration
end
```

**How it works:** The addon captures `expirationTime` from the aura API when it's working. If the API subsequently returns nil, the addon checks whether `GetTime()` has actually reached the saved expiration. If not, the buff/debuff is still active — the nil was an API failure, not a real state change.

**Pros:** No protected event registration, no heuristics, deterministic. Covers both combat taint and zone transitions.

**Cons:** If a buff is dispelled early, the addon won't detect the removal until the original timer expires or the aura API starts returning data again.

**Cons:** If the debuff is dispelled early during combat, the addon won't detect the removal until the original timer expires or combat ends.

### Checking if auras are restricted

```lua
-- 12.0+ API to check if a spell's aura data is secret
if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
    local isSecret = C_Secrets.ShouldSpellAuraBeSecret(57724)
    -- If true, fall back to timer or haste-delta approach
end
```

## 12.0 (Midnight) Secret Values Context

Patch 12.0 introduced "secret values" — aura and cooldown fields can be marked protected on tainted execution paths. This affects `C_UnitAuras`, `C_Spell`, and `C_ActionBar` APIs.

- Bloodlust/sated spell IDs are **not explicitly confirmed whitelisted** as of this writing
- Blizzard is whitelisting spells on a case-by-case basis (devs can request additions)
- `C_Secrets.ShouldSpellAuraBeSecret()` and `C_Secrets.ShouldUnitAuraInstanceBeSecret()` let addons check restriction status at runtime
- Traditional `UNIT_AURA` event registration can cause taint in restricted contexts — polling is safer
- `COMBAT_LOG_EVENT_UNFILTERED` is a **protected event** — registering for it triggers `ADDON_ACTION_FORBIDDEN`; do not use CLEU as a fallback detection path

## Key APIs

| API | Purpose |
| --- | ------- |
| `C_UnitAuras.GetPlayerAuraBySpellID(id)` | Check for a specific aura on the player by spell ID |
| `AuraUtil.ForEachAura(unit, filter, max, func)` | Iterate all auras on a unit |
| `AuraUtil.FindAuraByName(name, unit)` | Find aura by name (localized — fragile) |
| `GetHaste()` | Player's current haste % (unrestricted) |
| `C_Secrets.ShouldSpellAuraBeSecret(id)` | Check if aura data is protected (12.0+) |
| `UNIT_AURA` event | Fires on aura gain/loss (may taint in 12.0+) |
| `COMBAT_LOG_EVENT_UNFILTERED` | **Protected in 12.0** — cannot be registered by addons |
| `InCombatLockdown()` | Check if player is in combat (tainted execution path) |

## References

- [Warcraft Wiki: C_UnitAuras.GetPlayerAuraBySpellID](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID)
- [Warcraft Wiki: UNIT_AURA](https://warcraft.wiki.gg/wiki/UNIT_AURA)
- [Warcraft Wiki: Patch 12.0.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Wowhead: Bloodlust (2825)](https://www.wowhead.com/spell=2825/bloodlust)
- [Wowhead: Sated (57724)](https://www.wowhead.com/spell=57724/sated)
- [Icy Veins: Blizzard Relaxing Addon Limitations in Midnight](https://www.icy-veins.com/wow/news/blizzard-relaxing-more-addon-limitations-in-midnight/)
- [Lust Tracker addon (CurseForge)](https://www.curseforge.com/wow/addons/lust-tracker)
- [Wowpedia: Bloodlust effect](https://wowpedia.fandom.com/wiki/Bloodlust_effect)
