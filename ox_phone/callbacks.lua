-- ox_phone/server/callbacks.lua
local ESX = exports['es_extended']:getSharedObject()

-- ==========================================
-- INITIALISATION DES VARIABLES GLOBALES
-- ==========================================

-- Initialiser Config.EmergencyNumbers si non défini
if not Config.EmergencyNumbers then
    Config.EmergencyNumbers = {}
end

-- S'assurer que phoneNumbers est initialisé
if not _G.phoneNumbers then
    _G.phoneNumbers = {}
end
local phoneNumbers = _G.phoneNumbers

-- ==========================================
-- FONCTIONS UTILITAIRES
-- ==========================================

-- Fonction pour envoyer un événement client en toute sécurité
function SafeTriggerClientEvent(eventName, playerId, ...)
    if type(playerId) ~= "number" or playerId <= 0 then
        return false
    end
    
    if not DoesPlayerExist(playerId) then
        return false
    end
    
    TriggerClientEvent(eventName, playerId, ...)
    return true
end

-- Fonction pour vérifier si un joueur existe
function DoesPlayerExist(playerId)
    local player = ESX.GetPlayerFromId(playerId)
    return player ~= nil
end

-- ==========================================
-- CALLBACKS - TÉLÉPHONE GÉNÉRAL
-- ==========================================

-- Obtenir le numéro de téléphone d'un joueur
ESX.RegisterServerCallback('ox_phone:getPhoneNumber', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(nil)
        return
    end
    
    local result = MySQL.query.await('SELECT phone_number FROM users WHERE identifier = ?', {xPlayer.identifier})
    
    if result and result[1] and result[1].phone_number ~= nil and result[1].phone_number ~= '' then
        -- Numéro existant
        cb(result[1].phone_number)
    else
        -- Créer un nouveau numéro
        local newNumber = GeneratePhoneNumber()
        if DoesNumberExist(newNumber) then
            -- Essayer une nouvelle fois si le numéro existe déjà
            newNumber = GeneratePhoneNumber()
        end
        
        MySQL.update('UPDATE users SET phone_number = ? WHERE identifier = ?', {newNumber, xPlayer.identifier})
        cb(newNumber)
    end
end)

-- ==========================================
-- CALLBACKS - CONTACTS
-- ==========================================

-- Obtenir les contacts d'un joueur
ESX.RegisterServerCallback('ox_phone:getContacts', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    local result = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                  ' WHERE owner_identifier = ? ORDER BY display_name ASC', {xPlayer.identifier})
    
    cb(result or {})
end)

-- Ajouter un contact
ESX.RegisterServerCallback('ox_phone:addContact', function(source, cb, name, number)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    -- Vérifier si le contact existe déjà
    local existing = MySQL.query.await('SELECT id FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                     ' WHERE owner_identifier = ? AND phone_number = ?', 
                                     {xPlayer.identifier, number})
    
    if existing and #existing > 0 then
        -- Mettre à jour le contact existant
        MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_contacts .. 
                    ' SET display_name = ? WHERE id = ?', 
                    {name, existing[1].id})
        
        local updated = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                        ' WHERE id = ?', {existing[1].id})
        
        cb(true, updated[1])
    else
        -- Insérer un nouveau contact
        local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_contacts .. 
                                           ' (owner_identifier, display_name, phone_number) VALUES (?, ?, ?)', 
                                           {xPlayer.identifier, name, number})
        
        if insertId then
            local contact = {
                id = insertId,
                owner_identifier = xPlayer.identifier,
                display_name = name,
                phone_number = number,
                created_at = os.date('%Y-%m-%d %H:%M:%S')
            }
            
            cb(true, contact)
        else
            cb(false, nil)
        end
    end
end)

-- Supprimer un contact
ESX.RegisterServerCallback('ox_phone:deleteContact', function(source, cb, contactId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                   ' WHERE id = ? AND owner_identifier = ?', 
                                   {contactId, xPlayer.identifier})
    
    cb(result and result > 0) 
end)

-- ==========================================
-- CALLBACKS - MESSAGES
-- ==========================================

