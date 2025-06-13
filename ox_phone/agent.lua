-- ox_phone/server/agent.lua
local ESX = exports['es_extended']:getSharedObject()

-- Table pour suivre les redirections d'appels en cours
local pendingRedirects = {}

-- Table pour suivre les dernières notifications par joueur
local playerLastNotifications = {}

-- Fonction pour vérifier si une notification est un doublon
local function isNotificationDuplicate(playerId, jobLabel, message)
    if not playerLastNotifications[playerId] then
        playerLastNotifications[playerId] = {}
        return false
    end
    
    local lastNotif = playerLastNotifications[playerId]
    local currentTime = os.time()
    
    -- Vérifier si même notification dans les 5 dernières secondes
    if lastNotif.jobLabel == jobLabel and 
       lastNotif.message == message and 
       (currentTime - lastNotif.time) < 5 then
        return true
    end
    
    -- Mettre à jour l'entrée
    playerLastNotifications[playerId] = {
        jobLabel = jobLabel,
        message = message,
        time = currentTime
    }
    
    return false
end

-- Fonction pour obtenir le nom RP du joueur
local function GetCharacterName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        -- Récupère le nom du personnage
        return xPlayer.getName() -- Cette fonction devrait retourner le nom RP
    end
    return "Agent"
end


-- Initialiser la table de base de données
Citizen.CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS phone_service_phones (
            job VARCHAR(50) PRIMARY KEY,
            player_identifier VARCHAR(60),
            player_name VARCHAR(255),
            original_phone VARCHAR(20),
            service_phone VARCHAR(20),
            taken_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Nettoyer la table au démarrage du serveur
    MySQL.update('DELETE FROM phone_service_phones')
    
    print("^2[ox_phone:agent]^7 Système de téléphone de service initialisé")
end)

-- Fonction pour vérifier si un joueur est autorisé à utiliser l'application Agent
function IsJobAuthorized(job)
    return Config.AgentApp.AuthorizedJobs[job] ~= nil
end

-- Fonction pour obtenir l'état actuel du téléphone de service pour un job
function GetServicePhoneState(job)
    local result = MySQL.query.await('SELECT * FROM phone_service_phones WHERE job = ?', {job})
    
    if result and #result > 0 then
        return result[1]
    end
    
    return nil
end

-- Fonction pour obtenir tous les joueurs d'un job spécifique
function GetPlayersWithJob(job)
    local players = {}
    local xPlayers = ESX.GetPlayers()
    
    for i=1, #xPlayers do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == job then
            table.insert(players, xPlayer)
        end
    end
    
    return players
end

-- Callback pour vérifier si un joueur peut utiliser l'application Agent
ESX.RegisterServerCallback('ox_phone:canUseAgentApp', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    local job = xPlayer.job.name
    
    if IsJobAuthorized(job) then
        -- Récupérer les informations sur le job et l'état du téléphone de service
        local jobConfig = Config.AgentApp.AuthorizedJobs[job]
        local serviceState = GetServicePhoneState(job)
        
        cb(true, {
            job = job,
            jobLabel = jobConfig.label,
            icon = jobConfig.icon,
            servicePhone = jobConfig.servicePhone,
            hasServicePhone = (serviceState and serviceState.player_identifier == xPlayer.identifier),
            currentAgent = serviceState and serviceState.player_name,
            messages = jobConfig.messages
        })
    else
        cb(false, nil)
    end
end)

-- Callback pour prendre le téléphone de service
ESX.RegisterServerCallback('ox_phone:takeServicePhone', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, "Erreur: Joueur introuvable")
        return
    end
    
    local job = xPlayer.job.name
    
    if not IsJobAuthorized(job) then
        cb(false, "Vous n'êtes pas autorisé à utiliser ce service")
        return
    end
    
    -- Vérifier si le téléphone est déjà pris
    local currentState = GetServicePhoneState(job)
    if currentState then
        if currentState.player_identifier == xPlayer.identifier then
            cb(false, "Vous avez déjà le téléphone de service")
        else
            cb(false, "Le téléphone de service est déjà utilisé par " .. currentState.player_name)
        end
        return
    end
    
    -- Récupérer le numéro de téléphone personnel
    local result = MySQL.query.await('SELECT phone_number FROM users WHERE identifier = ?', {xPlayer.identifier})
    
    if not result or not result[1] or not result[1].phone_number then
        cb(false, "Erreur: Numéro de téléphone personnel introuvable")
        return
    end
    
    local originalPhone = result[1].phone_number
    local servicePhone = Config.AgentApp.AuthorizedJobs[job].servicePhone
    
    -- Utiliser REPLACE INTO au lieu de INSERT pour éviter les problèmes de duplication
    -- Code modifié
    local success = MySQL.update.await('REPLACE INTO phone_service_phones (job, player_identifier, player_name, original_phone, service_phone) VALUES (?, ?, ?, ?, ?)',
    {job, xPlayer.identifier, xPlayer.getName(), originalPhone, servicePhone})
    
    if not success then
        cb(false, "Erreur lors de l'enregistrement du téléphone de service")
        return
    end
    
    -- Mettre à jour le numéro de téléphone du joueur
    MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {servicePhone, xPlayer.identifier})
    
    -- Mettre à jour le numéro en mémoire
    if _G.phoneNumbers then
        _G.phoneNumbers[source] = servicePhone
    end
    
    -- Notifier tous les joueurs du même job
