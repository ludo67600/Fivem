-- J_PoliceNat client/main.lua
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales et initialisation
-- =============================================
local PlayerData = {}
local isOnDuty = false
local currentAlert = nil
local activeBlips = {}

-- Initialisation
CreateThread(function()
    Wait(1000)
    while ESX.GetPlayerData().job == nil do
        Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
    InitializeTargetPoints()
	CreateLocationPeds()
end)

-- Mise à jour des données joueur
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    Wait(500)
    if PlayerData.job.name == 'police' then
        TriggerServerEvent('police:getDutyStatus')
    end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    if job.name ~= 'police' then
        isOnDuty = false
    end
end)

-- =============================================
-- Création des PNJ aux points d'interaction
-- =============================================
function CreateLocationPeds()
    -- Créer un PNJ pour chaque emplacement configuré
    for location, data in pairs(Config.Locations) do
        if data.ped then
            local model = GetHashKey(data.ped.model)
            
            -- Charger le modèle
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(10)
            end
            
            -- Créer le PNJ
            local ped = CreatePed(4, model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.ped.heading, false, true)
            
            -- Configurer le PNJ
            SetEntityHeading(ped, data.ped.heading)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            
            -- Exécuter le scénario si défini
            if data.ped.scenario then
                TaskStartScenarioInPlace(ped, data.ped.scenario, 0, true)
            end
            
            -- Libérer le modèle
            SetModelAsNoLongerNeeded(model)
        end
    end
end
-- =============================================
-- Création du blip du commissariat
-- =============================================
CreateThread(function()
    -- Configuration du blip
    local blipConfig = {
        sprite = 60,    -- Sprite/icône du blip (60 = étoile de police)
        color = 38,     -- Couleur du blip (38 = bleu)
        scale = 1.0,    -- Taille du blip
        label = "Police Nationale" -- Nom affiché
    }
    
    -- Attendre que la carte soit chargée
    Wait(2000)
    
    -- Créer le blip à l'emplacement de l'accueil
    local coords = Config.Locations.main.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Configurer l'apparence du blip
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.color)
    SetBlipAsShortRange(blip, true)
    
    -- Ajouter un nom au blip
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipConfig.label)
    EndTextCommandSetBlipName(blip)
end)

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Vérification du service et du grade
function IsOnDuty()
    return isOnDuty and PlayerData.job and PlayerData.job.name == Config.Job.name
end

function HasMinimumGrade(minGrade)
    return PlayerData.job and PlayerData.job.grade >= minGrade
end

-- =============================================
-- Gestion du service (on/off duty)
-- =============================================

-- Bascule du statut de service
function ToggleDuty()
    if not PlayerData.job or PlayerData.job.name ~= Config.Job.name then return end
    local newDutyStatus = not isOnDuty
    TriggerServerEvent('police:toggleDuty', newDutyStatus)
end

-- Réception du statut de service
RegisterNetEvent('police:setDuty')
AddEventHandler('police:setDuty', function(newStatus)
    isOnDuty = newStatus
    if isOnDuty then
        exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Vous êtes maintenant en service',
    title = 'Service Police',
    image = 'img/policenat.png',
    duration = 5000
})

    else
        exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Vous n\'êtes plus en service',
    title = 'Service Police',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end)

-- =============================================
-- Initialisation des points d'interaction (ox_target)
-- =============================================

function InitializeTargetPoints()
    -- Point d'accueil
    exports.ox_target:addBoxZone({
        coords = Config.Locations.main.coords,
        size = vec3(1.0, 1.0, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_reception',
                icon = 'fa-solid fa-clipboard',
                label = 'Accueil Police',
                distance = 2.5,
                onSelect = function()
                    OpenReceptionMenu()
                end
            }
        }
    })

    -- Vestiaire
    exports.ox_target:addBoxZone({
        coords = Config.Locations.vestiaire.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_cloakroom',
                icon = 'fa-solid fa-shirt',
                label = 'Vestiaire',
                distance = 2.5,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == 'police'
                end,
                onSelect = function()
                    OpenCloakroomMenu()
                end
            }
        }
    })

    -- Garage
    exports.ox_target:addBoxZone({
        coords = Config.Locations.garage.coords,
        size = vec3(3.0, 3.0, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_garage',
                icon = 'fa-solid fa-car',
                label = 'Garage',
                distance = 3.5,
                canInteract = function()
                    return IsOnDuty()
                end,
                onSelect = function()
                    OpenGarageMenu()
                end
            }
        }
    })

    -- Armurerie
    exports.ox_target:addBoxZone({
        coords = Config.Locations.armory.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_armory',
                icon = 'fa-solid fa-shield',
                label = 'Armurerie',
                distance = 2.5,
                canInteract = function()
                    return IsOnDuty()
                end,
                onSelect = function()
                    TriggerEvent('ox_inventory:openInventory', 'shop', {type = 'Police Armoury'})
                end
            }
        }
    })
