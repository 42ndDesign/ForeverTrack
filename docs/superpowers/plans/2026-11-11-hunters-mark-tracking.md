# Hunter's Mark Tracking Match Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers-extended-cc:subagent-driven-development (if subagents available) or superpowers-extended-cc:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build v1.2.0 of ForeverTrack. When a hunter casts Hunter's Mark (or runs `/ftrack match`), switch their hunter tracking to the target's creature type. Ship a `/ftrack probe` command that a remote tester can run in-game.

**Architecture:** All changes go in `ForeverTrack.lua`, using its existing sections. The matched spell is added to the existing `pass`/`Step` queue so the GCD is waited out. Hunter Track spells become a group in the keep-on list where only one can be ticked. The probe runs on its own, outside that queue.

**Tech Stack:** WoW addon Lua 5.1 (Forever client, interface 16001). There's no Lua toolchain or test harness here, so checks are a syntax parse with `npx luaparse` plus the in-game test script.

**Spec:** `docs/superpowers/specs/2026-11-11-hunters-mark-tracking-design.md`

---

### Task 1: Hunter group, radio ticks, combat gate, pass changes
**Files:** Modify `ForeverTrack.lua`. This covers the constants, `Missing`, `CanAct`, `Step`, `EnableWanted`, `Toggle`, panel row OnClick and `Refresh`.
- [ ] Add the `HUNTER_TRACK` set (spell IDs), `IsHunter()`, `IsHunterTrack(e)`, and the `COMBAT_SWITCH_WORKS = false` constant.
- [ ] Add `SetWant(key, on)`, which unticks the other hunter Track spells when one is ticked. Use it in the panel rows and in `Toggle`.
- [ ] Run `MigrateHunterGroup()` once in the first `Refresh()`.
- [ ] Add `CanActCombat()`. `Step()` checks `pass.combatOK` and uses `CanActCombat()` when it's set, `CanAct()` otherwise.
- [ ] Have the pass track `reportKeys`. When the pass ends, print `Track X: ON` or `FAILED` for each of them (debug only).
- [ ] Verify: `npx luaparse` parses the file.

### Task 2: Match, triggers, debug messages, options
**Files:** Modify `ForeverTrack.lua`.
- [ ] Build the creature type → spell map, using `C_CreatureInfo` for localized names when available.
- [ ] Write `Match(unit, source)`, following spec §2 and §6.
- [ ] Add `DEFAULTS.markMatch = true` and `DEFAULTS.debug = false`, and `markCombat`, which is only used when `COMBAT_SWITCH_WORKS` is true.
- [ ] Register `UNIT_SPELLCAST_SUCCEEDED` for the player and recognize Hunter's Mark by ID or name.
- [ ] Add the slash commands: `match [unit]`, `mark`, `markcombat`, `debug`.
- [ ] Panel: add the hunter-only checkboxes and re-anchor the header.
- [ ] Verify: the file parses.

### Task 3: Probe
**Files:** Modify `ForeverTrack.lua`.
- [ ] Write `/ftrack probe`, following spec §1: the BUSY line, [1], [2], [3] and `PROBE RESULT`.
- [ ] Register `ADDON_ACTION_BLOCKED`/`FORBIDDEN` while an attempt runs and unregister after.
- [ ] Verify: the file parses.

### Task 4: Docs and version
**Files:** Create `docs/TESTING_HUNTERS_MARK.md`. Modify `README.md`, `CHANGELOG.md`, `docs/CURSEFORGE_DESCRIPTION.md`.
- [ ] Write the tester steps from spec §7.
- [ ] Add the changelog entry (v1.2.0), and the README and CurseForge command tables.
