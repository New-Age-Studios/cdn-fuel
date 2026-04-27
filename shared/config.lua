Config = {}
Config.FuelDebug = true                -- Used for debugging, although there are not many areas in yet (Default: false) + Enables Setfuel Commands (0, 50, 100).
Config.PolyDebug = false              -- Enables Polyzone Debugging to see PolyZones!
Config.ShowNearestGasStationOnly = true -- When enabled, only the nearest gas stations will be shown on the map.
Config.LeaveEngineRunning = false        -- When true, the vehicle's engine will be left running upon exit if the player *HOLDS* F.
Config.VehicleBlowUp = true             -- When true, there will be a configurable chance of the vehicle blowing up, if you fuel while the engine is on.
Config.BlowUpChance = 5                 -- Percentage for Chance of Engine Explosion (Default: 5% or 5)
Config.CostMultiplier = 3               -- Amount to multiply 1 by. This indicates fuel price. (Default: $3.0/l or 3.0)
Config.GlobalTax = 15.0                 -- The tax, in %, that people will be charged at the pump. (Default: 15% or 15.0)
Config.FuelNozzleExplosion = false      -- When true, it enables the fuel pump exploding when players run away with the nozzle. Highly recommeded to be false.
Config.FuelDecor = "_FUEL_LEVEL"        -- Do not touch! (Default: "_FUEL_LEVEL")
Config.RefuelTime = 600                 -- Highly recommended to leave at 600. This value will be multiplied times the amount the player is fueling for the progress bar and cancellation logic! DON'T GO BELOW 250, performance WILL drop!
Config.FuelTargetExport = false         -- DO NOT USE WITH OX_TARGET! This is only used to fix this qb-target issue: https://github.com/CodineDev/cdn-fuel/issues/3. <br> <br> If you don't have this issue and haven't installed this exports in qb-target, then this should be false. Otherwise there will be an error.

Config.Colors = {
    primary = "#ffffff", -- Default Green (Tailwind green-500)
    hover = "#e7e7e7"    -- Default Green Hover (Tailwind green-600)
}

function Config.HexToRGB(hex)
    hex = hex:gsub("#","")
    return {
        r = tonumber("0x"..hex:sub(1,2)),
        g = tonumber("0x"..hex:sub(3,4)),
        b = tonumber("0x"..hex:sub(5,6))
    }
end

-- 2.1.1 Update --
Config.OwnersPickupFuel = true -- If an owner buys fuel, they will have to go pick it up at a configured location.
Config.UnloadPropModel = "newage_fuel_b" -- Model of the prop that spawns for unloading fuel at the station.
Config.ElectricNozzleModel = "newage_fuel_d" -- Model of the electric nozzle prop used for charging.
Config.ElectricChargerModel = "newage_fuel_c" -- Model of the electric charger station prop.
Config.TankerLoadPropModel = "newage_refuel_a" -- Model of the loading pump at the depot.
Config.PossibleDeliveryTrucks = {
    "hauler",
    "phantom",
    -- "phantom3", --  This is an fast version of the normal phantom.
    "packer",
}
Config.DeliveryTruckSpawns = { -- https://i.imgur.com/VS22i8R.jpeg
    ['trailer'] = vector4(1724.0, -1649.7, 112.57, 194.24),
    ['truck'] = vector4(1727.08, -1664.01, 112.62, 189.62),
    ['tankerLoadProp'] = vector4(1677.25, -1863.08, 107.20, 200.11),  -- Position of the fuel loading pump at the depot
    ['PolyZone'] = {
        ['coords'] = {
            vector2(1724.62, -1672.36),
            vector2(1719.01, -1648.33),
            vector2(1730.99, -1645.62),
            vector2(1734.42, -1673.32),
        },
        ['minz'] = 110.0,
        ['maxz'] = 115.0,
    }
}
Config.TankerLoadDuration = 20000                   -- How long (ms) it takes to fill the tanker
Config.SmallDeliveryThreshold = 500                 -- Orders with liters <= this amount will use a rigid truck (no trailer)
Config.SmallDeliveryTruck = "mtanker2"               -- Model of the rigid truck for small orders
-- 2.1.1 End

