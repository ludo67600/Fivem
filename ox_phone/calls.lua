-- ox_phone/server/calls.lua
local ESX = exports['es_extended']:getSharedObject()

-- ==========================================
-- INITIALISATION DES VARIABLES GLOBALES
-- ==========================================

-- Gestion des appels téléphoniques
local activeCalls = {}

-- Référence aux numéros de téléphone
local phoneNumbers = {}

-- Accès à la variable globale
if _G.phoneNumbers then
    phoneNumbers = _G.phoneNumbers
end

-- ==========================================
-- FONCTIONS UTILITAIRES
-- ==========================================

-- Fonction pour obtenir le numéro de téléphone (fallback si l'export échoue)
local function GetPlayerPhoneNumber(source)
    -- D'abord essayer d'utiliser l'export
    local number = exports['ox_phone']:GetPhoneNumber(source)
    if number then 
        return number 
    end
    
    -- Fallback: vérifier dans la table locale
    if phoneNumbers[source] then
        return phoneNumbers[source]
    end
    
    -- Dernier recours: chercher directement dans la base de données
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local result = MySQL.query.await('SELECT phone_number FROM users WHERE identifier = ?', {xPlayer.identifier})
        if result and result[1] and result[1].phone_number then
            phoneNumbers[source] = result[1].phone_number
            return result[1].phone_number
        end
    end
    
    return nil
end

-- Générer un ID d'appel unique
local function GenerateCallId()
    return os.time() .. math.random(1000, 9999)
end

-- Fonction pour insérer un enregistrement d'appel dans la base de données
function InsertCallRecord(caller, receiver, status, duration)
    duration = duration or 0
    
    MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_calls .. 
                     ' (caller, receiver, status, duration) VALUES (?, ?, ?, ?)', 
                     {caller, receiver, status, duration})
end

-- ==========================================
-- GESTION DES APPELS
-- ==========================================

-- Démarrer un appel
RegisterNetEvent('ox_phone:startCall')
AddEventHandler('ox_phone:startCall', function(number)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return
    end
    
    local callerNumber = GetPlayerPhoneNumber(source)
    
    if not callerNumber then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Téléphone',
            description = 'Erreur: Numéro de téléphone non disponible',
            type = 'error'
        })
        return
    end
    
    -- Enregistrer l'appel dans la base de données avec le statut 'outgoing'
    local callRecord = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_calls .. 
                                   ' (caller, receiver, status) VALUES (?, ?, ?)', 
                                   {callerNumber, number, 'outgoing'})
    
    -- Créer un ID d'appel unique
    local callId = GenerateCallId()
    
    -- Rechercher le joueur avec ce numéro en utilisant la nouvelle fonction
    local targetSource = exports['ox_phone']:GetPlayerByPhoneNumber(number)
    
    if not targetSource then
        -- Joueur hors ligne ou numéro inexistant
TriggerClientEvent('ox_phone:showNotification', source, {
    title = 'Appel', 
    message = 'Numéro non joignable', 
    type = 'error', 
    icon = 'fa-phone-slash'
})        
return
    end
    
    -- Vérifier si le destinataire a activé le mode avion ou NPD
    local settings = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_settings .. 
                                     ' WHERE identifier = ?', {ESX.GetPlayerFromId(targetSource).identifier})
    
    if settings and settings[1] and (settings[1].do_not_disturb or settings[1].airplane_mode) then
        -- Le téléphone est en mode silencieux ou avion
		
		
TriggerClientEvent('ox_phone:showNotification', source, {
    title = 'Appel', 
    message = 'Aucune réponse', 
    type = 'error', 
    icon = 'fa-phone-slash'
})
        return
    end
    
    -- Enregistrer l'appel dans la structure activeCalls
    table.insert(activeCalls, {
        id = callId,
        callRecordId = callRecord, -- L'ID de l'enregistrement dans la base de données
        caller = source,
        callerNumber = callerNumber,
        receiver = targetSource,
        receiverNumber = number,
        status = 'ringing',
        startTime = os.time(),
        endTime = nil
    })
    
    -- Nom du personnage appelant pour afficher au destinataire
    local callerName = exports['ox_phone']:GetContactName(targetSource, callerNumber)
    if not callerName or callerName == callerNumber then
        callerName = xPlayer.getName()
    end
    
    -- Notifier le destinataire AVEC FORCE
    TriggerClientEvent('ox_phone:incomingCall', targetSource, callId, callerNumber, callerName)
    
    -- Notifier l'appelant de l'ID d'appel pour qu'il puisse raccrocher
    TriggerClientEvent('ox_phone:outgoingCallStarted', source, callId, number, callRecord)
    
    -- Envoyer une notification à l'appelant que l'appel est en cours
TriggerClientEvent('ox_phone:showNotification', source, {
    title = 'Appel', 
    message = 'Appel en cours vers ' .. number, 
    type = 'info', 
    icon = 'fa-phone'
})
end)