end

-- =============================================
-- Menus principaux et sous-menus
-- =============================================

-- Menu Vestiaire
function OpenCloakroomMenu()
    local elements = {
        {
            title = 'Tenue Civile',
            description = 'Remettre vos vêtements civils',
            icon = 'shirt',
            onSelect = function()
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    TriggerEvent('skinchanger:loadSkin', skin)
                end)
            end
        },
        {
            title = 'Tenues de Service',
            description = 'Choisir une tenue complète',
            icon = 'person-military-rifle',
            onSelect = function()
                OpenUniformsMenu()
            end
        },
        {
            title = 'Accessoires',
            description = 'Ajouter ou retirer des accessoires',
            icon = 'hat-cowboy',
            onSelect = function()
                OpenAccessoriesMenu()
            end
        }
    }

    lib.registerContext({
        id = 'police_cloakroom',
        title = 'Vestiaire Police',
        options = elements
    })

    lib.showContext('police_cloakroom')
end

-- Ajoutez ces nouvelles fonctions après OpenCloakroomMenu

-- Menu des tenues complètes
function OpenUniformsMenu()
    local elements = {}

    -- Ajout des tenues de service disponibles selon le grade
    for i=1, #Config.Uniforms do
        local uniform = Config.Uniforms[i]
        if HasMinimumGrade(uniform.minGrade) then
            table.insert(elements, {
                title = uniform.label,
                description = 'Mettre cette tenue de service',
                icon = 'user-police',
                onSelect = function()
                    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                        if skin.sex == 0 then
                            TriggerEvent('skinchanger:loadClothes', skin, uniform.male)
                        else
                            TriggerEvent('skinchanger:loadClothes', skin, uniform.female)
                        end
                    end)
                    exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Vous avez enfilé une tenue de service',
    title = 'Vestiaire',
    image = 'img/policenat.png',
    duration = 5000
})

                end
            })
        end
    end

    lib.registerContext({
        id = 'police_uniforms',
        title = 'Tenues de Service',
        menu = 'police_cloakroom',
        options = elements
    })

    lib.showContext('police_uniforms')
end

-- Menu des accessoires
function OpenAccessoriesMenu()
    local elements = {
        {
            title = 'Casques/Coiffes',
            description = 'Chapeaux, casques et coiffes',
            icon = 'helmet-safety',
            onSelect = function()
                OpenAccessoryCategoryMenu('helmets', 'Casques/Coiffes')
            end
        },
        {
            title = 'Gilets',
            description = 'Gilets tactiques et de protection',
            icon = 'vest',
            onSelect = function()
                OpenAccessoryCategoryMenu('vests', 'Gilets')
            end
        },
        {
            title = 'Brassards',
            description = 'Brassards et accessoires',
            icon = 'hand',
            onSelect = function()
                OpenAccessoryCategoryMenu('bracelets', 'Brassards')
            end
        },
        {
            title = 'Enlever tous les accessoires',
            description = 'Retirer tous les accessoires',
            icon = 'x',
            onSelect = function()
                RemoveAllAccessories()
            end
        }
    }

    lib.registerContext({
        id = 'police_accessories',
        title = 'Accessoires',
        menu = 'police_cloakroom',
        options = elements
    })

    lib.showContext('police_accessories')
end