-- 2.1.0 Update
Config.EmergencyServicesDiscount = {
    ['enabled'] = true,                 -- Enables Emergency Services Getting a discount based on the value below for Refueling & Electricity Charging Cost
    ['discount'] = 30,                  -- % Discount off of price.
    ['emergency_vehicles_only'] = true, -- Only allows discounts to be applied to Emergency Vehicles
    ['ondutyonly'] = true,              -- Discount only applies while on duty.
    ['job'] = {
        "police",
        "sasp",
        "trooper",
        "ambulance",
    },
    ['vehicles'] = {
        -- Add specific vehicle spawn names here if they are NOT Class 18 (Emergency)
         "wra45",
        -- "riot",
    }
}
Config.Core = 'qb-core' -- Change this to your core resources (Ex: 'qbx-core' | 'qb-core'), must be qb based!
Config.Ox = {
    Inventory = true,   -- Uses OX_Inventory's metadata instead of QB-Inventory's.
    Menu = true,        -- Uses OX Libraries instead of qb-menu.
    Input = true,       -- Uses Ox Input Dialog instead of qb-input.
    DrawText = true,    -- Uses Ox DrawText instead of qb-core DrawText.
    Progress = true     -- Uses Ox ProgressBar instead of progressbar.
}
Config.TargetResource =
"ox_target"            -- Supported: { 'qb-target', 'ox_target'} -- Others must use the same format as QB-Target or manual configuration is required.
Config.PumpHose = true -- If true, it creates a hose from the pump to the nozzle the client is holding, to give it a more realistic feel.
Config.RopeType = {    -- Options: 1-2-3-4-5; 1: Khaki Color, Kind of Thick, 2: Very Thick Khaki Rope, 3: Very Thick Black Rope, 4: Very Thin Black Rope, 5: Same as 3
    ['fuel'] = 3,
    ['electric'] = 4,
}
Config.FaceTowardsVehicle = true                            -- Ped will turn towards the entity's boot bone for refueling, sometimes can result in incorrect nozzle placement when refueling.
Config.VehicleShutoffOnLowFuel = {                          -- If enabled, vehicles will turn off when the reach 0 fuel. This works well in conjuction with disallowing people to turn on a vehicle with 0 fuel.
    ['shutOffLevel'] = 0,                                   -- At this fuel level, the vehicle will shut off. Default: 0, Recommended: 0-5.
    ['sounds'] = {
        ['enabled'] = true,                                 -- Are Sounds Enabled when vehicle has no fuel?
        -- Find sound banks and sounds here: https://pastebin.com/A8Ny8AHZ.
        ['audio_bank'] = "DLC_PILOT_ENGINE_FAILURE_SOUNDS", -- Audio Bank of Sound.
        ['sound'] = "Landing_Tone",                         -- Sound Name in Audio Bank.
    }
}

-- 2.1.0 End

-- Phone --
Config.RenewedPhonePayment = false -- Enables use of Renewed-Phone Payment System and Notifications

-- Syphoning --
Config.UseSyphoning = true       -- Follow the Syphoning Instalar Guide to enable this option!
Config.SyphonDebug = false         -- Used for Debugging the syphon portion!
Config.SyphonKitCap = 50           -- Maximum amount (in L) the syphon kit can fit!
Config.SyphonPoliceCallChance = 25 -- Math.Random(1, 100) Default: 25%
Config.SyphonDispatchSystem =
"ps-dispatch"                      -- Options: "ps-dispatch", "qb-dispatch", "qb-default" (just blips) or "custom" (Custom: you must configure yourself!)

--- Jerry Can -----
Config.UseJerryCan = true  -- Enable the Jerry Can functionality. Will only work if properly installed.
Config.JerryCanCap = 50    -- Maximum amount (in L) the jerrycan can fit! (Default: 50L)
Config.JerryCanPrice = 200 -- The price of a jerry can, not including tax.
Config.JerryCanGas = 25    -- The amount of Gas that the Jerry Can you purchase comes with. This should not be bigger that your Config.JerryCanCap!

-- Animations --
Config.StealAnimDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'   -- Used for Syphoning
Config.StealAnim = 'machinic_loop_mechandplayer'                    -- Used for Syphoning
Config.JerryCanAnimDict = 'weapon@w_sp_jerrycan'                    -- Used for Syphoning & Jerry Can
Config.JerryCanAnim = 'fire'                                        -- Used for Syphoning & Jerry Can
Config.RefuelAnimation = "gar_ig_5_filling_can"                     -- This is for refueling and charging.
Config.RefuelAnimationDictionary = "timetable@gardener@filling_can" -- This is for refueling and charging.

