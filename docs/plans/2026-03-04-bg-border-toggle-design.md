# Background & Border Toggle Design

## Summary

Add two independent toggles to show/hide the main frame's background and border.

## Saved Variables

Two new boolean keys in `DEFAULTS`:

- `showBackground` (default: `true`)
- `showBorder` (default: `true`)

## Behavior

- Background toggle: sets backdrop color alpha to `0` (hidden) or `0.46` (shown)
- Border toggle: sets backdrop border color alpha to `0` (hidden) or `1` (shown)
- Uses existing `SetBackdropColor` / `SetBackdropBorderColor` APIs — no backdrop recreation needed
- Applied via a helper function called from checkbox handlers and on initial load

## UI Placement

### Options Panel (`/pc` settings)

The two checkboxes sit on the same row as "Vertical orientation" — all three layout checkboxes in one row.

### Edit Mode Dialog

The two checkboxes appear after the "Vertical orientation" checkbox, before the Scale slider.

## Locale Strings

- `L.SHOW_BACKGROUND` = `"Show background"`
- `L.SHOW_BORDER` = `"Show border"`

No new section header needed — they share the existing layout area.

## Reset Defaults

The "Reset Defaults" button resets both to `true` and reapplies the backdrop.
