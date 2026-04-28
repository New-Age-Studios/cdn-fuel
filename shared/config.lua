Config = {}

-------------------------------------------------------------------------------
-- [ SEÇÃO 1: CONFIGURAÇÕES GERAIS E DEBUG ]
-------------------------------------------------------------------------------
Config.Core = 'qb-core'                 -- Nome do recurso do core (Ex: 'qbx-core' | 'qb-core')
Config.FuelDebug = true                -- Habilita marcadores visuais, prints no F8 e comandos /setfuel.
Config.DebugColor = "#FF00FF"           -- Cor HEX para os marcadores de debug (esferas e contornos).
Config.PolyDebug = false              -- Habilita o debug de PolyZones (visualizar áreas).
Config.FuelDecor = "_FUEL_LEVEL"        -- Decorator do nível de combustível (Não alterar).
Config.WaitTime = 400                   -- Tempo de espera após callbacks (ajuste se menus falharem).
Config.Timezone = "CUSTOM"              -- Fuso horário para a UI e logs.
Config.TimezoneOffsets = {
    UTC = 0, GMT = 0, EST = -5 * 3600, CST = -6 * 3600, MST = -7 * 3600, 
    PST = -8 * 3600, AKST = -9 * 3600, HST = -10 * 3600, EDT = -4 * 3600, 
    CDT = -5 * 3600, MDT = -6 * 3600, PDT = -7 * 3600, CET = 1 * 3600, 
    EET = 2 * 3600, WET = 0, IST = 5.5 * 3600, CST_China = 8 * 3600, 
    JST = 9 * 3600, KST = 9 * 3600, AEST = 10 * 3600, ACST = 9.5 * 3600, 
    AWST = 8 * 3600, CUSTOM = -3 * 3600, -- Brasilia Time
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 2: UI E CUSTOMIZAÇÃO VISUAL ]
-------------------------------------------------------------------------------
Config.Ox = {
    Inventory = true,                   -- Usa metadados do OX_Inventory.
    Menu = true,                        -- Usa Menus de Contexto da OX Lib.
    Input = true,                       -- Usa Diálogos de Input da OX Lib.
    DrawText = true,                    -- Usa DrawText da OX Lib.
    Progress = true                     -- Usa Barras de Progresso da OX Lib.
}
Config.Colors = {
    primary = "#ffffffff",              -- Cor principal de destaque da UI.
    hover = "#e6e6e6ff"                 -- Cor de destaque ao passar o mouse.
}
Config.ShowNearestGasStationOnly = true -- Mostra apenas os postos mais próximos no mapa.
Config.ElectricSprite = 620             -- Ícone do blip para carregadores elétricos.

-------------------------------------------------------------------------------
-- [ SEÇÃO 3: SISTEMA DE REABASTECIMENTO (GASOLINA) ]
-------------------------------------------------------------------------------
Config.CostMultiplier = 3               -- Preço base por litro.
Config.GlobalTax = 15.0                 -- Porcentagem de imposto cobrada na bomba.
Config.RefuelTime = 600                 -- Velocidade do progresso (litros * este valor).
Config.PumpHose = true                  -- Habilita a mangueira física (corda).
Config.RopeType = {
    ['fuel'] = 3,                       -- Estilo visual da mangueira de gasolina (1-5).
    ['electric'] = 3                    -- Estilo visual do cabo elétrico (1-5).
}
-------------------------------------------------------------------------------
-- [ SEÇÃO EXTRA: POSTO MARÍTIMO (PLATAFORMA) ]
-------------------------------------------------------------------------------
Config.MaritimePlatform = {
    Model = "prop_gas_tank_02a", -- Coloque aqui o nome do SEU modelo 3D da plataforma marítima
    
    -- Vetores de deslocamento relativo ao centro do modelo (X, Y, Z)
    -- Ajuste esses valores para encaixar perfeitamente com o seu 3D!
    OwnerInteractionOffset = vec3(0.0, 0.0, 5.0), -- Onde fica o menu de gerenciamento do dono
    
    -- Central de Descarregamento Continental (Para caminhões)
    -- Informe as coordenadas no mapa (vector4 com Heading) onde ficará o tanque em terra firme!
    CentralUnloadCoords = vector4(-319.22, -2763.1, 4.0, 92.47), 
    
    PumpOffsets = {
        -- Bomba 1
        { target = vec3(3.0, 3.0, 1.0), rope = vec3(3.0, 3.0, 1.5) },
        -- Bomba 2
        { target = vec3(3.0, -3.0, 1.0), rope = vec3(3.0, -3.0, 1.5) },
        -- Bomba 3
        { target = vec3(-3.0, 3.0, 1.0), rope = vec3(-3.0, 3.0, 1.5) },
        -- Bomba 4
        { target = vec3(-3.0, -3.0, 1.0), rope = vec3(-3.0, -3.0, 1.5) }
    }
}

