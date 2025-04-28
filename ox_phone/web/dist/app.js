// ox_phone/web/dist/app.js
let phoneNumber = null;
let playerIdentifier = null;
let activeScreen = 'home-screen';
let currentWallpaper = 'background1';
let currentRingtone = 'ringtone1';
let currentNotificationSound = 'notification1';
let currentTheme = 'default';
let doNotDisturb = false;
let airplaneMode = false;
let currentContacts = [];
let currentMessages = [];
let currentTweets = [];
let currentAds = [];
let currentGallery = [];
let currentBankData = { balance: 0, transactions: [] };
let currentCallHistory = [];
let activeCallId = null;
let activeCallNumber = null;
let callTimer = null;
let callDuration = 0;
let tweetImage = null;
let adImage = null;
let ringtoneAudio = null;
let notificationAudio = null;
// Variable pour suivre l'intervalle de rafraîchissement
let conversationRefreshInterval = null;

// Fonctions d'initialisation et de gestion des messages
document.addEventListener('DOMContentLoaded', function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch (data.action) {
            case 'openPhone':
                openPhone(data);
                break;
            case 'closePhone':
                closePhone();
                break;
			case 'playNotificationSound':
            // Jouer le son spécifié ou le son par défaut
            if (!doNotDisturb && !airplaneMode) {
                if (data.sound) {
                    currentNotificationSound = data.sound;
                }
                playNotificationSound();
            }
            break;
			
			case 'showSmsNotification':
                showSmsNotification(data);
            break;


            case 'newMessage':
                receiveMessage(data);
                // Déclencher immédiatement un rafraîchissement si l'écran de conversation est ouvert
                if (activeScreen === 'conversation-screen') {
                    const conversationTitle = document.getElementById('conversation-title');
                    if (conversationTitle && conversationTitle.dataset.number === data.sender) {
                        refreshCurrentConversation(data.sender);
                    }
                }
                break;

            case 'outgoingCallStarted':
                activeCallId = data.callId;
                console.log("Call ID set for outgoing call: " + activeCallId);
                break;
            case 'incomingCall':
                incomingCall(data);
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
        }
    });
    
    // Écouter les événements de base
    setupEventListeners();
    
    // Mettre à jour l'heure en temps réel
    updateClock();
    setInterval(updateClock, 1000);
    
    // Ajouter les styles pour les éléments sélectionnés
    addSelectionStyles();
});

// Fonction pour ajouter les styles CSS nécessaires
function addSelectionStyles() {
    const style = document.createElement('style');
    style.textContent = `
        /* Style pour les messages sélectionnés */
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
        
        /* Style pour les appels sélectionnés */
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
        
        /* Style pour le bouton de suppression */
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
        
        /* Style pour la notification personnalisée */
        .custom-notification {
            position: fixed;
            top: 20px;
            right: 20px;
            background-color: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 15px;
            border-radius: 5px;
            max-width: 300px;
            transform: translateX(110%);
            transition: transform 0.3s ease;
            z-index: 9999;
        }
        
        .custom-notification.show {
            transform: translateX(0);
        }
        
        .notification-title {
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .notification-message {
            font-size: 14px;
        }
        
        /* Amélioration pour les messages */
        .message-bubble.new {
            animation: newMessagePop 0.3s ease-out;
        }
        
        @keyframes newMessagePop {
            0% { transform: scale(0.8); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
        }
    `;
    
    document.head.appendChild(style);
}

// Ouvrir le téléphone
function openPhone(data) {
    document.getElementById('phone-container').style.display = 'block';
    
    // Définir phoneOpen à true
    phoneOpen = true;
    
    // Définir le numéro de téléphone
    phoneNumber = data.phoneNumber;
    document.getElementById('phone-number').textContent = phoneNumber;

    
    // Charger les paramètres
    fetchSettings();
    
    // Générer les icônes d'applications
    generateAppIcons(data.apps);
    
    // Afficher l'écran d'accueil
    showScreen('home-screen');
}

// Fermer le téléphone
function closePhone() {
    if (!phoneOpen) {
        return;
    }
    
    phoneOpen = false;
    
    // Arrêter l'intervalle de rafraîchissement lorsque le téléphone est fermé
    if (conversationRefreshInterval) {
        clearInterval(conversationRefreshInterval);
        conversationRefreshInterval = null;
    }
    
    // Masquer l'interface du téléphone
    document.getElementById('phone-container').style.display = 'none';
    
    // Arrêter les minuteries et les sons
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    // Arrêter la sonnerie si en cours
    stopRingtone();
    stopNotificationSound();
}

// Afficher un écran spécifique
function showScreen(screenId) {
    // Vérifier que l'écran actif existe
    const currentScreen = document.getElementById(activeScreen);
    if (currentScreen) {
        currentScreen.classList.remove('active');
    } else {
        console.error(`L'écran actif '${activeScreen}' n'existe pas.`);
    }
    
    // Vérifier que le nouvel écran existe
    const newScreen = document.getElementById(screenId);
    if (!newScreen) {
        console.error(`L'écran '${screenId}' n'existe pas.`);
        return;
    }
    
    // Afficher le nouvel écran
    newScreen.classList.add('active');
    
    // Mettre à jour l'écran actif
    activeScreen = screenId;
    
    // Actions spécifiques en fonction de l'écran
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
            break;
        case 'ads-screen':
            fetchAds();
            break;
        case 'bank-screen':
            fetchBankData();
            break;
        case 'gallery-screen':
            fetchGallery();
            break;
    }
}

// Mettre à jour l'heure
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
}

// Générer les icônes d'applications
function generateAppIcons(apps) {
    const appGrid = document.getElementById('app-grid');
    if (!appGrid) return;
    
    appGrid.innerHTML = '';
    
    apps.forEach(app => {
        const appIcon = document.createElement('div');
        appIcon.className = 'app-icon';
        appIcon.dataset.app = app.name;
        
        const icon = document.createElement('i');
        icon.className = app.icon;
        icon.style.color = getAppColor(app.name);
        
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

// Obtenir la couleur pour une application
function getAppColor(appName) {
    const colors = {
        'contacts': '#4CAF50',
        'messages': '#2196F3',
        'calls': '#F44336',
        'camera': '#FF9800',
        'bank': '#795548',
        'twitter': '#00acee',
        'ads': '#9C27B0',
        'settings': '#607D8B',
        'mdt': '#3F51B5',
        'emergency': '#F44336',
        'mechanic': '#FFC107'
    };
    
    return colors[appName] || '#FFFFFF';
}

// Ouvrir une application
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
        case 'settings':
            showScreen('settings-screen');
            break;
        case 'mdt':
            // À compléter selon le MDT
            break;
        case 'emergency':
            // À compléter selon votre système d'urgence
            break;
        case 'mechanic':
            // À compléter selon votre système de mécanicien
            break;
    }
    
    // Envoyer un événement NUI au client
    fetch('https://ox_phone/openApp', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            app: appName
        })
    }).catch(error => console.error('Erreur lors de l\'ouverture de l\'application:', error));
}

