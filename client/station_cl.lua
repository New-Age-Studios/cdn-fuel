if Config.PlayerOwnedGasStationsEnabled then -- This is so Player Owned Gas Stations are a Config Option, instead of forced. Set this option in shared/config.lua!
    -- Localize Natives
    local PlayerPedId = PlayerPedId
    local GetEntityCoords = GetEntityCoords
    local CreateObject = CreateObject
    local CreatePed = CreatePed
    local SetEntityHeading = SetEntityHeading
    local FreezeEntityPosition = FreezeEntityPosition
    local SetEntityInvincible = SetEntityInvincible
    local SetBlockingOfNonTemporaryEvents = SetBlockingOfNonTemporaryEvents
    local DeleteEntity = DeleteEntity
    local DoesEntityExist = DoesEntityExist
    local GetVehiclePedIsIn = GetVehiclePedIsIn
    local SetNewWaypoint = SetNewWaypoint
    local IsPedInAnyVehicle = IsPedInAnyVehicle
    local TaskLeaveVehicle = TaskLeaveVehicle
    local Wait = Wait

    -- Variables
    local QBCore = exports[Config.Core]:GetCoreObject()
    local PedsSpawned = false

    -- These are for fuel pickup:
    local CreatedEventHandler = false
    local locationSwapHandler
    local spawnedTankerTrailer
    local spawnedDeliveryTruck
    local ReservePickupData = {}
    local MissionStarted = false
    local holdingHose = false
    local hoseNozzle = nil
    local hoseRope = nil
    local StationProps = {}
    local returningHose = false -- True after unloading, while player must return the hose
    local tankerLoaded = false  -- True after player fills the tanker at the depot
    local depotLoadProp = nil   -- The fuel pump prop at the depot
    local depotNozzle = nil     -- The nozzle used to fill the tanker
    local depotRope = nil       -- The rope between depot pump and nozzle
    local depotLoadBlip = nil   -- The blip for the depot loading pump

    local StartMissionLoop -- Forward declaration
    local CurrentStockLevel = 0
    local CurrentMaxCapacity = Config.MaxFuelReserves

    -- Functions
    local function AddTargetEntity(entity, data)
        if Config.TargetResource == 'ox_target' then
            local options = {}
            for _, v in ipairs(data.options) do
                table.insert(options, {
                    name = v.label,
                    icon = v.icon,
                    label = v.label,
                    canInteract = v.canInteract,
                    distance = data.distance or 2.0,
                    onSelect = function(optionData)
                        if v.action then v.action() end
                        if v.event then TriggerEvent(v.event, v.data) end
                    end
                })
            end
            exports.ox_target:addLocalEntity(entity, options)
        else
            exports['qb-target']:AddTargetEntity(entity, data)
        end
    end

    -- Functions
    local function RequestAndLoadModel(model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(5)
        end
    end

    local function UpdateStationInfo(info)
        if Config.FuelDebug then print("Fetching Information for Location #" ..CurrentLocation) end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:fetchinfo', function(result)
            if result then
                for _, v in pairs(result) do
                    -- Reserves --
                    if info == "all" or info == "reserves" then
                        if Config.FuelDebug then print("Fetched Reserve Levels: "..v.fuel.." Liters!") end
                        Currentreserveamount = v.fuel
                        ReserveLevels = Currentreserveamount or 0
                        if Currentreserveamount < Config.MaxFuelReserves then
                            ReservesNotBuyable = false
                        else
                            ReservesNotBuyable = true
                        end
                        if Config.UnlimitedFuel then ReservesNotBuyable = true if Config.FuelDebug then print("Reserves are not buyable, because Config.UnlimitedFuel is set to true.") end end
                    end
                    -- Fuel Price --
                    if info == "all" or info == "fuelprice" then
                        StationFuelPrice = v.fuelprice
                    end
                    -- Fuel Station's Balance --
                    if info == "all" or info == "balance" then
                        StationBalance = v.balance
                        if Config.FuelDebug then print("Successfully Fetched: Balance") end
                    end
                    -- Stock Level --
                    if info == "all" or info == "stock_level" then
                        CurrentStockLevel = v.stock_level or 0
                        CurrentMaxCapacity = Config.StationUpgrades[CurrentStockLevel] and Config.StationUpgrades[CurrentStockLevel].capacity or Config.MaxFuelReserves
                        if Config.FuelDebug then print("Stock Level: "..CurrentStockLevel.." | Max Capacity: "..CurrentMaxCapacity) end
                    end
                    -- Loyalty Level --
                    if info == "all" or info == "loyalty_level" then
                        CurrentLoyaltyLevel = v.loyalty_level or 0
                        CurrentReservePrice = Config.LoyaltyUpgrades[CurrentLoyaltyLevel] and Config.LoyaltyUpgrades[CurrentLoyaltyLevel].fuelPrice or Config.FuelReservesPrice or 3.0
                        if Config.FuelDebug then print("Loyalty Level: "..CurrentLoyaltyLevel.." | Reserve Price: "..CurrentReservePrice) end
                    end
                    ----------------
                end
            end
        end, CurrentLocation)
    end exports(UpdateStationInfo, UpdateStationInfo)

    -- Optimization: Distance-based spawning
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local sleep = 1500

            for i, current in pairs(Config.GasStations) do
                if current and current.pedcoords then
                    local dist = #(coords - vector3(current.pedcoords.x, current.pedcoords.y, current.pedcoords.z))
                    
                    if dist < 150.0 then
                        sleep = 500
                        if not StationProps[i] then
                            StationProps[i] = { pumps = {} }
                            
                            -- Spawn Ped
                            local model = type(current.pedmodel) == 'string' and joaat(current.pedmodel) or current.pedmodel or joaat('a_m_m_indian_01')
                            RequestAndLoadModel(model)
                            local stationPed = CreatePed(0, model, current.pedcoords.x, current.pedcoords.y, current.pedcoords.z, current.pedcoords.w, false, false)
                            FreezeEntityPosition(stationPed, true)
                            SetEntityInvincible(stationPed, true)
                            SetBlockingOfNonTemporaryEvents(stationPed, true)
                            StationProps[i].ped = stationPed
                            
                            AddTargetEntity(stationPed, {
                                options = {{
                                    type = "client",
                                    label = Lang:t("station_talk_to_ped"),
                                    icon = "fas fa-building",
                                    action = function() TriggerEvent('cdn-fuel:stations:openmenu', i) end,
                                    canInteract = function() return not MissionStarted end
                                }},
                                distance = 2.0
                            })

                            -- Spawn Unloading Prop
                            local unloadCoords = current.unloadcoords or (Config.StationUnloadCoords and Config.StationUnloadCoords[i]) or (current.pedcoords)
                            if unloadCoords then
                                local propModel = joaat(Config.UnloadPropModel or 'prop_indus_pumps_01')
                                RequestAndLoadModel(propModel)
                                local prop = CreateObject(propModel, unloadCoords.x, unloadCoords.y, unloadCoords.z, false, false, false)
                                SetEntityHeading(prop, unloadCoords.w or 0.0)
                                PlaceObjectOnGroundProperly(prop)
                                FreezeEntityPosition(prop, true)
                                StationProps[i].unloadProp = prop
                                
                                AddTargetEntity(prop, {
                                    options = {{
                                        type = "client",
                                        label = Lang:t("connect_hose_station"),
                                        icon = "fas fa-fill-drip",
                                        action = function() TriggerEvent('cdn-fuel:station:client:connectHoseToStation', i) end,
                                        canInteract = function() return MissionStarted and holdingHose and i == ReservePickupData.location end
                                    }},
                                    distance = 2.5
                                })
                            end

                            -- Spawn electric charger
                            if current.electricchargercoords then
                                local chargerModel = GetHashKey(Config.ElectricChargerModel)
                                RequestAndLoadModel(chargerModel)
                                local charger = CreateObject(chargerModel, current.electricchargercoords.x, current.electricchargercoords.y, current.electricchargercoords.z, false, false, false)
                                SetEntityHeading(charger, current.electricchargercoords.w)
                                FreezeEntityPosition(charger, true)
                                StationProps[i].charger = charger
                            end

                            -- Spawn fuel pumps
                            if current.fuelpumpcoords and #current.fuelpumpcoords > 0 and (current.type ~= 'air' and current.type ~= 'water') then
                                local pumpModel = GetHashKey('prop_gas_pump_1d')
                                RequestAndLoadModel(pumpModel)
                                for _, pumpCoord in ipairs(current.fuelpumpcoords) do
                                    local pump = CreateObject(pumpModel, pumpCoord.x, pumpCoord.y, pumpCoord.z, false, false, false)
                                    SetEntityHeading(pump, pumpCoord.w)
                                    FreezeEntityPosition(pump, true)
                                    table.insert(StationProps[i].pumps, pump)
                                end
                            end
                        end
                    else
                        -- Out of range, delete peds/props
                        if StationProps[i] then
                            if StationProps[i].ped then DeleteEntity(StationProps[i].ped) end
                            if StationProps[i].unloadProp then DeleteEntity(StationProps[i].unloadProp) end
                            if StationProps[i].charger then DeleteEntity(StationProps[i].charger) end
                            if StationProps[i].pumps then
                                for _, p in ipairs(StationProps[i].pumps) do DeleteEntity(p) end
                            end
                            StationProps[i] = nil
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)

    local function GenerateRandomTruckModel()
        local possibleTrucks = Config.PossibleDeliveryTrucks
        if possibleTrucks then
            return possibleTrucks[math.random(#possibleTrucks)]
        end
    end

    local function SpawnPickupVehicles(amount)
        local isSmallDelivery = (amount and amount <= (Config.SmallDeliveryThreshold or 500))
        local trailer = GetHashKey('tanker')
        local truckToSpawn = GetHashKey(isSmallDelivery and (Config.SmallDeliveryTruck or "tanker2") or GenerateRandomTruckModel())
        
        if truckToSpawn then
            RequestAndLoadModel(truckToSpawn)
            spawnedDeliveryTruck = CreateVehicle(truckToSpawn, Config.DeliveryTruckSpawns['truck'], true, false)
            SetModelAsNoLongerNeeded(truckToSpawn)
            SetEntityAsMissionEntity(spawnedDeliveryTruck, 1, 1)

            if not isSmallDelivery then
                RequestAndLoadModel(trailer)
                spawnedTankerTrailer = CreateVehicle(trailer, Config.DeliveryTruckSpawns['trailer'], true, false)
                SetModelAsNoLongerNeeded(trailer)
                SetEntityAsMissionEntity(spawnedTankerTrailer, 1, 1)
                AttachVehicleToTrailer(spawnedDeliveryTruck, spawnedTankerTrailer, 15.0)
            else
                spawnedTankerTrailer = nil
            end

            if spawnedDeliveryTruck ~= 0 then
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(spawnedDeliveryTruck))
                
                -- Set mission state
                tankerLoaded = false
                local loadCoords = Config.DeliveryTruckSpawns['tankerLoadProp']
                if loadCoords then
                    -- Add GPS blip pointing to the existing depot pump
                    if depotLoadBlip then RemoveBlip(depotLoadBlip) end
                    depotLoadBlip = AddBlipForCoord(loadCoords.x, loadCoords.y, loadCoords.z)
                    SetBlipSprite(depotLoadBlip, 354) -- fuel pump icon
                    SetBlipColour(depotLoadBlip, 5)   -- yellow
                    SetBlipScale(depotLoadBlip, 0.8)
                    SetBlipRoute(depotLoadBlip, true)
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString("Carregar Tanque")
                    EndTextCommandSetBlipName(depotLoadBlip)

                    QBCore.Functions.Notify(isSmallDelivery and "Encha o tanque do caminhão antes de partir!" or "Primeiro encha o tanque do reboque antes de partir!", "primary")
                    SetNewWaypoint(loadCoords.x, loadCoords.y)
                end
                
                return true
            else
                return false
            end
        end
    end

    local function RemoveHose()
        if hoseNozzle then
            DeleteObject(hoseNozzle)
            hoseNozzle = nil
        end
        if hoseRope then
            RopeUnloadTextures()
            DeleteRope(hoseRope)
            hoseRope = nil
        end
        holdingHose = false
    end

    AddEventHandler('cdn-fuel:station:client:grabDepotNozzle', function()
        if tankerLoaded or depotNozzle ~= nil then return end
        local ped = PlayerPedId()

        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
        Wait(300)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)

        depotNozzle = CreateObject(joaat('prop_cs_fuel_nozle'), 1.0, 1.0, 1.0, true, true, false)
        local lefthand = GetPedBoneIndex(ped, 18905)
        AttachEntityToEntity(depotNozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)

        -- Create rope from depot pump to nozzle
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
            RopeLoadTextures()
        end

        local propCoords = GetEntityCoords(depotLoadProp)
        local nozzlePos = GetOffsetFromEntityInWorldCoords(depotNozzle, 0.0, -0.033, -0.195)
        depotRope = AddRope(propCoords.x, propCoords.y, propCoords.z, 0.0, 0.0, 0.0, 3.0, Config.RopeType and Config.RopeType['fuel'] or 4, 10.0, 0.0, 1.0, false, false, false, 1.0, true)
        while not depotRope do Wait(0) end
        ActivatePhysics(depotRope)
        Wait(100)
        AttachEntitiesToRope(depotRope, depotLoadProp, depotNozzle, propCoords.x, propCoords.y, propCoords.z + 2.1, nozzlePos.x, nozzlePos.y, nozzlePos.z, 10.0, false, false, nil, nil)

        QBCore.Functions.Notify(spawnedTankerTrailer and "Leve o bico até o reboque para encher o tanque!" or "Leve o bico até o caminhão para encher o tanque!", "primary")
        
        -- Target on either truck or trailer
        local targetEntity = spawnedTankerTrailer or spawnedDeliveryTruck
        AddTargetEntity(targetEntity, {
            options = {
                {
                    type = "client",
                    label = "Conectar e Encher o Tanque",
                    icon = "fas fa-fill-drip",
                    action = function()
                        TriggerEvent('cdn-fuel:station:client:loadTankerWithHose')
                    end,
                    canInteract = function()
                        return not tankerLoaded and depotNozzle ~= nil
                    end
                },
            },
            distance = 3.0
        })
    end)

    AddEventHandler('cdn-fuel:station:client:loadTankerWithHose', function()
        if isProcessing or tankerLoaded or depotNozzle == nil then return end
        isProcessing = true
        local ped = PlayerPedId()
        local targetEntity = spawnedTankerTrailer or spawnedDeliveryTruck

        -- Attach nozzle to target visually
        DetachEntity(depotNozzle, true, false)
        if spawnedTankerTrailer then
            AttachEntityToEntity(depotNozzle, spawnedTankerTrailer, 0, 0.0, 2.0, 1.5, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        else
            -- For rigid truck, attach to back area
            AttachEntityToEntity(depotNozzle, spawnedDeliveryTruck, 0, 0.0, -3.0, 1.2, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end

        -- Start Sound
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "refuel", 0.3)

        local success = false
        if Config.Ox.Progress then
            success = lib.progressBar({
                duration = Config.TankerLoadDuration or 20000,
                label = "Enchendo tanque...",
                useWhileDead = false,
                canCancel = true,
                disable = { car = true, move = true },
                anim = { dict = "timetable@gardener@filling_can", clip = "gar_ig_5_filling_can" }
            })
        else
            local p = promise.new()
            QBCore.Functions.Progressbar("load_tanker", "Enchendo tanque...", Config.TankerLoadDuration or 20000, false, true, {
                disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true
            }, { animDict = "timetable@gardener@filling_can", anim = "gar_ig_5_filling_can", flags = 16 }, {}, {}, function()
                p:resolve(true)
            end, function()
                p:resolve(false)
            end)
            success = Citizen.Await(p)
        end
        
        isProcessing = false
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "refuel", 0.0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)

        if success then
            tankerLoaded = true
            
            -- Play grab animation back
            LoadAnimDict("anim@am_hold_up@male")
            TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
            Wait(300)
            StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)

            -- Put nozzle back in player's hand
            local ped = PlayerPedId() -- Refresh ped handle
            DetachEntity(depotNozzle, true, true)
            local lefthand = GetPedBoneIndex(ped, 18905)
            AttachEntityToEntity(depotNozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)
            
            QBCore.Functions.Notify("Tanque cheio! Agora devolva o bico à bomba.", "success")
        else
            -- Cancelled - put nozzle back in hand
            DetachEntity(depotNozzle, true, false)
            local lefthand = GetPedBoneIndex(ped, 18905)
            AttachEntityToEntity(depotNozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)
            QBCore.Functions.Notify("Abastecimento cancelado.", "error")
        end
    end)

    RegisterNetEvent('cdn-fuel:station:client:returnDepotNozzle', function()
        if not tankerLoaded or depotNozzle == nil then return end
        local ped = PlayerPedId()

        -- Play return animation
        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
        Wait(300)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)

        -- Cleanup
        DetachEntity(depotNozzle, true, false)
        DeleteObject(depotNozzle)
        depotNozzle = nil
        if depotRope then RopeUnloadTextures() DeleteRope(depotRope) depotRope = nil end
        if depotLoadBlip then RemoveBlip(depotLoadBlip) depotLoadBlip = nil end

        QBCore.Functions.Notify("Bico guardado. Agora entregue o combustível no posto.", "success")

        -- Now show GPS to station
        local station = Config.GasStations[ReservePickupData.location]
        if station and station.pedcoords then
            SetNewWaypoint(station.pedcoords.x, station.pedcoords.y)
            SetUseWaypointAsDestination(true)
        end
        StartMissionLoop()
    end)

    RegisterNetEvent('cdn-fuel:station:client:grabHoseFromTrailer', function()
        local ped = PlayerPedId()
        if holdingHose then return end
        
        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
        Wait(300)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)
        
        hoseNozzle = CreateObject(joaat('prop_cs_fuel_nozle'), 1.0, 1.0, 1.0, true, true, false)
        local lefthand = GetPedBoneIndex(ped, 18905)
        AttachEntityToEntity(hoseNozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)
        
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
            RopeLoadTextures()
        end
        
        local hoseSource = spawnedTankerTrailer or spawnedDeliveryTruck
        local sourceCoords = GetEntityCoords(hoseSource)
        local nozzlePos = GetOffsetFromEntityInWorldCoords(hoseNozzle, 0.0, -0.033, -0.195)
        
        -- Create Rope - same pattern as fuel_cl.lua car fueling
        hoseRope = AddRope(sourceCoords.x, sourceCoords.y, sourceCoords.z, 0.0, 0.0, 0.0, 3.0, Config.RopeType and Config.RopeType['fuel'] or 4, 15.0, 0.0, 1.0, false, false, false, 1.0, true)
        while not hoseRope do Wait(0) end
        ActivatePhysics(hoseRope)
        Wait(100)
        
        -- Convert source local attachment point to world coords
        local attachPoint = GetOffsetFromEntityInWorldCoords(hoseSource, 0.0, spawnedTankerTrailer and -2.0 or -3.0, 1.0)
        AttachEntitiesToRope(hoseRope, hoseSource, hoseNozzle, attachPoint.x, attachPoint.y, attachPoint.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, 15.0, false, false, nil, nil)
        
        holdingHose = true
        QBCore.Functions.Notify(spawnedTankerTrailer and "Mangueira conectada ao reboque. Leve-a até o ponto de descarregamento." or "Mangueira conectada ao caminhão. Leve-a até o ponto de descarregamento.", "primary")
    end)

    AddEventHandler('cdn-fuel:station:client:grabHoseBack', function()
        if not returningHose or not hoseNozzle then return end
        local ped = PlayerPedId()

        -- Play grab animation
        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
        Wait(300)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)

        -- Detach from prop and reattach to player's hand (NO rope on return trip - trailer is far away)
        local lefthand = GetPedBoneIndex(ped, 18905)
        DetachEntity(hoseNozzle, true, false)
        AttachEntityToEntity(hoseNozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)

        local hoseSource = spawnedTankerTrailer or spawnedDeliveryTruck
        QBCore.Functions.Notify(spawnedTankerTrailer and "Mangueira recolhida. Retorne ao reboque para devolvê-la." or "Mangueira recolhida. Retorne ao caminhão para devolvê-la.", "primary")
        local sourceCoords = GetEntityCoords(hoseSource)
        SetNewWaypoint(sourceCoords.x, sourceCoords.y)
        
        -- Add Target to the SOURCE to return the hose
        AddTargetEntity(hoseSource, {
            options = {
                {
                    type = "client",
                    label = spawnedTankerTrailer and "Devolver Mangueira ao Reboque" or "Devolver Mangueira ao Caminhão",
                    icon = "fas fa-rotate-left",
                    action = function()
                        TriggerEvent('cdn-fuel:station:client:returnHoseToTrailer')
                    end,
                    canInteract = function()
                        return returningHose
                    end
                },
            },
            distance = 3.0
        })
    end)


    AddEventHandler('cdn-fuel:station:client:returnHoseToTrailer', function()
        if not returningHose then return end
        local ped = PlayerPedId()

        -- Play put-back animation
        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        Wait(500)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)

        returningHose = false
        RemoveHose()
        fuelUnloaded = true -- Signal main loop that delivery is done
        if Config.FuelDebug then print("[CDN-FUEL] Fuel unloaded and hose returned. Ready to return truck.") end
        SetNewWaypoint(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y)
        QBCore.Functions.Notify("Mangueira devolvida! Retorne o caminhão ao depósito.", "success")
    end)


    RegisterNetEvent('cdn-fuel:station:client:connectHoseToStation', function(stationId)
        if isProcessing or not holdingHose then return end
        isProcessing = true
        
        local ped = PlayerPedId()
        local stationData = StationProps[stationId]
        local targetProp = stationData and stationData.unloadProp
        
        print("[CDN-FUEL] Debug: targetProp encontrado? " .. tostring(targetProp ~= nil))
        if not targetProp or not DoesEntityExist(targetProp) then 
            print("[CDN-FUEL] Erro: Objeto do bocal não encontrado para o posto " .. stationId)
            return 
        end

        TaskTurnPedToFaceEntity(ped, targetProp, 1000)
        Wait(1000)
        
        -- Start Sound
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "refuel", 0.3)

        -- Attach Nozzle to Prop
        DetachEntity(hoseNozzle, true, true)
        AttachEntityToEntity(hoseNozzle, targetProp, 0, 0.0, 0.0, 1.1, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        
        local success = false
        if Config.Ox.Progress then
            success = lib.progressBar({
                duration = 15000,
                label = Lang:t("unloading_fuel"),
                useWhileDead = false,
                canCancel = true,
                disable = { car = true, move = true },
                anim = { dict = "anim@amb@business@weed@weed_inspecting_lo_med_hi@", clip = "weed_stand_check_v2_inspect_v2" }
            })
        else
            local p = promise.new()
            QBCore.Functions.Progressbar("unloading_fuel", Lang:t("unloading_fuel"), 15000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = "anim@amb@business@weed@weed_inspecting_lo_med_hi@",
                anim = "weed_stand_check_v2_inspect_v2",
                flags = 16,
            }, {}, {}, function()
                p:resolve(true)
            end, function()
                p:resolve(false)
            end)
            success = Citizen.Await(p)
        end

        isProcessing = false
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "refuel", 0.0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)

        if success then
            TriggerServerEvent('cdn-fuel:station:server:fuelpickup:unload', ReservePickupData.location)
            QBCore.Functions.Notify(Lang:t("fuel_unload_success"), "success")
            fuelUnloaded = true
            holdingHose = false
            returningHose = true

            -- Nozzle stays plugged into the prop, rope stays stretched from trailer to prop
            -- Rope is only removed when the player returns it to the trailer (RemoveHose)
            
            -- Add Target on the prop: 'Pegar Mangueira de Volta'
            local stationPropData = StationProps[ReservePickupData.location]
            local stationProp = stationPropData and stationPropData.unloadProp
            if stationProp then
                AddTargetEntity(stationProp, {
                    options = {
                        {
                            type = "client",
                            label = "Pegar Mangueira de Volta",
                            icon = "fas fa-hand-holding-hand",
                            action = function()
                                TriggerEvent('cdn-fuel:station:client:grabHoseBack')
                            end,
                            canInteract = function()
                                return returningHose
                            end
                        },
                    },
                    distance = 2.5
                })
            end

        end
    end)
    RegisterNetEvent('cdn-fuel:stations:updatelocation', function(updatedlocation)
        if Config.FuelDebug then if CurrentLocation == nil then CurrentLocation = 0 end
            if updatedlocation == nil then updatedlocation = 0 end
            print('Location: '..CurrentLocation..' has been replaced with a new location: ' ..updatedlocation)
        end
        CurrentLocation = updatedlocation or 0
    end)

    RegisterNetEvent('cdn-fuel:stations:client:buyreserves', function(data)
        local location = data.location
        local price = data.price
        local amount = data.amount
        TriggerServerEvent('cdn-fuel:stations:server:buyreserves', location, price, amount)
        if Config.FuelDebug then print("^5Attempting Purchase of ^2"..amount.. "^5 Fuel Reserves for location #"..location.."! Purchase Price: ^2"..price) end
    end)

    RegisterNetEvent('cdn-fuel:station:client:updateNUI', function(data)
        if data.balance then StationBalance = data.balance end
        if data.fuelStock then Currentreserveamount = data.fuelStock end
        if data.fuelPrice then StationFuelPrice = data.fuelPrice end
        if data.reservePrice then CurrentReservePrice = data.reservePrice end
        if data.loyaltyLevel then CurrentLoyaltyLevel = data.loyaltyLevel end
        if data.stockLevel then CurrentStockLevel = data.stockLevel end

        SendNUIMessage({
            action = "updateData",
            data = data
        })
    end)

    RegisterNetEvent('cdn-fuel:station:client:initiatefuelpickup', function(amountBought, finalReserveAmountAfterPurchase, location)
        local status = lib.callback('md-refuelcdn:server:status', false)
        if not status then return QBCore.Functions.Notify('Trabalho indisponível!', 'error') end
        if amountBought and finalReserveAmountAfterPurchase and location then
            MissionStarted = false
            fuelUnloaded = false
            tankerLoaded = false
            returningHose = false
            holdingHose = false
            isProcessing = false
            ReservePickupData = nil
            ReservePickupData = {
                finalAmount = finalReserveAmountAfterPurchase,
                amountBought = amountBought,
                location = location,
            }

            if SpawnPickupVehicles(amountBought) then
                QBCore.Functions.Notify(Lang:t("fuel_order_ready"), 'success')
                SetNewWaypoint(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y)
                SetUseWaypointAsDestination(true)
                ReservePickupData.blip = CreateBlip(vector3(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y, Config.DeliveryTruckSpawns['truck'].z), "Truck Pickup")
                SetBlipColour(ReservePickupData.blip, 5)


                -- Add Target to Trailer or Truck
                local hoseSource = spawnedTankerTrailer or spawnedDeliveryTruck
                AddTargetEntity(hoseSource, {
                    options = {
                        {
                            type = "client",
                            label = Lang:t("grab_hose_trailer"),
                            icon = "fas fa-gas-pump",
                            action = function()
                                TriggerEvent('cdn-fuel:station:client:grabHoseFromTrailer')
                            end,
                            canInteract = function()
                                return MissionStarted and not fuelUnloaded and not holdingHose and inGasStation and CurrentLocation == ReservePickupData.location
                            end
                        },
                    },
                    distance = 4.0
                })

                -- Create Zone
                ReservePickupData.PolyZone = PolyZone:Create(Config.DeliveryTruckSpawns.PolyZone.coords, {
                    name = "cdn_fuel_zone_delivery_truck_pickup",
                    minZ = Config.DeliveryTruckSpawns.PolyZone.minz,
                    maxZ = Config.DeliveryTruckSpawns.PolyZone.maxz,
                    debugPoly = Config.PolyDebug
                })

                -- Setup onPlayerInOut Events for zone that is created.
                ReservePickupData.PolyZone:onPlayerInOut(function(isPointInside)
                    if isPointInside then
                        if Config.FuelDebug then
                            print("Player has arrived at the pickup location!")
                        end
                        if ReservePickupData and ReservePickupData.blip then
                            RemoveBlip(ReservePickupData.blip)
                            ReservePickupData.blip = nil
                        end
                        -- Only start mission after the tanker is loaded at the depot
                        if not tankerLoaded then 
                            if Config.FuelDebug then print("[CDN-FUEL] Player in depot zone but tanker not loaded yet.") end
                            return 
                        end
                        StartMissionLoop()
                    end
                end)

                -- Check if player is already inside the zone
                if ReservePickupData.PolyZone:isPointInside(GetEntityCoords(PlayerPedId())) then
                    if ReservePickupData.blip then
                        RemoveBlip(ReservePickupData.blip)
                        ReservePickupData.blip = nil
                    end
                end
            else
                -- This is just a worst case scenario event, if the vehicles somehow do not spawn.
                TriggerServerEvent('cdn-fuel:station:server:fuelpickup:failed', location)
            end
        else
            if Config.FuelDebug then
                print("An error has occurred. The amountBought / finalReserveAmountAfterPurchase / location is nil: `cdn-fuel:station:client:initiatefuelpickup`")
            end
        end
    end)

    StartMissionLoop = function()
        if MissionStarted then return end
        if Config.FuelDebug then print("[CDN-FUEL] Starting Mission Loop Thread...") end
        MissionStarted = true
        CreateThread(function()
            local ped = PlayerPedId()
            local alreadyHasTruck = false
            local VehicleDelivered = false
            local showingReturnText = false
            while true do
                local sleep = 500
                if VehicleDelivered then break end
                
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if vehicle == spawnedDeliveryTruck then
                    sleep = 100
                    if not alreadyHasTruck then
                        if not fuelUnloaded then
                            local station = Config.GasStations[ReservePickupData.location]
                            if station and station.pedcoords then
                                SetNewWaypoint(station.pedcoords.x, station.pedcoords.y)
                                SetUseWaypointAsDestination(true)
                            end
                        end
                        alreadyHasTruck = true
                    end
                end

                if fuelUnloaded then
                    local truckCoords = GetEntityCoords(spawnedDeliveryTruck)
                    local returnCoords = vector3(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y, Config.DeliveryTruckSpawns['truck'].z)
                    local dist = #(truckCoords - returnCoords)
                    
                    if dist < 50.0 then
                        sleep = 0
                        if dist < 20.0 then
                            if not showingReturnText then
                                if Config.Ox.DrawText then
                                    lib.showTextUI(Lang:t("draw_text_fuel_return"), { position = 'right-center' })
                                else
                                    exports[Config.Core]:DrawText(Lang:t("draw_text_fuel_return"), 'left')
                                end
                                showingReturnText = true
                            end
                            if IsControlJustReleased(2, 38) then
                                VehicleDelivered = true
                                -- Handle Vehicle Return
                                if ReservePickupData and ReservePickupData.PolyZone then
                                    ReservePickupData.PolyZone:destroy()
                                    ReservePickupData.PolyZone = nil
                                end
                                
                                if IsPedInAnyVehicle(ped, true) and GetVehiclePedIsIn(ped, false) == spawnedDeliveryTruck then
                                    TaskLeaveVehicle(ped, spawnedDeliveryTruck, 1)
                                    Wait(2000)
                                end

                                if Config.Ox.DrawText then lib.hideTextUI() else exports[Config.Core]:HideText() end

                                if DoesEntityExist(spawnedDeliveryTruck) then DeleteEntity(spawnedDeliveryTruck) end
                                if DoesEntityExist(spawnedTankerTrailer) then DeleteEntity(spawnedTankerTrailer) end
                                RemoveHose()
                                TriggerServerEvent('cdn-fuel:station:server:fuelpickup:finished', ReservePickupData.location, ReservePickupData.amountBought)
                                
                                if ReservePickupData and ReservePickupData.blip then
                                    RemoveBlip(ReservePickupData.blip)
                                    ReservePickupData.blip = nil
                                end
                                if depotLoadBlip then RemoveBlip(depotLoadBlip) depotLoadBlip = nil end
                                MissionStarted = false
                                fuelUnloaded = false
                                tankerLoaded = false
                                returningHose = false
                                holdingHose = false
                                ReservePickupData = nil
                                ReservePickupData = {}
                                break
                            end
                        end
                    else
                        sleep = 500
                        if showingReturnText then
                            if Config.Ox.DrawText then lib.hideTextUI() else exports[Config.Core]:HideText() end
                            showingReturnText = false
                        end
                    end
                end
                Wait(sleep)
            end
        end)
    end

    RegisterNetEvent('cdn-fuel:stations:client:purchaselocation', function(data)
        local location = data.location
        local CitizenID = QBCore.Functions.GetPlayerData().citizenid
        CanOpen = false
        Wait(5)
        QBCore.Functions.TriggerCallback('cdn-fuel:server:locationpurchased', function(result)
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned!") end
                IsOwned = true
            else
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned.") end
                IsOwned = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)

        if not IsOwned then
            TriggerServerEvent('cdn-fuel:server:buyStation', location, CitizenID)
        elseif IsOwned then
            QBCore.Functions.Notify(Lang:t("station_already_owned"), 'error', 7500)
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:sellstation', function(data)
        local location = data.location
        local SalePrice = data.SalePrice
        local CitizenID = QBCore.Functions.GetPlayerData().citizenid
        CanSell = false
        Wait(5)
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            if result then
                if Config.FuelDebug then print("The Location: "..location.." is owned by ID: "..CitizenID) end
                CanSell = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..location.." is not owned by ID: "..CitizenID) end
                CanSell = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanSell then
            if Config.FuelDebug then print("Attempting to sell for: $"..SalePrice) end
            TriggerServerEvent('cdn-fuel:stations:server:sellstation', location)
            if Config.FuelDebug then print("Event Triggered") end
        else
            QBCore.Functions.Notify(Lang:t("station_cannot_sell"), 'error', 7500)
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasereserves:final', function(location, price, amount) -- Menu, seens after selecting the "purchase reserves" option.
        local location = location
        local price = price
        local amount = amount
        CanOpen = false
        Wait(5)
        if Config.FuelDebug then print("checking ownership of "..location) end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..location.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..location.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then print("Price: "..price.."<br> Amount: "..amount.." <br> Location: "..location) end
            if Config.Ox.Menu then
                lib.registerContext({
                    id = 'purchasereservesmenu',
                    title = Lang:t("menu_station_reserves_header")..Config.GasStations[location].label,
                    options = {
                        {
                            title = Lang:t("menu_station_reserves_purchase_header")..price,
                            description = Lang:t("menu_station_reserves_purchase_footer")..price.."!",
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:buyreserves',
                            args = {
                                location = location,
                                price = price,
                                amount = amount,
                            }
                        },
                        {
                            title = Lang:t("menu_header_close"),
                            description = Lang:t("menu_ped_close_footer"),
                            icon = "fas fa-times-circle",
                            arrow = false, -- puts arrow to the right
                            onSelect = function()
                                lib.hideContext()
                            end,
                        },
                    },
                })
                lib.showContext('purchasereservesmenu')
            else
                exports['qb-menu']:openMenu({
                    {
                        header = Lang:t("menu_station_reserves_header")..Config.GasStations[location].label,
                        isMenuHeader = true,
                        icon = "fas fa-gas-pump",
                    },
                    {
                        header = Lang:t("menu_station_reserves_purchase_header")..price,
                        txt = Lang:t("menu_station_reserves_purchase_footer")..price.."!",
                        icon = "fas fa-usd",
                        params = {
                            event = "cdn-fuel:stations:client:buyreserves",
                            args = {
                                location = location,
                                price = price,
                                amount = amount,
                            },
                        },
                    },
                    {
                        header = Lang:t("menu_header_close"),
                        txt = Lang:t("menu_station_reserves_cancel_footer"),
                        icon = "fas fa-times-circle",
                        params = {
                            event = "qb-menu:closeMenu",
                        }
                    },
                })
            end
        else
            if Config.FuelDebug then print("Not showing menu, as the player doesn't have proper permissions.") end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasereserves', function(data)
        local CanOpen = false
        local location = data.location
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            local bankmoney = QBCore.Functions.GetPlayerData().money['bank']
            if Config.FuelDebug then print("Showing Input for Reserves!") end
            if Config.Ox.Input then
                local reserves = lib.inputDialog('Reservas de compra', {
					{ type = "input", label = 'Preço atual',
					default = 'R$'.. Config.FuelReservesPrice .. ' por Litro',
					disabled = true },
					{ type = "input", label = 'Reservas atuais',
					default = Currentreserveamount,
					disabled = true },
					{ type = "input", label = 'Reservas necessárias',
					default = Config.MaxFuelReserves - Currentreserveamount,
					disabled = true },
					{ type = "slider", label = 'Custo total da reserva: R$' ..math.ceil(GlobalTax((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice) + ((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice)).. '',
					default = Config.MaxFuelReserves - Currentreserveamount,
					min = 0,
					max = Config.MaxFuelReserves - Currentreserveamount
					},
				})
				if not reserves then return end
				reservesAmount = tonumber(reserves[4])
                if reserves then
                    if Config.FuelDebug then print("Attempting to buy reserves!") end
                    Wait(100)
                    local amount = reservesAmount
                    if not reservesAmount then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    Reservebuyamount = tonumber(reservesAmount)
                    if Reservebuyamount < 1 then QBCore.Functions.Notify(Lang:t("station_more_than_one"), 'error', 7500) return end
                    if (Reservebuyamount + Currentreserveamount) > Config.MaxFuelReserves then
                        QBCore.Functions.Notify(Lang:t("station_reserve_cannot_fit"), "error")
                    else
                        if math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice)) <= bankmoney then
                            local price = math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice))
                            if Config.FuelDebug then print("Price: "..price) end

                            TriggerEvent("cdn-fuel:stations:client:purchasereserves:final", location, price, amount)

                        else
                            QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank"), 'error', 7500)
                        end
                    end
                end
            else
                local reserves = exports['qb-input']:ShowInput({
                    header = Lang:t("input_purchase_reserves_header_1") .. Lang:t("input_purchase_reserves_header_2") .. Currentreserveamount .. Lang:t("input_purchase_reserves_header_3") ..
                    math.ceil(GlobalTax((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice) + ((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice)) .. "",
                    submitText = Lang:t("input_purchase_reserves_submit_text"),
                    inputs = { {
                        type = 'number',
                        isRequired = true,
                        name = 'amount',
                        text = Lang:t("input_purchase_reserves_text")
                    }}
                })
                if reserves then
                    if Config.FuelDebug then print("Attempting to buy reserves!") end
                    Wait(100)
                    local amount = reserves.amount
                    if not reserves.amount then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    Reservebuyamount = tonumber(reserves.amount)
                    if Reservebuyamount < 1 then QBCore.Functions.Notify(Lang:t("station_more_than_one"), 'error', 7500) return end
                    if (Reservebuyamount + Currentreserveamount) > Config.MaxFuelReserves then
                        QBCore.Functions.Notify(Lang:t("station_reserve_cannot_fit"), "error")
                    else
                        if math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice)) <= bankmoney then
                            local price = math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice))
                            if Config.FuelDebug then print("Price: "..price) end
                            TriggerEvent("cdn-fuel:stations:client:purchasereserves:final", location, price, amount)

                        else
                            QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank"), 'error', 7500)
                        end
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:changefuelprice', function(data)
        CanOpen = false
        local location = data.location
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then print("Showing Input for Fuel Price Change!") end
            if Config.Ox.Input then
                local fuelprice = lib.inputDialog('Fuel Prices', {
                    { type = "input", label = 'Current Price',
                    default = '$'.. Comma_Value(StationFuelPrice) .. ' Per Liter',
                    disabled = true },
                    { type = "number", label = 'Enter New Fuel Price Per Liter',
                    default = StationFuelPrice,
                    min = Config.MinimumFuelPrice,
                    max = Config.MaxFuelPrice
                    },
                })
                if not fuelprice then return end
                fuelPrice = tonumber(fuelprice[2])
                if fuelprice then
                    if Config.FuelDebug then print("Attempting to change fuel price!") end
                    Wait(100)
                    if not fuelPrice then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    NewFuelPrice = tonumber(fuelPrice)
                    if NewFuelPrice < Config.MinimumFuelPrice then QBCore.Functions.Notify(Lang:t("station_price_too_low"), 'error', 7500) return end
                    if NewFuelPrice > Config.MaxFuelPrice then
                        QBCore.Functions.Notify(Lang:t("station_price_too_high"), "error")
                    else
                        TriggerServerEvent("cdn-fuel:station:server:updatefuelprice", NewFuelPrice, CurrentLocation)
                    end
                end
            else
                local fuelprice = exports['qb-input']:ShowInput({
                    header = Lang:t("input_alter_fuel_price_header_1")..StationFuelPrice..Lang:t("input_alter_fuel_price_header_2"),
                    submitText = Lang:t("input_alter_fuel_price_submit_text"),
                    inputs = { {
                        type = 'number',
                        isRequired = true,
                        name = 'price',
                        text = Lang:t("input_alter_fuel_price_submit_text")
                    }}
                })
                if fuelprice then
                    if Config.FuelDebug then print("Attempting to change fuel price!") end
                    Wait(100)
                    if not fuelprice.price then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    NewFuelPrice = tonumber(fuelprice.price)
                    if NewFuelPrice < Config.MinimumFuelPrice then QBCore.Functions.Notify(Lang:t("station_price_too_low"), 'error', 7500) return end
                    if NewFuelPrice > Config.MaxFuelPrice then
                        QBCore.Functions.Notify(Lang:t("station_price_too_high"), "error")
                    else
                        TriggerServerEvent("cdn-fuel:station:server:updatefuelprice", NewFuelPrice, CurrentLocation)
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:sellstation:menu', function(data) -- Menu, seen after selecting the Sell this Location option.
        local location = data.location
        local CitizenID = QBCore.Functions.GetPlayerData().citizenid
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            local GasStationCost = Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost)
            local SalePrice = math.percent(Config.GasStationSellPercentage, GasStationCost)
            if Config.Ox.Menu then
                lib.registerContext({
                    id = 'sellstationmenu',
                    title = Lang:t("menu_sell_station_header")..Config.GasStations[location].label,
                    options = {
                        {
                            title = Lang:t("menu_sell_station_header_accept"),
                            description = Lang:t("menu_sell_station_footer_accept")..Comma_Value(SalePrice)..".",
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:sellstation',
                            args = {
                                location = location,
                                SalePrice = SalePrice,
                            }
                        },
                        {
                            title = Lang:t("menu_header_close"),
                            description = Lang:t("menu_refuel_cancel"),
                            icon = "fas fa-times-circle",
                            arrow = false, -- puts arrow to the right
                            onSelect = function()
                                lib.hideContext()
                              end,
                        },
                    },
                })
                lib.showContext('sellstationmenu')
                TriggerServerEvent("cdn-fuel:stations:server:stationsold", location)
            else
                exports['qb-menu']:openMenu({
                    {
                        header = Lang:t("menu_sell_station_header")..Config.GasStations[location].label,
                        isMenuHeader = true,
                        icon = "fas fa-gas-pump",
                    },
                    {
                        header = Lang:t("menu_sell_station_header_accept"),
                        txt = Lang:t("menu_sell_station_footer_accept")..SalePrice..".",
                        icon = "fas fa-usd",
                        params = {
                            event = "cdn-fuel:stations:client:sellstation",
                            args = {
                                location = location,
                                SalePrice = SalePrice,
                            }
                        },
                    },
                    {
                        header = Lang:t("menu_header_close"),
                        txt = Lang:t("menu_sell_station_footer_close"),
                        icon = "fas fa-times-circle",
                        params = {
                            event = "qb-menu:closeMenu",
                        }
                    },
                })
                TriggerServerEvent("cdn-fuel:stations:server:stationsold", location)
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:changestationname', function() -- Menu for changing the label of the owned station.
        CanOpen = false
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then print("Showing Input for name Change!") end
            if Config.Ox.Input then
                local NewName = lib.inputDialog('Name Changer', {
                    { type = "input", label = 'Current Name',
                    default = Config.GasStations[CurrentLocation].label,
                    disabled = true },
                    { type = "input", label = 'Enter New Station Name',
                    placeholder = 'New Name'
                    },
                })
                if not NewName then return end
                NewNameName = NewName[2]
                if NewName then
                    if Config.FuelDebug then print("Attempting to alter stations name!") end
                    if not NewNameName then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error', 7500) return end
                    NewName = NewNameName
                    if type(NewName) ~= "string" then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error') return end
                    if Config.ProfanityList[NewName] then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error', 7500)
                        -- You can add logs for people that put prohibited words into the name changer if wanted, and here is where you would do it.
                        return
                    end
                    if string.len(NewName) > Config.NameChangeMaxChar then QBCore.Functions.Notify(Lang:t("station_name_too_long"), 'error') return end
                    if string.len(NewName) < Config.NameChangeMinChar then QBCore.Functions.Notify(Lang:t("station_name_too_short"), 'error') return end
                    Wait(100)
                    TriggerServerEvent("cdn-fuel:station:server:updatelocationname", NewName, CurrentLocation)
                end
            else
                local NewName = exports['qb-input']:ShowInput({
                    header = Lang:t("input_change_name_header_1")..Config.GasStations[CurrentLocation].label..Lang:t("input_change_name_header_2"),
                    submitText = Lang:t("input_change_name_submit_text"),
                    inputs = { {
                        type = 'text',
                        isRequired = true,
                        name = 'newname',
                        text = Lang:t("input_change_name_text")
                    }}
                })
                if NewName then
                    if Config.FuelDebug then print("Attempting to alter stations name!") end
                    if not NewName.newname then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error', 7500) return end
                    NewName = NewName.newname
                    if type(NewName) ~= "string" then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error') return end
                    if Config.ProfanityList[NewName] then QBCore.Functions.Notify(Lang:t("station_name_invalid"), 'error', 7500)
                        -- You can add logs for people that put prohibited words into the name changer if wanted, and here is where you would do it.
                        return
                    end
                    if string.len(NewName) > Config.NameChangeMaxChar then QBCore.Functions.Notify(Lang:t("station_name_too_long"), 'error') return end
                    if string.len(NewName) < Config.NameChangeMinChar then QBCore.Functions.Notify(Lang:t("station_name_too_short"), 'error') return end
                    Wait(100)
                    TriggerServerEvent("cdn-fuel:station:server:updatelocationname", NewName, CurrentLocation)
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:managemenu', function(location) -- Menu, seen after selecting the Manage this Location Option.
        location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        UpdateStationInfo("all")
        if Config.PlayerControlledFuelPrices then CanNotChangeFuelPrice = false else CanNotChangeFuelPrice = true end
        Wait(5)
        Wait(Config.WaitTime)
        if CanOpen then
            local PlayerData = QBCore.Functions.GetPlayerData()
            local ownerName = "Proprietário"
            if PlayerData and PlayerData.charinfo then
                ownerName = PlayerData.charinfo.firstname .. " " .. PlayerData.charinfo.lastname
            end

            -- Check shutoff status before opening
            QBCore.Functions.TriggerCallback('cdn-fuel:server:checkshutoff', function(isClosed)
                if isClosed == nil then isClosed = false end -- Default to open if nil

                local upgrades = {}
                if Config.StationUpgrades then
                    for k, v in pairs(Config.StationUpgrades) do
                        table.insert(upgrades, { level = k, label = v.label, capacity = v.capacity, price = v.price })
                    end
                end
                table.sort(upgrades, function(a, b) return a.level < b.level end)

                local loyaltyUpgrades = {}
                if Config.LoyaltyUpgrades then
                    for k, v in pairs(Config.LoyaltyUpgrades) do
                        table.insert(loyaltyUpgrades, { level = k, label = v.label, fuelPrice = v.fuelPrice, price = v.price, color = v.color or "#3b82f6" })
                    end
                end
                table.sort(loyaltyUpgrades, function(a, b) return a.level < b.level end)

                SendNUIMessage({
                    action = "openManagement",
                    data = {
                        balance = StationBalance or 0,
                        fuelStock = Currentreserveamount or 0,
                        maxStock = CurrentMaxCapacity,
                        fuelPrice = StationFuelPrice or 0,
                        ownerName = ownerName,
                        stationName = Config.GasStations[location].label,
                        reservePrice = CurrentReservePrice or Config.FuelReservesPrice or 3.0,
                        isClosed = isClosed, -- Pass shutoff status
                        logo = Config.GasStations[location].logo,
                        stockLevel = CurrentStockLevel,
                        upgrades = upgrades,
                        loyaltyLevel = CurrentLoyaltyLevel or 0,
                        loyaltyUpgrades = loyaltyUpgrades
                    }
                })
                SetNuiFocus(true, true)
            end, CurrentLocation)
        else
            if Config.FuelDebug then print("Not showing menu, as the player doesn't have proper permissions.") end
        end
    end)


    RegisterNetEvent('cdn-fuel:stations:client:managefunds', function(location) -- Menu, seen after selecting the Manage this Location Option.
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        UpdateStationInfo("all")
        Wait(5)
        Wait(Config.WaitTime)
        if CanOpen then

            if Config.Ox.Menu then
                lib.registerContext({
                    id = 'managefundsmenu',
                    title = Lang:t("menu_manage_company_funds_header_2")..Config.GasStations[CurrentLocation].label,
                    options = {
                        {
                            title = Lang:t("menu_manage_company_funds_withdraw_header"),
                            description = Lang:t("menu_manage_company_funds_withdraw_footer"),
                            icon = "fas fa-arrow-left",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:WithdrawFunds',
                            args = {
                                location = location,
                            }
                        },
                        {
                            title = Lang:t("menu_manage_company_funds_deposit_header"),
                            description = Lang:t("menu_manage_company_funds_deposit_footer"),
                            icon = "fas fa-arrow-right",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:DepositFunds',
                            args = {
                                location = location,
                            }
                        },
                        {
                            title = Lang:t("menu_manage_company_funds_return_header"),
                            description = Lang:t("menu_manage_company_funds_return_footer"),
                            icon = "fas fa-circle-left",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:managemenu',
                            args = {
                                location = location,
                            }
                        },
                        {
                            title = Lang:t("menu_header_close"),
                            description = Lang:t("menu_refuel_cancel"),
                            icon = "fas fa-times-circle",
                            arrow = false, -- puts arrow to the right
                            onSelect = function()
                                lib.hideContext()
                              end,
                        },
                    },
                })
                lib.showContext('managefundsmenu')
            else
                exports['qb-menu']:openMenu({
                    {
                        header = Lang:t("menu_manage_company_funds_header_2")..Config.GasStations[CurrentLocation].label,
                        isMenuHeader = true,
                        icon = "fas fa-gas-pump",
                    },
                    {
                        header = Lang:t("menu_manage_company_funds_withdraw_header"),
                        icon = "fas fa-arrow-left",
                        txt = Lang:t("menu_manage_company_funds_withdraw_footer"),
                        params = {
                            event = "cdn-fuel:stations:client:WithdrawFunds",
                            args = {
                                location = location,
                            }
                        },
                    },
                    {
                        header = Lang:t("menu_manage_company_funds_deposit_header"),
                        icon = "fas fa-arrow-right",
                        txt = Lang:t("menu_manage_company_funds_deposit_footer"),
                        params = {
                            event = "cdn-fuel:stations:client:DepositFunds",
                            args = {
                                location = location,
                            }
                        },
                    },
                    {
                        header = Lang:t("menu_manage_company_funds_return_header"),
                        txt = Lang:t("menu_manage_company_funds_return_footer"),
                        icon = "fas fa-circle-left",
                        params = {
                            event = "cdn-fuel:stations:client:managemenu",
                            args = {
                                location = location,
                            }
                        },
                    },
                })
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:WithdrawFunds', function(data)
        if Config.FuelDebug then print("Triggered Event for: Withdraw!") end
        CanOpen = false
        local location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then print("Showing Input for Withdraw!") end
            UpdateStationInfo("balance")
            Wait(50)
            if Config.Ox.Input then
                local Withdraw = lib.inputDialog('Withdraw Funds', {
                    { type = "input", label = 'Current Station Balance',
                    default = '$'..Comma_Value(StationBalance),
                    disabled = true },
                    { type = "number", label = 'Withdraw Amount',
                    },
                })
                if not Withdraw then return end
                WithdrawAmounts = tonumber(Withdraw[2])
                if Withdraw then
                    if Config.FuelDebug then print("Attempting to Withdraw!") end
                    Wait(100)
                    local amount = tonumber(WithdrawAmounts)
                    if not WithdrawAmounts then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    if amount < 1 then QBCore.Functions.Notify(Lang:t("station_withdraw_too_little"), 'error', 7500) return end
                    if amount > StationBalance then QBCore.Functions.Notify(Lang:t("station_withdraw_too_much"), 'error', 7500) return end
                    WithdrawAmount = tonumber(amount)
                    if (StationBalance - WithdrawAmount) < 0 then
                        QBCore.Functions.Notify(Lang:t("station_withdraw_too_much"), 'error', 7500)
                    else
                        TriggerServerEvent('cdn-fuel:station:server:Withdraw', amount, location, StationBalance)
                    end
                end
            else
                local Withdraw = exports['qb-input']:ShowInput({
                    header = Lang:t("input_withdraw_funds_header") ..StationBalance,
                    submitText = Lang:t("input_withdraw_submit_text"),
                    inputs = { {
                        type = 'number',
                        isRequired = true,
                        name = 'amount',
                        text = Lang:t("input_withdraw_text")
                    }}
                })
                if Withdraw then
                    if Config.FuelDebug then print("Attempting to Withdraw!") end
                    Wait(100)
                    local amount = tonumber(Withdraw.amount)
                    if not Withdraw.amount then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    if amount < 1 then QBCore.Functions.Notify(Lang:t("station_withdraw_too_little"), 'error', 7500) return end
                    if amount > StationBalance then QBCore.Functions.Notify(Lang:t("station_withdraw_too_much"), 'error', 7500) return end
                    WithdrawAmount = tonumber(amount)
                    if (StationBalance - WithdrawAmount) < 0 then
                        QBCore.Functions.Notify(Lang:t("station_withdraw_too_much"), 'error', 7500)
                    else
                        TriggerServerEvent('cdn-fuel:station:server:Withdraw', amount, location, StationBalance)
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:DepositFunds', function(data)
        if Config.FuelDebug then print("Triggered Event for: Deposit!") end
        CanOpen = false
        local location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                QBCore.Functions.Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            local bankmoney = QBCore.Functions.GetPlayerData().money['bank']
            if Config.FuelDebug then print("Showing Input for Deposit!") end
            UpdateStationInfo("balance")
            Wait(50)
            if Config.Ox.Input then
                local Deposit = lib.inputDialog('Deposit Funds', {
                    { type = "input", label = 'Current Station Balance',
                    default = '$'..Comma_Value(StationBalance),
                    disabled = true },
                    { type = "number", label = 'Deposit Amount',
                    },
                })
                if not Deposit then return end
                DepositAmounts = tonumber(Deposit[2])
                if Deposit then
                    if Config.FuelDebug then print("Attempting to Deposit!") end
                    Wait(100)
                    local amount = tonumber(DepositAmounts)
                    if not DepositAmounts then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    if amount < 1 then QBCore.Functions.Notify(Lang:t("station_deposit_too_little"), 'error', 7500) return end
                    DepositAmount = tonumber(amount)
                    if (DepositAmount) > bankmoney then
                        QBCore.Functions.Notify(Lang:t("station_deposity_too_much"), "error")
                    else
                        TriggerServerEvent('cdn-fuel:station:server:Deposit', amount, location, StationBalance)
                    end
                end
            else
                local Deposit = exports['qb-input']:ShowInput({
                    header = Lang:t("input_deposit_funds_header") ..StationBalance,
                    submitText = Lang:t("input_deposit_submit_text"),
                    inputs = { {
                        type = 'number',
                        isRequired = true,
                        name = 'amount',
                        text = Lang:t("input_deposit_text")
                    }}
                })
                if Deposit then
                    if Config.FuelDebug then print("Attempting to Deposit!") end
                    Wait(100)
                    local amount = tonumber(Deposit.amount)
                    if not Deposit.amount then QBCore.Functions.Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                    if amount < 1 then QBCore.Functions.Notify(Lang:t("station_deposit_too_little"), 'error', 7500) return end
                    DepositAmount = tonumber(amount)
                    if (DepositAmount) > bankmoney then
                        QBCore.Functions.Notify(Lang:t("station_deposity_too_much"), "error")
                    else
                        TriggerServerEvent('cdn-fuel:station:server:Deposit', amount, location, StationBalance)
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:Shutoff', function(location)
        TriggerServerEvent("cdn-fuel:stations:server:Shutoff", location)
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasemenu', function(location) -- Menu, seen after selecting the purchase this location option.
        local bankmoney = QBCore.Functions.GetPlayerData().money['bank']
        local baseCost = Config.GasStations[location].cost
        local taxAmount = GlobalTax(baseCost)
        local costofstation = baseCost + taxAmount

        if Config.OneStationPerPerson == true then
            QBCore.Functions.TriggerCallback('cdn-fuel:server:doesPlayerOwnStation', function(result)
                if result then
                    if Config.FuelDebug then print("Player already owns a station, so disallowing purchase.") end
                    PlayerOwnsAStation = true
                else
                    if Config.FuelDebug then print("Player doesn't own a station, so continuing purchase checks.") end
                    PlayerOwnsAStation = false
                end
            end)

            Wait(Config.WaitTime)

            if PlayerOwnsAStation == true then
                QBCore.Functions.Notify('You can only buy one station, and you already own one!', 'error')
                return
            end
        end

        if bankmoney < costofstation then
            QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank").." R$"..costofstation, 'error', 7500) return
        end

        if Config.FuelDebug then print("Opening NUI Purchase Menu") end

        SendNUIMessage({
            action = "openPurchase",
            data = {
                stationName = Config.GasStations[location].label,
                price = costofstation,
                tax = taxAmount
            }
        })
        SetNuiFocus(true, true)
    end)

    RegisterNetEvent('cdn-fuel:stations:openmenu', function(location) -- Menu #1, the first menu you see.
        if location then CurrentLocation = location end
        if not CurrentLocation then return end -- Safety check
        DisablePurchase = true
        DisableOwnerMenu = true
        ShutOffDisabled = false

        QBCore.Functions.TriggerCallback('cdn-fuel:server:locationpurchased', function(result)
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned.") end
                DisablePurchase = true
            else
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned.") end
                DisablePurchase = false
                DisableOwnerMenu = true
            end
        end, CurrentLocation)

        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBCore.Functions.GetPlayerData().citizenid
            if result then
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                DisableOwnerMenu = false
            else
                if Config.FuelDebug then print("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                DisableOwnerMenu = true
            end
        end, CurrentLocation)

        if Config.EmergencyShutOff then
            QBCore.Functions.TriggerCallback('cdn-fuel:server:checkshutoff', function(result)
                if result == true then
                    PumpState = "disabled."
                elseif result == false then
                    PumpState = "enabled."
                else
                    PumpState = "nil"
                end

                if Config.FuelDebug then print("The result from Callback: Config.GasStations["..CurrentLocation.."].shutoff = "..PumpState) end
            end, CurrentLocation)
        else
            PumpState = "enabled."
            ShutOffDisabled = true
        end

        Wait(Config.WaitTime)

        if Config.FuelDebug then print("Opening NUI Interaction Menu") end
        
        SendNUIMessage({
            action = "openInteraction",
            data = {
                stationName = Config.GasStations[CurrentLocation].label,
                isOwner = not DisableOwnerMenu,
                canPurchase = not DisablePurchase,
                pumpState = PumpState, -- "enabled." or "disabled." or "nil"
                shutoffDisabled = ShutOffDisabled
            }
        })
        SetNuiFocus(true, true)
    end)

    -- Threads
    CreateThread(function() -- Background refresh thread
        while true do
            Wait(30000) -- Refresh station labels every 30 seconds
            TriggerServerEvent('cdn-fuel:server:updatelocationlabels')
        end
    end)
    -- NUI Callbacks for Management
    RegisterNUICallback('manage:deposit', function(data, cb)
        TriggerServerEvent('cdn-fuel:station:server:Deposit', tonumber(data.amount), CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:withdraw', function(data, cb)
        TriggerServerEvent('cdn-fuel:station:server:Withdraw', tonumber(data.amount), CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:changePrice', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent("cdn-fuel:station:server:updatefuelprice", tonumber(data.price), CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:buyStock', function(data, cb)
        if not CurrentLocation then return end
        local amount = tonumber(data.amount)
        -- Use the dynamic CurrentReservePrice calculated from Loyalty Level
        local pricePerLiter = CurrentReservePrice or Config.FuelReservesPrice or 3.0
        local price = math.ceil(GlobalTax(amount * pricePerLiter) + (amount * pricePerLiter))
        TriggerServerEvent('cdn-fuel:stations:server:buyreserves', CurrentLocation, price, amount)
        cb('ok')
    end)

    RegisterNUICallback('manage:toggleStatus', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent("cdn-fuel:stations:server:Shutoff", CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:renameStation', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent("cdn-fuel:station:server:updatelocationname", data.name, CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:updateLogo', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent("cdn-fuel:station:server:updatelogo", data.url, CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:buyUpgrade', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent('cdn-fuel:station:server:buyUpgrade', { 
            location = CurrentLocation, 
            level = data.level, 
            price = data.price 
        })
        cb('ok')
    end)

    RegisterNUICallback('manage:buyLoyaltyUpgrade', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent('cdn-fuel:station:server:buyLoyaltyUpgrade', { 
            location = CurrentLocation, 
            level = data.level, 
            price = data.price 
        })
        cb('ok')
    end)

    RegisterNUICallback('manage:sellStation', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent("cdn-fuel:stations:server:sellstation", CurrentLocation)
        cb('ok')
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
    end)

    RegisterNUICallback('manage:getSales', function(data, cb)
        if not CurrentLocation then cb({}) return end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:getSales', function(result)
            cb(result)
        end, CurrentLocation)
    end)

    RegisterNUICallback('manage:getFinanceLogs', function(data, cb)
        if not CurrentLocation then cb({}) return end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:getFinanceLogs', function(result)
            cb(result)
        end, CurrentLocation)
    end)

    RegisterNUICallback('manage:clearFinanceHistory', function(data, cb)
        if not CurrentLocation then cb('error') return end
        TriggerServerEvent('cdn-fuel:station:server:clearFinanceHistory', CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('manage:getAnalytics', function(data, cb)
        if Config.FuelDebug then print("CDN-Fuel: NUI manage:getAnalytics called. CurrentLocation: " .. tostring(CurrentLocation)) end
        if not CurrentLocation then cb({}) return end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:getAnalytics', function(result)
            if Config.FuelDebug then print("CDN-Fuel: Analytics result received from server.") end
            cb(result)
        end, CurrentLocation)
    end)

    RegisterNUICallback('manage:closeWeek', function(data, cb)
        if not CurrentLocation then return end
        TriggerServerEvent('cdn-fuel:server:closeWeek', CurrentLocation, data.startDate, data.endDate)
        cb('ok')
    end)

    RegisterNUICallback('interaction:manage', function(data, cb)
        if not CurrentLocation then return end
        TriggerEvent('cdn-fuel:stations:client:managemenu', CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('interaction:purchase', function(data, cb)
        if not CurrentLocation then return end
        TriggerEvent('cdn-fuel:stations:client:purchasemenu', CurrentLocation)
        cb('ok')
    end)

    RegisterNUICallback('interaction:shutoff', function(data, cb)
        if not CurrentLocation then return end
        TriggerEvent('cdn-fuel:stations:client:Shutoff', CurrentLocation)
        cb('ok')
    end)



    RegisterNUICallback('purchase:confirm', function(data, cb)
        if not CurrentLocation then return end
        -- Trigger original purchase logic
        TriggerEvent('cdn-fuel:stations:client:purchaselocation', { location = CurrentLocation })
        
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
        cb('ok')
    end)

    -- StationProps is declared at the top of this block (line ~16)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            -- Cleanup Global Props tracked here
            for id, props in pairs(StationProps) do
                if DoesEntityExist(props.ped) then DeleteEntity(props.ped) end
                if DoesEntityExist(props.charger) then DeleteEntity(props.charger) end
                if props.pumps then
                    for _, p in ipairs(props.pumps) do
                        if DoesEntityExist(p) then DeleteEntity(p) end
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:client:syncStations', function(newId, stationData)
        if not newId or not stationData or not Config.PlayerOwnedGasStationsEnabled then return end
        
        -- Update Local Config
        local current = stationData
        Config.GasStations[newId] = current

        if Config.FuelDebug then print("[CDN-FUEL] Station #" .. newId .. " synchronized. Entities will spawn when nearby.") end
        
        if current.type == 'air' or current.type == 'water' then
            TriggerEvent('cdn-fuel:client:createDynamicAirSeaZone', newId, current)
        end
    end)

    -- Persistent Depot Prop Spawn
    CreateThread(function()
        local loadCoords = Config.DeliveryTruckSpawns['tankerLoadProp']
        if loadCoords then
            local propModel = joaat(Config.TankerLoadPropModel or 'prop_storagetank_02b')
            RequestAndLoadModel(propModel)
            depotLoadProp = CreateObject(propModel, loadCoords.x, loadCoords.y, loadCoords.z, false, false, false)
            SetEntityHeading(depotLoadProp, loadCoords.w)
            FreezeEntityPosition(depotLoadProp, true)

            -- Target: Grab nozzle from depot pump (Always present, checks tankerLoaded)
            AddTargetEntity(depotLoadProp, {
                options = {
                    {
                        type = "client",
                        label = "Pegar bico de carregamento",
                        icon = "fas fa-gas-pump",
                        action = function()
                            TriggerEvent('cdn-fuel:station:client:grabDepotNozzle')
                        end,
                        canInteract = function()
                            return not tankerLoaded and depotNozzle == nil and ReservePickupData and ReservePickupData.location ~= nil
                        end
                    },
                    {
                        type = "client",
                        label = "Devolver bico de carregamento",
                        icon = "fas fa-rotate-left",
                        action = function()
                            TriggerEvent('cdn-fuel:station:client:returnDepotNozzle')
                        end,
                        canInteract = function()
                            return tankerLoaded and depotNozzle ~= nil
                        end
                    },
                },
                distance = 3.0
            })
            if Config.FuelDebug then print("[CDN-FUEL] Persistent Depot Pump spawned.") end
        end
    end)
end -- For Config.PlayerOwnedGasStationsEnabled check, don't remove!