-- Obtenir les messages
ESX.RegisterServerCallback('ox_phone:getMessages', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb({})
        return
    end
    
    -- Convertir en chaîne pour la comparaison
    local phoneNumberString = tostring(phoneNumber)
    
    -- Récupérer les conversations uniques
    local conversations = {}
    local seen = {}
    
    -- Messages envoyés (non supprimés par l'expéditeur)
    local sent = MySQL.query.await(
        'SELECT DISTINCT receiver AS number ' ..
        'FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
        'WHERE sender = ? AND is_deleted_by_sender = 0 ' ..
        'ORDER BY created_at DESC', 
        {phoneNumberString})
    
    if sent then
        for _, v in ipairs(sent) do
            if not seen[v.number] then
                seen[v.number] = true
                
                -- Obtenir le dernier message
                local lastMessage = MySQL.query.await(
                    'SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
                    'WHERE ((sender = ? AND receiver = ? AND is_deleted_by_sender = 0) ' ..
                    'OR (sender = ? AND receiver = ? AND is_deleted_by_receiver = 0)) ' .. 
                    'ORDER BY created_at DESC LIMIT 1', 
                    {phoneNumberString, v.number, v.number, phoneNumberString})
                
                if lastMessage and lastMessage[1] then
                    -- Compter les messages non lus
                    local unread = MySQL.query.await(
                        'SELECT COUNT(*) AS count FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
                        'WHERE sender = ? AND receiver = ? AND is_read = 0 AND is_deleted_by_receiver = 0', 
                        {v.number, phoneNumberString})
                    
                    -- Obtenir le nom du contact si existant
                    local contactName = GetContactName(source, v.number)
                    
                    table.insert(conversations, {
                        number = v.number,
                        name = contactName,
                        last_message = lastMessage[1].message,
                        last_time = lastMessage[1].created_at,
                        unread = unread[1].count or 0
                    })
                end
            end
        end
    end
    
    -- Messages reçus (non supprimés par le destinataire)
    local received = MySQL.query.await(
        'SELECT DISTINCT sender AS number ' ..
        'FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
        'WHERE receiver = ? AND is_deleted_by_receiver = 0 ' ..
        'ORDER BY created_at DESC', 
        {phoneNumberString})
    
    if received then
        for _, v in ipairs(received) do
            if not seen[v.number] then
                seen[v.number] = true
                
                -- Obtenir le dernier message
                local lastMessage = MySQL.query.await(
                    'SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
                    'WHERE ((sender = ? AND receiver = ? AND is_deleted_by_sender = 0) ' ..
                    'OR (sender = ? AND receiver = ? AND is_deleted_by_receiver = 0)) ' .. 
                    'ORDER BY created_at DESC LIMIT 1', 
                    {phoneNumberString, v.number, v.number, phoneNumberString})
                
                if lastMessage and lastMessage[1] then
                    -- Compter les messages non lus
                    local unread = MySQL.query.await(
                        'SELECT COUNT(*) AS count FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
                        'WHERE sender = ? AND receiver = ? AND is_read = 0 AND is_deleted_by_receiver = 0', 
                        {v.number, phoneNumberString})
                    
                    -- Obtenir le nom du contact si existant
                    local contactName = GetContactName(source, v.number)
                    
                    table.insert(conversations, {
                        number = v.number,
                        name = contactName,
                        last_message = lastMessage[1].message,
                        last_time = lastMessage[1].created_at,
                        unread = unread[1].count or 0
                    })
                end
            end
        end
    end
    
    -- Trier par date décroissante
    table.sort(conversations, function(a, b)
        return a.last_time > b.last_time
    end)
    
    cb(conversations)
end)

-- Obtenir une conversation
ESX.RegisterServerCallback('ox_phone:getConversation', function(source, cb, number)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb({})
        return
    end

    local phoneNumber = GetPhoneNumber(source)

    if not phoneNumber then
        cb({})
        return
    end
    
    -- Convertir en chaînes pour la comparaison
    local phoneNumberString = tostring(phoneNumber)
    local targetNumberString = tostring(number)

    -- Récupérer tous les messages entre ces deux numéros, en excluant ceux supprimés par l'utilisateur
    local messages = MySQL.query.await(
        'SELECT *, (CASE WHEN sender = ? THEN 1 ELSE 0 END) AS is_sender ' ..
        'FROM ' .. Config.DatabaseTables.phone_messages .. ' ' ..
        'WHERE ((sender = ? AND receiver = ? AND is_deleted_by_sender = 0) ' ..
        'OR (sender = ? AND receiver = ? AND is_deleted_by_receiver = 0)) ' ..
        'ORDER BY created_at ASC',
        {phoneNumberString, phoneNumberString, targetNumberString, targetNumberString, phoneNumberString})

    -- Marquer tous les messages non lus comme lus
    MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_messages ..
                ' SET is_read = 1 ' ..
                'WHERE sender = ? AND receiver = ? AND is_read = 0',
                {targetNumberString, phoneNumberString})

    -- Obtenir le nom du contact si existant
    local contactName = GetContactName(source, number)

    cb({
        number = number,
        name = contactName,
        messages = messages or {}
    })
end)

-- Envoyer un message
ESX.RegisterServerCallback('ox_phone:sendMessage', function(source, cb, to, message)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false, nil)
        return
    end
    
    -- Insérer le message
    local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_messages .. 
                                       ' (sender, receiver, message) VALUES (?, ?, ?)', 
                                       {phoneNumber, to, message})
    
    if not insertId then
        cb(false, nil)
        return
    end
    
    -- Récupérer le message inséré
    local newMessage = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                       ' WHERE id = ?', {insertId})
    
    if not newMessage or not newMessage[1] then
        cb(false, nil)
        return
    end
    
    -- Chercher le destinataire
    local targetSource = nil
    
    -- S'assurer que phoneNumbers existe avant d'itérer dessus
    if phoneNumbers then
        for src, num in pairs(phoneNumbers) do
            if tostring(num) == tostring(to) then
                targetSource = tonumber(src)
                break
            end
        end
    end
    
    -- Si on ne trouve pas, faire une recherche en base de données
    if not targetSource then
        local result = MySQL.query.await('SELECT identifier FROM users WHERE phone_number = ?', {to})
        if result and result[1] then
            local targetPlayer = ESX.GetPlayerFromIdentifier(result[1].identifier)
            if targetPlayer then
                targetSource = targetPlayer.source
            end
        end
    end
    
    -- Notifier le destinataire s'il est en ligne
    if targetSource then
        -- Utiliser SafeTriggerClientEvent pour éviter les erreurs
        SafeTriggerClientEvent('ox_phone:receiveMessage', targetSource, phoneNumber, message, newMessage[1].created_at, newMessage[1].id)
    end
    
    -- Retourner le message complet à l'expéditeur
    cb(true, newMessage[1])
end)

