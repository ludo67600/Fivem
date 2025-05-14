-- J_PoliceNat client/vehicles.lua
local ESX = exports["es_extended"]:getSharedObject()

-- Variables locales
local currentTask = false

-- =============================================
-- Menu principal des interactions avec véhicules
-- =============================================
function OpenVehicleInteractionMenu()
    local elements = {
        {
            title = 'Vérifier le véhicule',
            description = 'Vérifier les informations du véhicule',
            icon = 'magnifying-glass',
            onSelect = function()
                CheckVehicleAction()
            end
        },
        {
            title = 'Mettre en fourrière',
            description = 'Envoyer le véhicule à la fourrière',
            icon = 'truck-tow',
            onSelect = function()
                ImpoundAction()
            end
        },
        {
            title = 'Déverrouiller',
            description = 'Déverrouiller un véhicule',
            icon = 'unlock',
            onSelect = function()
                UnlockAction()
            end
        },
        {
            title = 'Marquer comme retrouvé',
            description = 'Marquer un véhicule volé comme retrouvé',
            icon = 'car-on',
            onSelect = function()
                RecoverVehicleAction()
            end
        }
    }

    lib.registerContext({
        id = 'police_vehicle_menu',
        title = 'Interactions Véhicules',
        options = elements
    })

    lib.showContext('police_vehicle_menu')
end

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Obtenir le véhicule ciblé
function GetVehicleInDirection()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local endCoords = playerCoords + (forward * 5.0)

    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        playerCoords.x, playerCoords.y, playerCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        10, playerPed, 0
    )

    local _, hit, _, _, vehicle = GetShapeTestResult(rayHandle)

    if hit and DoesEntityExist(vehicle) then
        return vehicle
    end

    return nil
end

-- Spawn d'un véhicule de police
function SpawnPoliceVehicle(model)
    local playerPed = PlayerPedId()
    
    -- Vérifier si nous avons des points de spawn configurés
    if Config.Locations.garage and Config.Locations.garage.vehicleSpawnPoints and #Config.Locations.garage.vehicleSpawnPoints > 0 then
        -- Vérifier si le point de spawn est libre
        local spawnPoint = Config.Locations.garage.vehicleSpawnPoints[1]
        local isOccupied = IsPositionOccupied(spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, 2.0, false, true, true, false, false, 0, false)
        
        if isOccupied then
            -- Si la place est occupée, afficher un message d'erreur avec une image
     exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'La zone de stationnement est occupée. Dégagez la zone pour sortir un véhicule.',
    title = 'Garage Police Nationale',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end
        
        -- Si la place est libre, on sort le véhicule
        ESX.Game.SpawnVehicle(model, vector3(spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z), spawnPoint.heading, function(vehicle)
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            SetVehicleExtra(vehicle, 1, false)
            SetVehicleExtra(vehicle, 2, false)
            SetVehicleExtra(vehicle, 3, false)
            SetVehicleExtra(vehicle, 4, false)
            SetVehicleExtra(vehicle, 5, false)
            SetVehicleExtra(vehicle, 6, false)
            SetVehicleExtra(vehicle, 7, false)
            SetVehicleExtra(vehicle, 8, false)
            SetVehicleExtra(vehicle, 9, false)
            SetVehicleExtra(vehicle, 10, false)
            SetVehicleExtra(vehicle, 11, false)
            SetVehicleExtra(vehicle, 12, false)
            SetVehicleLivery(vehicle, 0)
            SetVehicleMod(vehicle, 48, 0, false)
            
            exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule de service sorti',
    title = 'Garage Police Nationale',
    image = 'img/policenat.png',
    duration = 5000
})

        end)
    else
        -- Si aucun point de spawn n'est configuré
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun point de stationnement n\'est configuré',
    title = 'Garage Police Nationale',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end

-- =============================================
-- Actions pour les véhicules
-- =============================================

