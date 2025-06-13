-- ox_phone/server/main.lua
local ESX = exports['es_extended']:getSharedObject()

-- ======================================================
-- VARIABLES GLOBALES
-- ======================================================
local phoneNumbers = {}
_G.phoneNumbers = phoneNumbers
local activeCalls = {}
_G.activeCalls = {}

-- ======================================================
-- FONCTIONS DE GESTION DES NUMÉROS DE TÉLÉPHONE
-- ======================================================

-- Recherche un joueur par son numéro de téléphone
---@param number string Le numéro de téléphone à rechercher
---@return number|nil L'ID serveur du joueur ou nil si non trouvé
function GetPlayerByPhoneNumber(number)
    number = tostring(number)
    
    -- Vérifier dans la table des numéros en mémoire
    for source, phoneNumber in pairs(phoneNumbers) do
        if tostring(phoneNumber) == number then
            return tonumber(source)
        end
    end
    
    -- Rechercher dans la base de données
    local result = MySQL.query.await('SELECT identifier FROM users WHERE phone_number = ?', {number})
    if result and result[1] then
        local xPlayer = ESX.GetPlayerFromIdentifier(result[1].identifier)
        if xPlayer then
            phoneNumbers[xPlayer.source] = number
            return xPlayer.source
        end
    end
    
    return nil
end

-- Génère un numéro de téléphone aléatoire
---@return string Un numéro de téléphone au format "555XXXX"
function GeneratePhoneNumber()
    local number = "555"
    for i = 1, 4 do
        number = number .. math.random(0, 9)
    end
    return number
end

-- Vérifie si un numéro existe déjà dans la base de données
---@param number string Le numéro à vérifier
---@return boolean True si le numéro existe, false sinon
function DoesNumberExist(number)
    local result = MySQL.query.await('SELECT phone_number FROM users WHERE phone_number = ?', {number})
    return result and #result > 0
end

-- Attribue un numéro de téléphone à un joueur
---@param source number L'ID source du joueur
---@return string|nil Le numéro attribué ou nil en cas d'échec
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
        return nil
    end
    
    -- Enregistrer le numéro
    MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {newNumber, xPlayer.identifier})
    phoneNumbers[source] = newNumber
    
    return newNumber
end

-- Récupère le numéro de téléphone d'un joueur
---@param source number L'ID source du joueur
---@return string|nil Le numéro de téléphone ou nil si non trouvé
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

-- Récupère le nom d'un contact associé à un numéro
---@param source number L'ID source du joueur
---@param number string Le numéro à rechercher
---@return string Le nom du contact ou le numéro lui-même si non trouvé
function GetContactName(source, number)
    if not source or not number then
        return number or "Inconnu"
    end
    
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
        if Config.EmergencyNumbers then
            for job, data in pairs(Config.EmergencyNumbers) do
                if data and data.number and data.number == number then
                    return data.name
                end
            end
        end
        
        -- Essayer de trouver si c'est un autre joueur
        local target = nil
        
        if phoneNumbers then
            for id, num in pairs(phoneNumbers) do
                if tostring(num) == tostring(number) then
                    target = tonumber(id)
                    break
                end
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
        
        -- Aucun nom trouvé, retourner le numéro
        return number
    end
end

-- ======================================================
-- INITIALISATION DE LA BASE DE DONNÉES
-- ======================================================

MySQL.ready(function()
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
end)

-- ======================================================
-- GESTION DES TRANSACTIONS BANCAIRES
-- ======================================================

-- Enregistre les transactions de dépôt
RegisterServerEvent('esx:onAddAccountMoney')
AddEventHandler('esx:onAddAccountMoney', function(source, account, amount)
    -- Vérifier que c'est un compte bancaire et que le montant est significatif
    if account == 'bank' and amount >= 1 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            -- Déterminer le type de transaction (salaire, commerce, etc.)
            local label = "Dépôt bancaire"
            if amount % 10 == 0 then  -- Heuristique simple pour détecter les salaires
                label = "Salaire"
            end
            
            -- Enregistrer la transaction
            MySQL.insert('INSERT INTO phone_bank_transactions (identifier, type, amount, label, date) VALUES (?, ?, ?, ?, NOW())',
                {xPlayer.identifier, 'credit', amount, label})
        end
    end
end)

-- Enregistre les transactions de retrait
RegisterServerEvent('esx:onRemoveAccountMoney')
AddEventHandler('esx:onRemoveAccountMoney', function(source, account, amount)
    -- Vérifier que c'est un compte bancaire et que le montant est significatif
    if account == 'bank' and amount >= 1 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            -- Enregistrer la transaction
            MySQL.insert('INSERT INTO phone_bank_transactions (identifier, type, amount, label, date) VALUES (?, ?, ?, ?, NOW())',
                {xPlayer.identifier, 'debit', -amount, "Retrait bancaire", NOW()})
        end
    end
end)

-- ======================================================
-- GESTION DES DÉCONNEXIONS
-- ======================================================

-- Gère la déconnexion des joueurs
AddEventHandler('playerDropped', function()
    local source = source
    local identifier = ESX.GetPlayerFromId(source).identifier
    
    -- Vérifier si le joueur avait un appel actif
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

-- ======================================================
-- EXPORTS
-- ======================================================

exports('GetPhoneNumber', GetPhoneNumber)
exports('GetContactName', GetContactName)
exports('GetAllPhoneNumbers', function() return phoneNumbers end)
exports('GetPlayerByPhoneNumber', GetPlayerByPhoneNumber)