-- Menu pour une catégorie d'accessoires spécifique
function OpenAccessoryCategoryMenu(category, categoryLabel)
    local elements = {}
    
    -- Option pour retirer l'accessoire
    table.insert(elements, {
        title = 'Retirer',
        description = 'Enlever cet accessoire',
        icon = 'x',
        onSelect = function()
            RemoveAccessory(category)
        end
    })

    -- Ajout des accessoires disponibles selon le grade
    for i=1, #Config.Accessories[category] do
        local accessory = Config.Accessories[category][i]
        if HasMinimumGrade(accessory.minGrade) then
            table.insert(elements, {
                title = accessory.label,
                description = 'Porter cet accessoire',
                icon = 'plus',
                onSelect = function()
                    ApplyAccessory(category, accessory)
                end
            })
        end
    end

    lib.registerContext({
        id = 'police_accessory_category',
        title = categoryLabel,
        menu = 'police_accessories',
        options = elements
    })

    lib.showContext('police_accessory_category')
end

-- Appliquer un accessoire spécifique
function ApplyAccessory(category, accessory)
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        local accessoryItems = {}
        
        if skin.sex == 0 then -- Homme
            accessoryItems = accessory.male
        else -- Femme
            accessoryItems = accessory.female
        end
        
        local currentSkin = {}
        TriggerEvent('skinchanger:getSkin', function(getSkin)
            currentSkin = getSkin
        end)
        
        -- Appliquer uniquement les éléments de l'accessoire
        for k, v in pairs(accessoryItems) do
            currentSkin[k] = v
        end
        
        TriggerEvent('skinchanger:loadSkin', currentSkin)
        
        exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Vous avez mis ' .. accessory.label,
    title = 'Accessoires',
    image = 'img/policenat.png',
    duration = 5000
})

    end)
end

-- Enlever un accessoire spécifique
function RemoveAccessory(category)
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        local currentSkin = {}
        TriggerEvent('skinchanger:getSkin', function(getSkin)
            currentSkin = getSkin
        end)
        
        -- Réinitialiser les valeurs selon la catégorie
        if category == 'helmets' then
            currentSkin['helmet_1'] = -1
            currentSkin['helmet_2'] = 0
        elseif category == 'vests' then
            currentSkin['bproof_1'] = 0
            currentSkin['bproof_2'] = 0
        elseif category == 'bracelets' then
            -- Comme il peut s'agir soit de tshirt, soit de chain, on réinitialise les deux
            -- Une meilleure approche serait de stocker l'état précédent, mais cela nécessiterait plus de code
            if currentSkin['tshirt_1'] == 56 then -- Brassard Chaine
                currentSkin['tshirt_1'] = 105 -- Valeur par défaut des uniformes
                currentSkin['tshirt_2'] = 0
            end
            if currentSkin['chain_1'] == 7 then -- Brassard
                currentSkin['chain_1'] = 3 -- Valeur par défaut des uniformes
                currentSkin['chain_2'] = 0
            end
        end
        
        TriggerEvent('skinchanger:loadSkin', currentSkin)
        
        exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Vous avez retiré l\'accessoire',
    title = 'Accessoires',
    image = 'img/policenat.png',
    duration = 5000
})

    end)
end

-- Enlever tous les accessoires
function RemoveAllAccessories()
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        local currentSkin = {}
        TriggerEvent('skinchanger:getSkin', function(getSkin)
            currentSkin = getSkin
        end)
        
        -- Réinitialiser tous les accessoires
        currentSkin['helmet_1'] = -1
        currentSkin['helmet_2'] = 0
        currentSkin['bproof_1'] = 0
        currentSkin['bproof_2'] = 0
        
        -- Réinitialiser les brassards (avec les valeurs par défaut des uniformes)
        currentSkin['tshirt_1'] = 105
        currentSkin['tshirt_2'] = 0
        currentSkin['chain_1'] = 3
        currentSkin['chain_2'] = 0
        
        TriggerEvent('skinchanger:loadSkin', currentSkin)
        
        exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Vous avez retiré tous les accessoires',
    title = 'Accessoires',
    image = 'img/policenat.png',
    duration = 5000
})

    end)
end