--- Player Owned Gas (Gasoline) Ergonomic Refueling Stations (Poggers) ---
Config.PlayerOwnedGasStationsEnabled = true -- When true, peds will be located at all gas stations, and players will be able to talk with peds & purchase gas stations, having to manage fuel supplies.
Config.StationFuelSalePercentage = 0.65     -- % of sales that the station gets. If they sell 4 Liters of Gas for $16 (not including taxes), they will get 16*Config.StationFuelSalePercentage back from the sale. Treat this as tax, also, it balances the profit margins a bit.
Config.EmergencyShutOff = false             -- When true, players can walk up to the ped and shut off the pumps at a gas station. While false, this option is disabled, because it can obviously be an issue.
Config.UnlimitedFuel = false                -- When true, the fuel stations will not require refuelling by gas station owners, this is for the early stages of implementation.
Config.MaxFuelReserves = 50000             -- This is the base maximum amount for fuel station reserves.
Config.FuelReservesPrice = 3               -- This is the price per liter for station owners to buy fuel reserves.
Config.DefaultFuelOnPurchase = 5000        -- This is the amount of fuel that a station will have when it is purchased.

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

Config.GasStationSellPercentage = 50        -- This is the percentage that players will get of the gas stations price, when they sell a location!
Config.MinimumFuelPrice = 2                 -- This is the minimum value you want to let players set their fuel prices to.
Config.MaxFuelPrice = 8                     -- This is the maximum value you want to let players set their fuel prices to.
Config.PlayerControlledFuelPrices = true    -- This gives you the option to disable people being able to control fuel prices. When true, players can control the fuel prices via to management menu for the location.
Config.GasStationNameChanges = true         -- This gives you the option to disable people being able to change the name of their gas station, only recommended if it becomes a problem.
Config.NameChangeMinChar = 10               -- This is the minimum length that a Gas Station's name must be.
Config.NameChangeMaxChar = 25               -- This is the maximum length that a Gas Station's name must be.
Config.WaitTime = 400                       -- This is the wait time after callbacks, if you are having issues with menus not popping up, or being greyed out, up this to around ~300, it is not recommended to go over ~750, as menus will get slower and more unresponsive the higher you go. (Fixes this issue: https://www.shorturl.at/eqS19)
Config.OneStationPerPerson = true           -- This prevents players that already own one station from buying another, to prevent monopolies over Gas Stations.

Config.Timezone = "CUSTOM"                   -- Set this to the key from TimezoneOffsets below
Config.TimezoneOffsets = {
    -- Standard Time Zones
    UTC = 0,                  -- Coordinated Universal Time
    GMT = 0,                  -- Greenwich Mean Time
    EST = -5 * 3600,          -- Eastern Standard Time
    CST = -6 * 3600,          -- Central Standard Time
    MST = -7 * 3600,          -- Mountain Standard Time
    PST = -8 * 3600,          -- Pacific Standard Time
    AKST = -9 * 3600,         -- Alaska Standard Time
    HST = -10 * 3600,         -- Hawaii-Aleutian Standard Time

    -- Daylight Saving Time Zones
    EDT = -4 * 3600,          -- Eastern Daylight Time
    CDT = -5 * 3600,          -- Central Daylight Time
    MDT = -6 * 3600,          -- Mountain Daylight Time
    PDT = -7 * 3600,          -- Pacific Daylight Time

    -- European Time Zones
    CET = 1 * 3600,           -- Central European Time
    EET = 2 * 3600,           -- Eastern European Time
    WET = 0,                  -- Western European Time

    -- Asian Time Zones
    IST = 5.5 * 3600,         -- Indian Standard Time
    CST_China = 8 * 3600,     -- China Standard Time
    JST = 9 * 3600,           -- Japan Standard Time
    KST = 9 * 3600,           -- Korea Standard Time

    -- Australian Time Zones
    AEST = 10 * 3600,         -- Australian Eastern Standard Time
    ACST = 9.5 * 3600,        -- Australian Central Standard Time
    AWST = 8 * 3600,          -- Australian Western Standard Time

    -- Custom Example
    CUSTOM = -3 * 3600,       -- Example for customization (Brasilia Time)
}

--- Electric Vehicles
Config.ElectricVehicleCharging = true -- When true, electric vehicles will actually consume resources and decrease 'Fuel / Battery' while driving. This means players will have to recharge their vehicle!
Config.ElectricChargingPrice = 4      -- Per "KW". This value is multiplied times the amount of electricity someone put into their vehicle, to constitute the final cost of the charge. Players whom own the gas station will not recieve the money from electric charging.
Config.ElectricVehicles = {           -- List of Electric Vehicles in the Base Game.
    ["surge"] = {
        isElectric = true,
    },
    ["iwagen"] = {
        isElectric = true,
    },
    ["voltic"] = {
        isElectric = true,
    },
    ["voltic2"] = {
        isElectric = true,
    },
    ["raiden"] = {
        isElectric = true,
    },
    ["cyclone"] = {
        isElectric = true,
    },
    ["tezeract"] = {
        isElectric = true,
    },
    ["neon"] = {
        isElectric = true,
    },
    ["omnisegt"] = {
        isElectric = true,
    },
    ["caddy"] = {
        isElectric = true,
    },
    ["caddy2"] = {
        isElectric = true,
    },
    ["caddy3"] = {
        isElectric = true,
    },
    ["airtug"] = {
        isElectric = true,
    },
    ["rcbandito"] = {
        isElectric = true,
    },
    ["imorgon"] = {
        isElectric = true,
    },
    ["dilettante"] = {
        isElectric = true,
    },
    ["khamelion"] = {
        isElectric = true,
    },
}
Config.ElectricSprite = 620        -- This is for when the player is in an electric charger, the blips with change to this sprite. (Sprite with a car with a bolt going through it: 620)

-- Basic Configuration Settings
-- Turn on Config.FuelDebug and use this command to get the name for here: getVehNameForBlacklist
Config.NoFuelUsage = { -- This is for you to put vehicles that you don't want to use fuel.
    ["bmx"] = {
        blacklisted = true
    },
}

Config.Classes = { -- Class multipliers. If you want SUVs to use less fuel, you can change it to anything under 1.0, and vise versa.
    [0] = 1.0,     -- Compacts
    [1] = 1.0,     -- Sedans
    [2] = 1.0,     -- SUVs
    [3] = 1.0,     -- Coupes
    [4] = 1.0,     -- Muscle
    [5] = 1.0,     -- Sports Classics
    [6] = 1.0,     -- Sports
    [7] = 1.0,     -- Super
    [8] = 1.0,     -- Motorcycles
    [9] = 1.0,     -- Off-road
    [10] = 1.0,    -- Industrial
    [11] = 1.0,    -- Utility
    [12] = 1.0,    -- Vans
    [13] = 0.0,    -- Cycles
    [14] = 1.0,    -- Boats
    [15] = 1.0,    -- Helicopters
    [16] = 1.0,    -- Planes
    [17] = 1.0,    -- Service
    [18] = 1.0,    -- Emergency
    [19] = 1.0,    -- Military
    [20] = 1.0,    -- Commercial
    [21] = 1.0,    -- Trains
}

Config.FuelUsage = { -- The left part is at percentage RPM, and the right is how much fuel (divided by 10) you want to remove from the tank every second
    [1.0] = 1.3,
    [0.9] = 1.1,
    [0.8] = 0.9,
    [0.7] = 0.8,
    [0.6] = 0.7,
    [0.5] = 0.5,
    [0.4] = 0.3,
    [0.3] = 0.2,
    [0.2] = 0.1,
    [0.1] = 0.1,
    [0.0] = 0.0,
}

Config.AirAndWaterVehicleFueling = {
    ['enabled'] = true,
    ['locations'] = {
        -- MRPD Helipad
        [1] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(439.96, -973.0),
                    vector2(458.09, -973.04),
                    vector2(458.26, -989.47),
                    vector2(439.58, -989.94),
                },
                ['minmax'] = {
                    ['min'] = 40,
                    ['max'] = 50.0
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(443.08, -978.15, 47.08, 269.52),
            }
        },
        -- Pillbox Hospital
        [2] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(340.46, -580.02),
                    vector2(351.11, -575.06),
                    vector2(360.2, -578.35),
                    vector2(364.99, -588.36),
                    vector2(361.57, -597.44),
                    vector2(351.71, -601.99),
                    vector2(342.19, -598.38),
                    vector2(337.23, -587.49),
                },
                ['minmax'] = {
                    ['min'] = 72.50,
                    ['max'] = 78.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(362.65, -592.64, 73.16, 71.26),
            }
        },
        -- Cental Los Santos Medical Center
        [3] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(287.81, -1454.52),
                    vector2(298.6, -1441.48),
                    vector2(325.74, -1464.21),
                    vector2(314.95, -1477.29),
                },
                ['minmax'] = {
                    ['min'] = 43.00,
                    ['max'] = 50.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(301.12, -1465.61, 45.51, 321.3),
            }
        },
        -- Devin Weston Terminal
        [4] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-944.57, -2963.51),
                    vector2(-954.6, -2981.75),
                    vector2(-929.13, -2996.81),
                    vector2(-918.35, -2978.74),
                },
                ['minmax'] = {
                    ['min'] = 11.00,
                    ['max'] = 19.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-923.12, -2976.81, 12.95, 149.55),
            }
        },
        -- Back Right Terminal
        [5] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-1658.47, -3109.69),
                    vector2(-1645.78, -3085.85),
                    vector2(-1664.28, -3074.94),
                    vector2(-1677.93, -3098.61),
                },
                ['minmax'] = {
                    ['min'] = 12.00,
                    ['max'] = 19.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-1665.44, -3104.53, 12.94, 329.89),
            }
        },
        -- La Puerta Helicopter Pad #1
        [6] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-701.34, -1441.48),
                    vector2(-728.05, -1473.15),
                    vector2(-712.1, -1486.4),
                    vector2(-685.58, -1454.86),
                },
                ['minmax'] = {
                    ['min'] = 4.00,
                    ['max'] = 10.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-706.13, -1464.14, 4.04, 320.0),
            }
        },
        -- La Puerta Helicopter Pad #2
        [7] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-777.17, -1446.61),
                    vector2(-761.78, -1459.59),
                    vector2(-739.92, -1433.25),
                    vector2(-755.4, -1420.29),
                },
                ['minmax'] = {
                    ['min'] = 4.00,
                    ['max'] = 10.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-764.81, -1434.32, 4.06, 320.0),
            }
        },
        -- La Puerta Boat Dock #1
        [8] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-793.1, -1482.94),
                    vector2(-786.39, -1500.85),
                    vector2(-809.39, -1508.94),
                    vector2(-817.48, -1491.62),
                },
                ['minmax'] = {
                    ['min'] = -5.00,
                    ['max'] = 8.50
                },
            },
            ['draw_text'] = "[G] Reabastecer embarcações",
            ['type'] = 'water',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-805.9, -1496.68, 0.6, 200.00),
            }
        },
        -- Fort Zancudo Military Base Hangar
        [9] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-2145.24, 3291.63),
                    vector2(-2127.94, 3281.7),
                    vector2(-2139.37, 3260.35),
                    vector2(-2157.69, 3271.1),
                },
                ['minmax'] = {
                    ['min'] = 30.00,
                    ['max'] = 37.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-2148.8, 3283.99, 31.81, 240.0),
            }
        },
        -- Paleto Bay Police Department
        [10] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-497.03, 5987.98),
                    vector2(-476.48, 6008.6),
                    vector2(-454.99, 5986.53),
                    vector2(-475.77, 5966.83),
                },
                ['minmax'] = {
                    ['min'] = 30.00,
                    ['max'] = 37.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-486.22, 5977.65, 30.3, 315.4),
            }
        },
        -- Grapeseed Airfield
        [11] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(2094.41, 4771.26),
                    vector2(2080.85, 4797.71),
                    vector2(2104.56, 4811.8),
                    vector2(2118.06, 4782.09),
                },
                ['minmax'] = {
                    ['min'] = 40.00,
                    ['max'] = 47.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(2101.82, 4776.8, 40.02, 21.41),
            }
        },
        -- Grapeseed Airfield
        [12] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(1347.76, 4277.37),
                    vector2(1330.47, 4279.02),
                    vector2(1328.53, 4261.64),
                    vector2(1346.13, 4260.88),
                },
                ['minmax'] = {
                    ['min'] = 28.00,
                    ['max'] = 37.50
                },
            },
            ['draw_text'] = "[G] Reabastecer embarcações",
            ['type'] = 'water',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(1338.13, 4269.62, 30.5, 85.00),
            }
        },
        -- Bob Smith PD
        [13] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-1083.85, -837.07),
                    vector2(-1100.36, -849.84),
                    vector2(-1108.85, -839.11),
                    vector2(-1107.04, -837.76),
                    vector2(-1109.65, -834.04),
                    vector2(-1104.1, -829.69),
                    vector2(-1104.29, -829.07),
                    vector2(-1095.62, -822.42),
                },
                ['minmax'] = {
                    ['min'] = 36.00,
                    ['max'] = 42.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = true,
                ['on_duty_only'] = true,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-1089.72, -830.6, 36.68, 129.00),
            }
        },
        -- Merryweather Helipad
        [14] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(488.84, -3383.66),
                    vector2(489.23, -3356.98),
                    vector2(467.46, -3356.83),
                    vector2(467.58, -3383.62),
                    vector2(472.59, -3383.59),
                    vector2(472.63, -3382.13),
                    vector2(476.67, -3382.11),
                    vector2(476.8, -3383.94),
                },
                ['minmax'] = {
                    ['min'] = 4.50,
                    ['max'] = 10.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(483.28, -3382.83, 5.07, 0.0),
            }
        },
        -- Airport Helipad #1 & #2
        [15] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-1133.49, -2860.32),
                    vector2(-1143.33, -2877.61),
                    vector2(-1191.03, -2850.14),
                    vector2(-1180.98, -2832.84),
                },
                ['minmax'] = {
                    ['min'] = 12.50,
                    ['max'] = 18.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-1158.29, -2848.67, 12.95, 240.0),
            }
        },
        -- Airport Helipad #3
        [16] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(-1124.63, -2865.31),
                    vector2(-1134.74, -2882.56),
                    vector2(-1108.76, -2897.71),
                    vector2(-1099.04, -2880.39),
                },
                ['minmax'] = {
                    ['min'] = 12.50,
                    ['max'] = 18.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(-1125.15, -2866.97, 12.95, 240.0),
            }
        },
        -- Sandy Shores Helipad
        [17] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(1764.15, 3226.34),
                    vector2(1758.66, 3246.44),
                    vector2(1777.28, 3250.51),
                    vector2(1781.89, 3230.8),
                },
                ['minmax'] = {
                    ['min'] = 40.50,
                    ['max'] = 47.50
                },
            },
            ['draw_text'] = "[G] Reabastecer helicóptero",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(1771.81, 3229.24, 41.51, 15.00),
            }
        },
        -- Sandy Shores Hangar
        [18] = {
            ['PolyZone'] = {
                ['coords'] = {
                    vector2(1755.37, 3301.3),
                    vector2(1764.9, 3294.63),
                    vector2(1769.42, 3277.19),
                    vector2(1728.83, 3266.58),
                    vector2(1721.75, 3291.6),
                },
                ['minmax'] = {
                    ['min'] = 40.00,
                    ['max'] = 47.50
                },
            },
            ['draw_text'] = "[G] Reabastecer aeronaves",
            ['type'] = 'air',
            ['whitelist'] = {
                ['enabled'] = false,
                ['on_duty_only'] = false,
                ['whitelisted_jobs'] = {
                    'police', 'ambulance'
                },
            },
            ['prop'] = {
                ['model'] = 'prop_gas_pump_1d',
                ['coords'] = vector4(1748.31, 3297.08, 40.16, 15.0),
            }
        },
        -- La Mesa Landing Pad (Custom)
        -- Does not work in conjunction with Gabz Trooper PD.
        -- [19] = {
        --     ['PolyZone'] = {
        --         ['coords'] = {
        --             vector2(830.66, -1378.54),
        --             vector2(834.87, -1382.59),
        --             vector2(834.81, -1388.5),
        --             vector2(830.75, -1392.54),
        --             vector2(824.96, -1392.58),
        --             vector2(820.8, -1388.39),
        --             vector2(820.84, -1382.65),
        --             vector2(824.97, -1378.52)
        --         },
        --         ['minmax'] = {
        --             ['min'] = 35.67,
        --             ['max'] = 38.67
        --         },
        --     },
        --     ['draw_text'] = "[G] Reabastecer aeronaves",
        --     ['type'] = 'air',
        --     ['whitelist'] = {
        --         ['enabled'] = false,
        --         ['on_duty_only'] = true,
        --         ['whitelisted_jobs'] = {
        --             'police', 'ambulance',
        --         }
        --     },
        --     ['prop'] = {
        --         ['model'] = 'prop_gas_pump_1c',
        --         ['coords'] = vector4(827.55, -1378.57, 36.67, 1.11)
        --     }
        -- }
    },
    ['refuel_button'] = 47,   -- "G" Button for Draw Text.
    ['nozzle_length'] = 20.0, -- The max distance you can go from the "Special Pump" before the nozzle in returned to the pump.
    ['air_fuel_price'] = 10,  -- Price Per Liter of Fuel for Air Vehicles (Emergency Services Discount Still Applies)
    ['water_fuel_price'] = 4, -- Price Per Liter of Fuel for Water Vehicles (Emergency Services Discount Still Applies)
}