-- Supprimer une conversation
ESX.RegisterServerCallback('ox_phone:deleteConversation', function(source, cb, number)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false)
        return
    end
    
    -- Convertir en chaînes pour la comparaison
    local phoneNumberString = tostring(phoneNumber)
    local targetNumberString = tostring(number)
    
    -- Marquer tous les messages envoyés à ce numéro comme supprimés par l'expéditeur
    local result1 = MySQL.update.await('UPDATE ' .. Config.DatabaseTables.phone_messages .. 
                ' SET is_deleted_by_sender = 1 WHERE sender = ? AND receiver = ?', 
                {phoneNumberString, targetNumberString})
    
    -- Marquer tous les messages reçus de ce numéro comme supprimés par le destinataire
    local result2 = MySQL.update.await('UPDATE ' .. Config.DatabaseTables.phone_messages .. 
                ' SET is_deleted_by_receiver = 1 WHERE sender = ? AND receiver = ?', 
                {targetNumberString, phoneNumberString})
    
    -- Si au moins une des mises à jour a réussi
    cb(result1 > 0 or result2 > 0)
end)

-- ==========================================
-- CALLBACKS - APPELS
-- ==========================================

-- Obtenir l'historique des appels
ESX.RegisterServerCallback('ox_phone:getCallHistory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb({})
        return
    end

    local phoneNumber = GetPhoneNumber(source)

    if not phoneNumber then
        cb({})
        return
    end
    
    -- Convertir en chaîne pour la comparaison
    local phoneNumberString = tostring(phoneNumber)

    -- Récupérer l'historique des appels avec plus de détails et une meilleure gestion des statuts
    local calls = MySQL.query.await(
        'SELECT *, (CASE WHEN caller = ? THEN "outgoing" ELSE "incoming" END) AS direction ' ..
        'FROM ' .. Config.DatabaseTables.phone_calls .. ' ' ..
        'WHERE (caller = ? AND is_deleted_by_caller = 0) OR (receiver = ? AND is_deleted_by_receiver = 0) ' ..
        'ORDER BY created_at DESC LIMIT 50',
        {phoneNumberString, phoneNumberString, phoneNumberString})

    if not calls then
        cb({})
        return
    end

    -- Enrichir les données avec direction et noms de contacts
    for i, call in ipairs(calls) do
        -- Explicitement définir la direction (entrant/sortant) du point de vue de l'utilisateur
        calls[i].direction = (call.caller == phoneNumber) and 'outgoing' or 'incoming'

        -- L'autre numéro dépend de la direction
        local otherNumber = (call.caller == phoneNumber) and call.receiver or call.caller

        -- Obtenir le nom du contact si existant
        local contactName = GetContactName(source, otherNumber)

        -- N'attribuer un nom que si c'est un contact enregistré
        if contactName and contactName ~= otherNumber then
            calls[i].name = contactName
        else
            calls[i].name = nil
        end

        -- Correction des statuts pour l'affichage
        -- Pour les appels entrants non répondus, les marquer explicitement comme manqués
        if calls[i].direction == 'incoming' and (call.status == 'outgoing' or (call.status == 'ended' and call.duration == 0)) then
            calls[i].status = 'missed'
        end
    end

    cb(calls)
end)

-- Supprimer un appel de l'historique
ESX.RegisterServerCallback('ox_phone:deleteCall', function(source, cb, callId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false)
        return
    end
    
    -- Convertir en chaîne pour la comparaison
    local phoneNumberString = tostring(phoneNumber)
    
    -- Vérifier que l'appel existe
    local callCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_calls .. 
                                      ' WHERE id = ?', {callId})
    
    if not callCheck or #callCheck == 0 then
        cb(false)
        return
    end
    
    local call = callCheck[1]
    
    -- Convertir les numéros de téléphone en chaînes
    local callerString = tostring(call.caller)
    local receiverString = tostring(call.receiver)
    
    -- Déterminer si l'utilisateur est l'appelant ou le destinataire
    local query = ""
    local params = {}
    
    if callerString == phoneNumberString then
        query = 'UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                ' SET is_deleted_by_caller = 1 WHERE id = ?'
        params = {callId}
    elseif receiverString == phoneNumberString then
        query = 'UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                ' SET is_deleted_by_receiver = 1 WHERE id = ?'
        params = {callId}
    else
        -- Si la comparaison de chaînes échoue, essayons une comparaison numérique
        local callerNum = tonumber(callerString)
        local receiverNum = tonumber(receiverString)
        local phoneNum = tonumber(phoneNumberString)
        
        if callerNum == phoneNum then
            query = 'UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                    ' SET is_deleted_by_caller = 1 WHERE id = ?'
            params = {callId}
        elseif receiverNum == phoneNum then
            query = 'UPDATE ' .. Config.DatabaseTables.phone_calls .. 
                    ' SET is_deleted_by_receiver = 1 WHERE id = ?'
            params = {callId}
        else
            cb(false)
            return
        end
    end
    
    -- Exécuter la requête SQL
    local result = MySQL.update.await(query, params)
    
    if result and result > 0 then
        cb(true)
    else
        cb(false)
    end
end)

-- Amélioration du callback pour supprimer plusieurs appels
ESX.RegisterServerCallback('ox_phone:deleteMultipleCalls', function(source, cb, callIds)
    if not callIds or #callIds == 0 then
        cb(false)
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false)
        return
    end
    
    local success = true
    local totalDeleted = 0
    
    for _, callId in ipairs(callIds) do
        -- Vérifier que l'appel appartient bien au joueur
        local callCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_calls .. 
                                          ' WHERE id = ? AND (caller = ? OR receiver = ?)', 
                                          {callId, phoneNumber, phoneNumber})
        
        if callCheck and #callCheck > 0 then
            -- Supprimer l'appel
            local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_calls .. 
                                            ' WHERE id = ? AND (caller = ? OR receiver = ?)', 
                                            {callId, phoneNumber, phoneNumber})
            
            if result > 0 then 
                totalDeleted = totalDeleted + 1
            else
                success = false
            end
        else
            success = false
        end
    end
    
    cb(success and totalDeleted == #callIds)
end)