-- Menu des plaintes
function OpenComplaintMenu()
    local input = lib.inputDialog('Enregistrement de plainte', {
        {
            type = 'select',
            label = 'Type de plainte',
            options = Config.Complaints.categories,
            required = true
        },
        {
            type = 'input',
            label = 'Nom du plaignant',
            description = 'Nom et prénom',
            required = true
        },
        {
            type = 'textarea',
            label = 'Description',
            description = 'Détails de la plainte',
            required = true
        }
    })

    if input then
        TriggerServerEvent('police:registerComplaint', {
            type = input[1],
            plaintiff = input[2],
            description = input[3]
        })
    end
end

-- Menu des alertes radio
function OpenAlertMenu()
    local elements = {}
    for _, code in ipairs(Config.Alerts.radioCodes) do
        table.insert(elements, {
            title = code.code .. ' - ' .. code.label,
            description = 'Envoyer cette alerte',
            icon = 'bell',
            onSelect = function()
                local coords = GetEntityCoords(PlayerPedId())
                TriggerServerEvent('police:sendAlert', code.code, coords)
            end
        })
    end

    lib.registerContext({
        id = 'police_alerts',
        title = 'Alertes Radio',
        options = elements
    })

    lib.showContext('police_alerts')
end

-- Menu F6 (menu principal)
function OpenPoliceMenu()
    local elements = {
        {
            title = isOnDuty and 'Fin de service' or 'Prise de service',
            description = 'Gérer votre service',
            icon = 'briefcase',
            onSelect = function()
                ToggleDuty()
            end
        }
    }

    if isOnDuty then
        -- LIGNE 2: Actions Personnelles
        table.insert(elements, {
            title = 'Actions Personnelles',
            description = 'Gérer vos actions personnelles',
            icon = 'user',
            onSelect = function()
                OpenPersonalActionsMenu()
            end
        })

        -- LIGNE 3: Interactions Citoyens
        table.insert(elements, {
            title = 'Interactions Citoyens',
            description = 'Gérer les interactions avec les citoyens',
            icon = 'users',
            onSelect = function()
                OpenCitizenInteractionMenu()
            end
        })

        -- LIGNE 4: Interactions Véhicules
        table.insert(elements, {
            title = 'Véhicules volés',
            description = 'Voir la liste des véhicules signalés volés',
            icon = 'car-burst',
            onSelect = function()
                OpenStolenVehiclesListMenu()
            end
        })

        table.insert(elements, {
            title = 'Interactions Véhicules',
            description = 'Gérer les interactions avec les véhicules',
            icon = 'car',
            onSelect = function()
                OpenVehicleInteractionMenu()
            end
        })

        -- LIGNE 5: Gestion des Rendez-vous
        table.insert(elements, {
            title = 'Gestion des Rendez-vous',
            description = 'Voir et gérer les rendez-vous',
            icon = 'calendar',
            onSelect = function()
                OpenAppointmentsManagementMenu()
            end
        })

        -- LIGNE 6: Casier Judiciaire
        table.insert(elements, {
            title = 'Casier Judiciaire',
            description = 'Consulter et gérer les casiers judiciaires',
            icon = 'file-alt',
            onSelect = function()
                OpenCriminalRecordMenu()
            end
        })

        -- LIGNE 7: Gestion Entreprise (uniquement pour les grades élevés)
        if PlayerData.job.grade >= Config.Job.bossGrade then
            table.insert(elements, {
                title = 'Gestion Entreprise',
                description = 'Gérer l\'entreprise',
                icon = 'building',
                onSelect = function()
                    OpenBossMenu()
                end
            })
        end
    end

    lib.registerContext({
        id = 'police_main_menu',
        title = 'Menu Police',
        options = elements
    })

    lib.showContext('police_main_menu')
end

-- Menu Actions Personnelles
function OpenPersonalActionsMenu()
    local elements = {
        {
            title = 'Tenues',
            description = 'Changer de tenue',
            icon = 'shirt',
            onSelect = function()
                OpenCloakroomMenu()
            end
        },
        {
            title = 'Gestion objets',
            description = 'Poser/Retirer des objets',
            icon = 'box',
            onSelect = function()
                OpenPropsMenu()
            end
        },
        {
            title = 'Gestion des plaintes',
            description = 'Gérer les plaintes',
            icon = 'file-pen',
            onSelect = function()
                OpenComplaintsMenu()
            end
        },
        {
            title = 'Alertes radio',
            description = 'Envoyer une alerte aux collègues',
            icon = 'radio',
            onSelect = function()
                OpenAlertMenu()
            end
        }
    }

    if HasMinimumGrade(Config.K9.minGrade) then
        table.insert(elements, {
            title = 'Gestion K9',
            description = 'Gérer votre chien de police',
            icon = 'dog',
            onSelect = function()
                OpenK9Menu()
            end
        })
    end

    lib.registerContext({
        id = 'police_personal',
        title = 'Actions Personnelles',
        options = elements
    })

    lib.showContext('police_personal')