-- Récupérer un véhicule volé
function RecoverVehicleAction()
    local vehicle = GetVehicleInDirection()
    if not vehicle then
	exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    
    -- Vérifier si le véhicule est signalé comme volé
    ESX.TriggerServerCallback('police:checkVehicleStatus', function(isStolen)
        if not isStolen then
            exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Ce véhicule n\'est pas signalé comme volé',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end
        
        local alert = lib.alertDialog({
            header = 'Véhicule retrouvé',
            content = 'Voulez-vous marquer le véhicule ' .. plate .. ' comme retrouvé?',
            centered = true,
            cancel = true
        })

        if alert == 'confirm' then
            TriggerServerEvent('police:recoverStolenVehicle', plate, true)
        end
    end, plate)
end

-- Action Vérifier le véhicule
function CheckVehicleAction()
    local vehicle = GetVehicleInDirection()
    if not vehicle then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    currentTask = true

    if lib.progressBar({
        duration = 2000,
        label = 'Vérification du véhicule...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'amb@code_human_police_investigate@idle_b',
            clip = 'idle_f',
            flags = 51
        },
    }) then
        TriggerServerEvent('police:checkVehicle', plate)
    end

    currentTask = false
end

-- Action Mise en fourrière
function ImpoundAction() 
    local vehicle = GetVehicleInDirection()
    if not vehicle then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})
        return
    end

    local alert = lib.alertDialog({
        header = 'Confirmation fourrière',
        content = 'Voulez-vous mettre ce véhicule en fourrière ?',
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        local plate = GetVehicleNumberPlateText(vehicle)
        local networkId = NetworkGetNetworkIdFromEntity(vehicle) -- Récupérer l'ID réseau
        currentTask = true

        if lib.progressBar({
            duration = Config.Animations.impound,
            label = 'Mise en fourrière...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_ped',
                flags = 49
            },
        }) then
            TriggerServerEvent('police:impoundVehicle', plate, GetEntityCoords(vehicle), networkId)
            exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule mis en fourrière',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        end

        currentTask = false
    end
end

-- Action Déverrouillage
function UnlockAction()
    local vehicle = GetVehicleInDirection()
    if not vehicle then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})
        return
    end

    currentTask = true

    if lib.progressBar({
        duration = Config.Animations.unlock,
        label = 'Déverrouillage du véhicule...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer',
            flags = 49
        },
    }) then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
       exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule déverrouillé',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})


        -- Effet visuel
        local coords = GetEntityCoords(vehicle)
        local hash = GetHashKey('prop_cs_cardigan')
        
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(0)
        end
        
        local prop = CreateObject(hash, coords.x, coords.y, coords.z + 2.0, true, true, true)
        PlaceObjectOnGroundProperly(prop)
        SetModelAsNoLongerNeeded(hash)
        Wait(2000)
        DeleteEntity(prop)
    end

    currentTask = false
end

-- Action Signaler véhicule volé
function ReportStolenVehicleAction()
    local vehicle = GetVehicleInDirection()
    if not vehicle then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local alert = lib.alertDialog({
        header = 'Signalement de véhicule volé',
        content = 'Voulez-vous signaler le véhicule ' .. plate .. ' comme volé?',
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent('police:reportStolenVehicle', plate, GetEntityCoords(vehicle))
exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule signalé comme volé',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end

-- =============================================
-- Gestion du garage de véhicules de service
-- =============================================

-- Garage véhicules de service
function OpenGarageMenu()
    local elements = {}
    
    for _, vehicle in ipairs(Config.Vehicles) do
        if HasMinimumGrade(vehicle.minGrade) then
            table.insert(elements, {
                title = vehicle.label,
                description = 'Sortir ce véhicule',
                onSelect = function()
                    SpawnPoliceVehicle(vehicle.model)
                end
            })
        end
    end

    table.insert(elements, {
        title = 'Ranger le véhicule',
        description = 'Ranger le véhicule de service',
        onSelect = function()
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle ~= 0 then
                ESX.Game.DeleteVehicle(vehicle)
exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule rangé',
    title = 'Garage Police',
    image = 'img/policenat.png',
    duration = 5000
})

            end
        end
    })

    lib.registerContext({
        id = 'police_garage',
        title = 'Garage Police',
        options = elements
    })

    lib.showContext('police_garage')