Config.PumpModels = {
    'prop_gas_pump_1d',
    'prop_gas_pump_1a',
    'prop_gas_pump_1b',
    'prop_gas_pump_1c',
    'prop_vintage_pump',
    'prop_gas_pump_old2',
    'prop_gas_pump_old3',
    'prop_gas_tank_02a', -- Aviation Tank
    Config.MaritimePlatform.Model
}
Config.PumpRopeOffsets = {              -- Pontos de origem da mangueira por modelo de bomba.
    ["prop_gas_pump_1d"] = vec3(1.0, 0.0, 2.1),
    ["prop_gas_pump_1a"] = vec3(0.0, 0.0, 2.1),
    ["prop_gas_pump_1b"] = vec3(0.0, 0.0, 2.1),
    ["prop_gas_pump_1c"] = vec3(0.0, 0.0, 2.1),
    ["prop_vintage_pump"] = vec3(-0.2, 0.05, 1.2),
    ["prop_gas_pump_old2"] = vec3(0.0, 0.0, 1.8),
    ["prop_gas_pump_old3"] = vec3(0.0, 0.0, 1.8),
    ["denis3d_prop_gas_pump"] = vec3(0.0, 0.0, 2.1),
    ["default"] = vec3(0.0, 0.0, 2.1)
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 4: SISTEMA DE AVIAÇÃO (JET A) ]
-------------------------------------------------------------------------------
Config.AviationFuelEnabled = true       -- Habilita o sistema de combustível JET A.
Config.AviationFuelLabel = "JET A-1"    -- Nome exibido na interface para aeronaves.
Config.AviationReservesPrice = 12       -- Preço por litro que o dono paga no depósito.
Config.AviationCostMultiplier = 15      -- Preço de venda padrão por litro (se não houver dono).
Config.AviationPumpOffsets = {
    ["prop_gas_tank_02a"] = {
        ropeOffset = vec3(0.0, 0.0, 0.50), 
        unload = { pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } 
    }
}
Config.AviationJerryCanPrice = 100      -- Preço do galão de aviação
Config.AviationJerryCanGas = 25         -- Quantidade INICIAL de combustível (L) ao comprar (padrão: 25)
Config.AviationJerryCanCap = 50         -- Capacidade MÁXIMA que o galão de aviação suporta (L)




Config.AviationVehicleClasses = {
    [15] = true, -- Helicopters
    [16] = true, -- Planes
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 5: SISTEMA DE RECARGA ELÉTRICA ]
-------------------------------------------------------------------------------
Config.AllowVehicleEmptyPushing = true  -- Permite empurrar veículos sem combustível?
Config.VehicleShutoffOnLowFuel = true   -- Desliga o motor de veículos quando estão sem gasolina?
Config.AirAndWaterVehicleFueling = true -- Permite abastecimento geral de barcos e aviões (além do sistema dedicado)?
Config.ElectricVehicleCharging = true   -- Habilita suporte a veículos elétricos.
Config.ElectricChargingPrice = 4        -- Preço por KWh de recarga.
Config.ElectricNozzleModel = "newage_fuel_d"
Config.ElectricChargerModel = "newage_fuel_c"
Config.ElectricRopeOffset = vec3(-0.3, 0.0, 1.85)
Config.ElectricNozzleAttachment = {
    pos = vec3(0.25, 0.10, -0.018),
    rot = vec3(-45.0, 120.0, 75.0),
    bone = 18905                        -- ID do Osso (18905: Mão Esquerda).
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 5.1: GESTÃO DE ENERGIA (PARA DONOS) ]
-------------------------------------------------------------------------------
Config.ElectricManagement = {
    Enabled = true,
    KwhPriceForOwners = 2.5,             -- Quanto o DONO paga por cada kWh consumido no posto.
    BillingInterval = "daily",           -- Opções: 'seconds' (teste), 'daily', 'weekly', 'monthly'.
    GracePeriodDays = 3,                 -- Dias de carência após o vencimento antes de desativar as bombas.
    
    -- Planos de Fidelidade Elétrica (Desconto no custo da energia para o DONO)
    LoyaltyPlans = {
        [0] = { label = "Plano Básico", price = 0, discount = 0 },
        [1] = { label = "Plano Eco-Friendly", price = 25000, discount = 10 }, -- 10% de desconto no kWh
        [2] = { label = "Plano Sustentável", price = 75000, discount = 25 },  -- 25% de desconto no kWh
        [3] = { label = "Parceiro Carbono Zero", price = 150000, discount = 50 } -- 50% de desconto no kWh
    }
}


