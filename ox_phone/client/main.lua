-- ox_phone/client/main.lua
local ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}
local phoneOpen = false
local currentApp = nil
local hasPhone = false
local phoneNumber = nil
local activeCall = nil
local ringtoneAudio = nil
local playerServerId = GetPlayerServerId(PlayerId())

-- Variables pour la gestion de la voix
local inCall = false
local activeCallTargetId = nil
local hasPlayedCallSound = false

-- Fonction pour initialiser le téléphone
local function InitializePhone()
    ESX.TriggerServerCallback('ox_phone:getPhoneNumber', function(number)
        if number then
            phoneNumber = number
            lib.notify({
                title = 'Téléphone',
                description = 'Votre numéro: ' .. number,
                type = 'info'
            })
        else
            lib.notify({
                title = 'Téléphone',
                description = 'Erreur d\'initialisation du téléphone',
                type = 'error'
            })
        end
    end)
    
    -- Vérifier si le joueur a un téléphone dans son inventaire
    CheckForPhone()
end

-- Vérification de la présence d'un téléphone dans l'inventaire
function CheckForPhone()
    local hasItem = exports.ox_inventory:Search('count', Config.PhoneItemName)
    hasPhone = hasItem > 0
    return hasPhone
end

-- Fonction pour configurer la voix dans un appel téléphonique
function SetupCallVoice(targetId)
    if not targetId then 
        print("^1[ox_phone]^7 ERROR: No target ID provided")
        return 
    end
    
    activeCallTargetId = tonumber(targetId)
    inCall = true
    
    -- Debug 
    print("^2[ox_phone]^7 Call setup: My ID: " .. playerServerId .. ", Target ID: " .. activeCallTargetId)
    
    -- Canal d'appel unique
    local playerMin = math.min(playerServerId, activeCallTargetId)
    local playerMax = math.max(playerServerId, activeCallTargetId)
    local callChannelId = tonumber(playerMin * 1000 + playerMax)
    
    print("^2[ox_phone]^7 Joining call channel: " .. callChannelId)
    
    -- Vérifier de façon sécurisée si pma-voice est disponible
    local voiceSuccess, voiceError = pcall(function()
        -- Sortir d'abord de tout canal existant
        exports["pma-voice"]:setCallChannel(0)
        Wait(100)
        -- Puis rejoindre le nouveau canal
        exports["pma-voice"]:setCallChannel(callChannelId)
    end)
    
    if voiceSuccess then
        print("^2[ox_phone]^7 Successfully joined call channel " .. callChannelId)
    else
        print("^1[ox_phone]^7 ERROR joining call channel: " .. tostring(voiceError))
    end
    
    -- Animation de téléphone
    Citizen.CreateThread(function()
        while inCall do
            if not IsEntityPlayingAnim(PlayerPedId(), "cellphone@", "cellphone_call_listen_base", 3) then
                lib.requestAnimDict("cellphone@")
                TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_call_listen_base", 3.0, -1, -1, 49, 0, false, false, false)
            end
            Citizen.Wait(1000)
        end
    end)
end

-- Fonction pour terminer l'appel et nettoyer les effets
function EndCallVoice()
    if not inCall then return end
    
    print("^2[ox_phone]^7 Ending call voice effects")
    inCall = false
    local oldCallTargetId = activeCallTargetId
    activeCallTargetId = nil
    hasPlayedCallSound = false
    
    -- Arrêter l'animation de téléphone
    StopAnimTask(PlayerPedId(), "cellphone@", "cellphone_call_listen_base", 1.0)
    
    -- Quitter le canal d'appel avec pma-voice
    local voiceSuccess, voiceError = pcall(function()
        exports["pma-voice"]:setCallChannel(0)
    end)
    
    if voiceSuccess then
        print("^2[ox_phone]^7 Successfully left call channel")
    else
        print("^1[ox_phone]^7 ERROR leaving call channel: " .. tostring(voiceError))
    end
    
    -- Notifier le serveur que nous avons quitté le canal
    if oldCallTargetId then
        TriggerServerEvent('ox_phone:leaveCallChannel', oldCallTargetId)
    end
    
    -- Jouer un son de fin d'appel
    PlaySoundFrontend(-1, "End_Call", "Phone_SoundSet_Default", 1)
