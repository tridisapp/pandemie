local status = 'healthy'
local untilTs = 0
local mask = false
local gel  = false

local function getInfectionLevel()
  if status == 'sick' then return 5 end
  if status == 'incubating' then return 2 end
  if status == 'immune' then return 0 end
  return 0
end

local function getInfectionLabel(level)
  if level <= 0 then
    return '~g~Niveau infection: 0~s~'
  end
  return ('~r~Niveau infection: %s/5~s~'):format(level)
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
    if status == 'sick' then
      local ped = PlayerPedId()

      -- toux prolongée
      if not IsPedInAnyVehicle(ped, false) then
        RequestAnimDict('timetable@gardener@smoking_joint')
        while not HasAnimDictLoaded('timetable@gardener@smoking_joint') do Wait(0) end
        TaskPlayAnim(ped, 'timetable@gardener@smoking_joint', 'idle_cough',
          2.0, 2.0, Config.CoughAnimDurationMs, 49, 0, false, false, false)
      end

      ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Config.CamShake)
    end
  end
end)
