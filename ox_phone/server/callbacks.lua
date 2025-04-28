-- ox_phone/server/callbacks.lua
local ESX = exports['es_extended']:getSharedObject()

-- Gestion des callbacks du téléphone

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
-- Supprimer un contact
ESX.RegisterServerCallback('ox_phone:deleteContact', function(source, cb, contactId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source) -- Ajout de cette ligne
    
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                   ' WHERE id = ? AND owner_identifier = ?', 
                                   {contactId, xPlayer.identifier})
    
    cb(result and result > 0) 
end)


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
    
    -- Récupérer les conversations uniques
    local conversations = {}
    local seen = {}
    
    -- Messages envoyés
    local sent = MySQL.query.await('SELECT DISTINCT receiver AS number FROM ' .. Config.DatabaseTables.phone_messages .. 
                                 ' WHERE sender = ? ORDER BY created_at DESC', {phoneNumber})
    
    if sent then
        for _, v in ipairs(sent) do
            if not seen[v.number] then
                seen[v.number] = true
                
                -- Obtenir le dernier message
                local lastMessage = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                                    ' WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?) ' .. 
                                                    ' ORDER BY created_at DESC LIMIT 1', 
                                                    {phoneNumber, v.number, v.number, phoneNumber})
                
                if lastMessage and lastMessage[1] then
                    -- Compter les messages non lus
                    local unread = MySQL.query.await('SELECT COUNT(*) AS count FROM ' .. Config.DatabaseTables.phone_messages .. 
                                                   ' WHERE sender = ? AND receiver = ? AND is_read = 0', 
                                                   {v.number, phoneNumber})
                    
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
    
    -- Messages reçus
    local received = MySQL.query.await('SELECT DISTINCT sender AS number FROM ' .. Config.DatabaseTables.phone_messages .. 
                                     ' WHERE receiver = ? ORDER BY created_at DESC', {phoneNumber})
    
    if received then
        for _, v in ipairs(received) do
            if not seen[v.number] then
                seen[v.number] = true
                
                -- Obtenir le dernier message
                local lastMessage = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                                    ' WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?) ' .. 
                                                    ' ORDER BY created_at DESC LIMIT 1', 
                                                    {phoneNumber, v.number, v.number, phoneNumber})
                
                if lastMessage and lastMessage[1] then
                    -- Compter les messages non lus
                    local unread = MySQL.query.await('SELECT COUNT(*) AS count FROM ' .. Config.DatabaseTables.phone_messages .. 
                                                   ' WHERE sender = ? AND receiver = ? AND is_read = 0', 
                                                   {v.number, phoneNumber})
                    
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

    -- Récupérer tous les messages entre ces deux numéros
    local messages = MySQL.query.await('SELECT *, (CASE WHEN sender = ? THEN 1 ELSE 0 END) AS is_sender FROM ' .. Config.DatabaseTables.phone_messages ..
                                     ' WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?) ' ..
                                     ' ORDER BY created_at ASC',
                                     {phoneNumber, phoneNumber, number, number, phoneNumber})

    -- Marquer tous les messages non lus comme lus
    MySQL.update('UPDATE ' .. Config.DatabaseTables.phone_messages ..
                ' SET is_read = 1 WHERE sender = ? AND receiver = ? AND is_read = 0',
                {number, phoneNumber})

    -- Obtenir le nom du contact si existant
    local contactName = GetContactName(source, number)

    cb({
        number = number,
        name = contactName,
        messages = messages or {}
    })
end)

-- Envoyer un message
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
    
    -- Vérifier si le destinataire est un service d'urgence
    local isEmergency = false
    local emergencyJob = nil
    
    for job, data in pairs(Config.EmergencyNumbers) do
        if data.number == to then
            isEmergency = true
            emergencyJob = job
            break
        end
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
    
    -- Si c'est un message à un service d'urgence
    if isEmergency then
        -- Notifier tous les employés du service correspondant
        local xPlayers = ESX.GetExtendedPlayers('job', emergencyJob)
        for _, xTarget in pairs(xPlayers) do
            local targetSource = xTarget.source
            local targetNumber = GetPhoneNumber(targetSource)
            
            if targetNumber then
                -- Envoyer le message avec plus d'information
                TriggerClientEvent('ox_phone:receiveMessage', targetSource, phoneNumber, message, newMessage[1].created_at, newMessage[1].id)
               
            end
        end
    else
        -- Chercher le destinataire
        local targetSource = nil
        
        for src, num in pairs(phoneNumbers) do
            if num == to then
                targetSource = tonumber(src)
                break
            end
        end
        
        -- Notifier le destinataire s'il est en ligne
        if targetSource then
            -- Notifier de la réception du message
            TriggerClientEvent('ox_phone:receiveMessage', targetSource, phoneNumber, message, newMessage[1].created_at, newMessage[1].id)
            
        end
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
    
    -- Supprimer tous les messages entre ces deux numéros
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_messages .. 
                                   ' WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)', 
                                   {phoneNumber, number, number, phoneNumber})
    
    cb(result and result.affectedRows > 0)
