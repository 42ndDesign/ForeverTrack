# Forever Auras / Musca Auras reminder: "Tracking is off"

A fallback if you'd rather not run the addon, or use it as reminder-only (`/ftrack auto` off).
It shows an icon when **Find Minerals or Find Treasure** is off. Spells your character
doesn't have are ignored.

## Setup (/wa)

1. **New** → **Icon**.
2. **Trigger** tab:
   - Type: **Custom**
   - Event Type: **Status**
   - Check On: **Event(s)**
   - Events: `MINIMAP_UPDATE_TRACKING PLAYER_ENTERING_WORLD PLAYER_ALIVE PLAYER_UNGHOST PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED`
   - **Custom Trigger:**

```lua
function()
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then return false end
  local want = { [2580] = true, [2481] = true } -- Find Minerals, Find Treasure
  local num = C_Minimap and C_Minimap.GetNumTrackingTypes or GetNumTrackingTypes
  local get = C_Minimap and C_Minimap.GetTrackingInfo or GetTrackingInfo
  for i = 1, (num() or 0) do
    local a, tex, active, _, _, spellID = get(i)
    if type(a) == "table" then tex, active, spellID = a.texture, a.active, a.spellID end
    if spellID and want[spellID] and not active then
      aura_env.icon = tex
      return true -- a wanted tracking is off: show
    end
  end
  return false
end
```

   - Hide: **Custom**
   - **Custom Untrigger:**

```lua
function()
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then return true end
  local want = { [2580] = true, [2481] = true }
  local num = C_Minimap and C_Minimap.GetNumTrackingTypes or GetNumTrackingTypes
  local get = C_Minimap and C_Minimap.GetTrackingInfo or GetTrackingInfo
  for i = 1, (num() or 0) do
    local a, _, active, _, _, spellID = get(i)
    if type(a) == "table" then active, spellID = a.active, a.spellID end
    if spellID and want[spellID] and not active then return false end
  end
  return true
end
```

   - **Icon Info** (optional, so the icon shows whichever one is off):

```lua
function() return aura_env.icon end
```

3. Optional: **Animations** tab → Main → Preset "Pulse"; **Actions** tab → On Show → play a sound.

To watch only Find Minerals, remove `[2481] = true` from both `want` tables.