end

-- Ouvrir le téléphone
function OpenPhone()
    if not hasPhone then
        lib.notify({
            title = 'Téléphone',
            description = 'Vous n\'avez pas de téléphone',
            type = 'error'
        })
        return
    end
    
    if phoneOpen then
        return
    end
    
    phoneOpen = true
    
    -- Animation pour sortir le téléphone
    lib.requestAnimDict('cellphone@')
    TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_text_in', 3.0, -1, -1, 50, 0, false, false, false)
    
    -- Définir l'accessoire du téléphone
    lib.requestModel(`prop_npc_phone_02`)
    local phoneModel = CreateObject(`prop_npc_phone_02`, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(phoneModel, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    -- Envoyer l'identifiant au NUI pour les interactions avec les tweets, etc.
    SendNUIMessage({
        action = 'openPhone',
        phoneNumber = phoneNumber,
        apps = GetAvailableApps()
    })
    
    -- Sauvegarder l'identifiant du joueur pour la NUI
    SendNUIMessage({
        action = 'setPlayerIdentifier',
        identifier = ESX.GetPlayerData().identifier
    })
    
    -- Ouvrir l'interface NUI
    SetNuiFocus(true, true)
end

-- Fermer le téléphone
function ClosePhone()
    if not phoneOpen then
        return
    end
    
    phoneOpen = false
    
    -- Animation pour ranger le téléphone
    StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_text_in', 1.0)
    TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_text_out', 3.0, -1, -1, 50, 0, false, false, false)
    
    -- Supprimer l'accessoire du téléphone
    local phoneObj = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 1.0, `prop_npc_phone_02`, false, false, false)
    if phoneObj ~= 0 then
        DeleteObject(phoneObj)
    end
    
    -- Fermer l'interface NUI
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closePhone'
    })
    
    currentApp = nil
end

-- Fonction pour gérer les sons FiveM
function PlaySound(soundName, soundSet)
    if not soundName then return end
    
    soundSet = soundSet or "Phone_SoundSet_Default"
    
    -- Jouer le son
    PlaySoundFrontend(-1, soundName, soundSet, 1)
end

-- Fonction pour arrêter tous les sons
function StopAllSounds()
    -- Arrêter tous les sons potentiels
    StopSound(-1, "Ringtone_Default", "Phone_SoundSet_Default")
    StopSound(-1, "Ringtone_Michael", "Phone_SoundSet_Michael")
    StopSound(-1, "Ringtone_Franklin", "Phone_SoundSet_Franklin")
    StopSound(-1, "Ringtone_Trevor", "Phone_SoundSet_Trevor")
    StopSound(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default")
end

-- Obtenir les applications disponibles pour le joueur
function GetAvailableApps()
    local apps = {}
    
    -- Ajouter les applications par défaut
    for _, app in ipairs(Config.Apps) do
        if app.default then
            table.insert(apps, app)
        end
    end
    
    -- Ajouter les applications liées au métier du joueur
    if PlayerData.job then
        local jobApps = Config.JobApps[PlayerData.job.name]
        if jobApps then
            for _, app in ipairs(jobApps) do
                if PlayerData.job.grade >= app.grade then
                    table.insert(apps, app)
                end
            end
        end
    end
    
    return apps
end

-- Écouter les événements de touche pour ouvrir/fermer le téléphone
RegisterCommand('phone', function()
    if not phoneOpen then
        OpenPhone()
    else
        ClosePhone()
    end
end, false)

RegisterKeyMapping('phone', 'Ouvrir/Fermer le téléphone', 'keyboard', Config.OpenKey)

-- Écouter les événements d'ox_target
exports.ox_target:addGlobalVehicle({
    {
        name = 'use_phone',
        icon = 'fas fa-phone',
        label = 'Utiliser le téléphone',
        canInteract = function(entity, distance, coords, name)
            return CheckForPhone() and not phoneOpen
        end,
        onSelect = function()
            OpenPhone()
        end
    }
})

-- Callbacks NUI
RegisterNUICallback('closePhone', function(data, cb)
    ClosePhone()
    cb('ok')
end)

RegisterNUICallback('openApp', function(data, cb)
    currentApp = data.app
    cb('ok')
end)

-- Contacts Callbacks
RegisterNUICallback('getContacts', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getContacts', function(contacts)
        cb(contacts)
    end)
end)

