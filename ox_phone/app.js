// =================================================================
// VARIABLES GLOBALES
// =================================================================
// Informations utilisateur
let phoneNumber = null;
let playerIdentifier = null;

// États du téléphone
let phoneOpen = false;
let isLocked = true;
let previousScreen = 'home-screen';
let activeScreen = 'home-screen';

// Paramètres du téléphone
let currentWallpaper = 'background1';
let currentRingtone = 'ringtone1';
let currentNotificationSound = 'notification1';
let currentTheme = 'default';
let doNotDisturb = false;
let airplaneMode = false;

// Données des applications
let currentContacts = [];
let currentMessages = [];
let currentTweets = [];
let currentAds = [];
let currentGallery = [];
let currentBankData = { balance: 0, transactions: [] };
let currentCallHistory = [];
let currentVehicles = [];
let currentAlarms = [];
let agentAppData = null;

// États des appels
let activeCallId = null;
let activeCallNumber = null;
let callTimer = null;
let callDuration = 0;

// États des médias
let tweetImage = null;
let adImage = null;
let activeYouTubeVideo = null;

// Timers de rafraîchissement
let conversationRefreshInterval = null;
let tweetRefreshInterval = null;
let adsRefreshInterval = null;

// Son en cours
let ringtoneAudio = null;
let notificationAudio = null;
let alarmAudio = null;

// =================================================================
// SYSTÈME DE NOTIFICATION UNIFIÉ
// =================================================================

// Conteneur pour empiler les notifications
let notificationStack = null;
let notificationCounter = 0;
const notificationDuration = 5000; // Durée par défaut en ms

// Système pour éviter les notifications en double
let notificationHistory = [];
const maxHistoryLength = 10;
const notificationDeduplicationDelay = 2000; // 2 secondes

/**
 * Vérifie si une notification similaire a été affichée récemment
 * @param {string} title - Titre de la notification
 * @param {string} message - Contenu de la notification
 * @returns {boolean} - True si c'est un doublon, false sinon
 */
function isDuplicateNotification(title, message) {
    // Créer une signature unique de la notification
    const signature = `${title}:${message}`;
    const currentTime = Date.now();
    
    // Vérifier dans l'historique récent
    for (const item of notificationHistory) {
        if (item.signature === signature && 
            (currentTime - item.timestamp) < notificationDeduplicationDelay) {
            return true;
        }
    }
    
    // Ajouter à l'historique
    notificationHistory.push({
        signature: signature,
        timestamp: currentTime
    });
    
    // Limiter la taille de l'historique
    if (notificationHistory.length > maxHistoryLength) {
        notificationHistory.shift();
    }
    
    return false;
}

/**
 * Crée et affiche une notification
 * @param {string} title - Titre de la notification
 * @param {string} message - Contenu de la notification
 * @param {string} type - Type de notification (info, success, error, warning)
 * @param {string} icon - Icône FontAwesome ou chemin d'image
 * @param {number} duration - Durée d'affichage en ms (optionnel)
 * @param {boolean} isImage - Indique si l'icône est une image (optionnel)
 */
function showPhoneNotification(title, message, type = 'info', icon = 'fa-bell', duration = notificationDuration, isImage = false) {
    // Vérifier si c'est un doublon récent
    if (isDuplicateNotification(title, message)) {
        return null;
    }
    if (!notificationStack) {
        notificationStack = document.createElement('div');
        notificationStack.className = 'notification-stack';
        document.body.appendChild(notificationStack);
    }
    // Incrémenter le compteur pour les IDs uniques
    notificationCounter++;
    
    // Créer la notification
    const notification = document.createElement('div');
    notification.className = `phone-notification ${type}`;
    notification.id = `notification-${notificationCounter}`;
    
    // Préparer le contenu de l'icône
    let iconContent = '';
    if (isImage) {
        iconContent = `<img src="${icon}" alt="Icon">`;
    } else {
        iconContent = `<i class="fas ${icon}"></i>`;
    }
    
    // Structure de la notification
    notification.innerHTML = `
        <div class="notification-icon">
            ${iconContent}
        </div>
        <div class="notification-content">
            <div class="notification-title">${title}</div>
            <div class="notification-message">${message}</div>
        </div>
        <button class="notification-close"><i class="fas fa-times"></i></button>
    `;
    
    // Ajouter au stack
    notificationStack.appendChild(notification);
    
    // Animation d'apparition
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    // Configurer le bouton de fermeture
    const closeBtn = notification.querySelector('.notification-close');
    closeBtn.addEventListener('click', () => {
        closeNotification(notification);
    });
    
    // Fermeture automatique après la durée spécifiée
    if (duration > 0) {
        setTimeout(() => {
            closeNotification(notification);
        }, duration);
    }
    
    // Retourner la notification pour référence
    return notification;
}

/**
 * Ferme une notification avec animation
 * @param {HTMLElement} notification - Élément de notification à fermer
 */
function closeNotification(notification) {
    notification.classList.remove('show');
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
            
            // Nettoyer le stack si vide
            if (notificationStack && notificationStack.childElementCount === 0) {
                document.body.removeChild(notificationStack);
                notificationStack = null;
            }
        }
    }, 300);
}

/**
 * Fonction simplifiée pour les anciennes references à showCustomNotification
 * @param {string} title - Titre de la notification
 * @param {string} message - Contenu de la notification
 * @param {string} type - Type de notification (optionnel)
 */
function showCustomNotification(title, message, type = 'info') {
    let icon = 'fa-bell';
    
    // Assigner l'icône selon le type
    switch (type) {
        case 'success':
            icon = 'fa-check-circle';
            break;
        case 'error':
            icon = 'fa-exclamation-circle';
            break;
        case 'warning':
            icon = 'fa-exclamation-triangle';
            break;
        case 'info':
        default:
            icon = 'fa-info-circle';
            break;
    }
    
    return showPhoneNotification(title, message, type, icon);
}

/**
 * Joue un son de notification et montre une notification visuelle
 * @param {string} title - Titre de la notification
 * @param {string} message - Contenu de la notification
 * @param {string} sound - Son de notification à jouer (optionnel)
 */
function showNotificationWithSound(title, message, type = 'info', sound = null) {
    // Jouer le son si spécifié et si les modes silencieux/avion sont désactivés
    if (sound && !doNotDisturb && !airplaneMode) {
        playNotificationSound(sound);
    }
    
    // Afficher la notification
    return showCustomNotification(title, message, type);
}

// =================================================================
// FONCTIONS UTILITAIRES
// =================================================================

/**
 * Ajuste le décalage horaire pour une date
 * @param {string} dateString - La date au format string
 * @return {Date} - La date ajustée
 */
function adjustTimeZone(dateString) {
    const date = new Date(dateString);
    date.setMinutes(date.getMinutes() - 120);
    return date;
}

/**
 * Joue un son d'alarme
 * @param {string} sound - Le nom du son d'alarme à jouer
 */
function playAlarmSound(sound) {
    stopAlarmSound();
    
    let audio = new Audio(`sounds/${sound}.ogg`);
    audio.loop = true;
    audio.volume = 1.0;
    
    audio.play().catch(error => {
        audio = new Audio(`sounds/${sound}.mp3`);
        audio.loop = true;
        audio.volume = 1.0;
        
        audio.play().catch(() => {});
    });
    
    alarmAudio = audio;
}

/**
 * Arrête le son d'alarme en cours
 */
function stopAlarmSound() {
    if (alarmAudio) {
        alarmAudio.pause();
        alarmAudio.currentTime = 0;
        alarmAudio = null;
    }
}

// =================================================================
// INITIALISATION ET CHARGEMENT
// =================================================================

/**
 * Initialisation au chargement du document
 */
document.addEventListener('DOMContentLoaded', function() {
    // Écouter les messages du client
    window.addEventListener('message', handleClientMessage);
    
    // Configurer les écouteurs d'événements
    setupEventListeners();
    
    // Mettre à jour l'heure en temps réel
    updateClock();
    setInterval(updateClock, 1000);
    
    // Ajouter les styles pour les éléments sélectionnés
    addSelectionStyles();
});

/**
 * Ajoute les styles CSS nécessaires dynamiquement
 */
function addSelectionStyles() {
    const style = document.createElement('style');
    style.textContent = `
        .message-bubble.selected {
            position: relative;
            opacity: 0.8;
            border: 2px dashed #777;
        }
        
        .message-bubble.selected::after {
            content: "✓";
            position: absolute;
            top: -8px;
            right: -8px;
            width: 20px;
            height: 20px;
            background-color: var(--primary-color);
            color: white;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 12px;
        }
        
        .call-item.selected {
            background-color: rgba(0, 123, 255, 0.1);
            border: 1px solid #007bff;
            position: relative;
        }
        
        .call-item.selected::after {
            content: "✓";
            position: absolute;
            top: 5px;
            right: 5px;
            width: 20px;
            height: 20px;
            background-color: var(--primary-color);
            color: white;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 12px;
        }
        
        .conversation-item.selected {
            background-color: rgba(0, 123, 255, 0.1);
            border: 1px solid #007bff;
            position: relative;
        }
        
        .conversation-item.selected::after {
            content: "✓";
            position: absolute;
            top: 5px;
            right: 5px;
            width: 20px;
            height: 20px;
            background-color: var(--primary-color);
            color: white;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 12px;
        }
        
        .delete-btn {
            background: none;
            border: none;
            color: #dc3545;
            font-size: 18px;
            cursor: pointer;
            padding: 5px 10px;
            margin-left: 10px;
        }
        
        .delete-btn:hover {
            color: #bd2130;
        }
    `;
    
    document.head.appendChild(style);
}

// =================================================================
// GESTIONNAIRE DE MESSAGES DU CLIENT
// =================================================================

/**
 * Gère les messages envoyés par le client
 * @param {Object} event - L'événement contenant le message
 */
function handleClientMessage(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'openPhone':
            openPhone(data);
            break;
        case 'directShowScreen':
            directShowScreen(data);
            break;
        case 'closePhone':
            closePhone();
            break;
        case 'playNotificationSound':
            handleNotificationSound(data);
            break;
        case 'showSmsNotification':
            showSmsNotification(data);
            break;
        case 'newMessage':
            receiveMessage(data);
            break;
        case 'outgoingCallStarted':
            handleOutgoingCallStarted(data);
            break;
        case 'incomingCall':
            handleIncomingCall(data);
            break;
        case 'callAnswered':
            callAnswered();
            break;
        case 'callRejected':
            callRejected();
            break;
        case 'callEnded':
            callEnded();
            break;
        case 'newTweet':
            receiveTweet(data);
            break;
        case 'newAd':
            receiveAd(data);
            break;
        case 'setPlayerIdentifier':
            playerIdentifier = data.identifier;
            break;
        case 'updateYouTubeStatus':
            handleYouTubeUpdate(data);
            break;
        case 'confirmDeletePhoto':
            showDeleteConfirmation(data.photoId);
            break;
        case 'confirmDeleteAlarm':
            showAlarmDeleteConfirmation(data.alarmId);
            break;
        case 'playRingtone':
            handlePlayRingtone(data);
            break;
        case 'showAlarmNotification':
            showAlarmNotification(data.alarm);
            break;
        case 'playAlarmSound':
            playAlarmSound(data.sound || 'alarm1');
            break;
        case 'stopAlarmSound':
            stopAlarmSound();
            break;
        case 'updateAgentAppIcon':
            updateAgentAppIcon(data.icon);
            break;
        case 'updateAgentAppData':
            updateAgentAppData(data);
            break;
        case 'showAgentPublicNotification':
            showAgentPublicNotification(data.jobLabel, data.message, data.image);
            break;
        case 'hideAgentPublicNotification':
            hideAgentPublicNotification();
            break;
        case 'showPhoneNotification':
             showPhoneNotification(data.title, data.message, data.type, data.icon, data.duration, data.isImage);
             break;
			
    }
}

/**
 * Gère la mise à jour du statut YouTube
 * @param {Object} data - Les données de statut YouTube
 */
function handleYouTubeUpdate(data) {
    if (data.video) {
        activeYouTubeVideo = data.video;
        updateYouTubeNowPlayingStatus();
    }
}

/**
 * Gère la lecture d'un son de notification
 * @param {Object} data - Les données de notification
 */
function handleNotificationSound(data) {
    if (!doNotDisturb && !airplaneMode) {
        if (data.sound) {
            currentNotificationSound = data.sound;
        }
        playNotificationSound();
    }
}

/**
 * Gère la mise à jour des données de l'application Agent
 * @param {Object} data - Les données Agent
 */
function updateAgentAppData(data) {
    agentAppData = data.data;
    if (activeScreen === 'agent-screen') {
        renderAgentScreen();
    }
}

/**
 * Gère la lecture d'une sonnerie
 * @param {Object} data - Les données de sonnerie
 */
function handlePlayRingtone(data) {
    if (!doNotDisturb && !airplaneMode) {
        if (data.ringtone) {
            currentRingtone = data.ringtone;
        }
        playRingtone();
    }
}

/**
 * Gère les informations d'appel sortant
 * @param {Object} data - Les données d'appel
 */
function handleOutgoingCallStarted(data) {
    activeCallId = data.callId;
}

/**
 * Gère les appels entrants
 * @param {Object} data - Les données d'appel
 */
