-- J_PoliceNat server/vehicles.lua
local ESX = exports["es_extended"]:getSharedObject()
local GetOnDutyPolice = exports['J_PoliceNat'].GetOnDutyPolice

-- =============================================
-- Callbacks serveur pour les véhicules
-- =============================================

-- Vérifier le statut d'un véhicule (volé ou non)
ESX.RegisterServerCallback('police:checkVehicleStatus', function(source, cb, plate)
    -- Nettoyer la plaque (enlever les espaces)
    plate = string.gsub(plate, "%s", "")
    
    MySQL.query('SELECT stolen FROM owned_vehicles WHERE REPLACE(plate, " ", "") = ?', {
        plate
    }, function(result)
        if result and result[1] then
            print("Véhicule trouvé, statut volé: " .. tostring(result[1].stolen == 1))
            cb(result[1].stolen == 1)
        else
            print("Véhicule non trouvé dans la base de données: " .. plate)
            cb(false)
        end
    end)
end)

-- Récupérer la liste des véhicules volés
ESX.RegisterServerCallback('police:getStolenVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return cb({}) end
    
    if xPlayer.job.name == 'police' then
        -- Si policier, voir tous les véhicules volés
        MySQL.query('SELECT v.*, CONCAT(u.firstname, " ", u.lastname) as owner_name FROM owned_vehicles v LEFT JOIN users u ON v.owner = u.identifier WHERE v.stolen = 1', {}, function(vehicles)
            for i=1, #vehicles do
                if vehicles[i].vehicle then
                    vehicles[i].vehicle = json.decode(vehicles[i].vehicle)
                end
            end
            cb(vehicles)
        end)
    else
        -- Si civil, voir uniquement ses véhicules volés
        MySQL.query('SELECT v.* FROM owned_vehicles v WHERE v.owner = ? AND v.stolen = 1', {
            xPlayer.identifier
        }, function(vehicles)
            for i=1, #vehicles do
                if vehicles[i].vehicle then
                    vehicles[i].vehicle = json.decode(vehicles[i].vehicle)
                end
            end
            cb(vehicles)
        end)
    end
end)

-- Récupérer les véhicules appartenant au joueur
ESX.RegisterServerCallback('police:getOwnedVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    MySQL.query('SELECT * FROM owned_vehicles WHERE owner = ?', {
        xPlayer.identifier
    }, function(result)
        local vehicles = {}
        
        if result and #result > 0 then
            for _, v in ipairs(result) do
                local vehicle = json.decode(v.vehicle)
                table.insert(vehicles, {
                    plate = v.plate,
                    model = vehicle.model,
                    stored = v.stored,
                    stolen = v.stolen == 1
                })
            end
        end
        
        cb(vehicles)
    end)
end)

-- Récupérer les véhicules de service autorisés
ESX.RegisterServerCallback('police:getAuthorizedVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.job.name ~= 'police' then
        cb({})
        return
    end

    local authorizedVehicles = {}
    for _, vehicle in pairs(Config.Vehicles) do
        if xPlayer.job.grade >= vehicle.minGrade then
            table.insert(authorizedVehicles, vehicle)
        end
    end

    cb(authorizedVehicles)
end)

-- =============================================
-- Events serveur pour les véhicules
-- =============================================

-- Vérification des informations du véhicule
RegisterServerEvent('police:checkVehicle')
AddEventHandler('police:checkVehicle', function(plate)
    local source = source
    if not IsPolice(source) then return end

    print("Vérification du véhicule avec plaque: " .. plate)

    MySQL.query('SELECT v.*, CONCAT(u.firstname, " ", u.lastname) as owner FROM owned_vehicles v LEFT JOIN users u ON v.owner = u.identifier WHERE v.plate = ?', {
        plate
    }, function(result)
        local vehicleData = {
            plate = plate,
            owner = 'Inconnu',
            model = 'Inconnu',
            stolen = false
        }

        if result and result[1] then
            -- Gestion explicite de toutes les formes possibles de "true"
            local isStolen = false
            
            if result[1].stolen == 1 or result[1].stolen == true or 
               result[1].stolen == "1" or result[1].stolen == "true" or
               tostring(result[1].stolen) == "true" then
                isStolen = true
            end
            
            print("Véhicule trouvé, valeur brute stolen: " .. tostring(result[1].stolen))
            print("Véhicule trouvé, statut volé (après conversion): " .. tostring(isStolen))
            
            vehicleData = {
                plate = result[1].plate,
                owner = result[1].owner,
                model = result[1].vehicle and json.decode(result[1].vehicle).model or 'Inconnu',
                stolen = isStolen
            }
        else
            print("Véhicule non trouvé dans la base de données")
        end

        TriggerClientEvent('police:receiveVehicleInfo', source, vehicleData)
    end)
end)