local players = GetPlayersWithJob(job)
for _, player in ipairs(players) do
    if player.source ~= source then
        TriggerClientEvent('ox_phone:servicePhoneUpdate', player.source, {
            job = job,
            action = "taken",
            playerName = GetCharacterName(source) -- Utiliser le nom RP
        })
    end
end
    
    cb(true, "Vous avez pris le téléphone de service (" .. servicePhone .. ")")
end)

-- Callback pour rendre le téléphone de service
ESX.RegisterServerCallback('ox_phone:returnServicePhone', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, "Erreur: Joueur introuvable")
        return
    end
    
    local job = xPlayer.job.name
    
    if not IsJobAuthorized(job) then
        cb(false, "Vous n'êtes pas autorisé à utiliser ce service")
        return
    end
    
    -- Vérifier si le joueur a bien le téléphone
    local currentState = GetServicePhoneState(job)
    if not currentState or currentState.player_identifier ~= xPlayer.identifier then
        cb(false, "Vous n'avez pas le téléphone de service")
        return
    end
    
    -- Restaurer le numéro de téléphone personnel
    MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {currentState.original_phone, xPlayer.identifier})
    
    -- Mettre à jour le numéro en mémoire
    if _G.phoneNumbers then
        _G.phoneNumbers[source] = currentState.original_phone
    end
    
    -- Supprimer l'entrée de la table
    MySQL.update('DELETE FROM phone_service_phones WHERE job = ?', {job})
    
-- Notifier tous les joueurs du même job
local players = GetPlayersWithJob(job)
for _, player in ipairs(players) do
    if player.source ~= source then
        TriggerClientEvent('ox_phone:servicePhoneUpdate', player.source, {
            job = job,
            action = "returned",
            playerName = GetCharacterName(source) -- Utiliser le nom RP
        })
    end
end
    
    cb(true, "Vous avez rendu le téléphone de service")
end)

-- Envoyer une notification publique
ESX.RegisterServerCallback('ox_phone:sendAgentNotification', function(source, cb, messageType, customMessage)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, "Erreur: Joueur introuvable")
        return
    end
    
    local job = xPlayer.job.name
    local jobConfig = Config.AgentApp.AuthorizedJobs[job]
    local message = ""
    
    -- Sélectionner le message en fonction du type
    if messageType == "custom" and customMessage then
        message = customMessage
    elseif messageType == "onDuty" then
        message = jobConfig.messages.onDuty
    elseif messageType == "onBreak" then
        message = jobConfig.messages.onBreak
    elseif messageType == "offDuty" then
        message = jobConfig.messages.offDuty
    else
        cb(false, "Type de message invalide")
        return
    end
    
    -- Vérifier si c'est un doublon
    if isNotificationDuplicate(source, jobConfig.label, message) then
        return
    end
    
    -- Envoyer la notification
    TriggerClientEvent('ox_phone:showAgentNotification', -1, {
        job = job,
        jobLabel = jobConfig.label,
        message = message,
        image = jobConfig.notificationImage
    })
    
    cb(true, "Notification envoyée")
end)

-- Vérifier les téléphones de service lors de la déconnexion d'un joueur
AddEventHandler('playerDropped', function()
    local source = source
    local identifier = ESX.GetPlayerFromId(source).identifier
    
    -- Vérifier si le joueur avait un téléphone de service
    local result = MySQL.query.await('SELECT * FROM phone_service_phones WHERE player_identifier = ?', {identifier})
    
    if result and #result > 0 then
        local jobState = result[1]
        
        -- Restaurer le numéro de téléphone personnel
        MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {jobState.original_phone, identifier})
        
        -- Supprimer l'entrée de la table
        MySQL.update('DELETE FROM phone_service_phones WHERE player_identifier = ?', {identifier})
        
        -- Notifier tous les joueurs du même job
        local players = GetPlayersWithJob(jobState.job)
        for _, player in ipairs(players) do
            TriggerClientEvent('ox_phone:servicePhoneUpdate', player.source, {
                job = jobState.job,
                action = "disconnected",
                playerName = jobState.player_name
            })
        end
    end