function handleIncomingCall(data) {
    if (!phoneOpen) {
        document.getElementById('phone-container').style.display = 'block';
        phoneOpen = true;
    }
    
    activeCallId = data.callId;
    activeCallNumber = data.caller;
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel entrant';
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = data.callerName || data.caller;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = data.caller;
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.remove('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    showScreen('calling-screen');
    
    if (!doNotDisturb && !airplaneMode) {
        playRingtone();
    }
}

// =================================================================
// FONCTIONS DE GESTION DU TÉLÉPHONE
// =================================================================

/**
 * Ouvre le téléphone avec les données fournies
 * @param {Object} data - Les données pour initialiser le téléphone
 */
function openPhone(data) {
    document.getElementById('phone-container').style.display = 'block';
    phoneOpen = true;
    
    phoneNumber = data.phoneNumber;
    document.getElementById('phone-number').textContent = phoneNumber;
    
    fetchSettings();
    generateAppIcons(data.apps);
    
    if (data.directScreen) {
        document.querySelectorAll('.screen').forEach(screen => {
            screen.classList.remove('active');
            screen.style.display = 'none';
        });
        
        if (data.directScreen === 'calling-screen' && data.callData) {
            handleDirectCallingScreen(data.callData);
        } else {
            showScreen(data.directScreen);
        }
    } else {
        document.querySelectorAll('.screen').forEach(screen => {
            screen.classList.remove('active');
            screen.style.display = 'none';
        });
        
        const lockScreen = document.getElementById('lock-screen');
        if (lockScreen) {
            lockScreen.style.backgroundImage = `url('images/wallpapers/${currentWallpaper}.jpg')`;
            lockScreen.classList.add('active');
            lockScreen.style.display = 'flex';
        }
        
        updateClock();
        
        isLocked = true;
        activeScreen = 'lock-screen';
    }
}

/**
 * Gère l'affichage direct de l'écran d'appel
 * @param {Object} callData - Les données d'appel
 */
function handleDirectCallingScreen(callData) {
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel entrant';
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = callData.callerName || callData.caller;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = callData.caller;
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.remove('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    activeCallId = callData.callId;
    activeCallNumber = callData.caller;
    
    const callingScreen = document.getElementById('calling-screen');
    if (callingScreen) {
        callingScreen.classList.add('active');
        callingScreen.style.display = 'flex';
    }
    
    activeScreen = 'calling-screen';
    isLocked = false;
    
    if (!doNotDisturb && !airplaneMode) {
        playRingtone();
    }
}

/**
 * Gère l'affichage direct d'un écran spécifique
 * @param {Object} data - Les données d'affichage
 */
function directShowScreen(data) {
    if (phoneOpen) {
        document.querySelectorAll('.screen').forEach(screen => {
            screen.classList.remove('active');
            screen.style.display = 'none';
        });
            
        if (data.screen === 'calling-screen' && data.callData) {
            handleDirectCallingScreen(data.callData);
        } else {
            showScreen(data.screen);
        }
    }
}

/**
 * Ferme le téléphone
 */
function closePhone() {
    if (!phoneOpen) {
        return;
    }
    
    phoneOpen = false;
    
    if (conversationRefreshInterval) {
        clearInterval(conversationRefreshInterval);
        conversationRefreshInterval = null;
    }
	
    if (tweetRefreshInterval) {
        clearInterval(tweetRefreshInterval);
        tweetRefreshInterval = null;
    }
    
    if (adsRefreshInterval) {
        clearInterval(adsRefreshInterval);
        adsRefreshInterval = null;
    }
    
    if (activeYouTubeVideo) {
    showPhoneNotification('Vidéo en cours', activeYouTubeVideo.title, 'info', 'fa-youtube', 8000);
    }
    
    document.getElementById('phone-container').style.display = 'none';
    
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    isLocked = true;
    
    stopRingtone();
    stopNotificationSound();
}

/**
 * Déverrouille le téléphone
 */
function unlockPhone() {
    if (!isLocked) return;
    
    const lockScreen = document.getElementById('lock-screen');
    if (!lockScreen) return;
    
    playSound('Unlock', 'Phone_SoundSet_Default');
    
    lockScreen.classList.add('unlocking');
    
    setTimeout(() => {
        isLocked = false;
        
        lockScreen.classList.remove('active');
        lockScreen.classList.remove('unlocking');
        lockScreen.style.display = 'none';
        
        const homeScreen = document.getElementById('home-screen');
        if (homeScreen) {
            homeScreen.classList.add('active');
            homeScreen.style.display = 'flex';
        }
        
        activeScreen = 'home-screen';
    }, 500);
}

/**
 * Verrouille le téléphone
 */
function lockPhone() {
    if (isLocked) return;
    
    previousScreen = activeScreen;
    
    document.querySelectorAll('.screen').forEach(screen => {
        screen.classList.remove('active');
        screen.style.display = 'none';
    });
    
    playSound('Lock', 'Phone_SoundSet_Default');
    
    const lockScreen = document.getElementById('lock-screen');
    if (lockScreen) {
        lockScreen.style.backgroundImage = `url('images/wallpapers/${currentWallpaper}.jpg')`;
        lockScreen.classList.add('active');
        lockScreen.style.display = 'flex';
    }
    
    isLocked = true;
    activeScreen = 'lock-screen';
}

/**
 * Affiche un écran spécifique
 * @param {string} screenId - L'identifiant de l'écran à afficher
 */
function showScreen(screenId) {
    if (isLocked && screenId !== 'lock-screen') {
        screenId = 'lock-screen';
    }
    
    document.querySelectorAll('.screen').forEach(screen => {
        screen.classList.remove('active');
        screen.style.display = 'none';
    });
    
    const newScreen = document.getElementById(screenId);
    if (!newScreen) {
        return;
    }
    
    newScreen.classList.add('active');
    newScreen.style.display = 'flex';
    
    activeScreen = screenId;
    
    // Actions spécifiques à l'écran
    switch (screenId) {
        case 'contacts-screen':
            fetchContacts();
            break;
        case 'messages-screen':
            fetchMessages();
            break;
        case 'call-history-screen':
            fetchCallHistory();
            break;
        case 'twitter-screen':
            fetchTweets();
            if (tweetRefreshInterval) {
                clearInterval(tweetRefreshInterval);
            }
            tweetRefreshInterval = setInterval(refreshTweets, 3000);
            break;
        case 'ads-screen':
            fetchAds();
            if (adsRefreshInterval) {
                clearInterval(adsRefreshInterval);
            }
            adsRefreshInterval = setInterval(refreshAds, 3000);
            break;
        case 'bank-screen':
            fetchBankData();
            break;
        case 'gallery-screen':
            fetchGallery();
            break;
        case 'youtube-screen':
            fetchYouTubeHistory();
            break;
        case 'garage-screen':
            fetchVehicles();
            break;
        case 'alarm-screen':
            fetchAlarms();
            break;
    }
}

/**
 * Génère les icônes des applications
 * @param {Array} apps - Liste des applications
 */
function generateAppIcons(apps) {
    const appGrid = document.getElementById('app-grid');
    if (!appGrid) return;
    
    appGrid.innerHTML = '';
    
    apps.forEach(app => {
        const appIcon = document.createElement('div');
        appIcon.className = 'app-icon';
        appIcon.dataset.app = app.name;
        
        const icon = document.createElement('img');
        icon.src = app.icon;
        icon.alt = app.label;
        
        const label = document.createElement('span');
        label.textContent = app.label;
        
        appIcon.appendChild(icon);
        appIcon.appendChild(label);
        
        appIcon.addEventListener('click', function() {
            openApp(app.name);
        });
        
        appGrid.appendChild(appIcon);
    });
}

/**
 * Met à jour l'icône de l'application Agent
 * @param {string} iconPath - Chemin de la nouvelle icône
 */
function updateAgentAppIcon(iconPath) {
    const appIcon = document.querySelector('.app-icon[data-app="agent"] img');
    if (appIcon) {
        appIcon.src = iconPath;
    }
}

/**
 * Ouvre une application
 * @param {string} appName - Nom de l'application à ouvrir
 */
function openApp(appName) {
    switch (appName) {
        case 'contacts':
            showScreen('contacts-screen');
            break;
        case 'messages':
            showScreen('messages-screen');
            break;
        case 'calls':
            showScreen('phone-app-screen');
            break;
        case 'camera':
            showScreen('camera-screen');
            break;
        case 'bank':
            showScreen('bank-screen');
            break;
        case 'twitter':
            showScreen('twitter-screen');
            break;
        case 'ads':
            showScreen('ads-screen');
            break;
        case 'youtube':
            showScreen('youtube-screen');
            fetchYouTubeHistory();
            break;
        case 'garage':
            showScreen('garage-screen');
            fetchVehicles();
            break;
        case 'alarm':
            showScreen('alarm-screen');
            fetchAlarms();
            break;
        case 'emergency_center':
            showScreen('emergency-center-screen');
            fetchEmergencyServices();
            break;
        case 'settings':
            showScreen('settings-screen');
            break;
        case 'agent':
            handleAgentApp();
            break;
    }
    
    fetch('https://ox_phone/openApp', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            app: appName
        })
    }).catch(() => {});
}

/**
 * Gère l'ouverture de l'application Agent
 */
function handleAgentApp() {
    fetch('https://ox_phone/getAgentAppData', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            agentAppData = data.data;
            showScreen('agent-screen');
            renderAgentScreen();
        } else {
            showPhoneNotification('Agent', data.message, 'error', 'fa-user-tie');
        }
    })
    .catch(() => {});
}

/**
 * Met à jour l'horloge
 */
function updateClock() {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const monthNames = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    const currentTimeElement = document.getElementById('current-time');
    if (currentTimeElement) {
        currentTimeElement.textContent = `${hours}:${minutes}`;
    }
    
    const dateString = `${dayNames[now.getDay()]} ${now.getDate()} ${monthNames[now.getMonth()]}`;
    const homeDateElement = document.getElementById('home-date');
    if (homeDateElement) {
        homeDateElement.textContent = dateString;
    }
    
    const lockTimeElement = document.getElementById('lock-time');
    if (lockTimeElement) {
        lockTimeElement.textContent = `${hours}:${minutes}`;
    }
    
    const lockDateElement = document.getElementById('lock-date');
    if (lockDateElement) {
        lockDateElement.textContent = dateString;
    }
}

// =================================================================
// CONFIGURATION DES ÉCOUTEURS D'ÉVÉNEMENTS
// =================================================================

/**
 * Configure tous les écouteurs d'événements de base
 */
function setupEventListeners() {
    setupBackButtons();
    setupNavigationButtons();
    setupContactsEventListeners();
    setupMessagesEventListeners();
    setupPhoneEventListeners();
    setupTwitterEventListeners();
    setupAdsEventListeners();
    setupSettingsListeners();
    setupPhotoOptionsListeners();
    setupBankListeners();
    setupCameraListeners();
    setupYouTubeListeners();
    setupGarageEventListeners();
    setupAlarmEventListeners();
    setupSimpleDeletionListeners();
}

/**
 * Configure les boutons de retour
 */
function setupBackButtons() {
    document.querySelectorAll('.back-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const parentScreen = this.closest('.screen')?.id;
            if (!parentScreen) return;
            
            if (parentScreen === 'alarm-form-screen') {
                stopAlarmSound();
            }

            handleBackNavigation(parentScreen);
        });
    });
}

/**
 * Gère la navigation de retour selon l'écran parent
 * @param {string} parentScreen - L'écran parent actuel
 */
function handleBackNavigation(parentScreen) {
    switch (parentScreen) {
        case 'contacts-screen':
        case 'messages-screen':
        case 'phone-app-screen':
            showScreen('home-screen');
            break;
        case 'twitter-screen':
            if (tweetRefreshInterval) {
                clearInterval(tweetRefreshInterval);
                tweetRefreshInterval = null;
            }
            showScreen('home-screen');
            break;
        case 'ads-screen':
            if (adsRefreshInterval) {
                clearInterval(adsRefreshInterval);
                adsRefreshInterval = null;
            }
            showScreen('home-screen');
            break;
        case 'bank-screen':
        case 'camera-screen':
        case 'settings-screen':
        case 'youtube-screen':
        case 'garage-screen':
        case 'alarm-screen':
            showScreen('home-screen');
            break;
        case 'conversation-screen':
            if (conversationRefreshInterval) {
                clearInterval(conversationRefreshInterval);
                conversationRefreshInterval = null;
            }
            showScreen('messages-screen');
            break;
        case 'contact-form-screen':
            showScreen('contacts-screen');
            break;
        case 'new-message-screen':
            showScreen('messages-screen');
            break;
        case 'call-history-screen':
            showScreen('phone-app-screen');
            break;
        case 'new-tweet-screen':
            showScreen('twitter-screen');
            tweetImage = null;
            const tweetPhotoPreview = document.getElementById('tweet-photo-preview');
            if (tweetPhotoPreview) {
                tweetPhotoPreview.classList.add('hidden');
            }
            break;
        case 'new-ad-screen':
            showScreen('ads-screen');
            adImage = null;
            const adPhotoPreview = document.getElementById('ad-photo-preview');
            if (adPhotoPreview) {
                adPhotoPreview.classList.add('hidden');
            }
            break;
        case 'transfer-screen':
            showScreen('bank-screen');
            break;
        case 'gallery-screen':
            showScreen('camera-screen');
            break;
        case 'photo-view-screen':
            showScreen('gallery-screen');
            break;
        case 'wallpaper-screen':
        case 'ringtone-screen':
        case 'notification-sound-screen':
            showScreen('settings-screen');
            break;
        case 'youtube-video-screen':
            showScreen('youtube-screen');
            const videoPlayer = document.getElementById('youtube-video-player');
            if (videoPlayer) videoPlayer.src = '';
            break;
        case 'youtube-search-screen':
            showScreen('youtube-screen');
            break;
        case 'vehicle-details-screen':
            showScreen('garage-screen');
            break;
        case 'alarm-form-screen':
            showScreen('alarm-screen');
            break;
    }
}

/**
 * Configure les boutons de navigation
 */
function setupNavigationButtons() {
    const homeBtn = document.getElementById('home-btn');
    if (homeBtn) {
        homeBtn.addEventListener('click', function() {
            if (activeScreen === 'calling-screen' && activeCallId) {
                return;
            }
            
            showScreen('home-screen');
        });
    }
    
    const fingerprintBtn = document.getElementById('fingerprint-btn');
    if (fingerprintBtn) {
        fingerprintBtn.addEventListener('click', function() {
            unlockPhone();
        });
    }
    
    const lockBtn = document.getElementById('lock-btn');
    if (lockBtn) {
        lockBtn.addEventListener('click', function() {
            lockPhone();
        });
    }

    const backBtn = document.getElementById('back-btn');
    if (backBtn) {
        backBtn.addEventListener('click', function() {
            if (activeScreen === 'home-screen' || isLocked) {
                return;
            }
            
            handleBackNavigation(activeScreen);
        });
    }
}

// =================================================================
// GESTION DE LA SUPPRESSION D'ÉLÉMENTS
// =================================================================

/**
 * Configure les écouteurs d'événements pour la suppression simple
 */
function setupSimpleDeletionListeners() {
    let contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu hidden';
    contextMenu.innerHTML = `
        <div class="context-menu-item delete-item">
            <i class="fas fa-trash"></i> Supprimer
        </div>
    `;
    document.body.appendChild(contextMenu);

    document.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        
        contextMenu.classList.add('hidden');
        
        let targetType = '';
        let targetElement = null;
        let targetId = null;
if (e.target.closest('.message-bubble') && activeScreen === 'conversation-screen') {
            targetType = 'message';
            targetElement = e.target.closest('.message-bubble');
            targetId = targetElement.dataset.id;
        } 
        else if (e.target.closest('.conversation-item') && activeScreen === 'messages-screen') {
            targetType = 'conversation';
            targetElement = e.target.closest('.conversation-item');
            const numberElement = targetElement.querySelector('.contact-number, .conversation-preview');
            targetId = numberElement ? numberElement.textContent.trim() : null;
        }
        else if (e.target.closest('.call-item') && activeScreen === 'call-history-screen') {
            targetType = 'call';
            targetElement = e.target.closest('.call-item');
            targetId = targetElement.dataset.id;
        }
        
        if (targetType && targetElement && targetId) {
            contextMenu.style.left = e.pageX + 'px';
            contextMenu.style.top = e.pageY + 'px';
            contextMenu.classList.remove('hidden');
            
            contextMenu.dataset.type = targetType;
            contextMenu.dataset.id = targetId;
            
            e.stopPropagation();
        }
    });
    
    document.querySelector('.delete-item').addEventListener('click', function() {
        const type = contextMenu.dataset.type;
        const id = contextMenu.dataset.id;
        
        if (type && id) {
            showItemDeleteConfirmation(type, id);
        }
        
        contextMenu.classList.add('hidden');
    });
    
    document.addEventListener('click', function() {
        contextMenu.classList.add('hidden');
    });
}

/**
 * Affiche la confirmation de suppression d'un élément
 * @param {string} type - Le type d'élément à supprimer
 * @param {string} id - L'identifiant de l'élément
 */
function showItemDeleteConfirmation(type, id) {
    let title, message;
    
    switch(type) {
        case 'message':
            title = "Supprimer le message";
            message = "Êtes-vous sûr de vouloir supprimer ce message ?";
            break;
        case 'conversation':
            title = "Supprimer la conversation";
            message = "Êtes-vous sûr de vouloir supprimer cette conversation ?";
            break;
        case 'call':
            title = "Supprimer l'appel";
            message = "Êtes-vous sûr de vouloir supprimer cet appel ?";
            break;
        default:
            return;
    }
    
    const confirmBox = document.createElement('div');
    confirmBox.className = 'delete-confirmation';
    confirmBox.innerHTML = `
        <div class="delete-confirmation-content">
            <div class="delete-confirmation-header">${title}</div>
            <div class="delete-confirmation-message">${message}</div>
            <div class="delete-confirmation-actions">
                <button class="delete-confirmation-btn cancel">Annuler</button>
                <button class="delete-confirmation-btn confirm">Supprimer</button>
            </div>
        </div>
    `;
    
    const phoneContainer = document.getElementById('phone-container');
    phoneContainer.appendChild(confirmBox);
    
    const cancelBtn = confirmBox.querySelector('.cancel');
    const confirmBtn = confirmBox.querySelector('.confirm');
    
    cancelBtn.addEventListener('click', function() {
        confirmBox.remove();
    });
    
    confirmBtn.addEventListener('click', function() {
        confirmBox.remove();
        
        if (type === 'message') {
            deleteItemMessage(id);
        } else if (type === 'conversation') {
            deleteItemConversation(id);
        } else if (type === 'call') {
            deleteItemCall(id);
        }
    });
}

/**
 * Supprime un message
 * @param {string} messageId - L'identifiant du message
 */
function deleteItemMessage(messageId) {
    fetch('https://ox_phone/deleteMessage', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            messageId: messageId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            const messageBubble = document.querySelector(`.message-bubble[data-id="${messageId}"]`);
            if (messageBubble) {
                messageBubble.remove();
            }
        }
    })
    .catch(() => {});
}

/**
 * Supprime une conversation
 * @param {string} number - Le numéro de la conversation
 */
function deleteItemConversation(number) {
    fetch('https://ox_phone/deleteConversation', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            number: number
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            if (activeScreen === 'messages-screen') {
                fetchMessages();
            }
            else if (activeScreen === 'conversation-screen') {
                const conversationTitle = document.getElementById('conversation-title');
                if (conversationTitle && conversationTitle.dataset.number === number) {
                    showScreen('messages-screen');
                }
            }
        }
    })
    .catch(() => {});
}

/**
 * Supprime un appel
 * @param {string} callId - L'identifiant de l'appel
 */
function deleteItemCall(callId) {
    fetch('https://ox_phone/deleteCall', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            callId: callId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            const callItem = document.querySelector(`.call-item[data-id="${callId}"]`);
            if (callItem) {
                callItem.remove();
            }
            
            if (activeScreen === 'call-history-screen') {
                fetchCallHistory();
            }
        }
    })
    .catch(() => {});
}

// =================================================================
// GESTION DES CONTACTS
// =================================================================

/**
 * Configure les écouteurs d'événements pour les contacts
 */
function setupContactsEventListeners() {
    const addContactBtn = document.getElementById('add-contact-btn');
    if (addContactBtn) {
        addContactBtn.addEventListener('click', function() {
            const contactForm = document.getElementById('contact-form');
            if (contactForm) contactForm.reset();
            
            const contactId = document.getElementById('contact-id');
            if (contactId) contactId.value = '';
            
            const contactFormTitle = document.getElementById('contact-form-title');
            if (contactFormTitle) contactFormTitle.textContent = 'Nouveau contact';
            
            showScreen('contact-form-screen');
        });
    }
    
    const saveContactBtn = document.getElementById('save-contact-btn');
    if (saveContactBtn) {
        saveContactBtn.addEventListener('click', function() {
            const contactId = document.getElementById('contact-id')?.value;
            const name = document.getElementById('contact-name')?.value;
            const number = document.getElementById('contact-number')?.value;
            
            if (!name || !number) {
                return;
            }
            
            if (contactId) {
                // Mise à jour d'un contact existant (non implémenté)
            } else {
                fetch('https://ox_phone/addContact', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        name: name,
                        number: number
                    })
                }).then(response => response.json())
                  .then(data => {
                      if (data.success) {
                          showScreen('contacts-screen');
                          fetchContacts();
                      }
                  })
                  .catch(() => {});
            }
        });
    }
    
    const contactSearch = document.getElementById('contact-search');
    if (contactSearch) {
        contactSearch.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            filterContacts(searchTerm);
        });
    }
}