-- Mise en fourrière
RegisterServerEvent('police:impoundVehicle')
AddEventHandler('police:impoundVehicle', function(plate, coords, networkId)
    local source = source
    if not IsPolice(source) then return end

    -- Supprimer d'abord visuellement le véhicule pour tous les joueurs
    if networkId then
        TriggerClientEvent('police:deleteVehicleForAll', -1, networkId)
    end

    MySQL.update('UPDATE owned_vehicles SET stored = 2, pound = "LosSantos" WHERE plate = ?', {
        plate
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Log Discord
            local embed = exports['J_PoliceNat']:FormatEmbed(
    "Mise en fourrière",
    ('L\'agent %s a mis en fourrière le véhicule [%s]'):format(
        xPlayer.getName(),
        plate
    ),
    3066993
)
exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Fourrière", nil, {embed})


            -- Notification au propriétaire si en ligne
            MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {
                plate
            }, function(result)
                if result[1] then
                    local xTarget = ESX.GetPlayerFromIdentifier(result[1].owner)
                    if xTarget then
    exports['jl_notifications']:SendNotificationToPlayer(xTarget.source, {
    type = 'error',
    message = ('Votre véhicule %s a été mis en fourrière'):format(plate),
    title = 'Fourrière',
    image = 'img/policenat.png',
    duration = 5000
})

                    end
                end
            end)
            
            -- Notification à l'agent
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'success',
    message = ('Véhicule %s mis en fourrière avec succès'):format(plate),
    title = 'Fourrière',
    image = 'img/policenat.png',
    duration = 5000
})
      
        end
    end)
end)

-- =============================================
-- Gestion des véhicules volés
-- =============================================

-- Alerte véhicule volé
RegisterServerEvent('police:reportStolenVehicle')
AddEventHandler('police:reportStolenVehicle', function(plate, description)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    -- Nettoyer la plaque (enlever les espaces)
    local cleanPlate = string.gsub(plate, "%s", "")
    
    print("Signalement de véhicule volé: " .. plate .. " (nettoyée: " .. cleanPlate .. ")")

    -- Vérifier que le véhicule appartient au joueur
    MySQL.query('SELECT * FROM owned_vehicles WHERE owner = ? AND REPLACE(plate, " ", "") = ?', {
        xPlayer.identifier, cleanPlate
    }, function(result)
        if not result[1] then 
exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Vous ne possédez pas ce véhicule',
    title = 'Signalement véhicule',
    image = 'img/policenat.png',
    duration = 5000
})

            return 
        end

        -- Vérifier qu'il n'est pas déjà signalé
        if result[1].stolen == 1 then
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Ce véhicule est déjà signalé comme volé',
    title = 'Signalement véhicule',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end

        -- Mise à jour du statut du véhicule
        MySQL.update('UPDATE owned_vehicles SET stolen = 1 WHERE plate = ?', {
            result[1].plate -- Utiliser la plaque exacte de la base de données
        }, function(affectedRows)
            print("Lignes affectées par la mise à jour: " .. tostring(affectedRows))
            if affectedRows > 0 then
                -- Notification à tous les policiers en service
                local players = ESX.GetPlayers()
                for i=1, #players do
                    local player = ESX.GetPlayerFromId(players[i])
                    if player and player.job.name == 'police' then
                        exports['jl_notifications']:SendNotificationToPlayer(player.source, {
    type = 'warning',
    message = 'Un véhicule ' .. plate .. ' vient d\'être signalé volé',
    title = 'Nouveau véhicule volé',
    image = 'img/policenat.png',
    duration = 10000
})

                    end
                end

                -- Notification au propriétaire
                exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'success',
    message = 'Votre véhicule a été signalé comme volé',
    title = 'Signalement enregistré',
    image = 'img/policenat.png',
    duration = 5000
})


                -- Log Discord
                exports['J_PoliceNat']:NotifyStolenVehicle(
    xPlayer.getName(),
    plate,
    true,
    description or 'Non fournie'
)

            end
        end)
    end)