RegisterNUICallback('addContact', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:addContact', function(success, contact)
        cb({success = success, contact = contact})
    end, data.name, data.number)
end)

RegisterNUICallback('deleteContact', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deleteContact', function(success)
        cb({success = success})
    end, data.id)
end)

-- Messages Callbacks
RegisterNUICallback('getMessages', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getMessages', function(messages)
        cb(messages)
    end)
end)

RegisterNUICallback('getConversation', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getConversation', function(messages)
        cb(messages)
    end, data.number)
end)

RegisterNUICallback('sendMessage', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:sendMessage', function(success, message)
        if success then
            -- Notification de succès uniquement visible pour le débogage
            print("Message envoyé avec succès")
        end
        cb({success = success, message = message})
    end, data.to, data.message)
end)



RegisterNUICallback('deleteConversation', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deleteConversation', function(success)
        cb({success = success})
    end, data.number)
end)

RegisterNUICallback('markMessageRead', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:markMessageRead', function(success)
        cb({success = success})
    end, data.sender)
end)



-- Appels Callbacks
RegisterNUICallback('startCall', function(data, cb)
    print("Starting call to: " .. data.number)
    
    TriggerServerEvent('ox_phone:startCall', data.number)
    
    -- Garder une référence à l'appel actif
    activeCall = {
        status = 'outgoing',
        number = data.number
    }
    
    cb('ok')
end)

RegisterNUICallback('answerCall', function(data, cb)
    print("Answering call: " .. tostring(data.callId))
    
    if not activeCall or activeCall.id ~= data.callId then
        print("Warning: Call ID mismatch or no active call")
    end
    
    TriggerServerEvent('ox_phone:answerCall', data.callId)
    
    if activeCall then
        activeCall.status = 'active'
    end
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    cb('ok')
end)

RegisterNUICallback('rejectCall', function(data, cb)
    print("Rejecting call: " .. tostring(data.callId))
    
    if not activeCall or activeCall.id ~= data.callId then
        print("Warning: Call ID mismatch or no active call")
    end
    
    TriggerServerEvent('ox_phone:rejectCall', data.callId)
    
    activeCall = nil
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    cb('ok')
end)

RegisterNUICallback('endCall', function(data, cb)
    print("End call request received")
    
    local callData = {
        id = activeCall and activeCall.id,
        number = activeCall and activeCall.number
    }
    
    print("Call data: ID=" .. tostring(callData.id) .. ", Number=" .. tostring(callData.number))
    
    -- Envoyer l'événement de fin d'appel au serveur
    TriggerServerEvent('ox_phone:endCall', callData)
    
    -- Terminer les effets de voix localement
    EndCallVoice()
    
    -- Réinitialiser l'appel actif
    activeCall = nil
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    cb({success = true})
end)

RegisterNUICallback('getCallHistory', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getCallHistory', function(calls)
        cb(calls)
    end)
end)

-- Nouveau callback NUI pour jouer des sons
RegisterNUICallback('playNotificationSound', function(data, cb)
    print("Lecture du son de notification: " .. tostring(data.sound))
    
    -- Ne rien faire ici, la lecture du son est gérée par le javascript
    cb({success = true})
end)



-- Callbacks pour supprimer des appels de l'historique
RegisterNUICallback('deleteCall', function(data, cb)
    print("Suppression de l'appel ID: " .. tostring(data.callId))
    ESX.TriggerServerCallback('ox_phone:deleteCall', function(success)
        print("Résultat de la suppression de l'appel: " .. tostring(success))
        cb({success = success})
    end, data.callId)
end)


-- Callback pour supprimer plusieurs appels
RegisterNUICallback('deleteMultipleCalls', function(data, cb)
    print("Suppression d'appels multiples: " .. json.encode(data.callIds))
    ESX.TriggerServerCallback('ox_phone:deleteMultipleCalls', function(success)
        print("Résultat de la suppression des appels: " .. tostring(success))
        cb({success = success})
    end, data.callIds)
end)


