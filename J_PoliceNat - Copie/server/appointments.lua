-- J_PoliceNat\server\appointments.lua"
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales et configuration
-- =============================================
-- Table pour stocker les rendez-vous actifs
local activeAppointments = {}

-- =============================================
-- Fonctions utilitaires pour gestion des dates
-- =============================================

-- Fonction pour convertir du format JJ/MM/AAAA au format AAAA-MM-JJ
local function convertToMySQLDate(dateStr)
    if not dateStr then return nil end
    
    -- Vérification du format JJ/MM/AAAA
    local day, month, year = dateStr:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    
    if not day or not month or not year then
        return nil
    end
    
    -- Convertir au format MySQL (AAAA-MM-JJ)
    return year .. '-' .. month .. '-' .. day
end

-- Fonction pour convertir du format AAAA-MM-JJ au format JJ/MM/AAAA
local function convertToDisplayDate(dateStr)
    if not dateStr or not dateStr:match("%d%d%d%d%-%d%d%-%d%d") then
        return dateStr
    end
    local year, month, day = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    return day .. '/' .. month .. '/' .. year
end

-- =============================================
-- Initialisation des rendez-vous
-- =============================================

-- Chargement initial des rendez-vous
CreateThread(function()
    MySQL.query('SELECT * FROM police_appointments WHERE status != "Terminé" AND date >= CURDATE()', {}, function(results)
        if results then
            for _, appointment in ipairs(results) do
                appointment.date = convertToDisplayDate(appointment.date)
                activeAppointments[appointment.id] = appointment
            end
        end
    end)
end)

-- =============================================
-- Gestion des rendez-vous côté citoyens
-- =============================================

-- Demande de rendez-vous
RegisterServerEvent('police:requestAppointment')
AddEventHandler('police:requestAppointment', function(appointmentData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    -- Conversion du format de date pour MySQL
    local mysqlDate = convertToMySQLDate(appointmentData.date)
    if not mysqlDate then
        exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Format de date invalide. Utilisez JJ/MM/AAAA',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})

        return
    end

    -- Vérification si le créneau est disponible
    MySQL.query('SELECT COUNT(*) as count FROM police_appointments WHERE date = ? AND time = ? AND status != "Annulé"', {
        mysqlDate,
        appointmentData.time
    }, function(result)
        if result[1].count > 0 then
            -- MODIFICATION: Notification immédiate si le créneau est déjà pris
            exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'error',
    message = 'Ce créneau est déjà pris. Veuillez choisir un autre horaire.',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})

            return
        end

        -- Insertion du rendez-vous
        MySQL.insert('INSERT INTO police_appointments (citizen_identifier, subject, description, date, time, status, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())', {
            xPlayer.identifier,
            appointmentData.subject,
            appointmentData.description,
            mysqlDate,
            appointmentData.time,
            'En attente'
        }, function(id)
            if id then
                appointmentData.id = id
                appointmentData.date = mysqlDate
                activeAppointments[id] = appointmentData

                -- Notification au joueur
                exports['jl_notifications']:SendNotificationToPlayer(source, {
    type = 'success',
    message = 'Votre demande de rendez-vous a été enregistrée',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})


                -- Notification Discord
local xPlayer = ESX.GetPlayerFromId(source)
MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
    local playerName = GetPlayerName(source)  -- Par défaut, utiliser le nom Steam/Discord
    if result and result[1] then
        playerName = result[1].firstname .. " " .. result[1].lastname  -- Utiliser le nom du personnage
    end
    
    exports['J_PoliceNat']:NotifyAppointment(
        "Nouveau",
        playerName,  -- Nom du personnage in-game
        "Non assigné",
        appointmentData.subject,
        convertToDisplayDate(mysqlDate),
        appointmentData.time,
        "En attente"
    )
end)

                -- Notification aux policiers en service
                NotifyOnDutyPolice('Nouveau rendez-vous', 'Un nouveau rendez-vous a été demandé')
            end
        end)
    end)
end)

-- Récupération des rendez-vous d'un citoyen
RegisterServerEvent('police:getMyAppointments')
AddEventHandler('police:getMyAppointments', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    -- Version modifiée qui récupère tous les rendez-vous sans filtre de date
    MySQL.query('SELECT a.*, CONCAT(u.firstname, " ", u.lastname) as officer_name FROM police_appointments a LEFT JOIN users u ON a.officer_identifier = u.identifier WHERE a.citizen_identifier = ? ORDER BY a.date, a.time', {
        xPlayer.identifier
    }, function(appointments)
        if appointments then
            for i=1, #appointments do
                appointments[i].date = convertToDisplayDate(appointments[i].date)
            end
        end
        TriggerClientEvent('police:showMyAppointments', source, appointments or {})
    end)
end)

-- =============================================
-- Gestion des rendez-vous côté agents
-- =============================================

-- Récupération des rendez-vous pour un officier
RegisterServerEvent('police:getOfficerAppointments')
AddEventHandler('police:getOfficerAppointments', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) then return end

    -- Modification pour montrer tous les rendez-vous sans le filtre de date
    MySQL.query('SELECT a.*, CONCAT(u.firstname, " ", u.lastname) as citizen_name FROM police_appointments a LEFT JOIN users u ON a.citizen_identifier = u.identifier WHERE (a.officer_identifier = ? OR a.status = "En attente") ORDER BY a.date, a.time', {
        xPlayer.identifier
    }, function(appointments)
        if appointments then
            for i=1, #appointments do
                appointments[i].date = convertToDisplayDate(appointments[i].date)
            end
        end
        TriggerClientEvent('police:showOfficerAppointments', source, appointments or {})
    end)