/**
 * Récupère la liste des contacts
 */
function fetchContacts() {
    fetch('https://ox_phone/getContacts', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentContacts = data || [];
          renderContacts(data || []);
      })
      .catch(() => {});
}

/**
 * Affiche la liste des contacts
 * @param {Array} contacts - Liste des contacts à afficher
 */
function renderContacts(contacts) {
    const contactsList = document.getElementById('contacts-list');
    if (!contactsList) return;
    
    contactsList.innerHTML = '';
    
    if (contacts.length === 0) {
        contactsList.innerHTML = '<div class="empty-list">Aucun contact</div>';
        return;
    }
    
    contacts.sort((a, b) => a.display_name.localeCompare(b.display_name));
    
    contacts.forEach(contact => {
        const item = document.createElement('div');
        item.className = 'list-item contact-item';
        item.innerHTML = `
            <div class="contact-avatar">
                <i class="fas fa-user"></i>
            </div>
            <div class="contact-info">
                <div class="contact-name">${contact.display_name}</div>
                <div class="contact-number">${contact.phone_number}</div>
            </div>
            <div class="contact-actions">
                <button class="contact-call" data-number="${contact.phone_number}"><i class="fas fa-phone"></i></button>
                <button class="contact-message" data-number="${contact.phone_number}" data-name="${contact.display_name}"><i class="fas fa-comment"></i></button>
                <button class="contact-delete" data-id="${contact.id}"><i class="fas fa-trash"></i></button>
            </div>
        `;
        
        contactsList.appendChild(item);
    });
    
    document.querySelectorAll('.contact-call').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            startCall(number);
        });
    });
    
    document.querySelectorAll('.contact-message').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            const name = this.dataset.name;
            openConversation(number, name);
        });
    });
    
    document.querySelectorAll('.contact-delete').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.dataset.id;
            deleteContact(id);
        });
    });
}

/**
 * Filtre les contacts selon un terme de recherche
 * @param {string} searchTerm - Le terme de recherche
 */
function filterContacts(searchTerm) {
    if (!searchTerm) {
        renderContacts(currentContacts);
        return;
    }
    
    const filtered = currentContacts.filter(contact => 
        contact.display_name.toLowerCase().includes(searchTerm) || 
        contact.phone_number.includes(searchTerm)
    );
    
    renderContacts(filtered);
}

/**
 * Supprime un contact
 * @param {string} id - L'identifiant du contact
 */
function deleteContact(id) {
    if (confirm('Êtes-vous sûr de vouloir supprimer ce contact ?')) {
        fetch('https://ox_phone/deleteContact', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                id: id
            })
        }).then(response => response.json())
          .then(data => {
              if (data.success) {
                  fetchContacts();
              }
          })
          .catch(() => {});
    }
}

// =================================================================
// GESTION DES MESSAGES
// =================================================================

/**
 * Configure les écouteurs d'événements pour les messages
 */
function setupMessagesEventListeners() {
    const newMessageBtn = document.getElementById('new-message-btn');
    if (newMessageBtn) {
        newMessageBtn.addEventListener('click', function() {
            const messageRecipient = document.getElementById('message-recipient');
            if (messageRecipient) messageRecipient.value = '';
            
            const contactsSuggestions = document.getElementById('contacts-suggestions');
            if (contactsSuggestions) contactsSuggestions.innerHTML = '';
            
            const continueMessageBtn = document.getElementById('continue-message-btn');
            if (continueMessageBtn) continueMessageBtn.classList.add('disabled');
            
            showScreen('new-message-screen');
        });
    }
    
    const messageRecipient = document.getElementById('message-recipient');
    if (messageRecipient) {
        messageRecipient.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            handleRecipientSearch(searchTerm);
        });
    }
    
    const continueMessageBtn = document.getElementById('continue-message-btn');
    if (continueMessageBtn) {
        continueMessageBtn.addEventListener('click', function() {
            if (!this.classList.contains('disabled')) {
                const recipient = document.getElementById('message-recipient')?.value;
                if (recipient && recipient.match(/^\d+$/) && recipient.length >= 3) {
                    const contact = currentContacts.find(c => c.phone_number === recipient);
                    openConversation(recipient, contact ? contact.display_name : null);
                }
            }
        });
    }
    
    const sendMessageBtn = document.getElementById('send-message-btn');
    if (sendMessageBtn) {
        sendMessageBtn.addEventListener('click', function() {
            sendMessage();
        });
    }
    
    const newMessageInput = document.getElementById('new-message-input');
    if (newMessageInput) {
        newMessageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
    }
}

/**
 * Gère la recherche de destinataire de message
 * @param {string} searchTerm - Le terme de recherche
 */
function handleRecipientSearch(searchTerm) {
    const suggestionsContainer = document.getElementById('contacts-suggestions');
    if (!suggestionsContainer) return;
    
    suggestionsContainer.innerHTML = '';
    
    const continueMessageBtn = document.getElementById('continue-message-btn');
    
    if (searchTerm.length < 2) {
        if (continueMessageBtn) continueMessageBtn.classList.add('disabled');
        return;
    }
    
    const matches = currentContacts.filter(contact => 
        contact.display_name.toLowerCase().includes(searchTerm) || 
        contact.phone_number.includes(searchTerm)
    );
    
    if (matches.length > 0) {
        if (continueMessageBtn) continueMessageBtn.classList.remove('disabled');
        
        matches.forEach(contact => {
            const item = document.createElement('div');
            item.className = 'list-item contact-item';
            item.innerHTML = `
                <div class="contact-avatar">
                    <i class="fas fa-user"></i>
                </div>
                <div class="contact-info">
                    <div class="contact-name">${contact.display_name}</div>
                    <div class="contact-number">${contact.phone_number}</div>
                </div>
            `;
            
            item.addEventListener('click', function() {
                openConversation(contact.phone_number, contact.display_name);
            });
            
            suggestionsContainer.appendChild(item);
        });
    } else if (searchTerm.match(/^\d+$/) && searchTerm.length >= 3) {
        if (continueMessageBtn) continueMessageBtn.classList.remove('disabled');
        
        const item = document.createElement('div');
        item.className = 'list-item contact-item';
        item.innerHTML = `
            <div class="contact-avatar">
                <i class="fas fa-user"></i>
            </div>
            <div class="contact-info">
                <div class="contact-name">Nouveau contact</div>
                <div class="contact-number">${searchTerm}</div>
            </div>
        `;
        
        item.addEventListener('click', function() {
            openConversation(searchTerm, null);
        });
        
        suggestionsContainer.appendChild(item);
    } else {
        if (continueMessageBtn) continueMessageBtn.classList.add('disabled');
    }
}

/**
 * Récupère la liste des messages
 */
function fetchMessages() {
    fetch('https://ox_phone/getMessages', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentMessages = data || [];
          renderConversations(data || []);
      })
      .catch(() => {});
}

/**
 * Affiche la liste des conversations
 * @param {Array} conversations - Liste des conversations à afficher
 */
function renderConversations(conversations) {
    const conversationsList = document.getElementById('conversations-list');
    if (!conversationsList) return;
    
    conversationsList.innerHTML = '';
    
    if (conversations.length === 0) {
        conversationsList.innerHTML = '<div class="empty-list">Aucun message</div>';
        return;
    }
    
    conversations.forEach(conversation => {
        const item = document.createElement('div');
        item.className = 'list-item conversation-item';
        
        const date = adjustTimeZone(conversation.last_time);
        const today = new Date();
        let timeString;
        
        if (date.toDateString() === today.toDateString()) {
            timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
            timeString = date.toLocaleDateString([], { day: 'numeric', month: 'numeric' });
        }
        
        const unreadBadge = conversation.unread > 0 
            ? `<div class="unread-badge">${conversation.unread}</div>` 
            : '';
        
        item.innerHTML = `
            <div class="conversation-avatar">
                <i class="fas fa-user"></i>
                ${unreadBadge}
            </div>
            <div class="conversation-info">
                <div class="conversation-name">
                    <span>${conversation.name || conversation.number}</span>
                    <span class="conversation-time">${timeString}</span>
                </div>
                <div class="conversation-preview">${conversation.last_message}</div>
            </div>
            <button class="conversation-delete-btn"><i class="fas fa-trash"></i></button>
        `;
        
        item.addEventListener('click', function(e) {
            if (!e.target.closest('.conversation-delete-btn')) {
                openConversation(conversation.number, conversation.name);
            }
        });
        
        conversationsList.appendChild(item);
    });
}

/**
 * Ouvre une conversation
 * @param {string} number - Le numéro du destinataire
 * @param {string} name - Le nom du destinataire (optionnel)
 */
function openConversation(number, name) {
    fetch('https://ox_phone/getConversation', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            number: number
        })
    }).then(response => response.json())
      .then(data => {
          const title = document.getElementById('conversation-title');
          if (title) {
              title.textContent = data.name || number;
              title.dataset.number = number;
          }
          
          renderMessages(data.messages || []);
          
          showScreen('conversation-screen');
          
          const messagesList = document.getElementById('messages-list');
          if (messagesList) messagesList.scrollTop = messagesList.scrollHeight;
          
          if (conversationRefreshInterval) {
              clearInterval(conversationRefreshInterval);
          }
          
          conversationRefreshInterval = setInterval(function() {
              refreshCurrentConversation(number);
          }, 3000);
      })
      .catch(() => {});
}

/**
 * Rafraîchit la conversation actuelle
 * @param {string} number - Le numéro du destinataire
 */
function refreshCurrentConversation(number) {
    if (!phoneOpen || activeScreen !== 'conversation-screen') {
        if (conversationRefreshInterval) {
            clearInterval(conversationRefreshInterval);
            conversationRefreshInterval = null;
        }
        return;
    }
    
    const conversationTitle = document.getElementById('conversation-title');
    if (!conversationTitle || conversationTitle.dataset.number !== number) {
        return;
    }
    
    fetch('https://ox_phone/getConversation', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            number: number
        })
    }).then(response => response.json())
      .then(data => {
          updateExistingConversation(data.messages || []);
      })
      .catch(() => {});
}

/**
 * Met à jour les messages d'une conversation sans tout redessiner
 * @param {Array} messages - Liste des messages à afficher
 */
function updateExistingConversation(messages) {
    const messagesList = document.getElementById('messages-list');
    if (!messagesList) return;
    
    const existingIds = new Set();
    document.querySelectorAll('.message-bubble').forEach(bubble => {
        if (bubble.dataset.id) {
            existingIds.add(bubble.dataset.id);
        }
    });
    
    let hasNewMessages = false;
    messages.forEach(message => {
        if (message.id && !existingIds.has(message.id.toString())) {
            const isOutgoing = message.is_sender === 1;
            const date = adjustTimeZone(message.created_at);
            const timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            
            const bubble = document.createElement('div');
            bubble.className = `message-bubble ${isOutgoing ? 'message-outgoing' : 'message-incoming'} new`;
            bubble.dataset.id = message.id;
            
            bubble.innerHTML = `
                <div class="message-content">${message.message}</div>
                <div class="message-time">${timeString}</div>
            `;
            
            messagesList.appendChild(bubble);
            hasNewMessages = true;
        }
    });
    
    if (hasNewMessages) {
        messagesList.scrollTop = messagesList.scrollHeight;
    }
}

/**
 * Affiche les messages d'une conversation
 * @param {Array} messages - Liste des messages à afficher
 */
function renderMessages(messages) {
    const messagesList = document.getElementById('messages-list');
    if (!messagesList) return;

    messagesList.innerHTML = '';

    if (messages.length === 0) {
        messagesList.innerHTML = '<div class="empty-list">Aucun message</div>';
        return;
    }

    const messagesByDate = {};
    messages.forEach(message => {
        const date = adjustTimeZone(message.created_at);
        const dateString = date.toLocaleDateString();

        if (!messagesByDate[dateString]) {
            messagesByDate[dateString] = [];
        }
        messagesByDate[dateString].push(message);
    });

    for (const dateString in messagesByDate) {
        const today = new Date();
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);

        let dateDisplay = dateString;
        if (dateString === today.toLocaleDateString()) {
            dateDisplay = "Aujourd'hui";
        } else if (dateString === yesterday.toLocaleDateString()) {
            dateDisplay = "Hier";
        }

        const dateHeader = document.createElement('div');
        dateHeader.className = 'message-date-header';
        dateHeader.textContent = dateDisplay;
        messagesList.appendChild(dateHeader);

        messagesByDate[dateString].forEach(message => {
            const isOutgoing = message.is_sender === 1;
            
            const date = adjustTimeZone(message.created_at);
            const timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

            const bubble = document.createElement('div');
            bubble.className = `message-bubble ${isOutgoing ? 'message-outgoing' : 'message-incoming'}`;
            bubble.dataset.id = message.id;

            bubble.innerHTML = `
                <div class="message-content">${message.message}</div>
                <div class="message-time">${timeString}</div>
            `;

            messagesList.appendChild(bubble);
        });
    }

    messagesList.scrollTop = messagesList.scrollHeight;
}

/**
 * Affiche une notification SMS
 * @param {Object} data - Les données du message
 */
