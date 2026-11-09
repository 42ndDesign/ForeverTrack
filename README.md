<p align="center"><img src="assets/avatar.png" width="160" alt="ForeverTrack icon"></p>

# ForeverTrack

A small addon for **World of Warcraft: Forever** that keeps **Find Minerals** and **Find Treasure** on,
and reminds you when one of them is off.

Forever lets you run several trackings at once, but dying clears them and they're easy to forget after
a loading screen. ForeverTrack turns them back on for you.

## Features

- Turns Find Minerals and Find Treasure on at login, after zoning and after you die.
- Respects your choice: if you turn a tracking off yourself, it stays off.
- Pulsing reminder icon (out of combat only) when a tracking you want is off. Click to fix, Shift-drag to move.
- Never acts in combat. Works within Forever's addon restrictions.
- Characters without a spell (for example, non-Dwarves and Find Treasure) just skip it.

## Install

- **CurseForge app:** choose World of Warcraft → **Forever** and install ForeverTrack.
- **By hand:** download the zip from [Releases](../../releases) and unzip it into your WoW Forever
  `Interface\AddOns` folder, then `/reload`.

## Commands

| Command | Effect |
|---|---|
| `/ftrack` or `/ftrack status` | Show what's on now |
| `/ftrack on` | Turn all managed trackings on now |
| `/ftrack minerals` | Toggle whether Find Minerals is managed |
| `/ftrack treasure` | Toggle whether Find Treasure is managed |
| `/ftrack auto` | Toggle auto-enable (off = reminder only) |
| `/ftrack reminder` | Toggle the reminder icon |

Settings are saved per character.

## Prefer an aura?

[docs/FOREVER_AURAS_REMINDER.md](docs/FOREVER_AURAS_REMINDER.md) has a Forever Auras / Musca Auras
custom trigger that shows the same reminder without this addon.

## Development

The repo root is the addon folder. Releases are built by
[BigWigsMods/packager](https://github.com/BigWigsMods/packager): push a tag like `v1.0.1` and the
GitHub Action builds the zip, creates a GitHub release and, once configured, uploads to CurseForge.
See [docs/PUBLISHING.md](docs/PUBLISHING.md).

## License

MIT © 42nd Design LLC. Not affiliated with or endorsed by Blizzard Entertainment.
World of Warcraft is a trademark of Blizzard Entertainment, Inc.