end)

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

    print("Récupération de l'historique des appels pour le numéro: " .. phoneNumber)

    -- Récupérer l'historique des appels avec plus de détails et une meilleure gestion des statuts
    local calls = MySQL.query.await('SELECT *, (CASE WHEN caller = ? THEN "outgoing" ELSE "incoming" END) AS direction FROM ' .. Config.DatabaseTables.phone_calls ..
                                  ' WHERE caller = ? OR receiver = ? ORDER BY created_at DESC LIMIT 50',
                                  {phoneNumber, phoneNumber, phoneNumber})

    if not calls then
        cb({})
        return
    end

    print("Nombre d'appels trouvés: " .. #calls)

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

        print(string.format("Appel %d: de=%s à=%s, direction=%s, statut=%s, durée=%d",
                           call.id, call.caller, call.receiver, calls[i].direction, calls[i].status, call.duration))
    end

    cb(calls)
end)

-- Supprimer un appel de l'historique
ESX.RegisterServerCallback('ox_phone:deleteCall', function(source, cb, callId)
    print("Tentative de suppression de l'appel ID: " .. tostring(callId))
    
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
    
    -- Vérifier d'abord que l'appel existe et appartient au joueur
    local callCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_calls .. 
                                      ' WHERE id = ? AND (caller = ? OR receiver = ?)', 
                                      {callId, phoneNumber, phoneNumber})
    
    if not callCheck or #callCheck == 0 then
        print("Appel non trouvé ou n'appartenant pas au joueur")
        cb(false)
        return
    end
    
    -- Supprimer l'appel
    local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_calls .. 
                                    ' WHERE id = ? AND (caller = ? OR receiver = ?)', 
                                    {callId, phoneNumber, phoneNumber})
    
    print("Résultat de la suppression: " .. tostring(result and result.affectedRows or 0) .. " lignes affectées")
    
    cb(result > 0)
end)

-- Amélioration du callback pour supprimer plusieurs appels
ESX.RegisterServerCallback('ox_phone:deleteMultipleCalls', function(source, cb, callIds)
    if not callIds or #callIds == 0 then
        cb(false)
        return
    end
    
    print("Tentative de suppression des appels IDs: " .. table.concat(callIds, ", "))
    
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
    
    print("Total appels supprimés: " .. totalDeleted .. " sur " .. #callIds)
    
    cb(success and totalDeleted == #callIds)
end)


ESX.RegisterServerCallback('ox_phone:deleteMessage', function(source, cb, messageId)
    print("Tentative de suppression du message ID: " .. tostring(messageId))
    
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
    
    -- Vérifier d'abord que le message existe et appartient au joueur
    local messageCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                         ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                         {messageId, phoneNumber, phoneNumber})
    
    if not messageCheck or #messageCheck == 0 then
        print("Message non trouvé ou n'appartenant pas au joueur")
        cb(false)
        return
    end
    
    -- Supprimer le message
    local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_messages .. 
                                    ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                    {messageId, phoneNumber, phoneNumber})
    
    print("Résultat de la suppression: " .. tostring(result and result.affectedRows or 0) .. " lignes affectées")
    
    cb(result > 0)
end)