function showSmsNotification(data) {
    const notification = document.createElement('div');
    notification.className = 'custom-notification';
    notification.innerHTML = `
        <div class="notification-title">Nouveau SMS de ${data.sender}</div>
        <div class="notification-message">${data.message.substring(0, 50)}${data.message.length > 50 ? '...' : ''}</div>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 5000);
}

/**
 * Envoie un message
 */
function sendMessage() {
    const input = document.getElementById('new-message-input');
    if (!input) return;
    
    const message = input.value.trim();
    const conversationTitle = document.getElementById('conversation-title');
    if (!conversationTitle) return;
    
    const number = conversationTitle.dataset.number;
    
    if (message.length === 0 || !number) {
        return;
    }
    
    input.value = '';
    
    fetch('https://ox_phone/sendMessage', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            to: number,
            message: message
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              refreshCurrentConversation(number);
          }
      })
      .catch(() => {});
}

/**
 * Reçoit un message
 * @param {Object} data - Les données du message
 */
function receiveMessage(data) {
    const conversationTitle = document.getElementById('conversation-title');
    
    if (conversationTitle && activeScreen === 'conversation-screen' && conversationTitle.dataset.number === data.sender) {
        const messages = document.getElementById('messages-list');
        if (!messages) return;
        
        const bubble = document.createElement('div');
        
        const date = data.time ? adjustTimeZone(data.time) : new Date();
        const timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        bubble.className = 'message-bubble message-incoming new';
        bubble.dataset.id = data.id || Date.now();
        
        bubble.innerHTML = `
            <div class="message-content">${data.message}</div>
            <div class="message-time">${timeString}</div>
        `;
        
        messages.appendChild(bubble);
        
        messages.scrollTop = messages.scrollHeight;
        
        fetch('https://ox_phone/markMessageRead', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                sender: data.sender
            })
        }).catch(() => {});
    } 
    else if (activeScreen === 'messages-screen') {
        fetchMessages();
    } 
    else {
        const notification = {
            title: 'Nouveau message',
            description: `De: ${data.sender}\n${data.message.substring(0, 30)}${data.message.length > 30 ? '...' : ''}`
        };
        
        try {
            fetch('https://ox_lib/notify', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(notification)
            }).catch(() => {
                showCustomNotification(notification.title, notification.description);
            });
        } catch (e) {
            showCustomNotification(notification.title, notification.description);
        }
    }
}

// =================================================================
// GESTION DES APPELS
// =================================================================

/**
 * Configure les écouteurs d'événements pour les appels
 */
function setupPhoneEventListeners() {
    document.querySelectorAll('.dialer-key').forEach(key => {
        key.addEventListener('click', function() {
            const digit = this.dataset.key;
            const display = document.getElementById('dialed-number');
            if (display) display.value += digit;
        });
    });
    
    const deleteDigitBtn = document.getElementById('delete-digit-btn');
    if (deleteDigitBtn) {
        deleteDigitBtn.addEventListener('click', function() {
            const display = document.getElementById('dialed-number');
            if (display) display.value = display.value.slice(0, -1);
        });
    }
    
    const startCallBtn = document.getElementById('start-call-btn');
    if (startCallBtn) {
        startCallBtn.addEventListener('click', function() {
            const number = document.getElementById('dialed-number')?.value;
            if (number && number.length > 0) {
                startCall(number);
            }
        });
    }
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) {
        answerCallBtn.addEventListener('click', function() {
            answerCall();
        });
    }
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) {
        endCallBtn.addEventListener('click', function() {
            endCall();
        });
    }
    
    const callHistoryBtn = document.getElementById('call-history-btn');
    if (callHistoryBtn) {
        callHistoryBtn.addEventListener('click', function() {
            showScreen('call-history-screen');
        });
    }
    
    const callFromMessageBtn = document.getElementById('call-from-message-btn');
    if (callFromMessageBtn) {
        callFromMessageBtn.addEventListener('click', function() {
            const title = document.getElementById('conversation-title');
            const number = title?.dataset.number;
            if (number) {
                startCall(number);
            }
        });
    }
}

/**
 * Joue la sonnerie
 */
function playRingtone() {
    stopRingtone();
    
    try {
        ringtoneAudio = new Audio(`sounds/${currentRingtone}.ogg`);
        ringtoneAudio.loop = true;
        ringtoneAudio.volume = 1.0;
        
        ringtoneAudio.play().catch(() => {
            ringtoneAudio = new Audio(`sounds/${currentRingtone}.mp3`);
            ringtoneAudio.loop = true;
            ringtoneAudio.volume = 1.0;
            ringtoneAudio.play().catch(() => {});
        });
    } catch (e) {}
}

/**
 * Arrête la sonnerie
 */
function stopRingtone() {
    if (ringtoneAudio) {
        ringtoneAudio.pause();
        ringtoneAudio.currentTime = 0;
        ringtoneAudio = null;
    }
}

/**
 * Joue le son de notification
 */
function playNotificationSound() {
    stopNotificationSound();
    
    try {
        notificationAudio = new Audio(`sounds/${currentNotificationSound}.ogg`);
        notificationAudio.volume = 1.0;
        
        const playPromise = notificationAudio.play();
        
        if (playPromise !== undefined) {
            playPromise.catch(() => {
                notificationAudio = new Audio(`sounds/${currentNotificationSound}.mp3`);
                notificationAudio.volume = 1.0;
                
                notificationAudio.play().catch(() => {});
            });
        }
    } catch (e) {}
}

/**
 * Arrête le son de notification
 */
function stopNotificationSound() {
    if (notificationAudio) {
        notificationAudio.pause();
        notificationAudio.currentTime = 0;
        notificationAudio = null;
    }
}

/**
 * Démarre un appel
 * @param {string} number - Le numéro à appeler
 */
function startCall(number) {
    if (activeCallId) {
        endCall();
    }
    
    activeCallNumber = number;
    
    fetch('https://ox_phone/startCall', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            number: number
        })
    }).catch(() => {});
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel en cours...';
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = getContactNameForNumber(number) || number;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = number;
    
    const callDurationElement = document.getElementById('call-duration');
    if (callDurationElement) callDurationElement.textContent = '00:00';
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    showScreen('calling-screen');
}

/**
 * Répond à un appel
 */
function answerCall() {
    if (!activeCallId) {
        return;
    }
    
    fetch('https://ox_phone/answerCall', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            callId: activeCallId
        })
    }).catch(() => {});
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    stopRingtone();
}

/**
 * Termine un appel
 */
function endCall() {
    if (!activeCallId && !activeCallNumber) {
        return;
    }
    
    fetch('https://ox_phone/endCall', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            callId: activeCallId,
            number: activeCallNumber
        })
    }).catch(() => {});
    
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel terminé';
    
    setTimeout(function() {
        if (activeScreen === 'calling-screen') {
            showScreen('phone-app-screen');
        }
        activeCallId = null;
        activeCallNumber = null;
    }, 2000);
    
    stopRingtone();
}

/**
 * Gère un appel répondu
 */
function callAnswered() {
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'En appel';
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    stopRingtone();
    
    fetch('https://ox_phone/stopAllSounds', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    }).catch(() => {});
    
    callDuration = 0;
    
    const callDurationElement = document.getElementById('call-duration');
    if (callDurationElement) callDurationElement.textContent = '00:00';
    
    callTimer = setInterval(function() {
        callDuration++;
        const minutes = Math.floor(callDuration / 60);
        const seconds = callDuration % 60;
        const formattedDuration = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        
        const callDurationElement = document.getElementById('call-duration');
        if (callDurationElement) callDurationElement.textContent = formattedDuration;
    }, 1000);
}

/**
 * Gère un appel rejeté
 */
function callRejected() {
    if (activeScreen === 'calling-screen') {
        const callStatus = document.getElementById('call-status');
        if (callStatus) callStatus.textContent = 'Appel rejeté';
        
        setTimeout(function() {
            showScreen('phone-app-screen');
            activeCallId = null;
            activeCallNumber = null;
        }, 2000);
    }
    
    stopRingtone();
}

/**
 * Gère un appel terminé
 */
function callEnded() {
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    if (activeScreen === 'calling-screen') {
        const callStatus = document.getElementById('call-status');
        if (callStatus) callStatus.textContent = 'Appel terminé';
        
        setTimeout(function() {
            showScreen('phone-app-screen');
            activeCallId = null;
            activeCallNumber = null;
        }, 2000);
    }
    
    stopRingtone();
}

/**
 * Obtient le nom d'un contact à partir de son numéro
 * @param {string} number - Le numéro du contact
 * @return {string} - Le nom du contact ou null
 */
function getContactNameForNumber(number) {
    const contact = currentContacts.find(c => c.phone_number === number);
    return contact ? contact.display_name : null;
}

/**
 * Récupère l'historique des appels
 */
function fetchCallHistory() {
    fetch('https://ox_phone/getCallHistory', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.text())
    .then(text => {
        try {
            const data = JSON.parse(text);
            currentCallHistory = data;
            renderCallHistory(data);
        } catch (e) {}
    })
    .catch(() => {});
}

/**
 * Affiche l'historique des appels
 * @param {Array} calls - Liste des appels à afficher
 */
function renderCallHistory(calls) {
    const callsList = document.getElementById('call-history-list');
    if (!callsList) {
        return;
    }

    callsList.innerHTML = '';

    if (!calls || calls.length === 0) {
        callsList.innerHTML = '<div class="empty-list">Aucun appel</div>';
        return;
    }

    calls.forEach(call => {
        const item = document.createElement('div');
        item.className = 'list-item call-item';
        item.dataset.id = call.id;

        const date = adjustTimeZone(call.created_at);
        const today = new Date();
        let timeString;

        if (date.toDateString() === today.toDateString()) {
            timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
            timeString = date.toLocaleDateString([], { day: 'numeric', month: 'numeric' });
        }

        let icon, statusClass, statusText, displayNumber;
        const duration = call.duration > 0 ? formatDuration(call.duration) : '';

        const isOutgoing = call.direction === 'outgoing';
        displayNumber = isOutgoing ? call.receiver : call.caller;

        if (isOutgoing) {
            if (call.status === 'answered' || call.status === 'ended') {
                icon = '<i class="fas fa-phone-alt" style="color: green;"></i>';
                statusClass = 'call-outgoing';
                statusText = 'Sortant';
            } else if (call.status === 'rejected') {
                icon = '<i class="fas fa-phone-slash" style="color: orange;"></i>';
                statusClass = 'call-rejected';
                statusText = 'Rejeté';
            } else {
                icon = '<i class="fas fa-phone-alt" style="color: orange;"></i>';
                statusClass = 'call-no-answer';
                statusText = 'Sans réponse';
            }
        } else {
            if (call.status === 'answered' || call.status === 'ended') {
                icon = '<i class="fas fa-phone-alt" style="color: green;"></i>';
                statusClass = 'call-incoming';
                statusText = 'Entrant';
            } else if (call.status === 'rejected') {
                icon = '<i class="fas fa-phone-slash" style="color: red;"></i>';
                statusClass = 'call-missed';
                statusText = 'Manqué';
            } else if (call.status === 'missed' || call.status === 'outgoing') {
                icon = '<i class="fas fa-phone-alt" style="color: red;"></i>';
                statusClass = 'call-missed';
                statusText = 'Manqué';
            } else {
                icon = '<i class="fas fa-phone-alt" style="color: red;"></i>';
                statusClass = 'call-missed';
                statusText = 'Manqué';
            }
        }

        const displayName = call.name || displayNumber;

        item.innerHTML = `
            <div class="call-icon ${statusClass}">
                ${icon}
            </div>
            <div class="call-info">
                <div class="call-name">${displayName}</div>
                <div class="call-details">
                    <span class="${statusClass}">${statusText}</span>
                    ${duration ? `<span> · ${duration}</span>` : ''}
                    <span> · ${timeString}</span>
                </div>
            </div>
            <div class="call-actions">
                <button class="call-btn-small" data-number="${displayNumber}">
                    <i class="fas fa-phone"></i>
                </button>
                <button class="call-delete-btn" data-id="${call.id}">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `;

        callsList.appendChild(item);
    });

    document.querySelectorAll('.call-btn-small').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            startCall(number);
        });
    });
}

/**
 * Formate la durée d'un appel
 * @param {number} seconds - Durée en secondes
 * @return {string} - Durée formatée
 */
function formatDuration(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
}

// =================================================================
// GESTION DES RÉSEAUX SOCIAUX (TWITTER, ANNONCES)
// =================================================================

/**
 * Configure les écouteurs d'événements pour Twitter
 */
function setupTwitterEventListeners() {
    const newTweetBtn = document.getElementById('new-tweet-btn');
    if (newTweetBtn) {
        newTweetBtn.addEventListener('click', function() {
            const tweetContent = document.getElementById('tweet-content');
            if (tweetContent) tweetContent.value = '';
            
            const tweetCharCount = document.getElementById('tweet-char-count');
            if (tweetCharCount) tweetCharCount.textContent = '0/280';
            
            tweetImage = null;
            
            const tweetPhotoPreview = document.getElementById('tweet-photo-preview');
            if (tweetPhotoPreview) tweetPhotoPreview.classList.add('hidden');
            
            showScreen('new-tweet-screen');
        });
    }
    
    const tweetContent = document.getElementById('tweet-content');
    if (tweetContent) {
        tweetContent.addEventListener('input', function() {
            const count = this.value.length;
            const tweetCharCount = document.getElementById('tweet-char-count');
            if (tweetCharCount) tweetCharCount.textContent = `${count}/280`;
        });
    }
    
    const tweetAddPhoto = document.getElementById('tweet-add-photo');
    if (tweetAddPhoto) {
        tweetAddPhoto.addEventListener('click', function() {
            showScreen('gallery-screen');
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = 'tweet';
        });
    }
    
    const tweetRemovePhoto = document.getElementById('tweet-remove-photo');
    if (tweetRemovePhoto) {
        tweetRemovePhoto.addEventListener('click', function() {
            tweetImage = null;
            const tweetPhotoPreview = document.getElementById('tweet-photo-preview');
            if (tweetPhotoPreview) tweetPhotoPreview.classList.add('hidden');
        });
    }
    
    const sendTweetBtn = document.getElementById('send-tweet-btn');
    if (sendTweetBtn) {
        sendTweetBtn.addEventListener('click', function() {
            const content = document.getElementById('tweet-content')?.value;
            if (content && content.length > 0) {
                fetch('https://ox_phone/postTweet', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        message: content,
                        image: tweetImage
                    })
                }).then(response => response.json())
                  .then(data => {
                      if (data.success) {
                          showScreen('twitter-screen');
                          fetchTweets();
                      }
                  })
                  .catch(() => {});
            }
        });
    }
}

/**
 * Récupère les tweets
 */
function fetchTweets() {
    fetch('https://ox_phone/getTweets', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentTweets = data || [];
          renderTweets(data || []);
      })
      .catch(() => {});
}

/**
 * Rafraîchit les tweets
 */
function refreshTweets() {
    if (!phoneOpen || activeScreen !== 'twitter-screen') {
        if (tweetRefreshInterval) {
            clearInterval(tweetRefreshInterval);
            tweetRefreshInterval = null;
        }
        return;
    }
    
    fetch('https://ox_phone/getTweets', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          updateExistingTweets(data || []);
      })
      .catch(() => {});
}

/**
 * Met à jour les tweets existants
 * @param {Array} tweets - Liste des tweets
 */
function updateExistingTweets(tweets) {
    const existingTweets = {};
    document.querySelectorAll('.tweet-item').forEach(tweetElem => {
        if (tweetElem.dataset.id) {
            existingTweets[tweetElem.dataset.id] = tweetElem;
        }
    });
    
    tweets.forEach(tweet => {
        const id = tweet.id.toString();
        
        if (existingTweets[id]) {
            const likes = JSON.parse(tweet.likes || '[]').length;
            const hasLiked = JSON.parse(tweet.likes || '[]').includes(playerIdentifier);
            
            const likeBtn = existingTweets[id].querySelector(`.tweet-like`);
            if (likeBtn) {
                const likeCount = likeBtn.querySelector('span');
                if (likeCount) likeCount.textContent = likes;
                
                likeBtn.dataset.liked = hasLiked.toString();
                
                const heart = likeBtn.querySelector('i');
                if (heart) heart.style.color = hasLiked ? 'red' : '';
            }
            
            const commentsSection = existingTweets[id].querySelector('.tweet-comments');
            if (commentsSection && commentsSection.classList.contains('open')) {
                fetchTweetComments(id).then(commentCount => {
                    const commentCountSpan = existingTweets[id].querySelector('.comment-count');
                    if (commentCountSpan) {
                        commentCountSpan.textContent = commentCount;
                    }
                });
            }
        } else {
            const tweetsList = document.getElementById('tweets-list');
            if (tweetsList) {
                const date = adjustTimeZone(tweet.created_at);
                const timeString = formatRelativeTime(date);
                
                const likes = JSON.parse(tweet.likes || '[]').length;
                
                const hasLiked = JSON.parse(tweet.likes || '[]').includes(playerIdentifier);
                
                const item = document.createElement('div');
                item.className = 'tweet-item';
                item.dataset.id = tweet.id;
                item.innerHTML = `
                    <div class="tweet-header">
                        <div class="tweet-avatar">
                            <i class="fas fa-user"></i>
                        </div>
                        <div class="tweet-user-info">
                            <div class="tweet-author">@${tweet.author}</div>
                            <div class="tweet-time">${timeString}</div>
                        </div>
                    </div>
                    <div class="tweet-content">${tweet.message}</div>
                    ${tweet.image ? `<img src="${tweet.image}" class="tweet-image" alt="Image">` : ''}
                    <div class="tweet-actions">
                        <div class="tweet-action tweet-like" data-id="${tweet.id}" data-liked="${hasLiked}">
                            <i class="fas fa-heart" ${hasLiked ? 'style="color: red;"' : ''}></i>
                            <span>${likes}</span>
                        </div>
                        <div class="tweet-action tweet-comment-toggle" data-id="${tweet.id}">
                            <i class="fas fa-comment"></i>
                            <span class="comment-count">0</span>
                        </div>
                        <div class="tweet-action">
                            <i class="fas fa-retweet"></i>
                            <span>0</span>
                        </div>
                    </div>
                    <div class="tweet-comments">
                        <div class="tweet-comments-list"></div>
                        <div class="tweet-comment-form">
                            <input type="text" class="tweet-comment-input" placeholder="Ajouter un commentaire...">
                            <button class="tweet-comment-submit"><i class="fas fa-paper-plane"></i></button>
                        </div>
                    </div>
                `;
                
                if (tweetsList.firstChild) {
                    tweetsList.insertBefore(item, tweetsList.firstChild);
                } else {
                    tweetsList.appendChild(item);
                }
                
                const likeBtn = item.querySelector('.tweet-like');
                if (likeBtn) {
                    likeBtn.addEventListener('click', function() {
                        likeTweet(tweet.id);
                    });
                }
                
                const commentToggle = item.querySelector('.tweet-comment-toggle');
                if (commentToggle) {
                    commentToggle.addEventListener('click', function() {
                        const tweetId = this.dataset.id;
                        const tweetItem = this.closest('.tweet-item');
                        const tweetComments = tweetItem.querySelector('.tweet-comments');
                        tweetComments.classList.toggle('open');
                        
                        if (tweetComments.classList.contains('open')) {
                            fetchTweetComments(tweetId);
                        }
                    });
                }
                
                const commentSubmit = item.querySelector('.tweet-comment-submit');
                if (commentSubmit) {
                    commentSubmit.addEventListener('click', function() {
                        const tweetItem = this.closest('.tweet-item');
                        const tweetId = tweetItem.dataset.id;
                        const commentInput = tweetItem.querySelector('.tweet-comment-input');
                        const message = commentInput.value.trim();
                        
                        if (message.length > 0) {
                            addTweetComment(tweetId, message);
                            commentInput.value = '';
                        }
                    });
                }
            }
        }
    });
}

/**
 * Récupère les commentaires d'un tweet
 * @param {string} tweetId - Identifiant du tweet
 * @return {Promise<number>} - Nombre de commentaires
 */
function fetchTweetComments(tweetId) {
    return fetch('https://ox_phone/getTweetComments', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            tweetId: tweetId
        })
    }).then(response => response.json())
      .then(data => {
          renderTweetComments(tweetId, data || []);
          return data ? data.length : 0;
      })
      .catch(() => {
          return 0;
      });
}

/**
 * Affiche les commentaires d'un tweet
 * @param {string} tweetId - Identifiant du tweet
 * @param {Array} comments - Liste des commentaires
 */
function renderTweetComments(tweetId, comments) {
    const commentsList = document.querySelector(`.tweet-item[data-id="${tweetId}"] .tweet-comments-list`);
    if (!commentsList) return;

    commentsList.innerHTML = '';

    if (comments.length === 0) {
        commentsList.innerHTML = '<div class="empty-list">Aucun commentaire</div>';
        return;
    }

    comments.forEach(comment => {
        const item = document.createElement('div');
        item.className = 'tweet-comment-item';
        item.innerHTML = `
            <div class="tweet-comment-header">
                <div class="tweet-comment-author">@${comment.author}</div>
                <div class="tweet-comment-time">${formatRelativeTime(new Date(comment.created_at))}</div>
            </div>
            <div class="tweet-comment-content">${comment.message}</div>
        `;
        commentsList.appendChild(item);
    });
}

/**
 * Ajoute un commentaire à un tweet
 * @param {string} tweetId - Identifiant du tweet
 * @param {string} message - Contenu du commentaire
 */
function addTweetComment(tweetId, message) {
    fetch('https://ox_phone/addTweetComment', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            tweetId: tweetId,
            message: message
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              fetchTweetComments(tweetId);
          }
      })
      .catch(() => {});
}

/**
 * Affiche les tweets
 * @param {Array} tweets - Liste des tweets
 */
function renderTweets(tweets) {
    const tweetsList = document.getElementById('tweets-list');
    if (!tweetsList) return;

    tweetsList.innerHTML = '';

    if (tweets.length === 0) {
        tweetsList.innerHTML = '<div class="empty-list">Aucun tweet</div>';
        return;
    }

    tweets.forEach(tweet => {
        const date = adjustTimeZone(tweet.created_at);
        const timeString = formatRelativeTime(date);

        const likes = JSON.parse(tweet.likes || '[]').length;

        const hasLiked = JSON.parse(tweet.likes || '[]').includes(playerIdentifier);

        const item = document.createElement('div');
        item.className = 'tweet-item';
        item.dataset.id = tweet.id;
        item.innerHTML = `
            <div class="tweet-header">
                <div class="tweet-avatar">
                    <i class="fas fa-user"></i>
                </div>
                <div class="tweet-user-info">
                    <div class="tweet-author">@${tweet.author}</div>
                    <div class="tweet-time">${timeString}</div>
                </div>
            </div>
            <div class="tweet-content">${tweet.message}</div>
            ${tweet.image ? `<img src="${tweet.image}" class="tweet-image" alt="Image">` : ''}
            <div class="tweet-actions">
                <div class="tweet-action tweet-like" data-id="${tweet.id}" data-liked="${hasLiked}">
                    <i class="fas fa-heart" ${hasLiked ? 'style="color: red;"' : ''}></i>
                    <span>${likes}</span>
                </div>
                <div class="tweet-action tweet-comment-toggle" data-id="${tweet.id}">
                    <i class="fas fa-comment"></i>
                    <span class="comment-count">0</span>
                </div>
                <div class="tweet-action">
                    <i class="fas fa-retweet"></i>
                    <span>0</span>
                </div>
            </div>
            <div class="tweet-comments">
                <div class="tweet-comments-list"></div>
                <div class="tweet-comment-form">
                    <input type="text" class="tweet-comment-input" placeholder="Ajouter un commentaire...">
                    <button class="tweet-comment-submit"><i class="fas fa-paper-plane"></i></button>
                </div>
            </div>
        `;

        tweetsList.appendChild(item);

        fetchTweetComments(tweet.id).then(commentCount => {
            const commentCountSpan = item.querySelector('.comment-count');
            if (commentCountSpan) {
                commentCountSpan.textContent = commentCount;
            }
        });
    });

    document.querySelectorAll('.tweet-like').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.dataset.id;
            likeTweet(id);
        });
    });

    document.querySelectorAll('.tweet-comment-toggle').forEach(btn => {
        btn.addEventListener('click', function() {
            const tweetId = this.dataset.id;
            const tweetItem = this.closest('.tweet-item');
            const tweetComments = tweetItem.querySelector('.tweet-comments');
            tweetComments.classList.toggle('open');

            if (tweetComments.classList.contains('open')) {
                fetchTweetComments(tweetId);
            }
        });
    });

    document.querySelectorAll('.tweet-comment-submit').forEach(btn => {
        btn.addEventListener('click', function() {
            const tweetItem = this.closest('.tweet-item');
            const tweetId = tweetItem.dataset.id;
            const commentInput = tweetItem.querySelector('.tweet-comment-input');
            const message = commentInput.value.trim();

            if (message.length > 0) {
                addTweetComment(tweetId, message);
                commentInput.value = '';
            }
        });
    });
}

/**
 * Aime un tweet
 * @param {string} id - Identifiant du tweet
 */
function likeTweet(id) {
    fetch('https://ox_phone/likeTweet', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            tweetId: id
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              const likeBtn = document.querySelector(`.tweet-like[data-id="${id}"]`);
              if (!likeBtn) return;
              
              const likeCount = likeBtn.querySelector('span');
              if (likeCount) likeCount.textContent = data.likes;
              
              const isLiked = likeBtn.dataset.liked === 'true';
              likeBtn.dataset.liked = (!isLiked).toString();
              
              const heart = likeBtn.querySelector('i');
              if (heart) heart.style.color = !isLiked ? 'red' : '';
          }
      })
      .catch(() => {});
}

/**
 * Reçoit un nouveau tweet
 * @param {Object} data - Données du tweet
 */
function receiveTweet(data) {
    if (activeScreen === 'twitter-screen') {
        const tweetsList = document.getElementById('tweets-list');
        if (!tweetsList) return;
        
        const date = adjustTimeZone(data.tweet.created_at);
        const timeString = 'à l\'instant';
        
        const item = document.createElement('div');
        item.className = 'tweet-item';
        item.innerHTML = `
            <div class="tweet-header">
                <div class="tweet-avatar">
                    <i class="fas fa-user"></i>
                </div>
                <div class="tweet-user-info">
                    <div class="tweet-author">@${data.tweet.author}</div>
                    <div class="tweet-time">${timeString}</div>
                </div>
            </div>
            <div class="tweet-content">${data.tweet.message}</div>
            ${data.tweet.image ? `<img src="${data.tweet.image}" class="tweet-image" alt="Image">` : ''}
            <div class="tweet-actions">
                <div class="tweet-action tweet-like" data-id="${data.tweet.id}" data-liked="false">
                    <i class="fas fa-heart"></i>
                    <span>0</span>
                </div>
                <div class="tweet-action">
                    <i class="fas fa-comment"></i>
                    <span>0</span>
                </div>
                <div class="tweet-action">
                    <i class="fas fa-retweet"></i>
                    <span>0</span>
                </div>
            </div>
        `;
        
        if (tweetsList.firstChild) {
            tweetsList.insertBefore(item, tweetsList.firstChild);
        } else {
            tweetsList.appendChild(item);
        }
        
        const likeBtn = item.querySelector('.tweet-like');
        if (likeBtn) {
            likeBtn.addEventListener('click', function() {
                likeTweet(data.tweet.id);
            });
        }
    }
    
    if (!doNotDisturb && !airplaneMode) {
        playNotificationSound();
    }
}

/**
 * Configure les écouteurs d'événements pour les annonces
 */
function setupAdsEventListeners() {
    const newAdBtn = document.getElementById('new-ad-btn');
    if (newAdBtn) {
        newAdBtn.addEventListener('click', function() {
            const adTitle = document.getElementById('ad-title');
            if (adTitle) adTitle.value = '';
            
            const adContent = document.getElementById('ad-content');
            if (adContent) adContent.value = '';
            
            const adPrice = document.getElementById('ad-price');
            if (adPrice) adPrice.value = '';
            
            adImage = null;
            
            const adPhotoPreview = document.getElementById('ad-photo-preview');
            if (adPhotoPreview) adPhotoPreview.classList.add('hidden');
            
            showScreen('new-ad-screen');
        });
    }
    
    const adAddPhoto = document.getElementById('ad-add-photo');
    if (adAddPhoto) {
        adAddPhoto.addEventListener('click', function() {
            showScreen('gallery-screen');
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = 'ad';
        });
    }
    
    const adRemovePhoto = document.getElementById('ad-remove-photo');
    if (adRemovePhoto) {
        adRemovePhoto.addEventListener('click', function() {
            adImage = null;
            const adPhotoPreview = document.getElementById('ad-photo-preview');
            if (adPhotoPreview) adPhotoPreview.classList.add('hidden');
        });
    }
    
    const sendAdBtn = document.getElementById('send-ad-btn');
    if (sendAdBtn) {
        sendAdBtn.addEventListener('click', function() {
            const title = document.getElementById('ad-title')?.value;
            const content = document.getElementById('ad-content')?.value;
            const price = document.getElementById('ad-price')?.value;
            
            if (title && title.length > 0 && content && content.length > 0) {
                fetch('https://ox_phone/postAd', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        title: title,
                        message: content,
                        image: adImage,
                        price: price || null
                    })
                }).then(response => response.json())
                  .then(data => {
                      if (data.success) {
                          showScreen('ads-screen');
                          fetchAds();
                      }
                  })
                  .catch(() => {});
            }
        });
    }
}

/**
 * Récupère les annonces
 */
function fetchAds() {
    fetch('https://ox_phone/getAds', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentAds = data || [];
          renderAds(data || []);
      })
      .catch(() => {});
}

/**
 * Rafraîchit les annonces
 */
function refreshAds() {
    if (!phoneOpen || activeScreen !== 'ads-screen') {
        if (adsRefreshInterval) {
            clearInterval(adsRefreshInterval);
            adsRefreshInterval = null;
        }
        return;
    }
    
    fetch('https://ox_phone/getAds', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          updateExistingAds(data || []);
      })
      .catch(() => {});
}

/**
 * Met à jour les annonces existantes
 * @param {Array} ads - Liste des annonces
 */
function updateExistingAds(ads) {
    const adsList = document.getElementById('ads-list');
    if (!adsList) return;
    
    const existingAds = {};
    document.querySelectorAll('.ad-item').forEach(adElem => {
        const adId = adElem.getAttribute('data-id');
        if (adId) {
            existingAds[adId] = adElem;
        }
    });
    
    if (Object.keys(existingAds).length === 0 && ads.length > 0) {
        renderAds(ads);
        return;
    }
    
    ads.forEach(ad => {
        const id = ad.id.toString();
        
        if (!existingAds[id]) {
            const date = adjustTimeZone(ad.created_at);
            const timeString = formatRelativeTime(date);
            
            const item = document.createElement('div');
            item.className = 'ad-item';
            item.setAttribute('data-id', id);
            
            const priceDisplay = ad.price ? `<div class="ad-price">$${parseFloat(ad.price).toFixed(2)}</div>` : '';
            
            item.innerHTML = `
                <div class="ad-header">
                    <div class="ad-title">${ad.title}</div>
                    ${priceDisplay}
                </div>
                <div class="ad-content">
                    ${ad.image ? `<img src="${ad.image}" class="ad-image" alt="Image">` : ''}
                    <div class="ad-description">${ad.message}</div>
                </div>
                <div class="ad-footer">
                    <div class="ad-author">${ad.author} · ${timeString}</div>
                    <div class="ad-contact">
                        <button class="ad-call" data-number="${ad.phone_number}"><i class="fas fa-phone"></i></button>
                        <button class="ad-message" data-number="${ad.phone_number}" data-name="${ad.author}"><i class="fas fa-comment"></i></button>
                    </div>
                </div>
            `;
            
            if (adsList.firstChild) {
                adsList.insertBefore(item, adsList.firstChild);
            } else {
                adsList.appendChild(item);
            }
            
            const callBtn = item.querySelector('.ad-call');
            if (callBtn) {
                callBtn.addEventListener('click', function() {
                    const number = this.dataset.number;
                    startCall(number);
                });
            }
            
            const messageBtn = item.querySelector('.ad-message');
            if (messageBtn) {
                messageBtn.addEventListener('click', function() {
                    const number = this.dataset.number;
                    const name = this.dataset.name;
                    openConversation(number, name);
                });
            }
        }
    });
}

/**
 * Affiche les annonces
 * @param {Array} ads - Liste des annonces
 */
function renderAds(ads) {
    const adsList = document.getElementById('ads-list');
    if (!adsList) return;
    
    adsList.innerHTML = '';
    
    if (ads.length === 0) {
        adsList.innerHTML = '<div class="empty-list">Aucune annonce</div>';
        return;
    }
    
    ads.forEach(ad => {
        const date = adjustTimeZone(ad.created_at);
        const timeString = formatRelativeTime(date);
        
        const item = document.createElement('div');
        item.className = 'ad-item';
        
        const priceDisplay = ad.price ? `<div class="ad-price">$${parseFloat(ad.price).toFixed(2)}</div>` : '';
        
        item.innerHTML = `
            <div class="ad-header">
                <div class="ad-title">${ad.title}</div>
                ${priceDisplay}
            </div>
            <div class="ad-content">
                ${ad.image ? `<img src="${ad.image}" class="ad-image" alt="Image">` : ''}
                <div class="ad-description">${ad.message}</div>
            </div>
            <div class="ad-footer">
                <div class="ad-author">${ad.author} · ${timeString}</div>
                <div class="ad-contact">
                    <button class="ad-call" data-number="${ad.phone_number}"><i class="fas fa-phone"></i></button>
                    <button class="ad-message" data-number="${ad.phone_number}" data-name="${ad.author}"><i class="fas fa-comment"></i></button>
                </div>
            </div>
        `;
        
        adsList.appendChild(item);
    });
    
    document.querySelectorAll('.ad-call').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            startCall(number);
        });
    });
    
    document.querySelectorAll('.ad-message').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            const name = this.dataset.name;
            openConversation(number, name);
        });
    });
}

/**
 * Reçoit une nouvelle annonce
 * @param {Object} data - Données de l'annonce
 */
function receiveAd(data) {
    if (activeScreen === 'ads-screen') {
        fetchAds();
    }
    
    if (!doNotDisturb && !airplaneMode) {
        playNotificationSound();
    }
}

/**
 * Formate le temps relatif
 * @param {Date} date - La date à formater
 * @return {string} - Temps relatif formaté
 */
function formatRelativeTime(date) {
    if (typeof date === 'string') {
        date = adjustTimeZone(date);
    }
    
    const now = new Date();
    const diffMs = now - date;
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHour = Math.floor(diffMin / 60);
    const diffDay = Math.floor(diffHour / 24);
    
    if (diffSec < 60) {
        return 'à l\'instant';
    } else if (diffMin < 60) {
        return `il y a ${diffMin} min`;
    } else if (diffHour < 24) {
        return `il y a ${diffHour} h`;
    } else if (diffDay < 7) {
        return `il y a ${diffDay} j`;
    } else {
        return date.toLocaleDateString();
    }
}

// =================================================================
// GESTION DE LA BANQUE
// =================================================================

/**
 * Configure les écouteurs d'événements pour la banque
 */
function setupBankListeners() {
    const newTransferBtn = document.getElementById('new-transfer-btn');
    if (newTransferBtn) {
        newTransferBtn.addEventListener('click', function() {
            const transferRecipient = document.getElementById('transfer-recipient');
            if (transferRecipient) transferRecipient.value = '';
            
            const transferAmount = document.getElementById('transfer-amount');
            if (transferAmount) transferAmount.value = '';
            
            const transferReason = document.getElementById('transfer-reason');
            if (transferReason) transferReason.value = '';
            
            showScreen('transfer-screen');
        });
    }
    
    const sendTransferBtn = document.getElementById('send-transfer-btn');
    if (sendTransferBtn) {
        sendTransferBtn.addEventListener('click', function() {
            const recipient = document.getElementById('transfer-recipient')?.value;
            const amount = document.getElementById('transfer-amount')?.value;
            const reason = document.getElementById('transfer-reason')?.value;
            
            if (recipient && recipient.length > 0 && amount && parseFloat(amount) > 0) {
                fetch('https://ox_phone/transferMoney', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        to: recipient,
                        amount: parseFloat(amount),
                        reason: reason || ''
                    })
                }).then(response => response.json())
                  .then(data => {
                      if (data.success) {
                          showScreen('bank-screen');
                          fetchBankData();
                      } else {
                          alert(data.message || "Erreur lors du transfert");
                      }
                  })
                  .catch(() => {});
            }
        });
    }
}

/**
 * Récupère les données bancaires
 */
function fetchBankData() {
    fetch('https://ox_phone/getBankData', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentBankData = data || { balance: 0, transactions: [] };
          renderBankData(data || { balance: 0, transactions: [] });
      })
      .catch(() => {});
}

/**
 * Affiche les données bancaires
 * @param {Object} data - Données bancaires
 */
function renderBankData(data) {
    const balanceAmount = document.getElementById('balance-amount');
    if (balanceAmount) balanceAmount.textContent = `$${parseFloat(data.balance).toFixed(2)}`;
    
    const transactionsList = document.getElementById('transactions-list');
    if (!transactionsList) return;
    
    transactionsList.innerHTML = '';
    
    if (!data.transactions || data.transactions.length === 0) {
        transactionsList.innerHTML = '<div class="empty-list">Aucune transaction</div>';
        return;
    }
    
    data.transactions.forEach(transaction => {
        const date = adjustTimeZone(transaction.date);
        const timeString = date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        const isPositive = transaction.type === 'credit' || parseFloat(transaction.amount) > 0;
        const amount = Math.abs(parseFloat(transaction.amount));
        
        const item = document.createElement('div');
        item.className = 'transaction-item';
        item.innerHTML = `
            <div class="transaction-info">
                <div class="transaction-name">${transaction.label}</div>
                <div class="transaction-date">${timeString}</div>
                ${transaction.to_number ? `<div class="transaction-recipient">Destinataire: ${transaction.to_number}</div>` : ''}
            </div>
            <div class="transaction-amount ${isPositive ? 'positive' : 'negative'}">
                ${isPositive ? '+' : '-'}$${amount.toFixed(2)}
            </div>
        `;
        
        transactionsList.appendChild(item);
    });
}

// =================================================================
// GESTION DE L'APPAREIL PHOTO ET DE LA GALERIE
// =================================================================

/**
 * Configure les écouteurs d'événements pour l'appareil photo
 */
function setupCameraListeners() {
    const takePhotoBtn = document.getElementById('take-photo-btn');
    if (takePhotoBtn) {
        takePhotoBtn.addEventListener('click', function() {
            takePhoto(false);
        });
    }
    
    const takeSelfieBtn = document.getElementById('take-selfie-btn');
    if (takeSelfieBtn) {
        takeSelfieBtn.addEventListener('click', function() {
            takePhoto(true);
        });
    }
    
    const viewGalleryBtn = document.getElementById('view-gallery-btn');
    if (viewGalleryBtn) {
        viewGalleryBtn.addEventListener('click', function() {
            showScreen('gallery-screen');
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = '';
        });
    }
}

/**
 * Prend une photo
 * @param {boolean} isSelfie - Indique s'il s'agit d'un selfie
 */
function takePhoto(isSelfie) {
    fetch('https://ox_phone/takePicture', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            selfie: isSelfie
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              fetchGallery();
              showScreen('gallery-screen');
          }
      })
      .catch(() => {});
}

/**
 * Configure les écouteurs d'événements pour les options photo
 */
function setupPhotoOptionsListeners() {
    const photoOptionsBtn = document.getElementById('photo-options-btn');
    if (photoOptionsBtn) {
        photoOptionsBtn.addEventListener('click', function() {
            const options = document.getElementById('photo-options');
            if (options) options.classList.toggle('hidden');
        });
    }
    
    const sharePhotoBtn = document.getElementById('share-photo-btn');
    if (sharePhotoBtn) {
        sharePhotoBtn.addEventListener('click', function() {
            const photoOptions = document.getElementById('photo-options');
            if (photoOptions) photoOptions.classList.add('hidden');
        });
    }
    
    const deletePhotoBtn = document.getElementById('delete-photo-btn');
    if (deletePhotoBtn) {
        deletePhotoBtn.addEventListener('click', function() {
            const photoId = document.getElementById('full-photo')?.dataset.id;
            if (!photoId) return;
            
            const photoOptions = document.getElementById('photo-options');
            if (photoOptions) photoOptions.classList.add('hidden');
            
            fetch('https://ox_phone/deletePhoto', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    photoId: photoId
                })
            });
        });
    }
}

/**
 * Récupère la galerie
 */
function fetchGallery() {
    fetch('https://ox_phone/getGallery', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentGallery = data || [];
          renderGallery(data || []);
      })
      .catch(() => {});
}

/**
 * Affiche la galerie
 * @param {Array} photos - Liste des photos
 */
function renderGallery(photos) {
    const galleryGrid = document.getElementById('gallery-grid');
    if (!galleryGrid) return;
    
    galleryGrid.innerHTML = '';
    
    if (photos.length === 0) {
        galleryGrid.innerHTML = '<div class="empty-list">Aucune photo</div>';
        return;
    }
    
    photos.forEach(photo => {
        const item = document.createElement('div');
        item.className = 'gallery-item';
        item.innerHTML = `<img src="${photo.image_url}" alt="Photo">`;
        
        item.addEventListener('click', function() {
            const selectFor = galleryGrid.dataset.selectFor;
            if (selectFor === 'tweet') {
                tweetImage = photo.image_url;
                const tweetPhoto = document.getElementById('tweet-photo');
                if (tweetPhoto) tweetPhoto.src = photo.image_url;
                
                const tweetPhotoPreview = document.getElementById('tweet-photo-preview');
                if (tweetPhotoPreview) tweetPhotoPreview.classList.remove('hidden');
                
                showScreen('new-tweet-screen');
            } else if (selectFor === 'ad') {
                adImage = photo.image_url;
                const adPhoto = document.getElementById('ad-photo');
                if (adPhoto) adPhoto.src = photo.image_url;
                
                const adPhotoPreview = document.getElementById('ad-photo-preview');
                if (adPhotoPreview) adPhotoPreview.classList.remove('hidden');
                
                showScreen('new-ad-screen');
            } else {
                const fullPhoto = document.getElementById('full-photo');
                if (fullPhoto) {
                    fullPhoto.src = photo.image_url;
                    fullPhoto.dataset.id = photo.id;
                }
                
                showScreen('photo-view-screen');
            }
        });
        
        galleryGrid.appendChild(item);
    });
}

/**
 * Affiche la confirmation de suppression d'une photo
 * @param {string} photoId - Identifiant de la photo
 */
function showDeleteConfirmation(photoId) {
    const confirmBox = document.createElement('div');
    confirmBox.className = 'delete-confirmation';
    confirmBox.innerHTML = `
        <div class="delete-confirmation-content">
            <div class="delete-confirmation-header">Confirmer la suppression</div>
            <div class="delete-confirmation-message">Êtes-vous sûr de vouloir supprimer cette photo ?</div>
            <div class="delete-confirmation-actions">
                <button class="delete-confirmation-btn cancel">Annuler</button>
                <button class="delete-confirmation-btn confirm">Supprimer</button>
            </div>
        </div>
    `;
    
    const phoneContainer = document.getElementById('phone-container');
    phoneContainer.appendChild(confirmBox);
    
    const cancelBtn = confirmBox.querySelector('.cancel');
    const confirmBtn = confirmBox.querySelector('.confirm');
    
    cancelBtn.addEventListener('click', function() {
        confirmBox.remove();
        fetch('https://ox_phone/confirmDeletePhotoAction', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                confirmed: false,
                photoId: photoId
            })
        });
    });
    
    confirmBtn.addEventListener('click', function() {
        confirmBox.remove();
        fetch('https://ox_phone/confirmDeletePhotoAction', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                confirmed: true,
                photoId: photoId
            })
        }).then(response => response.json())
          .then(data => {
              if (data.success) {
                  showScreen('gallery-screen');
                  fetchGallery();
              }
          })
          .catch(() => {});
    });
}

// =================================================================
// GESTION DE YOUTUBE
// =================================================================

/**
 * Configure les écouteurs d'événements pour YouTube
 */
function setupYouTubeListeners() {
    const youtubeSearchBtn = document.getElementById('youtube-search-btn');
    if (youtubeSearchBtn) {
        youtubeSearchBtn.addEventListener('click', function() {
            showScreen('youtube-search-screen');
        });
    }
    
    const youtubeSearchInput = document.getElementById('youtube-search-input');
    if (youtubeSearchInput) {
        youtubeSearchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const query = this.value.trim();
                if (query.length > 0) {
                    searchYouTube(query);
                }
            }
        });
    }
    
    const executeSearchBtn = document.getElementById('execute-search-btn');
    if (executeSearchBtn) {
        executeSearchBtn.addEventListener('click', function() {
            const query = document.getElementById('youtube-search-input')?.value.trim();
            if (query && query.length > 0) {
                searchYouTube(query);
            }
        });
    }
    
    const clearHistoryBtn = document.getElementById('clear-youtube-history-btn');
    if (clearHistoryBtn) {
        clearHistoryBtn.addEventListener('click', function() {
            if (confirm('Êtes-vous sûr de vouloir effacer tout l\'historique YouTube ?')) {
                clearYouTubeHistory();
            }
        });
    }
    
    const shareVideoBtn = document.getElementById('share-youtube-video-btn');
    if (shareVideoBtn) {
        shareVideoBtn.addEventListener('click', function() {
            const videoPlayer = document.getElementById('youtube-video-player');
            const videoTitle = document.getElementById('youtube-video-title');
            
            if (videoPlayer && videoPlayer.src) {
                const videoId = videoPlayer.src.split('/').pop().split('?')[0];
                const linkToShare = `https://youtu.be/${videoId}`;
                const titleToShare = videoTitle ? videoTitle.textContent : 'Vidéo YouTube';
                
                showPhoneNotification('Lien copié', 'Lien de la vidéo copié dans le presse-papier', 'info', 'fa-copy');
                
                if (confirm('Voulez-vous partager cette vidéo par message ?')) {
                    showScreen('new-message-screen');
                    const messageRecipient = document.getElementById('message-recipient');
                    if (messageRecipient) messageRecipient.focus();
                    
                    sessionStorage.setItem('pendingMessage', `${titleToShare} - ${linkToShare}`);
                }
            }
        });
    }
    
    const likeVideoBtn = document.getElementById('like-youtube-video-btn');
    if (likeVideoBtn) {
        likeVideoBtn.addEventListener('click', function() {
            const videoLikes = document.getElementById('youtube-video-likes');
            if (videoLikes) {
                const currentText = videoLikes.textContent;
                const currentLikes = parseInt(currentText.replace(/[^0-9]/g, ''));
                
                if (this.classList.contains('liked')) {
                    this.classList.remove('liked');
                    videoLikes.textContent = formatNumberWithCommas(currentLikes - 1) + ' likes';
                } else {
                    this.classList.add('liked');
                    videoLikes.textContent = formatNumberWithCommas(currentLikes + 1) + ' likes';
                }
                
                this.classList.add('animated');
                setTimeout(() => {
                    this.classList.remove('animated');
                }, 300);
            }
        });
    }
	
    const youtubeVideoScreen = document.getElementById('youtube-video-screen');
    if (youtubeVideoScreen) {
        let stopBtn = document.getElementById('youtube-stop-video-btn');
        
        if (!stopBtn) {
            stopBtn = document.createElement('button');
            stopBtn.id = 'youtube-stop-video-btn';
            stopBtn.className = 'youtube-stop-btn';
            stopBtn.innerHTML = '<i class="fas fa-stop"></i> Arrêter';
            
            const videoDetails = youtubeVideoScreen.querySelector('.youtube-video-details');
            if (videoDetails) {
                videoDetails.insertAdjacentElement('afterbegin', stopBtn);
            }
        }
        
        stopBtn.addEventListener('click', function() {
            stopYouTubeVideo();
            showScreen('youtube-screen');
        });
    }
}

