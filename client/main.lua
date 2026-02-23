local status = 'healthy'
local untilTs = 0
local mask = false
local gel  = false
local originalMask = nil
local contagiousZones = {}
local zoneMenuOpen = false
local zoneMenuIndex = 1
local zoneNewRadius = Config.ZoneDefaultRadius or 6.0
local zoneNewLethalSeconds = Config.ZoneDefaultLethalSeconds or 25
local zoneSmokeFx = {}
local wasIncapacitated = false

local function isFreemodePed(ped)
  local model = GetEntityModel(ped)
  return model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
end

local function applySurgicalMask(ped)
  local model = GetEntityModel(ped)
  local candidates = Config.SurgicalMaskDrawables and Config.SurgicalMaskDrawables[model]
  if not candidates or #candidates == 0 then return false end

  local maxDrawables = GetNumberOfPedDrawableVariations(ped, 1)
  if maxDrawables <= 0 then return false end

  if not originalMask then
    originalMask = {
      drawable = GetPedDrawableVariation(ped, 1),
      texture = GetPedTextureVariation(ped, 1)
    }
  end

  for _, drawable in ipairs(candidates) do
    if drawable >= 0 and drawable < maxDrawables then
      SetPedComponentVariation(ped, 1, drawable, Config.SurgicalMaskTexture or 0, 0)
      return true
    end
  end

  return false
end

local function removeSurgicalMask(ped)
  if originalMask then
    SetPedComponentVariation(ped, 1, originalMask.drawable, originalMask.texture, 0)
    originalMask = nil
  end
end

local function getInfectionLevel()
  if status == 'severe' then return 4 end
  if status == 'sick' then return 3 end
  if status == 'sick_light' then return 2 end
  if status == 'incubating' then return 1 end
  if status == 'immune' then return 0 end
  return 0
end

local function getInfectionLabel(level)
  if level == 1 then
    return '~y~Niveau 1: incubation (non contagieux)~s~'
  elseif level == 2 then
    return '~o~Niveau 2: légèrement malade (contagieux)~s~'
  elseif level == 3 then
    return '~o~Niveau 3: malade (contagieux)~s~'
  elseif level == 4 then
    return '~r~Niveau 4: gravement malade (mort en 10 min)~s~'
  end
  return '~g~Niveau 0: sain/immunisé~s~'
end

local function drawTopRightText(text, x, y, scale)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextScale(scale, scale)
  SetTextColour(255, 255, 255, 220)
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextEdge(1, 0, 0, 0, 205)
  SetTextDropShadow()
  SetTextOutline()
  SetTextRightJustify(true)
  SetTextWrap(0.0, x)
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('esx_infection:setStatus', function(s, u)
  status = s
  untilTs = u or 0
end)

RegisterNetEvent('esx_infection:setProtection', function(m, g)
  mask = m == true
  gel  = g == true

  local ped = PlayerPedId()
  if isFreemodePed(ped) then
    if mask then
      applySurgicalMask(ped)
    else
      removeSurgicalMask(ped)
    end
  end
end)

RegisterNetEvent('esx_infection:killPlayer', function()
  local ped = PlayerPedId()
  SetEntityHealth(ped, 0)
end)

RegisterNetEvent('esx_infection:setZones', function(zones)
  contagiousZones = zones or {}
end)

RegisterNetEvent('esx_infection:openZoneMenu', function()
  zoneMenuOpen = true
  zoneMenuIndex = 1
end)

local function drawZoneMenuLine(label, y, selected)
  local prefix = selected and '~g~>~s~ ' or '  '
  SetTextFont(4)
  SetTextScale(0.32, 0.32)
  SetTextColour(255, 255, 255, 230)
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(prefix .. label)
  EndTextCommandDisplayText(0.03, y)
end

local function drawZoneMenuHelp()
  SetTextFont(4)
  SetTextScale(0.3, 0.3)
  SetTextColour(180, 255, 180, 230)
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName('Menu zones contagieuses (~INPUT_FRONTEND_UP~/~INPUT_FRONTEND_DOWN~, ~INPUT_FRONTEND_ACCEPT~, ~INPUT_FRONTEND_CANCEL~)')
  EndTextCommandDisplayText(0.03, 0.18)