// Configuration des écouteurs d'événements
function setupEventListeners() {
    // Bouton retour pour chaque écran
    document.querySelectorAll('.back-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const parentScreen = this.closest('.screen')?.id;
            if (!parentScreen) return;
            
            // Logique de retour spécifique selon l'écran
            switch (parentScreen) {
                case 'contacts-screen':
                case 'messages-screen':
                case 'phone-app-screen':
                case 'twitter-screen':
                case 'ads-screen':
                case 'bank-screen':
                case 'camera-screen':
                case 'settings-screen':
                    showScreen('home-screen');
                    break;
                case 'conversation-screen':
    // Arrêter l'intervalle de rafraîchissement quand on quitte la conversation
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
            }
        });
    });
    
    // Bouton d'accueil
    const homeBtn = document.getElementById('home-btn');
    if (homeBtn) {
        homeBtn.addEventListener('click', function() {
            // Si un appel est en cours, ne pas quitter l'écran d'appel
            if (activeScreen === 'calling-screen' && activeCallId) {
                return;
            }
            
            showScreen('home-screen');
        });
    }
    
    setupContactsEventListeners();
    setupMessagesEventListeners();
    setupPhoneEventListeners();
    setupTwitterEventListeners();
    setupAdsEventListeners();
    setupCallHistoryEventListeners();
    setupSettingsListeners();
    setupPhotoOptionsListeners();
    setupBankListeners();
    setupCameraListeners();
}

// Contacts event listeners
function setupContactsEventListeners() {
    // Ajouter un contact
    const addContactBtn = document.getElementById('add-contact-btn');
    if (addContactBtn) {
        addContactBtn.addEventListener('click', function() {
            // Réinitialiser le formulaire
            const contactForm = document.getElementById('contact-form');
            if (contactForm) contactForm.reset();
            
            const contactId = document.getElementById('contact-id');
            if (contactId) contactId.value = '';
            
            const contactFormTitle = document.getElementById('contact-form-title');
            if (contactFormTitle) contactFormTitle.textContent = 'Nouveau contact';
            
            showScreen('contact-form-screen');
        });
    }
    
    // Enregistrer un contact
    const saveContactBtn = document.getElementById('save-contact-btn');
    if (saveContactBtn) {
        saveContactBtn.addEventListener('click', function() {
            const contactId = document.getElementById('contact-id')?.value;
            const name = document.getElementById('contact-name')?.value;
            const number = document.getElementById('contact-number')?.value;
            
            if (!name || !number) {
                return; // Validation simple
            }
            
            // Ajouter ou mettre à jour le contact
            if (contactId) {
                // Mise à jour d'un contact existant (non implémenté dans ce script)
            } else {
                // Nouveau contact
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
                          fetchContacts(); // Rafraîchir la liste
                      }
                  })
                  .catch(error => console.error('Erreur lors de l\'ajout du contact:', error));
            }
        });
    }
    
    // Recherche de contacts
    const contactSearch = document.getElementById('contact-search');
    if (contactSearch) {
        contactSearch.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            filterContacts(searchTerm);
        });
    }
}

// Messages event listeners
function setupMessagesEventListeners() {
    // Nouveau message
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
    
    // Recherche de destinataire pour un message
    const messageRecipient = document.getElementById('message-recipient');
    if (messageRecipient) {
        messageRecipient.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            const suggestionsContainer = document.getElementById('contacts-suggestions');
            if (!suggestionsContainer) return;
            
            suggestionsContainer.innerHTML = '';
            
            const continueMessageBtn = document.getElementById('continue-message-btn');
            
            if (searchTerm.length < 2) {
                if (continueMessageBtn) continueMessageBtn.classList.add('disabled');
                return;
            }
            
            // Filtrer les contacts correspondants
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
                // Si c'est un numéro valide
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
        });
    }
    
    // Continuer vers la conversation
    const continueMessageBtn = document.getElementById('continue-message-btn');
    if (continueMessageBtn) {
        continueMessageBtn.addEventListener('click', function() {
            if (!this.classList.contains('disabled')) {
                const recipient = document.getElementById('message-recipient')?.value;
                if (recipient && recipient.match(/^\d+$/) && recipient.length >= 3) {
                    // Chercher si c'est un contact existant
                    const contact = currentContacts.find(c => c.phone_number === recipient);
                    openConversation(recipient, contact ? contact.display_name : null);
                }
            }
        });
    }
    
    // Envoyer un message
    const sendMessageBtn = document.getElementById('send-message-btn');
    if (sendMessageBtn) {
        sendMessageBtn.addEventListener('click', function() {
            sendMessage();
        });
    }
    
    // Envoyer avec Entrée
    const newMessageInput = document.getElementById('new-message-input');
    if (newMessageInput) {
        newMessageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
    }
    
    // Écouter les clics sur les messages pour la sélection
    document.addEventListener('click', function(e) {
        if (e.target.closest('.message-bubble')) {
            const bubble = e.target.closest('.message-bubble');
            // Toggle sélection du message
            bubble.classList.toggle('selected');
            
            // Afficher ou masquer le bouton de suppression
            const selectedMessages = document.querySelectorAll('.message-bubble.selected');
            
            // Vérifier si on est sur l'écran de conversation
            const conversationHeader = document.querySelector('.conversation-screen .app-header');
            if (!conversationHeader) return;
            
            let deleteBtn = document.getElementById('delete-messages-btn');
            
            if (selectedMessages.length > 0) {
                // Créer le bouton de suppression s'il n'existe pas
                if (!deleteBtn) {
                    deleteBtn = document.createElement('button');
                    deleteBtn.id = 'delete-messages-btn';
                    deleteBtn.className = 'delete-btn';
                    deleteBtn.innerHTML = '<i class="fas fa-trash"></i>';
                    deleteBtn.onclick = function() {
                        deleteSelectedMessages();
                    };
                    
                    conversationHeader.appendChild(deleteBtn);
                }
            } else if (deleteBtn) {
                // Supprimer le bouton s'il n'y a plus de messages sélectionnés
                deleteBtn.remove();
            }
        }
    });
}

// Phone event listeners
function setupPhoneEventListeners() {
    // Touches du clavier numérique
    document.querySelectorAll('.dialer-key').forEach(key => {
        key.addEventListener('click', function() {
            const digit = this.dataset.key;
            const display = document.getElementById('dialed-number');
            if (display) display.value += digit;
        });
    });
    
    // Supprimer un chiffre
    const deleteDigitBtn = document.getElementById('delete-digit-btn');
    if (deleteDigitBtn) {
        deleteDigitBtn.addEventListener('click', function() {
            const display = document.getElementById('dialed-number');
            if (display) display.value = display.value.slice(0, -1);
        });
    }
    
    // Démarrer un appel
    const startCallBtn = document.getElementById('start-call-btn');
    if (startCallBtn) {
        startCallBtn.addEventListener('click', function() {
            const number = document.getElementById('dialed-number')?.value;
            if (number && number.length > 0) {
                startCall(number);
            }
        });
    }
    
    // Répondre à un appel
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) {
        answerCallBtn.addEventListener('click', function() {
            answerCall();
        });
    }
    
    // Terminer un appel
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) {
        endCallBtn.addEventListener('click', function() {
            endCall();
        });
    }
    
    // Voir l'historique des appels
    const callHistoryBtn = document.getElementById('call-history-btn');
    if (callHistoryBtn) {
        callHistoryBtn.addEventListener('click', function() {
            showScreen('call-history-screen');
        });
    }
    
    // Appeler depuis un message
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