-- ==========================================
-- CALLBACKS - SUPPRESSION DE MESSAGES
-- ==========================================

-- Supprimer un message
ESX.RegisterServerCallback('ox_phone:deleteMessage', function(source, cb, messageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    if not phoneNumber then
        cb(false)
        return
    end
    
    -- Vérifier d'abord que le message existe
    local query1 = 'SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. ' WHERE id = ?'
    
    local messageCheck = MySQL.query.await(query1, {messageId})
    
    if not messageCheck or #messageCheck == 0 then
        cb(false)
        return
    end
    
    local message = messageCheck[1]
    
    -- Comparaison des numéros de téléphone en tant que chaînes
    -- Conversion explicite en chaînes
    local senderString = tostring(message.sender)
    local receiverString = tostring(message.receiver)
    local phoneNumberString = tostring(phoneNumber)
    
    -- Déterminer si l'utilisateur est l'expéditeur ou le destinataire
    local query2 = ""
    local params = {}
    
    if senderString == phoneNumberString then
        query2 = 'UPDATE ' .. Config.DatabaseTables.phone_messages .. ' SET is_deleted_by_sender = 1 WHERE id = ?'
        params = {messageId}
    elseif receiverString == phoneNumberString then
        query2 = 'UPDATE ' .. Config.DatabaseTables.phone_messages .. ' SET is_deleted_by_receiver = 1 WHERE id = ?'
        params = {messageId}
    else
        -- Si la comparaison de chaînes échoue, essayons une comparaison numérique
        local senderNum = tonumber(senderString)
        local receiverNum = tonumber(receiverString)
        local phoneNum = tonumber(phoneNumberString)
        
        if senderNum == phoneNum then
            query2 = 'UPDATE ' .. Config.DatabaseTables.phone_messages .. ' SET is_deleted_by_sender = 1 WHERE id = ?'
            params = {messageId}
        elseif receiverNum == phoneNum then
            query2 = 'UPDATE ' .. Config.DatabaseTables.phone_messages .. ' SET is_deleted_by_receiver = 1 WHERE id = ?'
            params = {messageId}
        else
            cb(false)
            return
        end
    end
    
    -- Essai avec MySQL.update.await
    local result = MySQL.update.await(query2, params)
    
    if result and result > 0 then
        cb(true)
    else
        cb(false)
    end
end)

-- Amélioration du callback pour supprimer plusieurs messages
ESX.RegisterServerCallback('ox_phone:deleteMultipleMessages', function(source, cb, messageIds)
    if not messageIds or #messageIds == 0 then
        cb(false)
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false)
        return
    end
    
    local success = true
    local totalDeleted = 0
    
    for _, messageId in ipairs(messageIds) do
        -- Vérifier que le message appartient bien au joueur
        local messageCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                             ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                             {messageId, phoneNumber, phoneNumber})
        
        if messageCheck and #messageCheck > 0 then
            -- Supprimer le message
            local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_messages .. 
                                            ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                            {messageId, phoneNumber, phoneNumber})
            
            if result > 0 then
                totalDeleted = totalDeleted + 1
            else
                success = false
            end
        else
            success = false
        end
    end
    
    cb(success and totalDeleted == #messageIds)
end)

-- ==========================================
-- CALLBACKS - TWITTER
-- ==========================================

-- Obtenir les tweets
ESX.RegisterServerCallback('ox_phone:getTweets', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer les tweets, les plus récents d'abord
    local tweets = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_tweets .. 
                                   ' ORDER BY created_at DESC LIMIT 100')
    
    cb(tweets or {})
end)

-- Publier un tweet
ESX.RegisterServerCallback('ox_phone:postTweet', function(source, cb, message, image)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    -- Nom du personnage
    local charName = xPlayer.getName()
    
    -- Insérer le tweet
    local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_tweets .. 
                                       ' (author, author_identifier, message, image) VALUES (?, ?, ?, ?)', 
                                       {charName, xPlayer.identifier, message, image or nil})
    
    if not insertId then
        cb(false, nil)
        return
    end
    
    -- Récupérer le tweet inséré
    local newTweet = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_tweets .. 
                                     ' WHERE id = ?', {insertId})
    
    if not newTweet or not newTweet[1] then
        cb(false, nil)
        return
    end
    
    -- Notifier tous les joueurs
    TriggerClientEvent('ox_phone:newTweet', -1, newTweet[1])
    
    cb(true, newTweet[1])
end)

-- Liker un tweet
ESX.RegisterServerCallback('ox_phone:likeTweet', function(source, cb, tweetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, 0)
        return
    end
    
    -- Récupérer le tweet
    local tweet = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_tweets .. 
                                  ' WHERE id = ?', {tweetId})
    
    if not tweet or not tweet[1] then
        cb(false, 0)
        return
    end
    
    -- Vérifier si l'utilisateur a déjà liké
    local likes = json.decode(tweet[1].likes or '[]')
    local hasLiked = false
    
    for i, identifier in ipairs(likes) do
        if identifier == xPlayer.identifier then
            -- Retirer le like
            table.remove(likes, i)
            hasLiked = true
            break
        end
    end
    
    if not hasLiked then
        -- Ajouter le like
        table.insert(likes, xPlayer.identifier)
    end
    
    -- Mettre à jour les likes
    MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_tweets .. 
                ' SET likes = ? WHERE id = ?', 
                {json.encode(likes), tweetId})
    
    cb(true, #likes)
end)

