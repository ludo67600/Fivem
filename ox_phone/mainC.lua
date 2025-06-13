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



--------------------------------------------------
-- INITIALISATION ET FONCTIONS PRINCIPALES
--------------------------------------------------

-- Fonction pour initialiser le téléphone
local function InitializePhone()
    ESX.TriggerServerCallback('ox_phone:getPhoneNumber', function(number)
        if number then
            phoneNumber = number
ShowPhoneNotification('Téléphone', 'Votre numéro: ' .. number, 'info', 'fa-phone')
        else
ShowPhoneNotification('Téléphone', 'Erreur d\'initialisation du téléphone', 'error', 'fa-exclamation-circle')
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

-- Ouvrir le téléphone
function OpenPhone()
    if not hasPhone then
        ShowPhoneNotification('Téléphone', 'Vous n\'avez pas de téléphone', 'error', 'fa-mobile-alt')
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
    
    -- Arrêter immédiatement l'animation d'entrée si elle est en cours
    StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_text_in', 1.0)
    
    -- Animation pour ranger le téléphone
    lib.requestAnimDict('cellphone@')
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
    
    -- Thread pour s'assurer que l'animation se termine correctement
    Citizen.CreateThread(function()
        -- Attendre que l'animation de sortie se termine (environ 2 secondes)
        Citizen.Wait(2000)
        
        -- Forcer l'arrêt de toutes les animations du téléphone
        StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_text_out', 1.0)
        StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_text_in', 1.0)
        StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 1.0)
        
        -- Forcer le reset de l'animation du personnage
        ClearPedTasks(PlayerPedId())
        
        -- Optionnel: Jouer une animation neutre très brève pour remettre les bras en position normale
        TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_a', 1.0, 1.0, 100, 0, 0, false, false, false)
        Citizen.Wait(100)
        StopAnimTask(PlayerPedId(), 'mp_common', 'givetake1_a', 1.0)
    end)
end



-- Fonction unifiée pour les notifications
function ShowPhoneNotification(title, message, type, icon, duration, isImage)
    -- Valeurs par défaut
    type = type or 'info'
    icon = icon or 'fa-bell'
    duration = duration or 5000
    isImage = isImage or false
    
    -- Envoyer au NUI
    SendNUIMessage({
        action = 'showPhoneNotification',
        title = title,
        message = message,
        type = type,
        icon = icon,
        duration = duration,
        isImage = isImage
    })
end

-- Version plus simple pour maintenir la compatibilité avec le code existant
function ShowNotification(message, type)
    ShowPhoneNotification('Téléphone', message, type or 'info')
end

-- Callback pour les notifications depuis JavaScript
RegisterNUICallback('showPhoneNotification', function(data, cb)
    ShowPhoneNotification(data.title, data.message, data.type, data.icon, data.duration, data.isImage)
    cb('ok')
end)