end

-- Menu de gestion des plaintes
function OpenComplaintsMenu()
    local elements = {
        {
            title = 'Enregistrer une plainte',
            description = 'Enregistrer une nouvelle plainte',
            icon = 'plus',
            onSelect = function()
                OpenComplaintRegistrationMenu()
            end
        },
        {
            title = 'Consulter les plaintes',
            description = 'Voir les plaintes enregistrées',
            icon = 'list',
            onSelect = function()
                OpenComplaintsManagementMenu()
            end
        }
    }
    
    lib.registerContext({
        id = 'police_complaints_menu',
        title = 'Gestion des Plaintes',
        options = elements
    })

    lib.showContext('police_complaints_menu')
end

-- Menu pour enregistrer une plainte
function OpenComplaintRegistrationMenu()
    local input = lib.inputDialog('Enregistrement de plainte', {
        {
            type = 'select',
            label = 'Type de plainte',
            options = Config.Complaints.categories,
            required = true
        },
        {
            type = 'input',
            label = 'Nom du plaignant',
            description = 'Nom et prénom',
            required = true
        },
        {
            type = 'textarea',
            label = 'Description',
            description = 'Détails de la plainte',
            required = true
        }
    })

    if input then
        TriggerServerEvent('police:registerComplaint', {
            type = input[1],
            plaintiff = input[2],
            description = input[3]
        })
        
        exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Plainte enregistrée avec succès',
    title = 'Plainte',
    image = 'img/policenat.png',
    duration = 5000
})

    end
end

-- Menu de gestion des plaintes
function OpenComplaintsManagementMenu()
    ESX.TriggerServerCallback('police:getComplaints', function(complaints)
        local elements = {}
        
        if #complaints == 0 then
            table.insert(elements, {
                title = 'Aucune plainte',
                description = 'Aucune plainte n\'a été enregistrée',
                disabled = true
            })
        else
            for _, complaint in ipairs(complaints) do
                local statusColor = complaint.status == 'Ouvert' and 'green' or 'gray'
                
                table.insert(elements, {
                    title = complaint.type .. ' - ' .. complaint.plaintiff,
                    description = 'Date: ' .. complaint.date .. ' - Status: ' .. complaint.status,
                    metadata = {
                        {label = 'Description', value = complaint.description},
                        {label = 'Agent', value = complaint.officer_name or 'Inconnu'}
                    },
                    onSelect = function()
                        if complaint.status == 'Ouvert' then
                            OpenComplaintDetailsMenu(complaint)
                        else
                            exports['jl_notifications']:ShowNotification({
    type = 'info',
    message = 'Cette plainte est déjà fermée',
    title = 'Plainte',
    image = 'img/policenat.png',
    duration = 5000
})

                        end
                    end
                })
            end
        end

        lib.registerContext({
            id = 'police_complaints_menu',
            title = 'Gestion des Plaintes',
            options = elements
        })

        lib.showContext('police_complaints_menu')
    end)
end

