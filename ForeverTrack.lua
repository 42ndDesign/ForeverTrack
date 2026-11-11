-- ForeverTrack: keep the minimap trackings you choose switched on in WoW Forever
-- (Forever allows several at once), and show a clickable reminder when one is off.
-- Works with every entry in the minimap tracking menu: gathering (Find Minerals,
-- Herbs, Treasure, Fish), class tracking (Track Beasts, Humanoids, Undead, ...,
-- Sense Undead/Demons) and town trackers (Flight Master, Mailbox, ...).
-- All changes happen OUT of combat only.

local ADDON = ...

-- Spells turned on by default the first time a character sees them.
local DEFAULT_ON = {
  [2580]  = true, -- Find Minerals
  [2383]  = true, -- Find Herbs
  [2481]  = true, -- Find Treasure (Dwarf)
  [43308] = true, -- Find Fish
}
-- English fallback when an entry carries no spell ID
local DEFAULT_ON_NAMES = {
  ["Find Minerals"] = true, ["Find Herbs"] = true,
  ["Find Treasure"] = true, ["Find Fish"] = true,
}

-- Hunter Track spells. In Forever only one of these can be on at a time.
local HUNTER_TRACK = {
  [1494]  = true, -- Track Beasts
  [19879] = true, -- Track Dragonkin
  [19878] = true, -- Track Demons
  [19880] = true, -- Track Elementals
  [19882] = true, -- Track Giants
  [19884] = true, -- Track Undead
  [19883] = true, -- Track Humanoids
  [19885] = true, -- Track Hidden (no creature type maps to it)
}
-- Creature type ID -> Track spell, and the English type names as a fallback
local TYPE_TRACK = { [1] = 1494, [2] = 19879, [3] = 19878, [4] = 19880, [5] = 19882, [6] = 19884, [7] = 19883 }
local TYPE_EN = { [1] = "Beast", [2] = "Dragonkin", [3] = "Demon", [4] = "Elemental",
                  [5] = "Giant", [6] = "Undead", [7] = "Humanoid" }
local HUNTERS_MARK = { [1130] = true, [14323] = true, [14324] = true, [14325] = true }

-- Whether SetTracking works in combat from a timer. Set from the tester's
-- /ftrack probe results (timer=OK while in combat). Off until confirmed.
local COMBAT_SWITCH_WORKS = false

local DEFAULTS = {
  want = {},         -- [key] = true/false, key = "spell:<id>" or "name:<name>"
  auto = true,       -- re-enable at login, zoning, and after death
  reminder = true,   -- show the "tracking is off" icon
  pausePvP = true,   -- do nothing in battlegrounds and arenas
  markMatch = true,  -- hunters: switch tracking to the Hunter's Mark target's type
  markCombat = false,-- also switch in combat (only offered if COMBAT_SWITCH_WORKS)
  debug = false,     -- one chat line per match decision
  point = nil,       -- saved reminder position
}

local db

local function Print(msg) print("|cff33ff99ForeverTrack|r: " .. msg) end
local function Debug(msg) if db and db.debug then Print(msg) end end

local function Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = get and get(ADDON, "Version")
  if type(v) ~= "string" or v:find("@", 1, true) then return "dev" end
  return v
end

local function IsHunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

---------------------------------------------------------------------------
-- API shims (C_Minimap on the modern client; old globals as fallback)
---------------------------------------------------------------------------
local function NumTrackingTypes()
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    return C_Minimap.GetNumTrackingTypes() or 0
  elseif GetNumTrackingTypes then
    return GetNumTrackingTypes() or 0
  end
  return 0
end

-- Returns name, texture, active, type, subType, spellID
local function TrackingInfo(i)
  local a, b, c, d, e, f
  if C_Minimap and C_Minimap.GetTrackingInfo then
    a, b, c, d, e, f = C_Minimap.GetTrackingInfo(i)
  elseif GetTrackingInfo then
    a, b, c, d, e, f = GetTrackingInfo(i)
  end
  if type(a) == "table" then
    return a.name, a.texture, a.active, a.type, a.subType, a.spellID
  end
  return a, b, c, d, e, f
end

local function SetTrackingIndex(i, on)
  if C_Minimap and C_Minimap.SetTracking then
    C_Minimap.SetTracking(i, on)
  elseif SetTracking then
    SetTracking(i, on)
  end
