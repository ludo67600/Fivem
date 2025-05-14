-- J_PoliceNat client/k9.lua
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales
-- =============================================
local policeDog = nil
local followingTarget = nil
local searching = false
local attacking = false

-- Commandes d'animation du chien
local dogAnimations = {
    sit = {
        dict = "creatures@rottweiler@amb@world_dog_sitting@base",
        anim = "base"
    },
    laydown = {
        dict = "creatures@rottweiler@amb@sleep_in_kennel@",
        anim = "sleep_in_kennel"
    },
    bark = {
        dict = "creatures@rottweiler@amb@world_dog_barking@idle_a",
        anim = "idle_a"
    }
}

-- =============================================
-- Menu K9 principal
-- =============================================
function OpenK9Menu()
    if not IsOnDuty() then return end
    if not HasMinimumGrade(Config.K9.minGrade) then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Grade insuffisant pour utiliser l\'unité K9',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    local elements = {
        {
            title = policeDog and 'Renvoyer le chien' or 'Appeler le chien',
            description = policeDog and 'Faire partir le chien' or 'Appeler votre chien de service',
            icon = 'dog',
            onSelect = function()
                if policeDog then
                    DespawnPoliceDog()
                else
                    SpawnPoliceDog()
                end
            end
        }
    }

    if policeDog then
        table.insert(elements, {
            title = 'Assis',
            description = 'Ordonner au chien de s\'asseoir',
            icon = 'hand',
            onSelect = function()
                CommandSit()
            end
        })

        table.insert(elements, {
            title = 'Suis-moi',
            description = 'Ordonner au chien de suivre',
            icon = 'person-walking',
            onSelect = function()
                CommandFollow()
            end
        })

        table.insert(elements, {
            title = 'Attaque',
            description = 'Ordonner au chien d\'attaquer',
            icon = 'skull',
            onSelect = function()
                CommandAttack()
            end
        })

        table.insert(elements, {
            title = 'Cherche',
            description = 'Ordonner au chien de chercher',
            icon = 'magnifying-glass',
            onSelect = function()
                CommandSearch()
            end
        })
    end

    lib.registerContext({
        id = 'police_k9_menu',
        title = 'Menu K9',
        options = elements
    })

    lib.showContext('police_k9_menu')
end

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Charger une animation
function LoadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

-- =============================================
-- Gestion du chien (spawn, despawn)
-- =============================================

-- Spawn du chien
function SpawnPoliceDog()
    if policeDog then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Vous avez déjà un chien',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Chargement du modèle
    local model = GetHashKey(Config.K9.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(50)
    end

    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.0, -1.0)

    policeDog = CreatePed(28, model, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, true)

    -- Configuration du chien
    SetPedComponentVariation(policeDog, 0, 0, 0, 0)
    SetBlockingOfNonTemporaryEvents(policeDog, true)
    SetPedFleeAttributes(policeDog, 0, false)
    SetPedCombatAttributes(policeDog, 3, true)
    SetPedCombatAbility(policeDog, 100)
    SetPedCombatMovement(policeDog, 3)
    SetPedCombatRange(policeDog, 2)
    SetEntityHealth(policeDog, 200)
    
    -- Suivre le joueur par défaut
    TaskFollowToOffsetOfEntity(policeDog, playerPed, 0.5, 0.0, 0.0, 5.0, -1, 0.0, true)

    exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Chien de police déployé',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

end

-- Despawn du chien
function DespawnPoliceDog()
    if not policeDog then return end

    DeleteEntity(policeDog)
    policeDog = nil

exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Chien de police renvoyé',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

end

-- =============================================
-- Commandes du chien
-- =============================================