-- Callback pour jouer un son de notification
RegisterNUICallback('playNotificationSound', function(data, cb)
    local sound = data.sound or currentNotificationSound
    if not doNotDisturb and not airplaneMode then
        if data.asRingtone then
            PlaySound(-1, sound, "Phone_SoundSet_Default", 0, 0, 1)
        else
            PlaySound(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", 0, 0, 1)
        end
    end
    cb('ok')
end)


--------------------------------------------------
-- FONCTIONS DE GESTION DE LA VOIX ET DES APPELS
--------------------------------------------------

-- Fonction pour configurer la voix dans un appel téléphonique
function SetupCallVoice(targetId)
    if not targetId then return end
    
    activeCallTargetId = tonumber(targetId)
    inCall = true
    
    -- Canal d'appel unique
    local playerMin = math.min(playerServerId, activeCallTargetId)
    local playerMax = math.max(playerServerId, activeCallTargetId)
    local callChannelId = tonumber(playerMin * 1000 + playerMax)
    
    -- Vérifier de façon sécurisée si pma-voice est disponible
    local voiceSuccess = pcall(function()
        -- Sortir d'abord de tout canal existant
        exports["pma-voice"]:setCallChannel(0)
        Wait(100)
        -- Puis rejoindre le nouveau canal
        exports["pma-voice"]:setCallChannel(callChannelId)
    end)
    
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
    
    inCall = false
    local oldCallTargetId = activeCallTargetId
    activeCallTargetId = nil
    hasPlayedCallSound = false
    
    -- Arrêter l'animation de téléphone
    StopAnimTask(PlayerPedId(), "cellphone@", "cellphone_call_listen_base", 1.0)
    
    -- Quitter le canal d'appel avec pma-voice
    pcall(function()
        exports["pma-voice"]:setCallChannel(0)
    end)
    
    -- Notifier le serveur que nous avons quitté le canal
    if oldCallTargetId then
        TriggerServerEvent('ox_phone:leaveCallChannel', oldCallTargetId)
    end
    
    -- Jouer un son de fin d'appel
    PlaySoundFrontend(-1, "End_Call", "Phone_SoundSet_Default", 1)
end

--------------------------------------------------
-- FONCTIONS DE GESTION DU SON
--------------------------------------------------

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

--------------------------------------------------
-- FONCTIONS UTILITAIRES
--------------------------------------------------

-- Obtenir les applications disponibles pour le joueur
function GetAvailableApps()
    local apps = {}
    local playerJob = ESX.GetPlayerData().job.name
    
    -- Ajouter les applications par défaut
    for _, app in ipairs(Config.Apps) do
        if app.default then
            table.insert(apps, app)
        elseif app.name == 'agent' and Config.AgentApp and Config.AgentApp.AuthorizedJobs and Config.AgentApp.AuthorizedJobs[playerJob] then
            -- Inclure l'application Agent avec l'icône spécifique au job
            local agentApp = table.copy(app) -- Copier l'app pour ne pas modifier l'original
            agentApp.icon = Config.AgentApp.AuthorizedJobs[playerJob].icon
            table.insert(apps, agentApp)
        end
    end
    
    return apps
end

-- Fonction utilitaire pour copier une table
function table.copy(t)
    local u = {}
    for k, v in pairs(t) do u[k] = v end
    return u
end

--------------------------------------------------
-- COMMANDES ET TOUCHES
--------------------------------------------------

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

--------------------------------------------------
-- CALLBACKS NUI
--------------------------------------------------

-- Callbacks généraux
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
    TriggerServerEvent('ox_phone:startCall', data.number)
    
    -- Garder une référence à l'appel actif
    activeCall = {
        status = 'outgoing',
        number = data.number
    }
    
    cb('ok')
end)

RegisterNUICallback('answerCall', function(data, cb)
    TriggerServerEvent('ox_phone:answerCall', data.callId)
    
    if activeCall then
        activeCall.status = 'active'
    end
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    cb('ok')
end)

RegisterNUICallback('rejectCall', function(data, cb)
    TriggerServerEvent('ox_phone:rejectCall', data.callId)
    
    activeCall = nil
    
    -- Arrêter la sonnerie
    StopAllSounds()
    
    cb('ok')
end)

RegisterNUICallback('endCall', function(data, cb)
    local callData = {
        id = activeCall and activeCall.id,
        number = activeCall and activeCall.number
    }
    
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

RegisterNUICallback('deleteCall', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deleteCall', function(success)
        cb({success = success})
    end, data.callId)
end)

