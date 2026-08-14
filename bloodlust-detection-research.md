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

### Drum Variants (15% haste, 40s duration, triggers Exhaustion)

| Spell                       | ID      | Source                           |
| --------------------------- | ------- | -------------------------------- |
| Drums of Rage               | 146555  | MoP drums                       |
| Netherwinds                 | 160452  | Hunter exotic pet                |
| Drums of Fury               | 178207  | WoD drums                       |
| Drums of Battle             | 204276  | Legion drums                    |
| Drums of the Mountain       | 230935  | Legion drums                    |
| Drums of the Maelstrom      | 256740  | BfA drums                       |
| Drums of Battle (BfA)       | 272678  | BfA drums (alternate)           |
| Drums of Battle (BfA)       | 275200  | BfA drums (alternate)           |
| Drums of the Maelstrom      | 292686  | BfA drums (alternate)           |
| Drums of Deathly Ferocity   | 309658  | Shadowlands drums               |
| Feral Hide Drums            | 381301  | Dragonflight drums              |
| Timeless Drums              | 441076  | TWW drums                       |
| Thunderous Drums            | 444257  | TWW drums                       |
| Void-touched Drums          | 1243972 | Midnight drums (12.0)           |

Note: Drums give 15% haste (not 30%), which is why the retired haste-delta approach could never detect them. Sated-anchored detection covers them like any other source, because drums apply the same lockout debuff.

### Sated / Lockout Debuffs (10 min duration)

| Debuff                 | ID     | Applied by              |
| ---------------------- | ------ | ----------------------- |
| Sated                  | 57724  | Bloodlust / Primal Rage |
| Exhaustion             | 57723  | Heroism                 |
| Temporal Displacement  | 80354  | Time Warp               |
| Insanity               | 95809  | Ancient Hysteria (pet)  |
| Fatigued               | 160455 | Netherwinds (pet)       |
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

## Approach 2: Haste Delta Detection (RETIRED)

Inferred lust from a ≥25% multiplicative haste spike (`currentHaste > lastHaste * 1.25`) with an assumed 40s duration. **Removed in 1.8.0.** Recorded here because the reasons it failed are worth not repeating:

- **The premise expired.** This approach existed because `GetHaste()` was unrestricted by secret values. That stopped being true in 12.0.5, when player stat APIs began returning secrets whenever auras are secret — exactly the situation the fallback was for. It was dormant from then on.
- **It could not see drums.** At 15% haste they sit below any threshold high enough to exclude trinket procs. No amount of tuning fixes that; the signal genuinely isn't there.
- **It needed a growing exclusion list.** Power Infusion, Metamorphosis, Icy Veins, Crusade, Surging Elements, Ascendance — eight entries by the end, each one a class ability that happened to spike haste, each needing its own aura/cooldown/cast detection to suppress. Every expansion would add more.

The general lesson: a heuristic keyed on a *side effect* (haste) needs constant maintenance to distinguish it from everything else producing that side effect. Keying on a *co-applied marker* (sated) needs none, because nothing else applies it.

## Approach 3: Sated-Anchored Detection (PulseCheck's Solution for 12.1+)

Since 12.1 the Sated/Exhaustion family is flagged **never-secret** while the Bloodlust buff is **not**. That asymmetry is the whole design.

Sated is applied by the same effect that grants lust, to exactly the targets that receive it, so `sated present ⟺ the player got lust`. And because the aura carries real timing even in an encounter, the lust window is *derived* rather than estimated:

```lua
local lustStart      = satedExpiration - satedDuration
local lustExpiration = lustStart + LUST_ASSUMED_DURATION
```

Layers, in priority order:

1. **Aura API** — `C_UnitAuras.GetPlayerAuraBySpellID` over the lust IDs. Exact when readable.
2. **Sated derivation** — the above. Covers every source uniformly, drums included.
3. **Time-based retain** (Approach 4) — hold a known-active lust across a tick that couldn't read it.
4. **Cast events** — `UNIT_SPELLCAST_SUCCEEDED`, in case Sated is ever re-classified as secret.

**Layers 2-4 only apply while the buff is unreadable.** Where the aura API answers honestly, a nil lookup is proof of absence and must win: sated outlives a buff that was cancelled, purged, or dropped on death, and inferring from it there shows a countdown for something the player doesn't have. `LustAuraReadable()` gates this, checking the whole lust ID set since secrecy is decided per spell.