-- Répondre à un appel
RegisterNetEvent('ox_phone:answerCall')
AddEventHandler('ox_phone:answerCall', function(callId)
    local source = source
    
    for i, call in ipairs(activeCalls) do
        if call.id == callId and call.receiver == source then
            -- Mettre à jour le statut
            activeCalls[i].status = 'active'
            activeCalls[i].answeredTime = os.time()
            
            -- Mettre à jour la base de données - changer le statut de 'outgoing' à 'answered'
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                        ' SET status = ? WHERE id = ?', 
                        {'answered', call.callRecordId})
            
            -- Notifier les deux parties
            TriggerClientEvent('ox_phone:callAnswered', call.caller, callId)
            TriggerClientEvent('ox_phone:callAnswered', source, callId)
            return
        end
    end
end)

-- Rejeter un appel
RegisterNetEvent('ox_phone:rejectCall')
AddEventHandler('ox_phone:rejectCall', function(callId)
    local source = source
    
    for i, call in ipairs(activeCalls) do
        if call.id == callId and call.receiver == source then
            -- Mettre à jour le statut
            activeCalls[i].status = 'rejected'
            activeCalls[i].endTime = os.time()
            
            -- Mettre à jour la base de données - changer le statut de 'outgoing' à 'rejected'
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                        ' SET status = ? WHERE id = ?', 
                        {'rejected', call.callRecordId})
            
            -- Notifier l'appelant
            TriggerClientEvent('ox_phone:callRejected', call.caller, callId)
            
            -- Supprimer l'appel de la liste active
            table.remove(activeCalls, i)
            return
        end
    end
end)

-- Terminer un appel
RegisterNetEvent('ox_phone:endCall')
AddEventHandler('ox_phone:endCall', function(callData)
    local source = source
    
    local callId = nil
    local targetNumber = nil
    
    -- Supporter les deux formats (ID simple ou objet avec ID et numéro)
    if type(callData) == "table" then
        callId = callData.id
        targetNumber = callData.number
    else
        callId = callData
    end
    
    -- Si nous n'avons pas d'ID d'appel mais un numéro cible, essayez de trouver l'appel par numéro
    if not callId and targetNumber then
        for i, call in ipairs(activeCalls) do
            if (call.caller == source and call.receiverNumber == targetNumber) or 
               (call.receiver == source and call.callerNumber == targetNumber) then
                callId = call.id
                break
            end
        end
    end
    
    -- Si toujours pas d'ID, rechercher basé uniquement sur la source
    if not callId then
        for i, call in ipairs(activeCalls) do
            if call.caller == source or call.receiver == source then
                callId = call.id
                break
            end
        end
    end
    
    if not callId then
        return
    end
    
    for i, call in ipairs(activeCalls) do
        if call.id == callId and (call.caller == source or call.receiver == source) then
            -- Calculer la durée de l'appel
            local duration = 0
            if call.status == 'active' and call.answeredTime then
                duration = os.time() - call.answeredTime
            end
            
            -- Mettre à jour la base de données - changer le statut à 'ended' et enregistrer la durée
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                        ' SET status = ?, duration = ? WHERE id = ?', 
                        {'ended', duration, call.callRecordId})
            
            -- Notifier l'autre partie
            if call.caller == source then
                TriggerClientEvent('ox_phone:callEnded', call.receiver, callId)
            else
                TriggerClientEvent('ox_phone:callEnded', call.caller, callId)
            end
            
            -- Supprimer l'appel de la liste active
            table.remove(activeCalls, i)
            return
        end
    end
end)

-- ==========================================
-- SYNCHRONISATION DE LA VOIX
-- ==========================================

-- Synchroniser le canal d'appel entre les joueurs
RegisterNetEvent('ox_phone:syncCallChannel')
AddEventHandler('ox_phone:syncCallChannel', function(targetId, channelId)
    local source = source
    
    -- Vérifier que l'appel est légitime
    local isValidCall = false
    for _, call in pairs(activeCalls) do
        if (call.caller == source and call.receiver == targetId) or 
           (call.caller == targetId and call.receiver == source) then
            isValidCall = true
            break
        end
    end
    
    if isValidCall then
        -- Notifier l'autre joueur de rejoindre le même canal d'appel
        TriggerClientEvent('ox_phone:joinCallChannel', targetId, channelId)
    end
end)

-- Notifier qu'un joueur a quitté le canal d'appel
RegisterNetEvent('ox_phone:leaveCallChannel')
AddEventHandler('ox_phone:leaveCallChannel', function(targetId)
    local source = source
    
    -- Notifier l'autre joueur que nous avons quitté le canal
    TriggerClientEvent('ox_phone:otherPlayerLeftCall', targetId)
end)

-- ==========================================
-- CALLBACKS
-- ==========================================

-- Callback pour récupérer l'ID du joueur à l'autre bout de l'appel
ESX.RegisterServerCallback('ox_phone:getCallTargetId', function(source, cb, callId)
    -- Rechercher l'appel dans les appels actifs
    for _, call in ipairs(activeCalls) do
        if call.id == callId then
            if call.caller == source then
                -- L'appelant est notre source, donc la cible est le destinataire
                cb(call.receiver)
                return
            elseif call.receiver == source then
                -- Le destinataire est notre source, donc la cible est l'appelant
                cb(call.caller)
                return
            end
        end
    end
    
    -- Si on arrive ici, on n'a pas trouvé l'appel
    cb(nil)
end)

-- ==========================================
-- EXPORT
-- ==========================================

-- Partager les appels actifs avec d'autres ressources
_G.activeCalls = activeCalls