-- Commande Assis
function CommandSit()
    if not policeDog then return end
    
    ClearPedTasks(policeDog)
    LoadAnimDict(dogAnimations.sit.dict)
    TaskPlayAnim(policeDog, dogAnimations.sit.dict, dogAnimations.sit.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

-- Commande Suis-moi
function CommandFollow()
    if not policeDog then return end
    
    -- Réinitialiser les états
    ClearPedTasks(policeDog)
    followingTarget = nil
    attacking = false
    searching = false
    
    -- Faire suivre le joueur
    local playerPed = PlayerPedId()
    TaskFollowToOffsetOfEntity(policeDog, playerPed, 0.5, 0.0, 0.0, 5.0, -1, 0.5, true)
    
    -- Notification
exports['jl_notifications']:ShowNotification({
    type = 'info',
    message = 'Le chien vous suit maintenant',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

end

-- Commande Attaque
function CommandAttack()
    if not policeDog or attacking then return end

    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 5.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucune cible à proximité',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    local targetPed = GetPlayerPed(closestPlayer)
    attacking = true

    -- Animation d'aboiement avant l'attaque
    LoadAnimDict(dogAnimations.bark.dict)
    TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    Wait(1500)

    -- Lancement de l'attaque
    TaskCombatPed(policeDog, targetPed, 0, 16)

    -- Reset après 10 secondes
    SetTimeout(10000, function()
        attacking = false
        CommandFollow()
    end)
end

-- Commande Cherche
function CommandSearch()
    if not policeDog or searching then return end
    searching = true
    local startCoords = GetEntityCoords(policeDog)

    -- Animation de recherche
    LoadAnimDict("creatures@rottweiler@amb@world_dog_sitting@idle_a")
    TaskPlayAnim(policeDog, "creatures@rottweiler@amb@world_dog_sitting@idle_a", "idle_b", 8.0, -8.0, -1, 0, 0.0, false, false, false)

    -- Progress bar pour la recherche
    if lib.progressBar({
        duration = 10000,
        label = 'Le chien cherche...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
    }) then
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed, true)
        local detectionFound = false
        
        -- Vérifier s'il y a un joueur à proximité
        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
        if closestPlayer ~= -1 and closestDistance <= 3.0 then
            print("Recherche K9: Joueur trouvé, vérification")
            local targetId = GetPlayerServerId(closestPlayer)
            TriggerServerEvent('police:k9CheckInventory', targetId)
            
            -- Animation du chien qui renifle le joueur
            local targetPed = GetPlayerPed(closestPlayer)
            TaskGoToEntity(policeDog, targetPed, -1, 0.5, 2.0, 0, 0)
            Wait(2000)
            detectionFound = true
        end
        
        -- Vérifier s'il y a un véhicule à proximité (indépendamment)
        local closestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)
        if DoesEntityExist(closestVehicle) then
            print("Recherche K9: Véhicule trouvé")
            
            -- Si un véhicule est trouvé, vérifier son coffre
            local plate = GetVehicleNumberPlateText(closestVehicle)
            if plate then
                -- Nettoyons la plaque (supprimez les espaces)
                plate = plate:gsub("%s+", "")
                print("Recherche K9: Vérifie la plaque " .. plate)
                
                -- Important: Utiliser le netID du véhicule pour ox_inventory
                local vehNetId = NetworkGetNetworkIdFromEntity(closestVehicle)
                TriggerServerEvent('police:k9CheckVehicle', plate, vehNetId)
                
                -- Faire le chien renifler autour du véhicule
                TaskGoToEntity(policeDog, closestVehicle, -1, 0.5, 2.0, 0, 0)
                Wait(2000)
                detectionFound = true
            end
        end
        
        -- Si aucune détection n'a été faite
        if not detectionFound then
exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucune cible à proximité pour la recherche',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        end
    end

    searching = false
    CommandFollow()
end

-- =============================================
-- Events de détection et notifications
-- =============================================

-- Event pour la détection d'items pour les joueurs
RegisterNetEvent('police:k9ItemDetectedPlayer')
AddEventHandler('police:k9ItemDetectedPlayer', function(detected)
    if not policeDog then return end
    if detected then
        -- Animation d'aboiement pour signaler la détection
        LoadAnimDict(dogAnimations.bark.dict)
        TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
        
        exports['jl_notifications']:ShowNotification({
    type = 'warning',
    message = 'Le chien a détecté quelque chose de suspect sur le citoyen !',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

    else
        exports['jl_notifications']:ShowNotification({
    type = 'info',
    message = 'Le chien n\'a rien trouvé de suspect sur le citoyen',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end)

-- Event pour la détection d'items pour les véhicules
RegisterNetEvent('police:k9ItemDetectedVehicle')
AddEventHandler('police:k9ItemDetectedVehicle', function(detected)
    if not policeDog then return end
    if detected then
        -- Animation d'aboiement pour signaler la détection
        LoadAnimDict(dogAnimations.bark.dict)
        TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
        
        exports['jl_notifications']:ShowNotification({
    type = 'warning',
    message = 'Le chien a détecté quelque chose de suspect dans le véhicule !',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

    else
        exports['jl_notifications']:ShowNotification({
    type = 'info',
    message = 'Le chien n\'a rien trouvé de suspect dans le véhicule',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end)

-- =============================================
-- Nettoyage
-- =============================================

-- Suppression du chien à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and policeDog then
        DeleteEntity(policeDog)
    end
end)

-- Export pour vérifier si le chien existe
exports('DoesK9Exist', function()
    return policeDog ~= nil and DoesEntityExist(policeDog)
end)

-- Export des fonctions K9
exports('SpawnPoliceDog', SpawnPoliceDog)
exports('DespawnPoliceDog', DespawnPoliceDog)
exports('CommandSit', CommandSit)
exports('CommandFollow', CommandFollow)
exports('CommandAttack', CommandAttack)
exports('CommandSearch', CommandSearch)