end

-- =============================================
-- Fonction pour les véhicules volés
-- =============================================

-- Fonction pour voir la liste des véhicules volés
function OpenStolenVehiclesListMenu()
    ESX.TriggerServerCallback('police:getStolenVehicles', function(vehicles)
        local elements = {}
        
        if #vehicles == 0 then
            table.insert(elements, {
                title = 'Aucun véhicule volé',
                description = 'Aucun véhicule n\'est actuellement signalé comme volé',
                disabled = true
            })
        else
            for _, vehicle in ipairs(vehicles) do
                local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle.model)))
                if vehicleName == 'NULL' then
                    vehicleName = vehicle.vehicle.model
                end
                
                table.insert(elements, {
                    title = vehicleName .. ' [' .. vehicle.plate .. ']',
                    description = 'Propriétaire: ' .. (vehicle.owner_name or 'Inconnu'),
                    icon = 'car-burst',
                    onSelect = function()
                        local options = {
                            {
                                title = 'Marquer comme retrouvé',
                                description = 'Signaler que ce véhicule a été retrouvé',
                                icon = 'car-on',
                                onSelect = function()
                                    TriggerServerEvent('police:recoverStolenVehicle', vehicle.plate, true)
                                    Wait(500)
                                    OpenStolenVehiclesListMenu()
                                end
                            }
                        }
                        
                        lib.registerContext({
                            id = 'stolen_vehicle_options',
                            title = 'Options pour ' .. vehicle.plate,
                            menu = 'stolen_vehicles_list',
                            options = options
                        })
                        
                        lib.showContext('stolen_vehicle_options')
                    end
                })
            end
        end

        lib.registerContext({
            id = 'stolen_vehicles_list',
            title = 'Véhicules signalés volés',
            options = elements
        })

        lib.showContext('stolen_vehicles_list')
    end)
end

-- =============================================
-- Events
-- =============================================

-- Event pour recevoir les infos du véhicule
RegisterNetEvent('police:receiveVehicleInfo')
AddEventHandler('police:receiveVehicleInfo', function(data) 
    if not data then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucune information trouvée',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Debug
    print("Données reçues du véhicule:")
    print("Plaque: " .. data.plate)
    print("Statut volé (type): " .. type(data.stolen))
    print("Statut volé (valeur): " .. tostring(data.stolen))

    -- Correction du formatage du statut
    local statusValue = ""
    if data.stolen == true then
        statusValue = "SIGNALÉ VOLÉ"
    else
        statusValue = "En règle"
    end

    local elements = {
        {
            title = 'Informations du véhicule',
            description = ('Plaque: %s'):format(data.plate),
            metadata = {
                {label = 'Propriétaire', value = data.owner or 'Inconnu'},
                {label = 'Modèle', value = data.model or 'Inconnu'},
                {label = 'Statut', value = statusValue}
            }
        }
    }
    -- Ajouter une option pour marquer comme retrouvé si le véhicule est volé
    if data.stolen then
        table.insert(elements, {
            title = 'Marquer comme retrouvé',
            description = 'Signaler que ce véhicule a été retrouvé',
            icon = 'car-on',
            onSelect = function()
                TriggerServerEvent('police:recoverStolenVehicle', data.plate, true)
            end
        })
    end

    lib.registerContext({
        id = 'police_vehicle_info',
        title = 'Informations Véhicule',
        options = elements
    })

    lib.showContext('police_vehicle_info')
end)

-- Événement pour supprimer un véhicule pour tous les joueurs
RegisterNetEvent('police:deleteVehicleForAll')
AddEventHandler('police:deleteVehicleForAll', function(networkId)
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    
    if DoesEntityExist(vehicle) then
        -- Ne supprime que si le véhicule existe réellement pour ce client
        DeleteEntity(vehicle)
    end
end)

