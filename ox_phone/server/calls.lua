-- ox_phone/server/calls.lua
local ESX = exports['es_extended']:getSharedObject()

-- Gestion des appels téléphoniques
local activeCalls = {}

-- Référence aux numéros de téléphone
local phoneNumbers = {}

-- Accès à la variable globale
if _G.phoneNumbers then
    phoneNumbers = _G.phoneNumbers
end

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
    
    print("^2[ox_phone]^7 Call from " .. callerNumber .. " to " .. number)
    
    -- Enregistrer l'appel dans la base de données avec le statut 'outgoing'
local callRecord = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_calls .. 
                                   ' (caller, receiver, status) VALUES (?, ?, ?)', 
                                   {callerNumber, number, 'outgoing'})
    
    -- Vérifier si c'est un numéro d'urgence géré par le centre d'appel
    local isEmergencyHandled = false
    
    -- Si le script centreAppel est disponible, vérifier si c'est un numéro d'urgence qu'il gère
    if GetResourceState('CentreAppel') == 'started' then
        local emergencyConfig = exports['CentreAppel']:getEmergencyConfig(number)
        if emergencyConfig then
            isEmergencyHandled = true
            -- Déclencher l'événement pour que CentreAppel traite l'appel
            TriggerEvent('centreAppel:nouvelAppel', source, number, "Appel d'urgence")
            
            return
        end
    end
    
    -- Logique originale pour les appels normaux
    
    -- Vérifier si c'est un numéro d'urgence non géré par le centre d'appel
    local isEmergency = false
    local emergencyJob = nil
    
    for job, data in pairs(Config.EmergencyNumbers) do
        if data.number == number then
            isEmergency = true
            emergencyJob = job
            break
        end
    end
    
    -- Créer un ID d'appel unique
    local callId = GenerateCallId()
    
    if isEmergency then
        -- Notifier tous les employés du service d'urgence
        local xPlayers = ESX.GetExtendedPlayers('job', emergencyJob)
        local hasRecipients = false
        
        for _, xTarget in pairs(xPlayers) do
            local targetSource = xTarget.source
            local targetNumber = GetPlayerPhoneNumber(targetSource)
            
            if targetNumber then
                hasRecipients = true
                -- Enregistrer l'appel dans la structure activeCalls
                table.insert(activeCalls, {
                    id = callId,
                    caller = source,
                    callerNumber = callerNumber,
                    receiver = targetSource,
                    receiverNumber = targetNumber,
                    status = 'ringing',
                    startTime = os.time(),
                    endTime = nil,
                    emergency = true,
                    emergencyJob = emergencyJob
                })
                
                -- Nom du personnage appelant
                local callerName = xPlayer.getName()
                
                -- Notifier l'opérateur d'urgence
                TriggerClientEvent('ox_phone:incomingCall', targetSource, callId, callerNumber, callerName)
            end
        end
        
        if not hasRecipients then
            -- Pas d'opérateurs en ligne, appel échoué
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Appel',
                description = 'Aucun ' .. Config.EmergencyNumbers[emergencyJob].name .. ' n\'est disponible actuellement',
                type = 'error'
            })
        else
            -- Notifier l'appelant de l'ID d'appel
            TriggerClientEvent('ox_phone:outgoingCallStarted', source, callId, number)
        end
    else
        -- Rechercher le joueur avec ce numéro
        local targetSource = nil
        
        -- Recherche du destinataire par son numéro de téléphone
        for playerSource, playerPhoneNumber in pairs(phoneNumbers) do
            if tostring(playerPhoneNumber) == tostring(number) then
                targetSource = tonumber(playerSource)
                break
            end
        end
        
        -- Si on ne trouve pas, faire une recherche en base de données
        if not targetSource then
            local result = MySQL.query.await('SELECT identifier FROM users WHERE phone_number = ?', {number})
            if result and result[1] then
                local targetPlayer = ESX.GetPlayerFromIdentifier(result[1].identifier)
                if targetPlayer then
                    targetSource = targetPlayer.source
                end
            end
        end
        
        if not targetSource then
            -- Joueur hors ligne ou numéro inexistant
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Appel',
                description = 'Numéro non joignable',
                type = 'error'
            })
            return
        end
        
        -- Vérifier si le destinataire a activé le mode avion ou NPD
        local settings = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_settings .. 
                                         ' WHERE identifier = ?', {ESX.GetPlayerFromId(targetSource).identifier})
        
        if settings and settings[1] and (settings[1].do_not_disturb or settings[1].airplane_mode) then
            -- Le téléphone est en mode silencieux ou avion
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Appel',
                description = 'Aucune réponse',
                type = 'error'
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
        
        print("^2[ox_phone]^7 Notifying receiver " .. targetSource .. " of incoming call")
        
        -- Notifier le destinataire
        TriggerClientEvent('ox_phone:incomingCall', targetSource, callId, callerNumber, callerName)
        
        -- Notifier l'appelant de l'ID d'appel pour qu'il puisse raccrocher
        print("^2[ox_phone]^7 Notifying caller " .. source .. " of call ID: " .. callId)
        TriggerClientEvent('ox_phone:outgoingCallStarted', source, callId, number, callRecord)
        
        -- Envoyer une notification à l'appelant que l'appel est en cours
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Appel',
            description = 'Appel en cours vers ' .. number,
            type = 'inform'
        })
    end
