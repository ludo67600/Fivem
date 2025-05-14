-- J_PoliceNat shared/config.lua
Config = {}

-- Configuration générale
Config.Job = {
    name = 'police',
    label = 'Police Nationale',
    bossGrade = 10 -- Grade du boss
}

-- Prix du permis de port d'arme
Config.WeaponLicensePrice = 1500


-- Points d'interaction
Config.Locations = {
    main = {
        coords = vector3(442.0855, -982.2700, 30.7238),  
        label = 'Accueil Police Nationale',
        ped = {
            model = 's_m_y_cop_01',
            heading = 80.0,
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        }
    },
    garage = {
        coords = vector3(478.8255, -999.8632, 27.0291),  
        label = 'Garage Police',
        ped = {
            model = 's_m_y_cop_01',
            heading = 80.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
        },
        vehicleSpawnPoints = {
            {coords = vector3(476.3253, -1004.6592, 26.8215), heading = 180.0}  
        }
    },
    vestiaire = {
        coords = vector3(460.7025, -977.7528, 34.2974),  
        label = 'Vestiaire',
        ped = {
            model = 's_m_y_cop_01',
            heading = 180.0,
            scenario = 'WORLD_HUMAN_STAND_MOBILE'
        }
    },
    armory = {
        coords = vector3(440.1633, -984.0378, 34.2974),  
        label = 'Armurerie',
        ped = {
            model = 's_m_y_cop_01',
            heading = 270.0,
            scenario = 'WORLD_HUMAN_GUARD_STAND'
        }
    }
}


-- Véhicules de service
Config.Vehicles = {
    {
     
        label = 'Dacia Duster',
        model = 'police3',
        minGrade = 0
    },
    {
        label = 'Peugeot 5008',
        model = 'police',
        minGrade = 0
    },
    {
        label = 'Peugeot 3008',
        model = '3008pln',
        minGrade = 0
    },
    {
        label = 'Ford Galaxy',
        model = 'galaxypn',
        minGrade = 0
    },
    {
        label = 'Skoda Kodiaq',
        model = 'kodiaqpn',
        minGrade = 0
    },
    {
	    label = 'Renault Megane 4',
        model = 'megane4pln',
        minGrade = 0
    },
    {
	    label = 'Renault Trafic',
        model = 'traficpn2mlx4',
        minGrade = 0
    },
    {
	    label = 'Skoada Octavia',
        model = 'skodapn',
        minGrade = 0
    },
    {
	    label = 'Skoda Octavia Combi',
        model = 'skodacombipn1',
        minGrade = 0
    },
    {
	    label = 'Opel Vivaro',
        model = 'vivaropn',
        minGrade = 0
    },
    {
	    label = 'Ford transit',
        model = 'transitpn',
        minGrade = 0
    },
    {
	    label = 'Moto Bmw R1200RT',
        model = 'motopn',
        minGrade = 0
    },
    {
	    label = 'Megane RS',
        model = 'megpn',
        minGrade = 0
    },
    {
	    label = 'Moto Yamaha Tracer',
        model = 'tracerpln',
        minGrade = 0
    },
    {
	    label = 'Moto Yamaha MT-09',
        model = 'mt09pn',
        minGrade = 0
    },
    {
	    label = 'Moto Crs',
        model = 'crsb',
        minGrade = 0
    },
    {
	    label = 'Renault Master',
        model = 'policet',
        minGrade = 0
    },
    {
	    label = 'Peugeot Partner',
        model = 'partnerpln',
        minGrade = 0
    },
    {
	    label = 'E-golf',
        model = 'egolfpn',
        minGrade = 0
    
    },
    {
	    label = 'Renault Crs',
        model = 'mastercrs',
        minGrade = 0
    },
    {
	    label = 'Lanceur d/Eau CRS Crs',
        model = 'firetruk',
        minGrade = 0
    },
    {
	   
	    label = 'Blindé Raid',
        model = 'riot',
        minGrade = 0
    },
    {
	    label = 'Blindé Raid 2',
        model = 'bearcat',
        minGrade = 0
    },
    {
	  
	    label = 'Moto Tracer 900 Bana',
        model = 'tracer900bana',
        minGrade = 0
    },
    {
	    label = 'T6 Bac',
        model = 't6ban',
        minGrade = 0
    },
    {
	    label = 'Megane 4 Bac',
        model = 'megane4estate',
        minGrade = 0
    },
    {
	
        label = 'Master Bac',
        model = 'masterbana',
        minGrade = 0
    },
    {
        label = 'Volkswagen Passat',
        model = 'passatbana',
        minGrade = 0
    },
    {
        label = 'Ford Bac',
        model = 'fordbac',
        minGrade = 0
    },
    {
        label = 'Peugeot 308 22 Bac',
        model = '3082022bana',
        minGrade = 0
    },
    {
        label = 'Peugeot 208 Bac',
        model = '208bana',
        minGrade = 0
    },
    {
        label = 'Peugeot 508 Bac',
        model = '508bana',
        minGrade = 0
    }
}



