local coordsCache = {}  -- coordsCache[src] = vector3(...)
local stateCache  = {}  -- stateCache[identifier] = {status, untilTs, mask, gel}

local function now() return os.time() end
local function rand(a,b) return math.random(a,b) end

local function isAdmin(xPlayer)
  if not xPlayer then return false end
  local g = xPlayer.getGroup()
  for _,allowed in ipairs(Config.AdminGroups) do
    if g == allowed then return true end
  end
  return false
end

local function getIdentifier(src)
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return nil end
  return xPlayer.getIdentifier()
end

local function loadState(identifier, cb)
  MySQL.single('SELECT * FROM infection_state WHERE identifier = ?', {identifier}, function(row)
    if row then
      stateCache[identifier] = {
        status  = row.status or 'healthy',
        untilTs = tonumber(row.until_ts) or 0,
        mask    = row.mask == 1,
        gel     = row.gel == 1
      }
    else
      stateCache[identifier] = { status='healthy', untilTs=0, mask=false, gel=false }
      MySQL.insert('INSERT INTO infection_state (identifier,status,until_ts,mask,gel) VALUES (?,?,?,?,?)',
        {identifier,'healthy',0,0,0})
    end
    cb(stateCache[identifier])
  end)
end

local function saveState(identifier)
  local st = stateCache[identifier]
  if not st then return end
  MySQL.update('UPDATE infection_state SET status=?, until_ts=?, mask=?, gel=? WHERE identifier=?',
    {st.status, st.untilTs or 0, st.mask and 1 or 0, st.gel and 1 or 0, identifier})
end

local function syncToClient(src, identifier)
  local st = stateCache[identifier]
  if not st then return end
  TriggerClientEvent('esx_infection:setStatus', src, st.status, st.untilTs)
  TriggerClientEvent('esx_infection:setProtection', src, st.mask, st.gel)
end

local function setStatusByIdentifier(identifier, status, duration)
  local st = stateCache[identifier]
  if not st then return end
  st.status = status
  st.untilTs = duration and (now() + duration) or 0
  saveState(identifier)

  -- sync si le joueur est en ligne
  for _,src in ipairs(GetPlayers()) do
    src = tonumber(src)
    local id = getIdentifier(src)
    if id == identifier then
      syncToClient(src, identifier)
      break
    end
  end
end

-- ====== Connexion joueur ======
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
  local identifier = xPlayer.getIdentifier()
  loadState(identifier, function()
    syncToClient(playerId, identifier)
  end)
end)

AddEventHandler('playerDropped', function()
  local src = source
  coordsCache[src] = nil
end)

-- ====== Coords report ======
RegisterNetEvent('esx_infection:reportCoords', function(x,y,z)
  local src = source
  coordsCache[src] = vector3(x,y,z)
end)

-- ====== Protections via items / events ======
local function setProtection(src, mask, gel)
  local identifier = getIdentifier(src)
  if not identifier then return end
  if not stateCache[identifier] then
    loadState(identifier, function()
      setProtection(src, mask, gel)
    end)
    return
  end
  local st = stateCache[identifier]
  st.mask = mask == true
  st.gel  = gel == true
  saveState(identifier)
  TriggerClientEvent('esx_infection:setProtection', src, st.mask, st.gel)
end

ESX.RegisterUsableItem(Config.Items.mask, function(src)
  local identifier = getIdentifier(src); if not identifier then return end
  local st = stateCache[identifier]
  if not st then return end

  st.mask = not st.mask
  saveState(identifier)
  TriggerClientEvent('esx_infection:setProtection', src, st.mask, st.gel)
  TriggerClientEvent('esx:showNotification', src, st.mask and 'Masque ~g~mis~s~.' or 'Masque ~y~retiré~s~.')
end)

ESX.RegisterUsableItem(Config.Items.gel, function(src)
  local identifier = getIdentifier(src); if not identifier then return end
  local st = stateCache[identifier]
  if not st then return end

  -- Gel = buff “actif” quelques minutes (au lieu d’un toggle permanent)
  st.gel = true
  saveState(identifier)
  TriggerClientEvent('esx_infection:setProtection', src, st.mask, st.gel)
  TriggerClientEvent('esx:showNotification', src, 'Gel ~g~utilisé~s~ (protection temporaire).')

  SetTimeout(5 * 60 * 1000, function()
    -- si le joueur s’est déco/reco, on coupe quand même au niveau BDD
    if stateCache[identifier] then
      stateCache[identifier].gel = false
      saveState(identifier)
    end
    for _,p in ipairs(GetPlayers()) do
      p = tonumber(p)
      if getIdentifier(p) == identifier then
        TriggerClientEvent('esx_infection:setProtection', p, stateCache[identifier].mask, false)
        TriggerClientEvent('esx:showNotification', p, 'Effet du gel ~y~terminé~s~.')
        break
      end
    end
  end)
end)

