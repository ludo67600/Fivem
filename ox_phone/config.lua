Config = {}

-- Configuration générale
Config.PhoneItemName = 'phone' -- Nom de l'item téléphone dans l'inventaire
Config.DefaultBackground = 'background1' -- Fond d'écran par défaut
Config.DefaultRingtone = 'ringtone1' -- Sonnerie par défaut
Config.OpenKey = 'F1' -- Touche pour ouvrir le téléphone (par défaut M)

Config.EmergencyNumbers = {}  -- Table vide pour éviter les erreurs

-- Configuration du Centre d'appel d'urgence
Config.EmergencyCenter = {
    -- Liste des services disponibles
    Services = {
        {
            label = "Police Secours", 
            number = "17", 
            icon = "images/icons/police.png",
            description = "Appeler les forces de l'ordre pour signaler un crime"
        },
        {
            label = "Samu", 
            number = "15", 
            icon = "images/icons/ambulance.png",
            description = "Appeler les services médicaux en cas d'urgence"
			
        },
        {
            label = "Auto Ecole ECF", 
            number = "0719378", 
            icon = "images/icons/ecf.png",
            description = "Appeler L'auto ecole ECF"

        }
    }
}

-- Configuration pour l'application Agent
Config.AgentApp = {
    -- Liste des métiers autorisés à utiliser l'application
    AuthorizedJobs = {
        ["police"] = {
            label = "Police Nationale",
            servicePhone = "17",
            icon = "images/icons/policenat.png",
            notificationImage = "images/icons/police.png",
            messages = {
                onDuty = "En service et prête à intervenir.",
                onBreak = "En pause mais reste disponible pour les urgences.",
                offDuty = "Actuellement hors service."
            },
            -- Priorité plus basse = plus importante
            priority = 1
        },
        ["pm"] = {
            label = "Police Municipale",
            servicePhone = "17", 
            icon = "images/icons/policemu.png",
            notificationImage = "images/icons/police.png",
            messages = {
                onDuty = "En service et prête à intervenir.",
                onBreak = "En pause mais reste disponible pour les urgences.",
                offDuty = "Actuellement hors service."
            },
            priority = 2
        },
        ["gendarmerie"] = {
            label = "Gendarmerie Nationale",
            servicePhone = "17", 
            icon = "images/icons/gendarmerie.png",
            notificationImage = "images/icons/police.png",
            messages = {
                onDuty = "En service et prête à intervenir.",
                onBreak = "En pause mais reste disponible pour les urgences.",
                offDuty = "Actuellement hors service."
            },
            priority = 3
        },
        ["ambulance"] = {
            label = "SAMU",
            servicePhone = "15",
            icon = "images/icons/samu.png",
            notificationImage = "images/icons/ambulance.png",
            messages = {
                onDuty = "Le SAMU est en service et prêt à intervenir.",
                onBreak = "Le SAMU est en pause mais reste disponible pour les urgences.",
                offDuty = "Le SAMU est actuellement hors service."
            },
            priority = 1
        },
        ["driving"] = {
            label = "ECF",
            servicePhone = "0719378",
            icon = "images/icons/ecf.png",
            notificationImage = "images/icons/ecf.png",
            messages = {
                onDuty = "L'auto ecole ECF est en service.",
                onBreak = "L'auto ecole ECF est en pause.",
                offDuty = "L'auto ecole ECF est actuellement hors service."
            },
            priority = 1
        }
    },
    
    -- Délais avant redirection automatique des appels (en secondes)
    RedirectDelay = 30,
    
    -- Temps minimum entre deux notifications publiques (en secondes)
    NotificationCooldown = 60
}


-- Configuration des applications
Config.Apps = {
    {
        name = 'alarm',
        label = 'Alarme',
        icon = 'images/icons/alarm.png',
        default = true
    },
    {
        name = 'agent',
        label = 'Agent',
        icon = 'images/icons/agent.png',
        default = false 
    },
    {
	
        name = 'emergency_center',
        label = 'Centre d\'appel',
        icon = 'images/icons/emergency_center.png',
        default = true
    },
    {
        name = 'garage',
        label = 'Garage',
        icon = 'images/icons/garage.png',
        default = true
    },
    {        
        name = 'contacts',
        label = 'Contacts',
        icon = 'images/icons/contacts.png', 
        default = true
    },
    {
        name = 'messages',
        label = 'Messages',
        icon = 'images/icons/messages.png',
        default = true
    },
    {
        name = 'calls',
        label = 'Téléphone',
        icon = 'images/icons/calls.png',
        default = true
    },
    {
        name = 'camera',
        label = 'Appareil photo',
        icon = 'images/icons/camera.png',
        default = true
    },
    {
        name = 'bank',
        label = 'Banque',
        icon = 'images/icons/bank.png',
        default = true
    },
    {
        name = 'twitter',
        label = 'Twitter',
        icon = 'images/icons/twitter.png',
        default = true
    },
    {
        name = 'ads',
        label = 'Annonces',
        icon = 'images/icons/ads.png',
        default = true
    },
    {
        name = 'youtube',
        label = 'YouTube',
        icon = 'images/icons/youtube.png',
        default = true
    },
    {
        name = 'settings',
        label = 'Paramètres',
        icon = 'images/icons/settings.png',
        default = true
    }
}

-- Configuration YouTube
Config.YouTube = {
    apiKey = '*********',
    maxResults = 15,  -- Nombre maximal de résultats par recherche
    maxHistory = 20   -- Nombre maximal d'historiques par joueur
}

-- Configuration des emplacements de garage
Config.GarageLocations = {
    ["VespucciBoulevard"] = vector3(-285.2, -886.5, 31.0),
    ["SanAndreasAvenue"] = vector3(216.4, -786.6, 30.8)
}

-- Configuration des emplacements de fourrière
Config.PoundLocations = {
    ["LosSantos"] = vector3(400.7, -1630.5, 29.3),
    ["PaletoBay"] = vector3(-211.4, 6206.5, 31.4),
    ["SandyShores"] = vector3(1728.2, 3709.3, 33.2)
}

-- Configuration de la base de données
Config.DatabaseTables = {
    phone_contacts = "phone_contacts",
    phone_messages = "phone_messages",
    phone_calls = "phone_calls",
    phone_tweets = "phone_tweets",
    phone_tweet_comments = "phone_tweet_comments",
    phone_ads = "phone_ads",
    phone_settings = "phone_settings",
    phone_gallery = "phone_gallery",
    phone_youtube_history = "phone_youtube_history",
    phone_alarms = "phone_alarms",
	phone_service_phones = "phone_service_phones"
}