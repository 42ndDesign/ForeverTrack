<!-- Paste into the CurseForge project's Description (Markdown). -->

**Summary (for the CurseForge summary field, max ~200 chars):**
Keeps your minimap tracking on in WoW Forever: Find Minerals, Herbs, Treasure, Track Beasts and more come back after death, zoning and login, with a reminder when one is off.

---

# ForeverTrack

**Never farm with a blank minimap again.**

WoW Forever lets you track several things at once, but dying clears your tracking and it's easy to forget
after a loading screen. ForeverTrack keeps the trackings you choose switched on.

## What it does

- ⛏️ **Every tracking in the menu.** Find Minerals, Herbs, Treasure and Fish, hunter tracks (Beasts, Humanoids, Undead, Hidden, Elementals, Demons, Giants, Dragonkin), Sense Undead/Demons, and town trackers.
- 🔁 **Turns them back on** at login, after zoning and after you die.
- ✅ **Pick what's managed** with a checkbox per tracking. Gathering is on by default; class and town trackers are off until you tick them.
- ✋ **Respects your choice.** Turn a tracking off yourself and it stays off.
- 🔔 **Reminder icon** when a ticked tracking is off. Only out of combat. Hover to see which, click to fix, Shift-drag to move.
- 🏹 **Hunter's Mark matching.** Mark a beast and you switch to Track Beasts; mark a humanoid and you switch to Track Humanoids. No extra GCD if you're already tracking that type. Macro: `/ftrack match`.
- 🛡️ **Combat-safe.** Never acts in combat, so no blocked-action errors under Forever's addon rules.
- ⚔️ **Stays out of PvP.** Pauses in battlegrounds and arenas. You can turn this off.

## Options

Type `/ftrack` or go to Esc → Options → AddOns → ForeverTrack.

| Command | Effect |
|---|---|
| `/ftrack` | Open the options panel |
| `/ftrack list` | List every tracking with its number and state |
| `/ftrack toggle <number or name>` | Keep it on, or stop managing it |
| `/ftrack on` | Turn all ticked trackings on now |
| `/ftrack auto` | Toggle auto-enable (off = reminder only) |
| `/ftrack reminder` | Toggle the reminder icon |
| `/ftrack pvp` | Toggle pausing in battlegrounds and arenas |
| `/ftrack mark` | Hunters: toggle matching tracking to the Hunter's Mark target |
| `/ftrack match [unit]` | Hunters: switch tracking to the target's type now (for macros) |
| `/ftrack debug` | Print a line for every tracking match |

Settings are saved per character, and only trackings that character has are shown.

## Prefer an aura?

The GitHub repo includes a ready-made Forever Auras / Musca Auras trigger that shows the same reminder.

## Feedback

Found a bug or have an idea? Open an issue on GitHub or leave a comment here.

---

<sub>Source: [github.com/42ndDesign/ForeverTrack](https://github.com/42ndDesign/ForeverTrack) · MIT License · Not affiliated with Blizzard Entertainment.</sub>