-- Ajouter un commentaire à un tweet
ESX.RegisterServerCallback('ox_phone:addTweetComment', function(source, cb, tweetId, message)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false, nil)
        return
    end

    -- Nom du personnage
    local charName = xPlayer.getName()

    -- Insérer le commentaire
    local insertId = MySQL.insert.await('INSERT INTO phone_tweet_comments (tweet_id, author, author_identifier, message) VALUES (?, ?, ?, ?)',
                                       {tweetId, charName, xPlayer.identifier, message})

    if not insertId then
        cb(false, nil)
        return
    end

    -- Récupérer le commentaire inséré
    local newComment = MySQL.query.await('SELECT * FROM phone_tweet_comments WHERE id = ?', {insertId})

    if not newComment or not newComment[1] then
        cb(false, nil)
        return
    end

    cb(true, newComment[1])
end)

-- Récupérer les commentaires d'un tweet
ESX.RegisterServerCallback('ox_phone:getTweetComments', function(source, cb, tweetId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb({})
        return
    end

    -- Récupérer les commentaires
    local comments = MySQL.query.await('SELECT * FROM phone_tweet_comments WHERE tweet_id = ? ORDER BY created_at ASC', {tweetId})

    cb(comments or {})
end)

-- ==========================================
-- CALLBACKS - ANNONCES
-- ==========================================

-- Obtenir les annonces
ESX.RegisterServerCallback('ox_phone:getAds', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer les annonces, les plus récentes d'abord
    local ads = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_ads .. 
                                ' ORDER BY created_at DESC LIMIT 50')
    
    cb(ads or {})
end)

-- Publier une annonce
ESX.RegisterServerCallback('ox_phone:postAd', function(source, cb, title, message, image, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    -- Nom du personnage
    local charName = xPlayer.getName()
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false, nil)
        return
    end
    
    -- Insérer l'annonce
    local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_ads .. 
                                       ' (author, author_identifier, title, message, image, price, phone_number) VALUES (?, ?, ?, ?, ?, ?, ?)', 
                                       {charName, xPlayer.identifier, title, message, image or nil, price or nil, phoneNumber})
    
    if not insertId then
        cb(false, nil)
        return
    end
    
    -- Récupérer l'annonce insérée
    local newAd = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_ads .. 
                                  ' WHERE id = ?', {insertId})
    
    if not newAd or not newAd[1] then
        cb(false, nil)
        return
    end
    
    -- Ajouter le numéro de téléphone à l'annonce pour le retour
    newAd[1].phone_number = phoneNumber
    
    -- Notifier tous les joueurs
    TriggerClientEvent('ox_phone:newAd', -1, newAd[1])
    
    cb(true, newAd[1])
end)

-- Supprimer une annonce
ESX.RegisterServerCallback('ox_phone:deleteAd', function(source, cb, adId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
-- Vérifier que l'annonce appartient bien au joueur
    local ad = MySQL.query.await('SELECT author_identifier FROM ' .. Config.DatabaseTables.phone_ads .. 
                               ' WHERE id = ?', {adId})
    
    if not ad or not ad[1] or ad[1].author_identifier ~= xPlayer.identifier then
        cb(false)
        return
    end
    
    -- Supprimer l'annonce
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_ads .. 
                                   ' WHERE id = ?', {adId})
    
    cb(result and result.affectedRows > 0)
end)

-- ==========================================
-- CALLBACKS - BANQUE
-- ==========================================

-- Obtenir les données bancaires
ESX.RegisterServerCallback('ox_phone:getBankData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer le solde bancaire
    local balance = xPlayer.getAccount('bank').money
    
    -- Récupérer les transactions récentes
    local transactions = MySQL.query.await('SELECT * FROM phone_bank_transactions WHERE identifier = ? ORDER BY date DESC LIMIT 20', {xPlayer.identifier})
    
    -- Si aucune table de transactions n'existe, on retourne une liste vide
    if not transactions then
        transactions = {}
    end
    
    -- Formater la réponse
    local bankData = {
        balance = balance,
        transactions = transactions
    }
    
    cb(bankData)
end)

-- Transfert d'argent
ESX.RegisterServerCallback('ox_phone:transferMoney', function(source, cb, to, amount, reason)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, "Erreur: Joueur introuvable")
        return
    end
    
    -- Convertir le montant en nombre
    amount = tonumber(amount)
    
    if not amount or amount <= 0 then
        cb(false, "Montant invalide")
        return
    end
    
    -- Vérifier si le joueur a assez d'argent
    if xPlayer.getAccount('bank').money < amount then
        cb(false, "Fonds insuffisants")
        return
    end
    
    -- Trouver le destinataire
    local targetIdentifier = nil
    local targetNumber = nil
    
    -- Vérifier si c'est un numéro de téléphone
    local targetResult = MySQL.query.await('SELECT identifier, phone_number FROM users WHERE phone_number = ?', {to})
    
    if targetResult and targetResult[1] then
        targetIdentifier = targetResult[1].identifier
        targetNumber = targetResult[1].phone_number
    end
    
    if not targetIdentifier then
        cb(false, "Destinataire introuvable")
        return
    end
    
    -- Récupérer le joueur cible s'il est en ligne
    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    
    -- Préparer la raison/libellé du transfert
    local label = reason and reason ~= "" and reason or "Transfert bancaire"
    
    -- Effectuer le transfert
    xPlayer.removeAccountMoney('bank', amount)
    
    -- Enregistrer la transaction sortante pour l'expéditeur
    MySQL.insert('INSERT INTO phone_bank_transactions (identifier, type, amount, label, to_identifier, to_number, date) VALUES (?, ?, ?, ?, ?, ?, NOW())',
        {xPlayer.identifier, 'debit', -amount, label, targetIdentifier, targetNumber})
    
    if xTarget then
        -- Le joueur est en ligne
        xTarget.addAccountMoney('bank', amount)
        
        -- Enregistrer la transaction entrante pour le destinataire
        MySQL.insert('INSERT INTO phone_bank_transactions (identifier, type, amount, label, to_identifier, to_number, date) VALUES (?, ?, ?, ?, ?, ?, NOW())',
            {targetIdentifier, 'credit', amount, label, xPlayer.identifier, phoneNumbers[source]})
        
        -- Notifier le destinataire
        TriggerClientEvent('ox_lib:notify', xTarget.source, {
            title = 'Banque',
            description = 'Vous avez reçu un virement de $' .. amount .. ' de ' .. xPlayer.getName(),
            type = 'success'
        })
    else
        -- Le joueur est hors ligne, mettre à jour la base de données
        local targetMoney = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ?', {targetIdentifier})
        
        if targetMoney and targetMoney[1] then
            local accounts = json.decode(targetMoney[1].accounts)
            accounts.bank = accounts.bank + amount
            
            MySQL.update('UPDATE users SET accounts = ? WHERE identifier = ?', {json.encode(accounts), targetIdentifier})
            
            -- Enregistrer la transaction entrante pour le destinataire hors ligne
            MySQL.insert('INSERT INTO phone_bank_transactions (identifier, type, amount, label, to_identifier, to_number, date) VALUES (?, ?, ?, ?, ?, ?, NOW())',
                {targetIdentifier, 'credit', amount, label, xPlayer.identifier, phoneNumbers[source]})
        end
    end
    
    cb(true, "Transfert réussi")