/**
 * Récupère l'historique YouTube
 */
function fetchYouTubeHistory() {
    fetch('https://ox_phone/getYouTubeHistory', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          renderYouTubeHistory(data || []);
      })
      .catch(() => {});
}

/**
 * Affiche l'historique YouTube
 * @param {Array} history - Historique des vidéos YouTube
 */
function renderYouTubeHistory(history) {
    const historyList = document.getElementById('youtube-history-list');
    const trendingList = document.getElementById('youtube-trending-list');
    
    if (!historyList || !trendingList) return;
    
    historyList.innerHTML = '';
    
    if (history.length === 0) {
        historyList.innerHTML = '<div class="empty-list">Aucun historique</div>';
    } else {
        history.forEach(video => {
            const item = document.createElement('div');
            item.className = 'youtube-video-item';
            item.dataset.id = video.video_id;
            
            const date = adjustTimeZone(video.created_at);
            const timeString = formatRelativeTime(date);
            
            item.innerHTML = `
                <div class="youtube-thumbnail">
                    <img src="${video.thumbnail}" alt="Thumbnail">
                </div>
                <div class="youtube-video-info">
                    <div class="youtube-video-title">${video.title}</div>
                    <div class="youtube-video-channel">${video.channel} · ${timeString}</div>
                </div>
            `;
            
            item.addEventListener('click', function() {
                openYouTubeVideo(video.video_id);
            });
            
            historyList.appendChild(item);
        });
    }
    
    if (trendingList) {
        trendingList.innerHTML = '<div class="loading-indicator"><div class="loading-spinner"></div></div>';
        
        fetch('https://ox_phone/searchYouTube', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                query: 'popular music videos'
            })
        }).then(response => response.json())
          .then(data => {
              trendingList.innerHTML = '';
              
              if (data.success && data.results && data.results.length > 0) {
                  data.results.forEach(video => {
                      const item = document.createElement('div');
                      item.className = 'youtube-video-item';
                      item.dataset.id = video.id;
                      
                      item.innerHTML = `
                          <div class="youtube-thumbnail">
                              <img src="${video.thumbnail}" alt="Thumbnail">
                          </div>
                          <div class="youtube-video-info">
                              <div class="youtube-video-title">${video.title}</div>
                              <div class="youtube-video-channel">${video.channel}</div>
                          </div>
                      `;
                      
                      item.addEventListener('click', function() {
                          openYouTubeVideo(video.id);
                      });
                      
                      trendingList.appendChild(item);
                  });
              } else {
                  trendingList.innerHTML = '<div class="empty-list">Impossible de charger les tendances</div>';
              }
          })
          .catch(() => {
              trendingList.innerHTML = '<div class="empty-list">Erreur de chargement</div>';
          });
    }
}

