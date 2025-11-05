ESX = exports["es_extended"]:getSharedObject()

-- Globale Variablen
ATL = {
    active = false,
    phase = nil, -- 'registration', 'preparation', 'active', 'ended'
    registeredPlayers = {},
    teams = {},
    pounderVehicles = {},
    startTime = 0,
    phaseEndTime = 0,
    deliveredTeam = nil,
    lootEndTime = 0
}

-- Hilfsfunktionen
function GetOnlinePlayersCount()
    local count = 0
    local players = ESX.GetExtendedPlayers()
    
    for _, xPlayer in pairs(players) do
        local job = xPlayer.job.name
        if Config.AllowedJobs[job] then
            count = count + 1
        end
    end
    
    return count
end

function GetJobColor(job)
    if Config.AllowedJobs[job] then
        return Config.AllowedJobs[job].blipColor
    end
    return 1
end

function IsPlayerEligible(xPlayer)
    local job = xPlayer.job.name
    local grade = xPlayer.job.grade
    
    if Config.AllowedJobs[job] then
        local jobConfig = Config.AllowedJobs[job]
        if grade >= jobConfig.minGrade and grade <= jobConfig.maxGrade then
            return true
        end
    end
    
    return false
end

function NotifyTeam(job, message)
    local players = ESX.GetExtendedPlayers('job', job)
    for _, xPlayer in pairs(players) do
        TriggerClientEvent('esx:showNotification', xPlayer.source, message)
    end
end