-- Amélioration du callback pour supprimer plusieurs messages
ESX.RegisterServerCallback('ox_phone:deleteMultipleMessages', function(source, cb, messageIds)
    if not messageIds or #messageIds == 0 then
        cb(false)
        return
    end
    
    print("Tentative de suppression des messages IDs: " .. table.concat(messageIds, ", "))
    
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
    
    print("Total messages supprimés: " .. totalDeleted .. " sur " .. #messageIds)
    
    cb(success and totalDeleted == #messageIds)
end)

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
                                       ' (author, author_identifier, title, message, image, price) VALUES (?, ?, ?, ?, ?, ?)', 
                                       {charName, xPlayer.identifier, title, message, image or nil, price or nil})
    
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

-- Obtenir les données bancaires
ESX.RegisterServerCallback('ox_phone:getBankData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    -- Récupérer le solde bancaire et les transactions récentes
    local bankData = {
        balance = xPlayer.getAccount('bank').money,
        transactions = {} -- Ceci dépend de votre système bancaire
    }
    
    -- Si vous utilisez un système de banque personnalisé, vous pouvez récupérer les transactions ici
    
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
    
    -- Vérifier si c'est un numéro de téléphone
    local targetResult = MySQL.query.await('SELECT identifier FROM users WHERE phone_number = ?', {to})
    
    if targetResult and targetResult[1] then
        targetIdentifier = targetResult[1].identifier
    end
    
    if not targetIdentifier then
        cb(false, "Destinataire introuvable")
        return
    end
    
    -- Récupérer le joueur cible s'il est en ligne
    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    
    -- Effectuer le transfert
    xPlayer.removeAccountMoney('bank', amount)
    
    if xTarget then
        -- Le joueur est en ligne
        xTarget.addAccountMoney('bank', amount)
        
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
        end
    end
    
    -- Enregistrer la transaction dans l'historique si vous avez un système de banque personnalisé
    
    cb(true, "Transfert réussi")
end)

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
-- Mettre à jour les paramètres
ESX.RegisterServerCallback('ox_phone:updateSettings', function(source, cb, settings)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    print("Mise à jour des paramètres du téléphone: " .. json.encode(settings))

    -- Vérifier d'abord si des paramètres existent pour ce joueur
    local existingSettings = MySQL.query.await('SELECT identifier FROM ' .. Config.DatabaseTables.phone_settings ..
                                             ' WHERE identifier = ?', {xPlayer.identifier})

    local result

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

        print("Résultat de la mise à jour: " .. tostring(result and result.affectedRows or 0) .. " lignes affectées")

        cb(result > 0)
    end
end)


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


-- Supprimer un contact
ESX.RegisterServerCallback('ox_phone:deleteContact', function(source, cb, contactId)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local phoneNumber = GetPhoneNumber(source) -- Ajout de cette ligne
    
    local result = MySQL.query.await('DELETE FROM ' .. Config.DatabaseTables.phone_contacts .. 
                                   ' WHERE id = ? AND owner_identifier = ?', 
                                   {contactId, xPlayer.identifier})
    
    cb(result and result > 0) -- Correction ici
end)

-- Amélioration du callback pour supprimer plusieurs appels
ESX.RegisterServerCallback('ox_phone:deleteMultipleCalls', function(source, cb, callIds)
    if not callIds or #callIds == 0 then
        cb(false)
        return
    end
    
    print("Tentative de suppression des appels IDs: " .. table.concat(callIds, ", "))
    
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
            
            if result > 0 then -- Correction ici
                totalDeleted = totalDeleted + 1
            else
                success = false
            end
        else
            success = false
        end
    end
    
    print("Total appels supprimés: " .. totalDeleted .. " sur " .. #callIds)
    
    cb(success and totalDeleted == #callIds)
end)

-- Supprimer un message
ESX.RegisterServerCallback('ox_phone:deleteMessage', function(source, cb, messageId)
    print("Tentative de suppression du message ID: " .. tostring(messageId))
    
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
    
    -- Vérifier d'abord que le message existe et appartient au joueur
    local messageCheck = MySQL.query.await('SELECT * FROM ' .. Config.DatabaseTables.phone_messages .. 
                                         ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                         {messageId, phoneNumber, phoneNumber})
    
    if not messageCheck or #messageCheck == 0 then
        print("Message non trouvé ou n'appartenant pas au joueur")
        cb(false)
        return
    end
    
    -- Supprimer le message
    local result = MySQL.update.await('DELETE FROM ' .. Config.DatabaseTables.phone_messages .. 
                                    ' WHERE id = ? AND (sender = ? OR receiver = ?)', 
                                    {messageId, phoneNumber, phoneNumber})
    
    print("Résultat de la suppression: " .. tostring(result and result.affectedRows or 0) .. " lignes affectées")
    
    cb(result > 0)
end)

-- Amélioration du callback pour supprimer plusieurs messages
ESX.RegisterServerCallback('ox_phone:deleteMultipleMessages', function(source, cb, messageIds)
    if not messageIds or #messageIds == 0 then
        cb(false)
        return
    end
    
    print("Tentative de suppression des messages IDs: " .. table.concat(messageIds, ", "))
    
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
    
    print("Total messages supprimés: " .. totalDeleted .. " sur " .. #messageIds)
    
    cb(success and totalDeleted == #messageIds)
end)

-- Mettre à jour les paramètres
ESX.RegisterServerCallback('ox_phone:updateSettings', function(source, cb, settings)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    print("Mise à jour des paramètres du téléphone: " .. json.encode(settings))

    -- Vérifier d'abord si des paramètres existent pour ce joueur
    local existingSettings = MySQL.query.await('SELECT identifier FROM ' .. Config.DatabaseTables.phone_settings ..
                                             ' WHERE identifier = ?', {xPlayer.identifier})

    local result

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

        print("Résultat de la mise à jour: " .. tostring(result or 0) .. " lignes affectées") 


        cb(result > 0) 
    end
end)

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

-- Exporter les fonctions
exports('GetPhoneNumber', GetPhoneNumber)
exports('GetContactName', GetContactName)

