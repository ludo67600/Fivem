-- ox_phone/server/vehicles.lua
local ESX = exports['es_extended']:getSharedObject()

-- Enregistrer l'événement pour sauvegarder la position du véhicule
RegisterServerEvent('ox_phone:saveVehiclePosition')
AddEventHandler('ox_phone:saveVehiclePosition', function(plate, position)
    local source = source
    
    -- Vérifier que le véhicule existe dans la base de données (peut appartenir à n'importe qui)
    local vehicle = MySQL.query.await('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate})
    
    if vehicle and vehicle[1] then
        -- Le véhicule existe, mettre à jour sa position peu importe qui l'a conduit
        MySQL.update('UPDATE owned_vehicles SET position = ?, stored = 0 WHERE plate = ?', 
                    {json.encode(position), plate})
        
        -- Optionnel : Log pour debug
        -- print("^2[ox_phone:vehicles]^7 Position mise à jour pour le véhicule " .. plate .. " par le joueur " .. source)
    end
end)