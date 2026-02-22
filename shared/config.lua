Config = {}

Config.Enabled = true

-- Boucles
Config.CoordReportMs = 2000      -- le client envoie ses coords au serveur
Config.TickSeconds = 3           -- tick propagation + évolution maladie

-- Propagation
Config.SpreadRadius = 4.0
Config.BaseInfectChance = 0.12
Config.MaxInfectPerTick = 3

-- Timers (secondes)
Config.IncubationMin = 60
Config.IncubationMax = 180
Config.SickDurationMin = 240
Config.SickDurationMax = 480
Config.ImmunitySeconds = 300

-- Réduction de chance via protections (items)
Config.MaskReduction = 0.60
Config.GelReduction  = 0.35

-- Symptômes client
Config.SymptomTickMin = 8
Config.SymptomTickMax = 18
Config.CamShake = 0.08

-- Admin / permissions
Config.AdminGroups = { 'admin', 'superadmin' } -- ESX group
Config.Commands = {
  start = 'infection_start',
  stop  = 'infection_stop',
  cure  = 'infection_cure',
  infect= 'infection_infect',
  info  = 'infection_info'
}

-- Items ESX (esx_inventory)
Config.Items = {
  mask = 'mask',
  gel  = 'gel'
}