/**
 * Recherche des vidéos YouTube
 * @param {string} query - Termes de recherche
 */
function searchYouTube(query) {
    const searchResults = document.getElementById('youtube-search-results');
    if (!searchResults) return;
    
    searchResults.innerHTML = '<div class="loading-indicator"><div class="loading-spinner"></div></div>';
    
    fetch('https://ox_phone/searchYouTube', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            query: query
        })
    }).then(response => response.json())
      .then(data => {
          searchResults.innerHTML = '';
          
          if (data.success && data.results && data.results.length > 0) {
              data.results.forEach(video => {
                  const item = document.createElement('div');
                  item.className = 'youtube-video-item';
                  item.dataset.id = video.id;
                  
                  item.innerHTML = `
                      <div class="youtube-thumbnail">
                          <img src="${video.thumbnail}" alt="Thumbnail">
                      </div>
                      <div class="youtube-video-info">
                          <div class="youtube-video-title">${video.title}</div>
                          <div class="youtube-video-channel">${video.channel}</div>
                      </div>
                  `;
                  
                  item.addEventListener('click', function() {
                      openYouTubeVideo(video.id);
                  });
                  
                  searchResults.appendChild(item);
              });
          } else {
              searchResults.innerHTML = '<div class="empty-list">Aucun résultat trouvé</div>';
          }
      })
      .catch(() => {
          searchResults.innerHTML = '<div class="empty-list">Erreur de recherche</div>';
      });
}

/**
 * Ouvre une vidéo YouTube
 * @param {string} videoId - Identifiant de la vidéo
 */
function openYouTubeVideo(videoId) {
    fetch('https://ox_phone/getVideoInfo', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            videoId: videoId
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success && data.video) {
              const video = data.video;
              
              const embedUrl = `https://www.youtube.com/embed/${videoId}?autoplay=1&rel=0`;
              
              const videoPlayer = document.getElementById('youtube-video-player');
              const videoTitle = document.getElementById('youtube-video-title');
              const videoChannel = document.getElementById('youtube-video-channel');
              const videoViews = document.getElementById('youtube-video-views');
              const videoLikes = document.getElementById('youtube-video-likes');
              const videoDescription = document.getElementById('youtube-video-description');
              
              if (videoPlayer) videoPlayer.src = embedUrl;
              if (videoTitle) videoTitle.textContent = video.title;
              if (videoChannel) videoChannel.textContent = video.channel;
              
              if (videoViews) videoViews.textContent = formatNumberWithCommas(video.views) + ' vues';
              if (videoLikes) videoLikes.textContent = formatNumberWithCommas(video.likes) + ' likes';
              
              if (videoDescription) videoDescription.textContent = video.description;
              
              activeYouTubeVideo = {
                  id: videoId,
                  title: video.title,
                  channel: video.channel,
                  embedUrl: embedUrl
              };
              
              updateYouTubeNowPlayingStatus();
              
              showScreen('youtube-video-screen');
              
              setTimeout(fetchYouTubeHistory, 1000);
          } else {
              showPhoneNotification('Erreur', 'Impossible de charger la vidéo', 'error', 'fa-exclamation-circle');
          }
      })
      .catch(() => {
          showPhoneNotification('Erreur', 'Impossible de charger la vidéo', 'error', 'fa-exclamation-circle');
      });
}

/**
 * Arrête la vidéo YouTube en cours
 */
function stopYouTubeVideo() {
    const videoPlayer = document.getElementById('youtube-video-player');
    if (videoPlayer) videoPlayer.src = '';
    
    activeYouTubeVideo = null;
    
    updateYouTubeNowPlayingStatus();
    
    showCustomNotification('YouTube', 'Vidéo arrêtée');
}

/**
 * Met à jour le statut de lecture YouTube
 */
function updateYouTubeNowPlayingStatus() {
    document.querySelectorAll('.now-playing-badge').forEach(badge => badge.remove());
    
    if (activeYouTubeVideo) {
        const youtubeHeader = document.querySelector('#youtube-screen .app-header');
        if (youtubeHeader) {
            const badge = document.createElement('div');
            badge.className = 'now-playing-badge';
            badge.innerHTML = `
                <div class="badge-content">
                    <i class="fas fa-play-circle"></i>
                    <span>En cours</span>
                </div>
                <button class="badge-stop-btn" id="stop-youtube-from-badge"><i class="fas fa-stop"></i></button>
            `;
            youtubeHeader.appendChild(badge);
            
            const stopBtn = document.getElementById('stop-youtube-from-badge');
            if (stopBtn) {
                stopBtn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    stopYouTubeVideo();
                });
            }
        }
        
        const youtubeAppIcon = document.querySelector('.app-icon[data-app="youtube"]');
        if (youtubeAppIcon) {
            const indicator = document.createElement('div');
            indicator.className = 'app-indicator';
            indicator.innerHTML = '<i class="fas fa-play"></i>';
            youtubeAppIcon.appendChild(indicator);
        }
    } else {
        const indicator = document.querySelector('.app-icon[data-app="youtube"] .app-indicator');
        if (indicator) indicator.remove();
    }
}