// Twitter event listeners
function setupTwitterEventListeners() {
    // Nouveau tweet
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
    
    // Compteur de caractères pour le tweet
    const tweetContent = document.getElementById('tweet-content');
    if (tweetContent) {
        tweetContent.addEventListener('input', function() {
            const count = this.value.length;
            const tweetCharCount = document.getElementById('tweet-char-count');
            if (tweetCharCount) tweetCharCount.textContent = `${count}/280`;
        });
    }
    
    // Ajouter une photo au tweet
    const tweetAddPhoto = document.getElementById('tweet-add-photo');
    if (tweetAddPhoto) {
        tweetAddPhoto.addEventListener('click', function() {
            showScreen('gallery-screen');
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = 'tweet';
        });
    }
    
    // Supprimer la photo du tweet
    const tweetRemovePhoto = document.getElementById('tweet-remove-photo');
    if (tweetRemovePhoto) {
        tweetRemovePhoto.addEventListener('click', function() {
            tweetImage = null;
            const tweetPhotoPreview = document.getElementById('tweet-photo-preview');
            if (tweetPhotoPreview) tweetPhotoPreview.classList.add('hidden');
        });
    }
    
    // Envoyer un tweet
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
                          fetchTweets(); // Rafraîchir la liste
                      }
                  })
                  .catch(error => console.error('Erreur lors de l\'envoi du tweet:', error));
            }
        });
    }
}

// Ads event listeners
function setupAdsEventListeners() {
    // Nouvelle annonce
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
    
    // Ajouter une photo à l'annonce
    const adAddPhoto = document.getElementById('ad-add-photo');
    if (adAddPhoto) {
        adAddPhoto.addEventListener('click', function() {
            showScreen('gallery-screen');
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = 'ad';
        });
    }
    
    // Supprimer la photo de l'annonce
    const adRemovePhoto = document.getElementById('ad-remove-photo');
    if (adRemovePhoto) {
        adRemovePhoto.addEventListener('click', function() {
            adImage = null;
            const adPhotoPreview = document.getElementById('ad-photo-preview');
            if (adPhotoPreview) adPhotoPreview.classList.add('hidden');
        });
    }
    
    // Envoyer une annonce
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
                          fetchAds(); // Rafraîchir la liste
                      }
                  })
                  .catch(error => console.error('Erreur lors de l\'envoi de l\'annonce:', error));
            }
        });
    }
}

// Écouteurs d'événements pour l'historique d'appels
function setupCallHistoryEventListeners() {
    // Option pour supprimer un appel
    document.addEventListener('click', function(e) {
        // Vérifier si nous sommes sur l'écran d'historique des appels
        if (activeScreen !== 'call-history-screen') return;
        
        const callItem = e.target.closest('.call-item');
        if (!callItem) return;
        
        // Ignorer si on a cliqué sur le bouton d'appel
        if (e.target.closest('.call-btn-small')) return;
        
        // Toggle sélection de l'appel
        callItem.classList.toggle('selected');
        
        // Afficher ou masquer le bouton de suppression
        const selectedCalls = document.querySelectorAll('.call-item.selected');
        
        // Vérifier si l'en-tête d'historique existe
        const historyHeader = document.querySelector('.call-history-screen .app-header');
        if (!historyHeader) return;
        
        let deleteBtn = document.getElementById('delete-calls-btn');
        
        if (selectedCalls.length > 0) {
            // Créer le bouton de suppression s'il n'existe pas
            if (!deleteBtn) {
                deleteBtn = document.createElement('button');
                deleteBtn.id = 'delete-calls-btn';
                deleteBtn.className = 'delete-btn';
                deleteBtn.innerHTML = '<i class="fas fa-trash"></i>';
                deleteBtn.onclick = function() {
                    deleteSelectedCalls();
                };
                
                historyHeader.appendChild(deleteBtn);
            }
        } else if (deleteBtn) {
            // Supprimer le bouton s'il n'y a plus d'appels sélectionnés
            deleteBtn.remove();
        }
    });
}

// Fonction pour supprimer les appels sélectionnés
function deleteSelectedCalls() {
    const selectedCalls = document.querySelectorAll('.call-item.selected');
    const callIds = Array.from(selectedCalls).map(call => call.dataset.id).filter(id => id);
    
    if (callIds.length === 0) {
        console.error("Aucun ID d'appel trouvé dans les éléments sélectionnés");
        return;
    }
    
    console.log("Suppression des appels IDs:", callIds);
    
    if (callIds.length === 1) {
        // Supprimer un seul appel
        fetch('https://ox_phone/deleteCall', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                callId: callIds[0]
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Supprimer les éléments de l'interface
                selectedCalls.forEach(call => call.remove());
                
                // Supprimer le bouton de suppression
                const deleteBtn = document.getElementById('delete-calls-btn');
                if (deleteBtn) deleteBtn.remove();
            } else {
                console.error("Échec de suppression de l'appel:", data);
            }
        })
        .catch(error => {
            console.error('Erreur lors de la suppression de l\'appel:', error);
        });
    } else {
        // Supprimer plusieurs appels
        fetch('https://ox_phone/deleteMultipleCalls', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                callIds: callIds
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Supprimer les éléments de l'interface
                selectedCalls.forEach(call => call.remove());
                
                // Supprimer le bouton de suppression
                const deleteBtn = document.getElementById('delete-calls-btn');
                if (deleteBtn) deleteBtn.remove();
            } else {
                console.error("Échec de suppression des appels:", data);
            }
        })
        .catch(error => {
            console.error('Erreur lors de la suppression des appels:', error);
        });
    }
}

// Fonction pour supprimer les messages sélectionnés
function deleteSelectedMessages() {
    const selectedMessages = document.querySelectorAll('.message-bubble.selected');
    const messageIds = Array.from(selectedMessages).map(bubble => bubble.dataset.id).filter(id => id);
    
    if (messageIds.length === 0) {
        console.error("Aucun ID de message trouvé dans les éléments sélectionnés");
        return;
    }
    
    console.log("Suppression des messages IDs:", messageIds);
    
    if (messageIds.length === 1) {
        // Supprimer un seul message
        fetch('https://ox_phone/deleteMessage', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                messageId: messageIds[0]
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Supprimer les éléments de l'interface
                selectedMessages.forEach(bubble => bubble.remove());
                
                // Supprimer le bouton de suppression
                const deleteBtn = document.getElementById('delete-messages-btn');
                if (deleteBtn) deleteBtn.remove();
            } else {
                console.error("Échec de suppression du message:", data);
            }
        })
        .catch(error => {
            console.error('Erreur lors de la suppression du message:', error);
        });
    } else {
        // Supprimer plusieurs messages
        fetch('https://ox_phone/deleteMultipleMessages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                messageIds: messageIds
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Supprimer les éléments de l'interface
                selectedMessages.forEach(bubble => bubble.remove());
                
                // Supprimer le bouton de suppression
                const deleteBtn = document.getElementById('delete-messages-btn');
                if (deleteBtn) deleteBtn.remove();
            } else {
                console.error("Échec de suppression des messages:", data);
            }
        })
        .catch(error => {
            console.error('Erreur lors de la suppression des messages:', error);
        });
    }
}