end)

-- ==========================================
-- CALLBACKS - PARAMÈTRES
-- ==========================================

-- Obtenir les paramètres du téléphone
ESX.RegisterServerCallback('ox_phone:getSettings', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer les paramètres
    local settings = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_settings .. 
                                     ' WHERE identifier = ?', {xPlayer.identifier})
    
    if not settings or not settings[1] then
        -- Créer des paramètres par défaut
        MySQL.insert('INSERT INTO ' .. Config.DatabaseTables.phone_settings .. 
                    ' (identifier) VALUES (?)', {xPlayer.identifier})
        
        cb({
            background = Config.DefaultBackground,
            ringtone = Config.DefaultRingtone,
            notification_sound = 'notification1',
            do_not_disturb = false,
            airplane_mode = false,
            theme = 'default'
        })
    else
        cb(settings[1])
    end
end)

-- Mettre à jour les paramètres
ESX.RegisterServerCallback('ox_phone:updateSettings', function(source, cb, settings)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Vérifier d'abord si des paramètres existent pour ce joueur
    local existingSettings = MySQL.query.await('SELECT identifier FROM ' .. Config.DatabaseTables.phone_settings ..
                                             ' WHERE identifier = ?', {xPlayer.identifier})
    
    if not existingSettings or #existingSettings == 0 then
        -- Insérer de nouveaux paramètres
        local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_settings ..
                                  ' (identifier, background, ringtone, notification_sound, do_not_disturb, airplane_mode, theme) VALUES (?, ?, ?, ?, ?, ?, ?)',
                                  {
                                      xPlayer.identifier,
                                      settings.background or Config.DefaultBackground,
                                      settings.ringtone or Config.DefaultRingtone,
                                      settings.notification_sound or 'notification1',
                                      settings.do_not_disturb or false,
                                      settings.airplane_mode or false,
                                      settings.theme or 'default'
                                  })
        
        cb(insertId and insertId > 0)
    else
        -- Mettre à jour les paramètres existants
        local result = MySQL.update.await('UPDATE ' .. Config.DatabaseTables.phone_settings ..
                                  ' SET background = ?, ringtone = ?, notification_sound = ?, do_not_disturb = ?, airplane_mode = ?, theme = ? ' ..
                                  ' WHERE identifier = ?',
                                  {
                                      settings.background or Config.DefaultBackground,
                                      settings.ringtone or Config.DefaultRingtone,
                                      settings.notification_sound or 'notification1',
                                      settings.do_not_disturb or false,
                                      settings.airplane_mode or false,
                                      settings.theme or 'default',
                                      xPlayer.identifier
                                  })
        
        cb(result and result > 0)
    end
end)

-- ==========================================
-- CALLBACKS - GALERIE PHOTOS
-- ==========================================

-- Sauvegarder une photo dans la galerie
ESX.RegisterServerCallback('ox_phone:saveGalleryPhoto', function(source, cb, imageUrl)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    -- Insérer la photo
    local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_gallery .. 
                                       ' (owner_identifier, image_url) VALUES (?, ?)', 
                                       {xPlayer.identifier, imageUrl})
    
    if not insertId then
        cb(false, nil)
        return
    end
    
    -- Récupérer la photo insérée
    local photo = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_gallery .. 
                                  ' WHERE id = ?', {insertId})
    
    cb(photo and photo[1] ~= nil, photo and photo[1])
end)

-- Obtenir la galerie photos
ESX.RegisterServerCallback('ox_phone:getGallery', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer les photos
    local photos = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_gallery .. 
                                   ' WHERE owner_identifier = ? ORDER BY created_at DESC', 
                                   {xPlayer.identifier})
    
    cb(photos or {})
end)

-- Supprimer une photo
ESX.RegisterServerCallback('ox_phone:deletePhoto', function(source, cb, photoId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Vérifier que la photo appartient bien au joueur
    local photo = MySQL.query.await('SELECT owner_identifier FROM ' .. Config.DatabaseTables.phone_gallery .. 
                                  ' WHERE id = ?', {photoId})
    
    if not photo or not photo[1] or photo[1].owner_identifier ~= xPlayer.identifier then
        cb(false)
        return
    end
    
    -- Supprimer la photo
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_gallery .. 
                                   ' WHERE id = ?', {photoId})
    
    cb(result > 0)
end)