-- Fonction pour scanner les véhicules à proximité
RegisterNetEvent('police:startVehicleCheck')
AddEventHandler('police:startVehicleCheck', function()
    -- Ne vérifier que si le joueur est policier et en service
    if not IsOnDuty() then return end
    
    CreateThread(function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local vehicles = GetGamePool('CVehicle') -- Récupère tous les véhicules dans le monde
        local nearbyPlates = {}
        
        for _, vehicle in ipairs(vehicles) do
            local distance = #(playerCoords - GetEntityCoords(vehicle))
            -- Vérifier uniquement les véhicules dans un rayon de 30m
            if distance <= 30.0 then
                local plate = GetVehicleNumberPlateText(vehicle)
                if plate and plate ~= "" then
                    -- Stocker la plaque et les coordonnées du véhicule
                    nearbyPlates[plate] = GetEntityCoords(vehicle)
                end
            end
        end
        
        -- Envoyer les plaques au serveur pour vérification
        if next(nearbyPlates) then -- Si la table n'est pas vide
            TriggerServerEvent('police:checkNearbyVehicles', nearbyPlates)
        end
    end)
end)

-- Gestion des notifications de véhicule volé
RegisterNetEvent('police:vehicleStolenNotify')
AddEventHandler('police:vehicleStolenNotify', function(coords)
    if not coords then return end
    
    -- Notification
exports['jl_notifications']:ShowNotification({
    type = 'warning',
    message = 'Un véhicule volé a été détecté à proximité',
    title = 'Véhicule volé',
    image = 'img/policenat.png',
    duration = 10000
})

    
    -- Créer un blip sur la carte
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 225) -- Sprite de voiture
    SetBlipColour(blip, 1) -- Rouge
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Véhicule volé')
    EndTextCommandSetBlipName(blip)
    
    -- Supprimer le blip après 60 secondes
    SetTimeout(60000, function()
        RemoveBlip(blip)
    end)
end)

-- =============================================
-- Ajout des options ox_target
-- =============================================

-- Ajout des options ox_target pour les véhicules
exports.ox_target:addGlobalVehicle({
    {
        name = 'police_check_vehicle',
        icon = 'fa-solid fa-magnifying-glass',
        label = 'Vérifier le véhicule',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return IsOnDuty()
        end,
        onSelect = function(data)
            CheckVehicleAction()
        end
    },
    {
        name = 'police_impound_vehicle',
        icon = 'fa-solid fa-truck-tow',
        label = 'Mettre en fourrière',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return IsOnDuty()
        end,
        onSelect = function(data)
            ImpoundAction()
        end
    },
    {
        name = 'police_unlock_vehicle',
        icon = 'fa-solid fa-unlock',
        label = 'Déverrouiller',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return IsOnDuty()
        end,
        onSelect = function(data)
            UnlockAction()
        end
    },
    {
        name = 'police_recover_vehicle',
        icon = 'fa-solid fa-car-on',
        label = 'Marquer comme retrouvé',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return IsOnDuty()
        end,
        onSelect = function(data)
            local plate = GetVehicleNumberPlateText(data.entity)
            
            ESX.TriggerServerCallback('police:checkVehicleStatus', function(isStolen)
                if not isStolen then
				
				exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Ce véhicule n\'est pas signalé comme volé',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

                    return
                end
                
                local alert = lib.alertDialog({
                    header = 'Véhicule retrouvé',
                    content = 'Voulez-vous marquer le véhicule ' .. plate .. ' comme retrouvé?',
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('police:recoverStolenVehicle', plate, true)
                end
            end, plate)
        end
    },
    {
        name = 'police_report_stolen',
        icon = 'fa-solid fa-car-burst',
        label = 'Signaler comme volé',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return IsOnDuty()
        end,
        onSelect = function(data)
            local plate = GetVehicleNumberPlateText(data.entity)
            local alert = lib.alertDialog({
                header = 'Signalement de véhicule volé',
                content = 'Voulez-vous signaler le véhicule ' .. plate .. ' comme volé?',
                centered = true,
                cancel = true
            })

            if alert == 'confirm' then
                TriggerServerEvent('police:reportStolenVehicle', plate, GetEntityCoords(data.entity))
				
				
				exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Véhicule signalé comme volé',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

            end
        end
    }
})

-- Export de la fonction SpawnPoliceVehicle
exports('SpawnPoliceVehicle', SpawnPoliceVehicle)