-- Messages Callbacks
RegisterNUICallback('deleteMessage', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:deleteMessage', function(success)
        cb({success = success})
    end, data.messageId)
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
    
    -- Variables pour le contrôle de la caméra
    local cameraHandle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local isSelfie = data.selfie or false
    local playerPed = PlayerPedId()
    
    -- Figer le joueur pendant la prise de photo
    FreezeEntityPosition(playerPed, true)
    
    -- Variables pour le contrôle de la caméra
    local camPosition = {x = 0, y = 0, z = 0}
    local camRotation = {x = 0, y = 0, z = 0}
    local initialRotation = {x = 0, y = 0, z = 0}  -- Pour stocker la rotation initiale
    local zoomLevel = 50.0
    local inCameraMode = true
    local photoTakenMode = false  -- Nouvel état pour suivi de la prise de photo
    local photoResult = nil       -- Pour stocker le résultat de la photo
    
    -- Configurer la caméra initiale
    local function SetupCamera()
        if isSelfie then
            -- Mode selfie - solution directe
            local coords = GetEntityCoords(playerPed)
            local forwardVector = GetEntityForwardVector(playerPed)  -- Vecteur indiquant où le joueur regarde
            
            -- Distances fixes pour le selfie
            local forwardDistance = 0.5  -- Distance devant le joueur
            local heightOffset = 0.6     -- Hauteur de la caméra par rapport au sol
            
            -- Positionner la caméra devant le joueur en utilisant son vecteur avant
            camPosition.x = coords.x + (forwardVector.x * forwardDistance)
            camPosition.y = coords.y + (forwardVector.y * forwardDistance)
            camPosition.z = coords.z + heightOffset
            
            -- Calculer l'angle pour que la caméra regarde vers le joueur (180° par rapport au joueur)
            local playerHeading = GetEntityHeading(playerPed)
            local selfieHeading = (playerHeading + 180.0) % 360.0  -- Opposé de la direction du joueur
            
            camRotation.x = 0.0           -- Pas d'inclinaison
            camRotation.y = 0.0           -- Pas de roulis
            camRotation.z = selfieHeading -- Regarder vers le joueur
        else
            -- Mode caméra normale
            local forwardVector = GetEntityForwardVector(playerPed)
            local coords = GetEntityCoords(playerPed)
            local playerHeading = GetEntityHeading(playerPed)
            
            camPosition.x = coords.x + forwardVector.x * 2.0
            camPosition.y = coords.y + forwardVector.y * 2.0
            camPosition.z = coords.z + 0.6
            
            camRotation.x = 0
            camRotation.y = 0
            camRotation.z = playerHeading
        end
        
        -- Stocker la rotation initiale
        initialRotation.x = camRotation.x
        initialRotation.y = camRotation.y
        initialRotation.z = camRotation.z
        
        SetCamCoord(cameraHandle, camPosition.x, camPosition.y, camPosition.z)
        SetCamRot(cameraHandle, camRotation.x, camRotation.y, camRotation.z, 2)
    end
    
    -- Initialiser la caméra
    SetupCamera()
    SetCamActive(cameraHandle, true)
    RenderScriptCams(true, false, 0, true, true)
    
    -- Animation de téléphone
    lib.requestAnimDict("cellphone@")
    TaskPlayAnim(playerPed, "cellphone@", "cellphone_photo_idle", 3.0, -1, -1, 49, 0, false, false, false)
    
    -- Afficher les instructions selon le mode
    local function UpdateInstructions()
        if photoTakenMode then
            lib.showTextUI('RETOUR: Quitter | ENTRÉE: Nouvelle photo', {
                position = "top-center",
                icon = 'camera',
                style = {
                    borderRadius = 0,
                    backgroundColor = '#141517',
                    color = 'white'
                }
            })
        else
            lib.showTextUI('↑↓: Rotation Haut/Bas | ←→: Pivoter | ENTRER: Prendre photo | RETOUR: Annuler', {
                position = "top-center",
                icon = 'camera',
                style = {
                    borderRadius = 0,
                    backgroundColor = '#141517',
                    color = 'white'
                }
            })
        end
    end
    
    UpdateInstructions()
    
    -- Désactiver temporairement les contrôles de mouvement du joueur
    local function DisableMovementControls()
        DisableControlAction(0, 30, true) -- Mouvement latéral (A et D)
        DisableControlAction(0, 31, true) -- Mouvement avant/arrière (W et S)
        DisableControlAction(0, 21, true) -- Sprint (Shift)
        DisableControlAction(0, 22, true) -- Saut (Espace)
        DisableControlAction(0, 23, true) -- Entrer dans un véhicule (F)
        DisableControlAction(0, 24, true) -- Attaque
        DisableControlAction(0, 25, true) -- Viser
        DisableControlAction(0, 44, true) -- Couvrir
        DisableControlAction(0, 37, true) -- Roue des armes
    end
    
    -- Fonction pour prendre la photo
    function TakePhoto()
        -- Jouer un son de prise de photo
        PlaySoundFrontend(-1, "Camera_Shoot", "Phone_Soundset_Franklin", 1)
        
        -- Flash de l'écran
        StartScreenEffect('camera_flash', 0, false)
        
        -- Attendre un moment pour voir le flash
        Wait(200)
        
        -- Passer en mode "photo prise"
        photoTakenMode = true
        UpdateInstructions()
        
        -- Prendre la capture d'écran
        exports['screenshot-basic']:requestScreenshotUpload(GetConvar("screenshot_webhook", ""), "files[]", {
            encoding = 'jpg',
            quality = 0.9
        }, function(data)
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
                
                -- Stocker le résultat pour une utilisation ultérieure
                photoResult = {
                    success = success,
                    imageUrl = imageUrl
                }
            else
                photoResult = {
                    success = false
                }
            end
        end)
    end
    
    -- Fonction pour quitter le mode photo
    function ExitPhotoMode()
        inCameraMode = false
        
        -- Nettoyage
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cameraHandle, false)
        StopAnimTask(playerPed, "cellphone@", "cellphone_photo_idle", 1.0)
        lib.hideTextUI()
        SetNuiFocus(true, true)
        
        -- Déverrouiller le joueur
        FreezeEntityPosition(playerPed, false)
        
        -- Réactiver tous les contrôles
        EnableAllControlActions(0)
        
        -- Retourner le résultat au callback
        if photoResult and photoResult.success and photoResult.imageUrl and photoResult.imageUrl ~= "" then
            -- Sauvegarder dans la galerie
            ESX.TriggerServerCallback('ox_phone:saveGalleryPhoto', function(success, photo)
                cb({success = success, photo = photo})
            end, photoResult.imageUrl)
        else
            cb({success = false, canceled = true})
        end
    end
    
    -- Créer une boucle pour les contrôles de caméra
    Citizen.CreateThread(function()
        while inCameraMode do
            Citizen.Wait(0)
            
            -- Désactiver les contrôles de mouvement
            DisableMovementControls()
            
            -- Si nous sommes en mode "photo prise", attendre uniquement ESC ou ENTER
            if photoTakenMode then
                -- Quitter 
                if IsControlJustPressed(0, 194) then -- Escape
                    ExitPhotoMode()
                    break
                -- Prendre une nouvelle photo
                elseif IsControlJustPressed(0, 191) then -- Entrée
                    photoTakenMode = false
                    UpdateInstructions()
                    TakePhoto()
                end
            else
                -- Contrôles standard de la caméra
                local rotationSpeed = 2.0
                
                -- Rotation Gauche/Droite
                if IsControlPressed(0, 174) then -- Flèche Gauche
                    local newRotZ = camRotation.z + rotationSpeed
                    local diff = math.abs((newRotZ % 360) - (initialRotation.z % 360))
                    diff = math.min(diff, 360 - diff)
                    if diff <= 90 then
                        camRotation.z = newRotZ
                    end
                elseif IsControlPressed(0, 175) then -- Flèche Droite
                    local newRotZ = camRotation.z - rotationSpeed
                    local diff = math.abs((newRotZ % 360) - (initialRotation.z % 360))
                    diff = math.min(diff, 360 - diff)
                    if diff <= 90 then
                        camRotation.z = newRotZ
                    end
                end

                -- Rotation Haut/Bas
                if IsControlPressed(0, 27) then -- Flèche Haut
                    local newRotX = camRotation.x + rotationSpeed
                    if math.abs(newRotX - initialRotation.x) <= 90 then
                        camRotation.x = newRotX
                    end
                elseif IsControlPressed(0, 173) then -- Flèche Bas
                    local newRotX = camRotation.x - rotationSpeed
                    if math.abs(newRotX - initialRotation.x) <= 90 then
                        camRotation.x = newRotX
                    end
                end
                
                -- Molette pour zoomer
                if IsControlJustPressed(0, 14) then -- Molette vers le bas
                    zoomLevel = math.min(zoomLevel + 5.0, 100.0)
                    SetCamFov(cameraHandle, 90.0 - (zoomLevel * 0.8))
                elseif IsControlJustPressed(0, 15) then -- Molette vers le haut
                    zoomLevel = math.max(zoomLevel - 5.0, 10.0)
                    SetCamFov(cameraHandle, 90.0 - (zoomLevel * 0.8))
                end
                
                -- Mettre à jour la position et la rotation de la caméra
                SetCamCoord(cameraHandle, camPosition.x, camPosition.y, camPosition.z)
                SetCamRot(cameraHandle, camRotation.x, camRotation.y, camRotation.z, 2)
                
                -- Prendre la photo
                if IsControlJustPressed(0, 191) then -- Entrée
                    TakePhoto()
                end
                
                -- Sortie
                if IsControlJustPressed(0, 194) then -- Escape
                    ExitPhotoMode()
                    break
                end
            end
        end
    end)