-- Nouvelle structure pour les tenues
Config.Uniforms = {
    {
        label = 'Tenue courte Policier Adjoint',
        minGrade = 0,
        male = {
                   tshirt_1 = 105, tshirt_2 = 0,
                   torso_1 = 153,  torso_2 = 1,
                   decals_1 = 0,  decals_2 = 0,
                   arms = 41,
                   pants_1 = 46,  pants_2 = 0,
                   shoes_1 = 25,  shoes_2 = 0,
                   helmet_1 = -1, helmet_2 = 0,
                   chain_1 = 3,   chain_2 = 0,
                   mask_1 = -1, mask_2 = 0,
                   bproof_1 = 0, bproof_2 = 0,
                   ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Gardien de la Paix',
        minGrade = 0,
        male = {
			   tshirt_1 = 105, tshirt_2 = 0,
               torso_1 = 153,  torso_2 = 3,
               decals_1 = 0,  decals_2 = 0,
               arms = 41,
               pants_1 = 46,  pants_2 = 0,
               shoes_1 = 25,  shoes_2 = 0,
               helmet_1 = -1, helmet_2 = 0,
               chain_1 = 3,   chain_2 = 0,
               mask_1 = -1, mask_2 = 0,
               bproof_1 = 0, bproof_2 = 0,
               ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Brigadier',
        minGrade = 0,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 4,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte brigadier',
        minGrade = 1,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 5,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Brigadier chef',
        minGrade = 2,
        male = {
       tshirt_1 = 105, tshirt_2 = 0,
       torso_1 = 153,  torso_2 = 5,
       decals_1 = 0,  decals_2 = 0,
       arms = 41,
       pants_1 = 46,  pants_2 = 0,
       shoes_1 = 25,  shoes_2 = 0,
       helmet_1 = -1, helmet_2 = 0,
       chain_1 = 3,   chain_2 = 0,
       mask_1 = -1, mask_2 = 0,
       bproof_1 = 0, bproof_2 = 0,
       ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Major',
        minGrade = 3,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 6,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte sous Lieutenant',
        minGrade = 4,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 7,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Lieutenant',
        minGrade = 4,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 8,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Capitaine',
        minGrade = 5,
        male = {
		           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 9,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Commandant',
        minGrade = 6,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 10,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Commissaire',
        minGrade = 6,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 11,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue courte Commissaire Divisionnaire',
        minGrade = 7,
        male = {
			           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 153,  torso_2 = 12,
           decals_1 = 0,  decals_2 = 0,
           arms = 41,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue longue Policier Adjoint',
        minGrade = 8,
        male = {
			           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 1,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    },
    {
        label = 'Tenue longue Stagiaire ',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 2,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Gardien de la Paix',
        minGrade = 9,
        male = {
                      tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 3,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Stagiaire ',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 2,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Brigadier',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 4,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Brigadier-Chef',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 5,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Major',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 6,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Sous Lieutenant',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 7,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Lieutenant',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 8,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Capitaine',
        minGrade = 9,
        male = {
            tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 9,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Commandant',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 10,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Commissaire',
        minGrade = 9,
        male = {
            tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 11,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
	},
    {
        label = 'Tenue longue Commissaire Divisionnaire',
        minGrade = 9,
        male = {
           tshirt_1 = 105, tshirt_2 = 0,
           torso_1 = 152,  torso_2 = 12,
           decals_1 = 0,  decals_2 = 0,
           arms = 42,
           pants_1 = 46,  pants_2 = 0,
           shoes_1 = 25,  shoes_2 = 0,
           helmet_1 = -1, helmet_2 = 0,
           chain_1 = 3,   chain_2 = 0,
           mask_1 = -1, mask_2 = 0,
           bproof_1 = 0, bproof_2 = 0,
           ears_1 = 0,    ears_2 = 0
		},
		female = {}
    }
}

-- Configuration des accessoires
Config.Accessories = {
    helmets = {
        {
            label = 'Calot',
            male = {helmet_1 = 114, helmet_2 = 0},
            female = {helmet_1 = 114, helmet_2 = 0},
            minGrade = 0
        },
        {
            label = 'Casque Anti Emeute',
            male = {helmet_1 = 18, helmet_2 = 0},
            female = {helmet_1 = 18, helmet_2 = 0},
            minGrade = 0
        },
        {
            label = 'Casque Moto',
            male = {helmet_1 = 17, helmet_2 = 2},
            female = {helmet_1 = 17, helmet_2 = 2},
            minGrade = 0
        }
    },
    vests = {
        {
            label = 'Gilet par Balle',
            male = {bproof_1 = 9, bproof_2 = 0},
            female = {bproof_1 = 9, bproof_2 = 0},
            minGrade = 0
        },
        {
            label = 'Gilet par Balle 2',
            male = {bproof_1 = 9, bproof_2 = 2},
            female = {bproof_1 = 9, bproof_2 = 2},
            minGrade = 0
        },
        {
            label = 'Gilet par Balle lourd',
            male = {bproof_1 = 4, bproof_2 = 1},
            female = {bproof_1 = 4, bproof_2 = 1},
            minGrade = 0
        },
        {
            label = 'Gilet par Balle discret',
            male = {bproof_1 = 8, bproof_2 = 0},
            female = {bproof_1 = 8, bproof_2 = 0},
            minGrade = 0
        },
        {
            label = 'Gilet par Balle bac',
            male = {bproof_1 = 7, bproof_2 = 3},
            female = {bproof_1 = 7, bproof_2 = 3},
            minGrade = 0
        },
        {
            label = 'Gilet par Balle crs',
            male = {bproof_1 = 7, bproof_2 = 1},
            female = {bproof_1 = 7, bproof_2 = 1},
            minGrade = 0
        },
        {
            label = 'Gilet jaune',
            male = {bproof_1 = 6, bproof_2 = 0},
            female = {bproof_1 = 6, bproof_2 = 0},
            minGrade = 0
        }
    },
    bracelets = {
        {
            label = 'Brassard',
            male = {tshirt_1 = 56, tshirt_2 = 0},
            female = {tshirt_1 = 56, tshirt_2 = 0},
            minGrade = 0
        }
    }
}


-- Props disponibles
Config.Props = {
    {
        label = 'Balisage',
        model = 'prop_mp_num_0',
        minGrade = 0,
        zOffset = 0.0
    },
    {
        label = 'Panneau Droit',
        model = 'prop_mp_num_1',
        minGrade = 0,
        zOffset = 0.0
    },
    {
        label = 'Panneau Gauche',
        model = 'prop_mp_num_2',
        minGrade = 0,
        zOffset = 0.0
		
    },
    {
        label = 'Panneau Stop',
        model = 'prop_mp_num_4',
        minGrade = 0,
        zOffset = 0.0
	},
    {
        label = 'Panneau innondation',
        model = 'prop_mp_num_5',
        minGrade = 0,
        zOffset = 0.0
    },
    {
        label = 'Route barré',
        model = 'prop_mp_num_6',
        minGrade = 0,
        zOffset = 0.0
	},
    {
        label = 'Barrieres simple',
        model = 'prop_mp_barrier_02b',
        minGrade = 0,
        zOffset = 0.0
	},
    {
        label = 'Barriere route barré',
        model = 'prop_mp_barrier_02',
        minGrade = 0,
        zOffset = 0.0
    }
}

-- Codes radio et Alertes
Config.Alerts = {
    duration = 180, -- Durée d'affichage du blip en secondes
    radioCodes = {
        { code = '10-0', label = 'Urgence absolue - Agent en danger', color = 'red' },
        { code = '10-13', label = 'Officier à terre', color = 'red' },
        { code = '10-20', label = 'Localisation demandée', color = 'blue' },
        { code = '10-31', label = 'Crime en cours', color = 'orange' },
        { code = '10-32', label = 'Individu armé', color = 'red' },
        { code = '10-71', label = 'Fusillade', color = 'red' }
    },
    blip = {
        sprite = 161,
        color = 1,
        scale = 1.0
    }
}

-- Configuration des plaintes
Config.Complaints = {
    categories = {
        { label = 'Vol', value = 'theft' },
        { label = 'Agression', value = 'assault' },
        { label = 'Vandalisme', value = 'vandalism' },
        { label = 'Autre', value = 'other' }
    }
}

-- Configuration Discord Webhook
Config.DiscordWebhook = {
    rendezvous = 'https://discord.com/api/webhooks/1346204711359090738/K2zGucmULVKDXZds_gdPvryHs5wn1ATE_oG63lx5fGhjzZrLQC7xoVb8ecFfm_EjpHS4',  -- Webhook pour les rendez-vous
    alerts = 'https://discord.com/api/webhooks/1346204495369080892/jbqVCoRAUoyzcPryZzY6jQwcQwfG2QUcnfzRA7PP6DtcqXlwZ4cMmcEv5FQvhRtAfa8z',          -- Webhook pour les alertes courantes
    plaintes = 'https://discord.com/api/webhooks/1349360787092672573/rdcP5z7zycpVroDDqc6Vsp6KmBSxAnvrGNoI9gPynW0wTUDKkzVfPXONMzzAurwGRNvj',      -- Webhook pour les plaintes et vols de véhicules
    casier = 'https://discord.com/api/webhooks/1346204147652755456/gAnNtWMI9cccp5UGu3c-0hQ6tK3tDCMgmoxw8wvEF_fgH_oF7Vn-RwHUbiCbP24NQqvg'           -- Webhook pour les casiers judiciaires
}


-- Configuration K9
Config.K9 = {
    minGrade = 2, -- Grade minimum pour utiliser un chien
    model = "a_c_shepherd" -- Modèle du chien
}

-- Configuration des amendes
Config.Fines = {
    categories = {
        {
            label = 'Infractions routières mineures',
            minAmount = 100,
            maxAmount = 1000
        },
        {
            label = 'Infractions routières graves',
            minAmount = 1000,
            maxAmount = 5000
        },
        {
            label = 'Infractions pénales',
            minAmount = 5000,
            maxAmount = 20000
        }
    }
}

-- Temps d'animations (en ms)
Config.Animations = {
    handcuff = 2000,    -- Temps pour menotter
    search = 5000,      -- Temps pour fouiller
    impound = 10000,    -- Temps pour la fourrière
    unlock = 3000       -- Temps pour déverrouiller
}