end)

-- Marquer un véhicule comme retrouvé
RegisterServerEvent('police:recoverStolenVehicle')
AddEventHandler('police:recoverStolenVehicle', function(plate, byPolice)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    -- Vérifier que le véhicule est bien signalé comme volé
    MySQL.query('SELECT * FROM owned_vehicles WHERE plate = ?', {
        plate
    }, function(result)
        if not result[1] then return end
        
        if result[1].stolen == 0 then
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Ce véhicule n\'est pas signalé comme volé',
    title = 'Véhicule retrouvé',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end

        -- Si c'est un policier qui fait la demande, ou le propriétaire
        if (byPolice and xPlayer.job.name == 'police') or result[1].owner == xPlayer.identifier then
            MySQL.update('UPDATE owned_vehicles SET stolen = 0 WHERE plate = ?', {
                plate
            })

            -- Notification
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'success',
    message = 'Le véhicule ' .. plate .. ' a été marqué comme retrouvé',
    title = 'Véhicule retrouvé',
    image = 'img/policenat.png',
    duration = 5000
})


            -- Notifier le propriétaire si c'est un policier qui retrouve le véhicule
            if byPolice and result[1].owner ~= xPlayer.identifier then
                local targetPlayer = ESX.GetPlayerFromIdentifier(result[1].owner)
                if targetPlayer then
                    exports['jl_notifications']:SendNotificationToPlayer(targetPlayer.source, {
    type = 'success',
    message = 'Votre véhicule ' .. plate .. ' a été retrouvé par la police',
    title = 'Véhicule retrouvé',
    image = 'img/policenat.png',
    duration = 10000
})

                end
            end

            -- Log Discord
            exports['J_PoliceNat']:NotifyStolenVehicle(
    xPlayer.getName(),
    plate,
    false,
    byPolice and "Retrouvé par un agent de police" or "Retrouvé par le propriétaire"
)

        else
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Vous n\'êtes pas autorisé à effectuer cette action',
    title = 'Véhicule retrouvé',
    image = 'img/policenat.png',
    duration = 5000
})

        end
    end)
end)

-- =============================================
-- Système de détection des véhicules volés
-- =============================================

-- Système de recherche automatique des plaques
RegisterServerEvent('police:checkNearbyVehicles')
AddEventHandler('police:checkNearbyVehicles', function(nearbyPlates)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.job.name ~= 'police' then return end

    MySQL.query('SELECT plate FROM owned_vehicles WHERE stolen = 1', {}, function(result)
        if result then
            for _, data in ipairs(result) do
                if nearbyPlates[data.plate] then
                    TriggerClientEvent('police:vehicleStolenNotify', source, nearbyPlates[data.plate])
                end
            end
        end
    end)
end)

-- Thread pour la vérification périodique des véhicules volés
CreateThread(function()
    while true do
        -- Vérifier s'il y a des policiers en service
        local xPlayers = ESX.GetPlayers()
        local policePlayers = {}
        
        for i=1, #xPlayers do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and xPlayer.job.name == 'police' then
                -- On ajoute tous les joueurs avec le job de police
                table.insert(policePlayers, xPlayer.source)
            end
        end
        
        -- Vérifier les véhicules seulement s'il y a des policiers
        if #policePlayers > 0 then
            for _, src in ipairs(policePlayers) do
                TriggerClientEvent('police:startVehicleCheck', src)
            end
            Wait(60000) -- Attendre 1 minute
        else
            Wait(300000) -- Attendre 5 minutes si aucun policier
        end
    end
end)