-- ==========================================
-- CALLBACKS - DIVERS (APPELS SPÉCIFIQUES)
-- ==========================================

-- Callback pour récupérer l'ID du joueur à l'autre bout de l'appel
ESX.RegisterServerCallback('ox_phone:getCallTargetId', function(source, cb, callId)
    -- Rechercher l'appel dans les appels actifs
    local callsTable = _G.activeCalls or {}
    
    for _, call in ipairs(callsTable) do
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

-- Callback pour marquer un message comme lu
ESX.RegisterServerCallback('ox_phone:markMessageRead', function(source, cb, sender)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source)
    
    if not phoneNumber then
        cb(false)
        return
    end
    
    -- Marquer tous les messages de cet expéditeur comme lus
    MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_messages .. 
                ' SET is_read = 1 WHERE sender = ? AND receiver = ? AND is_read = 0', 
                {sender, phoneNumber})
    
    cb(true)
end)

-- ==========================================
-- CALLBACKS - YOUTUBE
-- ==========================================

-- Recherche YouTube
ESX.RegisterServerCallback('ox_phone:searchYouTube', function(source, cb, query)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({success = false, message = "Erreur: Joueur introuvable"})
        return
    end
    
    -- Vérifier si la clé API existe
    if not Config.YouTube.apiKey or Config.YouTube.apiKey == '' then
        cb({success = false, message = "Erreur: Clé API YouTube non configurée"})
        return
    end
    
    -- Exécuter la recherche YouTube
    PerformHTTPRequest('https://www.googleapis.com/youtube/v3/search', {
        method = 'GET',
        params = {
            part = 'snippet',
            q = query,
            type = 'video',
            maxResults = Config.YouTube.maxResults,
            key = Config.YouTube.apiKey
        }
    }, function(status, body, headers)
        if status == 200 then
            local data = json.decode(body)
            if data and data.items then
                -- Formater les résultats
                local results = {}
                for _, item in ipairs(data.items) do
                    table.insert(results, {
                        id = item.id.videoId,
                        title = item.snippet.title,
                        description = item.snippet.description,
                        thumbnail = item.snippet.thumbnails.medium.url,
                        channel = item.snippet.channelTitle,
                        published = item.snippet.publishedAt
                    })
                end
                cb({success = true, results = results})
            else
                cb({success = false, message = "Erreur: Format de réponse YouTube invalide"})
            end
        else
            cb({success = false, message = "Erreur: Échec de la requête YouTube (statut " .. tostring(status) .. ")"})
        end
    end)
end)

-- Obtenir les informations d'une vidéo YouTube
ESX.RegisterServerCallback('ox_phone:getVideoInfo', function(source, cb, videoId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({success = false, message = "Erreur: Joueur introuvable"})
        return
    end
    
    -- Vérifier si la clé API existe
    if not Config.YouTube.apiKey or Config.YouTube.apiKey == '' then
        cb({success = false, message = "Erreur: Clé API YouTube non configurée"})
        return
    end
    
    -- Récupérer les informations de la vidéo
    PerformHTTPRequest('https://www.googleapis.com/youtube/v3/videos', {
        method = 'GET',
        params = {
            part = 'snippet,contentDetails,statistics',
            id = videoId,
            key = Config.YouTube.apiKey
        }
    }, function(status, body, headers)
        if status == 200 then
            local data = json.decode(body)
            if data and data.items and data.items[1] then
                local item = data.items[1]
                local videoInfo = {
                    id = item.id,
                    title = item.snippet.title,
                    description = item.snippet.description,
                    thumbnail = item.snippet.thumbnails.medium.url,
                    channel = item.snippet.channelTitle,
                    published = item.snippet.publishedAt,
                    views = item.statistics.viewCount,
                    likes = item.statistics.likeCount,
                    duration = item.contentDetails.duration -- Format ISO 8601
                }
                cb({success = true, video = videoInfo})
                
                -- Ajouter à l'historique
                AddToYouTubeHistory(xPlayer.identifier, videoInfo)
            else
                cb({success = false, message = "Erreur: Vidéo introuvable"})
            end
        else
            cb({success = false, message = "Erreur: Échec de la requête YouTube (statut " .. tostring(status) .. ")"})
        end
    end)
end)

-- Obtenir l'historique YouTube
ESX.RegisterServerCallback('ox_phone:getYouTubeHistory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer l'historique
    local history = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_youtube_history .. 
                                   ' WHERE owner_identifier = ? ORDER BY created_at DESC LIMIT ?', 
                                   {xPlayer.identifier, Config.YouTube.maxHistory})
    
    cb(history or {})
end)

-- Effacer l'historique YouTube
ESX.RegisterServerCallback('ox_phone:clearYouTubeHistory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Supprimer l'historique
    local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_youtube_history .. 
                                    ' WHERE owner_identifier = ?', 
                                    {xPlayer.identifier})
    
    cb(result > 0)
end)

