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

## Approach 2: Haste Delta Detection (The "Big Haste" Workaround)

`GetHaste()` returns the player's total haste percentage and is **not** restricted by secret values. A sudden ~30% jump strongly suggests bloodlust was applied.

```lua
local lastHaste = GetHaste()
local LUST_HASTE = 30

-- Poll on a ticker (e.g., every 0.5s)
local currentHaste = GetHaste()
local delta = currentHaste - lastHaste
if delta >= (LUST_HASTE - 2) then  -- threshold with tolerance
    -- Likely just gained bloodlust
end
lastHaste = currentHaste
```

**Pros:** Not affected by secret value restrictions.

**Cons:** Heuristic — trinket procs, gear swaps, or stacking haste buffs can false-positive. Cannot detect sated (no haste change).

## Approach 3: Hybrid (Recommended for 12.0+)

This is what addons like [Lust Tracker](https://www.curseforge.com/wow/addons/lust-tracker) do:

1. **Query spell IDs directly** via `C_UnitAuras.GetPlayerAuraBySpellID`
2. If aura data is secret/unavailable in combat, **start a 10-minute fallback timer** from first detection
3. Use a **lightweight polling loop** (`C_Timer.NewTicker`) instead of `UNIT_AURA` event registration to avoid taint

~~Optionally use `COMBAT_LOG_EVENT_UNFILTERED` with `SPELL_AURA_APPLIED`~~ — **this is no longer viable in 12.0**. `COMBAT_LOG_EVENT_UNFILTERED` is a protected event; registering for it triggers `ADDON_ACTION_FORBIDDEN`. See Approach 4 below.

## Approach 4: Time-Based Expiration Validation (PulseCheck's Solution)

When the aura API returns nil for sated during combat (due to 12.0 secret values / taint), we can't trust a sated→false transition. Instead, compare `GetTime()` against the previously saved `satedExpiration`:

```lua
-- In UpdateBloodlustState(), after aura queries:
if oldSated and not state.sated and InCombatLockdown() then
    -- Aura API returned nil during combat — likely taint, not real expiration
    if oldSatedExpiration > 0 and GetTime() < oldSatedExpiration then
        state.sated = true
        state.satedExpiration = oldSatedExpiration
        state.satedDuration = oldSatedDuration
    end
end
```

**How it works:** Before entering combat, the addon captures the sated debuff's `expirationTime` from the aura API. If combat starts and the API suddenly returns nil (taint), the addon checks whether `GetTime()` has actually reached the saved expiration. If not, the debuff is still active — the nil was an API failure, not a real state change.

**Pros:** No protected event registration, no heuristics, deterministic.

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