-- Menu détails d'une plainte
function OpenComplaintDetailsMenu(complaint)
    local elements = {
        {
            title = 'Détails de la plainte',
            description = complaint.description,
            metadata = {
                {label = 'Plaignant', value = complaint.plaintiff},
                {label = 'Date', value = complaint.date},
                {label = 'Agent', value = complaint.officer_name or 'Inconnu'}
            }
        },
        {
            title = 'Clôturer la plainte',
            description = 'Marquer cette plainte comme résolue',
            icon = 'check',
            onSelect = function()
                local input = lib.inputDialog('Rapport de clôture', {
                    {
                        type = 'textarea',
                        label = 'Rapport',
                        description = 'Expliquez comment la plainte a été résolue',
                        required = true
                    }
                })

                if input then
                    TriggerServerEvent('police:closeComplaint', complaint.id, input[1])
                    exports['jl_notifications']:ShowNotification({
    type = 'success',
    message = 'Plainte clôturée avec succès',
    title = 'Plainte',
    image = 'img/policenat.png',
    duration = 5000
})

                    Wait(500)
                    OpenComplaintsManagementMenu()
                end
            end
        }
    }

    lib.registerContext({
        id = 'complaint_details',
        title = 'Plainte #' .. complaint.id,
        menu = 'police_complaints_menu',
        options = elements
    })

    lib.showContext('complaint_details')
end

-- Fonction pour ouvrir le menu de gestion d'entreprise
function OpenBossMenu()
    -- Méthode standard pour esx_society
    TriggerEvent('esx_society:openBossMenu', 'police', function(data, menu)
    end, {wash = false}) -- {wash = true} si vous voulez activer le blanchiment d'argent
end

-- =============================================
-- Casier judiciaire
-- =============================================

-- Fonction pour ouvrir le menu casier judiciaire
function OpenCriminalRecordMenu()
    local input = lib.inputDialog('Recherche casier judiciaire', {
        {
            type = 'input',
            label = 'Numéro de la carte d\'identité',
            description = 'Exemple: ID-123456',
            required = true
        }
    })
    
    if not input or not input[1] then return end
    
    ESX.TriggerServerCallback('police:searchCitizenByDocumentNumber', function(data)
        if not data then
            exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Aucun citoyen trouvé avec ce numéro d\'identité',
    title = 'Casier Judiciaire',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end
        
        -- Afficher les informations du citoyen
        OpenCitizenInfoMenu(data)
    end, input[1])
end

-- Affichage des informations du citoyen
function OpenCitizenInfoMenu(data)
    local citizen = data.citizen
    local fullName = citizen.firstname .. ' ' .. citizen.lastname
    
    local elements = {
        {
            title = 'Informations personnelles',
            description = fullName,
            metadata = {
                {label = 'Nom', value = citizen.lastname},
                {label = 'Prénom', value = citizen.firstname},
                {label = 'Date de naissance', value = citizen.dateofbirth},
                {label = 'Sexe', value = citizen.sex == 'm' and 'Masculin' or 'Féminin'},
                {label = 'Taille', value = citizen.height .. ' cm'}
            }
        },
        {
            title = 'Documents',
            description = 'Voir les documents du citoyen',
            icon = 'id-card',
            onSelect = function()
                OpenCitizenDocumentsMenu(data.documents)
            end
        },
        {
            title = 'Casier judiciaire',
            description = #data.criminalRecords > 0 and 'Voir les antécédents' or 'Casier vierge',
            icon = 'file-alt',
            onSelect = function()
                OpenCriminalRecordsListMenu(data.criminalRecords, citizen, data.documents)
            end
        },
        {
            title = 'Ajouter une infraction',
            description = 'Enregistrer une nouvelle infraction',
            icon = 'plus',
            onSelect = function()
                OpenAddCriminalRecordMenu(citizen, data.documents[1])
            end
        }
    }
    
    lib.registerContext({
        id = 'police_citizen_info',
        title = 'Dossier de ' .. fullName,
        options = elements
    })
    
    lib.showContext('police_citizen_info')
end

-- Menu des documents du citoyen
function OpenCitizenDocumentsMenu(documents)
    local elements = {}
    
    for _, doc in ipairs(documents) do
        local statusColor = doc.isExpired and 'red' or 'green'
        local statusText = doc.isExpired and 'Expiré' or 'Valide'
        
        table.insert(elements, {
            title = GetDocumentTypeName(doc.type) .. ' - ' .. doc.number,
            description = statusText,
            icon = doc.isExpired and 'times' or 'check',
            metadata = {
                {label = 'Nom', value = doc.lastName},
                {label = 'Prénom', value = doc.firstName},
                {label = 'Date d\'émission', value = doc.issueDate},
                {label = 'Date d\'expiration', value = doc.expirationDate},
                {label = 'Délivré par', value = doc.issuer}
            }
        })
    end
    
    if #elements == 0 then
        table.insert(elements, {
            title = 'Aucun document',
            description = 'Le citoyen ne possède aucun document',
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'police_citizen_documents',
        title = 'Documents du citoyen',
        menu = 'police_citizen_info',
        options = elements
    })
    
    lib.showContext('police_citizen_documents')