-------------------------------------------------------------------------------
-- [ SEÇÃO 5: INTERAÇÃO E TARGET ]
-------------------------------------------------------------------------------
Config.TargetResource = "ox_target"     -- Suportado: 'qb-target', 'ox_target'.
Config.FuelTargetExport = false         -- Correção para issues antigas do qb-target.
Config.FaceTowardsVehicle = true        -- Ped vira de frente para o bocal do carro.

-------------------------------------------------------------------------------
-- [ SEÇÃO 6: LOGÍSTICA E SISTEMA DE ENTREGAS ]
-------------------------------------------------------------------------------
Config.OwnersPickupFuel = true          -- Donos de postos devem buscar suas cargas no depósito.
Config.UnloadPropModel = "newage_fuel_b" -- Prop para descarregamento no posto.
Config.UnloadNozzleAttachment = {        -- Posição do bico engatado na prop de descarga.
    pos = vec3(0.0, 1.05, 0.35),
    rot = vec3(-20.0, 0.0, 180.0)
}
Config.TankerLoadPropModel = "newage_fuel_a"   -- Bomba de carregamento no depósito.
Config.TankerLoadRopeOffset = vec3(0.2, 0.0, 0.1) -- Origem da corda no depósito.
Config.TankerLoadDuration = 20000              -- Tempo para encher o caminhão (ms).
Config.SmallDeliveryThreshold = 500            -- Pedidos <= este valor usam caminhão rígido.
Config.SmallDeliveryTruck = "mtanker2"         -- Modelo do caminhão rígido.
Config.PossibleDeliveryTrucks = { "hauler", "phantom", "packer" }
Config.DeliveryTruckSpawns = {
    ['trailer'] = vector4(1724.0, -1649.7, 112.57, 194.24),
    ['truck'] = vector4(1727.08, -1664.01, 112.62, 189.62),
    ['tankerLoadProp'] = vector4(1677.25, -1863.08, 107.20, 200.11),
    ['PolyZone'] = {
        ['coords'] = {
            vector2(1724.62, -1672.36), vector2(1719.01, -1648.33),
            vector2(1730.99, -1645.62), vector2(1734.42, -1673.32),
        },
        ['minz'] = 110.0, ['maxz'] = 115.0,
    }
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 7: SEGURANÇA E EXPLOSÕES ]
-------------------------------------------------------------------------------
Config.LeaveEngineRunning = false       -- Se true, permite sair do carro com motor ligado (segurando F).
Config.VehicleBlowUp = true             -- Chance de explosão se abastecer com motor ligado.
Config.BlowUpChance = 5                 -- Porcentagem de chance (0-100).
Config.FuelNozzleExplosion = false      -- Explode se o player fugir com a mangueira engatada.
Config.VehicleShutoffOnLowFuel = {
    ['shutOffLevel'] = 0,               -- Nível em que o motor morre por falta de gasolina.
    ['sounds'] = {
        ['enabled'] = true,
        ['audio_bank'] = "DLC_PILOT_ENGINE_FAILURE_SOUNDS",
        ['sound'] = "Landing_Tone",
    }
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 8: DESCONTOS E PRIVILÉGIOS DE CARGO ]
-------------------------------------------------------------------------------
Config.EmergencyServicesDiscount = {
    ['enabled'] = true,
    ['discount'] = 30,                  -- Porcentagem de desconto (Ex: 30%).
    ['emergency_vehicles_only'] = true, -- Desconto apenas para veículos de emergência.
    ['ondutyonly'] = true,              -- Apenas para quem estiver em serviço.
    ['job'] = { "police", "sasp", "trooper", "ambulance" },
    ['vehicles'] = { "wra45" }           -- Veículos extras fora da Classe 18.
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 9: GALÕES E ROUBO (SIFÃO) ]
-------------------------------------------------------------------------------
Config.UseJerryCan = true               -- Habilita o uso de Galões (Jerry Cans).
Config.JerryCanCap = 50                 -- Capacidade máxima do galão (L).
Config.JerryCanPrice = 200              -- Preço do galão vazio.
Config.JerryCanGas = 25                 -- Gasolina inicial ao comprar o galão.
Config.UseSyphoning = true              -- Habilita o roubo de gasolina com mangueira.
Config.SyphonDebug = false
Config.SyphonKitCap = 50                -- Limite do kit de sifonagem.
Config.SyphonPoliceCallChance = 25      -- Chance de alerta policial ao roubar.
Config.SyphonDispatchSystem = "ps-dispatch" -- "ps-dispatch", "qb-dispatch", "qb-default" ou "custom".