end)

-- Répondre à un appel
RegisterNetEvent('ox_phone:answerCall')
AddEventHandler('ox_phone:answerCall', function(callId)
    local source = source
    print("^2[ox_phone]^7 Answer call request from " .. source .. " for call ID: " .. callId)
    
    -- Vérifier si cet appel est géré par le système de centre d'appel
    if GetResourceState('CentreAppel') == 'started' then
        local centreAppelHandled = false
        
        -- On vérifie d'abord si le centre d'appel gère cet appel
        for i, call in ipairs(activeCalls) do
            if call.id == callId and call.emergency and call.receiver == source then
                -- Cet appel est un appel d'urgence, vérifier si le centre d'appel le gère
                local serviceNumber = nil
                for _, service in pairs(Config.EmergencyNumbers) do
                    if service.job == call.emergencyJob then
                        serviceNumber = service.number
                        break
                    end
                end
                
                if serviceNumber and exports['CentreAppel']:isEmergencyNumber(serviceNumber) then
                    centreAppelHandled = true
                    break
                end
            end
        end
        
        if centreAppelHandled then
            -- Ne rien faire ici, le centre d'appel gère cet appel
            return
        end
    end
    
    -- Logique originale pour les appels normaux
    for i, call in ipairs(activeCalls) do
        if call.id == callId and (call.receiver == source or call.emergency) then
            print("^2[ox_phone]^7 Found call to answer: " .. callId)
            
            -- Mettre à jour le statut
            activeCalls[i].status = 'active'
            activeCalls[i].answeredTime = os.time()
            
            -- Si c'est un appel d'urgence, assigner l'agent à cet appel
            if call.emergency then
                activeCalls[i].assignedTo = source
            end
            
            -- Mettre à jour la base de données - changer le statut de 'outgoing' à 'answered'
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
            ' SET status = ? WHERE id = ?', 
            {'answered', call.callRecordId})

            
            -- Notifier les deux parties
            print("^2[ox_phone]^7 Notifying caller: " .. call.caller)
            TriggerClientEvent('ox_phone:callAnswered', call.caller, callId)
            
            print("^2[ox_phone]^7 Notifying receiver: " .. source)
            TriggerClientEvent('ox_phone:callAnswered', source, callId)
            return
        end
    end
    
    print("^1[ox_phone]^7 Call not found to answer: " .. callId)
end)