end

-- Liste des infractions du casier judiciaire
function OpenCriminalRecordsListMenu(records, citizen, documents)
    local elements = {}
    
    if #records == 0 then
        table.insert(elements, {
            title = 'Casier judiciaire vierge',
            description = 'Aucun antécédent judiciaire enregistré',
            icon = 'check',
            disabled = true
        })
    else
        for _, record in ipairs(records) do
            table.insert(elements, {
                title = record.offense,
                description = 'Date: ' .. record.date,
                metadata = {
                    {label = 'Agent', value = record.officerName},
                    {label = 'Amende', value = '€' .. record.fineAmount},
                    {label = 'Peine', value = record.jailTime .. ' minutes'},
                    {label = 'Notes', value = record.notes or 'Aucune'}
                },
                onSelect = function()
                    -- Option pour supprimer l'entrée si grade suffisant
                    if ESX.GetPlayerData().job.grade >= (Config.Job.bossGrade - 1) then
                        local alert = lib.alertDialog({
                            header = 'Supprimer l\'entrée',
                            content = 'Voulez-vous supprimer cette entrée du casier judiciaire?',
                            centered = true,
                            cancel = true
                        })
                        
                        if alert == 'confirm' then
                            TriggerServerEvent('police:deleteCriminalRecord', record.id)
                            
                            -- Attendre un peu puis rafraîchir le menu
                            Wait(500)
                            ESX.TriggerServerCallback('police:searchCitizenByDocumentNumber', function(newData)
                                if newData then
                                    OpenCriminalRecordsListMenu(newData.criminalRecords, citizen, documents)
                                end
                            end, documents[1].number)
                        end
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'police_criminal_records',
        title = 'Casier judiciaire',
        menu = 'police_citizen_info',
        options = elements
    })
    
    lib.showContext('police_criminal_records')
end

-- Menu pour ajouter une infraction
function OpenAddCriminalRecordMenu(citizen, document)
    if not document then
	exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = 'Impossible d\'ajouter une infraction: aucun document d\'identité trouvé',
    title = 'Casier Judiciaire',
    image = 'img/policenat.png',
    duration = 5000
})
        return
    end
    
    local input = lib.inputDialog('Ajouter une infraction', {
        {
            type = 'input',
            label = 'Infraction',
            description = 'Nature de l\'infraction',
            required = true
        },
        {
            type = 'number',
            label = 'Montant de l\'amende',
            description = 'En euro',
            icon = 'euro-sign',
            default = 0,
            min = 0,
            max = 100000
        },
        {
            type = 'number',
            label = 'Durée d\'emprisonnement',
            description = 'En minutes',
            icon = 'clock',
            default = 0,
            min = 0,
            max = 1000
        },
        {
            type = 'textarea',
            label = 'Notes',
            description = 'Informations supplémentaires'
        }
    })
    
    if not input then return end
    
    -- Vérifier si le joueur est en ligne pour envoyer éventuellement en prison
    local targetId = nil
    local players = ESX.Game.GetPlayers()
    for i=1, #players do
        local target = ESX.GetPlayerData(players[i])
        if target and target.identifier == citizen.identifier then
            targetId = players[i]
            break
        end
    end
    
    TriggerServerEvent('police:addCriminalRecord', {
        citizenId = citizen.identifier,
        documentNumber = document.number,
        citizenName = citizen.firstname .. ' ' .. citizen.lastname,
        offense = input[1],
        fineAmount = input[2],
        jailTime = input[3],
        notes = input[4],
        targetId = targetId
    })
    
    -- Rafraîchir le menu après quelques secondes
    Wait(500)
    ESX.TriggerServerCallback('police:searchCitizenByDocumentNumber', function(data)
        if data then
            OpenCitizenInfoMenu(data)
        end
    end, document.number)
end

-- =============================================
-- Fonction utilitaires
-- =============================================