end)

-- Système de redirection des appels
-- Intercepter les événements d'appel
AddEventHandler('ox_phone:startCall', function(number)
    local source = source
    
    -- Vérifier si le numéro est un numéro de service
    local serviceJobs = {}
    
    for job, config in pairs(Config.AgentApp.AuthorizedJobs) do
        if config.servicePhone == number then
            table.insert(serviceJobs, {
                job = job,
                priority = config.priority
            })
        end
    end
    
    -- Si ce n'est pas un numéro de service, ne rien faire
    if #serviceJobs == 0 then
        return
    end
    
    -- Trier les jobs par priorité
    table.sort(serviceJobs, function(a, b)
        return a.priority < b.priority
    end)
    
    -- Créer une liste de redirection
    local redirectChain = {}
    
    for _, jobInfo in ipairs(serviceJobs) do
        local serviceState = GetServicePhoneState(jobInfo.job)
        
        if serviceState then
            local targetPlayer = ESX.GetPlayerFromIdentifier(serviceState.player_identifier)
            
            if targetPlayer then
                table.insert(redirectChain, {
                    job = jobInfo.job,
                    playerId = targetPlayer.source
                })
            end
        end
    end
    
    -- Si aucun agent n'est disponible, utiliser le système normal
    if #redirectChain == 0 then
        return
    end
    
    -- Enregistrer la redirection
    local callId = os.time() .. math.random(1000, 9999)
    pendingRedirects[callId] = {
        caller = source,
        chain = redirectChain,
        currentIndex = 1,
        startTime = os.time(),
        timeoutId = nil
    }
    
    -- Commencer la redirection
    StartRedirection(callId)
end)

-- Fonction pour démarrer/poursuivre la redirection
function StartRedirection(callId)
    local redirect = pendingRedirects[callId]
    
    if not redirect then
        return
    end
    
    -- Vérifier si nous sommes à la fin de la chaîne
    if redirect.currentIndex > #redirect.chain then
        pendingRedirects[callId] = nil
        return
    end
    
    local currentTarget = redirect.chain[redirect.currentIndex]
    
    -- Informer le joueur de l'appel (en utilisant le système existant)
    local callerNumber = GetPhoneNumber(redirect.caller)
    local xCaller = ESX.GetPlayerFromId(redirect.caller)
    local callerName = xCaller and xCaller.getName() or "Inconnu"
    
    TriggerClientEvent('ox_phone:incomingCall', currentTarget.playerId, callId, callerNumber, callerName)
    
    -- Configurer un timeout pour passer au service suivant si pas de réponse
    redirect.timeoutId = SetTimeout(Config.AgentApp.RedirectDelay * 1000, function()
        -- Vérifier si l'appel est toujours en attente
        if pendingRedirects[callId] then
            -- Notifier l'appelant que son appel est redirigé
            TriggerClientEvent('ox_lib:notify', redirect.caller, {
                title = 'Appel',
                description = 'Votre appel est redirigé vers un autre service...',
                type = 'info'
            })
            
            -- Passer au service suivant
            pendingRedirects[callId].currentIndex = pendingRedirects[callId].currentIndex + 1
            StartRedirection(callId)
        end
    end)
end

-- Gérer les réponses aux appels
AddEventHandler('ox_phone:answerCall', function(callId)
    -- Annuler la redirection si l'appel est accepté
    if pendingRedirects[callId] then
        if pendingRedirects[callId].timeoutId then
            clearTimeout(pendingRedirects[callId].timeoutId)
        end
        pendingRedirects[callId] = nil
    end
end)

-- Gérer les rejets d'appels
AddEventHandler('ox_phone:rejectCall', function(callId)
    -- Si l'appel est dans notre système de redirection
    if pendingRedirects[callId] then
        local redirect = pendingRedirects[callId]
        
        -- Annuler le timeout actuel
        if redirect.timeoutId then
            clearTimeout(redirect.timeoutId)
        end
        
        -- Passer au service suivant immédiatement
        redirect.currentIndex = redirect.currentIndex + 1
        StartRedirection(callId)
    end
end)

-- Exporter la fonction pour vérifier si un numéro est un numéro de service
exports('IsServicePhoneNumber', function(number)
    for _, config in pairs(Config.AgentApp.AuthorizedJobs) do
        if config.servicePhone == number then
            return true
        end
    end
    return false
end)