-- Fonction pour ajouter une vidéo à l'historique
function AddToYouTubeHistory(identifier, videoInfo)
    -- Vérifier d'abord si cette vidéo est déjà dans l'historique
    local existing = MySQL.query.await('SELECT id FROM ' .. Config.DatabaseTables.phone_youtube_history .. 
                                     ' WHERE owner_identifier = ? AND video_id = ?', 
                                     {identifier, videoInfo.id})
    
    if existing and #existing > 0 then
        -- Mettre à jour la date
        MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_youtube_history .. 
                    ' SET created_at = NOW() WHERE id = ?', 
                    {existing[1].id})
    else
        -- Insérer une nouvelle entrée
        MySQL.insert('INSERT INTO ' .. Config.DatabaseTables.phone_youtube_history .. 
                    ' (owner_identifier, video_id, title, thumbnail, channel) VALUES (?, ?, ?, ?, ?)', 
                    {identifier, videoInfo.id, videoInfo.title, videoInfo.thumbnail, videoInfo.channel})
        
        -- Nettoyer l'historique si nécessaire
        MySQL.query('DELETE FROM ' .. Config.DatabaseTables.phone_youtube_history .. 
                  ' WHERE owner_identifier = ? AND id NOT IN (SELECT id FROM (SELECT id FROM ' .. 
                  Config.DatabaseTables.phone_youtube_history .. ' WHERE owner_identifier = ? ORDER BY created_at DESC LIMIT ?) as temp)', 
                  {identifier, identifier, Config.YouTube.maxHistory})
    end
end

-- Fonction pour effectuer des requêtes HTTP
function PerformHTTPRequest(url, options, callback)
    -- Construire l'URL avec les paramètres
    if options.params then
        local query = {}
        for k, v in pairs(options.params) do
            table.insert(query, k .. '=' .. encodeURIComponent(v))
        end
        if #query > 0 then
            url = url .. '?' .. table.concat(query, '&')
        end
    end
    
    -- Effectuer la requête
    PerformHttpRequest(url, function(statusCode, responseText, responseHeaders)
        callback(statusCode, responseText, responseHeaders)
    end, options.method or 'GET')
end

-- Fonction pour encoder les paramètres d'URL
function encodeURIComponent(str)
    if str then
        str = string.gsub(str, '([^%w ])', function(c)
            return string.format('%%%02X', string.byte(c))
        end)
        str = string.gsub(str, ' ', '+')
    end
    return str
end

-- ==========================================
-- CALLBACKS - VÉHICULES
-- ==========================================

-- Obtenir les véhicules du joueur
ESX.RegisterServerCallback('ox_phone:getVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    local result = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? ORDER BY plate ASC', {xPlayer.identifier})
    
    cb(result or {})
end)

-- Récupérer les informations d'un véhicule
ESX.RegisterServerCallback('ox_phone:getVehiclePosition', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(nil, nil, nil, nil)
        return
    end
    
    local vehicle = MySQL.query.await('SELECT position, stored, parking, pound FROM owned_vehicles WHERE owner = ? AND plate = ?', 
                                   {xPlayer.identifier, plate})
    
    if vehicle and vehicle[1] then
        cb(vehicle[1].position, vehicle[1].stored, vehicle[1].parking, vehicle[1].pound)
    else
        cb(nil, nil, nil, nil)
    end
end)

-- ==========================================
-- CALLBACKS - ALARMES
-- ==========================================

-- Obtenir les alarmes d'un joueur
ESX.RegisterServerCallback('ox_phone:getAlarms', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer les alarmes
    local alarms = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_alarms .. 
                                   ' WHERE owner_identifier = ? ORDER BY time ASC', 
                                   {xPlayer.identifier})
    
    cb(alarms or {})
end)

-- Ajouter une alarme
ESX.RegisterServerCallback('ox_phone:addAlarm', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false, nil)
        return
    end
    
    -- Insérer l'alarme
    local insertId = MySQL.insert.await('INSERT INTO ' .. Config.DatabaseTables.phone_alarms .. 
                                       ' (owner_identifier, label, time, days, enabled, sound, repeat_weekly) VALUES (?, ?, ?, ?, ?, ?, ?)', 
                                       {xPlayer.identifier, data.label, data.time, data.days, data.enabled or true, data.sound or 'alarm1', data.repeat_weekly or true})
    
    if not insertId then
        cb(false, nil)
        return
    end
    
    -- Récupérer l'alarme insérée
    local alarm = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_alarms .. 
                                  ' WHERE id = ?', {insertId})
    
    cb(alarm and alarm[1] ~= nil, alarm and alarm[1])
end)

-- Mettre à jour une alarme
ESX.RegisterServerCallback('ox_phone:updateAlarm', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Vérifier que l'alarme appartient au joueur
    local alarm = MySQL.query.await('SELECT owner_identifier FROM ' .. Config.DatabaseTables.phone_alarms .. 
                                  ' WHERE id = ?', {data.id})
    
    if not alarm or not alarm[1] or alarm[1].owner_identifier ~= xPlayer.identifier then
        cb(false)
        return
    end
    
    -- Mettre à jour l'alarme
    local result = MySQL.update.await('UPDATE ' .. Config.DatabaseTables.phone_alarms .. 
                                    ' SET label = ?, time = ?, days = ?, enabled = ?, sound = ?, repeat_weekly = ? WHERE id = ?', 
                                    {data.label, data.time, data.days, data.enabled, data.sound, data.repeat_weekly, data.id})
    
    cb(result > 0)
end)

-- Supprimer une alarme
ESX.RegisterServerCallback('ox_phone:deleteAlarm', function(source, cb, alarmId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Vérifier que l'alarme appartient au joueur
    local alarm = MySQL.query.await('SELECT owner_identifier FROM ' .. Config.DatabaseTables.phone_alarms .. 
                                  ' WHERE id = ?', {alarmId})
    
    if not alarm or not alarm[1] or alarm[1].owner_identifier ~= xPlayer.identifier then
        cb(false)
        return
    end
    
    -- Supprimer l'alarme
    local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_alarms .. 
                                    ' WHERE id = ?', {alarmId})
    
    cb(result > 0)
end)

-- Exporter les fonctions
exports('GetPhoneNumber', GetPhoneNumber)
exports('GetContactName', GetContactName)