end)

RegisterNUICallback('getGallery', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getGallery', function(photos)
        cb(photos)
    end)
end)

RegisterNUICallback('deletePhoto', function(data, cb)
    -- Au lieu d'exécuter directement la suppression, demander confirmation via NUI
    SendNUIMessage({
        action = 'confirmDeletePhoto',
        photoId = data.photoId
    })
    
    -- Retourner un résultat "en attente"
    cb({pending = true})
end)

RegisterNUICallback('confirmDeletePhotoAction', function(data, cb)
    if data.confirmed then
        ESX.TriggerServerCallback('ox_phone:deletePhoto', function(success)
            cb({success = success})
        end, data.photoId)
    else
        cb({canceled = true})
    end
end)

-- YouTube Callbacks
RegisterNUICallback('searchYouTube', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:searchYouTube', function(result)
        cb(result)
    end, data.query)
end)

RegisterNUICallback('getVideoInfo', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getVideoInfo', function(result)
        cb(result)
    end, data.videoId)
end)

RegisterNUICallback('getYouTubeHistory', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getYouTubeHistory', function(history)
        cb(history)
    end)
end)

RegisterNUICallback('clearYouTubeHistory', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:clearYouTubeHistory', function(success)
        cb({success = success})
    end)
end)

-- Services d'urgence Callbacks
RegisterNUICallback('getEmergencyServices', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getEmergencyServices', function(services)
        cb(services)
    end)
