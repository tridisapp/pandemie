local status = 'healthy'
local untilTs = 0
local mask = false
local gel  = false
local originalMask = nil

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

-- Envoi coords au serveur
CreateThread(function()
  while true do
    Wait(Config.CoordReportMs)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    TriggerServerEvent('esx_infection:reportCoords', c.x, c.y, c.z)
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
