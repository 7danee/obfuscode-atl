ESX = exports["es_extended"]:getSharedObject()

-- Lokale Variablen
local atlActive = false
local ownSpawnBlip = nil
local enemySpawnBlip = nil
local pounderBlips = {}
local myPounder = nil
local enemyPounder = nil
local myTeamKey = nil
local lootVehicles = {}

-- Blips erstellen
function CreateCastleBlip(coords, color, label, isOwn)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Blips.castle.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blips.castle.scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

function CreatePounderBlip(vehicle, color, label)
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, Config.Blips.pounder.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blips.pounder.scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- Spawn-Punkte anzeigen
RegisterNetEvent('atl:client:showSpawnPoints')
AddEventHandler('atl:client:showSpawnPoints', function(data)
    atlActive = true
    
    -- Eigene Basis
    ownSpawnBlip = CreateCastleBlip(
        data.ownSpawn.coords,
        data.ownColor,
        "Deine Basis",
        true
    )
    
    -- Gegner Basis
    enemySpawnBlip = CreateCastleBlip(
        data.enemySpawn.coords,
        data.enemyColor,
        "Gegner Basis",
        false
    )
    
    print('[ATL] Spawn-Punkte angezeigt')
end)

-- Pounder spawnen
RegisterNetEvent('atl:client:spawnPounder')
AddEventHandler('atl:client:spawnPounder', function(data)
    local model = GetHashKey(Config.PounderModel)
    RequestModel(model)
    
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end
    
    local vehicle = CreateVehicle(
        model,
        data.coords.x,
        data.coords.y,
        data.coords.z,
        data.heading,
        true,
        false
    )
    
    SetVehicleNumberPlateText(vehicle, "ATL " .. data.teamKey:upper())
    SetVehicleColours(vehicle, data.color, data.color)
    SetVehicleEngineOn(vehicle, false, false, false)
    
    -- Blip erstellen für beide Teams sichtbar
    local blip = CreatePounderBlip(
        vehicle,
        data.color,
        "Pounder - " .. data.teamKey:upper()
    )
    
    pounderBlips[data.teamKey] = blip
    
    -- Netzwerk ID an Server senden
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('atl:server:registerPounder', netId, data.teamKey)
    
    -- Eigenen Pounder merken
    local playerData = ESX.GetPlayerData()
    local playerJob = playerData.job.name
    
    -- Team-Zugehörigkeit prüfen (vom Server sollte eigentlich Info kommen, aber wir prüfen Job)
    if not myTeamKey then
        -- Wir müssen rausfinden zu welchem Team wir gehören
        -- Das machen wir indem wir prüfen ob wir in der Nähe eines Spawn-Punktes sind
        local playerCoords = GetEntityCoords(PlayerPedId())
        local dist1 = #(playerCoords - data.coords)
        
        if dist1 < 100.0 then
            myTeamKey = data.teamKey
            myPounder = vehicle
            
            -- Bewegungsüberwachung starten
            Citizen.CreateThread(function()
                MonitorPounderMovement(vehicle, data.teamKey, data.coords)
            end)
        else
            enemyPounder = vehicle
        end
    end
    
    print('[ATL] Pounder gespawnt: ' .. data.teamKey)
end)

-- Pounder Bewegung überwachen
function MonitorPounderMovement(vehicle, teamKey, spawnCoords)
    local initialPos = GetEntityCoords(vehicle)
    local moved = false
    local startTime = GetGameTimer()
    local timeout = Config.PounderMoveTime * 1000
    
    while DoesEntityExist(vehicle) and not moved do
        Citizen.Wait(1000)
        
        if not DoesEntityExist(vehicle) then break end
        
        local currentPos = GetEntityCoords(vehicle)
        local distance = #(initialPos - currentPos)
        
        if distance >= Config.PounderMoveDistance then
            moved = true
            TriggerServerEvent('atl:server:pounderMoved', teamKey)
            print('[ATL] Pounder bewegt: ' .. distance .. 'm')
            
            -- Abgabe-Thread starten
            Citizen.CreateThread(function()
                MonitorPounderDelivery(vehicle, teamKey)
            end)
            break
        end
        
        -- Timeout check
        if GetGameTimer() - startTime > timeout then
            break
        end
    end
end