-- Callback pour supprimer un message
RegisterNUICallback('deleteMessage', function(data, cb)
    print("Suppression du message ID: " .. tostring(data.messageId))
    ESX.TriggerServerCallback('ox_phone:deleteMessage', function(success)
        print("Résultat de la suppression du message: " .. tostring(success))
        cb({success = success})
    end, data.messageId)
end)


-- Callback pour supprimer plusieurs messages
RegisterNUICallback('deleteMultipleMessages', function(data, cb)
    print("Suppression de messages multiples: " .. json.encode(data.messageIds))
    ESX.TriggerServerCallback('ox_phone:deleteMultipleMessages', function(success)
        print("Résultat de la suppression des messages: " .. tostring(success))
        cb({success = success})
    end, data.messageIds)
end)



-- Twitter Callbacks
RegisterNUICallback('getTweets', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getTweets', function(tweets)
        cb(tweets)
    end)
end)

RegisterNUICallback('postTweet', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:postTweet', function(success, tweet)
        cb({success = success, tweet = tweet})
    end, data.message, data.image)
end)

RegisterNUICallback('likeTweet', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:likeTweet', function(success, likes)
        cb({success = success, likes = likes})
    end, data.tweetId)
end)

RegisterNUICallback('addTweetComment', function(data, cb) 
    ESX.TriggerServerCallback('ox_phone:addTweetComment', function(success, comment) 
        cb({success = success, comment = comment})
    end, data.tweetId, data.message)
end)

RegisterNUICallback('getTweetComments', function(data, cb) 
    ESX.TriggerServerCallback('ox_phone:getTweetComments', function(comments) 
        cb(comments)
    end, data.tweetId)
end)


-- Annonces Callbacks
RegisterNUICallback('getAds', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getAds', function(ads)
        cb(ads)
    end)
end)

RegisterNUICallback('postAd', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:postAd', function(success, ad)
        cb({success = success, ad = ad})
    end, data.title, data.message, data.image, data.price)
end)

RegisterNUICallback('deleteAd', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deleteAd', function(success)
        cb({success = success})
    end, data.adId)
end)

-- Banque Callbacks
RegisterNUICallback('getBankData', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getBankData', function(bankData)
        cb(bankData)
    end)
end)

RegisterNUICallback('transferMoney', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:transferMoney', function(success, message)
        cb({success = success, message = message})
    end, data.to, data.amount, data.reason)
end)

-- Paramètres Callbacks
RegisterNUICallback('getSettings', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
        cb(settings)
    end)
end)

RegisterNUICallback('updateSettings', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:updateSettings', function(success)
        cb({success = success})
    end, data.settings)
end)

