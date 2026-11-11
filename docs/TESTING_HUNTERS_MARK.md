# ForeverTrack test: Hunter's Mark tracking

An in-game checklist for the Hunter's Mark feature. Run it on a hunter before a release that
touches matching. Each step says what to do and what chat should show. Lines start with
`ForeverTrack:`.

## Setup

1. `/ftrack debug`. Expect: `Debug messages: ON`

## Out of combat

2. Track anything except Beasts. Target a beast and cast Hunter's Mark.
   Expect: the Mark lands on the first click, `Mark: Beast -> switching to Track Beasts`, then
   about 1.5 s later `Track Beasts: ON`.

3. Cast Hunter's Mark on the same beast again.
   Expect: `Mark: Beast -> Track Beasts already on, no change`. No second GCD.

4. Target a humanoid and cast Hunter's Mark.
   Expect: `Mark: Humanoid -> switching to Track Humanoids`, then `Track Humanoids: ON`.

5. Target a critter and cast Hunter's Mark.
   Expect: `Mark: Critter -> no tracking for this type, no change`.

6. Mark a mob whose Track spell you haven't trained (low-level hunter).
   Expect: the Mark casts, and `Mark: <Type> -> Track <Type> not known by this character, no change`.

7. Mark a beast and attack it straight away (fight starts within 1.5 s).
   Expect: `Track Beasts: waiting for combat to end`. After the fight: `Track Beasts: ON`.

8. Cast Hunter's Mark in the middle of a fight.
   Expect: `Mark: in combat -> skipped (in-combat switching is off)`.

9. Die or zone, then wait a few seconds.
   Expect: the last type you marked comes back on.

## In combat

`/ftrack markcombat`. Expect: `In-combat switching: ON` (also a checkbox in the options panel).

10. Mid-fight, mark a mob of a type you aren't tracking.
    Expect: `switching to Track <Type>`, then `Track <Type>: ON`.

11. Mark a beast and attack it straight away.
    Expect: `Track Beasts: ON` during the fight, not `waiting for combat to end`.

`/ftrack markcombat` again to turn it back off.

## Macro

12. `/ftrack mark`. Expect: `Hunter's Mark matching: OFF`. Then use this macro on a beast while
    tracking something else:
    ```
    #showtooltip Hunter's Mark
    /cast Hunter's Mark
    /ftrack match
    ```
    Expect: `Macro: Beast -> switching to Track Beasts`, then `Track Beasts: ON`.

13. `/ftrack mark` (expect `ON`) and `/ftrack debug` (expect `OFF`) to restore the defaults.