~~Optionally use `COMBAT_LOG_EVENT_UNFILTERED` with `SPELL_AURA_APPLIED`~~ — **not viable since 12.0**. It is a protected event; registering for it triggers `ADDON_ACTION_FORBIDDEN`.

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

**Cons:** If a lust buff is removed early (cancelled, purged, lost on death), the retain path won't notice until the original timer expires. This is why layers 2-4 are gated on the buff being unreadable — where the API answers, an early removal is observed directly and the retain must not override it.

Sated cannot be dispelled and **persists through death**, which is the trap: a dead player has no lust but still has sated, so any inference from sated must also check `UnitIsDeadOrGhost`. (Spirit of Redemption reports not-dead, so Holy Priests correctly keep theirs.) Only encounter reset clears sated, so the time-based retain is safe for sated itself.

### Checking if auras are restricted

```lua
-- Per spell. This is the one to use: secrecy is decided spell by spell.
if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
    local isSecret = C_Secrets.ShouldSpellAuraBeSecret(2825)   -- Bloodlust
    -- If true, the aura is unreadable and inference is warranted.
    -- If false, a nil lookup means genuinely absent -- do not infer over it.
end

-- Global. True in every encounter, so it is TOO BLUNT to gate a specific
-- spell: never-secret spells stay readable while this reports true.
local anySecret = C_Secrets.ShouldAurasBeSecret()
```

Measured in a live 12.1 encounter: `ShouldAurasBeSecret()` = true, `ShouldSpellAuraBeSecret(2825)` = true, `ShouldSpellAuraBeSecret(57724)` = false.

## 12.0 (Midnight) Secret Values Context

Patch 12.0 introduced "secret values" — aura and cooldown fields can be marked protected on tainted execution paths. This affects `C_UnitAuras`, `C_Spell`, and `C_ActionBar` APIs.

- Secrecy is per spell: auras are secret by default during combat, encounters, challenge mode and PvP, but individual spells carry never-secret / always-secret flags that override that
- **Sated/Exhaustion (all seven IDs) are never-secret; Bloodlust/Heroism is not.** Confirmed in a live 12.1 encounter
- **The classification list changes between patches.** 12.1 shipped by removing healer buffs and HoTs from the never-secret list, then Blizzard walked that back and added Sated. Probe at runtime; never hardcode the assumption
- Index, slot, and auraInstanceID lookups **raise a Lua error** when called while auras are secret (12.1). Spell ID and spell name lookups stay callable — `C_UnitAuras.GetUnitAuraBySpellID` is the only safe way to read another unit's auras
- `C_Secrets.ShouldSpellAuraBeSecret()` and `C_Secrets.ShouldUnitAuraInstanceBeSecret()` let addons check restriction status at runtime
- Traditional `UNIT_AURA` event registration can cause taint in restricted contexts — polling is safer
- `COMBAT_LOG_EVENT_UNFILTERED` is a **protected event** — registering for it triggers `ADDON_ACTION_FORBIDDEN`; do not use CLEU as a fallback detection path

## Key APIs

| API | Purpose |
| --- | ------- |
| `C_UnitAuras.GetPlayerAuraBySpellID(id)` | Check for a specific aura on the player by spell ID |
| `C_UnitAuras.GetUnitAuraBySpellID(unit, id)` | Same for another unit. Callable while tainted — the only safe cross-unit read in 12.1 |
| `C_UnitAuras.GetAuraDataByIndex(unit, i, filter)` | **Raises a Lua error** while auras are secret (12.1). Do not use |
| `AuraUtil.ForEachAura(unit, filter, max, func)` | Iterates by index/slot underneath, so it inherits the same 12.1 error. Avoid |
| `AuraUtil.FindAuraByName(name, unit)` | Find aura by name (localized — fragile) |
| `GetHaste()` | Player's current haste %. Returns a secret whenever auras are secret (12.0.5+) |
| `C_Secrets.ShouldSpellAuraBeSecret(id)` | Is this spell's aura data protected? Per spell (12.0+) |
| `C_Secrets.ShouldAurasBeSecret()` | Are auras generally secret? Global — too blunt to gate a specific spell |
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