// ------ FONCTIONS D'APPEL TÉLÉPHONIQUE ------

// Jouer la sonnerie
function playRingtone() {
    console.log("Démarrage de la sonnerie: " + currentRingtone);
    
    // Arrêter la sonnerie précédente
    stopRingtone();
    
    // Jouer la nouvelle sonnerie avec boucle
    try {
        ringtoneAudio = new Audio(`sounds/${currentRingtone}.ogg`);
        ringtoneAudio.loop = true;
        ringtoneAudio.volume = 1.0;
        
        // Essayer de jouer la sonnerie en .ogg
        ringtoneAudio.play().catch(error => {
            console.warn('Impossible de jouer la sonnerie, nouvelle tentative avec .mp3:', error);
            
            // Essayer avec un format mp3 en fallback
            ringtoneAudio = new Audio(`sounds/${currentRingtone}.mp3`);
            ringtoneAudio.loop = true;
            ringtoneAudio.volume = 1.0;
            ringtoneAudio.play().catch(mp3Error => {
                console.error('Échec de lecture de la sonnerie en mp3:', mp3Error);
                
                // Tenter d'utiliser un son natif de FiveM
                try {
                    fetch('https://ox_phone/playRingtone', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({})
                    }).catch(err => console.error('Erreur lors de la requête de sonnerie:', err));
                } catch (e) {
                    console.error('Erreur lors de la tentative de jouer un son natif:', e);
                }
            });
        });
    } catch (e) {
        console.error('Erreur lors de la lecture de la sonnerie:', e);
    }
}

// Arrêter la sonnerie
function stopRingtone() {
    if (ringtoneAudio) {
        ringtoneAudio.pause();
        ringtoneAudio.currentTime = 0;
        ringtoneAudio = null;
    }
}

// Jouer le son de notification
function playNotificationSound() {
    // Arrêter le son précédent
    stopNotificationSound();
    
    console.log(`Démarrage du son de notification: ${currentNotificationSound}`);
    
    // Jouer le nouveau son avec un volume audible
    try {
        // Créer un nouvel élément audio
        notificationAudio = new Audio(`sounds/${currentNotificationSound}.ogg`);
        notificationAudio.volume = 1.0;
        
        // Jouer le son avec un fallback en MP3
        const playPromise = notificationAudio.play();
        
        // Gérer les erreurs de lecture
        if (playPromise !== undefined) {
            playPromise.catch(error => {
                console.warn('Impossible de jouer la notification en .ogg, tentative avec .mp3:', error);
                
                // Essayer avec un format mp3 en fallback
                notificationAudio = new Audio(`sounds/${currentNotificationSound}.mp3`);
                notificationAudio.volume = 1.0;
                
                notificationAudio.play().catch(mp3Error => {
                    console.error('Échec de lecture de la notification en mp3:', mp3Error);
                });
            });
        }
    } catch (e) {
        console.error('Erreur lors de la lecture de la notification:', e);
    }
}
// Arrêter le son de notification
function stopNotificationSound() {
    if (notificationAudio) {
        notificationAudio.pause();
        notificationAudio.currentTime = 0;
        notificationAudio = null;
    }
}

// Démarrer un appel
function startCall(number) {
    console.log("Démarrage d'un appel vers " + number);
    
    // Nettoyer tout appel précédent
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
    }).catch(error => console.error('Erreur lors du démarrage de l\'appel:', error));
    
    // Préparer l'écran d'appel
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel en cours...';
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = getContactNameForNumber(number) || number;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = number;
    
    const callDurationElement = document.getElementById('call-duration');
    if (callDurationElement) callDurationElement.textContent = '00:00';
    
    // Masquer le bouton de réponse, afficher seulement le bouton pour raccrocher
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    showScreen('calling-screen');
}

// Appel entrant
function incomingCall(data) {
    console.log("Appel entrant: ", data);
    
    activeCallId = data.callId;
    activeCallNumber = data.caller;
    
    // Préparer l'écran d'appel
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel entrant';
    
    const callerName = document.getElementById('caller-name');
    if (callerName) callerName.textContent = data.callerName || data.caller;
    
    const callerNumber = document.getElementById('caller-number');
    if (callerNumber) callerNumber.textContent = data.caller;
    
    const callDurationElement = document.getElementById('call-duration');
    if (callDurationElement) callDurationElement.textContent = '';
    
    // Afficher les deux boutons: répondre et raccrocher
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.remove('hidden');
    
    const endCallBtn = document.getElementById('end-call-btn');
    if (endCallBtn) endCallBtn.classList.remove('hidden');
    
    showScreen('calling-screen');
    
    // Jouer la sonnerie sauf si en silencieux
    if (!doNotDisturb && !airplaneMode) {
        playRingtone();
    }
}

// Fonction de réponse à un appel
function answerCall() {
    console.log("Répondre à l'appel ID: " + activeCallId);
    
    if (!activeCallId) {
        console.error("Impossible de répondre: aucun appel actif");
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
    }).catch(error => console.error('Erreur lors de la réponse à l\'appel:', error));
    
    // Mettre à jour l'interface
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    // Arrêter la sonnerie
    stopRingtone();
}

// Fonction pour terminer un appel 
function endCall() {
    console.log("Terminer l'appel ID: " + activeCallId);
    
    if (!activeCallId && !activeCallNumber) {
        console.error("Impossible de raccrocher: aucun appel actif");
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
    }).catch(error => console.error('Erreur lors de la fin de l\'appel:', error));
    
    // Arrêter le timer
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'Appel terminé';
    
    // Attendre un peu puis revenir à l'écran précédent
    setTimeout(function() {
        if (activeScreen === 'calling-screen') {
            showScreen('phone-app-screen');
        }
        activeCallId = null;
        activeCallNumber = null;
    }, 2000);
    
    // Arrêter la sonnerie
    stopRingtone();
}

// Appel répondu
function callAnswered() {
    console.log("Appel répondu");
    
    const callStatus = document.getElementById('call-status');
    if (callStatus) callStatus.textContent = 'En appel';
    
    const answerCallBtn = document.getElementById('answer-call-btn');
    if (answerCallBtn) answerCallBtn.classList.add('hidden');
    
    // Démarrer le compteur de durée
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
    
    stopRingtone();
}

// Appel rejeté
function callRejected() {
    console.log("Appel rejeté");
    
    if (activeScreen === 'calling-screen') {
        const callStatus = document.getElementById('call-status');
        if (callStatus) callStatus.textContent = 'Appel rejeté';
        
        // Attendre un peu puis revenir à l'écran précédent
        setTimeout(function() {
            showScreen('phone-app-screen');
            activeCallId = null;
            activeCallNumber = null;
        }, 2000);
    }
    
    stopRingtone();
}

// Appel terminé
function callEnded() {
    console.log("Appel terminé");
    
    if (callTimer) {
        clearInterval(callTimer);
        callTimer = null;
    }
    
    if (activeScreen === 'calling-screen') {
        const callStatus = document.getElementById('call-status');
        if (callStatus) callStatus.textContent = 'Appel terminé';
        
        // Attendre un peu puis revenir à l'écran précédent
        setTimeout(function() {
            showScreen('phone-app-screen');
            activeCallId = null;
            activeCallNumber = null;
        }, 2000);
    }
    
    stopRingtone();
}

