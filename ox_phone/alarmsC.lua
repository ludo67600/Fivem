-- ox_phone/client/alarms.lua
local activeAlarms = {}
local alarmSounds = {}
local snoozeTimers = {}

-- Son d'alarme en cours
local currentAlarmSound = nil

-- ==========================================
-- FONCTIONS UTILITAIRES
-- ==========================================

-- Obtenir l'heure et le jour actuel sans utiliser os.date
local function GetCurrentTime()
    -- Obtenir les données de temps depuis NetworkGetServerTime
    local year, month, day, hour, minute, second = GetLocalTime()
    
    -- Calculer le jour de la semaine (algorithme de Zeller modifié)
    -- 0 = dimanche, 1 = lundi, ..., 6 = samedi
    local dayOfWeek
    if month < 3 then
        month = month + 12
        year = year - 1
    end
    local century = math.floor(year / 100)
    year = year % 100
    dayOfWeek = (day + math.floor((month + 1) * 26 / 10) + year + math.floor(year / 4) + math.floor(century / 4) + 5 * century) % 7
    
    -- Correction du décalage d'un jour
    -- Si le jour est dimanche (0), le laisser tel quel, sinon soustraire 1
    dayOfWeek = (dayOfWeek == 0) and 0 or dayOfWeek - 1
    
    return {
        hour = hour,
        minute = minute,
        dayOfWeek = dayOfWeek
    }
end

-- Fonction d'initialisation pour les objets Timeout
local TimeoutList = {}

function setTimeout(cb, delay)
    local timeoutId = #TimeoutList + 1
    TimeoutList[timeoutId] = {
        callback = cb,
        endTime = GetGameTimer() + delay
    }
    return timeoutId
end

function clearTimeout(timeoutId)
    if TimeoutList[timeoutId] then
        TimeoutList[timeoutId] = nil
    end
end

-- ==========================================
-- GESTION DES ALARMES
-- ==========================================

-- Initialiser les alarmes au démarrage
function InitializeAlarms()
    ESX.TriggerServerCallback('ox_phone:getAlarms', function(alarms)
        for _, alarm in ipairs(alarms) do
            if alarm.enabled then
                RegisterAlarm(alarm)
            end
        end
    end)
end

-- Enregistrer une alarme
function RegisterAlarm(alarm)
    -- Désinscrire d'abord si déjà présente
    UnregisterAlarm(alarm.id)
    
    -- Vérifier si l'alarme est activée
    if not alarm.enabled then
        return
    end
    
    -- Parser les jours (format JSON: ["Monday","Tuesday"])
    local days = json.decode(alarm.days)
    if not days or #days == 0 then
        -- Par défaut, tous les jours
        days = {"Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"}
    end
    
    -- Parser l'heure (format: "HH:MM")
    local hours, minutes = alarm.time:match("(%d+):(%d+)")
    hours = tonumber(hours)
    minutes = tonumber(minutes)
    
    if not hours or not minutes then
        return
    end
    
    -- Créer une entrée pour cette alarme
    activeAlarms[alarm.id] = {
        id = alarm.id,
        label = alarm.label,
        time = alarm.time,
        days = days,
        sound = alarm.sound,
        repeat_weekly = alarm.repeat_weekly,
        nextTrigger = 0, -- Sera calculé ci-dessous
        hours = hours,
        minutes = minutes
    }
    
    -- Calculer la prochaine occurrence de l'alarme
    CalculateNextAlarmTrigger(alarm.id)
end