Config.GasStations = { -- Configuration options for various gas station related things, including peds, coords and labels.
    -- All stations are now loaded from data/locations.json
}

-- Profanity Dictionary from another source, used for stopping people from putting the words blacklisted as the name of their gas stations. --

Config.ProfanityList = {
    "4r5e",
    "5h1t",
    "5hit",
    "a55",
    "anal",
    "anus",
    "ar5e",
    "arrse",
    "arse",
    "ass",
    "ass-fucker",
    "asses",
    "assfucker",
    "assfukka",
    "asshole",
    "assholes",
    "asswhole",
    "a_s_s",
    "b!tch",
    "b00bs",
    "b17ch",
    "b1tch",
    "ballbag",
    "balls",
    "ballsack",
    "bastard",
    "beastial",
    "beastiality",
    "bellend",
    "bestial",
    "bestiality",
    "bi+ch",
    "biatch",
    "bitch",
    "bitcher",
    "bitchers",
    "bitches",
    "bitchin",
    "bitching",
    "bloody",
    "blow job",
    "blowjob",
    "blowjobs",
    "boiolas",
    "bollock",
    "bollok",
    "boner",
    "boob",
    "boobs",
    "booobs",
    "boooobs",
    "booooobs",
    "booooooobs",
    "breasts",
    "buceta",
    "bugger",
    "bum",
    "bunny fucker",
    "butt",
    "butthole",
    "buttmuch",
    "buttplug",
    "c0ck",
    "c0cksucker",
    "carpet muncher",
    "cawk",
    "chink",
    "cipa",
    "cl1t",
    "clit",
    "clitoris",
    "clits",
    "cnut",
    "cock",
    "cock-sucker",
    "cockface",
    "cockhead",
    "cockmunch",
    "cockmuncher",
    "cocks",
    "cocksuck",
    "cocksucked",
    "cocksucker",
    "cocksucking",
    "cocksucks",
    "cocksuka",
    "cocksukka",
    "cok",
    "cokmuncher",
    "coksucka",
    "coon",
    "cox",
    "crap",
    "cum",
    "cummer",
    "cumming",
    "cums",
    "cumshot",
    "cunilingus",
    "cunillingus",
    "cunnilingus",
    "cunt",
    "cuntlick",
    "cuntlicker",
    "cuntlicking",
    "cunts",
    "cyalis",
    "cyberfuc",
    "cyberfuck",
    "cyberfucked",
    "cyberfucker",
    "cyberfuckers",
    "cyberfucking",
    "d1ck",
    "damn",
    "dick",
    "dickhead",
    "dildo",
    "dildos",
    "dink",
    "dinks",
    "dirsa",
    "dlck",
    "dog-fucker",
    "doggin",
    "dogging",
    "donkeyribber",
    "doosh",
    "duche",
    "dyke",
    "ejaculate",
    "ejaculated",
    "ejaculates",
    "ejaculating",
    "ejaculatings",
    "ejaculation",
    "ejakulate",
    "f u c k",
    "f u c k e r",
    "f4nny",
    "fag",
    "fagging",
    "faggitt",
    "faggot",
    "faggs",
    "fagot",
    "fagots",
    "fags",
    "fanny",
    "fannyflaps",
    "fannyfucker",
    "fanyy",
    "fatass",
    "fcuk",
    "fcuker",
    "fcuking",
    "feck",
    "fecker",
    "felching",
    "fellate",
    "fellatio",
    "fingerfuck",
    "fingerfucked",
    "fingerfucker",
    "fingerfuckers",
    "fingerfucking",
    "fingerfucks",
    "fistfuck",
    "fistfucked",
    "fistfucker",
    "fistfuckers",
    "fistfucking",
    "fistfuckings",
    "fistfucks",
    "flange",
    "fook",
    "fooker",
    "fuck",
    "fucka",
    "fucked",
    "fucker",
    "fuckers",
    "fuckhead",
    "fuckheads",
    "fuckin",
    "fucking",
    "fuckings",
    "fuckingshitmotherfucker",
    "fuckme",
    "fucks",
    "fuckwhit",
    "fuckwit",
    "fudge packer",
    "fudgepacker",
    "fuk",
    "fuker",
    "fukker",
    "fukkin",
    "fuks",
    "fukwhit",
    "fukwit",
    "fux",
    "fux0r",
    "f_u_c_k",
    "gangbang",
    "gangbanged",
    "gangbangs",
    "gaylord",
    "gaysex",
    "goatse",
    "God",
    "god-dam",
    "god-damned",
    "goddamn",
    "goddamned",
    "hardcoresex",
    "hell",
    "heshe",
    "hoar",
    "hoare",
    "hoer",
    "homo",
    "hore",
    "horniest",
    "horny",
    "hotsex",
    "jack-off",
    "jackoff",
    "jap",
    "jerk-off",
    "jism",
    "jiz",
    "jizm",
    "jizz",
    "kawk",
    "knob",
    "knobead",
    "knobed",
    "knobend",
    "knobhead",
    "knobjocky",
    "knobjokey",
    "kock",
    "kondum",
    "kondums",
    "kum",
    "kummer",
    "kumming",
    "kums",
    "kunilingus",
    "l3i+ch",
    "l3itch",
    "labia",
    "lust",
    "lusting",
    "m0f0",
    "m0fo",
    "m45terbate",
    "ma5terb8",
    "ma5terbate",
    "masochist",
    "master-bate",
    "masterb8",
    "masterbat*",
    "masterbat3",
    "masterbate",
    "masterbation",
    "masterbations",
    "masturbate",
    "mo-fo",
    "mof0",
    "mofo",
    "mothafuck",
    "mothafucka",
    "mothafuckas",
    "mothafuckaz",
    "mothafucked",
    "mothafucker",
    "mothafuckers",
    "mothafuckin",
    "mothafucking",
    "mothafuckings",
    "mothafucks",
    "mother fucker",
    "motherfuck",
    "motherfucked",
    "motherfucker",
    "motherfuckers",
    "motherfuckin",
    "motherfucking",
    "motherfuckings",
    "motherfuckka",
    "motherfucks",
    "muff",
    "mutha",
    "muthafecker",
    "muthafuckker",
    "muther",
    "mutherfucker",
    "n1gga",
    "n1gger",
    "nazi",
    "nigg3r",
    "nigg4h",
    "nigga",
    "niggah",
    "niggas",
    "niggaz",
    "nigger",
    "niggers",
    "nob",
    "nob jokey",
    "nobhead",
    "nobjocky",
    "nobjokey",
    "numbnuts",
    "nutsack",
    "orgasim",
    "orgasims",
    "orgasm",
    "orgasms",
    "p0rn",
    "pawn",
    "pecker",
    "penis",
    "penisfucker",
    "phonesex",
    "phuck",
    "phuk",
    "phuked",
    "phuking",
    "phukked",
    "phukking",
    "phuks",
    "phuq",
    "pigfucker",
    "pimpis",
    "piss",
    "pissed",
    "pisser",
    "pissers",
    "pisses",
    "pissflaps",
    "pissin",
    "pissing",
    "pissoff",
    "poop",
    "porn",
    "porno",
    "pornography",
    "pornos",
    "prick",
    "pricks",
    "pron",
    "pube",
    "pusse",
    "pussi",
    "pussies",
    "pussy",
    "pussys",
    "rectum",
    "retard",
    "rimjaw",
    "rimming",
    "s hit",
    "s.o.b.",
    "sadist",
    "schlong",
    "screwing",
    "scroat",
    "scrote",
    "scrotum",
    "semen",
    "sex",
    "sh!+",
    "sh!t",
    "sh1t",
    "shag",
    "shagger",
    "shaggin",
    "shagging",
    "shemale",
    "shi+",
    "shit",
    "shitdick",
    "shite",
    "shited",
    "shitey",
    "shitfuck",
    "shitfull",
    "shithead",
    "shiting",
    "shitings",
    "shits",
    "shitted",
    "shitter",
    "shitters",
    "shitting",
    "shittings",
    "shitty",
    "skank",
    "slut",
    "sluts",
    "smegma",
    "smut",
    "snatch",
    "son-of-a-bitch",
    "spac",
    "spunk",
    "s_h_i_t",
    "t1tt1e5",
    "t1tties",
    "teets",
    "teez",
    "testical",
    "testicle",
    "tit",
    "titfuck",
    "tits",
    "titt",
    "tittie5",
    "tittiefucker",
    "titties",
    "tittyfuck",
    "tittywank",
    "titwank",
    "tosser",
    "turd",
    "tw4t",
    "twat",
    "twathead",
    "twatty",
    "twunt",
    "twunter",
    "v14gra",
    "v1gra",
    "vagina",
    "viagra",
    "vulva",
    "w00se",
    "wang",
    "wank",
    "wanker",
    "wanky",
    "whoar",
    "whore",
    "willies",
    "willy",
    "xrated",
    "xxx",
}