-- Appareil photo Callbacks
RegisterNUICallback('takePicture', function(data, cb)
    -- Désactiver le NUI pendant la prise de photo
    SetNuiFocus(false, false)
    
    -- Logique de caméra...
    local cameraHandle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cameraHandle, true)
    RenderScriptCams(true, false, 0, true, true)
    
    -- Mode selfie ou caméra arrière
    local isSelfie = data.selfie or false
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local rotation = GetEntityRotation(playerPed)
    
    if isSelfie then
        -- Mode selfie: caméra face au joueur
        local forwardVector = GetEntityForwardVector(playerPed)
        local pos = vector3(
            coords.x - forwardVector.x * 1.0,
            coords.y - forwardVector.y * 1.0,
            coords.z + 0.7
        )
        SetCamCoord(cameraHandle, pos)
        PointCamAtCoord(cameraHandle, coords.x, coords.y, coords.z + 0.7)
    else
        -- Mode caméra normale
        local forwardVector = GetEntityForwardVector(playerPed)
        local pos = vector3(
            coords.x,
            coords.y,
            coords.z + 0.7
        )
        SetCamCoord(cameraHandle, pos)
        PointCamAtCoord(cameraHandle, 
            coords.x + forwardVector.x * 10.0, 
            coords.y + forwardVector.y * 10.0, 
            coords.z + 0.7
        )
    end
    
    Wait(500) -- Attendre que la caméra se mette en place
    
    -- Jouer un son de prise de photo pour l'immersion
    PlaySoundFrontend(-1, "Camera_Shoot", "Phone_Soundset_Franklin", 1)
    
    -- Prendre la photo
    exports['screenshot-basic']:requestScreenshotUpload(GetConvar("screenshot_webhook", "https://discord.com/api/webhooks/VOTRE_WEBHOOK_ICI"), "files[]", {
        encoding = 'jpg',
        quality = 0.85
    }, function(data)
        -- Vérifier si les données sont valides
        if data then
            local success = false
            local imageUrl = ""
            
            -- Tenter de décoder la réponse JSON
            local resp = json.decode(data)
            if resp then
                -- Discord webhook retourne généralement les URLs dans ce format
                if resp.attachments and resp.attachments[1] and resp.attachments[1].url then
                    success = true
                    imageUrl = resp.attachments[1].url
                -- Autre format possible de réponse
                elseif resp.url then
                    success = true
                    imageUrl = resp.url
                end
            end
            
            -- Si on a une URL d'image valide
            if success and imageUrl ~= "" then
                -- Sauvegarder dans la galerie
                ESX.TriggerServerCallback('ox_phone:saveGalleryPhoto', function(success, photo)
                    -- Réactiver le NUI
                    SetNuiFocus(true, true)
                    
                    -- Détruire la caméra
                    RenderScriptCams(false, false, 0, true, true)
                    DestroyCam(cameraHandle, false)
                    
                    -- Retourner le résultat
                    cb({success = success, photo = photo})
                end, imageUrl)
            else
                -- Échec de l'upload
                SetNuiFocus(true, true)
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(cameraHandle, false)
                cb({success = false, message = "Échec de l'upload de la photo"})
            end
        else
            -- Échec de la prise de photo
            SetNuiFocus(true, true)
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(cameraHandle, false)
            cb({success = false, message = "Échec de la prise de photo"})
        end
    end)
end)

RegisterNUICallback('getGallery', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getGallery', function(photos)
        cb(photos)
    end)
end)

RegisterNUICallback('deletePhoto', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deletePhoto', function(success)
        cb({success = success})
    end, data.photoId)
end)

-- Événements
RegisterNetEvent('ox_phone:outgoingCallStarted')
AddEventHandler('ox_phone:outgoingCallStarted', function(callId, receiverNumber)
    print("^2[ox_phone]^7 Outgoing call started: ID=" .. callId .. ", Number=" .. receiverNumber)
    
    if activeCall and activeCall.number == receiverNumber then
        activeCall.id = callId
        
        -- Informer l'interface
        SendNUIMessage({
            action = 'outgoingCallStarted',
            callId = callId
        })
    end
end)

RegisterNetEvent('ox_phone:joinCallChannel')
AddEventHandler('ox_phone:joinCallChannel', function(channelId)
    print("^2[ox_phone]^7 Received joinCallChannel event with channel: " .. tostring(channelId))
    
    -- Rejoindre le canal d'appel spécifié
    local voiceSuccess, voiceError = pcall(function()
        exports["pma-voice"]:setCallChannel(tonumber(channelId))
    end)
    
    if voiceSuccess then
        print("^2[ox_phone]^7 Successfully joined call channel: " .. channelId)
    else
        print("^1[ox_phone]^7 ERROR joining call channel: " .. tostring(voiceError))
    end
end)

