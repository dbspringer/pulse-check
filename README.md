# PulseCheck

A lightweight World of Warcraft addon that tracks two raid-critical cooldowns: **Battle Resurrection** charges and **Bloodlust / Heroism** status.

## Features

**Battle Res** — Shows remaining encounter charges with a cooldown timer. Outside of encounters, tracks your personal brez cooldown if your class has one (Druid, Death Knight, Warlock, Paladin).

**Bloodlust** — Detects all bloodlust variants (Bloodlust, Heroism, Time Warp, Primal Rage, Fury of the Aspects, drums, etc.) with four visual states:
- **Ready** — normal icon
- **Active** — glowing icon with duration countdown
- **Sated** — desaturated icon with lockout timer
- **Raid Sated** — dimmed icon when your group is sated but you aren't

Both icons display in a compact, moveable frame with an optional backdrop.

## Installation

Install from [CurseForge](https://www.curseforge.com/wow/addons/pulsecheck), or manually:

1. Download or clone this repository
2. Copy the `PulseCheck` folder into your WoW AddOns directory:
   - **Windows:** `World of Warcraft\_retail_\Interface\AddOns\`
   - **macOS:** `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload` if already running

## Configuration

**Edit Mode** — Press Esc > Edit Mode to unlock the frame. Click it to open an inline settings dialog with orientation, scale, visibility, and sound options. Drag to reposition (snaps to a 10px grid).

**Interface > AddOns > PulseCheck** — Same settings in the standard addon options panel.

**Slash Commands:**

| Command | Description |
|---|---|
| `/plc` | Open settings panel |
| `/plc help` | Show command list |
| `/plc lock` / `unlock` | Lock or unlock frame position |
| `/plc orientation` | Toggle horizontal / vertical layout |
| `/plc scale <0.5-2.0>` | Set icon scale |
| `/plc sound <lust\|bres> <on\|off>` | Toggle sound alerts |
| `/plc show <type\|all> <on\|off>` | Toggle visibility per content type |
| `/plc reset` | Reset all settings to defaults |

Visibility types: `dungeons`, `raids`, `scenarios`, `battlegrounds`, `openworld`, `solo`, `all`

## Sound Alerts

Built-in alert sounds for bloodlust activation, bloodlust ready (sated expired), and battle res charge used. If [LibSharedMedia](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) is available (via BigWigs, SharedMedia_Causese, etc.), those sounds appear in the picker too.

## Compatibility

- **Retail only** — requires World of Warcraft 12.0 (Midnight) or later
- Handles 12.0 "secret values" aura restrictions with haste-delta and time-based fallbacks
- No external library dependencies

## License

[MIT](LICENSE)