function SelectRandomSpawnPoints()
    local available = {}
    for i, point in ipairs(Config.SpawnPoints) do
        table.insert(available, i)
    end
    
    -- Zufällig 2 verschiedene Punkte auswählen
    local index1 = math.random(#available)
    local spawn1 = available[index1]
    table.remove(available, index1)
    
    local index2 = math.random(#available)
    local spawn2 = available[index2]
    
    return Config.SpawnPoints[spawn1], Config.SpawnPoints[spawn2]
end

function GenerateLoot()
    local loot = {}
    
    for _, lootItem in ipairs(Config.Loot) do
        local amount = math.random(lootItem.min, lootItem.max)
        table.insert(loot, {
            item = lootItem.item,
            count = amount
        })
    end
    
    return loot
end

-- ATL Drop starten
function StartATLDrop()
    if ATL.active then return end
    
    local playerCount = GetOnlinePlayersCount()
    if playerCount < Config.MinPlayers then return end
    
    print('[ATL] ATL Drop gestartet! Spieler: ' .. playerCount)
    
    ATL.active = true
    ATL.phase = 'registration'
    ATL.registeredPlayers = {}
    ATL.startTime = os.time()
    ATL.phaseEndTime = os.time() + Config.RegistrationTime
    
    -- Allen berechtigten Spielern Bescheid geben
    TriggerClientEvent('esx:showNotification', -1, Config.Notifications.atlDropped)
end

-- Registrierung
RegisterCommand('acceptatl', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not ATL.active or ATL.phase ~= 'registration' then
        TriggerClientEvent('esx:showNotification', source, '❌ Kein ATL aktiv!')
        return
    end
    
    if not IsPlayerEligible(xPlayer) then
        TriggerClientEvent('esx:showNotification', source, Config.Notifications.notEligible)
        return
    end
    
    local job = xPlayer.job.name
    
    -- Prüfen ob bereits registriert
    if ATL.registeredPlayers[source] then
        TriggerClientEvent('esx:showNotification', source, Config.Notifications.alreadyRegistered)
        return
    end
    
    ATL.registeredPlayers[source] = job
    TriggerClientEvent('esx:showNotification', source, Config.Notifications.registered)
    
    print('[ATL] Spieler ' .. xPlayer.getName() .. ' (' .. job .. ') hat sich registriert')
end)

-- Team-Auslosung
function SelectTeams()
    -- Jobs mit angemeldeten Spielern sammeln
    local jobsWithPlayers = {}
    
    for playerId, job in pairs(ATL.registeredPlayers) do
        if not jobsWithPlayers[job] then
            jobsWithPlayers[job] = {}
        end
        table.insert(jobsWithPlayers[job], playerId)
    end
    
    -- Mindestens 2 Jobs müssen sich angemeldet haben
    local availableJobs = {}
    for job, _ in pairs(jobsWithPlayers) do
        table.insert(availableJobs, job)
    end
    
    if #availableJobs < 2 then
        print('[ATL] Nicht genug Jobs registriert. ATL abgebrochen.')
        ATL.active = false
        TriggerClientEvent('esx:showNotification', -1, '❌ ATL abgebrochen - zu wenig Teams!')
        return false
    end
    
    -- 2 zufällige Jobs auswählen
    local team1Job = availableJobs[math.random(#availableJobs)]
    local team2Job
    repeat
        team2Job = availableJobs[math.random(#availableJobs)]
    until team2Job ~= team1Job
    
    -- Spawn-Punkte zuweisen
    local spawn1, spawn2 = SelectRandomSpawnPoints()
    
    ATL.teams = {
        team1 = {
            job = team1Job,
            players = jobsWithPlayers[team1Job],
            spawn = spawn1,
            color = GetJobColor(team1Job),
            pounder = nil,
            delivered = false
        },
        team2 = {
            job = team2Job,
            players = jobsWithPlayers[team2Job],
            spawn = spawn2,
            color = GetJobColor(team2Job),
            pounder = nil,
            delivered = false
        }
    }
    
    print('[ATL] Teams ausgelost: ' .. team1Job .. ' vs ' .. team2Job)
    
    -- Benachrichtigungen
    local message = string.format(Config.Notifications.teamsSelected, team1Job, team2Job)
    TriggerClientEvent('esx:showNotification', -1, message)
    
    -- Nicht ausgeloste Spieler entfernen
    for playerId, job in pairs(ATL.registeredPlayers) do
        if job ~= team1Job and job ~= team2Job then
            ATL.registeredPlayers[playerId] = nil
        end
    end
    
    return true
end

-- Vorbereitungsphase starten
function StartPreparationPhase()
    ATL.phase = 'preparation'
    ATL.phaseEndTime = os.time() + Config.PreparationTime
    
    -- Teams über Spawn-Punkte informieren
    for teamKey, team in pairs(ATL.teams) do
        for _, playerId in ipairs(team.players) do
            TriggerClientEvent('atl:client:showSpawnPoints', playerId, {
                ownSpawn = team.spawn,
                ownColor = team.color,
                enemySpawn = teamKey == 'team1' and ATL.teams.team2.spawn or ATL.teams.team1.spawn,
                enemyColor = teamKey == 'team1' and ATL.teams.team2.color or ATL.teams.team1.color
            })
        end
        NotifyTeam(team.job, Config.Notifications.preparationPhase)
    end
end

-- Pounder spawnen
function SpawnPounders()
    for teamKey, team in pairs(ATL.teams) do
        local spawn = team.spawn
        
        TriggerClientEvent('atl:client:spawnPounder', -1, {
            coords = spawn.coords,
            heading = spawn.heading,
            color = team.color,
            teamKey = teamKey
        })
        
        NotifyTeam(team.job, Config.Notifications.pounderSpawned)
    end
    
    ATL.phase = 'active'
    ATL.phaseEndTime = os.time() + Config.PounderMoveTime
end

-- Pounder registrieren (von Client)
RegisterNetEvent('atl:server:registerPounder')
AddEventHandler('atl:server:registerPounder', function(netId, teamKey)
    if not ATL.active or not ATL.teams[teamKey] then return end
    
    ATL.teams[teamKey].pounder = {
        netId = netId,
        moved = false,
        initialPos = nil
    }
    
    print('[ATL] Pounder für ' .. teamKey .. ' registriert: ' .. netId)
end)

-- Pounder bewegt
RegisterNetEvent('atl:server:pounderMoved')
AddEventHandler('atl:server:pounderMoved', function(teamKey)
    if not ATL.active or not ATL.teams[teamKey] then return end
    
    ATL.teams[teamKey].pounder.moved = true
    print('[ATL] Pounder ' .. teamKey .. ' wurde bewegt')
end)

-- Pounder Abgabe
RegisterNetEvent('atl:server:deliverPounder')
AddEventHandler('atl:server:deliverPounder', function(teamKey)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not ATL.active or ATL.phase ~= 'active' then return end
    if not ATL.teams[teamKey] then return end
    if ATL.teams[teamKey].delivered then return end
    
    -- Prüfen ob Spieler im richtigen Team ist
    local playerJob = xPlayer.job.name
    if ATL.teams[teamKey].job ~= playerJob then return end
    
    -- Pounder abgegeben
    ATL.teams[teamKey].delivered = true
    ATL.deliveredTeam = teamKey
    ATL.phase = 'ended'
    ATL.lootEndTime = os.time() + Config.LootTime
    
    -- Loot generieren
    local loot = GenerateLoot()
    
    -- Allen Bescheid geben
    local message = string.format(Config.Notifications.delivered, ATL.teams[teamKey].job)
    TriggerClientEvent('esx:showNotification', -1, message)
    
    -- Pounder Motor ausschalten
    TriggerClientEvent('atl:client:disablePounder', -1, ATL.teams[teamKey].pounder.netId)
    
    -- Loot im Kofferraum speichern
    TriggerClientEvent('atl:client:enableLoot', -1, ATL.teams[teamKey].pounder.netId, loot, teamKey)
    
    print('[ATL] Team ' .. teamKey .. ' hat gewonnen!')
end)

-- Loot nehmen
RegisterNetEvent('atl:server:takeLoot')
AddEventHandler('atl:server:takeLoot', function(netId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not ATL.deliveredTeam then return end
    
    local team = ATL.teams[ATL.deliveredTeam]
    if not team or team.pounder.netId ~= netId then return end
    
    -- Prüfen ob Spieler im Gewinner-Team ist
    local playerJob = xPlayer.job.name
    if team.job ~= playerJob then
        TriggerClientEvent('esx:showNotification', source, '❌ Nur das Gewinner-Team darf den Loot nehmen!')
        return
    end
    
    -- Loot geben (wird vom Client angefordert)
    TriggerClientEvent('atl:client:openLoot', source, netId)
end)

-- Loot Item nehmen
RegisterNetEvent('atl:server:takeItem')
AddEventHandler('atl:server:takeItem', function(item, count)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not ATL.deliveredTeam then return end
    
    local team = ATL.teams[ATL.deliveredTeam]
    local playerJob = xPlayer.job.name
    if team.job ~= playerJob then return end
    
    -- Item hinzufügen
    xPlayer.addInventoryItem(item, count)
    TriggerClientEvent('esx:showNotification', source, '✅ Du hast ' .. count .. 'x ' .. item .. ' erhalten!')
end)

-- Szenario beenden
function EndScenario()
    print('[ATL] Szenario wird beendet')
    
    -- Allen Bescheid geben
    TriggerClientEvent('esx:showNotification', -1, Config.Notifications.scenarioEnded)
    
    -- Pounder despawnen
    TriggerClientEvent('atl:client:cleanupScenario', -1)
    
    -- Reset
    ATL.active = false
    ATL.phase = nil
    ATL.registeredPlayers = {}
    ATL.teams = {}
    ATL.pounderVehicles = {}
    ATL.deliveredTeam = nil
    ATL.lootEndTime = 0
end

-- Timer Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if ATL.active then
            local currentTime = os.time()
            
            -- Registrierungsphase beendet
            if ATL.phase == 'registration' and currentTime >= ATL.phaseEndTime then
                if SelectTeams() then
                    StartPreparationPhase()
                else
                    ATL.active = false
                end
            end
            
            -- Vorbereitungsphase beendet
            if ATL.phase == 'preparation' and currentTime >= ATL.phaseEndTime then
                SpawnPounders()
            end
            
            -- Prüfen ob Pounder bewegt wurden
            if ATL.phase == 'active' and currentTime >= ATL.phaseEndTime then
                local allMoved = true
                for teamKey, team in pairs(ATL.teams) do
                    if team.pounder and not team.pounder.moved then
                        allMoved = false
                        break
                    end
                end
                
                if not allMoved then
                    TriggerClientEvent('esx:showNotification', -1, Config.Notifications.pounderNotMoved)
                    EndScenario()
                end
            end
            
            -- Loot-Zeit abgelaufen
            if ATL.phase == 'ended' and ATL.lootEndTime > 0 and currentTime >= ATL.lootEndTime then
                EndScenario()
            end
        end
    end
end)

-- Zufälliger ATL Drop (alle 30-60 Minuten prüfen)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(math.random(1800000, 3600000)) -- 30-60 Minuten
        
        if not ATL.active then
            local playerCount = GetOnlinePlayersCount()
            if playerCount >= Config.MinPlayers then
                -- 30% Chance für Drop
                if math.random(100) <= 30 then
                    StartATLDrop()
                end
            end
        end
    end
end)

-- Admin Command zum Testen
RegisterCommand('startatl', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Hier kannst du Admin-Check einbauen
    -- if xPlayer.getGroup() ~= 'admin' then return end
    
    StartATLDrop()
end, false)

print('[ATL] Server-Script geladen')