end

local function stopZoneSmoke(idx)
  if zoneSmokeFx[idx] and zoneSmokeFx[idx].handles then
    for _, handle in ipairs(zoneSmokeFx[idx].handles) do
      if handle and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, false)
      end
    end
  end
  zoneSmokeFx[idx] = nil
end

local function drawContagiousZones()
  local ped = PlayerPedId()
  local pcoords = GetEntityCoords(ped)

  for i, zone in ipairs(contagiousZones) do
    local pos = vector3(zone.x + 0.0, zone.y + 0.0, zone.z + 0.0)
    local distance = #(pcoords - pos)

    if distance <= (Config.ZoneMarkerDistance or 100.0) then
      local pulse = (math.sin(GetGameTimer() / 300.0) + 1.0) * 0.5
      local markerG = math.floor(200 + (55 * pulse))
      local markerA = math.floor(120 + (60 * pulse))

      -- Anneau visible autour de la zone contagieuse
      DrawMarker(28, zone.x, zone.y, zone.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        zone.radius * 2.0, zone.radius * 2.0, 2.0,
        20, markerG, 20, markerA, false, false, 2, false, nil, nil, false)

      -- Léger remplissage pour mieux repérer la zone de loin
      DrawMarker(1, zone.x, zone.y, zone.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        zone.radius * 2.0, zone.radius * 2.0, 1.2,
        20, markerG, 20, 80, false, false, 2, false, nil, nil, false)
    end

    if distance <= (Config.ZoneParticleDistance or 60.0) then
      local hasSmoke = zoneSmokeFx[i] and zoneSmokeFx[i].handles and #zoneSmokeFx[i].handles > 0
      if hasSmoke then
        hasSmoke = false
        for _, handle in ipairs(zoneSmokeFx[i].handles) do
          if handle and DoesParticleFxLoopedExist(handle) then
            hasSmoke = true
            break
          end
        end
      end

      if not hasSmoke then
        stopZoneSmoke(i)
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
        local smokeScale = math.max(1.0, (zone.radius / 3.6) * (Config.ZoneSmokeScaleMultiplier or 1.15))
        local smokeHeight = zone.z + (Config.ZoneSmokeVerticalOffset or 0.25)
        local smokeColors = Config.ZoneSmokeColors or {
          { r = 0.15, g = 1.0, b = 0.20 }
        }

        local handles = {}
        local offsets = {
          { x = 0.0, y = 0.0 },
          { x = zone.radius * 0.18, y = -zone.radius * 0.16 }
        }

        for colorIndex, color in ipairs(smokeColors) do
          UseParticleFxAssetNextCall('core')
          local offset = offsets[colorIndex] or offsets[1]
          local handle = StartParticleFxLoopedAtCoord('exp_grd_bzgas_smoke',
            zone.x + offset.x, zone.y + offset.y, smokeHeight,
            0.0, 0.0, 0.0, smokeScale, false, false, false, false)

          if handle then
            SetParticleFxLoopedColour(handle, color.r or 0.15, color.g or 1.0, color.b or 0.20, false)
            handles[#handles + 1] = handle
          end
        end

        if #handles > 0 then
          zoneSmokeFx[i] = { handles = handles }
        end
      end
    else
      stopZoneSmoke(i)
    end
  end

  for idx, _ in pairs(zoneSmokeFx) do
    if not contagiousZones[idx] then
      stopZoneSmoke(idx)
    end
  end
end

-- Envoi coords au serveur
CreateThread(function()
  TriggerServerEvent('esx_infection:requestZones')
  while true do
    Wait(Config.CoordReportMs)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    TriggerServerEvent('esx_infection:reportCoords', c.x, c.y, c.z)
  end
end)

CreateThread(function()
  local menuItems = {
    'Ajouter une zone ici',
    'Rayon +',
    'Rayon -',
    'Temps mortel +5s',
    'Temps mortel -5s',
    'Supprimer la zone la plus proche',
    'Vider toutes les zones',
    'Fermer'
  }

  while true do
    Wait(0)
    drawContagiousZones()

    if zoneMenuOpen then
      drawZoneMenuHelp()
      drawZoneMenuLine(('Nouveau rayon: ~g~%.1fm~s~, mort en ~r~%ss~s~'):format(zoneNewRadius, zoneNewLethalSeconds), 0.21, false)

      for i, label in ipairs(menuItems) do
        drawZoneMenuLine(label, 0.22 + (i * 0.026), zoneMenuIndex == i)
      end

      if IsControlJustPressed(0, 172) then -- up
        zoneMenuIndex = zoneMenuIndex - 1
        if zoneMenuIndex < 1 then zoneMenuIndex = #menuItems end
      elseif IsControlJustPressed(0, 173) then -- down
        zoneMenuIndex = zoneMenuIndex + 1
        if zoneMenuIndex > #menuItems then zoneMenuIndex = 1 end
      elseif IsControlJustPressed(0, 177) then -- back
        zoneMenuOpen = false
      elseif IsControlJustPressed(0, 191) then -- enter
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)

        if zoneMenuIndex == 1 then
          TriggerServerEvent('esx_infection:addZone', {
            x = c.x,
            y = c.y,
            z = c.z,
            radius = zoneNewRadius,
            lethalSeconds = zoneNewLethalSeconds
          })
        elseif zoneMenuIndex == 2 then
          zoneNewRadius = math.min((Config.ZoneMaxRadius or 25.0), zoneNewRadius + 1.0)
        elseif zoneMenuIndex == 3 then
          zoneNewRadius = math.max((Config.ZoneMinRadius or 2.0), zoneNewRadius - 1.0)
        elseif zoneMenuIndex == 4 then
          zoneNewLethalSeconds = math.min(300, zoneNewLethalSeconds + 5)
        elseif zoneMenuIndex == 5 then
          zoneNewLethalSeconds = math.max(5, zoneNewLethalSeconds - 5)
        elseif zoneMenuIndex == 6 then
          TriggerServerEvent('esx_infection:removeNearestZone', { x = c.x, y = c.y, z = c.z })
        elseif zoneMenuIndex == 7 then
          TriggerServerEvent('esx_infection:clearZones')
        elseif zoneMenuIndex == 8 then
          zoneMenuOpen = false
        end
      end
    end
  end
end)

