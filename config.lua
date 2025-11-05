Config = {}

-- Minimum Online-Spieler für ATL Drop
Config.MinPlayers = 50

-- Erlaubte Jobs und deren Grade
Config.AllowedJobs = {
    ['vagos'] = {
        minGrade = 9,
        maxGrade = 12,
        color = 5, -- Gelb
        blipColor = 46
    },
    ['ballas'] = {
        minGrade = 9,
        maxGrade = 12,
        color = 27, -- Lila
        blipColor = 27
    },
    ['grove'] = {
        minGrade = 9,
        maxGrade = 12,
        color = 2, -- Grün
        blipColor = 2
    }
}

-- Zeiten (in Sekunden)
Config.RegistrationTime = 600 -- 10 Minuten Anmeldephase
Config.PreparationTime = 300 -- 5 Minuten bis Pounder spawnt
Config.PounderMoveDistance = 5 -- Mindestens 5 Meter bewegen
Config.PounderMoveTime = 60 -- 60 Sekunden Zeit zum Bewegen
Config.LootTime = 600 -- 10 Minuten Zeit für Loot nach Abgabe
Config.DeliveryRadius = 10.0 -- 10 Meter Radius für Abgabe

-- Spawn-Punkte für die "Burgen" (werden zufällig ausgewählt)
Config.SpawnPoints = {
    {coords = vector3(331.23, -2039.85, 20.94), heading = 140.0}, -- La Mesa
    {coords = vector3(1397.49, 1141.91, 114.33), heading = 0.0}, -- Vinewood Hills
    {coords = vector3(-1542.43, -85.37, 54.93), heading = 230.0}, -- Rockford Hills
    {coords = vector3(2436.52, 4964.18, 46.81), heading = 45.0}, -- Grapeseed
    {coords = vector3(1698.30, 3589.16, 35.62), heading = 210.0}, -- Sandy Shores
    {coords = vector3(-22.16, -1433.13, 30.65), heading = 180.0}, -- Vespucci
    {coords = vector3(85.74, -1959.50, 20.85), heading = 320.0}, -- Davis
    {coords = vector3(-1105.86, -1690.03, 4.37), heading = 125.0}, -- Vespucci Beach
}

-- Pounder Model
Config.PounderModel = 'pounder'

-- Loot-Tabelle
Config.Loot = {
    {item = 'WEAPON_REVOLVER', min = 2, max = 3},
    {item = 'WEAPON_SPECIALCARBINE', min = 4, max = 7},
    {item = 'military_kevlar', min = 50, max = 175},
    {item = 'WEAPON_PISTOL', min = 1, max = 3},
    {item = 'WEAPON_COMBATPISTOL', min = 1, max = 2},
    {item = 'WEAPON_HEAVYPISTOL', min = 1, max = 2},
    {item = 'pistol_ammo', min = 50, max = 150},
    {item = 'rifle_ammo', min = 100, max = 300},
}

-- Blip Einstellungen
Config.Blips = {
    castle = {
        sprite = 473, -- Festung Icon
        scale = 1.2,
        label = "Team Basis"
    },
    pounder = {
        sprite = 67, -- LKW Icon
        scale = 1.0,
        label = "Pounder"
    },
    enemyCastle = {
        sprite = 473,
        scale = 1.2,
        label = "Gegner Basis"
    }
}

-- Benachrichtigungen
Config.Notifications = {
    atlDropped = "Ein ATL wurde gedroppt! Nutze /acceptatl um teilzunehmen!",
    registered = "Du hast dich für das ATL angemeldet!",
    alreadyRegistered = "Du bist bereits angemeldet!",
    notEligible = "Dein Job oder Grad ist nicht berechtigt!",
    teamsSelected = "Teams wurden ausgelost: %s vs %s",
    notSelected = "Dein Team wurde nicht ausgelost.",
    preparationPhase = "Bereitet euch vor! Pounder spawnt in 5 Minuten an eurer Basis.",
    pounderSpawned = "Der Pounder wurde gespawnt! Bewegt ihn mindestens 5 Meter!",
    pounderNotMoved = "Der Pounder wurde nicht bewegt! Szenario bricht ab...",
    deliver = "Fahre den Pounder zur gegnerischen Basis und hupe (E)!",
    delivered = "%s hat den Pounder abgegeben! Loot verfügbar!",
    lootTimeRemaining = "Noch %s Minuten um den Loot zu holen!",
    scenarioEnded = "Das ATL-Szenario ist beendet!",
}
