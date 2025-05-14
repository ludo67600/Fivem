-- J_PoliceNat server/props.lua
local ESX = exports["es_extended"]:getSharedObject()

-- Table pour stocker les props actifs
local activeProps = {}

-- Fonction pour obtenir le label d'un prop
function GetPropLabel(model)
    for _, prop in ipairs(Config.Props) do
        if prop.model == model then
            return prop.label
        end
    end
    return model
end

-- Chargement des props au démarrage
CreateThread(function()
    Wait(1000) -- Attendre que la base de données soit prête
    MySQL.query('SELECT * FROM police_props', {}, function(results)
        if results then
            for _, prop in ipairs(results) do
                activeProps[prop.id] = {
                    id = prop.id,
                    model = prop.model,
                    coords = json.decode(prop.position),
                    heading = prop.heading,
                    officer_identifier = prop.officer_identifier
                }
            end
            print("^2[Police Props] Chargé " .. #results .. " props^7")
        end
    end)
end)

-- Synchronisation des props pour tous les clients
RegisterServerEvent('police:requestProps')
AddEventHandler('police:requestProps', function()
    local source = source
    TriggerClientEvent('police:loadProps', source, activeProps)
end)

-- Sauvegarde d'un prop
RegisterServerEvent('police:saveProp')
AddEventHandler('police:saveProp', function(propInfo)
    local source = source
    if not IsPolice(source) then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    
    MySQL.insert('INSERT INTO police_props (model, position, heading, officer_identifier, created_at) VALUES (?, ?, ?, ?, NOW())', {
        propInfo.model,
        json.encode(propInfo.coords),
        propInfo.heading,
        xPlayer.identifier
    }, function(id)
        if id then
            -- Ajout aux props actifs
            activeProps[id] = {
                id = id,
                model = propInfo.model,
                coords = propInfo.coords,
                heading = propInfo.heading,
                officer_identifier = xPlayer.identifier
            }
            
            -- Notifier tous les autres clients
            local players = ESX.GetPlayers()
            for _, playerId in ipairs(players) do
                if playerId ~= source then
                    TriggerClientEvent('police:loadProps', playerId, activeProps)
                end
            end
            
            -- Log Discord
            local embed = exports['J_PoliceNat']:FormatEmbed(
                "Placement d'objet",
                ('L\'agent %s a placé un %s'):format(
                    xPlayer.getName(),
                    GetPropLabel(propInfo.model)
                ),
                3066993
            )
            exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Props", nil, {embed})
        end
    end)
end)

-- Suppression d'un prop
RegisterServerEvent('police:removeProp')
AddEventHandler('police:removeProp', function(propInfo)
    local source = source
    if not IsPolice(source) then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Zone de recherche large
    MySQL.query('SELECT id FROM police_props WHERE model = ? AND JSON_EXTRACT(position, "$.x") BETWEEN ? AND ? AND JSON_EXTRACT(position, "$.y") BETWEEN ? AND ? AND JSON_EXTRACT(position, "$.z") BETWEEN ? AND ?', {
        propInfo.model,
        propInfo.coords.x - 5.0, propInfo.coords.x + 5.0,
        propInfo.coords.y - 5.0, propInfo.coords.y + 5.0,
        propInfo.coords.z - 5.0, propInfo.coords.z + 5.0
    }, function(results)
        if results and #results > 0 then
            -- Supprimer de la base de données
            MySQL.update('DELETE FROM police_props WHERE id = ?', {results[1].id}, function(affectedRows)
                if affectedRows > 0 then
                    -- Suppression du prop actif
                    activeProps[results[1].id] = nil
                    
                    -- Notifier tous les autres clients
                    local players = ESX.GetPlayers()
                    for _, playerId in ipairs(players) do
                        if playerId ~= source then
                            TriggerClientEvent('police:loadProps', playerId, activeProps)
                        end
                    end
                    
                    -- Log Discord
                    local embed = exports['J_PoliceNat']:FormatEmbed(
                        "Retrait d'objet",
                        ('L\'agent %s a retiré un %s'):format(
                            xPlayer.getName(),
                            GetPropLabel(propInfo.model)
                        ),
                        15158332
                    )
                    exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Props", nil, {embed})
                end
            end)
        else
            -- Tentative alternative de suppression
            MySQL.update('DELETE FROM police_props WHERE model = ? LIMIT 1', {propInfo.model}, function(affectedRows)
                if affectedRows > 0 then
                    -- Recharger tous les props
                    RefreshProps()
                end
            end)
        end
    end)
end)

-- Fonction pour recharger tous les props depuis la base de données
function RefreshProps()
    MySQL.query('SELECT * FROM police_props', {}, function(results)
        -- Vider la table des props actifs
        activeProps = {}
        
        -- Recharger tous les props
        if results then
            for _, prop in ipairs(results) do
                activeProps[prop.id] = {
                    id = prop.id,
                    model = prop.model,
                    coords = json.decode(prop.position),
                    heading = prop.heading,
                    officer_identifier = prop.officer_identifier
                }
            end
        end
        
        -- Synchroniser avec tous les clients
        TriggerClientEvent('police:loadProps', -1, activeProps)
    end)
end

-- Nettoyage automatique des props anciens
CreateThread(function()
    while true do
        Wait(3600000) -- Toutes les heures
        
        -- Suppression des props placés il y a plus de 12 heures
        MySQL.update('DELETE FROM police_props WHERE TIMESTAMPDIFF(HOUR, created_at, NOW()) > 12', {}, function(affectedRows)
            if affectedRows > 0 then
                -- Recharger tous les props
                RefreshProps()
            end
        end)
    end
end)

-- Export pour récupérer les props actifs
exports('GetActiveProps', function()
    return activeProps
end)