-- Pounder Abgabe überwachen
function MonitorPounderDelivery(vehicle, teamKey)
    -- Wir müssen die gegnerische Spawn-Position kennen
    -- Diese wird vom Blip genommen
    local enemyCoords = nil
    
    if enemySpawnBlip then
        enemyCoords = GetBlipCoords(enemySpawnBlip)
    end
    
    if not enemyCoords then
        print('[ATL] Keine gegnerische Spawn-Position gefunden')
        return
    end
    
    local delivered = false
    
    while DoesEntityExist(vehicle) and not delivered do
        Citizen.Wait(500)
        
        local ped = PlayerPedId()
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(vehicleCoords - enemyCoords)
        
        -- In Abgabe-Reichweite?
        if distance <= Config.DeliveryRadius then
            -- Ist Spieler der Fahrer?
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                -- Anzeige zum Hupen
                ESX.ShowHelpNotification('Drücke ~INPUT_CONTEXT~ zum Hupen und Abgeben')
                
                if IsControlJustPressed(0, 38) then -- E-Taste
                    -- Hupen
                    StartVehicleHorn(vehicle, 1000, GetHashKey("NORMAL"), false)
                    
                    -- An Server melden
                    TriggerServerEvent('atl:server:deliverPounder', teamKey)
                    delivered = true
                    break
                end
            end
        end
    end
end

-- Pounder Motor deaktivieren
RegisterNetEvent('atl:client:disablePounder')
AddEventHandler('atl:client:disablePounder', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if DoesEntityExist(vehicle) then
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        SetVehicleDoorsLocked(vehicle, 2) -- Locked
        print('[ATL] Pounder wurde deaktiviert')
    end
end)

-- Loot aktivieren
RegisterNetEvent('atl:client:enableLoot')
AddEventHandler('atl:client:enableLoot', function(netId, loot, teamKey)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if DoesEntityExist(vehicle) then
        lootVehicles[netId] = {
            vehicle = vehicle,
            loot = loot,
            teamKey = teamKey,
            taken = false
        }
        
        -- Loot-Interaktion Thread
        Citizen.CreateThread(function()
            MonitorLootInteraction(vehicle, netId)
        end)
        
        print('[ATL] Loot aktiviert für Fahrzeug: ' .. netId)
    end
end)

-- Loot Interaktion
function MonitorLootInteraction(vehicle, netId)
    local lootData = lootVehicles[netId]
    if not lootData then return end
    
    while DoesEntityExist(vehicle) and lootData and not lootData.taken do
        Citizen.Wait(0)
        
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(pedCoords - vehicleCoords)
        
        if distance <= 3.0 then
            ESX.ShowHelpNotification('Drücke ~INPUT_CONTEXT~ um den Kofferraum zu öffnen')
            
            if IsControlJustPressed(0, 38) then -- E-Taste
                TriggerServerEvent('atl:server:takeLoot', netId)
            end
        end
    end
end

-- Loot UI öffnen
RegisterNetEvent('atl:client:openLoot')
AddEventHandler('atl:client:openLoot', function(netId)
    local lootData = lootVehicles[netId]
    if not lootData or lootData.taken then return end
    
    -- Ox Inventory öffnen (Beispiel)
    local items = {}
    
    for i, lootItem in ipairs(lootData.loot) do
        table.insert(items, {
            slot = i,
            name = lootItem.item,
            count = lootItem.count,
            label = lootItem.item, -- Hier könntest du echte Item-Labels laden
            weight = 0,
            usable = false,
            rare = false,
            canRemove = true
        })
    end
    
    -- Ox Inventory API
    exports.ox_inventory:openInventory('stash', {
        id = 'atl_loot_' .. netId,
        title = 'ATL Pounder Loot',
        slots = #items,
        weight = 999999
    })
    
    -- Items ins Stash laden
    for _, item in ipairs(items) do
        TriggerServerEvent('atl:server:takeItem', item.name, item.count)
    end
    
    lootData.taken = true
end)

-- Cleanup
RegisterNetEvent('atl:client:cleanupScenario')
AddEventHandler('atl:client:cleanupScenario', function()
    -- Blips entfernen
    if ownSpawnBlip then
        RemoveBlip(ownSpawnBlip)
        ownSpawnBlip = nil
    end
    
    if enemySpawnBlip then
        RemoveBlip(enemySpawnBlip)
        enemySpawnBlip = nil
    end
    
    for _, blip in pairs(pounderBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    pounderBlips = {}
    
    -- Pounder despawnen
    if myPounder and DoesEntityExist(myPounder) then
        DeleteEntity(myPounder)
    end
    
    if enemyPounder and DoesEntityExist(enemyPounder) then
        DeleteEntity(enemyPounder)
    end
    
    -- Loot Fahrzeuge despawnen
    for netId, data in pairs(lootVehicles) do
        if DoesEntityExist(data.vehicle) then
            DeleteEntity(data.vehicle)
        end
    end
    
    -- Reset
    atlActive = false
    myPounder = nil
    enemyPounder = nil
    myTeamKey = nil
    lootVehicles = {}
    
    print('[ATL] Client aufgeräumt')
end)

-- Disconnect Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Cleanup
    if ownSpawnBlip then RemoveBlip(ownSpawnBlip) end
    if enemySpawnBlip then RemoveBlip(enemySpawnBlip) end
    
    for _, blip in pairs(pounderBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

print('[ATL] Client-Script geladen')