-- ====== Evolution maladie ======
local function tickStateMachine()
  if not Config.Enabled then return end

  for _,src in ipairs(GetPlayers()) do
    src = tonumber(src)
    local identifier = getIdentifier(src)
    if identifier then
      if not stateCache[identifier] then
        loadState(identifier, function() end)
      else
        local st = stateCache[identifier]
        if st.status == 'incubating' and st.untilTs > 0 and now() >= st.untilTs then
          setStatusByIdentifier(identifier, 'sick', rand(Config.SickDurationMin, Config.SickDurationMax))
          TriggerClientEvent('esx:showNotification', src, '~r~Tu es malade.')
        elseif st.status == 'sick' and st.untilTs > 0 and now() >= st.untilTs then
          setStatusByIdentifier(identifier, 'immune', Config.ImmunitySeconds)
          TriggerClientEvent('esx:showNotification', src, '~g~Tu es guéri (immunité temporaire).')
        elseif st.status == 'immune' and st.untilTs > 0 and now() >= st.untilTs then
          setStatusByIdentifier(identifier, 'healthy', nil)
          TriggerClientEvent('esx:showNotification', src, '~b~Tu es en bonne santé.')
        end
      end
    end
  end
end

-- ====== Propagation ======
local function dist(a,b)
  local dx=a.x-b.x; local dy=a.y-b.y; local dz=a.z-b.z
  return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function trySpread()
  if not Config.Enabled then return end

  local players = {}
  for _,src in ipairs(GetPlayers()) do
    src = tonumber(src)
    local identifier = getIdentifier(src)
    if identifier and coordsCache[src] then
      players[#players+1] = { src=src, id=identifier, pos=coordsCache[src] }
    end
  end

  for _,inf in ipairs(players) do
    local stInf = stateCache[inf.id]
    if stInf and stInf.status == 'sick' then
      local infectedCount = 0

      for _,target in ipairs(players) do
        if infectedCount >= Config.MaxInfectPerTick then break end
        if target.src ~= inf.src then
          local stT = stateCache[target.id]
          if stT and stT.status == 'healthy' then
            if dist(inf.pos, target.pos) <= Config.SpreadRadius then
              local chance = Config.BaseInfectChance
              if stT.mask then chance = chance * (1.0 - Config.MaskReduction) end
              if stT.gel  then chance = chance * (1.0 - Config.GelReduction) end

              if math.random() < chance then
                setStatusByIdentifier(target.id, 'incubating', rand(Config.IncubationMin, Config.IncubationMax))
                TriggerClientEvent('esx:showNotification', target.src, '~y~Tu te sens bizarre... (incubation)')
                infectedCount = infectedCount + 1
              end
            end
          end
        end
      end
    end
  end
end

-- Tick principal
CreateThread(function()
  math.randomseed(GetGameTimer())
  while true do
    Wait(Config.TickSeconds * 1000)
    tickStateMachine()
    trySpread()
  end
end)

-- ====== Commandes admin ======
RegisterCommand(Config.Commands.start, function(src)
  if src ~= 0 then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAdmin(xPlayer) then return end
  end
  Config.Enabled = true
  if src ~= 0 then TriggerClientEvent('esx:showNotification', src, 'Infection ~g~activée~s~.') end
end)

RegisterCommand(Config.Commands.stop, function(src)
  if src ~= 0 then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAdmin(xPlayer) then return end
  end
  Config.Enabled = false
  if src ~= 0 then TriggerClientEvent('esx:showNotification', src, 'Infection ~r~désactivée~s~.') end
end)

RegisterCommand(Config.Commands.cure, function(src, args)
  local xPlayer = ESX.GetPlayerFromId(src)
  if not isAdmin(xPlayer) then return end
  local target = tonumber(args[1]) or src
  local id = getIdentifier(target); if not id then return end
  setStatusByIdentifier(id, 'immune', Config.ImmunitySeconds)
  TriggerClientEvent('esx:showNotification', target, '~g~Soins effectués (immunité).')
end)

RegisterCommand(Config.Commands.infect, function(src, args)
  local xPlayer = ESX.GetPlayerFromId(src)
  if not isAdmin(xPlayer) then return end
  local target = tonumber(args[1])
  if not target then return end
  local id = getIdentifier(target); if not id then return end
  setStatusByIdentifier(id, 'incubating', rand(Config.IncubationMin, Config.IncubationMax))
  TriggerClientEvent('esx:showNotification', target, '~y~Tu te sens bizarre... (incubation)')
end)

RegisterCommand(Config.Commands.info, function(src)
  local identifier = getIdentifier(src); if not identifier then return end
  local st = stateCache[identifier]; if not st then return end
  TriggerClientEvent('esx:showNotification', src,
    ('Etat: %s | fin: %s | masque: %s | gel: %s'):format(st.status, tostring(st.untilTs), tostring(st.mask), tostring(st.gel))
  )
end)