-- Rejeter un appel
RegisterNetEvent('ox_phone:rejectCall')
AddEventHandler('ox_phone:rejectCall', function(callId)
    local source = source
    print("^2[ox_phone]^7 Reject call request from " .. source .. " for call ID: " .. callId)
    
    -- Vérifier si cet appel est géré par le système de centre d'appel
    if GetResourceState('CentreAppel') == 'started' then
        local centreAppelHandled = false
        
        -- On vérifie d'abord si le centre d'appel gère cet appel
        for i, call in ipairs(activeCalls) do
            if call.id == callId and call.emergency and call.receiver == source then
                -- Cet appel est un appel d'urgence, vérifier si le centre d'appel le gère
                local serviceNumber = nil
                for _, service in pairs(Config.EmergencyNumbers) do
                    if service.job == call.emergencyJob then
                        serviceNumber = service.number
                        break
                    end
                end
                
                if serviceNumber and exports['CentreAppel']:isEmergencyNumber(serviceNumber) then
                    centreAppelHandled = true
                    break
                end
            end
        end
        
        if centreAppelHandled then
            -- Ne rien faire ici, le centre d'appel gère cet appel
            return
        end
    end
    
    -- Logique originale pour les appels normaux
    for i, call in ipairs(activeCalls) do
        if call.id == callId and (call.receiver == source or call.emergency) then
            print("^2[ox_phone]^7 Found call to reject: " .. callId)
            
            -- Mettre à jour le statut
            activeCalls[i].status = 'rejected'
            activeCalls[i].endTime = os.time()
            
            -- Mettre à jour la base de données - changer le statut de 'outgoing' à 'rejected'
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
            ' SET status = ? WHERE id = ?', 
            {'rejected', call.callRecordId})

            
            -- Notifier l'appelant
            print("^2[ox_phone]^7 Notifying caller of rejection: " .. call.caller)
            TriggerClientEvent('ox_phone:callRejected', call.caller, callId)
            
            -- Si c'est un appel d'urgence, essayer avec un autre agent
            if call.emergency and not call.assignedTo then
                local xPlayers = ESX.GetExtendedPlayers('job', call.emergencyJob)
                local hasRecipients = false
                
                for _, xTarget in pairs(xPlayers) do
                    local targetSource = xTarget.source
                    if targetSource ~= source then -- Ne pas réessayer avec le même agent
                        local targetNumber = GetPlayerPhoneNumber(targetSource)
                        
                        if targetNumber then
                            hasRecipients = true
                            
                            -- Créer un nouvel appel
                            local newCallId = GenerateCallId()
                            table.insert(activeCalls, {
                                id = newCallId,
                                caller = call.caller,
                                callerNumber = call.callerNumber,
                                receiver = targetSource,
                                receiverNumber = targetNumber,
                                status = 'ringing',
                                startTime = os.time(),
                                endTime = nil,
                                emergency = true,
                                emergencyJob = call.emergencyJob
                            })
                            
                            -- Nom du personnage appelant
                            local callerName = ESX.GetPlayerFromId(call.caller).getName()
                            
                            -- Notifier le nouvel agent
                            TriggerClientEvent('ox_phone:incomingCall', targetSource, newCallId, call.callerNumber, callerName)
                            break -- On essaie avec un seul autre agent
                        end
                    end
                end
            end
            
            -- Supprimer l'appel de la liste active
            table.remove(activeCalls, i)
            return
        end
    end
    
    print("^1[ox_phone]^7 Call not found to reject: " .. callId)
end)

-- Terminer un appel
RegisterNetEvent('ox_phone:endCall')
AddEventHandler('ox_phone:endCall', function(callData)
    local source = source
    print("^2[ox_phone]^7 End call request from " .. source)
    
    local callId = nil
    local targetNumber = nil
    
    -- Supporter les deux formats (ID simple ou objet avec ID et numéro)
    if type(callData) == "table" then
        callId = callData.id
        targetNumber = callData.number
        print("^2[ox_phone]^7 Call data: ID=" .. tostring(callId) .. ", Number=" .. tostring(targetNumber))
    else
        callId = callData
        print("^2[ox_phone]^7 Call data: ID=" .. tostring(callId))
    end
    
    -- Si nous n'avons pas d'ID d'appel mais un numéro cible, essayez de trouver l'appel par numéro
    if not callId and targetNumber then
        for i, call in ipairs(activeCalls) do
            if (call.caller == source and call.receiverNumber == targetNumber) or 
               (call.receiver == source and call.callerNumber == targetNumber) then
                callId = call.id
                print("^2[ox_phone]^7 Found call by number: " .. callId)
                break
            end
        end
    end
    
    -- Si toujours pas d'ID, rechercher basé uniquement sur la source
    if not callId then
        for i, call in ipairs(activeCalls) do
            if call.caller == source or call.receiver == source then
                callId = call.id
                print("^2[ox_phone]^7 Found call by source: " .. callId)
                break
            end
        end
    end
    
    if not callId then
        print("^1[ox_phone]^7 No call ID found. Cannot end call.")
        return
    end
    
    -- Vérifier si cet appel est géré par le système de centre d'appel
    if GetResourceState('CentreAppel') == 'started' then
        -- On laisse le centre d'appel gérer aussi ce cas pour ses propres appels
    end
    
    -- Logique pour les appels normaux
    for i, call in ipairs(activeCalls) do
        if call.id == callId and (call.caller == source or call.receiver == source or call.assignedTo == source) then
            print("^2[ox_phone]^7 Found call to end: " .. callId)
            
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
                print("^2[ox_phone]^7 Notifying receiver of call end: " .. call.receiver)
                TriggerClientEvent('ox_phone:callEnded', call.receiver, callId)
            else
                print("^2[ox_phone]^7 Notifying caller of call end: " .. call.caller)
                TriggerClientEvent('ox_phone:callEnded', call.caller, callId)
            end
            
            -- Supprimer l'appel de la liste active
            table.remove(activeCalls, i)
            return
        end
    end
    
    print("^1[ox_phone]^7 Call not found to end: " .. callId)
end)

