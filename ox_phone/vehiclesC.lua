-- ox_phone/client/vehicles.lua
local ESX = exports['es_extended']:getSharedObject()

-- Table pour suivre les véhicules déjà traités
local trackedVehicles = {}

-- Enregistrer la position du véhicule lorsqu'on le quitte
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            -- Vérifier si c'est le conducteur
            if GetPedInVehicleSeat(vehicle, -1) == playerPed then
                -- Mémoriser le véhicule et sa plaque
                local lastVehicle = vehicle
                local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
                
                -- Vérifier si le joueur quitte le véhicule
                Citizen.CreateThread(function()
                    local stillInVehicle = true
                    
                    while stillInVehicle do
                        Citizen.Wait(1000)
                        
                        if not IsPedInVehicle(playerPed, lastVehicle, false) then
                            stillInVehicle = false
                            
                            -- Sauvegarder la position du véhicule s'il existe encore
                            if DoesEntityExist(lastVehicle) then
                                local coords = GetEntityCoords(lastVehicle)
                                
                                -- S'assurer que le véhicule est toujours là et n'est pas conduit par quelqu'un d'autre
                                if DoesEntityExist(lastVehicle) and IsVehicleSeatFree(lastVehicle, -1) then
                                    TriggerServerEvent('ox_phone:saveVehiclePosition', plate, {
                                        x = coords.x,
                                        y = coords.y,
                                        z = coords.z
                                    })
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end)

-- Thread additionnel pour détecter tous les véhicules abandonnés dans la zone
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Vérifier toutes les 5 secondes
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Chercher tous les véhicules dans un rayon de 50 mètres
        local vehicles = ESX.Game.GetVehiclesInArea(playerCoords, 50.0)
        
        for _, vehicle in pairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
                
                -- Vérifier si le véhicule est vide (aucun joueur dedans)
                local isEmpty = true
                for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
                    if not IsVehicleSeatFree(vehicle, seat) then
                        local occupant = GetPedInVehicleSeat(vehicle, seat)
                        if IsPedAPlayer(occupant) then
                            isEmpty = false
                            break
                        end
                    end
                end
                
                -- Si le véhicule est vide et n'a pas été traité récemment
                if isEmpty and not trackedVehicles[plate] then
                    local coords = GetEntityCoords(vehicle)
                    
                    -- Marquer ce véhicule comme traité pour éviter les doublons
                    trackedVehicles[plate] = GetGameTimer()
                    
                    -- Envoyer la position au serveur
                    TriggerServerEvent('ox_phone:saveVehiclePosition', plate, {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    })
                end
            end
        end
        
        -- Nettoyer les véhicules traités après 60 secondes
        local currentTime = GetGameTimer()
        for plate, time in pairs(trackedVehicles) do
            if currentTime - time > 60000 then -- 60 secondes
                trackedVehicles[plate] = nil
            end
        end
    end
end)