// Fonction utilitaire pour obtenir le nom d'un contact à partir d'un numéro
function getContactNameForNumber(number) {
    const contact = currentContacts.find(c => c.phone_number === number);
    return contact ? contact.display_name : null;
}

// ------ BANQUE ------
// Nouveau transfert
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
    
    // Envoyer un transfert
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
                          fetchBankData(); // Rafraîchir les données
                      } else {
                          alert(data.message || "Erreur lors du transfert");
                      }
                  })
                  .catch(error => console.error('Erreur lors du transfert:', error));
            }
        });
    }
}

// ------ APPAREIL PHOTO ------
function setupCameraListeners() {
    // Prendre une photo
    const takePhotoBtn = document.getElementById('take-photo-btn');
    if (takePhotoBtn) {
        takePhotoBtn.addEventListener('click', function() {
            takePhoto(false);
        });
    }
    
    // Prendre un selfie
    const takeSelfieBtn = document.getElementById('take-selfie-btn');
    if (takeSelfieBtn) {
        takeSelfieBtn.addEventListener('click', function() {
            takePhoto(true);
        });
    }
    
    // Voir la galerie
    const viewGalleryBtn = document.getElementById('view-gallery-btn');
    if (viewGalleryBtn) {
        viewGalleryBtn.addEventListener('click', function() {
            showScreen('gallery-screen');
            // Pas de sélection, juste visualisation
            const galleryGrid = document.getElementById('gallery-grid');
            if (galleryGrid) galleryGrid.dataset.selectFor = '';
        });
    }
}

// Prendre une photo
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
              // Retour à la galerie après la prise de photo
              fetchGallery();
              showScreen('gallery-screen');
          }
      })
      .catch(error => console.error('Erreur lors de la prise de photo:', error));
}
// ------ PARAMÈTRES ------
function setupSettingsListeners() {
    // Changer le fond d'écran
    const changeWallpaperBtn = document.getElementById('change-wallpaper-btn');
    if (changeWallpaperBtn) {
        changeWallpaperBtn.addEventListener('click', function() {
            showScreen('wallpaper-screen');
        });
    }
    
    // Sélectionner un fond d'écran
    document.querySelectorAll('.wallpaper-item').forEach(item => {
        item.addEventListener('click', function() {
            const wallpaper = this.dataset.wallpaper;
            setWallpaper(wallpaper);
            showScreen('settings-screen');
        });
    });
    
    // Changer la sonnerie
    const changeRingtoneBtn = document.getElementById('change-ringtone-btn');
    if (changeRingtoneBtn) {
        changeRingtoneBtn.addEventListener('click', function() {
            showScreen('ringtone-screen');
        });
    }
    
    // Sélectionner une sonnerie
    document.querySelectorAll('.ringtone-item').forEach(item => {
        item.addEventListener('click', function() {
            const ringtone = this.dataset.ringtone;
            setRingtone(ringtone);
        });
    });
    
    // Écouter une sonnerie
    document.querySelectorAll('.ringtone-item .play-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const ringtone = this.closest('.ringtone-item')?.dataset.ringtone;
            if (ringtone) playSound(ringtone);
        });
    });
    
    // Changer le son de notification
    const changeNotificationBtn = document.getElementById('change-notification-btn');
    if (changeNotificationBtn) {
        changeNotificationBtn.addEventListener('click', function() {
            showScreen('notification-sound-screen');
        });
    }
    
    // Sélectionner un son de notification
    document.querySelectorAll('.notification-item').forEach(item => {
        item.addEventListener('click', function() {
            const notification = this.dataset.notification;
            setNotificationSound(notification);
        });
    });
    
    // Écouter un son de notification
    document.querySelectorAll('.notification-item .play-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const notification = this.closest('.notification-item')?.dataset.notification;
            if (notification) playSound(notification);
        });
    });
    
    // Changer le thème
    const themeSelect = document.getElementById('theme-select');
    if (themeSelect) {
        themeSelect.addEventListener('change', function() {
            setTheme(this.value);
        });
    }
    
    // Mode silencieux
    const dndToggle = document.getElementById('dnd-toggle');
    if (dndToggle) {
        dndToggle.addEventListener('change', function() {
            setDoNotDisturb(this.checked);
        });
    }
    
    // Mode avion
    const airplaneToggle = document.getElementById('airplane-toggle');
    if (airplaneToggle) {
        airplaneToggle.addEventListener('change', function() {
            setAirplaneMode(this.checked);
        });
    }
}

// Options photo
function setupPhotoOptionsListeners() {
    const photoOptionsBtn = document.getElementById('photo-options-btn');
    if (photoOptionsBtn) {
        photoOptionsBtn.addEventListener('click', function() {
            const options = document.getElementById('photo-options');
            if (options) options.classList.toggle('hidden');
        });
    }
    
    // Partager une photo
    const sharePhotoBtn = document.getElementById('share-photo-btn');
    if (sharePhotoBtn) {
        sharePhotoBtn.addEventListener('click', function() {
            const photoUrl = document.getElementById('full-photo')?.src;
            // Implémenter la logique de partage selon les besoins
            const photoOptions = document.getElementById('photo-options');
            if (photoOptions) photoOptions.classList.add('hidden');
        });
    }
    
    // Supprimer une photo
    const deletePhotoBtn = document.getElementById('delete-photo-btn');
    if (deletePhotoBtn) {
        deletePhotoBtn.addEventListener('click', function() {
            const photoId = document.getElementById('full-photo')?.dataset.id;
            if (!photoId) return;
            
            if (confirm('Êtes-vous sûr de vouloir supprimer cette photo ?')) {
                fetch('https://ox_phone/deletePhoto', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        photoId: photoId
                    })
                }).then(response => response.json())
                  .then(data => {
                      if (data.success) {
                          showScreen('gallery-screen');
                          fetchGallery(); // Rafraîchir la galerie
                      }
                  })
                  .catch(error => console.error('Erreur lors de la suppression de la photo:', error));
            }
            
            const photoOptions = document.getElementById('photo-options');
            if (photoOptions) photoOptions.classList.add('hidden');
        });
    }
}

// ----- CONTACTS -----
// Récupérer les contacts
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
      .catch(error => console.error('Erreur lors de la récupération des contacts:', error));
}

// Afficher les contacts
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
    
    // Écouter les actions sur les contacts
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

// Filtrer les contacts
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

// Supprimer un contact
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
                  fetchContacts(); // Rafraîchir la liste
              }
          })
          .catch(error => console.error('Erreur lors de la suppression du contact:', error));
    }
}

// ----- MESSAGES -----
// Récupérer les messages
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
      .catch(error => console.error('Erreur lors de la récupération des messages:', error));
}

// Afficher les conversations