end)

RegisterNUICallback('callEmergencyService', function(data, cb)
    TriggerServerEvent('ox_phone:startCall', data.number)
    
    -- Garder une référence à l'appel actif
    activeCall = {
        status = 'outgoing',
        number = data.number
    }
    
    cb('ok')
end)

-- Garage Callbacks
RegisterNUICallback('getVehicles', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getVehicles', function(vehicles)
        cb(vehicles)
    end)
end)

RegisterNUICallback('locateVehicle', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getVehiclePosition', function(position, stored, parking, pound)
        if pound then
            -- Le véhicule est à la fourrière
            local poundCoords = Config.PoundLocations[pound]
            
            if poundCoords then
                -- Créer un blip pour la fourrière
                local blip = AddBlipForCoord(poundCoords.x, poundCoords.y, poundCoords.z)
                SetBlipSprite(blip, 67)  -- Sprite de fourrière
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 1.0)
                SetBlipColour(blip, 1)  -- Rouge
                SetBlipAsShortRange(blip, false)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Fourrière: " .. pound)
                EndTextCommandSetBlipName(blip)
                
                -- Définir un itinéraire jusqu'à la fourrière
                SetNewWaypoint(poundCoords.x, poundCoords.y)
                
                -- Supprimer le blip après 60 secondes
                Citizen.CreateThread(function()
                    Wait(60000)
                    RemoveBlip(blip)
                end)
                
ShowPhoneNotification('Localisation', 'Votre véhicule est à la fourrière ' .. pound, 'info', 'fa-map-marker-alt')
                
                cb({success = true})
            else
