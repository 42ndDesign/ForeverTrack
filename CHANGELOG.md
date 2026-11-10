# ForeverTrack

## v1.1.2

- Pauses in battlegrounds and arenas: no tracking changes and no reminder. Your trackings come back when you leave. On by default; turn it off in the options panel or with `/ftrack pvp`.
- The tracking list in the options panel now scrolls when it doesn't fit.

## v1.1.1

- Fixed: only the first tracking came back on (e.g. Find Minerals but not Find Treasure). Tracking abilities share the global cooldown, so ForeverTrack now turns them on one at a time, about 1.5 seconds apart.
- The reminder icon waits until all trackings have been tried before showing.
- Fixed the "Attempt to register unknown event LEARNED_SPELL_IN_TAB" error on load.

## v1.1.0

- Works with every tracking in the minimap menu: Find Herbs, Find Fish, hunter Track Beasts/Humanoids/Undead/Hidden/Elementals/Demons/Giants/Dragonkin, Sense Undead/Demons, and town trackers such as Flight Master or Mailbox.
- New options panel (Esc → Options → AddOns → ForeverTrack, or `/ftrack`) with a checkbox per tracking.
- Gathering trackings (Minerals, Herbs, Treasure, Fish) are on by default. Class and town trackers are off until you tick them.
- `/ftrack list` and `/ftrack toggle <number or name>` for chat control.
- Reminder tooltip lists every tracking that's off.
- Settings from v1.0.0 carry over.

## v1.0.0

- First release for WoW Forever (1.60.1).
- Keeps Find Minerals and Find Treasure on together. Turns them back on at login, after zoning and after death.
- Leaves a tracking off if you turn it off yourself.
- Out-of-combat reminder icon when a tracking you want is off. Click it to fix, Shift-drag to move.
- `/ftrack` commands to choose what's managed, turn auto-enable off, and check status.