-- Calculer la prochaine occurrence d'une alarme
function CalculateNextAlarmTrigger(alarmId)
    local alarm = activeAlarms[alarmId]
    if not alarm then return end
    
    -- Obtenir la date et l'heure actuelles
    local currentTime = GetCurrentTime()
    local currentHour = currentTime.hour
    local currentMinute = currentTime.minute
    local currentDayOfWeek = currentTime.dayOfWeek
    
    -- Table de correspondance des jours - IMPORTANT: doit correspondre exactement aux valeurs retournées par GetCurrentTime
    local dayNameToIndex = {
        ["Sunday"] = 0,
        ["Monday"] = 1,
        ["Tuesday"] = 2,
        ["Wednesday"] = 3,
        ["Thursday"] = 4,
        ["Friday"] = 5,
        ["Saturday"] = 6
    }
    
    -- Correspondance inversée pour le débogage
    local indexToDayName = {
        [0] = "Sunday",
        [1] = "Monday",
        [2] = "Tuesday",
        [3] = "Wednesday",
        [4] = "Thursday",
        [5] = "Friday",
        [6] = "Saturday"
    }
    
    -- Si le jour actuel est 5 mais que le système attend 4 pour jeudi, ajuster la valeur
    -- Cette correction ajuste le jour actuel pour correspondre à notre table de correspondance
    if currentDayOfWeek == 5 and indexToDayName[4] == "Thursday" then 
        currentDayOfWeek = 4
    end
    
    -- Convertir les noms de jours en indices
    local dayIndexes = {}
    
    for _, dayName in ipairs(alarm.days) do
        local dayIndex = dayNameToIndex[dayName]
        if dayIndex ~= nil then
            table.insert(dayIndexes, dayIndex)
        end
    end
    
    -- Si aucun jour n'est activé, désactiver l'alarme
    if #dayIndexes == 0 then
        activeAlarms[alarmId] = nil
        return
    end
    
    -- Vérifier si l'alarme peut se déclencher aujourd'hui
    local canTriggerToday = false
    
    -- Si nous sommes l'un des jours autorisés et que l'heure n'est pas encore passée
    for _, dayIdx in ipairs(dayIndexes) do
        if dayIdx == currentDayOfWeek then
            if alarm.hours > currentHour or 
              (alarm.hours == currentHour and alarm.minutes > currentMinute) then
                canTriggerToday = true
                break
            end
        end
    end
    
    local gameTime = GetGameTimer()
    local secondsInDay = 24 * 60 * 60
    
    if canTriggerToday then
        -- L'alarme se déclenchera plus tard aujourd'hui
        local secondsTillTrigger = ((alarm.hours - currentHour) * 60 + (alarm.minutes - currentMinute)) * 60
        alarm.nextTrigger = gameTime + secondsTillTrigger * 1000 -- Convertir en millisecondes
    else
        -- Trouver le prochain jour où l'alarme doit se déclencher
        local daysToWait = 7 -- Maximum 7 jours
        local nextDay = nil
        
        for _, dayIdx in ipairs(dayIndexes) do
            -- Calculer combien de jours jusqu'au prochain jour correspondant
            local daysFromNow = (dayIdx - currentDayOfWeek + 7) % 7
            
            -- Si c'est aujourd'hui mais l'heure est déjà passée, considérer la semaine prochaine
            if daysFromNow == 0 then 
                daysFromNow = 7
            end
            
            if daysFromNow < daysToWait then
                daysToWait = daysFromNow
                nextDay = indexToDayName[dayIdx]
            end
        end
        
        -- Calculer le temps jusqu'au prochain déclenchement
        local secondsTillMidnight = ((24 - currentHour) * 60 - currentMinute) * 60
        local secondsTillTrigger = (daysToWait - 1) * secondsInDay + 
                                 secondsTillMidnight + 
                                 alarm.hours * 3600 + 
                                 alarm.minutes * 60
        
        alarm.nextTrigger = gameTime + secondsTillTrigger * 1000 -- Convertir en millisecondes
    end
end

-- Désinscrire une alarme
function UnregisterAlarm(alarmId)
    if activeAlarms[alarmId] then
        activeAlarms[alarmId] = nil
    end
    
    -- Annuler également les répétitions
    if snoozeTimers[alarmId] then
        if snoozeTimers[alarmId].timeoutId then
            clearTimeout(snoozeTimers[alarmId].timeoutId)
        end
        snoozeTimers[alarmId] = nil
    end
end

-- Vérifier les alarmes à déclencher
function CheckAlarms()
    local gameTime = GetGameTimer()
    
    for id, alarm in pairs(activeAlarms) do
        if alarm.nextTrigger and gameTime >= alarm.nextTrigger then
            -- Déclencher l'alarme
            TriggerAlarm(id)
            
            -- Calculer la prochaine occurrence si répétition hebdomadaire
            if alarm.repeat_weekly then
                CalculateNextAlarmTrigger(id)
            else
                -- Sinon, désactiver l'alarme
                UnregisterAlarm(id)
                
                -- Mettre à jour la base de données
                ESX.TriggerServerCallback('ox_phone:updateAlarm', function() end, {
                    id = id,
                    label = alarm.label,
                    time = alarm.time,
                    days = json.encode(alarm.days),
                    sound = alarm.sound,
                    repeat_weekly = false,
                    enabled = false
                })
            end
        end
    end
end

-- ==========================================
-- ACTIONS DES ALARMES
-- ==========================================

