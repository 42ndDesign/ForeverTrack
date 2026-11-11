# Hunter's Mark tracking match: design

Date: 2026-11-11
Target version: v1.2.0
Status: approved, implemented on feature/hunters-mark-tracking

## Goal

A survival hunter does more damage while tracking the same creature type as their target. When they
cast Hunter's Mark, ForeverTrack should switch their hunter tracking to the target's type. If they
already track that type, it does nothing and costs no GCD.

Requested by a hunter player. They will test the build in-game and report back to us by chat
screenshot or copy-paste, so every message the addon prints for this feature has to be short and
clear, and mean one thing only.

## Facts and unknowns

Known (from the requester and existing code):

- In Forever, only one hunter Track spell can be on at a time. Turning one on turns the others off.
  Gathering (Find Minerals, Herbs, Treasure, Fish) and town trackers are not affected.
- `SetTracking` works out of combat from addon code, including from `C_Timer` callbacks
  (ForeverTrack v1.1.x does this).
- Tracking spells trigger the GCD. The existing `pass`/`Step` queue already waits it out.
- The player mostly marks before the pull, out of combat.

Unknown. The probe (section 1) answers these:

- U1: Is `UnitCreatureType(unit)` readable in combat, or a secret value?
- U2: Does `SetTracking` work in combat when called from a key press (macro or slash command)?
- U3: Does `SetTracking` work in combat when called from a timer or event (not a key press)?

Both triggers switch from a timer once the GCD of the spell just cast is over (section 3), so U3
decides it. The in-combat option ships only if U1 and U3 both come back OK. U2 is recorded for
information and doesn't gate anything. The decision is made at build time, as a constant
`COMBAT_SWITCH_WORKS` in the file. The addon does not check it at run time.

## Spell and type tables

Hunter Track spells (the exclusive group), by spell ID:

| Creature type (type ID) | Track spell | Spell ID |
|---|---|---|
| Beast (1) | Track Beasts | 1494 |
| Dragonkin (2) | Track Dragonkin | 19879 |
| Demon (3) | Track Demons | 19878 |
| Elemental (4) | Track Elementals | 19880 |
| Giant (5) | Track Giants | 19882 |
| Undead (6) | Track Undead | 19884 |
| Humanoid (7) | Track Humanoids | 19883 |
| (none) | Track Hidden | 19885 |

Track Hidden belongs to the exclusive group, but no creature type maps to it.

Hunter's Mark spell IDs: 1130, 14323, 14324, 14325. `UNIT_SPELLCAST_SUCCEEDED` passes
`(unit, castGUID, spellID)` and no spell name. If the ID is not in the list, look up its name with
`C_Spell.GetSpellName(spellID)` (or `GetSpellInfo(spellID)` on older clients) and compare it with
the localized name of 1130. This also catches any ranks Forever adds with new IDs. Skip the check
if the spell ID is a secret value.

Creature type names: `UnitCreatureType` returns a localized string. Build the type-name → spell map
from `C_CreatureInfo.GetCreatureTypeInfo(id).name` for IDs 1–7 when that API exists, plus the
English names as a fallback. Types without a Track spell (Critter, Mechanical, Not specified, Totem,
Non-combat Pet) and unknown strings mean "no match".

Track entries in the tracking menu are found by spell ID first, then by spell name, as `Entries()`
already does.

## 1. Probe: `/ftrack probe`

Built and shipped to the tester first, in the same build as the feature.

Run it with a target selected. Procedure:

1. If the GCD is running, print only `PROBE RESULT: BUSY (GCD) - run again` and stop. This keeps
   line [2] a true key-press test.
2. Line [1]: read `UnitCreatureType("target")` and report it: readable, secret, or no target.
3. Pick two different hunter Track spells that are off: A for line [2] and B for line [3]. Prefer
   the target's type for A. If no spell is free for a line, that line reports `SKIPPED`.
4. Line [2]: call `SetTracking(A, true)` right away. This runs inside the key press. After 0.3 s,
   read the menu and report the result.
5. Line [3]: once the GCD from step 4 is over, turn on B from a `C_Timer` callback (no key press)
   and report the result the same way. Both lines test turning a tracking *on*, the same action
   matching does.
6. Summary line.

The probe leaves B on. The tester gets their own tracking back by picking it again.

How a result is decided, for [2] and [3]:

- `BLOCKED`: `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` fired for ForeverTrack during the
  attempt. Register both events for the probe only. A blocked protected call doesn't raise a Lua
  error, so the result comes from these events. The `pcall` around `SetTracking` is only a guard,
  and if it fails the line reports `BLOCKED` too. `ADDON_ACTION_FORBIDDEN` also brings up
  Blizzard's "ForeverTrack has been blocked" popup. The tester clicks Ignore (section 7).
- `OK`: the tracking ended up in the requested state.
- `NOCHANGE`: no error, but the state did not change.

Output. Every line starts with the `ForeverTrack` chat prefix, and nothing else is printed:

```
ForeverTrack: probe | version: 1.2.0 | in combat: YES
[1] target type: Humanoid (readable)
[2] key press: Track Humanoids on: OK
[3] timer: Track Beasts on: BLOCKED
PROBE RESULT: combat=YES type=OK keypress=OK timer=BLOCKED
```

The tester runs the probe twice: once out of combat, once in combat. Typing `/ftrack probe` in chat
counts as a key press just as a macro does. A macro button is easier to use mid-fight, though. The
last line is the only one they need to send back.

Values on the summary line: `combat=YES|NO|ENDED` (ENDED: combat was over before [3] ran, so run it
again in a longer fight), `type=OK|SECRET|NOTARGET|NONE`,
`keypress=OK|BLOCKED|NOCHANGE|SKIPPED`, `timer=OK|BLOCKED|NOCHANGE|SKIPPED`. `SKIPPED` means the
step could not run, for example because there is no target or no hunter Track spell is off. The
line before it says why.

The probe works whatever the options say: it ignores the in-combat setting and the PvP pause.

## 2. Matching

`Match(unit, source)`. `source` is `"mark"` or `"macro"` and is only used in messages.

1. Not a hunter: return quietly.
2. Gate. Add `CanActCombat()`: alive, not on a taxi, not paused for PvP. That is `CanAct()` without
   the combat check. Out of combat, `CanAct()` must pass. In combat, `COMBAT_SWITCH_WORKS` and
   `db.markCombat` must both be true, and then `CanActCombat()` must pass. Matching runs whether
   `db.auto` is on or off. `auto` only covers re-enabling after login, zoning and death.
3. Read the creature type. No unit, a secret value, or a type with no Track spell: stop.
4. Find the matching Track entry in the menu. If this character lacks that spell, stop.
5. Already on: stop. No `SetTracking`, so no GCD.
6. Otherwise, move the keep-on tick (section 4) to the matching spell, then queue it through the
   existing pass: add it to `pass.targets`, or start a new pass. A new pass must set `targets`,
   `tries = {}` and `deadline`, as `EnableWanted` does. Set `pass.combatOK = true` for a match
   allowed in combat. `Step()` checks `pass.combatOK and CanActCombat() or CanAct()`, so a pass
   started in combat isn't dropped on its first step. `Step()` waits for the Hunter's Mark GCD,
   then calls `SetTracking`.

A match that arrives during a running pass joins that pass. If a second match arrives for another
type before the first has fired (the player marked two targets quickly), the newer one wins: the
older Track spell is removed from `pass.targets`.

When a pass ends, it reports how each of its hunter Track targets came out (section 6): on, or
failed because it was refused, timed out or the conditions stopped allowing it.

## 3. Triggers

- Automatic: `ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")`. The `OnEvent` handler
  takes `(self, event, arg1, arg2, arg3)`, and `arg3` is the spell ID. On a Hunter's Mark (see the
  spell tables), and only if `db.markMatch` is on, call `Match("target", "mark")`.
  Known limit: the event doesn't say who the spell hit. A Mark cast through a mouseover or focus
  macro is matched against `target`. Those players should use `/ftrack match mouseover` (or
  `focus`) and turn the automatic option off.
- Macro: `/ftrack match [unit]`. `unit` defaults to `target`. Valid units: `target`, `focus`,
  `mouseover`, plus anything `UnitExists` accepts. It works even with the automatic option off, so
  it can follow any spell:

  ```
  #showtooltip Hunter's Mark
  /cast Hunter's Mark
  /ftrack match
  ```

The macro's `/cast` triggers the GCD, so `/ftrack match` always queues and switches from a timer.
That makes the probe's `timer=` result the one that decides whether in-combat matching works.

## 4. Keep-on list: hunter Track spells as a radio group

- Ticking one hunter Track spell unticks the others. This applies in the options panel rows and in
  `/ftrack toggle`, through one helper, `SetWant(key, on)`. Unticking leaves none ticked.
- `Match` moves the tick to the matched spell, so after death or zoning the last-marked type comes
  back on.