-------------------------------------------------------------------------------
-- [ SEÇÃO 10: ANIMAÇÕES ]
-------------------------------------------------------------------------------
Config.RefuelAnimation = "gar_ig_5_filling_can"
Config.RefuelAnimationDictionary = "timetable@gardener@filling_can"
Config.JerryCanAnimDict = 'weapon@w_sp_jerrycan'
Config.JerryCanAnim = 'fire'
Config.StealAnimDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
Config.StealAnim = 'machinic_loop_mechandplayer'

-------------------------------------------------------------------------------
-- [ SEÇÃO 11: GESTÃO DE POSTOS PRÓPRIOS (PLAYERS) ]
-------------------------------------------------------------------------------
Config.PlayerOwnedGasStationsEnabled = true 
Config.StationFuelSalePercentage = 0.65     -- Porcentagem da venda que vai para o dono.
Config.UnlimitedFuel = false                -- Se true, donos não precisam reabastecer o estoque.
Config.MaxFuelReserves = 50000             -- Estoque máximo base.
Config.FuelReservesPrice = 3               -- Preço por litro pago pelo dono no depósito.
Config.DefaultFuelOnPurchase = 5000        -- Gasolina inicial ao comprar o posto.
Config.EmergencyShutOff = false             -- Permite players desligarem as bombas via Ped.
Config.OneStationPerPerson = false           -- Limita 1 posto por CPF/ID.
Config.PlayerControlledFuelPrices = true    -- Permite o dono alterar o preço de venda.
Config.MinimumFuelPrice = 2
Config.MaxFuelPrice = 8
Config.GasStationSellPercentage = 50        -- Quanto o player recebe ao vender o posto.
Config.GasStationNameChanges = true         -- Permite trocar o nome do posto.
Config.NameChangeMinChar = 10
Config.NameChangeMaxChar = 25

Config.StationUpgrades = {
    [0] = { label = "Tanque Padrão", capacity = 50000, price = 0 },
    [1] = { label = "Expansão Nível 1", capacity = 100000, price = 50000 },
    [2] = { label = "Expansão Nível 2", capacity = 250000, price = 150000 },
    [3] = { label = "Tanque Industrial", capacity = 500000, price = 300000 },
}

Config.LoyaltyUpgrades = {
    [0] = { label = "Fidelidade Bronze", fuelPrice = 3, price = 0, color = "#CD7F32" },
    [1] = { label = "Fidelidade Prata", fuelPrice = 2, price = 25000, color = "#C0C0C0" },
    [2] = { label = "Fidelidade Ouro", fuelPrice = 1.5, price = 75000, color = "#FFD700" },
    [3] = { label = "Fidelidade Diamante", fuelPrice = 1, price = 150000, color = "#B9F2FF" },
}

