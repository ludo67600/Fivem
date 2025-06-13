-- ox_phone/client/emergency_center.lua
local ESX = exports['es_extended']:getSharedObject()

-- Callback pour obtenir les services d'urgence
RegisterNUICallback('getEmergencyServices', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getEmergencyServices', function(services)
        cb(services)
    end)
end)

-- Callback pour appeler un service d'urgence
RegisterNUICallback('callEmergencyService', function(data, cb)
    local number = data.number
    
    -- Utiliser la fonction d'appel existante
    TriggerEvent('ox_phone:startCall', number)
    
    -- Garder une référence à l'appel actif (comme dans la fonction d'appel normale)
    TriggerEvent('setActiveCall', {
        status = 'outgoing',
        number = number
    })
    
    cb('ok')
end)