ShowPhoneNotification('Localisation', 'Votre véhicule est à la fourrière ' .. pound .. ' (coordonnées inconnues)', 'error', 'fa-map-marker-alt')
                
                cb({success = false, message = "Fourrière introuvable dans la configuration"})
            end
        elseif stored == 1 and parking then
            -- Le véhicule est dans un garage
            local garageCoords = Config.GarageLocations[parking]
            
            if garageCoords then
                -- Créer un blip pour le garage
                local blip = AddBlipForCoord(garageCoords.x, garageCoords.y, garageCoords.z)
                SetBlipSprite(blip, 357)  -- Sprite de garage
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 1.0)
                SetBlipColour(blip, 3)  -- Bleu
                SetBlipAsShortRange(blip, false)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Garage: " .. parking)
                EndTextCommandSetBlipName(blip)
                
                -- Définir un itinéraire jusqu'au garage
                SetNewWaypoint(garageCoords.x, garageCoords.y)
                
                -- Supprimer le blip après 60 secondes
                Citizen.CreateThread(function()
                    Wait(60000)
                    RemoveBlip(blip)
                end)
                
                ShowPhoneNotification('Localisation', 'Votre véhicule est dans le garage ' .. parking, 'info', 'fa-car')
                
                cb({success = true})
            else
ShowPhoneNotification('Localisation', 'Votre véhicule est dans le garage ' .. parking .. ' (coordonnées inconnues)', 'warning', 'fa-car')
                
                cb({success = false, message = "Garage introuvable dans la configuration"})
            end
        elseif position then
            -- Le véhicule est garé à l'extérieur
            local coords = json.decode(position)
            
            -- Créer un blip pour le véhicule
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 225)  -- Sprite de voiture
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 1.0)
            SetBlipColour(blip, 2)  -- Vert
            SetBlipAsShortRange(blip, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Votre véhicule")
            EndTextCommandSetBlipName(blip)
            
            -- Définir un itinéraire jusqu'au véhicule
            SetNewWaypoint(coords.x, coords.y)
            
            -- Supprimer le blip après 60 secondes
            Citizen.CreateThread(function()
                Wait(60000)
                RemoveBlip(blip)
            end)
            
ShowPhoneNotification('Localisation', 'Votre véhicule a été localisé', 'success', 'fa-search-location')
            
            cb({success = true})
        else
ShowPhoneNotification('Localisation', 'Position du véhicule inconnue', 'error', 'fa-question-circle')
            
            cb({success = false, message = "Position du véhicule inconnue"})
        end
    end, data.plate)
end)

-- Alarmes Callbacks
RegisterNUICallback('getAlarms', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:getAlarms', function(alarms)
        cb(alarms)
    end)
end)

RegisterNUICallback('addAlarm', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:addAlarm', function(success, alarm)
        if success then
            -- Enregistrer l'alarme dans le gestionnaire local
            RegisterAlarm(alarm)
        end
        cb({success = success, alarm = alarm})
    end, data)
end)

RegisterNUICallback('updateAlarm', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:updateAlarm', function(success)
        if success then
            -- Mettre à jour l'alarme dans le gestionnaire local
            UpdateLocalAlarm(data)
        end
        cb({success = success})
    end, data)
end)

RegisterNUICallback('deleteAlarm', function(data, cb)
    -- Ici, ne rien faire car la confirmation est déjà gérée côté JavaScript
    cb({status = 'ok'})
end)

RegisterNUICallback('confirmDeleteAlarmAction', function(data, cb)
    if data.confirmed then
        ESX.TriggerServerCallback('ox_phone:deleteAlarm', function(success)
            if success then
                -- Supprimer l'alarme du gestionnaire local
                UnregisterAlarm(data.alarmId)
                cb({success = success})
            else
                cb({success = false})
            end
        end, data.alarmId)
    else
        cb({canceled = true})
    end
end)

RegisterNUICallback('dismissAlarm', function(data, cb)
    -- Arrêter la sonnerie et notification
    StopAlarmSound()
    cb({success = true})
end)

RegisterNUICallback('snoozeAlarm', function(data, cb)
    -- Programmer une répétition dans 5 minutes
    local alarmId = data.alarmId
    SnoozeAlarm(alarmId, 5) -- 5 minutes
    cb({success = true})
end)

RegisterNUICallback('playAlarmSound', function(data, cb)
    PlayAlarmSound(data.sound)
    cb({success = true})
end)

RegisterNUICallback('stopAlarmSound', function(data, cb)
    StopAlarmSound()
    cb({success = true})
end)