function showSmsNotification(data) {
    console.log("showSmsNotification appelé avec les données:", data);

    // Vérifier si le mode NPD ou avion est activé
    if (doNotDisturb || airplaneMode) {
        console.log("Notification SMS bloquée à cause du mode NPD ou avion");
        return;
    }

    const notification = {
        title: 'Nouveau SMS',
        description: `De: ${data.sender}\n${data.message.substring(0, 30)}${data.message.length > 30 ? '...' : ''}`
    };

    // Essayer d'utiliser le système de notification du jeu
    try {
        console.log("Tentative d'envoi de la notification à ox_lib:", notification);
        fetch('https://ox_lib/notify', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(notification)
        }).then(response => {
            console.log("Réponse de ox_lib:", response);
            if (!response.ok) {
                console.warn("ox_lib a retourné une erreur:", response.status, response.statusText);
                showCustomNotification(notification.title, notification.description);
            }
        }).catch(error => {
            console.error('Erreur lors de l\'envoi de la notification à ox_lib:', error);
            showCustomNotification(notification.title, notification.description);
        });
    } catch (e) {
        console.error('Erreur lors de la tentative de notification:', e);
        showCustomNotification(notification.title, notification.description);
    }
}



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
        
        // Formater la date
        const date = new Date(conversation.last_time);
        const today = new Date();
        let timeString;
        
        if (date.toDateString() === today.toDateString()) {
            // Aujourd'hui, afficher juste l'heure
            timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
            // Autre jour, afficher la date
            timeString = date.toLocaleDateString([], { day: 'numeric', month: 'numeric' });
        }
        
        // Badge de messages non lus
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
        `;
        
        item.addEventListener('click', function() {
            openConversation(conversation.number, conversation.name);
        });
        
        conversationsList.appendChild(item);
    });
}

// Ouvrir une conversation
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
          
          // Faire défiler jusqu'en bas
          const messagesList = document.getElementById('messages-list');
          if (messagesList) messagesList.scrollTop = messagesList.scrollHeight;
          
          // Arrêter l'ancien intervalle s'il existe
          if (conversationRefreshInterval) {
              clearInterval(conversationRefreshInterval);
          }
          
          // Définir un nouvel intervalle pour rafraîchir la conversation toutes les 3 secondes
          conversationRefreshInterval = setInterval(function() {
              refreshCurrentConversation(number);
          }, 3000);
      })
      .catch(error => console.error('Erreur lors de l\'ouverture de la conversation:', error));
}

// Nouvelle fonction pour rafraîchir la conversation actuelle
function refreshCurrentConversation(number) {
    // Ne rafraîchir que si le téléphone est ouvert, l'écran de conversation est actif
    if (!phoneOpen || activeScreen !== 'conversation-screen') {
        // Si le téléphone est fermé ou pas sur l'écran de conversation, arrêter l'intervalle
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
    
    console.log("Rafraîchissement de la conversation avec " + number);
    
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
          // Au lieu de tout réinitialiser, nous allons comparer les messages existants et ajouter seulement les nouveaux
          updateExistingConversation(data.messages || []);
      })
      .catch(error => console.error('Erreur lors du rafraîchissement de la conversation:', error));
}

// Fonction pour mettre à jour les messages sans tout redessiner
function updateExistingConversation(messages) {
    const messagesList = document.getElementById('messages-list');
    if (!messagesList) return;
    
    // Obtenir tous les IDs de message actuellement affichés
    const existingIds = new Set();
    document.querySelectorAll('.message-bubble').forEach(bubble => {
        if (bubble.dataset.id) {
            existingIds.add(bubble.dataset.id);
        }
    });
    
    // Identifier et ajouter uniquement les nouveaux messages
    let hasNewMessages = false;
    messages.forEach(message => {
        // Si le message n'existe pas déjà
        if (message.id && !existingIds.has(message.id.toString())) {
            const isOutgoing = message.is_sender === 1;
            const date = new Date(message.created_at);
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
    
    // Faire défiler jusqu'en bas uniquement si de nouveaux messages ont été ajoutés
    if (hasNewMessages) {
        messagesList.scrollTop = messagesList.scrollHeight;
    }
}

// Afficher les messages d'une conversation
function renderMessages(messages) {
    const messagesList = document.getElementById('messages-list');
    if (!messagesList) return;

    messagesList.innerHTML = '';

    if (messages.length === 0) {
        messagesList.innerHTML = '<div class="empty-list">Aucun message</div>';
        return;
    }

    // Regrouper les messages par jour
    const messagesByDate = {};
    messages.forEach(message => {
        // Utiliser timestamp comme identifiant stable pour le message
        const date = new Date(message.created_at);
        const dateString = date.toLocaleDateString();

        if (!messagesByDate[dateString]) {
            messagesByDate[dateString] = [];
        }
        messagesByDate[dateString].push(message);
    });

    // Créer les éléments par jour
    for (const dateString in messagesByDate) {
        // Ajouter le séparateur de date
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

        // Ajouter les messages de cette date
        messagesByDate[dateString].forEach(message => {
            const isOutgoing = message.is_sender === 1;
            
            // Utiliser la date exacte telle que fournie par le serveur
            const date = new Date(message.created_at);
            const timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

            const bubble = document.createElement('div');
            bubble.className = `message-bubble ${isOutgoing ? 'message-outgoing' : 'message-incoming'}`;
            bubble.dataset.id = message.id; // Utiliser l'ID fourni par le serveur

            bubble.innerHTML = `
                <div class="message-content">${message.message}</div>
                <div class="message-time">${timeString}</div>
            `;

            messagesList.appendChild(bubble);
        });
    }

    // Faire défiler jusqu'en bas
    messagesList.scrollTop = messagesList.scrollHeight;
}

// Envoyer un message
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
    
    // Effacer le champ de saisie immédiatement pour une meilleure UX
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
              // Plutôt que d'ajouter le message manuellement, déclencher un rafraîchissement immédiat
              refreshCurrentConversation(number);
          }
      })
      .catch(error => console.error('Erreur lors de l\'envoi du message:', error));
}

// Recevoir un message
function receiveMessage(data) {
    console.log("Message reçu:", data);
    
    // Jouer un son de notification si on n'est pas en mode silencieux
    if (!doNotDisturb && !airplaneMode) {
        playNotificationSound();
    }
    
    // Si on est dans la conversation avec l'expéditeur, ajouter le message
    const conversationTitle = document.getElementById('conversation-title');
    
    if (conversationTitle && activeScreen === 'conversation-screen' && conversationTitle.dataset.number === data.sender) {
        const messages = document.getElementById('messages-list');
        if (!messages) return;
        
        const bubble = document.createElement('div');
        
        // Utiliser la date fournie ou la date actuelle
        const date = data.time ? new Date(data.time) : new Date();
        const timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        bubble.className = 'message-bubble message-incoming new';
        bubble.dataset.id = data.id || Date.now(); // Utiliser l'ID fourni ou timestamp
        
        bubble.innerHTML = `
            <div class="message-content">${data.message}</div>
            <div class="message-time">${timeString}</div>
        `;
        
        messages.appendChild(bubble);
        
        // Faire défiler jusqu'en bas
        messages.scrollTop = messages.scrollHeight;
        
        // Marquer le message comme lu en envoyant une requête au serveur
        fetch('https://ox_phone/markMessageRead', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                sender: data.sender
            })
        }).catch(error => console.error('Erreur lors du marquage du message comme lu:', error));
    } 
    else if (activeScreen === 'messages-screen') {
        // Mettre à jour la liste des conversations si on est sur l'écran des messages
        fetchMessages();
    } 
    else {
        // Si on n'est pas dans la conversation ou l'écran de messages,
        // afficher une notification visuelle
        const notification = {
            title: 'Nouveau message',
            description: `De: ${data.sender}\n${data.message.substring(0, 30)}${data.message.length > 30 ? '...' : ''}`
        };
        
        // Essayer d'utiliser le système de notification du jeu
        try {
            fetch('https://ox_lib/notify', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(notification)
            }).catch(error => {
                console.error('Erreur lors de l\'envoi de la notification au jeu:', error);
                showCustomNotification(notification.title, notification.description);
            });
        } catch (e) {
            console.error('Erreur lors de la tentative de notification:', e);
            showCustomNotification(notification.title, notification.description);
        }
    }
}

// Fonction de notification personnalisée fallback
function showCustomNotification(title, message) {
    const notification = document.createElement('div');
    notification.className = 'custom-notification';
    notification.innerHTML = `
        <div class="notification-title">${title}</div>
        <div class="notification-message">${message}</div>
    `;
    
    // Ajouter au DOM
    document.body.appendChild(notification);
    
    // Animer l'entrée
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    // Supprimer après un délai
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

// ----- HISTORIQUE DES APPELS -----
// Récupérer l'historique des appels
function fetchCallHistory() {
    fetch('https://ox_phone/getCallHistory', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => {
        console.log('Response status:', response.status);
        return response.text(); // Utilisez text() au lieu de json() pour voir la réponse brute
    })
    .then(text => {
        console.log('Raw response:', text);
        // Essayer de parser le JSON manuellement pour voir où est l'erreur
        try {
            const data = JSON.parse(text);
            console.log('Parsed data:', data);
            currentCallHistory = data;
            renderCallHistory(data);
        } catch (e) {
            console.error('Error parsing JSON:', e);
        }
    })
    .catch(error => console.error('Erreur lors de la récupération de l\'historique des appels:', error));
}

// Afficher l'historique des appels
function renderCallHistory(calls) {
    const callsList = document.getElementById('call-history-list');
    if (!callsList) {
        console.error("Element call-history-list introuvable");
        return;
    }

    callsList.innerHTML = '';

    if (!calls || calls.length === 0) {
        callsList.innerHTML = '<div class="empty-list">Aucun appel</div>';
        return;
    }

    console.log("Rendu de l'historique des appels:", calls);

    calls.forEach(call => {
        const item = document.createElement('div');
        item.className = 'list-item call-item';
        item.dataset.id = call.id; // Ajouter l'ID de l'appel pour pouvoir le supprimer

        // Formater la date
        const date = new Date(call.created_at);
        const today = new Date();
        let timeString;

        if (date.toDateString() === today.toDateString()) {
            timeString = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
            timeString = date.toLocaleDateString([], { day: 'numeric', month: 'numeric' });
        }

        // Déterminer l'icône, la classe et le texte de statut
        let icon, statusClass, statusText, displayNumber;
        const duration = call.duration > 0 ? formatDuration(call.duration) : '';

        // Détecter la direction (incoming/outgoing) et le numéro à afficher
        const isOutgoing = call.direction === 'outgoing';
        displayNumber = isOutgoing ? call.receiver : call.caller;

        // Déterminer le style en fonction de la direction et du statut
        if (isOutgoing) {
            // Appel sortant
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
            // Appel entrant
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

        // Utiliser le nom du contact si disponible, sinon le numéro
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
            </div>
        `;

        callsList.appendChild(item);
    });

    // Écouter les actions sur les appels
    document.querySelectorAll('.call-btn-small').forEach(btn => {
        btn.addEventListener('click', function() {
            const number = this.dataset.number;
            startCall(number);
        });
    });
}