-------------------------------------------------------------------------------
-- [ SEÇÃO 12: DADOS ESTÁTICOS E LISTAS ]
-------------------------------------------------------------------------------
Config.NoFuelUsage = { ["bmx"] = { blacklisted = true } }
Config.ElectricVehicles = {
    ["surge"] = { isElectric = true }, ["iwagen"] = { isElectric = true },
    ["voltic"] = { isElectric = true }, ["voltic2"] = { isElectric = true },
    ["raiden"] = { isElectric = true }, ["cyclone"] = { isElectric = true },
    ["tezeract"] = { isElectric = true }, ["neon"] = { isElectric = true },
    ["omnisegt"] = { isElectric = true }, ["caddy"] = { isElectric = true },
    ["caddy2"] = { isElectric = true }, ["caddy3"] = { isElectric = true },
    ["airtug"] = { isElectric = true }, ["rcbandito"] = { isElectric = true },
    ["imorgon"] = { isElectric = true }, ["dilettante"] = { isElectric = true },
    ["khamelion"] = { isElectric = true },
}
Config.Classes = {
    [0]=1.0, [1]=1.0, [2]=1.0, [3]=1.0, [4]=1.0, [5]=1.0, [6]=1.0, [7]=1.0, [8]=1.0, 
    [9]=1.0, [10]=1.0, [11]=1.0, [12]=1.0, [13]=0.0, [14]=1.0, [15]=1.0, [16]=1.0, 
    [17]=1.0, [18]=1.0, [19]=1.0, [20]=1.0, [21]=1.0,
}
Config.FuelUsage = {
    [1.0]=1.3, [0.9]=1.1, [0.8]=0.9, [0.7]=0.8, [0.6]=0.7, [0.5]=0.5, 
    [0.4]=0.3, [0.3]=0.2, [0.2]=0.1, [0.1]=0.1, [0.0]=0.0,
}
Config.AirAndWaterVehicleFueling = {
    ['enabled'] = true,
    ['refuel_button'] = 47,   -- Botão "G"
    ['nozzle_length'] = 20.0, 
    ['air_fuel_price'] = 10,  
    ['water_fuel_price'] = 4, 
    ['locations'] = {}
}
Config.GasStations = {}
Config.ProfanityList = {
    "4r5e", "5h1t", "5hit", "a55", "anal", "anus", "ar5e", "arrse", "arse", "ass", "ass-fucker", "asses", "assfucker", "assfukka", "asshole", "assholes", "asswhole", "a_s_s", "b!tch", "b00bs", "b17ch", "b1tch", "ballbag", "balls", "ballsack", "bastard", "beastial", "beastiality", "bellend", "bestial", "bestiality", "bi+ch", "biatch", "bitch", "bitcher", "bitchers", "bitches", "bitchin", "bitching", "bloody", "blow job", "blowjob", "blowjobs", "boiolas", "bollock", "bollok", "boner", "boob", "boobs", "booobs", "boooobs", "booooobs", "booooooobs", "breasts", "buceta", "bugger", "bum", "bunny fucker", "butt", "butthole", "buttmuch", "buttplug", "c0ck", "c0cksucker", "carpet muncher", "cawk", "chink", "cipa", "cl1t", "clit", "clitoris", "clits", "cnut", "cock", "cock-sucker", "cockface", "cockhead", "cockmunch", "cockmuncher", "cocks", "cocksuck", "cocks darkness", "cocksucker", "cocksucking", "cocksucks", "cocksuka", "cocksukka", "cok", "cokmuncher", "coksucka", "coon", "cox", "crap", "cum", "cummer", "cumming", "cums", "cumshot", "cunilingus", "cunillingus", "cunnilingus", "cunt", "cuntlick", "cuntlicker", "cuntlicking", "cunts", "cyalis", "cyberfuc", "cyberfuck", "cyberfucked", "cyberfucker", "cyberfuckers", "cyberfucking", "d1ck", "damn", "dick", "dickhead", "dildo", "dildos", "dink", "dinks", "dirsa", "dlck", "dog-fucker", "doggin", "dogging", "donkeyribber", "doosh", "duche", "dyke", "ejaculate", "ejaculated", "ejaculates", "ejaculating", "ejaculatings", "ejaculation", "ejakulate", "f u c k", "f u c k e r", "f4nny", "fag", "fagging", "faggitt", "faggot", "faggs", "fagot", "fagots", "fags", "fanny", "fannyflaps", "fannyfucker", "fanyy", "fatass", "fcuk", "fcuker", "fcuking", "feck", "fecker", "felching", "fellate", "fellatio", "fingerfuck", "fingerfucked", "fingerfucker", "fingerfuckers", "fingerfucking", "fingerfucks", "fistfuck", "fistfucked", "fistfucker", "fistfuckers", "fistfucking", "fistfuckings", "fistfucks", "flange", "fook", "fooker", "fuck", "fucka", "fucked", "fucker", "fuckers", "fuckhead", "fuckheads", "fuckin", "fucking", "fuckings", "fuckingshitmotherfucker", "fuckme", "fucks", "fuckwhit", "fuckwit", "fudge packer", "fudgepacker", "fuk", "fuker", "fukker", "fukkin", "fuks", "fukwhit", "fukwit", "fux", "fux0r", "f_u_c_k", "gangbang", "gangbanged", "gangbangs", "gaylord", "gaysex", "goatse", "God", "god-dam", "god-damned", "goddamn", "goddamned", "hardcoresex", "hell", "heshe", "hoar", "hoare", "hoer", "homo", "hore", "horniest", "horny", "hotsex", "jack-off", "jackoff", "jap", "jerk-off", "jism", "jiz", "jizm", "jizz", "kawk", "knob", "knobead", "knobed", "knobend", "knobhead", "knobjocky", "knobjokey", "kock", "kondum", "kondums", "kum", "kummer", "kumming", "kums", "kunilingus", "l3i+ch", "l3itch", "labia", "lust", "lusting", "m0f0", "m0fo", "m45terbate", "ma5terb8", "ma5terbate", "masochist", "master-bate", "masterb8", "masterbat*", "masterbat3", "masterbate", "masterbation", "masterbations", "masturbate", "mo-fo", "mof0", "mofo", "mothafuck", "mothafucka", "mothafuckas", "mothafuckaz", "mothafucked", "mothafucker", "mothafuckers", "mothafuckin", "mothafucking", "mothafuckings", "mothafucks", "mother fucker", "motherfuck", "motherfucked", "motherfucker", "motherfuckers", "motherfuckin", "motherfucking", "motherfuckings", "motherfuckka", "motherfucks", "muff", "mutha", "muthafecker", "muthafuckker", "muther", "mutherfucker", "n1gga", "n1gger", "nazi", "nigg3r", "nigg4h", "nigga", "niggah", "niggas", "niggaz", "nigger", "niggers", "nob", "nob jokey", "nobhead", "nobjocky", "nobjokey", "numbnuts", "nutsack", "orgasim", "orgasims", "orgasm", "orgasms", "p0rn", "pawn", "pecker", "penis", "penisfucker", "phonesex", "phuck", "phuk", "phuked", "phuking", "phukkked", "phukking", "phuks", "phuq", "pigfucker", "pimpis", "piss", "pissed", "pisser", "pissers", "pisses", "pissflaps", "pissin", "pissing", "pissoff", "poop", "porn", "porno", "pornography", "pornos", "prick", "pricks", "pron", "pube", "pusse", "pussi", "pussies", "pussy", "pussys", "rectum", "retard", "rimjaw", "rimming", "s hit", "s.o.b.", "sadist", "schlong", "screwing", "scroat", "scrote", "scrotum", "semen", "sex", "sh!+", "sh!t", "sh1t", "shag", "shagger", "shaggin", "shagging", "shemale", "shi+", "shit", "shitdick", "shite", "shited", "shitey", "shitfuck", "shitfull", "shithead", "shiting", "shitings", "shits", "shitted", "shitter", "shitters", "shitting", "shittings", "shitty", "skank", "slut", "sluts", "smegma", "smut", "snatch", "son-of-a-bitch", "spac", "spunk", "s_h_i_t", "t1tt1e5", "t1tties", "teets", "teez", "testical", "testicle", "tit", "titfuck", "tits", "titt", "tittie5", "tittiefucker", "titties", "tittyfuck", "tittywank", "titwank", "tosser", "turd", "tw4t", "twat", "twathead", "twatty", "twunt", "twunter", "v14gra", "v1gra", "vagina", "viagra", "vulva", "w00se", "wang", "wank", "wanker", "wanky", "whoar", "whore", "willies", "willy", "xrated", "xxx", "arrombado", "babaca", "bicha", "boiola", "bosta", "buceta", "bumm", "cacete", "cadela", "canalha", "caralho", "cassete", "chupa", "corno", "cu", "curra", "cuzao", "cuzão", "debiloide", "desgraca", "desgraça", "escroto", "estupro", "foda", "fodase", "foda-se", "foder", "fofoca", "fudido", "fudida", "gay", "idiota", "imbecil", "iscroto", "merda", "nojo", "otario", "otário", "pau", "pau-no-cu", "pau-no-ku", "pau-nu-cu", "pau-nu-ku", "peido", "pica", "pinto", "porra", "puta", "putaria", "quenga", "rapariga", "retardado", "rola", "safado", "safada", "tesao", "tesão", "transa", "trouxa", "vaca", "vadia", "vadiagem", "veado", "viado", "viciado", "viciada", "xana", "xoxota",
}