- Migration runs once per session, in the first `Refresh()`. By then the tracking menu is filled
  in, which isn't true yet at `ADDON_LOADED`. If more than one hunter Track spell is ticked, keep
  the one that is on. If none of them is on, keep the first by name. This fixes the existing
  problem where two ticked hunter tracks fight each other and the reminder shows.
- `Missing()` and the reminder treat the group as one slot: the group is "missing" only if its
  ticked spell is off.

## 5. Options

Saved per character, added to `DEFAULTS`:

| Key | Default | Panel label | Slash |
|---|---|---|---|
| `markMatch` | `true` | Match tracking to Hunter's Mark target | `/ftrack mark` |
| `markCombat` | `false` | Also switch in combat | `/ftrack markcombat` |
| `debug` | `false` | (not in panel) | `/ftrack debug` |

- The panel shows the first two only on hunters. They go between the `pvp` checkbox and the
  "Keep these on:" header. Re-anchor `header` to the last visible checkbox, so it sits under `pvp`
  for other classes.
- "Also switch in combat" (and `/ftrack markcombat`) exists only while `COMBAT_SWITCH_WORKS` is
  true. The test build sets it to false, so the option stays hidden.
- Slash toggles print one line, e.g. `Hunter's Mark matching: ON`.

## 6. Messages

Normal use prints nothing. The tracking change is the feedback, and the extra GCD is expected.

With `/ftrack debug` on, every match prints one line. Each line names the source, the type, and the
result:

```
Mark: Beast -> Track Beasts already on, no change
Mark: Humanoid -> switching to Track Humanoids
Macro: Critter -> no tracking for this type, no change
Mark: in combat -> skipped (in-combat switching is off)
Mark: dead -> skipped
Mark: on a flight path -> skipped
Mark: battleground or arena -> skipped (PvP pause is on)
Macro: no target -> no change            (or "no mouseover", "no focus")
Macro: type hidden by the game -> no change
Mark: Undead -> Track Undead not known by this character, no change
Macro: Undead -> already switching to Track Undead   (macro + automatic trigger both fired)
```

When the pass started by a "switching to" line ends, it prints one result line:

```
Track Humanoids: ON
Track Humanoids: waiting for combat to end
Track Humanoids: FAILED (died, flight path or PvP pause)
Track Humanoids: FAILED (timed out)
Track Humanoids: FAILED (game refused the change)
```

"Waiting for combat to end" covers the common case: mark, then pull before the GCD is over. The
switch is kept and runs 0.5 s after `PLAYER_REGEN_ENABLED`, then prints `ON`. A newer match
replaces it.

`/ftrack match` never prints anything when `debug` is off, so a macro pressed often does not spam
chat.

## 7. Tester handoff

Add `docs/TESTING_HUNTERS_MARK.md` with numbered steps. Each step gives what to do and the exact
line to expect, and the tester sends back any line that differs:

0. If a popup says "ForeverTrack has been blocked from an action", click Ignore and keep going.
   This is expected during the probe and tells us the answer.
1. `/ftrack debug` (expect `Debug messages: ON`).
2. Out of combat, target a beast, `/ftrack probe`, send the `PROBE RESULT` line. If it says
   `BUSY (GCD)`, wait two seconds and run it again.
3. Put `/ftrack probe` on a macro button. Fight a mob and press it in combat, then send the
   `PROBE RESULT` line.
4. Out of combat, mark a beast while tracking something else (expect `Mark: Beast -> switching to
   Track Beasts`, then `Track Beasts: ON` after about 1.5 s).
5. Mark the same beast again (expect `already on, no change`, and no second GCD).
6. Mark a humanoid (expect a switch to Track Humanoids).
7. Mark a critter (expect `no tracking for this type`).
8. Die or zone, and check Track Humanoids comes back on.
9. `/ftrack mark` to turn the automatic trigger off, then repeat 4 with the macro instead
   (expect `Macro: ...` lines).

## Out of scope

- Other classes' trackings (druid Track Humanoids, paladin and warlock Sense spells): no exclusive
  group handling and no matching.
- A list of trigger spells you edit in the panel. The `/ftrack match` macro covers this.
- Detecting at run time whether calls work in combat.

## Files

- Modify: `ForeverTrack.lua` (tables, `Match`, probe, event, options, radio group, slash commands).
- Modify: `README.md`, `CHANGELOG.md`, `docs/CURSEFORGE_DESCRIPTION.md`.
- Create: `docs/TESTING_HUNTERS_MARK.md`.
