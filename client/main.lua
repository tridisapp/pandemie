local status = 'healthy'
local untilTs = 0
local mask = false
local gel  = false

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

-- Symptômes
CreateThread(function()
  while true do
    Wait(math.random(Config.SymptomTickMin, Config.SymptomTickMax) * 1000)
    if status == 'sick' then
      local ped = PlayerPedId()

      -- petite toux anim
      if not IsPedInAnyVehicle(ped, false) then
        RequestAnimDict("timetable@gardener@smoking_joint")
        while not HasAnimDictLoaded("timetable@gardener@smoking_joint") do Wait(0) end
        TaskPlayAnim(ped, "timetable@gardener@smoking_joint", "idle_cough",
          2.0, 2.0, 1200, 49, 0, false, false, false)
      end

      ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", Config.CamShake)
    end
  end
end)