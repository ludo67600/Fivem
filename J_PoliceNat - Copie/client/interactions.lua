-- J_PoliceNat client/interactions.lua
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales
-- =============================================
local draggedPlayer = nil
local isHandcuffed = false
local isDragged = false

-- =============================================
-- Menu Interactions Citoyens
-- =============================================
function OpenCitizenInteractionMenu()
    local elements = {
        {
            title = 'Menotter/Démenotter',
            description = 'Menotter ou démenotter un citoyen',
            icon = 'handcuffs',
            onSelect = function()
                HandcuffAction()
            end
        },
        {
            title = 'Escorter',
            description = 'Escorter un citoyen',
            icon = 'people-arrows',
            onSelect = function()
                EscortAction()
            end
        },
        {
            title = 'Mettre dans le véhicule',
            description = 'Mettre un citoyen dans un véhicule',
            icon = 'car',
            onSelect = function()
                PutInVehicleAction()
            end
        },
        {
            title = 'Sortir du véhicule',
            description = 'Sortir un citoyen d\'un véhicule',
            icon = 'car-side',
            onSelect = function()
                OutOfVehicleAction()
            end
        },
        {
            title = 'Fouiller',
            description = 'Fouiller un citoyen',
            icon = 'search',
            onSelect = function()
                SearchAction()
            end
        },
        {
            title = 'Amendes',
            description = 'Donner une amende',
            icon = 'money-bill',
            onSelect = function()
                OpenFineMenu()
            end
        },
        {
            title = 'Gestion des permis',
            description = 'Gérer les permis du citoyen',
            icon = 'id-card',
            onSelect = function()
                OpenLicenseManagementMenu()
            end
        }
    }

    lib.registerContext({
        id = 'police_citizen_menu',
        title = 'Interactions Citoyens',
        options = elements
    })

    lib.showContext('police_citizen_menu')
end

-- =============================================
-- Actions de restriction (Menottes, escorte, etc.)
-- =============================================

-- Action Menotter
function HandcuffAction()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    lib.progressBar({
        duration = Config.Animations.handcuff,
        label = 'Application des menottes...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_arrest_paired',
            clip = 'cop_p2_back_right',
            flags = 51
        },
    })

    TriggerServerEvent('police:handcuffPlayer', GetPlayerServerId(closestPlayer))
end

-- Event pour être menotté
RegisterNetEvent('police:getHandcuffed')
AddEventHandler('police:getHandcuffed', function()
    isHandcuffed = not isHandcuffed
    local playerPed = PlayerPedId()

    if isHandcuffed then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do
            Wait(100)
        end

        TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
        SetEnableHandcuffs(playerPed, true)
        DisablePlayerFiring(playerPed, true)
        SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
        SetPedCanPlayGestureAnims(playerPed, false)

        -- Désactivation des contrôles
        CreateThread(function()
            while isHandcuffed do
                DisableControlAction(0, 1, true) -- Look Left/Right
                DisableControlAction(0, 2, true) -- Look Up/Down
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 257, true) -- Attack 2
                DisableControlAction(0, 25, true) -- Aim
                DisableControlAction(0, 263, true) -- Melee Attack 1
                DisableControlAction(0, 45, true) -- Reload
                DisableControlAction(0, 44, true) -- Cover
                DisableControlAction(0, 37, true) -- Select Weapon
                DisableControlAction(0, 21, true) -- Sprint
                DisableControlAction(0, 22, true) -- Jump
                DisableControlAction(0, 288, true) -- F1
                DisableControlAction(0, 289, true) -- F2
                DisableControlAction(0, 170, true) -- F3
                DisableControlAction(0, 167, true) -- F6
                DisableControlAction(0, 318, true) -- F9
                Wait(0)
            end
        end)
    else
        ClearPedSecondaryTask(playerPed)
        SetEnableHandcuffs(playerPed, false)
        DisablePlayerFiring(playerPed, false)
        SetPedCanPlayGestureAnims(playerPed, true)
    end
end)

-- Action Escorter
function EscortAction()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    TriggerServerEvent('police:escortPlayer', GetPlayerServerId(closestPlayer))
end

