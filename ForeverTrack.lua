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

local DEFAULTS = {
  want = {},         -- [key] = true/false, key = "spell:<id>" or "name:<name>"
  auto = true,       -- re-enable at login, zoning, and after death
  reminder = true,   -- show the "tracking is off" icon
  point = nil,       -- saved reminder position
}

local db

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
-- Every entry in the tracking menu: { index, key, name, texture, active, isSpell, spellID }
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

local function CanAct()
  if InCombatLockdown() then return false end
  if UnitIsDeadOrGhost("player") then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  return true
end

local function Missing()
  local out = {}
  for _, e in ipairs(Entries()) do
    if db.want[e.key] and not e.active then out[#out + 1] = e end
  end
  return out
end

local function EnableAllWanted()
  if not CanAct() then return end
  local list = Entries()
  ApplyDefaults(list)
  for _, e in ipairs(list) do
    if db.want[e.key] and not e.active then
      SetTrackingIndex(e.index, true)
    end
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

local function UpdateReminder()
  if not db or not db.reminder or InCombatLockdown() or UnitIsDeadOrGhost("player") then
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

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  header:SetPoint("TOPLEFT", panel.rem, "BOTTOMLEFT", 2, -14)
  header:SetText("Keep these on:")
  panel.header = header
end

local function RefreshPanel()
  if not db then return end
  BuildPanel()
  panel.auto:SetChecked(db.auto)
  panel.rem:SetChecked(db.reminder)

  local list = Entries()
  ApplyDefaults(list)
  for _, row in ipairs(panel.rows) do row:Hide() end

  local anchor, lastWasSpell = panel.header, true
  for i, e in ipairs(list) do
    local row = panel.rows[i]
    if not row then
      row = MakeCheck(panel, "", nil, function() end)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", row, "RIGHT", 4, 0)
      row.label:ClearAllPoints()
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      panel.rows[i] = row
    end
    local gap = (lastWasSpell and not e.isSpell) and -12 or -2
    lastWasSpell = e.isSpell
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i == 1) and -2 or 0, (i == 1) and -6 or gap)
    row.icon:SetTexture(e.texture or 134400)
    row.label:SetText(e.name .. (e.active and "  |cff33ff33(on)|r" or "  |cff999999(off)|r"))
    row:SetChecked(db.want[e.key] and true or false)
    row:SetScript("OnClick", function(self)
      db.want[e.key] = self:GetChecked() and true or false
      if db.want[e.key] and CanAct() then SetTrackingIndex(e.index, true) end
      C_Timer.After(0.3, function() if panel:IsVisible() then RefreshPanel() end UpdateReminder() end)
    end)
    row:Show()
    anchor = row
  end
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
  ApplyDefaults(Entries())
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
ev:RegisterEvent("LEARNED_SPELL_IN_TAB")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

ev:SetScript("OnEvent", function(_, event, arg1)
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

  if event == "PLAYER_REGEN_DISABLED" then
    HideReminder()
  elseif event == "MINIMAP_UPDATE_TRACKING" or event == "PLAYER_REGEN_ENABLED" then
    UpdateReminder()
    if panel:IsVisible() then RefreshPanel() end
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
local function Print(msg) print("|cff33ff99ForeverTrack|r: " .. msg) end

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
  db.want[hit.key] = not db.want[hit.key]
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
  elseif cmd == "on" then
    -- fall through
  else
    Print("/ftrack (options) | list | toggle <n|name> | on | auto | reminder")
    return
  end
  EnableAllWanted()
  UpdateReminder()
end