RegisterNetEvent('ox_phone:otherPlayerLeftCall')
AddEventHandler('ox_phone:otherPlayerLeftCall', function()
    print("^2[ox_phone]^7 Other player left the call")
    
    -- Quitter notre canal d'appel aussi
    if inCall then
        EndCallVoice()
        
        -- Informer l'UI que l'appel est terminé
        SendNUIMessage({
            action = 'callEnded',
            callId = activeCall and activeCall.id
        })
        
        activeCall = nil
    end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    InitializePhone()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('ox_inventory:itemCount')
AddEventHandler('ox_inventory:itemCount', function(itemName, count)
    if itemName == Config.PhoneItemName then
        hasPhone = count > 0
    end
end)

-- Événements téléphoniques
RegisterNetEvent('ox_phone:receiveMessage')
AddEventHandler('ox_phone:receiveMessage', function(sender, message, time, id)
    -- Récupérer les paramètres de l'utilisateur pour vérifier le mode NPD et le son choisi
    ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
        if settings and not settings.do_not_disturb and not settings.airplane_mode then
            -- Envoyer un événement NUI pour jouer le son
            SendNUIMessage({
                action = 'playNotificationSound',
                sound = settings.notification_sound or 'notification1'
            })
        end
    end)
    
    -- Notification visuelle
    lib.notify({
        title = 'Nouveau message',
        description = 'De: ' .. sender,
        type = 'info'
    })
    
    -- Si le téléphone est ouvert, envoyer la mise à jour à l'interface
    if phoneOpen then
        SendNUIMessage({
            action = 'newMessage',
            sender = sender,
            message = message,
            time = time,
            id = id or math.random(100000, 999999)
        })
    else
        -- Si le téléphone est fermé, envoyer une notification NUI pour afficher la notification
        ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
            if settings and not settings.do_not_disturb and not settings.airplane_mode then
                SendNUIMessage({
                    action = 'showSmsNotification',
                    sender = sender,
                    message = message
                })
            end
        end)
    end
end)



-- Ajouter cette fonction pour gérer les sons du téléphone plus efficacement
function PlayPhoneSound(soundName, soundSet)
    soundSet = soundSet or "Phone_SoundSet_Default"
    
    -- Essayer de jouer le son de manière robuste
    if soundName and soundSet then
        PlaySoundFrontend(-1, soundName, soundSet, 1)
    elseif soundName then
        PlaySoundFrontend(-1, soundName, "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", 1)
    end
end


function StopAllSounds()
    StopSound(-1, "Ringtone_Default", "Phone_SoundSet_Default")
    StopSound(-1, "Ringtone_Michael", "Phone_SoundSet_Michael")
    StopSound(-1, "Ringtone_Franklin", "Phone_SoundSet_Franklin")
    StopSound(-1, "Ringtone_Trevor", "Phone_SoundSet_Trevor")
    StopSound(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default")
end


RegisterNetEvent('ox_phone:incomingCall')
AddEventHandler('ox_phone:incomingCall', function(callId, caller, callerName)
    print("^2[ox_phone]^7 Incoming call: ID=" .. callId .. ", From=" .. caller)
    
    -- Mettre à jour l'appel actif
    activeCall = {
        id = callId,
        number = caller,
        caller = caller,
        callerName = callerName,
        status = 'incoming'
    }
    
    -- Jouer la sonnerie
    PlaySoundFrontend(-1, "Ringtone_Default", "Phone_SoundSet_Default", 1)
    Citizen.CreateThread(function()
        local ringCount = 0
        while activeCall and activeCall.status == 'incoming' and ringCount < 10 do
            Wait(3000) -- 3 secondes entre chaque sonnerie
            if activeCall and activeCall.status == 'incoming' then
                PlaySoundFrontend(-1, "Ringtone_Default", "Phone_SoundSet_Default", 1)
                ringCount = ringCount + 1
            end
        end
    end)
    
    -- Afficher une notification
    lib.notify({
        title = 'Appel entrant',
        description = callerName or caller,
        type = 'info',
        duration = 10000
    })
    
    -- Si le téléphone est déjà ouvert
    if phoneOpen then
        SendNUIMessage({
            action = 'incomingCall',
            callId = callId,
            caller = caller,
            callerName = callerName
        })
    else
        -- Ouvrir le téléphone automatiquement si il est dans l'inventaire
        if hasPhone then
            OpenPhone()
            Wait(500)
            SendNUIMessage({
                action = 'incomingCall',
                callId = callId,
                caller = caller,
                callerName = callerName
            })
        end
    end
end)

RegisterNetEvent('ox_phone:callAnswered')
AddEventHandler('ox_phone:callAnswered', function(callId)
    print("^2[ox_phone]^7 Call answered: " .. callId)
    
    if activeCall and activeCall.id == callId then
        activeCall.status = 'active'
        
        -- Récupérer l'ID du joueur à l'autre bout de l'appel
        ESX.TriggerServerCallback('ox_phone:getCallTargetId', function(targetId)
            if targetId then
                print("^2[ox_phone]^7 Setting up voice with target: " .. targetId)
                -- Configurer la voix pour l'appel
                SetupCallVoice(targetId)
            else
                print("^1[ox_phone]^7 No target ID returned for call")
            end
        end, callId)
    end
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    SendNUIMessage({
        action = 'callAnswered',
        callId = callId
    })
end)

RegisterNetEvent('ox_phone:callRejected')
AddEventHandler('ox_phone:callRejected', function(callId)
    print("^2[ox_phone]^7 Call rejected: " .. callId)
    
    if activeCall and activeCall.id == callId then
        activeCall = nil
    end
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    SendNUIMessage({
        action = 'callRejected',
        callId = callId
    })
end)

RegisterNetEvent('ox_phone:callEnded')
AddEventHandler('ox_phone:callEnded', function(callId)
    print("^2[ox_phone]^7 Call ended: " .. callId)
    
    if activeCall and activeCall.id == callId then
        -- Terminer les effets de voix
        EndCallVoice()
        
        activeCall = nil
    end
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    SendNUIMessage({
        action = 'callEnded',
        callId = callId
    })
end)

RegisterNetEvent('ox_phone:newTweet')
AddEventHandler('ox_phone:newTweet', function(tweet)
    -- Jouer le son de notification personnalisé
    ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
        if settings and not settings.do_not_disturb and not settings.airplane_mode then
            -- Envoyer un événement NUI pour jouer le son
            SendNUIMessage({
                action = 'playNotificationSound',
                sound = settings.notification_sound or 'notification1'
            })
        end
    end)
    
    lib.notify({
        title = 'Nouveau tweet',
        description = tweet.author .. ': ' .. tweet.message:sub(1, 30) .. '...',
        type = 'info'
    })
    
    if phoneOpen and currentApp == 'twitter' then
        SendNUIMessage({
            action = 'newTweet',
            tweet = tweet
        })
    end
end)