end

local function IsSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

---------------------------------------------------------------------------
-- Tracking list
---------------------------------------------------------------------------
-- Localized names of the hunter Track spells, for entries without a spell ID
local hunterTrackNames
local function HunterTrackByName(name)
  if not hunterTrackNames then
    hunterTrackNames = {}
    for id in pairs(HUNTER_TRACK) do
      local n = SpellName(id)
      if n then hunterTrackNames[n] = id end
    end
  end
  return hunterTrackNames[name]
end

-- Every entry in the tracking menu:
-- { index, key, name, texture, active, isSpell, spellID, hunterTrack }
-- Spell trackings come first, then town trackers, each sorted by name.
local function Entries()
  local list = {}
  for i = 1, NumTrackingTypes() do
    local name, texture, active, ttype, _, spellID = TrackingInfo(i)
    if name and not IsSecret(name) and not IsSecret(active) then
      if IsSecret(spellID) then spellID = nil end
      local key = (spellID and spellID > 0) and ("spell:" .. spellID) or ("name:" .. name)
      list[#list + 1] = {
        index = i, key = key, name = name, texture = texture,
        active = active and true or false,
        isSpell = (ttype == "spell") or (spellID ~= nil and spellID > 0),
        spellID = spellID,
        hunterTrack = (spellID and HUNTER_TRACK[spellID]) and spellID or HunterTrackByName(name),
      }
    end
  end
  table.sort(list, function(a, b)
    if a.isSpell ~= b.isSpell then return a.isSpell end
    return a.name < b.name
  end)
  return list
end

-- First time we see an entry, give it a default; afterwards the saved choice wins.
local function ApplyDefaults(list)
  for _, e in ipairs(list) do
    if db.want[e.key] == nil then
      db.want[e.key] = (e.spellID and DEFAULT_ON[e.spellID]) or DEFAULT_ON_NAMES[e.name] or false
    end
  end
end

-- Hunter Track spells are a radio group: ticking one unticks the others.
local function SetWant(e, on, list)
  db.want[e.key] = on and true or false
  if on and e.hunterTrack then
    for _, o in ipairs(list or Entries()) do
      if o.hunterTrack and o.key ~= e.key then db.want[o.key] = false end
    end
  end
end