// Formater la durée en minutes:secondes
function formatDuration(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
}

// ----- TWITTER -----
// Récupérer les tweets
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
      .catch(error => console.error('Erreur lors de la récupération des tweets:', error));
}

// Récupérer les commentaires d'un tweet
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
          return data ? data.length : 0; // Retourner le nombre de commentaires
      })
      .catch(error => {
          console.error('Erreur lors de la récupération des commentaires du tweet:', error);
          return 0; // Retourner 0 en cas d'erreur
      });
}


    // Afficher les commentaires d'un tweet
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

    // Ajouter un commentaire à un tweet
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
                  fetchTweetComments(tweetId); // Rafraîchir les commentaires
              }
          })
          .catch(error => console.error('Erreur lors de l\'ajout du commentaire au tweet:', error));
    }

// Afficher les tweets
function renderTweets(tweets) {
    const tweetsList = document.getElementById('tweets-list');
    if (!tweetsList) return;

    tweetsList.innerHTML = '';

    if (tweets.length === 0) {
        tweetsList.innerHTML = '<div class="empty-list">Aucun tweet</div>';
        return;
    }

    tweets.forEach(tweet => {
        const date = new Date(tweet.created_at);
        const timeString = formatRelativeTime(date);

        // Compter les likes
        const likes = JSON.parse(tweet.likes || '[]').length;

        // Vérifier si l'utilisateur a liké ce tweet
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

        // Récupérer et afficher le nombre de commentaires
        fetchTweetComments(tweet.id).then(commentCount => {
            const commentCountSpan = item.querySelector('.comment-count');
            if (commentCountSpan) {
                commentCountSpan.textContent = commentCount;
            }
        });
    });

    // Écouter les actions sur les tweets
    document.querySelectorAll('.tweet-like').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.dataset.id;
            likeTweet(id);
        });
    });

    // Écouter les actions pour afficher/masquer les commentaires
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

    // Écouter les actions pour ajouter un commentaire
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


// Formater le temps relatif (il y a X minutes, heures, etc.)
function formatRelativeTime(date) {
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

// Liker un tweet
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
              // Mettre à jour l'affichage du nombre de likes
              const likeBtn = document.querySelector(`.tweet-like[data-id="${id}"]`);
              if (!likeBtn) return;
              
              const likeCount = likeBtn.querySelector('span');
              if (likeCount) likeCount.textContent = data.likes;
              
              // Inverser l'état "aimé"
              const isLiked = likeBtn.dataset.liked === 'true';
              likeBtn.dataset.liked = (!isLiked).toString();
              
              // Changer la couleur du cœur
              const heart = likeBtn.querySelector('i');
              if (heart) heart.style.color = !isLiked ? 'red' : '';
          }
      })
      .catch(error => console.error('Erreur lors du like du tweet:', error));
}

// Recevoir un nouveau tweet
function receiveTweet(data) {
    if (activeScreen === 'twitter-screen') {
        // Si on est déjà sur l'écran Twitter, ajouter le tweet en haut
        const tweetsList = document.getElementById('tweets-list');
        if (!tweetsList) return;
        
        const date = new Date(data.tweet.created_at);
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
        
        // Ajouter au début
        if (tweetsList.firstChild) {
            tweetsList.insertBefore(item, tweetsList.firstChild);
        } else {
            tweetsList.appendChild(item);
        }
        
        // Écouter le like pour ce nouveau tweet
        const likeBtn = item.querySelector('.tweet-like');
        if (likeBtn) {
            likeBtn.addEventListener('click', function() {
                likeTweet(data.tweet.id);
            });
        }
    }
    
    // Jouer un son de notification sauf si en silencieux
    if (!doNotDisturb && !airplaneMode) {
        playNotificationSound();
    }
}

