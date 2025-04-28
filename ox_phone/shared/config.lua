Config = {}

-- Configuration générale
Config.PhoneItemName = 'phone' -- Nom de l'item téléphone dans l'inventaire
Config.DefaultBackground = 'background1' -- Fond d'écran par défaut
Config.DefaultRingtone = 'ringtone1' -- Sonnerie par défaut
Config.OpenKey = 'F1' -- Touche pour ouvrir le téléphone (par défaut M)

-- Configuration des applications
Config.Apps = {
    {
        name = 'contacts',
        label = 'Contacts',
        icon = 'fas fa-address-book',
        default = true
    },
    {
        name = 'messages',
        label = 'Messages',
        icon = 'fas fa-comment',
        default = true
    },
    {
        name = 'calls',
        label = 'Téléphone',
        icon = 'fas fa-phone',
        default = true
    },
    {
        name = 'camera',
        label = 'Appareil photo',
        icon = 'fas fa-camera',
        default = true
    },
    {
        name = 'bank',
        label = 'Banque',
        icon = 'fas fa-university',
        default = true
    },
    {
        name = 'twitter',
        label = 'Twitter',
        icon = 'fab fa-twitter',
        default = true
    },
    {
        name = 'ads',
        label = 'Annonces',
        icon = 'fas fa-ad',
        default = true
    },
    {
        name = 'settings',
        label = 'Paramètres',
        icon = 'fas fa-cog',
        default = true
    }
}

-- Métiers qui peuvent avoir accès à des applications spéciales
Config.JobApps = {
    police = {
        {
            name = 'mdt',
            label = 'MDT',
            icon = 'fas fa-database',
            job = 'police',
            grade = 0 -- Grade minimum
        }
    },
    ambulance = {
        {
            name = 'emergency',
            label = 'Urgences',
            icon = 'fas fa-ambulance',
            job = 'ambulance',
            grade = 0
        }
    },
    mechanic = {
        {
            name = 'mechanic',
            label = 'Mécano',
            icon = 'fas fa-wrench',
            job = 'mechanic',
            grade = 0
        }
    }
}

-- Numéros d'urgence et services
Config.EmergencyNumbers = {
    police = {
        number = '911',
        name = 'Police'
    },
    ambulance = {
        number = '112',
        name = 'Ambulance'
    },
    mechanic = {
        number = '907',
        name = 'Mécano'
    }
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
    phone_gallery = "phone_gallery"
}