-- Older versions let several hunter Track spells be ticked, and they fought each
-- other. Keep one: the one that's on, else the first by name. Runs once, after
-- the tracking menu has loaded.
local groupMigrated
local function MigrateHunterGroup(list)
  if groupMigrated or #list == 0 then return end
  groupMigrated = true
  local ticked = {}
  for _, e in ipairs(list) do
    if e.hunterTrack and db.want[e.key] then ticked[#ticked + 1] = e end
  end
  if #ticked < 2 then return end
  local keep = ticked[1]
  for _, e in ipairs(ticked) do if e.active then keep = e; break end end
  for _, e in ipairs(ticked) do if e ~= keep then db.want[e.key] = false end end
end

-- Battlegrounds and arenas: ForeverTrack stays out of the way (unless the option is off).
local function InPvPInstance()
  if not (db and db.pausePvP) or not IsInInstance then return false end
  local inInstance, kind = IsInInstance()
  if IsSecret(inInstance) or IsSecret(kind) then return false end
  return inInstance and (kind == "pvp" or kind == "arena") or false
end

-- Everything CanAct checks except combat; used by in-combat matches.
local function CanActCombat()
  if InPvPInstance() then return false end
  if UnitIsDeadOrGhost("player") then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  return true
end

local function CanAct()
  if InCombatLockdown() then return false end
  return CanActCombat()
end

local function Missing()
  local out = {}
  for _, e in ipairs(Entries()) do
    if db.want[e.key] and not e.active then out[#out + 1] = e end
  end
  return out
end

-- Tracking abilities are spells and trigger the global cooldown, so turning on
-- two in the same frame fails for the second one. Turn them on one at a time,
-- waiting out the GCD and re-reading the menu between steps.
local GCD_SPELL = 61304   -- the client's global-cooldown spell
local GCD_FALLBACK = 1.6  -- wait this long after a spell when the GCD can't be read
local STEP = 0.25         -- delay before checking whether the last step worked
local MAX_TRIES = 3       -- per tracking per pass, so a refusal can't loop forever
local PASS_TIMEOUT = 30   -- give up on a pass after this many seconds

-- { targets = {[key]=true}, tries = {[key]=n}, lastSpell = time, deadline = time,
--   report = {[key]=name} (matches to report on when the pass ends),
--   combatOK = true (an in-combat match is allowed to run) }
local pass
local UpdateReminder
local afterCombat = {} -- [key] = name: matches cut off by combat, resumed when it ends

local function NewPass()
  return { targets = {}, tries = {}, report = {}, deadline = GetTime() + PASS_TIMEOUT }
end

local function PassAllowed()
  if pass.combatOK then return CanActCombat() end
  return CanAct()
end

-- End the pass and, for matches, say how it went (debug only).
-- why: nil = finished normally, "stopped" = conditions changed, "timeout"
local function FinishPass(why)
  local p = pass
  pass = nil
  if p and next(p.report) then
    local byKey = {}
    for _, e in ipairs(Entries()) do byKey[e.key] = e end
    for key, name in pairs(p.report) do
      local e = byKey[key]
      if e and e.active then
        Debug(name .. ": ON")
      elseif why == "stopped" and InCombatLockdown() and db.want[key] then
        afterCombat[key] = name
        Debug(name .. ": waiting for combat to end")
      elseif why == "stopped" then
        Debug(name .. ": FAILED (died, flight path or PvP pause)")
      elseif why == "timeout" then
        Debug(name .. ": FAILED (timed out)")
      else
        Debug(name .. ": FAILED (game refused the change)")
      end
    end
  end
  UpdateReminder()
end

local function GCDRemaining()
  local start, duration
  if C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(GCD_SPELL)
    if type(info) == "table" then start, duration = info.startTime, info.duration end
  elseif GetSpellCooldown then
    start, duration = GetSpellCooldown(GCD_SPELL)
  end
  if IsSecret(start) or IsSecret(duration) then return nil end
  if type(start) ~= "number" or type(duration) ~= "number" then return nil end
  if duration == 0 then return 0 end
  return math.max(0, start + duration - GetTime())
end

local function Casting()
  local c = UnitCastingInfo and UnitCastingInfo("player")
  local ch = UnitChannelInfo and UnitChannelInfo("player")
  return (c ~= nil) or (ch ~= nil)
end

local function Step()
  if not pass then return end
  if not PassAllowed() then FinishPass("stopped"); return end
  if GetTime() > pass.deadline then FinishPass("timeout"); return end
  -- Wait for whichever is later: the GCD as the game reports it, or GCD_FALLBACK
  -- after the last spell we know of. Right after a cast the game can still report
  -- the GCD as 0, and casting then would eat the spell we were triggered by.
  local wait = math.max(GCDRemaining() or 0, (pass.lastSpell or -100) + GCD_FALLBACK - GetTime())
  if wait > 0 or Casting() then
    C_Timer.After(math.max(wait, STEP) + 0.05, Step); return
  end
  for _, e in ipairs(Entries()) do
    if pass.targets[e.key] and db.want[e.key] and not e.active
        and (pass.tries[e.key] or 0) < MAX_TRIES then
      pass.tries[e.key] = (pass.tries[e.key] or 0) + 1
      if e.isSpell then pass.lastSpell = GetTime() end
      SetTrackingIndex(e.index, true)
      C_Timer.After(STEP, Step)
      return
    end
  end
  FinishPass()
end

-- Turn on every ticked tracking that is off (or only `onlyKey`). Only what is
-- off when asked is targeted, so a tracking you switch off mid-pass stays off.
local function EnableWanted(onlyKey)
  if not CanAct() then return end
  local list = Entries()
  ApplyDefaults(list)
  local fresh = not pass
  pass = pass or NewPass()
  pass.deadline = GetTime() + PASS_TIMEOUT
  for _, e in ipairs(list) do
    if db.want[e.key] and not e.active and (not onlyKey or e.key == onlyKey) then
      pass.targets[e.key] = true
    end
  end
  if fresh then Step() end
end

local function EnableAllWanted() EnableWanted() end

---------------------------------------------------------------------------
-- Hunter's Mark: match hunter tracking to the target's creature type
---------------------------------------------------------------------------
local typeMap -- creature type name (localized and English) -> Track spell ID
local function TrackSpellForType(ctype)
  if not typeMap then
    typeMap = {}
    for id, spell in pairs(TYPE_TRACK) do
      typeMap[TYPE_EN[id]] = spell
      if C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
        local info = C_CreatureInfo.GetCreatureTypeInfo(id)
        if type(info) == "table" and type(info.name) == "string" then typeMap[info.name] = spell end
      end
    end
  end
  return typeMap[ctype]
end

local function FindHunterTrack(list, spell)
  for _, e in ipairs(list) do
    if e.hunterTrack == spell then return e end
  end
end

-- Queue one matched Track spell. A newer match replaces an older one still waiting.
local function QueueMatch(e, list, combatOK)
  local fresh = not pass
  pass = pass or NewPass()
  pass.deadline = GetTime() + PASS_TIMEOUT
  -- Treat the triggering spell (Hunter's Mark, or the macro's /cast) as just
  -- cast, so the switch never lands on top of it, whatever order the macro uses.
  pass.lastSpell = GetTime()
  if combatOK then pass.combatOK = true end
  for _, o in ipairs(list) do
    if o.hunterTrack and o.key ~= e.key then
      pass.targets[o.key] = nil; pass.report[o.key] = nil; afterCombat[o.key] = nil
    end
  end
  pass.targets[e.key] = true
  pass.tries[e.key] = 0
  pass.report[e.key] = e.name
  afterCombat[e.key] = nil
  if fresh then Step() end
end

-- source: "mark" (automatic, after Hunter's Mark) or "macro" (/ftrack match)
local function Match(unit, source)
  if not db or not IsHunter() then return end
  local label = (source == "mark") and "Mark" or "Macro"
  if UnitIsDeadOrGhost("player") then Debug(label .. ": dead -> skipped"); return end
  if UnitOnTaxi and UnitOnTaxi("player") then Debug(label .. ": on a flight path -> skipped"); return end
  if InPvPInstance() then Debug(label .. ": battleground or arena -> skipped (PvP pause is on)"); return end
  local combat = InCombatLockdown()
  if combat and not (COMBAT_SWITCH_WORKS and db.markCombat) then
    Debug(label .. ": in combat -> skipped (in-combat switching is off)"); return
  end

  local okExists, exists = pcall(UnitExists, unit)
  if not okExists or IsSecret(exists) or not exists then
    Debug(("%s: no %s -> no change"):format(label, unit)); return
  end
  local ctype = UnitCreatureType(unit)
  if IsSecret(ctype) then Debug(label .. ": type hidden by the game -> no change"); return end
  if not ctype then Debug(label .. ": target has no creature type -> no change"); return end

  local spell = TrackSpellForType(ctype)
  if not spell then
    Debug(("%s: %s -> no tracking for this type, no change"):format(label, ctype)); return
  end
  local list = Entries()
  ApplyDefaults(list)
  local e = FindHunterTrack(list, spell)
  if not e then
    Debug(("%s: %s -> %s not known by this character, no change"):format(
      label, ctype, SpellName(spell) or ("spell " .. spell)))
    return
  end
  SetWant(e, true, list)
  if e.active then
    Debug(("%s: %s -> %s already on, no change"):format(label, ctype, e.name)); return
  end
  if pass and pass.targets[e.key] then
    -- e.g. a macro with /cast Hunter's Mark + /ftrack match while auto-matching is on
    Debug(("%s: %s -> already switching to %s"):format(label, ctype, e.name)); return
  end
  Debug(("%s: %s -> switching to %s"):format(label, ctype, e.name))
  -- With in-combat switching on, a switch queued just before the pull may finish in the fight.
  QueueMatch(e, list, combat or (COMBAT_SWITCH_WORKS and db.markCombat))
end

-- Matches cut off by combat (marked, then pulled before the GCD ended)
local function ResumeAfterCombat()
  if not next(afterCombat) or not CanAct() then return end
  local list = Entries()
  for _, e in ipairs(list) do
    if afterCombat[e.key] and db.want[e.key] then
      if e.active then Debug(e.name .. ": ON") else QueueMatch(e, list, false) end
    end
  end
  wipe(afterCombat)
end

local markName
local function IsHuntersMark(spellID)
  if type(spellID) ~= "number" or IsSecret(spellID) then return false end
  if HUNTERS_MARK[spellID] then return true end
  markName = markName or SpellName(1130)
  return markName ~= nil and SpellName(spellID) == markName
end

---------------------------------------------------------------------------
-- /ftrack probe: in-game test of what Forever allows. Prints one summary line
-- (PROBE RESULT ...) for a remote tester to send back.
---------------------------------------------------------------------------
local probe -- { r = results, watching = bool, blocked = bool, started = time }

local blockWatch = CreateFrame("Frame")
pcall(blockWatch.RegisterEvent, blockWatch, "ADDON_ACTION_BLOCKED")
pcall(blockWatch.RegisterEvent, blockWatch, "ADDON_ACTION_FORBIDDEN")
blockWatch:SetScript("OnEvent", function(_, _, addon)
  if probe and probe.watching and addon == ADDON then probe.blocked = true end
end)

-- Try to turn `e` on, then report OK / BLOCKED / NOCHANGE on one line.
local function ProbeAttempt(e, label, field, done)
  probe.blocked, probe.watching = false, true
  local ok = pcall(SetTrackingIndex, e.index, true)
  C_Timer.After(0.3, function()
    probe.watching = false
    local now = false
    for _, o in ipairs(Entries()) do if o.key == e.key then now = o.active end end
    local res = (probe.blocked or not ok) and "BLOCKED" or (now and "OK" or "NOCHANGE")
    probe.r[field] = res
    Print(("%s: %s on: %s"):format(label, e.name, res))
    done()
  end)
end

local function Probe()
  if probe and GetTime() - probe.started < 15 then
    Print("Probe still running. Wait for the PROBE RESULT line."); return
  end
  probe = nil
  local gcd = GCDRemaining()
  if (gcd and gcd > 0) or Casting() then
    Print("PROBE RESULT: BUSY (GCD) - run again"); return
  end

  local r = { combat = InCombatLockdown() and "YES" or "NO", type = "NOTARGET",
              keypress = "SKIPPED", timer = "SKIPPED" }
  probe = { r = r, started = GetTime() }
  Print(("probe | version: %s | in combat: %s"):format(Version(), r.combat))

  -- [1] creature type
  local ctype
  local exists = UnitExists("target")
  if IsSecret(exists) then
    r.type = "SECRET"; Print("[1] target type: hidden by the game (secret)")
  elseif not exists then
    Print("[1] target type: no target")
  else
    ctype = UnitCreatureType("target")
    if IsSecret(ctype) then
      r.type, ctype = "SECRET", nil; Print("[1] target type: hidden by the game (secret)")
    elseif not ctype then
      r.type = "NONE"; Print("[1] target type: none (readable)")
    else
      r.type = "OK"; Print(("[1] target type: %s (readable)"):format(ctype))
    end
  end

  -- Two different hunter Track spells that are off; the target's type first.
  local want = ctype and TrackSpellForType(ctype)
  local off = {}
  for _, e in ipairs(Entries()) do
    if e.hunterTrack and not e.active then
      if e.hunterTrack == want then table.insert(off, 1, e) else off[#off + 1] = e end
    end
  end
  local A, B = off[1], off[2]

  local function finish()
    Print(("PROBE RESULT: combat=%s type=%s keypress=%s timer=%s"):format(
      r.combat, r.type, r.keypress, r.timer))
    probe = nil
  end

  local function timerTest()
    if not B then
      Print("[3] timer: SKIPPED (needs a second hunter Track spell that is off)"); finish(); return
    end
    local waited = false
    local function try()
      local w = GCDRemaining()
      if w == nil then w = waited and 0 or GCD_FALLBACK end
      waited = true
      if w > 0 or Casting() then C_Timer.After(w + 0.1, try); return end
      if r.combat == "YES" and not InCombatLockdown() then r.combat = "ENDED" end
      ProbeAttempt(B, "[3] timer", "timer", finish)
    end
    C_Timer.After(0.1, try)
  end

  -- [2] straight from the key press
  if not A then
    Print("[2] key press: SKIPPED (no hunter Track spell is off)")
    timerTest()
  else
    ProbeAttempt(A, "[2] key press", "keypress", timerTest)
  end
end

---------------------------------------------------------------------------
-- Reminder icon
---------------------------------------------------------------------------
local reminder = CreateFrame("Button", "ForeverTrackReminder", UIParent)
reminder:SetSize(44, 44)
reminder:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
reminder:SetMovable(true)
reminder:EnableMouse(true)
reminder:RegisterForDrag("LeftButton")
reminder:RegisterForClicks("AnyUp")
reminder:SetClampedToScreen(true)
reminder:Hide()

reminder.icon = reminder:CreateTexture(nil, "ARTWORK")
reminder.icon:SetAllPoints()
reminder.icon:SetTexture(134400) -- placeholder; replaced by the tracking's own icon

reminder.text = reminder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reminder.text:SetPoint("TOP", reminder, "BOTTOM", 0, -4)
reminder.text:SetTextColor(1, 0.3, 0.3)

local pulse = reminder:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.35)
fade:SetDuration(0.8)

local function HideReminder() reminder:Hide(); pulse:Stop() end

function UpdateReminder()
  -- pass: still turning trackings on one by one; Step() calls us when done
  if not db or not db.reminder or pass or InCombatLockdown() or UnitIsDeadOrGhost("player")
      or InPvPInstance() then
    HideReminder(); return
  end
  local missing = Missing()
  if #missing == 0 then HideReminder(); return end

  if missing[1].texture then reminder.icon:SetTexture(missing[1].texture) end
  if #missing == 1 then
    reminder.text:SetText(missing[1].name .. " off")
  else
    reminder.text:SetText(("%s + %d more off"):format(missing[1].name, #missing - 1))
  end
  reminder.missing = missing
  reminder:Show()
  if not pulse:IsPlaying() then pulse:Play() end
end

reminder:SetScript("OnDragStart", function(self)
  if IsShiftKeyDown() then self:StartMoving() end
end)
reminder:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db.point = { p, rp, x, y }
end)
reminder:SetScript("OnClick", function()
  if InCombatLockdown() then return end
  EnableAllWanted()
end)
reminder:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("ForeverTrack")
  for _, e in ipairs(self.missing or {}) do
    GameTooltip:AddLine("|T" .. (e.texture or 134400) .. ":14|t " .. e.name .. " is off", 1, 0.5, 0.5)
  end
  GameTooltip:AddLine("Click to turn them back on.", 1, 1, 1)
  GameTooltip:AddLine("Shift-drag to move. /ftrack for options.", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
reminder:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Options panel (Esc > Options > AddOns > ForeverTrack)
---------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "ForeverTrack"
panel.rows = {}
local settingsCategory

local function MakeCheck(parent, label, tooltip, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.label:SetText(label)
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  if tooltip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(tooltip, 1, 1, 1, true); GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return cb
end

local function BuildPanel()
  if panel.built then return end
  panel.built = true

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ForeverTrack")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetText("Ticked trackings are turned back on at login, after zoning and after death. "
    .. "Settings are saved per character. Only trackings this character has are listed.")

  panel.auto = MakeCheck(panel, "Turn tracking on automatically",
    "Off = reminder only. ForeverTrack never changes tracking in combat.",
    function(v) db.auto = v end)
  panel.auto:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -10)

  panel.rem = MakeCheck(panel, "Show reminder icon when a ticked tracking is off",
    nil, function(v) db.reminder = v; UpdateReminder() end)
  panel.rem:SetPoint("TOPLEFT", panel.auto, "BOTTOMLEFT", 0, -2)

  panel.pvp = MakeCheck(panel, "Pause in battlegrounds and arenas",
    "No tracking changes and no reminder while you're in a battleground or arena.",
    function(v) db.pausePvP = v; UpdateReminder() end)
  panel.pvp:SetPoint("TOPLEFT", panel.rem, "BOTTOMLEFT", 0, -2)

  -- Hunters only (shown in RefreshPanel)
  panel.mark = MakeCheck(panel, "Match tracking to Hunter's Mark target",
    "When you cast Hunter's Mark, switch your hunter tracking to the target's type "
    .. "(Beast, Humanoid, ...). Nothing happens, and no extra GCD, if it's already on. "
    .. "Out of combat only. For a macro, put /ftrack match after any spell.",
    function(v) db.markMatch = v end)
  panel.mark:SetPoint("TOPLEFT", panel.pvp, "BOTTOMLEFT", 0, -2)
  if COMBAT_SWITCH_WORKS then
    panel.markCombat = MakeCheck(panel, "Also switch in combat",
      "Lets Hunter's Mark and /ftrack match switch tracking during a fight.",
      function(v) db.markCombat = v end)
    panel.markCombat:SetPoint("TOPLEFT", panel.mark, "BOTTOMLEFT", 0, -2)
  end

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  header:SetPoint("TOPLEFT", panel.pvp, "BOTTOMLEFT", 2, -14)
  header:SetText("Keep these on:")
  panel.header = header

  -- The tracking list can be longer than the panel, so it lives in a scroll frame.
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -6)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  scroll:HookScript("OnSizeChanged", function(_, w) content:SetWidth(w or 1) end)
  panel.scroll, panel.list = scroll, content
end

local function RefreshPanel()
  if not db then return end
  BuildPanel()
  panel.auto:SetChecked(db.auto)
  panel.rem:SetChecked(db.reminder)
  panel.pvp:SetChecked(db.pausePvP)

  local hunter = IsHunter()
  local last = panel.pvp
  panel.mark:SetShown(hunter)
  panel.mark:SetChecked(db.markMatch)
  if hunter then last = panel.mark end
  if panel.markCombat then
    panel.markCombat:SetShown(hunter)
    panel.markCombat:SetChecked(db.markCombat)
    if hunter then last = panel.markCombat end
  end
  panel.header:ClearAllPoints()
  panel.header:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -14)

  local list = Entries()
  ApplyDefaults(list)
  for _, row in ipairs(panel.rows) do row:Hide() end

  local ROW_H = 26
  local anchor, lastWasSpell, height = nil, true, 0
  for i, e in ipairs(list) do
    local row = panel.rows[i]
    if not row then
      row = MakeCheck(panel.list, "", nil, function() end)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", row, "RIGHT", 4, 0)
      row.label:ClearAllPoints()
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      panel.rows[i] = row
    end
    local gap = (lastWasSpell and not e.isSpell) and 12 or 2
    lastWasSpell = e.isSpell
    row:ClearAllPoints()
    if anchor then
      row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
      height = height + gap + ROW_H
    else
      row:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, 0)
      height = ROW_H
    end
    row.icon:SetTexture(e.texture or 134400)
    row.label:SetText(e.name .. (e.active and "  |cff33ff33(on)|r" or "  |cff999999(off)|r"))
    row:SetChecked(db.want[e.key] and true or false)
    row:SetScript("OnClick", function(self)
      SetWant(e, self:GetChecked(), list)
      if db.want[e.key] then EnableWanted(e.key) end
      C_Timer.After(0.3, function() if panel:IsVisible() then RefreshPanel() end UpdateReminder() end)
    end)
    row:Show()
    anchor = row
  end
  panel.list:SetWidth(math.max(1, panel.scroll:GetWidth() or 1))
  panel.list:SetHeight(math.max(1, height))
end

panel:SetScript("OnShow", RefreshPanel)

local function RegisterPanel()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

local function OpenPanel()
  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Auto re-enable only on "tracking got reset" moments (login, zoning, death).
-- If you switch one off by hand mid-session, it stays off and the reminder shows.
local function Refresh()
  local list = Entries()
  ApplyDefaults(list)
  MigrateHunterGroup(list)
  if db.auto then EnableAllWanted() end
  UpdateReminder()
end

-- v1.0 saved { want = { minerals = bool, treasure = bool } }
local function Migrate(saved)
  local w = saved.want
  if type(w) ~= "table" then saved.want = {}; return end
  if w.minerals ~= nil then w["spell:2580"] = w.minerals; w.minerals = nil end
  if w.treasure ~= nil then w["spell:2481"] = w.treasure; w.treasure = nil end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_ALIVE")
ev:RegisterEvent("PLAYER_UNGHOST")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("MINIMAP_UPDATE_TRACKING")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

-- Event names differ between clients, and registering an unknown one raises an
-- error that would stop the rest of this file loading. Register these carefully.
local function TryRegister(name)
  if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(name) then return end
  pcall(ev.RegisterEvent, ev, name)
end
TryRegister("LEARNED_SPELL_IN_SKILL_LINE") -- modern client
TryRegister("LEARNED_SPELL_IN_TAB")        -- older clients
if ev.RegisterUnitEvent then
  pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
else
  TryRegister("UNIT_SPELLCAST_SUCCEEDED")
end

ev:SetScript("OnEvent", function(_, event, arg1, _, arg3)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    ForeverTrackDB = ForeverTrackDB or {}
    Migrate(ForeverTrackDB)
    for k, v in pairs(DEFAULTS) do
      if ForeverTrackDB[k] == nil then
        ForeverTrackDB[k] = (type(v) == "table") and {} or v
      end
    end
    db = ForeverTrackDB
    if db.point then
      reminder:ClearAllPoints()
      reminder:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    RegisterPanel()
    return
  end
  if not db then return end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- arg1 = unit, arg3 = spell ID
    if arg1 == "player" and db.markMatch and IsHunter() and IsHuntersMark(arg3) then
      Match("target", "mark")
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    HideReminder()
  elseif event == "MINIMAP_UPDATE_TRACKING" or event == "PLAYER_REGEN_ENABLED" then
    UpdateReminder()
    if panel:IsVisible() then RefreshPanel() end
    if event == "PLAYER_REGEN_ENABLED" then C_Timer.After(0.5, ResumeAfterCombat) end
  elseif event == "UPDATE_SHAPESHIFT_FORM" then
    -- e.g. druid Track Humanoids only exists in Cat Form; just refresh the icon
    C_Timer.After(0.5, UpdateReminder)
  else
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 3 or 1, Refresh)
  end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function List()
  local list = Entries()
  ApplyDefaults(list)
  if #list == 0 then Print("No trackings available on this character.") return end
  for i, e in ipairs(list) do
    Print(("%d. |T%s:14|t %s - %s%s"):format(i, tostring(e.texture or 134400), e.name,
      e.active and "|cff33ff33ON|r" or "|cff999999off|r",
      db.want[e.key] and " |cffffd200(kept on)|r" or ""))
  end
  Print(("auto=%s, reminder=%s. /ftrack toggle <number or name>"):format(
    tostring(db.auto), tostring(db.reminder)))
end

local function Toggle(arg)
  local list = Entries()
  ApplyDefaults(list)
  local n = tonumber(arg)
  local hit = n and list[n]
  if not hit and arg ~= "" then
    for _, e in ipairs(list) do
      if e.name:lower():find(arg, 1, true) then hit = e; break end
    end
  end
  if not hit then Print("No tracking matches '" .. arg .. "'. Try /ftrack list.") return end
  SetWant(hit, not db.want[hit.key], list)
  Print(hit.name .. (db.want[hit.key] and " will be kept on." or " is no longer managed."))
end

SLASH_FOREVERTRACK1 = "/ftrack"
SLASH_FOREVERTRACK2 = "/forevertrack"
SlashCmdList.FOREVERTRACK = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  cmd, arg = cmd:lower(), arg:lower()
  if cmd == "" or cmd == "config" or cmd == "options" then
    OpenPanel(); return
  elseif cmd == "list" or cmd == "status" then
    List(); return
  elseif cmd == "toggle" or cmd == "t" then
    Toggle(arg)
  elseif cmd == "minerals" then
    Toggle("find minerals")
  elseif cmd == "treasure" then
    Toggle("find treasure")
  elseif cmd == "auto" then
    db.auto = not db.auto
    Print("auto-enable " .. (db.auto and "on" or "off"))
  elseif cmd == "reminder" then
    db.reminder = not db.reminder
    Print("reminder " .. (db.reminder and "on" or "off"))
  elseif cmd == "pvp" then
    db.pausePvP = not db.pausePvP
    Print("pause in battlegrounds and arenas " .. (db.pausePvP and "on" or "off"))
    UpdateReminder()
    return
  elseif cmd == "match" then
    Match(arg ~= "" and arg or "target", "macro")
    return
  elseif cmd == "mark" then
    db.markMatch = not db.markMatch
    Print("Hunter's Mark matching: " .. (db.markMatch and "ON" or "OFF"))
    return
  elseif cmd == "markcombat" and COMBAT_SWITCH_WORKS then
    db.markCombat = not db.markCombat
    Print("In-combat switching: " .. (db.markCombat and "ON" or "OFF"))
    return
  elseif cmd == "debug" then
    db.debug = not db.debug
    Print("Debug messages: " .. (db.debug and "ON" or "OFF"))
    return
  elseif cmd == "probe" then
    Probe()
    return
  elseif cmd == "on" then
    -- fall through
  else
    Print("/ftrack (options) | list | toggle <n|name> | on | auto | reminder | pvp"
      .. " | match [unit] | mark | debug | probe")
    return
  end
  EnableAllWanted()
  UpdateReminder()
end
