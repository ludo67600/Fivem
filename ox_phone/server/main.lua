-- ox_phone/server/main.lua
local ESX = exports['es_extended']:getSharedObject()
local phoneNumbers = {}
local activeCalls = {}
_G.activeCalls = {}



-- Fonction pour générer un numéro de téléphone
function GeneratePhoneNumber()
    local number = "555"
    for i = 1, 4 do
        number = number .. math.random(0, 9)
    end
    return number
end

-- Fonction pour vérifier si un numéro existe déjà
function DoesNumberExist(number)
    local result = MySQL.query.await('SELECT phone_number FROM users WHERE phone_number = ?', {number})
    return result and #result > 0
end

-- Fonction pour attribuer un numéro de téléphone à un joueur
function AssignPhoneNumber(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return nil
    end
    
    -- Vérifier si le joueur a déjà un numéro
    local result = MySQL.query.await('SELECT phone_number FROM users WHERE identifier = ?', {xPlayer.identifier})
    
    if result and result[1] and result[1].phone_number ~= nil and result[1].phone_number ~= '' then
        phoneNumbers[source] = result[1].phone_number
        return result[1].phone_number
    end
    
    -- Générer un nouveau numéro
    local newNumber
    local attempts = 0
    repeat
        newNumber = GeneratePhoneNumber()
        attempts = attempts + 1
    until not DoesNumberExist(newNumber) or attempts > 10
    
    if attempts > 10 then
        return nil -- Échec après 10 tentatives
    end
    
    -- Enregistrer le numéro
    MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {newNumber, xPlayer.identifier})
    phoneNumbers[source] = newNumber
    
    return newNumber
end

-- Obtenir le numéro de téléphone d'un joueur
function GetPhoneNumber(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return nil
    end
    
    if phoneNumbers[source] then
        return phoneNumbers[source]
    end
    
    return AssignPhoneNumber(source)
end

-- Obtenir le nom associé à un numéro
function GetContactName(source, number)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return number
    end
    
    local result = MySQL.query.await('SELECT display_name FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                   ' WHERE owner_identifier = ? AND phone_number = ?', {xPlayer.identifier, number})
    
    if result and result[1] then
        return result[1].display_name
    else
        -- Si c'est un numéro d'urgence, retourner son nom
        for job, data in pairs(Config.EmergencyNumbers) do
            if data.number == number then
                return data.name
            end
        end
        
        -- Essayer de trouver si c'est un autre joueur
        local target = nil
        for id, num in pairs(phoneNumbers) do
            if num == number then
                target = id
                break
            end
        end
        
        if target then
            local targetPlayer = ESX.GetPlayerFromId(target)
            if targetPlayer then
                local charName = targetPlayer.getName()
                if charName then
                    return charName
                end
            end
        end
        
        return number
    end
end

-- Initialiser les tables de la base de données
MySQL.ready(function()
    -- Vérifier et créer les tables si elles n'existent pas
	
    -- Table des contacts
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_contacts .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            owner_identifier VARCHAR(60) NOT NULL,
            display_name VARCHAR(255) NOT NULL,
            phone_number VARCHAR(20) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Table des messages
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_messages .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            sender VARCHAR(20) NOT NULL,
            receiver VARCHAR(20) NOT NULL,
            message TEXT NOT NULL,
            is_read BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Table des appels
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_calls .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            caller VARCHAR(20) NOT NULL,
            receiver VARCHAR(20) NOT NULL,
            duration INT DEFAULT 0,
            status VARCHAR(10) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Table des tweets
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_tweets .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            author VARCHAR(255) NOT NULL,
            author_identifier VARCHAR(60) NOT NULL,
            message TEXT NOT NULL,
            image VARCHAR(255) DEFAULT NULL,
            likes JSON DEFAULT '[]',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
	
	-- Table des commentaires de tweets
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_tweet_comments .. [[ (

            id INT AUTO_INCREMENT PRIMARY KEY,
            tweet_id INT NOT NULL,
            author VARCHAR(255) NOT NULL,
            author_identifier VARCHAR(60) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (tweet_id) REFERENCES phone_tweets(id) ON DELETE CASCADE
        )
    ]])

    
    -- Table des annonces
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_ads .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            author VARCHAR(255) NOT NULL,
            author_identifier VARCHAR(60) NOT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            image VARCHAR(255) DEFAULT NULL,
            price DECIMAL(10, 2) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Table des paramètres
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_settings .. [[ (
            identifier VARCHAR(60) PRIMARY KEY,
            background VARCHAR(255) DEFAULT 'background1',
            ringtone VARCHAR(255) DEFAULT 'ringtone1',
            notification_sound VARCHAR(255) DEFAULT 'notification1',
            do_not_disturb BOOLEAN DEFAULT FALSE,
            airplane_mode BOOLEAN DEFAULT FALSE,
            theme VARCHAR(20) DEFAULT 'default',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    -- Table de la galerie
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DatabaseTables.phone_gallery .. [[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            owner_identifier VARCHAR(60) NOT NULL,
            image_url VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Vérifier également si la table centre_appel existe
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS centre_appel (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL,
            firstname VARCHAR(50) NOT NULL,
            lastname VARCHAR(50) NOT NULL,
            phone_number VARCHAR(20) NOT NULL,
            service VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    print("^2ox_phone^7: Base de données initialisée avec succès!")
end)

-- Gérer la déconnexion des joueurs
AddEventHandler('playerDropped', function()
    local source = source
    
    -- Terminer tous les appels actifs du joueur
    for i, call in ipairs(activeCalls) do
        if call.caller == source or call.receiver == source or call.assignedTo == source then
            -- Calculer la durée de l'appel
            local duration = 0
            if call.status == 'active' and call.answeredTime then
                duration = os.time() - call.answeredTime
            end
            
            -- Mettre à jour la base de données
            MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                        ' SET status = ?, duration = ? WHERE caller = ? AND receiver = ? AND status IN (?, ?) ORDER BY id DESC LIMIT 1', 
                        {'ended', duration, call.callerNumber, call.receiverNumber, 'outgoing', 'answered'})
            
            -- Notifier l'autre partie
            if call.caller == source then
                TriggerClientEvent('ox_phone:callEnded', call.receiver, call.id)
            else
                TriggerClientEvent('ox_phone:callEnded', call.caller, call.id)
            end
        end
    end
    
    -- Filtrer les appels actifs
    local newActiveCalls = {}
    for _, call in ipairs(activeCalls) do
        if call.caller ~= source and call.receiver ~= source and call.assignedTo ~= source then
            table.insert(newActiveCalls, call)
        end
    end
    
    activeCalls = newActiveCalls
    
    -- Supprimer le numéro de téléphone de la mémoire
    phoneNumbers[source] = nil
end)

-- Accès à la table phoneNumbers pour les autres fichiers
_G.phoneNumbers = phoneNumbers

-- Exporter les fonctions
exports('GetPhoneNumber', GetPhoneNumber)
exports('GetContactName', GetContactName)
exports('GetAllPhoneNumbers', function() return phoneNumbers end)