-- Déclencher une alarme
function TriggerAlarm(alarmId)
    local alarm = activeAlarms[alarmId]
    if not alarm then return end
    
    -- Jouer le son d'alarme
    PlayAlarmSound(alarm.sound)
    
    -- Ouvrir le téléphone si fermé
    if not phoneOpen then
        OpenPhone()
    end
    
    -- Afficher la notification d'alarme
    SendNUIMessage({
        action = 'showAlarmNotification',
        alarm = {
            id = alarm.id,
            label = alarm.label,
            time = alarm.time
        }
    })
end

-- Jouer le son d'alarme
function PlayAlarmSound(sound)
    StopAlarmSound() -- Arrêter l'alarme en cours
    
    sound = sound or 'alarm1'
    currentAlarmSound = sound
    
    -- Envoyer uniquement un événement NUI pour jouer le son via JavaScript
    SendNUIMessage({
        action = 'playAlarmSound',
        sound = sound
    })
    
    -- Notification visuelle pour accompagner le son
    if activeAlarms[alarmId] then
ShowPhoneNotification('ALARME!', 'Votre alarme "' .. activeAlarms[alarmId].label .. '" sonne!', 'error', 'fa-bell', 10000)
    else
ShowPhoneNotification('ALARME!', 'Votre alarme sonne!', 'error', 'fa-bell', 10000)
    end
end

-- Arrêter le son d'alarme
function StopAlarmSound()
    currentAlarmSound = nil
    
    -- Notification NUI pour arrêter le son
    SendNUIMessage({
        action = 'stopAlarmSound'
    })
    
    -- Arrêter aussi les sons natifs par précaution
    StopSound(-1, "Ringtone_Default", "Phone_SoundSet_Default")
    StopSound(-1, "Ringtone_Michael", "Phone_SoundSet_Michael")
    StopSound(-1, "Ringtone_Franklin", "Phone_SoundSet_Franklin")
    StopSound(-1, "Ringtone_Trevor", "Phone_SoundSet_Trevor")
end

-- Répéter l'alarme après X minutes
function SnoozeAlarm(alarmId, minutes)
    local alarm = activeAlarms[alarmId]
    if not alarm then return end
    
    -- Arrêter le son
    StopAlarmSound()
    
    -- Annuler un timer existant
    if snoozeTimers[alarmId] and snoozeTimers[alarmId].timeoutId then
        clearTimeout(snoozeTimers[alarmId].timeoutId)
    end
    
    -- Programmez la répétition
    local timeoutId = setTimeout(function()
        TriggerAlarm(alarmId)
        if snoozeTimers[alarmId] then
            snoozeTimers[alarmId] = nil -- Nettoyer après déclenchement
        end
    end, minutes * 60000) -- Convertir minutes en millisecondes
    
    snoozeTimers[alarmId] = {
        timeoutId = timeoutId,
        triggerTime = GetGameTimer() + minutes * 60000
    }
    
ShowPhoneNotification('Alarme', 'L\'alarme sonnera à nouveau dans ' .. minutes .. ' minutes', 'info', 'fa-bell')
end

-- Mettre à jour une alarme locale
function UpdateLocalAlarm(data)
    if activeAlarms[data.id] then
        -- Si l'alarme est désactivée, la désinscrire
        if not data.enabled then
            UnregisterAlarm(data.id)
            return
        end
        
        -- Mettre à jour les données
        activeAlarms[data.id] = {
            id = data.id,
            label = data.label,
            time = data.time,
            days = json.decode(data.days),
            sound = data.sound,
            repeat_weekly = data.repeat_weekly,
            nextTrigger = nil
        }
        
        -- Parser l'heure (format: "HH:MM")
        local hours, minutes = data.time:match("(%d+):(%d+)")
        activeAlarms[data.id].hours = tonumber(hours)
        activeAlarms[data.id].minutes = tonumber(minutes)
        
        -- Recalculer la prochaine occurrence
        CalculateNextAlarmTrigger(data.id)
    elseif data.enabled then
        -- Si l'alarme n'est pas active mais a été activée
        RegisterAlarm(data)
    end
end

-- ==========================================
-- THREADS ET ÉVÉNEMENTS
-- ==========================================

-- Thread pour vérifier les timeouts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes
        
        local currentTime = GetGameTimer()
        for id, timeout in pairs(TimeoutList) do
            if timeout.endTime <= currentTime then
                local cb = timeout.callback
                TimeoutList[id] = nil
                cb()
            end
        end
    end
end)

-- Thread principal pour vérifier les alarmes
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Vérifier toutes les 10 secondes
        CheckAlarms()
    end
end)

-- Initialiser les alarmes au démarrage du script
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Attendre un peu pour s'assurer que la connexion à ESX est établie
        Citizen.Wait(2000)
        InitializeAlarms()
    end
end)