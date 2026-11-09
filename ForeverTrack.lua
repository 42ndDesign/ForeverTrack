-- ForeverTrack: keep Find Minerals and Find Treasure on at the same time
-- (WoW Forever allows multiple trackings, like retail), and show a clickable
-- reminder when one you want is off. All changes happen OUT of combat only.

local ADDON = ...

local SPELLS = {
  minerals = 2580, -- Find Minerals (Mining)
  treasure = 2481, -- Find Treasure (Dwarf racial)
}
local FALLBACK_NAMES = {
  minerals = "Find Minerals",
  treasure = "Find Treasure",
}
local ORDER = { "minerals", "treasure" }

local DEFAULTS = {
  want = { minerals = true, treasure = true },
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

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(id)
  elseif GetSpellInfo then
    return (GetSpellInfo(id))
  end
end

local function IsSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function Label(key)
  return SpellName(SPELLS[key]) or FALLBACK_NAMES[key]
end

---------------------------------------------------------------------------
-- Tracking helpers
---------------------------------------------------------------------------
-- Find the tracking-menu entry for "minerals"/"treasure". Returns index, active, texture.
local function Find(key)
  local wantID, wantName = SPELLS[key], Label(key)
  for i = 1, NumTrackingTypes() do
    local name, texture, active, _, _, spellID = TrackingInfo(i)
    if not IsSecret(name) and not IsSecret(active) then
      if (spellID and spellID == wantID) or (name and name == wantName) then
        return i, active and true or false, texture
      end
    end
  end
end

local function CanAct()
  if InCombatLockdown() then return false end
  if UnitIsDeadOrGhost("player") then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  return true
end

local function Enable(key)
  local idx, active = Find(key)
  if idx and not active then
    SetTrackingIndex(idx, true)
    return true
  end
  return false
end

-- Wanted trackings this character knows but has switched off
local function Missing()
  local list = {}
  for _, key in ipairs(ORDER) do
    if db.want[key] then
      local idx, active, tex = Find(key)
      if idx and not active then
        list[#list + 1] = { key = key, tex = tex }
      end
    end
  end
  return list
end

local function EnableAllWanted()
  if not CanAct() then return end
  for _, key in ipairs(ORDER) do
    if db.want[key] then Enable(key) end
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
reminder.icon:SetTexture(134400) -- placeholder; replaced by the tracking spell's own icon

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

  local names = {}
  for _, m in ipairs(missing) do names[#names + 1] = Label(m.key) end
  if missing[1].tex then reminder.icon:SetTexture(missing[1].tex) end
  reminder.text:SetText(table.concat(names, " + ") .. " off")
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
  GameTooltip:AddLine("Click to turn your tracking back on.", 1, 1, 1)
  GameTooltip:AddLine("Shift-drag to move. /ftrack for options.", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
reminder:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Auto re-enable only on "tracking got reset" moments (login, zoning, death).
-- If you switch one off by hand mid-session, it stays off and the reminder shows.
local function Refresh()
  if db.auto then EnableAllWanted() end
  UpdateReminder()
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

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    ForeverTrackDB = ForeverTrackDB or {}
    for k, v in pairs(DEFAULTS) do
      if ForeverTrackDB[k] == nil then
        ForeverTrackDB[k] = (type(v) == "table") and CopyTable and CopyTable(v) or v
      end
    end
    if type(ForeverTrackDB.want) ~= "table" then
      ForeverTrackDB.want = { minerals = true, treasure = true }
    end
    db = ForeverTrackDB
    if db.point then
      reminder:ClearAllPoints()
      reminder:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    return
  end
  if not db then return end

  if event == "PLAYER_REGEN_DISABLED" then
    HideReminder()
  elseif event == "MINIMAP_UPDATE_TRACKING" or event == "PLAYER_REGEN_ENABLED" then
    UpdateReminder()
  else
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 3 or 1, Refresh)
  end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Print(msg) print("|cff33ff99ForeverTrack|r: " .. msg) end

local function Status()
  local parts = {}
  for _, key in ipairs(ORDER) do
    local idx, active = Find(key)
    local state = not idx and "not known" or (active and "ON" or "off")
    parts[#parts + 1] = ("%s: %s%s"):format(Label(key), state, db.want[key] and "" or " (not managed)")
  end
  Print(table.concat(parts, " | "))
  Print(("auto=%s, reminder=%s"):format(tostring(db.auto), tostring(db.reminder)))
end

SLASH_FOREVERTRACK1 = "/ftrack"
SLASH_FOREVERTRACK2 = "/forevertrack"
SlashCmdList.FOREVERTRACK = function(msg)
  local cmd = (msg or ""):lower():match("^(%S*)")
  if cmd == "minerals" or cmd == "treasure" then
    db.want[cmd] = not db.want[cmd]
    Print(Label(cmd) .. (db.want[cmd] and " will be kept on." or " is no longer managed."))
  elseif cmd == "auto" then
    db.auto = not db.auto
  elseif cmd == "reminder" then
    db.reminder = not db.reminder
  elseif cmd == "on" then
    -- fall through to EnableAllWanted below
  elseif cmd == "status" or cmd == "" then
    Status(); return
  else
    Print("/ftrack on | minerals | treasure | auto | reminder | status")
    return
  end
  EnableAllWanted()
  UpdateReminder()
  Status()
end