-- HUD niveau infection (en haut à droite, sous la zone métier ESX)
CreateThread(function()
  while true do
    Wait(0)
    local level = getInfectionLevel()
    drawTopRightText(getInfectionLabel(level), 0.985, 0.115, 0.33)
  end
end)

local function isPlayerIncapacitated(ped)
  if IsEntityDead(ped) then return true end
  if IsPedDeadOrDying(ped, true) then return true end
  if IsPedFatallyInjured(ped) then return true end
  return false
end

-- Nettoie l'infection dès que le joueur meurt/perd connaissance (peu importe la cause)
CreateThread(function()
  while true do
    Wait(250)
    local ped = PlayerPedId()
    local isIncapacitated = isPlayerIncapacitated(ped)

    if isIncapacitated and not wasIncapacitated then
      wasIncapacitated = true
      TriggerServerEvent('esx_infection:playerDied')
    elseif not isIncapacitated and wasIncapacitated then
      wasIncapacitated = false
    end
  end
end)

-- Symptômes
CreateThread(function()
  while true do
    Wait(math.random(Config.SymptomTickMin, Config.SymptomTickMax) * 1000)
    if status == 'sick_light' or status == 'sick' or status == 'severe' then
      local ped = PlayerPedId()

      -- toux prolongée
      if not IsPedInAnyVehicle(ped, false) then
        RequestAnimDict('timetable@gardener@smoking_joint')
        while not HasAnimDictLoaded('timetable@gardener@smoking_joint') do Wait(0) end
        TaskPlayAnim(ped, 'timetable@gardener@smoking_joint', 'idle_cough',
          2.0, 2.0, Config.CoughAnimDurationMs, 49, 0, false, false, false)
      end

      local shake = Config.CamShake
      if status == 'sick_light' then shake = Config.CamShake * 0.6 end
      if status == 'severe' then shake = Config.CamShake * 1.8 end
      ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', shake)
    end
  end
end)