end)

-- Acceptation d'un rendez-vous
RegisterServerEvent('police:acceptAppointment')
AddEventHandler('police:acceptAppointment', function(appointmentId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) then return end

    MySQL.query('SELECT * FROM police_appointments WHERE id = ?', {
        appointmentId
    }, function(appointments)
        if not appointments[1] then return end
        
        local appointment = appointments[1]
        
        -- Mise à jour du rendez-vous
        MySQL.update('UPDATE police_appointments SET status = ?, officer_identifier = ? WHERE id = ?', {
            'Accepté',
            xPlayer.identifier,
            appointmentId
        })

        -- Notification au citoyen
        local xTarget = ESX.GetPlayerFromIdentifier(appointment.citizen_identifier)
        if xTarget then
            exports['jl_notifications']:SendNotificationToPlayer(xTarget.source, {
    type = 'success',
    message = 'Votre rendez-vous a été accepté',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})

        end

        -- Notification Discord
        MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {appointment.citizen_identifier}, function(result)
    local citizenName = "Inconnu"
    if result and result[1] then
        citizenName = result[1].firstname .. " " .. result[1].lastname
    end
    
    exports['J_PoliceNat']:NotifyAppointment(
        "Accepté",
        citizenName,
        xPlayer.getName(),
        appointment.subject,
        convertToDisplayDate(appointment.date),
        appointment.time,
        "Accepté"
    )
end)

    end)
end)

-- Annulation d'un rendez-vous
RegisterServerEvent('police:cancelAppointment')
AddEventHandler('police:cancelAppointment', function(appointmentId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end

    MySQL.query('SELECT * FROM police_appointments WHERE id = ? AND (citizen_identifier = ? OR (? AND officer_identifier = ?))', {
        appointmentId,
        xPlayer.identifier,
        IsPolice(source),
        xPlayer.identifier
    }, function(appointments)
        if not appointments[1] then return end
        
        local appointment = appointments[1]
        
        -- Mise à jour du rendez-vous
        MySQL.update('UPDATE police_appointments SET status = ? WHERE id = ?', {
            'Annulé',
            appointmentId
        })

        -- Notification à l'autre partie
        local targetIdentifier = IsPolice(source) and appointment.citizen_identifier or appointment.officer_identifier
        if targetIdentifier then
            local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if xTarget then
                exports['jl_notifications']:SendNotificationToPlayer(xTarget.source, {
    type = 'warning',
    message = 'Un rendez-vous a été annulé',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})

            end
        end

        -- Notification Discord
        MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {appointment.citizen_identifier}, function(result)
    local citizenName = "Inconnu"
    if result and result[1] then
        citizenName = result[1].firstname .. " " .. result[1].lastname
    end
    
    local officerName = "Non assigné"
    if appointment.officer_identifier then
        if IsPolice(source) then
            officerName = xPlayer.getName()
        else
            MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {appointment.officer_identifier}, function(officerResult)
                if officerResult and officerResult[1] then
                    officerName = officerResult[1].firstname .. " " .. officerResult[1].lastname
                end
            end)
        end
    end
    
    exports['J_PoliceNat']:NotifyAppointment(
        "Annulé",
        citizenName,
        officerName,
        appointment.subject,
        convertToDisplayDate(appointment.date),
        appointment.time,
        "Annulé"
    )
end)

    end)
end)

-- Marquer un rendez-vous comme terminé
RegisterServerEvent('police:finishAppointment')
AddEventHandler('police:finishAppointment', function(appointmentId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) then return end

    MySQL.update('UPDATE police_appointments SET status = ? WHERE id = ? AND officer_identifier = ?', {
        'Terminé',
        appointmentId,
        xPlayer.identifier
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Notification Discord
            MySQL.query('SELECT * FROM police_appointments WHERE id = ?', {appointmentId}, function(result)
    if result and result[1] then
        local appointment = result[1]
        
        MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {appointment.citizen_identifier}, function(citizenResult)
            local citizenName = "Inconnu"
            if citizenResult and citizenResult[1] then
                citizenName = citizenResult[1].firstname .. " " .. citizenResult[1].lastname
            end
            
            exports['J_PoliceNat']:NotifyAppointment(
                "Terminé",
                citizenName,
                xPlayer.getName(),
                appointment.subject,
                convertToDisplayDate(appointment.date),
                appointment.time,
                "Terminé"
            )
        end)
    end
end)

            
            -- Notification au citoyen si en ligne
            MySQL.query('SELECT citizen_identifier FROM police_appointments WHERE id = ?', {
                appointmentId
            }, function(result)
                if result[1] then
                    local xTarget = ESX.GetPlayerFromIdentifier(result[1].citizen_identifier)
                    if xTarget then
                        exports['jl_notifications']:SendNotificationToPlayer(xTarget.source, {
    type = 'success',
    message = 'Votre rendez-vous a été marqué comme terminé',
    title = 'Rendez-vous',
    image = 'img/policenat.png',
    duration = 5000
})

                    end
                end
            end)
        end
    end)
end)

-- =============================================
-- Tâches périodiques
-- =============================================

-- Nettoyage périodique des anciens rendez-vous
CreateThread(function()
    while true do
        Wait(3600000) -- Toutes les heures
        MySQL.update('UPDATE police_appointments SET status = "Terminé" WHERE date < CURDATE() AND status != "Terminé"')
    end
end)

-- =============================================
-- Exports
-- =============================================

-- Export des fonctions utiles
exports('GetActiveAppointments', function()
    return activeAppointments
end)