RegisterNetEvent('ox_phone:newAd')
AddEventHandler('ox_phone:newAd', function(ad)
    -- Jouer le son de notification personnalisé
    ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
        if settings and not settings.do_not_disturb and not settings.airplane_mode then
            -- Envoyer un événement NUI pour jouer le son
            SendNUIMessage({
                action = 'playNotificationSound',
                sound = settings.notification_sound or 'notification1'
            })
        end
    end)
    
    lib.notify({
        title = 'Nouvelle annonce',
        description = ad.title,
        type = 'info'
    })
    
    if phoneOpen and currentApp == 'ads' then
        SendNUIMessage({
            action = 'newAd',
            ad = ad
        })
    end
end)

-- Commande pour tester pma-voice
RegisterCommand('testvoice', function()
    -- Vérifier si pma-voice est disponible
    local pmaAvailable = (exports["pma-voice"] ~= nil)
    print("^2[ox_phone]^7 PMA-Voice disponible: " .. tostring(pmaAvailable))
    
    if pmaAvailable then
        -- Test de setCallChannel
        print("^2[ox_phone]^7 Test de setCallChannel...")
        
        local success1, error1 = pcall(function()
            exports["pma-voice"]:setCallChannel(12345)
        end)
        
        if success1 then
            print("^2[ox_phone]^7 Test 1 réussi: Canal d'appel défini à 12345")
        else
            print("^1[ox_phone]^7 Test 1 échoué: " .. tostring(error1))
        end
        
        Wait(2000)
        
        local success2, error2 = pcall(function()
            exports["pma-voice"]:setCallChannel(0)
        end)
        
        if success2 then
            print("^2[ox_phone]^7 Test 2 réussi: Canal d'appel réinitialisé à 0")
        else
            print("^1[ox_phone]^7 Test 2 échoué: " .. tostring(error2))
        end
    else
        print("^1[ox_phone]^7 ERREUR: pma-voice n'est pas disponible!")
    end
end)

-- Initialiser le téléphone au démarrage
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    
    PlayerData = ESX.GetPlayerData()
    InitializePhone()
end)

-- À l'arrêt de la ressource, fermer le téléphone
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    if phoneOpen then
        ClosePhone()
    end
    
    -- Nettoyer les sons et effets
    StopAllSounds()
    if inCall then
        EndCallVoice()
    end
end)