/**
 * Efface l'historique YouTube
 */
function clearYouTubeHistory() {
    fetch('https://ox_phone/clearYouTubeHistory', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              fetchYouTubeHistory();
              
              showCustomNotification('YouTube', 'Historique effacé');
          }
      })
      .catch(() => {});
}

/**
 * Formate les nombres avec des virgules
 * @param {number} number - Nombre à formater
 * @return {string} - Nombre formaté
 */
function formatNumberWithCommas(number) {
    return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// =================================================================
// GESTION DU GARAGE
// =================================================================

/**
 * Configure les écouteurs d'événements pour le garage
 */
function setupGarageEventListeners() {
    const vehicleSearch = document.getElementById('vehicle-search');
    if (vehicleSearch) {
        vehicleSearch.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            filterVehicles(searchTerm);
        });
    }
    
    const refreshVehiclesBtn = document.getElementById('refresh-vehicles-btn');
    if (refreshVehiclesBtn) {
        refreshVehiclesBtn.addEventListener('click', function() {
            fetchVehicles();
        });
    }
    
    const locateVehicleBtn = document.getElementById('locate-vehicle-btn');
    if (locateVehicleBtn) {
        locateVehicleBtn.addEventListener('click', function() {
            const plate = this.dataset.plate;
            locateVehicle(plate);
        });
    }
}

/**
 * Récupère les véhicules
 */
function fetchVehicles() {
    fetch('https://ox_phone/getVehicles', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          currentVehicles = data || [];
          renderVehicles(data || []);
      })
      .catch(() => {});
}

/**
 * Affiche les véhicules
 * @param {Array} vehicles - Liste des véhicules
 */
function renderVehicles(vehicles) {
    const vehiclesList = document.getElementById('vehicles-list');
    if (!vehiclesList) return;
    
    vehiclesList.innerHTML = '';
    
    if (vehicles.length === 0) {
        vehiclesList.innerHTML = '<div class="empty-list">Aucun véhicule</div>';
        return;
    }
    
    vehicles.forEach(vehicle => {
        let statusClass = '';
        let statusText = '';
        
        if (vehicle.pound) {
            statusClass = 'status-pound';
            statusText = 'Fourrière';
        } else if (vehicle.stored === 1) {
            statusClass = 'status-garage';
            statusText = 'Garage';
        } else if (vehicle.position) {
            statusClass = 'status-outside';
            statusText = 'Dehors';
        } else {
            statusClass = 'status-outside';
            statusText = 'Dehors';
        }
        
        const item = document.createElement('div');
        item.className = 'vehicle-item';
        item.dataset.plate = vehicle.plate;
        item.dataset.vehicle = JSON.stringify(vehicle);
        
        item.innerHTML = `
            <div class="vehicle-icon">
                <i class="fas ${vehicle.type === 'car' ? 'fa-car' : vehicle.type === 'helicopter' ? 'fa-helicopter' : 'fa-motorcycle'}"></i>
            </div>
            <div class="vehicle-info">
                <div class="vehicle-plate">${vehicle.plate}</div>
                <div class="vehicle-type">${formatVehicleType(vehicle.type)}</div>
            </div>
            <div class="vehicle-status ${statusClass}">${statusText}</div>
        `;
        
        item.addEventListener('click', function() {
            showVehicleDetails(vehicle);
        });
        
        vehiclesList.appendChild(item);
    });
}

/**
 * Formate le type de véhicule
 * @param {string} type - Type de véhicule
 * @return {string} - Type formaté
 */
function formatVehicleType(type) {
    switch(type) {
        case 'car':
            return 'Voiture';
        case 'helicopter':
            return 'Hélicoptère';
        case 'boat':
            return 'Bateau';
        case 'motorcycle':
            return 'Moto';
        default:
            return type.charAt(0).toUpperCase() + type.slice(1);
    }
}

/**
 * Filtre les véhicules
 * @param {string} searchTerm - Terme de recherche
 */
function filterVehicles(searchTerm) {
    if (!currentVehicles) return;
    
    if (!searchTerm) {
        renderVehicles(currentVehicles);
        return;
    }
    
    const filtered = currentVehicles.filter(vehicle => 
        vehicle.plate.toLowerCase().includes(searchTerm) ||
        formatVehicleType(vehicle.type).toLowerCase().includes(searchTerm)
    );
    
    renderVehicles(filtered);
}

/**
 * Affiche les détails d'un véhicule
 * @param {Object} vehicle - Données du véhicule
 */
function showVehicleDetails(vehicle) {
    const title = document.getElementById('vehicle-detail-title');
    if (title) title.textContent = vehicle.plate;
    
    const vehicleInfo = document.getElementById('vehicle-info');
    if (!vehicleInfo) return;
    
    let locationText = '';
    if (vehicle.pound) {
        locationText = 'À la fourrière: ' + vehicle.pound;
    } else if (vehicle.stored === 1) {
        locationText = 'Dans le garage: ' + (vehicle.parking || 'Inconnu');
    } else if (vehicle.position) {
        locationText = 'À l\'extérieur';
    } else {
        locationText = 'Dehors, emplacement inconnu';
    }
    
    vehicleInfo.innerHTML = `
        <div>
            <div class="info-label">Plaque</div>
            <div class="info-value">${vehicle.plate}</div>
        </div>
        <div>
            <div class="info-label">Type</div>
            <div class="info-value">${formatVehicleType(vehicle.type)}</div>
        </div>
        <div>
            <div class="info-label">État</div>
            <div class="info-value">${vehicle.body ? Math.round(vehicle.body) + '%' : 'Inconnu'}</div>
        </div>
        <div>
            <div class="info-label">Emplacement</div>
            <div class="info-value">${locationText}</div>
        </div>
    `;
    
    const locateBtn = document.getElementById('locate-vehicle-btn');
    if (locateBtn) {
        locateBtn.dataset.plate = vehicle.plate;
        
        if (vehicle.stored === 1 && !vehicle.position) {
            locateBtn.classList.add('disabled');
        } else {
            locateBtn.classList.remove('disabled');
        }
    }
    
    showScreen('vehicle-details-screen');
    activeScreen = 'vehicle-details-screen';
}

/**
 * Localise un véhicule
 * @param {string} plate - Plaque d'immatriculation
 */
function locateVehicle(plate) {
    if (!plate) return;
    
    fetch('https://ox_phone/locateVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            plate: plate
        })
    }).then(response => response.json())
      .then(data => {
          if (data.success) {
              showCustomNotification('Localisation', 'Véhicule marqué sur la carte');
          } else {
              showCustomNotification('Erreur', data.message || 'Impossible de localiser le véhicule');
          }
      })
      .catch(() => {});
}

// =================================================================
// GESTION DES ALARMES
// =================================================================

/**
 * Configure les écouteurs d'événements pour les alarmes
 */
function setupAlarmEventListeners() {
    const addAlarmBtn = document.getElementById('add-alarm-btn');
    if (addAlarmBtn) {
        addAlarmBtn.addEventListener('click', function() {
            resetAlarmForm();
            document.getElementById('alarm-form-title').textContent = 'Nouvelle alarme';
            showScreen('alarm-form-screen');
        });
    }
    
    const saveAlarmBtn = document.getElementById('save-alarm-btn');
    if (saveAlarmBtn) {
        saveAlarmBtn.addEventListener('click', function() {
            saveAlarm();
        });
    }
    
    const testAlarmSound = document.getElementById('test-alarm-sound');
    if (testAlarmSound) {
        testAlarmSound.addEventListener('click', function() {
            const sound = document.getElementById('alarm-sound').value;
            
            if (this.dataset.playing === "true") {
                stopAlarmSound();
                this.innerHTML = '<i class="fas fa-play"></i> Tester';
                this.dataset.playing = "false";
            } else {
                playAlarmSound(sound);
                this.innerHTML = '<i class="fas fa-stop"></i> Arrêter';
                this.dataset.playing = "true";
            }
        });
    }
    
    const dayItems = document.querySelectorAll('.day-item');
    if (dayItems) {
        dayItems.forEach(item => {
            item.addEventListener('click', function() {
                const checkbox = this.querySelector('.day-checkbox');
                checkbox.classList.toggle('selected');
            });
        });
    }
    
    const dismissAlarmBtn = document.getElementById('dismiss-alarm');
    if (dismissAlarmBtn) {
        dismissAlarmBtn.addEventListener('click', function() {
            const alarmId = document.getElementById('alarm-notification').dataset.alarmId;
            
            stopAlarmSound();
            
            fetch('https://ox_phone/dismissAlarm', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    alarmId: alarmId
                })
            });
            
            hideAlarmNotification();
        });
    }
    
    const snoozeAlarmBtn = document.getElementById('snooze-alarm');
    if (snoozeAlarmBtn) {
        snoozeAlarmBtn.addEventListener('click', function() {
            const alarmId = document.getElementById('alarm-notification').dataset.alarmId;
            
            stopAlarmSound();
            
            fetch('https://ox_phone/snoozeAlarm', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    alarmId: alarmId
                })
            });
            
            hideAlarmNotification();
        });
    }
    
    const closeAlarmNotification = document.getElementById('close-alarm-notification');
    if (closeAlarmNotification) {
        closeAlarmNotification.addEventListener('click', function() {
            hideAlarmNotification();
        });
    }
}

/**
 * Affiche une notification d'alarme
 * @param {Object} alarm - Données de l'alarme
 */
function showAlarmNotification(alarm) {
    const notification = document.getElementById('alarm-notification');
    const timeEl = document.getElementById('alarm-notification-time');
    const labelEl = document.getElementById('alarm-notification-label');
    
    if (notification && timeEl && labelEl) {
        notification.dataset.alarmId = alarm.id;
        timeEl.textContent = alarm.time;
        labelEl.textContent = alarm.label;
        
        notification.classList.remove('hidden');
    }
}

/**
 * Cache la notification d'alarme
 */
function hideAlarmNotification() {
    const notification = document.getElementById('alarm-notification');
    if (notification) {
        notification.classList.add('hidden');
        
        stopAlarmSound();
    }
}

/**
 * Réinitialise le formulaire d'alarme
 */
function resetAlarmForm() {
    const form = document.getElementById('alarm-form');
    if (form) {
        form.reset();
        
        stopAlarmSound();
        
        const testButton = document.getElementById('test-alarm-sound');
        if (testButton) {
            testButton.innerHTML = '<i class="fas fa-play"></i> Tester';
            testButton.dataset.playing = "false";
        }
        
        document.querySelectorAll('.day-checkbox').forEach(checkbox => {
            checkbox.classList.remove('selected');
        });
        
        document.getElementById('alarm-id').value = '';
        
        const now = new Date();
        let hours = now.getHours();
        let minutes = now.getMinutes() >= 30 ? 0 : 30;
        
        if (minutes === 0 && now.getMinutes() >= 30) {
            hours = (hours + 1) % 24;
        }
        
        const timeStr = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
        document.getElementById('alarm-time').value = timeStr;
        
        document.querySelectorAll('.day-checkbox').forEach(checkbox => {
            checkbox.classList.add('selected');
        });
    }
}

/**
 * Enregistre une alarme
 */
function saveAlarm() {
    const alarmId = document.getElementById('alarm-id').value;
    const label = document.getElementById('alarm-label').value;
    const time = document.getElementById('alarm-time').value;
    const sound = document.getElementById('alarm-sound').value;
    const repeat = document.getElementById('alarm-repeat').checked;
    const enabled = document.getElementById('alarm-enabled').checked;
    
    const selectedDays = [];
    document.querySelectorAll('.day-item').forEach(item => {
        if (item.querySelector('.day-checkbox').classList.contains('selected')) {
            selectedDays.push(item.dataset.day);
        }
    });
    
    if (!label || !time || selectedDays.length === 0) {
        return;
    }
    
    const alarmData = {
        id: alarmId || undefined,
        label: label,
        time: time,
        days: JSON.stringify(selectedDays),
        sound: sound,
        repeat_weekly: repeat,
        enabled: enabled
    };
    
    if (alarmId) {
        fetch('https://ox_phone/updateAlarm', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(alarmData)
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                fetchAlarms();
                showScreen('alarm-screen');
            }
        });
    } else {
        fetch('https://ox_phone/addAlarm', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(alarmData)
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                fetchAlarms();
                showScreen('alarm-screen');
            }
        });
    }
}

/**
 * Récupère les alarmes
 */
function fetchAlarms() {
    fetch('https://ox_phone/getAlarms', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    })
    .then(response => response.json())
    .then(alarms => {
        currentAlarms = alarms;
        renderAlarms(alarms);
    });
}

/**
 * Affiche les alarmes
 * @param {Array} alarms - Liste des alarmes
 */
function renderAlarms(alarms) {
    const alarmsList = document.getElementById('alarms-list');
    const emptyAlarms = document.getElementById('empty-alarms');
    
    if (!alarmsList) return;
    
    alarmsList.innerHTML = '';
    
    if (!alarms || alarms.length === 0) {
        if (emptyAlarms) emptyAlarms.classList.remove('hidden');
        return;
    }
    
    if (emptyAlarms) emptyAlarms.classList.add('hidden');
    
    alarms.forEach(alarm => {
        let days = [];
        try {
            days = JSON.parse(alarm.days);
        } catch (e) {
            days = [];
        }
        
        const daysText = formatDays(days);
        
        const item = document.createElement('div');
        item.className = 'alarm-item';
        item.dataset.id = alarm.id;
        
        item.innerHTML = `
            <div class="alarm-info">
                <div class="alarm-time">${alarm.time}</div>
                <div class="alarm-label">${alarm.label}</div>
                <div class="alarm-days">${daysText}</div>
            </div>
            <div class="alarm-toggle">
                <label class="switch">
                    <input type="checkbox" ${alarm.enabled ? 'checked' : ''} data-id="${alarm.id}" class="alarm-toggle-input">
                    <span class="slider"></span>
                </label>
            </div>
            <div class="alarm-actions">
                <button class="alarm-edit" data-id="${alarm.id}"><i class="fas fa-edit"></i></button>
                <button class="alarm-delete" data-id="${alarm.id}"><i class="fas fa-trash"></i></button>
            </div>
        `;
        
        alarmsList.appendChild(item);
    });
	
    document.querySelectorAll('.alarm-toggle-input').forEach(toggle => {
        toggle.addEventListener('change', function() {
            const id = this.dataset.id;
            const enabled = this.checked;
            
            toggleAlarm(id, enabled);
        });
    });
    
    document.querySelectorAll('.alarm-edit').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.dataset.id;
            editAlarm(id);
        });
    });
    
    document.querySelectorAll('.alarm-delete').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            const id = this.dataset.id;
            showAlarmDeleteConfirmation(id);
        });
    });
}

/**
 * Formate les jours
 * @param {Array} days - Liste des jours
 * @return {string} - Jours formatés
 */
function formatDays(days) {
    if (!days || days.length === 0) return 'Aucun jour';
    
    if (days.length === 7) return 'Tous les jours';
    
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const weekends = ['Saturday', 'Sunday'];
    
    let isWeekdays = weekdays.every(day => days.includes(day));
    let isWeekends = weekends.every(day => days.includes(day));
    
    if (isWeekdays && !isWeekends) return 'Jours de semaine';
    if (!isWeekdays && isWeekends) return 'Weekends';
    
    const dayMap = {
        'Monday': 'Lun',
        'Tuesday': 'Mar',
        'Wednesday': 'Mer',
        'Thursday': 'Jeu',
        'Friday': 'Ven',
        'Saturday': 'Sam',
        'Sunday': 'Dim'
    };
    
    return days.map(day => dayMap[day]).join(', ');
}

/**
 * Active/désactive une alarme
 * @param {string} id - Identifiant de l'alarme
 * @param {boolean} enabled - État de l'alarme
 */
function toggleAlarm(id, enabled) {
    const alarm = currentAlarms.find(a => a.id == id);
    if (!alarm) return;
    
    fetch('https://ox_phone/updateAlarm', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            id: id,
            enabled: enabled,
            label: alarm.label,
            time: alarm.time,
            days: alarm.days,
            sound: alarm.sound,
            repeat_weekly: alarm.repeat_weekly
        })
    });
}

/**
 * Édite une alarme
 * @param {string} id - Identifiant de l'alarme
 */
function editAlarm(id) {
    const alarm = currentAlarms.find(a => a.id == id);
    if (!alarm) return;
    
    document.getElementById('alarm-id').value = alarm.id;
    document.getElementById('alarm-label').value = alarm.label;
    document.getElementById('alarm-time').value = alarm.time;
    document.getElementById('alarm-sound').value = alarm.sound;
    document.getElementById('alarm-repeat').checked = alarm.repeat_weekly;
    document.getElementById('alarm-enabled').checked = alarm.enabled;
    
    let days = [];
    try {
        days = JSON.parse(alarm.days);
    } catch (e) {
        days = [];
    }
    
    document.querySelectorAll('.day-item').forEach(item => {
        const day = item.dataset.day;
        const checkbox = item.querySelector('.day-checkbox');
        
        if (days.includes(day)) {
            checkbox.classList.add('selected');
        } else {
            checkbox.classList.remove('selected');
        }
    });
    
    document.getElementById('alarm-form-title').textContent = 'Modifier l\'alarme';
    showScreen('alarm-form-screen');
}

