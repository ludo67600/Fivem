-- ox_phone/server/emergency_center.lua
local ESX = exports['es_extended']:getSharedObject()

-- Fonction pour obtenir la liste des services
ESX.RegisterServerCallback('ox_phone:getEmergencyServices', function(source, cb)
    local services = Config.EmergencyCenter.Services
    cb(services)
end)