-- Obtenir le nom du type de document
function GetDocumentTypeName(type)
    local documentTypes = {
        ID = 'Carte d\'identité',
        Driver = 'Permis de conduire',
        Weapon = 'Permis de port d\'arme'
    }
    
    return documentTypes[type] or type
end

-- =============================================
-- Event handlers pour les alertes et les licences
-- =============================================

-- Réception des alertes radio
RegisterNetEvent('police:receiveAlert')
AddEventHandler('police:receiveAlert', function(code, coords, officerName)
    -- Trouver les informations du code d'alerte
    local codeInfo = nil
    for _, codeData in ipairs(Config.Alerts.radioCodes) do
        if codeData.code == code then
            codeInfo = codeData
            break
        end
    end
    
    if not codeInfo then return end
    
    -- Notification
	
	exports['jl_notifications']:ShowNotification({
    type = 'error',
    message = officerName .. ': ' .. codeInfo.label,
    title = 'Alerte ' .. code,
    image = 'img/policenat.png',
    duration = 10000
})
   
    -- Création d'un blip temporaire
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Alerts.blip.sprite)
    SetBlipColour(blip, Config.Alerts.blip.color)
    SetBlipScale(blip, Config.Alerts.blip.scale)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Alerte: ' .. code)
    EndTextCommandSetBlipName(blip)
    
    -- Ajouter à la liste des blips actifs
    table.insert(activeBlips, {
        blip = blip,
        time = GetGameTimer() + (Config.Alerts.duration * 1000)
    })
    
    -- S'assurer que le thread de nettoyage est actif
    if #activeBlips == 1 then
        CreateThread(function()
            while #activeBlips > 0 do
                local currentTime = GetGameTimer()
                for i = #activeBlips, 1, -1 do
                    if currentTime > activeBlips[i].time then
                        RemoveBlip(activeBlips[i].blip)
                        table.remove(activeBlips, i)
                    end
                end
                Wait(1000)
            end
        end)
    end
end)

-- Event pour afficher les licences
RegisterNetEvent('police:showLicenses')
AddEventHandler('police:showLicenses', function(licenses)
    local elements = {}
    
    -- Carte d'identité
    table.insert(elements, {
        title = "Carte d'Identité",
        description = licenses['identity_card'] and 'Valide' or 'Non valide',
        icon = licenses['identity_card'] and 'check' or 'xmark',
        metadata = {
            {label = 'Statut', value = licenses['identity_card'] and 'Document valide' or 'Document non présenté ou expiré'}
        }
    })
    
    -- Permis de conduire
    table.insert(elements, {
        title = "Permis de Conduire",
        description = licenses['drive'] and 'Valide' or 'Non valide',
        icon = licenses['drive'] and 'check' or 'xmark',
        metadata = {
            {label = 'Statut', value = licenses['drive'] and 'Document valide' or 'Document non présenté ou expiré'}
        }
    })
    
    -- Permis de port d'arme
    table.insert(elements, {
        title = "Permis de Port d'Arme",
        description = licenses['weapon'] and 'Valide' or 'Non valide',
        icon = licenses['weapon'] and 'check' or 'xmark',
        metadata = {
            {label = 'Statut', value = licenses['weapon'] and 'Document valide' or 'Document non présenté ou expiré'}
        }
    })
    
    -- Ajouter d'autres licences si elles existent
    for type, status in pairs(licenses) do
        if type ~= 'identity_card' and type ~= 'drive' and type ~= 'weapon' then
            table.insert(elements, {
                title = string.upper(string.sub(type, 1, 1)) .. string.sub(type, 2),
                description = status and 'Valide' or 'Non valide',
                icon = status and 'check' or 'xmark'
            })
        end
    end

    lib.registerContext({
        id = 'police_licenses_menu',
        title = 'Licences du citoyen',
        options = elements
    })

    lib.showContext('police_licenses_menu')
end)

-- =============================================
-- Commandes et keybinds
-- =============================================

-- Menu F6
RegisterCommand('policemenu', function()
    if not PlayerData.job or PlayerData.job.name ~= Config.Job.name then return end
    OpenPoliceMenu()
end)

RegisterKeyMapping('policemenu', 'Menu Police', 'keyboard', 'F6')