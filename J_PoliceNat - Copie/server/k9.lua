-- J_PoliceNat\server\k9.lua"
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Configuration et variables
-- =============================================

-- Liste des items que le chien peut détecter
local illegalItems = {
    -- Drogues
    'weed',
    'weed_pooch',
    'coke',
    'coke_pooch',
    'meth',
    'meth_pooch',
    'opium',
    'opium_pooch',
    
    -- Explosifs
    'c4_bank',
    'thermite',
    'explosive',
    
    -- Armes illégales
    'WEAPON_SMG',
    'WEAPON_ASSAULTRIFLE',
    'armor'
}

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Fonction pour logger les messages (à des fins de débogage)
function LogDebug(message)
    -- Débogage désactivé en production
    -- print("[K9 DEBUG] " .. message)
end

-- =============================================
-- Vérifications d'inventaire
-- =============================================

-- Vérification d'inventaire par le chien
RegisterServerEvent('police:k9CheckInventory')
AddEventHandler('police:k9CheckInventory', function(targetId)
    local source = source
    
    if not IsPolice(source) then return end
    if not HasMinimumGrade(source, Config.K9.minGrade) then
        exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Grade insuffisant pour utiliser l\'unité K9',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end
        
    -- Version améliorée pour vérifier l'inventaire du joueur
    local itemDetected = false
    local inventory = exports.ox_inventory:GetInventory(targetId)
    
    if inventory and inventory.items then
        for slot, item in pairs(inventory.items) do
            if item and item.name then
                for _, illegalItem in ipairs(illegalItems) do
                    if string.lower(item.name) == string.lower(illegalItem) then
                        itemDetected = true
                        break
                    end
                end
            end
            if itemDetected then break end
        end
    else
        print("Aucun inventaire trouvé pour le joueur")
    end
        
    -- Notification au policier avec type spécifique (joueur)
    TriggerClientEvent('police:k9ItemDetectedPlayer', source, itemDetected)
    
    -- Log Discord
    local embed = exports['J_PoliceNat']:FormatEmbed(
    "Recherche K9 - Personne",
    ('L\'agent %s a effectué une recherche K9 sur %s'):format(
        ESX.GetPlayerFromId(source).getName(),
        xTarget.getName()
    ),
    itemDetected and 15158332 or 3066993,
    {{name = "Résultat", value = itemDetected and '⚠️ Détection positive' or '✅ Rien à signaler'}}
)
exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - K9", nil, {embed})

end)

-- Vérification K9 du véhicule
RegisterServerEvent('police:k9CheckVehicle')
AddEventHandler('police:k9CheckVehicle', function(plate, netId)
    local source = source
    if not IsPolice(source) then return end
    local xPlayer = ESX.GetPlayerFromId(source)

    -- Vérification du grade pour le K9
    if not HasMinimumGrade(source, Config.K9.minGrade) then
        exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Grade insuffisant pour utiliser l\'unité K9',
    title = 'K9',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Nettoyer la plaque (enlever les espaces)
    plate = string.gsub(plate, "%s", "")
    
    -- Format de la plaque dans la base de données (avec espaces)
    local dbPlate = string.format("%s %s%s", string.sub(plate, 1, 3), string.sub(plate, 4, 5), string.sub(plate, 6))
    
    print("K9 vérifie le véhicule avec plaque: " .. plate .. " (dbPlate: " .. dbPlate .. ")")
    
    local itemDetected = false
    
    -- Vérification directe dans la base de données
    MySQL.query('SELECT glovebox, trunk FROM owned_vehicles WHERE plate = ?', {dbPlate}, function(result)
        if result and result[1] then
            -- Vérifier la boîte à gants
            if result[1].glovebox and result[1].glovebox ~= '' then
                local items = json.decode(result[1].glovebox)
                
                if items then
                    for _, item in ipairs(items) do
                        print("DB glovebox - Item: " .. (item.name or "sans nom"))
                        
                        for _, illegalItem in ipairs(illegalItems) do
                            if string.lower(item.name) == string.lower(illegalItem) then
                                print("Item illégal trouvé dans DB glovebox: " .. item.name)
                                itemDetected = true
                                break
                            end
                        end
                        
                        if itemDetected then break end
                    end
                end
            end
            
            -- Vérifier le coffre si rien n'a été trouvé dans la boîte à gants
            if not itemDetected and result[1].trunk and result[1].trunk ~= '' then
                local items = json.decode(result[1].trunk)
                
                if items then
                    for _, item in ipairs(items) do
                        print("DB trunk - Item: " .. (item.name or "sans nom"))
                        
                        for _, illegalItem in ipairs(illegalItems) do
                            if string.lower(item.name) == string.lower(illegalItem) then
                                print("Item illégal trouvé dans DB trunk: " .. item.name)
                                itemDetected = true
                                break
                            end
                        end
                        
                        if itemDetected then break end
                    end
                end
            end
        end
        
        print("Résultat final de la vérification K9 (véhicule): " .. tostring(itemDetected))
        
        -- Notification au policier avec type spécifique (véhicule)
        TriggerClientEvent('police:k9ItemDetectedVehicle', source, itemDetected)

        -- Log Discord
        local embed = exports['J_PoliceNat']:FormatEmbed(
    "Recherche K9 - Véhicule",
    ('L\'agent %s a effectué une recherche K9 sur le véhicule [%s]'):format(
        xPlayer.getName(),
        dbPlate
    ),
    itemDetected and 15158332 or 3066993,
    {{name = "Résultat", value = itemDetected and '⚠️ Détection positive' or '✅ Rien à signaler'}}
)
exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - K9", nil, {embed})

    end)
end)

-- =============================================
-- Actions du chien K9
-- =============================================

-- Système d'attaque K9
RegisterServerEvent('police:k9Attack')
AddEventHandler('police:k9Attack', function(targetId)
    local source = source
    if not IsPolice(source) then return end
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Vérification du grade pour le K9
    if not HasMinimumGrade(source, Config.K9.minGrade) then return end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    -- Notification de l'attaque
    TriggerClientEvent('police:k9AttackTarget', targetId)

    -- Log Discord
    local embed = exports['J_PoliceNat']:FormatEmbed(
    "Attaque K9",
    ('L\'agent %s a ordonné une attaque K9 sur %s'):format(
        xPlayer.getName(),
        xTarget.getName()
    ),
    15158332
)
exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - K9", nil, {embed})

end)

-- Système de suivi K9
RegisterServerEvent('police:k9Follow')
AddEventHandler('police:k9Follow', function(targetId)
    local source = source
    if not IsPolice(source) then return end
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Vérification du grade pour le K9
    if not HasMinimumGrade(source, Config.K9.minGrade) then return end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    -- Notification du suivi à tous les policiers en service
    local officers = exports["police"]:GetOnDutyPolice()
    for _, officer in ipairs(officers) do
        TriggerClientEvent('police:k9FollowTarget', officer.source, targetId)
    end

    -- Log Discord
    local embed = exports['J_PoliceNat']:FormatEmbed(
    "Suivi K9",
    ('L\'agent %s a ordonné le suivi d\'une cible par le K9'):format(
        xPlayer.getName()
    ),
    3066993
)
exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - K9", nil, {embed})

end)