-- Synchroniser le canal d'appel entre les joueurs
RegisterNetEvent('ox_phone:syncCallChannel')
AddEventHandler('ox_phone:syncCallChannel', function(targetId, channelId)
    local source = source
    print("^2[ox_phone]^7 SyncCallChannel request from " .. source .. " to " .. targetId .. " on channel " .. channelId)
    
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
        print("^2[ox_phone]^7 Notifying target to join call channel: " .. targetId)
        TriggerClientEvent('ox_phone:joinCallChannel', targetId, channelId)
    else
        print("^1[ox_phone]^7 Invalid call sync request")
    end
end)

-- Notifier qu'un joueur a quitté le canal d'appel
RegisterNetEvent('ox_phone:leaveCallChannel')
AddEventHandler('ox_phone:leaveCallChannel', function(targetId)
    local source = source
    print("^2[ox_phone]^7 LeaveCallChannel notification from " .. source .. " to " .. targetId)
    
    -- Notifier l'autre joueur que nous avons quitté le canal
    TriggerClientEvent('ox_phone:otherPlayerLeftCall', targetId)
end)

-- Callback pour récupérer l'ID du joueur à l'autre bout de l'appel
ESX.RegisterServerCallback('ox_phone:getCallTargetId', function(source, cb, callId)
    print("^2[ox_phone]^7 GetCallTargetId request for call ID: " .. callId)
    
    -- Rechercher l'appel dans les appels actifs
    for _, call in ipairs(activeCalls) do
        if call.id == callId then
            if call.caller == source then
                -- L'appelant est notre source, donc la cible est le destinataire
                print("^2[ox_phone]^7 Returning target ID (receiver): " .. call.receiver)
                cb(call.receiver)
                return
            elseif call.receiver == source then
                -- Le destinataire est notre source, donc la cible est l'appelant
                print("^2[ox_phone]^7 Returning target ID (caller): " .. call.caller)
                cb(call.caller)
                return
            end
        end
    end
    
    -- Si on arrive ici, on n'a pas trouvé l'appel
    print("^1[ox_phone]^7 Call not found for getCallTargetId: " .. callId)
    cb(nil)
end)

-- Fonction d'export pour vérifier si un appel d'urgence est actif
exports('hasActiveEmergencyCall', function(serviceNumber)
    for _, call in ipairs(activeCalls) do
        if call.status == 'ringing' and call.emergency then
            -- Vérifier si ce service gère ce numéro d'urgence
            local service = Config.EmergencyNumbers[call.emergencyJob]
            if service and service.number == serviceNumber then
                return true
            end
        end
    end
    return false
end)

-- Fonction d'export pour vérifier si un numéro est un numéro d'urgence
exports('isEmergencyNumber', function(number)
    for _, data in pairs(Config.EmergencyNumbers) do
        if data.number == number then
            return true
        end
    end
    return false
end)

-- Partager les appels actifs avec d'autres ressources
_G.activeCalls = activeCalls