-- Application Agent Callbacks
RegisterNUICallback('getAgentAppData', function(data, cb)
    -- Vérifier si le joueur peut utiliser l'application
    ESX.TriggerServerCallback('ox_phone:canUseAgentApp', function(canUse, agentData)
        if canUse then
            cb({success = true, data = agentData})
        else
            cb({success = false, message = "Vous n'êtes pas autorisé à utiliser cette application"})
        end
    end)
end)

RegisterNUICallback('takeServicePhone', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:takeServicePhone', function(success, message)
        cb({success = success, message = message})
    end)
end)

RegisterNUICallback('returnServicePhone', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:returnServicePhone', function(success, message)
        cb({success = success, message = message})
    end)
end)

RegisterNUICallback('sendAgentNotification', function(data, cb)
    ESX.TriggerServerCallback('ox_phone:sendAgentNotification', function(success, message)
        cb({success = success, message = message})
    end, data.type, data.customMessage)
end)

--------------------------------------------------
-- ÉVÉNEMENTS
--------------------------------------------------

-- Événements d'appel
RegisterNetEvent('ox_phone:outgoingCallStarted')
AddEventHandler('ox_phone:outgoingCallStarted', function(callId, receiverNumber)
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
    -- Rejoindre le canal d'appel spécifié
    pcall(function()
        exports["pma-voice"]:setCallChannel(tonumber(channelId))
    end)
end)

