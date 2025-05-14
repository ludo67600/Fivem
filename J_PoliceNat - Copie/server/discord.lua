-- J_PoliceNat\server\discord.lua
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Configuration des webhooks
-- =============================================

-- Utilisation des webhooks configurés dans Config.DiscordWebhook
local webhooks = {
    alerts = Config.DiscordWebhook.alerts,       -- Webhook pour les alertes courantes
    rendezvous = Config.DiscordWebhook.rendezvous, -- Webhook pour les rendez-vous
    plaintes = Config.DiscordWebhook.plaintes,    -- Webhook pour les plaintes et vols de véhicules
    casier = Config.DiscordWebhook.casier        -- Webhook pour les casiers judiciaires
}

-- =============================================
-- Fonctions utilitaires pour les notifications Discord
-- =============================================

-- Fonction générique pour envoyer un message à Discord
function SendToDiscord(webhookURL, username, message, embeds)
    if not webhookURL or webhookURL == 'VOTRE_WEBHOOK_ICI' then
        -- Webhook non configuré, on n'envoie pas de message
        return
    end

    local data = {
        username = username or "Police Nationale",
        content = message or nil,
        embeds = embeds or nil
    }

    PerformHttpRequest(webhookURL, function(err, text, headers) end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end

-- Fonction pour formater un embed Discord
function FormatEmbed(title, description, color, fields, footer)
    local embed = {
        title = title,
        description = description,
        color = color or 3447003, -- Bleu par défaut
        fields = fields or {},
        footer = {
            text = footer or "Police Nationale • " .. os.date("%d/%m/%Y %H:%M:%S")
        }
    }
    
    return embed
end

-- =============================================
-- Fonctions spécifiques pour différents types de notifications
-- =============================================

-- Notification de prise/fin de service
function NotifyDutyChange(playerName, isDutyOn)
    local status = isDutyOn and "a pris son service" or "a terminé son service"
    local color = isDutyOn and 3066993 or 15158332 -- Vert si prise de service, rouge si fin de service
    
    local embed = FormatEmbed(
        "Changement de service",
        "**" .. playerName .. "** " .. status,
        color
    )
    
    SendToDiscord(webhooks.alerts, "Police Nationale - Service", nil, {embed})
end

-- Notification d'amende
function NotifyFine(officerName, targetName, amount, reason)
    local embed = FormatEmbed(
        "Amende",
        "**" .. officerName .. "** a donné une amende à **" .. targetName .. "**",
        15105570, -- Orange
        {
            {name = "Montant", value = amount .. "€", inline = true},
            {name = "Raison", value = reason, inline = true}
        }
    )
    
    SendToDiscord(webhooks.alerts, "Police Nationale - Amendes", nil, {embed})
end

-- Notification de fouille
function NotifySearch(officerName, targetName, itemsFound)
    local description = "**" .. officerName .. "** a fouillé **" .. targetName .. "**"
    local color = #itemsFound > 0 and 15158332 or 3066993 -- Rouge si des items trouvés, vert sinon
    
    local fields = {}
    if #itemsFound > 0 then
        local itemsList = ""
        for _, item in ipairs(itemsFound) do
            itemsList = itemsList .. "- " .. item.count .. "x " .. item.label .. "\n"
        end
        
        table.insert(fields, {name = "Items trouvés", value = itemsList})
    else
        table.insert(fields, {name = "Résultat", value = "Aucun item suspect trouvé"})
    end
    
    local embed = FormatEmbed(
        "Fouille",
        description,
        color,
        fields
    )
    
    SendToDiscord(webhooks.alerts, "Police Nationale - Fouilles", nil, {embed})
end

-- Notification de casier judiciaire
function NotifyCriminalRecord(officerName, targetName, offense, fine, jailTime)
    local embed = FormatEmbed(
        "Casier Judiciaire",
        "**" .. officerName .. "** a ajouté une infraction au casier de **" .. targetName .. "**",
        15158332, -- Rouge
        {
            {name = "Infraction", value = offense, inline = false},
            {name = "Amende", value = fine .. "€", inline = true},
            {name = "Peine de prison", value = jailTime .. " minutes", inline = true}
        }
    )
    
    SendToDiscord(webhooks.casier, "Police Nationale - Casier Judiciaire", nil, {embed})
end

-- Notification de plainte
function NotifyComplaint(officerName, plaintiff, type, status, description)
    local embed = FormatEmbed(
        "Plainte - " .. status,
        "**" .. officerName .. "** a " .. (status == "Ouvert" and "enregistré" or "clôturé") .. " une plainte",
        status == "Ouvert" and 16776960 or 3066993, -- Jaune pour ouvert, vert pour clôturé
        {
            {name = "Plaignant", value = plaintiff, inline = true},
            {name = "Type", value = type, inline = true},
            {name = "Description", value = description, inline = false}
        }
    )
    
    -- Envoi vers le webhook des plaintes (important!)
    SendToDiscord(webhooks.plaintes, "Police Nationale - Plaintes", nil, {embed})
end

-- Notification de rendez-vous
function NotifyAppointment(type, citizenName, officerName, subject, date, time, status)
    local title = "Rendez-vous - " .. type
    local description = "Rendez-vous entre **" .. citizenName .. "** et **" .. (officerName or "Non assigné") .. "**"
    
    local color
    if status == "En attente" then
        color = 16776960 -- Jaune
    elseif status == "Accepté" then
        color = 3066993 -- Vert
    elseif status == "Terminé" then
        color = 7506394 -- Gris
    elseif status == "Annulé" then
        color = 15158332 -- Rouge
    end
    
    local fields = {
        {name = "Sujet", value = subject, inline = true},
        {name = "Date", value = date .. " à " .. time, inline = true},
        {name = "Statut", value = status, inline = true}
    }
    
    local embed = FormatEmbed(
        title,
        description,
        color,
        fields
    )
    
    SendToDiscord(webhooks.rendezvous, "Police Nationale - Rendez-vous", nil, {embed})
end

-- Notification de véhicule volé
function NotifyStolenVehicle(citizenName, plate, status, description)
    local title = status and "Véhicule volé" or "Véhicule retrouvé"
    local descText = "**" .. citizenName .. "** a signalé son véhicule **" .. plate .. "** comme " .. (status and "volé" or "retrouvé")
    
    local fields = {}
    if description and description ~= "" then
        table.insert(fields, {name = "Description", value = description, inline = false})
    end
    
    local embed = FormatEmbed(
        title,
        descText,
        status and 15158332 or 3066993, -- Rouge si volé, vert si retrouvé
        fields
    )
    
    -- Envoi vers le webhook des plaintes pour les véhicules volés (important!)
    SendToDiscord(webhooks.plaintes, "Police Nationale - Véhicules", nil, {embed})
end

-- Exporter les fonctions pour les utiliser dans d'autres fichiers
exports('SendToDiscord', SendToDiscord)
exports('FormatEmbed', FormatEmbed)
exports('NotifyDutyChange', NotifyDutyChange)
exports('NotifyFine', NotifyFine)
exports('NotifySearch', NotifySearch)
exports('NotifyCriminalRecord', NotifyCriminalRecord)
exports('NotifyComplaint', NotifyComplaint)
exports('NotifyAppointment', NotifyAppointment)
exports('NotifyStolenVehicle', NotifyStolenVehicle)