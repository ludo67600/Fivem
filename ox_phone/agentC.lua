-- ox_phone/client/agent.lua
local ESX = exports['es_extended']:getSharedObject()

-- ==========================================
-- VARIABLES LOCALES
-- ==========================================
local canUseAgentApp = false
local agentAppData = nil
local lastNotificationTime = 0
local notificationActive = false

-- ==========================================
-- INITIALISATION
-- ==========================================

-- Initialiser l'application Agent
Citizen.CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end
    
    -- Vérifier si le joueur peut utiliser l'application Agent
    ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, data)
        canUseAgentApp = canUse
        agentAppData = data
        
        -- Si le joueur peut utiliser l'application, mettre à jour l'icône
        if canUse and data and data.icon then
            SendNUIMessage({
                action = 'updateAgentAppIcon',
                icon = data.icon
            })
        end
    end)
end)

-- ==========================================
-- GESTIONNAIRES D'ÉVÉNEMENTS
-- ==========================================

-- Événement lorsque le job du joueur change
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    -- Vérifier si le joueur peut utiliser l'application Agent avec son nouveau job
    ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, data)
        canUseAgentApp = canUse
        agentAppData = data
        
        -- Si le joueur peut utiliser l'application, mettre à jour l'icône
        if canUse and data and data.icon then
            SendNUIMessage({
                action = 'updateAgentAppIcon',
                icon = data.icon
            })
        end
    end)
end)

-- Événement pour les mises à jour du téléphone de service
RegisterNetEvent('ox_phone:servicePhoneUpdate')
AddEventHandler('ox_phone:servicePhoneUpdate', function(data)
    -- Vérifier si les données Agent sont initialisées
    if not agentAppData then return end
    
    -- Mettre à jour les données locales
    if data.job == ESX.GetPlayerData().job.name then
        -- Rafraîchir les données de l'application
        ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, newData)
            canUseAgentApp = canUse
            agentAppData = newData
            
            -- Mettre à jour l'interface NUI si le téléphone est ouvert
            if phoneOpen then
                SendNUIMessage({
                    action = 'updateAgentAppData',
                    data = agentAppData
                })
            end          
        end)
    end
end)

function ShowAgentPublicNotification(jobLabel, message, image)
    if image then
        ShowPhoneNotification(jobLabel, message, 'info', image, 8000, true)
    else
        ShowPhoneNotification(jobLabel, message, 'info', 'fa-bullhorn', 8000)
    end
end

-- Événement pour afficher une notification d'agent
RegisterNetEvent('ox_phone:showAgentNotification')
AddEventHandler('ox_phone:showAgentNotification', function(data)
    -- Vérifier s'il y a un délai minimum entre les notifications
    local currentTime = GetGameTimer()
    if currentTime - lastNotificationTime < (Config.AgentApp.NotificationCooldown * 1000) and notificationActive then
        return
    end
    
    lastNotificationTime = currentTime
    notificationActive = true
    
    -- Créer et afficher la notification NUI personnalisée
-- Afficher la notification unifiée
ShowAgentPublicNotification(data.jobLabel, data.message, data.image)
    
    -- Masquer la notification après 10 secondes
    Citizen.SetTimeout(10000, function()
        SendNUIMessage({
            action = 'hideAgentPublicNotification'
        })
        notificationActive = false
    end)
end)

-- ==========================================
-- CALLBACKS NUI
-- ==========================================

-- Récupérer les données de l'application
RegisterNUICallback('getAgentAppData', function(data, cb)
    -- Vérifier si le joueur peut utiliser l'application
    if not canUseAgentApp then
        cb({success = false, message = "Vous n'êtes pas autorisé à utiliser cette application"})
        return
    end
    
    -- Rafraîchir les données
    ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, newData)
        canUseAgentApp = canUse
        agentAppData = newData
        
        cb({success = true, data = agentAppData})
    end)
end)

-- Prendre le téléphone de service
RegisterNUICallback('takeServicePhone', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:takeServicePhone', function(success, message)
        if success then
            -- Rafraîchir les données
            ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, newData)
                agentAppData = newData
                
                -- Mettre à jour l'interface NUI
                SendNUIMessage({
                    action = 'updateAgentAppData',
                    data = agentAppData
                })
                
                cb({success = true, message = message})
            end)
        else
            cb({success = false, message = message})
        end
    end)
end)

-- Rendre le téléphone de service
RegisterNUICallback('returnServicePhone', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:returnServicePhone', function(success, message)
        if success then
            -- Rafraîchir les données
            ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, newData)
                agentAppData = newData
                
                -- Mettre à jour l'interface NUI
                SendNUIMessage({
                    action = 'updateAgentAppData',
                    data = agentAppData
                })
                
                cb({success = true, message = message})
            end)
        else
            cb({success = false, message = message})
        end
    end)
end)

-- Envoyer une notification d'agent
RegisterNUICallback('sendAgentNotification', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:sendAgentNotification', function(success, message)
        cb({success = success, message = message})
    end, data.type, data.customMessage)
end)