-- Event pour être escorté
RegisterNetEvent('police:getEscorted')
AddEventHandler('police:getEscorted', function(copId)
    local playerPed = PlayerPedId()
    isDragged = not isDragged
    draggedPlayer = copId

    if isDragged then
        AttachEntityToEntity(playerPed, GetPlayerPed(GetPlayerFromServerId(draggedPlayer)), 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    else
        DetachEntity(playerPed, true, false)
    end
end)

-- Action Mettre dans le véhicule
function PutInVehicleAction()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Utiliser une autre méthode plus fiable pour détecter les véhicules
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    
    if not DoesEntityExist(vehicle) then
exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    TriggerServerEvent('police:putInVehicle', GetPlayerServerId(closestPlayer))
end

-- Event pour être mis dans un véhicule
RegisterNetEvent('police:putInVehicle')
AddEventHandler('police:putInVehicle', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Si le joueur est escorté, on le détache d'abord
    if isDragged then
        isDragged = false
        DetachEntity(playerPed, true, false)
    end
    
    if not IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
        
        if DoesEntityExist(vehicle) then
            local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
            
            -- Recherche d'un siège libre
            for i=0, maxSeats-1 do
                if IsVehicleSeatFree(vehicle, i) then
                    TaskWarpPedIntoVehicle(playerPed, vehicle, i)
                    exports['jl_notifications']:ShowNotification({
    type = 'info',
    message = 'Vous avez été placé dans le véhicule',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

                    break
                end
            end
        else
            exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun véhicule à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        end
    end
end)

-- Action Sortir du véhicule
function OutOfVehicleAction()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    TriggerServerEvent('police:outOfVehicle', GetPlayerServerId(closestPlayer))
end

-- Event pour sortir du véhicule
RegisterNetEvent('police:outOfVehicle')
AddEventHandler('police:outOfVehicle', function()
    local playerPed = PlayerPedId()
    
    if IsPedSittingInAnyVehicle(playerPed) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 16)
        
        -- Si le joueur est menotté, réappliquer les menottes après être sorti du véhicule
        if isHandcuffed then
            Wait(1000) -- Attendre que l'animation de sortie du véhicule soit terminée
            RequestAnimDict('mp_arresting')
            while not HasAnimDictLoaded('mp_arresting') do
                Wait(100)
            end
            
            TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
            SetEnableHandcuffs(playerPed, true)
        end
    end
end)

-- =============================================
-- Actions d'interaction (Fouille, amendes, etc.)
-- =============================================

-- Action Fouille
function SearchAction()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    if lib.progressBar({
        duration = Config.Animations.search,
        label = 'Fouille en cours...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@gangops@facility@servers@bodysearch@',
            clip = 'player_search',
            flags = 49
        },
    }) then
        -- Utiliser ox_inventory pour ouvrir l'inventaire
        exports.ox_inventory:openInventory('player', GetPlayerServerId(closestPlayer))
    end
end

-- =============================================
-- Système d'amendes
-- =============================================

-- Menu Amendes avec intégration à esx_billing
function OpenFineMenu()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
       exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    local elements = {}
    
    for _, category in ipairs(Config.Fines.categories) do
        table.insert(elements, {
            title = category.label,
            description = ('Amendes de %s€ à %s€'):format(category.minAmount, category.maxAmount),
            icon = 'money-bill',
            onSelect = function()
                OpenFineInputMenu(category, closestPlayer)
            end
        })
    end

    lib.registerContext({
        id = 'police_fines_menu',
        title = 'Catégories d\'amendes',
        options = elements
    })

    lib.showContext('police_fines_menu')
end

-- Menu Saisie Amende
function OpenFineInputMenu(category, closestPlayer)
    local input = lib.inputDialog('Amende', {
        {
            type = 'number',
            label = 'Montant',
            description = 'Entre ' .. category.minAmount .. '€ et ' .. category.maxAmount .. '€',
            default = category.minAmount,
            min = category.minAmount,
            max = category.maxAmount,
            required = true
        },
        {
            type = 'input',
            label = 'Raison',
            description = 'Motif de l\'amende',
            required = true
        }
    })

    if input then
        local amount = input[1]
        local reason = input[2]

        -- Animation de rédaction de l'amende
        local playerPed = PlayerPedId()
        TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_CLIPBOARD", 0, true)
        
        if lib.progressBar({
            duration = 3000,
            label = 'Rédaction de l\'amende...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
        }) then
            TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_police', reason, amount)
            exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Amende donnée',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

            ClearPedTasks(playerPed)
        else
            ClearPedTasks(playerPed)
        end
    end
end

-- =============================================
-- Gestion des permis et licences
-- =============================================

-- Menu des licences et permis
function OpenLicenseManagementMenu()
    local elements = {
        {
            title = 'Vérifier les permis',
            description = 'Consulter les permis d\'un citoyen',
            icon = 'id-card',
            onSelect = function()
                CheckCitizenLicenses()
            end
        },
        {
            title = 'Délivrer un permis de port d\'arme',
            description = 'Approuver une demande de PPA',
            icon = 'gun',
            onSelect = function()
                IssueWeaponLicense()
            end
        },
        {
            title = 'Révoquer un permis',
            description = 'Révoquer un permis existant',
            icon = 'ban',
            onSelect = function()
                RevokeLicense()
            end
        }
    }

    lib.registerContext({
        id = 'police_license_menu',
        title = 'Gestion des Permis',
        options = elements
    })

    lib.showContext('police_license_menu')
end

-- Fonction pour délivrer un permis de port d'arme (version corrigée)
function IssueWeaponLicense()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
       exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end
    
    -- Envoyer une demande de vérification au serveur
    TriggerServerEvent('police:requestWeaponLicense', GetPlayerServerId(closestPlayer))
end

-- Gestionnaire pour l'événement de confirmation du PPA
RegisterNetEvent('police:confirmWeaponLicense')
AddEventHandler('police:confirmWeaponLicense', function(targetId)
    -- Demander confirmation avec prix hardcodé
    local alert = lib.alertDialog({
        header = 'Permis de port d\'arme',
        content = 'Voulez-vous délivrer un permis de port d\'arme à cette personne? Le coût de 1500€ sera prélevé directement.',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('police:confirmWeaponLicense', targetId)
    end
end)

-- Fonction pour révoquer un permis
function RevokeLicense()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end
    
    local input = lib.inputDialog('Révoquer un permis', {
        {
            type = 'select',
            label = 'Type de permis',
            options = {
                {value = 'Driver', label = 'Permis de conduire'},
                {value = 'Weapon', label = 'Permis de port d\'arme'}
            },
            required = true
        },
        {
            type = 'input',
            label = 'Motif de révocation',
            description = 'Raison de la révocation',
            required = true
        }
    })
    
    if input then
        TriggerServerEvent('police:revokeDocument', GetPlayerServerId(closestPlayer), input[1], input[2])
    end
end

-- Vérifier les permis d'un citoyen
function CheckCitizenLicenses()
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun joueur à proximité',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Animation de vérification des documents
    local playerPed = PlayerPedId()
    TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_CLIPBOARD", 0, true)
    
    if lib.progressBar({
        duration = 2000,
        label = 'Vérification des documents...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
    }) then
        TriggerServerEvent('police:checkDetailedLicenses', GetPlayerServerId(closestPlayer))
        Wait(500)
        ClearPedTasks(playerPed)
    else
        ClearPedTasks(playerPed)
       exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Vérification annulée',
    title = 'Police',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end

-- =============================================
-- Événements et fonctions utilitaires
-- =============================================

-- Event pour afficher les licences
RegisterNetEvent('police:showDetailedLicenses')
AddEventHandler('police:showDetailedLicenses', function(documents)
    local elements = {}
    
    if #documents == 0 then
        table.insert(elements, {
            title = 'Aucun document',
            description = 'Cette personne ne possède aucun document',
            icon = 'times',
            disabled = true
        })
    else
        for _, doc in ipairs(documents) do
            local isExpired = doc.isExpired
            local statusText = isExpired and 'Expiré' or 'Valide'
            local statusIcon = isExpired and 'times' or 'check'
            
            table.insert(elements, {
                title = GetDocumentTypeName(doc.type),
                description = 'État: ' .. statusText,
                icon = statusIcon,
                metadata = {
                    {label = 'Numéro', value = doc.number},
                    {label = 'Prénom', value = doc.firstName},
                    {label = 'Nom', value = doc.lastName},
                    {label = 'Date d\'émission', value = doc.issueDate},
                    {label = 'Date d\'expiration', value = doc.expirationDate},
                    {label = 'Délivré par', value = doc.issuer}
                }
            })
        end
    end

    lib.registerContext({
        id = 'police_licenses_menu',
        title = 'Documents du citoyen',
        options = elements
    })

    lib.showContext('police_licenses_menu')
end)

-- Fonction utilitaire pour obtenir le nom du type de document
function GetDocumentTypeName(type)
    local documentTypes = {
        ID = 'Carte d\'identité',
        Driver = 'Permis de conduire',
        Weapon = 'Permis de port d\'arme'
    }
    
    return documentTypes[type] or type
end