RegisterNetEvent('ox_phone:otherPlayerLeftCall')
AddEventHandler('ox_phone:otherPlayerLeftCall', function()
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

-- Événement pour recevoir un message
RegisterNetEvent('ox_phone:receiveMessage')
AddEventHandler('ox_phone:receiveMessage', function(sender, message, time, id)
    -- Récupérer les paramètres de l'utilisateur pour la sonnerie
    ESX.TriggerServerCallback('ox_phone:getSettings', function(settings)
        local notificationSound = settings and settings.notification_sound or 'notification1'
        local doNotDisturb = settings and settings.do_not_disturb or false
        local airplaneMode = settings and settings.airplane_mode or false
        
        -- Ne jouer le son que si les modes silencieux/avion sont désactivés
        if not doNotDisturb and not airplaneMode then
            SendNUIMessage({
                action = 'playNotificationSound',
                sound = notificationSound
            })
        end
        
        -- Notification visuelle unique
ShowPhoneNotification('Nouveau message', 'De: ' .. sender .. '\n' .. message:sub(1, 30) .. (message:len() > 30 and "..." or ""), 'info', 'fa-envelope')
        
        -- Si le téléphone est ouvert, mettre à jour l'interface
        if phoneOpen then
            SendNUIMessage({
                action = 'newMessage',
                sender = sender,
                message = message,
                time = time,
                id = id or math.random(100000, 999999)
            })
        else
            -- Notification visuelle de SMS qui apparait sur l'écran
            SendNUIMessage({
                action = 'showSmsNotification',
                sender = sender,
                message = message
            })
        end
    end)
end)

-- Événement pour recevoir un appel entrant
RegisterNetEvent('ox_phone:incomingCall')
AddEventHandler('ox_phone:incomingCall', function(callId, caller, callerName)
    -- Vérifier si un appel est déjà en cours
    if activeCall and activeCall.id == callId then
        return -- Empêcher les notifications en double
    end
    
    -- Mettre à jour l'appel actif
    activeCall = {
        id = callId,
        number = caller,
        caller = caller,
        callerName = callerName,
        status = 'incoming'
    }
    
    -- Sonnerie unique avec gestion du statut
    Citizen.CreateThread(function()
        local ringingTime = 0
        local maxRingingTime = 30 -- secondes
        
        -- Jouer la sonnerie immédiatement
        PlaySoundFrontend(-1, "Ringtone_Default", "Phone_SoundSet_Default", 1)
        
        while activeCall and activeCall.status == 'incoming' and ringingTime < maxRingingTime do
            -- Rejouer le son toutes les 3 secondes
            Citizen.Wait(3000)
            ringingTime = ringingTime + 3
            
            if activeCall and activeCall.status == 'incoming' then
                PlaySoundFrontend(-1, "Ringtone_Default", "Phone_SoundSet_Default", 1)
                
                -- Notification régulière
ShowPhoneNotification('Appel entrant', callerName or caller, 'info', 'fa-phone-volume', 3000)
            else
                break -- Sortir si l'appel n'est plus en cours
            end
        end
        
        -- Si l'appel n'a pas été répondu après le temps maximum
        if activeCall and activeCall.status == 'incoming' then
            -- Manquer l'appel automatiquement
            TriggerServerEvent('ox_phone:rejectCall', callId)
            activeCall = nil
ShowPhoneNotification('Appel manqué', 'De ' .. (callerName or caller), 'error', 'fa-phone-missed', 3000)
        end
    end)
    
    -- Ouvrir le téléphone et aller directement à l'écran d'appel
    if not phoneOpen then
        if CheckForPhone() then
            OpenPhone()
            
            -- Petit délai pour s'assurer que le téléphone est ouvert
            Citizen.SetTimeout(500, function()
                -- Envoyer un message à l'interface NUI pour afficher l'écran d'appel
                SendNUIMessage({
                    action = 'directShowScreen',
                    screen = 'calling-screen',
                    callData = {
                        callId = callId,
                        caller = caller,
                        callerName = callerName
                    }
                })
            end)
        end
    else
        -- Si le téléphone est déjà ouvert, envoyer l'événement pour afficher l'écran d'appel
        SendNUIMessage({
            action = 'directShowScreen',
            screen = 'calling-screen',
            callData = {
                callId = callId,
                caller = caller,
                callerName = callerName
            }
        })
    end
end)

RegisterNetEvent('ox_phone:callAnswered')
AddEventHandler('ox_phone:callAnswered', function(callId)
    if activeCall and activeCall.id == callId then
        activeCall.status = 'active'
        
        -- Récupérer l'ID du joueur à l'autre bout de l'appel
        ESX.TriggerServerCallback('ox_phone:getCallTargetId', function(targetId)
            if targetId then
                -- Configurer la voix pour l'appel
                SetupCallVoice(targetId)
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

-- Événements de réseaux sociaux
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
    
ShowPhoneNotification('Nouveau tweet', tweet.author .. ': ' .. tweet.message:sub(1, 30) .. '...', 'info', 'fa-twitter')
    
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
    
    ShowPhoneNotification('Nouvelle annonce', ad.title, 'info', 'fa-bullhorn')
    
    if phoneOpen and currentApp == 'ads' then
        SendNUIMessage({
            action = 'newAd',
            ad = ad
        })
    end
end)

-- Événements pour l'application Agent
RegisterNetEvent('ox_phone:showAgentNotification')
AddEventHandler('ox_phone:showAgentNotification', function(data)
    -- Envoyer l'événement NUI pour afficher la notification
    SendNUIMessage({
        action = 'showAgentPublicNotification',
        jobLabel = data.jobLabel,
        message = data.message,
        image = data.image
    })
end)

RegisterNetEvent('ox_phone:servicePhoneUpdate')
AddEventHandler('ox_phone:servicePhoneUpdate', function(data)
    -- Si le téléphone est ouvert, mettre à jour l'interface
    if phoneOpen then
        SendNUIMessage({
            action = 'updateAgentAppData',
            job = data.job,
            action = data.action,
            playerName = data.playerName
        })
    end
    
    -- Envoyer une notification
    local actionMessage = ""
    if data.action == "taken" then
        actionMessage = data.playerName .. " a pris le téléphone de service"
    elseif data.action == "returned" then
        actionMessage = data.playerName .. " a rendu le téléphone de service"
    elseif data.action == "disconnected" then
        actionMessage = data.playerName .. " s'est déconnecté, le téléphone de service est disponible"
    end
    
ShowPhoneNotification('Agent', actionMessage, 'info', 'fa-user-tie')
end)

-- Événement pour recevoir des notifications du serveur
RegisterNetEvent('ox_phone:showNotification')
AddEventHandler('ox_phone:showNotification', function(data)
    ShowPhoneNotification(data.title, data.message, data.type, data.icon, data.duration, data.isImage)
end)

--------------------------------------------------
-- INITIALISATION
--------------------------------------------------

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