// ----- ANNONCES -----
// Récupérer les annonces
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
      .catch(error => console.error('Erreur lors de la récupération des annonces:', error));
}

// Afficher les annonces
function renderAds(ads) {
    const adsList = document.getElementById('ads-list');
    if (!adsList) return;
    
    adsList.innerHTML = '';
    
    if (ads.length === 0) {
        adsList.innerHTML = '<div class="empty-list">Aucune annonce</div>';
        return;
    }
    
    ads.forEach(ad => {
        const date = new Date(ad.created_at);
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
    
    // Écouter les actions sur les annonces
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

// Recevoir une nouvelle annonce
function receiveAd(data) {
    if (activeScreen === 'ads-screen') {
        // Si on est déjà sur l'écran des annonces, ajouter l'annonce en haut
        fetchAds(); // Rafraîchir la liste
    }
    
    // Jouer un son de notification sauf si en silencieux
    if (!doNotDisturb && !airplaneMode) {
        playNotificationSound();
    }
}

// ----- BANQUE -----
// Récupérer les données bancaires
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
      .catch(error => console.error('Erreur lors de la récupération des données bancaires:', error));
}

// Afficher les données bancaires
function renderBankData(data) {
    // Formater le solde
    const balanceAmount = document.getElementById('balance-amount');
    if (balanceAmount) balanceAmount.textContent = `$${parseFloat(data.balance).toFixed(2)}`;
    
    // Afficher les transactions
    const transactionsList = document.getElementById('transactions-list');
    if (!transactionsList) return;
    
    transactionsList.innerHTML = '';
    
    if (!data.transactions || data.transactions.length === 0) {
        transactionsList.innerHTML = '<div class="empty-list">Aucune transaction</div>';
        return;
    }
    
    data.transactions.forEach(transaction => {
        const date = new Date(transaction.date);
        const timeString = date.toLocaleDateString();
        
        const isPositive = transaction.amount > 0;
        
        const item = document.createElement('div');
        item.className = 'transaction-item';
        item.innerHTML = `
            <div class="transaction-info">
                <div class="transaction-name">${transaction.label}</div>
                <div class="transaction-date">${timeString}</div>
            </div>
            <div class="transaction-amount ${isPositive ? 'positive' : 'negative'}">
                ${isPositive ? '+' : ''}$${Math.abs(transaction.amount).toFixed(2)}
            </div>
        `;
        
        transactionsList.appendChild(item);
    });
}

// ----- GALERIE -----
// Récupérer la galerie
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
      .catch(error => console.error('Erreur lors de la récupération de la galerie:', error));
}

// Afficher la galerie
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
            // Si on sélectionne pour un tweet ou une annonce
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
                // Sinon, voir la photo en plein écran
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

// ----- PARAMÈTRES -----
// Récupérer les paramètres
function fetchSettings() {
    fetch('https://ox_phone/getSettings', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        }
    }).then(response => response.json())
      .then(data => {
          // Appliquer les paramètres
          setWallpaper(data.background || 'background1');
          setRingtone(data.ringtone || 'ringtone1');
          setNotificationSound(data.notification_sound || 'notification1');
          setTheme(data.theme || 'default');
          setDoNotDisturb(data.do_not_disturb || false);
          setAirplaneMode(data.airplane_mode || false);
          
          // Mettre à jour les éléments de l'interface
          const themeSelect = document.getElementById('theme-select');
          if (themeSelect) themeSelect.value = data.theme || 'default';
          
          const dndToggle = document.getElementById('dnd-toggle');
          if (dndToggle) dndToggle.checked = data.do_not_disturb || false;
          
          const airplaneToggle = document.getElementById('airplane-toggle');
          if (airplaneToggle) airplaneToggle.checked = data.airplane_mode || false;
      })
      .catch(error => console.error('Erreur lors de la récupération des paramètres:', error));
}

// Définir le fond d'écran
function setWallpaper(wallpaper) {
    currentWallpaper = wallpaper;
    
    const homeScreen = document.getElementById('home-screen');
    if (homeScreen) homeScreen.style.backgroundImage = `url('images/wallpapers/${wallpaper}.jpg')`;
    
    // Enregistrer le paramètre
    saveSettings();
}

// Définir la sonnerie
function setRingtone(ringtone) {
    currentRingtone = ringtone;
    
    // Mettre en surbrillance la sonnerie sélectionnée
    document.querySelectorAll('.ringtone-item').forEach(item => {
        if (item.dataset.ringtone === ringtone) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
    
    // Enregistrer le paramètre
    saveSettings();
}

// Définir le son de notification
function setNotificationSound(sound) {
    currentNotificationSound = sound;
    
    // Mettre en surbrillance le son sélectionné
    document.querySelectorAll('.notification-item').forEach(item => {
        if (item.dataset.notification === sound) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
    
    // Enregistrer le paramètre
    saveSettings();
}

// Définir le thème
function setTheme(theme) {
    currentTheme = theme;
    document.body.dataset.theme = theme;
    
    // Enregistrer le paramètre
    saveSettings();
}

// Définir le mode silencieux
function setDoNotDisturb(value) {
    doNotDisturb = value;
    
    // Enregistrer le paramètre
    saveSettings();
}

// Définir le mode avion
function setAirplaneMode(value) {
    airplaneMode = value;
    
    // Enregistrer le paramètre
    saveSettings();
}

// Enregistrer les paramètres
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
    }).catch(error => console.error('Erreur lors de la sauvegarde des paramètres:', error));
}

// Jouer un son
function playSound(sound) {
    if (!sound) return;
    
    try {
        console.log(`Tentative de lecture du son: ${sound}`);
        
        // Créer et jouer le son
        const audio = new Audio(`sounds/${sound}.ogg`);
        
        // Augmenter le volume pour être sûr qu'il soit audible
        audio.volume = 1.0;
        
        // Jouer le son et gérer les erreurs
        audio.play().catch(error => {
            console.warn('Impossible de jouer le son, nouvelle tentative avec .mp3:', error);
            
            // Essayer avec un format mp3 en fallback
            const mp3Audio = new Audio(`sounds/${sound}.mp3`);
            mp3Audio.volume = 1.0;
            mp3Audio.play().catch(mp3Error => {
                console.error('Échec de lecture du son en mp3:', mp3Error);
                
                // Tenter d'utiliser un son natif de FiveM comme dernier recours
                try {
                    fetch('https://ox_phone/playSound', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            sound: sound
                        })
                    }).catch(err => console.error('Erreur lors de la requête de son:', err));
                } catch (e) {
                    console.error('Erreur lors de la tentative de jouer un son natif:', e);
                }
            });
        });
        
        // Retourner l'objet audio pour pouvoir l'arrêter plus tard si nécessaire
        return audio;
    } catch (e) {
        console.error('Erreur lors de la lecture du son:', e);
        return null;
    }
}

// Fermer le téléphone (callback NUI)
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch('https://ox_phone/closePhone', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            }
        }).catch(error => console.error('Erreur lors de la fermeture du téléphone:', error));
    }
});