/**
 * Affiche la confirmation de suppression d'alarme
 * @param {string} alarmId - Identifiant de l'alarme
 */
function showAlarmDeleteConfirmation(alarmId) {
    const confirmBox = document.createElement('div');
    confirmBox.className = 'delete-confirmation';
    confirmBox.innerHTML = `
        <div class="delete-confirmation-content">
            <div class="delete-confirmation-header">Confirmer la suppression</div>
            <div class="delete-confirmation-message">Êtes-vous sûr de vouloir supprimer cette alarme ?</div>
            <div class="delete-confirmation-actions">
                <button class="delete-confirmation-btn cancel">Annuler</button>
                <button class="delete-confirmation-btn confirm">Supprimer</button>
            </div>
        </div>
    `;
    
    const phoneContainer = document.getElementById('phone-container');
    phoneContainer.appendChild(confirmBox);
    
    const cancelBtn = confirmBox.querySelector('.cancel');
    const confirmBtn = confirmBox.querySelector('.confirm');
    
    cancelBtn.addEventListener('click', function() {
        confirmBox.remove();
        fetch('https://ox_phone/confirmDeleteAlarmAction', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                confirmed: false,
                alarmId: alarmId
            })
        });
    });
    
    confirmBtn.addEventListener('click', function() {
        confirmBox.remove();
        fetch('https://ox_phone/confirmDeleteAlarmAction', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                confirmed: true,
                alarmId: alarmId
            })
        }).then(response => response.json())
          .then(data => {
              if (data.success) {
                  showScreen('alarm-screen');
                  fetchAlarms();
              }
          })
          .catch(() => {});
    });
}

// =================================================================
// GESTION DES SERVICES D'URGENCE
// =================================================================

/**
 * Récupère la liste des services d'urgence
 */
function fetchEmergencyServices() {
    fetch('https://ox_phone/getEmergencyServices', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(services => {
          window.emergencyServices = services;
          renderEmergencyServices(services);
      })
      .catch(() => {});
}

/**
 * Affiche la liste des services d'urgence
 * @param {Array} services - Liste des services
 */
function renderEmergencyServices(services) {
    const servicesList = document.getElementById('emergency-services-list');
    if (!servicesList) return;
    
    servicesList.innerHTML = '';
    
    if (services.length === 0) {
        servicesList.innerHTML = '<div class="empty-list">Aucun service disponible</div>';
        return;
    }
    
    services.forEach(service => {
        const item = document.createElement('div');
        item.className = 'service-item';
        item.innerHTML = `
            <div class="service-icon">
                <img src="${service.icon}" alt="${service.label}">
            </div>
            <div class="service-info">
                <div class="service-name">${service.label}</div>
                <div class="service-number">${service.number}</div>
                <div class="service-description">${service.description || ''}</div>
            </div>
            <button class="service-call-btn" data-number="${service.number}">
                <i class="fas fa-phone"></i>
            </button>
        `;
        
        servicesList.appendChild(item);
    });
    
    document.querySelectorAll('.service-call-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const number = this.dataset.number;
            callEmergencyService(number);
        });
    });
    
    document.querySelectorAll('.service-item').forEach(item => {
        item.addEventListener('click', function() {
            const callBtn = this.querySelector('.service-call-btn');
            if (callBtn) {
                const number = callBtn.dataset.number;
                callEmergencyService(number);
            }
        });
    });
    
    const serviceSearch = document.getElementById('service-search');
    if (serviceSearch) {
        serviceSearch.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            filterEmergencyServices(searchTerm, services);
        });
    }
}

/**
 * Filtre les services d'urgence
 * @param {string} searchTerm - Terme de recherche
 * @param {Array} services - Liste des services
 */
function filterEmergencyServices(searchTerm, services) {
    if (!searchTerm) {
        renderEmergencyServices(services);
        return;
    }
    
    const filtered = services.filter(service => 
        service.label.toLowerCase().includes(searchTerm) ||
        service.number.includes(searchTerm) ||
        (service.description && service.description.toLowerCase().includes(searchTerm))
    );
    
    renderEmergencyServices(filtered);
}

/**
 * Appelle un service d'urgence
 * @param {string} number - Numéro du service
 */
function callEmergencyService(number) {
    fetch('https://ox_phone/callEmergencyService', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({ number: number })
    }).catch(() => {});
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel en cours...';
    
    const service = findServiceByNumber(number);
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = service ? service.label : number;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = number;
    
    const callDurationElement = document.getElementById('call-duration');
    if (callDurationElement) callDurationElement.textContent = '00:00';
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    showScreen('calling-screen');
}

/**
 * Trouve un service par son numéro
 * @param {string} number - Numéro du service
 * @return {Object} - Service correspondant
 */
function findServiceByNumber(number) {
    if (window.emergencyServices) {
        return window.emergencyServices.find(service => service.number === number);
    }
    return null;
}

// =================================================================
// GESTION DE L'APPLICATION AGENT
// =================================================================

/**
 * Affiche l'écran de l'application Agent
 */
function renderAgentScreen() {
    if (!agentAppData) return;
    
    const statusInfo = document.getElementById('agent-status-info');
    const actionButtons = document.getElementById('agent-action-buttons');
    
    statusInfo.innerHTML = `
        <h2>${agentAppData.jobLabel}</h2>
        <div class="agent-info">
            <div class="agent-info-row">
                <span>Numéro de service:</span>
                <span>${agentAppData.servicePhone}</span>
            </div>
            <div class="agent-info-row">
                <span>Agent en service:</span>
                <span id="current-agent">${agentAppData.currentAgent || 'Aucun'}</span>
            </div>
        </div>
    `;
    
    if (agentAppData.hasServicePhone) {
        actionButtons.innerHTML = `
            <div class="service-phone-actions">
                <button id="return-service-phone" class="btn-danger">
                    <i class="fas fa-phone-slash"></i> Rendre le téléphone de service
                </button>
            </div>
            <div class="notification-section">
                <h3>Envoyer une notification publique</h3>
                <div class="status-buttons">
                    <button id="notify-onduty" class="btn-primary">
                        <i class="fas fa-check-circle"></i> En service
                    </button>
                    <button id="notify-onbreak" class="btn-secondary">
                        <i class="fas fa-coffee"></i> En pause
                    </button>
                    <button id="notify-offduty" class="btn-danger">
                        <i class="fas fa-times-circle"></i> Hors service
                    </button>
                </div>
                <div class="custom-notification">
                    <input type="text" id="custom-notification-text" placeholder="Message personnalisé...">
                    <button id="send-custom-notification" class="btn-primary">
                        <i class="fas fa-paper-plane"></i> Envoyer
                    </button>
                </div>
            </div>
        `;
        
        document.getElementById('return-service-phone').addEventListener('click', returnServicePhone);
        document.getElementById('notify-onduty').addEventListener('click', () => sendAgentNotification('onDuty'));
        document.getElementById('notify-onbreak').addEventListener('click', () => sendAgentNotification('onBreak'));
        document.getElementById('notify-offduty').addEventListener('click', () => sendAgentNotification('offDuty'));
        document.getElementById('send-custom-notification').addEventListener('click', sendCustomNotification);
        
    } else {
        actionButtons.innerHTML = `
            <div class="service-phone-actions">
                <button id="take-service-phone" class="btn-primary ${agentAppData.currentAgent ? 'disabled' : ''}">
                    <i class="fas fa-phone"></i> Prendre le téléphone de service
                </button>
            </div>
        `;
        
        const takeButton = document.getElementById('take-service-phone');
        if (!agentAppData.currentAgent) {
            takeButton.addEventListener('click', takeServicePhone);
        }
    }
}

/**
 * Prend le téléphone de service
 */
function takeServicePhone() {
    fetch('https://ox_phone/takeServicePhone', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showCustomNotification('Agent', data.message, 'success');
        } else {
            showPhoneNotification('Agent', data.message, 'error', 'fa-user-tie');
        }
    })
    .catch(() => {});
}

/**
 * Rend le téléphone de service
 */
function returnServicePhone() {
    fetch('https://ox_phone/returnServicePhone', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showCustomNotification('Agent', data.message, 'success');
        } else {
            showPhoneNotification('Agent', data.message, 'error', 'fa-user-tie');
        }
    })
    .catch(() => {});
}

/**
 * Envoie une notification agent
 * @param {string} type - Type de notification
 */
function sendAgentNotification(type) {
    fetch('https://ox_phone/sendAgentNotification', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            type: type
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showPhoneNotification('Agent', 'Notification envoyée avec succès', 'success', 'fa-check-circle');
        } else {
            showPhoneNotification('Agent', data.message, 'error', 'fa-user-tie');
        }
    })
    .catch(() => {});
}

/**
 * Envoie une notification personnalisée
 */
function sendCustomNotification() {
    const message = document.getElementById('custom-notification-text').value.trim();
    
    if (!message) {
        showCustomNotification('Agent', 'Veuillez entrer un message', 'error');
        return;
    }
    
    fetch('https://ox_phone/sendAgentNotification', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            type: 'custom',
            customMessage: message
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            document.getElementById('custom-notification-text').value = '';
            showPhoneNotification('Agent', 'Notification envoyée avec succès', 'success', 'fa-check-circle');
        } else {
            showPhoneNotification('Agent', data.message, 'error', 'fa-user-tie');
        }
    })
    .catch(() => {});
}

/**
 * Affiche une notification publique agent
 * @param {string} jobLabel - Libellé du métier
 * @param {string} message - Message à afficher
 * @param {string} imagePath - Chemin de l'image
 */

// Variable pour suivre la dernière notification agent
let lastAgentNotification = {
    time: 0,
    message: '',
    job: ''
};

// Modifier la fonction existante
function showAgentPublicNotification(jobLabel, message, imagePath) {
    // Vérifier si c'est la même notification récente
    const now = Date.now();
    if (now - lastAgentNotification.time < 5000 && 
        lastAgentNotification.message === message && 
        lastAgentNotification.job === jobLabel) {
        return;
    }
    
    // Mettre à jour le suivi
    lastAgentNotification = {
        time: now,
        message: message,
        job: jobLabel
    };
    
    // Utiliser le nouveau système de notification unifiée
    showPhoneNotification(jobLabel, message, 'info', imagePath, 8000, true);
}


/**
 * Cache la notification publique agent
 */
function hideAgentPublicNotification() {
    // Cette fonction est maintenue pour la compatibilité
    // Les notifications sont désormais gérées par le système unifié
}

// =================================================================
// GESTION DES PARAMÈTRES
// =================================================================

/**
 * Configure les écouteurs d'événements pour les paramètres
 */
function setupSettingsListeners() {
    const changeWallpaperBtn = document.getElementById('change-wallpaper-btn');
    if (changeWallpaperBtn) {
        changeWallpaperBtn.addEventListener('click', function() {
            showScreen('wallpaper-screen');
        });
    }
    
    document.querySelectorAll('.wallpaper-item').forEach(item => {
        item.addEventListener('click', function() {
            const wallpaper = this.dataset.wallpaper;
            setWallpaper(wallpaper);
            showScreen('settings-screen');
        });
    });
    
    const changeRingtoneBtn = document.getElementById('change-ringtone-btn');
    if (changeRingtoneBtn) {
        changeRingtoneBtn.addEventListener('click', function() {
            showScreen('ringtone-screen');
        });
    }
    
    document.querySelectorAll('.ringtone-item').forEach(item => {
        item.addEventListener('click', function() {
            const ringtone = this.dataset.ringtone;
            setRingtone(ringtone);
        });
    });
    
    document.querySelectorAll('.ringtone-item .play-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const ringtone = this.closest('.ringtone-item')?.dataset.ringtone;
            if (ringtone) playSound(ringtone);
        });
    });
    
    const changeNotificationBtn = document.getElementById('change-notification-btn');
    if (changeNotificationBtn) {
        changeNotificationBtn.addEventListener('click', function() {
            showScreen('notification-sound-screen');
        });
    }
    
    document.querySelectorAll('.notification-item').forEach(item => {
        item.addEventListener('click', function() {
            const notification = this.dataset.notification;
            setNotificationSound(notification);
        });
    });
    
    document.querySelectorAll('.notification-item .play-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const notification = this.closest('.notification-item')?.dataset.notification;
            if (notification) playSound(notification);
        });
    });
    
    const themeSelect = document.getElementById('theme-select');
    if (themeSelect) {
        themeSelect.addEventListener('change', function() {
            setTheme(this.value);
        });
    }
    
    const dndToggle = document.getElementById('dnd-toggle');
    if (dndToggle) {
        dndToggle.addEventListener('change', function() {
            setDoNotDisturb(this.checked);
        });
    }
    
    const airplaneToggle = document.getElementById('airplane-toggle');
    if (airplaneToggle) {
        airplaneToggle.addEventListener('change', function() {
            setAirplaneMode(this.checked);
        });
    }
}

/**
 * Récupère les paramètres
 */
function fetchSettings() {
    fetch('https://ox_phone/getSettings', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          setWallpaper(data.background || Config.DefaultBackground);
          setRingtone(data.ringtone || Config.DefaultRingtone);
          setNotificationSound(data.notification_sound || 'notification1');
          setTheme(data.theme || 'default');
          setDoNotDisturb(data.do_not_disturb || false);
          setAirplaneMode(data.airplane_mode || false);
          
          const themeSelect = document.getElementById('theme-select');
          if (themeSelect) themeSelect.value = data.theme || 'default';
          
          const dndToggle = document.getElementById('dnd-toggle');
          if (dndToggle) dndToggle.checked = data.do_not_disturb || false;
          
          const airplaneToggle = document.getElementById('airplane-toggle');
          if (airplaneToggle) airplaneToggle.checked = data.airplane_mode || false;
          
          setTimeout(function() {
              document.querySelectorAll('.wallpaper-item').forEach(item => {
                  if (item.dataset.wallpaper === currentWallpaper) {
                      item.classList.add('selected');
                  } else {
                      item.classList.remove('selected');
                  }
              });
              
              document.querySelectorAll('.ringtone-item').forEach(item => {
                  if (item.dataset.ringtone === currentRingtone) {
                      item.classList.add('selected');
                  } else {
                      item.classList.remove('selected');
                  }
              });
              
              document.querySelectorAll('.notification-item').forEach(item => {
                  if (item.dataset.notification === currentNotificationSound) {
                      item.classList.add('selected');
                  } else {
                      item.classList.remove('selected');
                  }
              });
          }, 200);
      })
      .catch(() => {});
}

/**
 * Définit le fond d'écran
 * @param {string} wallpaper - Nom du fond d'écran
 */
function setWallpaper(wallpaper) {
    currentWallpaper = wallpaper;
    
    const homeScreen = document.getElementById('home-screen');
    if (homeScreen) homeScreen.style.backgroundImage = `url('images/wallpapers/${wallpaper}.jpg')`;
    
    document.querySelectorAll('.wallpaper-item').forEach(item => {
        if (item.dataset.wallpaper === wallpaper) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
    
    saveSettings();
}

/**
 * Définit la sonnerie
 * @param {string} ringtone - Nom de la sonnerie
 */
function setRingtone(ringtone) {
    currentRingtone = ringtone;
    
    document.querySelectorAll('.ringtone-item').forEach(item => {
        if (item.dataset.ringtone === ringtone) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
    
    saveSettings();
}

/**
 * Définit le son de notification
 * @param {string} sound - Nom du son
 */
function setNotificationSound(sound) {
    currentNotificationSound = sound;
    
    document.querySelectorAll('.notification-item').forEach(item => {
        if (item.dataset.notification === sound) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
    
    saveSettings();
}

/**
 * Définit le thème
 * @param {string} theme - Nom du thème
 */
function setTheme(theme) {
    currentTheme = theme;
    document.body.dataset.theme = theme;
    
    saveSettings();
}

/**
 * Définit le mode "Ne pas déranger"
 * @param {boolean} value - État du mode
 */
function setDoNotDisturb(value) {
    doNotDisturb = value;
    
    saveSettings();
}

/**
 * Définit le mode avion
 * @param {boolean} value - État du mode
 */
function setAirplaneMode(value) {
    airplaneMode = value;
    
    saveSettings();
}

/**
 * Enregistre les paramètres
 */
function saveSettings() {
    fetch('https://ox_phone/updateSettings', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            settings: {
                background: currentWallpaper,
                ringtone: currentRingtone,
                notification_sound: currentNotificationSound,
                theme: currentTheme,
                do_not_disturb: doNotDisturb,
                airplane_mode: airplaneMode
            }
        })
    }).catch(() => {});
}

/**
 * Joue un son
 * @param {string} sound - Nom du son
 * @returns {HTMLAudioElement|null} - L'élément audio
 */
function playSound(sound) {
    if (!sound) return null;
    
    try {
        const audio = new Audio(`sounds/${sound}.ogg`);
        
        audio.volume = 1.0;
        
        audio.play().catch(() => {
            const mp3Audio = new Audio(`sounds/${sound}.mp3`);
            mp3Audio.volume = 1.0;
            mp3Audio.play().catch(() => {
                try {
                    fetch('https://ox_phone/playSound', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            sound: sound
                        })
                    }).catch(() => {});
                } catch (e) {}
            });
        });
        
        return audio;
    } catch (e) {
        return null;
    }
}

// Gestion de la touche Échap pour fermer le téléphone
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch('https://ox_phone/closePhone', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            }
        }).catch(() => {});
    }
});