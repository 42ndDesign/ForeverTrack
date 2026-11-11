# ForeverTrack test: Hunter's Mark tracking

Thanks for testing. Each step says what to do and what chat should show. Lines start with
`ForeverTrack:`.

**Send back:** the two `PROBE RESULT` lines from steps 2 and 3, and the step number plus the exact
chat line for any step that doesn't match.

If a popup says *"ForeverTrack has been blocked from an action"*, click **Ignore** and carry on.
That's expected during step 3, and it tells us the answer.

## Setup

1. Install this build, `/reload`, then type `/ftrack debug`.
   Expect: `Debug messages: ON`

## Probe (what the game allows)

2. Out of combat, target any mob and type `/ftrack probe`.
   Expect four lines, then one starting with `PROBE RESULT:`. Send that line.
   If you see `PROBE RESULT: BUSY (GCD) - run again`, wait 2 seconds and run it again.

3. Make a macro containing just `/ftrack probe` and put it on your bars. Start a fight with a
   mob that lives a while (at least 5 seconds), target it, and press the macro mid-fight.
   Send the `PROBE RESULT:` line.
   If it says `combat=ENDED`, the fight ended too soon. Do it again on a tougher mob.

The probe switches your hunter tracking around. Set it back afterwards.

## Hunter's Mark (out of combat)

4. Track anything except Beasts. Target a beast and cast Hunter's Mark.
   Expect: `Mark: Beast -> switching to Track Beasts`, then about 1.5 s later
   `Track Beasts: ON`, and the minimap tracking changes.

5. Cast Hunter's Mark on the same beast again.
   Expect: `Mark: Beast -> Track Beasts already on, no change`. No second GCD.

6. Target a humanoid and cast Hunter's Mark.
   Expect: `Mark: Humanoid -> switching to Track Humanoids`, then `Track Humanoids: ON`.

7. Target a critter (rabbit, squirrel...) and cast Hunter's Mark.
   Expect: `Mark: Critter -> no tracking for this type, no change`.

8. Mark a beast and attack it straight away, so the fight starts within 1.5 seconds.
   Expect: `Mark: Beast -> switching to Track Beasts`, then
   `Track Beasts: waiting for combat to end`. After the fight: `Track Beasts: ON`.

9. Cast Hunter's Mark in the middle of a fight.
   Expect: `Mark: in combat -> skipped (in-combat switching is off)`.

10. Die or zone (hearth, instance portal), then wait a few seconds.
    Expect: the last type you marked comes back on.

## Macro version

11. Type `/ftrack mark`. Expect: `Hunter's Mark matching: OFF`.
    Make this macro:
    ```
    #showtooltip Hunter's Mark
    /cast Hunter's Mark
    /ftrack match
    ```
    Use it on a beast while tracking something else.
    Expect: `Macro: Beast -> switching to Track Beasts`, then `Track Beasts: ON`.

12. Type `/ftrack mark` again (expect `Hunter's Mark matching: ON`) and `/ftrack debug`
    (expect `Debug messages: OFF`). You're back to normal settings.
