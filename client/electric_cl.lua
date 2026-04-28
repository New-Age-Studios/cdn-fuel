if Config.ElectricVehicleCharging then
    -- Variables   
    local QBCore = exports[Config.Core]:GetCoreObject()
    local HoldingElectricNozzle = false
    local RefuelPossible = false
    local RefuelPossibleAmount = 0 
    local RefuelCancelled = false
    local RefuelPurchaseType = 'bank'

    if Config.PumpHose then
        Rope = nil
    end

    -- Global Electric Charger Visual Debug
    if Config.FuelDebug then
        CreateThread(function()
            while true do
                local sleep = 1500
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local pumpCoords, pumpEntity = GetClosestPump(coords, true)

                if pumpEntity and pumpEntity ~= 0 then
                    local dist = #(coords - pumpCoords)
                    if dist < 10.0 then
                        sleep = 0
                        local offset = Config.ElectricRopeOffset or vec3(0.0, 0.0, 1.76)
                        local worldCoords = GetOffsetFromEntityInWorldCoords(pumpEntity, offset.x, offset.y, offset.z)
                        -- Draw Sphere Marker
                        local debugColor = HexToRGB(Config.DebugColor or "#FF00FF")
                        DrawMarker(28, worldCoords.x, worldCoords.y, worldCoords.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, debugColor.r, debugColor.g, debugColor.b, 200, false, false, 2, false, nil, nil, false)
                    end
                end
                Wait(sleep)
            end
        end)
    end

    -- Start
    AddEventHandler('onResourceStart', function(resource)
        if resource == GetCurrentResourceName() then
            Wait(100)
            DeleteObject(ElectricNozzle)
            HoldingElectricNozzle = false
        end
    end)

    -- Functions
    function IsHoldingElectricNozzle()
        return HoldingElectricNozzle
    end exports('IsHoldingElectricNozzle', IsHoldingElectricNozzle)

    function SetElectricNozzle(state)
        if state == "putback" then
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "putbackcharger", 0.4)
            Wait(250)
            if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(false, true) end
            DeleteObject(ElectricNozzle)
            HoldingElectricNozzle = false
            if Config.PumpHose == true then
                RopeUnloadTextures()
                DeleteRope(Rope)
            end
        elseif state == "pickup" then    
            TriggerEvent('cdn-fuel:client:grabelectricnozzle')
            HoldingElectricNozzle = true
        else
            if Config.FuelDebug then print("State is not valid, it must be pickup or putback.") end
        end
    end exports('SetElectricNozzle', SetElectricNozzle)

    -- Events
    if Config.Ox.Menu then
        RegisterNetEvent('cdn-electric:client:OpenContextMenu', function(total, fuelamounttotal, purchasetype)
            lib.registerContext({
                id = 'electricconfirmationmenu',
                title = Lang:t("menu_purchase_station_header_1")..math.ceil(total)..Lang:t("menu_purchase_station_header_2"),
                options = {
                    {
                        title = Lang:t("menu_purchase_station_confirm_header"),
                        description = Lang:t("menu_electric_accept"),
                        icon = "fas fa-check-circle",
                        arrow = false, -- puts arrow to the right
                        event = 'cdn-fuel:client:electric:ChargeVehicle',
                        args = {
                            fuelamounttotal = fuelamounttotal,
                            purchasetype = purchasetype,
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
            lib.showContext('electricconfirmationmenu')
        end)
    end

    RegisterNetEvent('cdn-fuel:client:electric:FinalMenu', function(purchasetype)
        local money = nil
        if purchasetype == "bank" then money = QBCore.Functions.GetPlayerData().money['bank'] elseif purchasetype == 'cash' then money = QBCore.Functions.GetPlayerData().money['cash'] end
        FuelPrice = (1 * Config.ElectricChargingPrice)
        local vehicle = GetClosestVehicle()

        -- Police Discount Math --
        if Config.EmergencyServicesDiscount['enabled'] == true and (Config.EmergencyServicesDiscount['emergency_vehicles_only'] == false or (Config.EmergencyServicesDiscount['emergency_vehicles_only'] == true and GetVehicleClass(vehicle) == 18)) then
            local discountedJobs = Config.EmergencyServicesDiscount['job']
            local plyJob = QBCore.Functions.GetPlayerData().job.name
            local shouldRecieveDiscount = false

            if type(discountedJobs) == "table" then
                for i = 1, #discountedJobs, 1 do
                    if plyJob == discountedJobs[i] then
                        shouldRecieveDiscount = true
                        break
                    end
                end
            elseif plyJob == discountedJobs then
                shouldRecieveDiscount = true
            end

            if shouldRecieveDiscount == true and not QBCore.Functions.GetPlayerData().job.onduty and Config.EmergencyServicesDiscount['ondutyonly'] then
                QBCore.Functions.Notify(Lang:t("you_are_discount_eligible"), 'primary', 7500)
				shouldRecieveDiscount = false
			end

            if shouldRecieveDiscount then
                local discount = Config.EmergencyServicesDiscount['discount']
                if discount > 100 then
                    discount = 100
                else
                    if discount <= 0 then discount = 0 end
                end
                if discount ~= 0 then
                    if discount == 100 then
                        FuelPrice = 0
                        if Config.FuelDebug then
                            print("Your discount for Emergency Services is set @ "..discount.."% so fuel is free!")
                        end
                    else
                        discount = discount / 100
                        FuelPrice = FuelPrice - (FuelPrice*discount)

                        if Config.FuelDebug then
                            print("Your discount for Emergency Services is set @ "..discount.."%. Setting new price to: $"..FuelPrice)
                        end
                    end
                else
                    if Config.FuelDebug then
                        print("Your discount for Emergency Services is set @ "..discount.."%. It cannot be 0 or < 0!")
                    end
                end
            end
        end

        local curfuel = GetFuel(vehicle)
        local finalfuel
        if curfuel < 10 then finalfuel = string.sub(curfuel, 1, 1) else finalfuel = string.sub(curfuel, 1, 2) end
        local maxfuel = (100 - finalfuel - 1)
        local wholetankcost = (FuelPrice * maxfuel)
        local wholetankcostwithtax = math.ceil((wholetankcost) + GlobalTax(wholetankcost))
        if Config.FuelDebug then print("Attempting to open Input with the total: $"..wholetankcostwithtax.." at $"..FuelPrice.." / L".." Maximum Fuel Amount: "..maxfuel) end
        if Config.Ox.Input then
            Electricity = lib.inputDialog('Carregador Elétrico', {
                { type = "input", label = 'Preço da Eletricidade',
                  default = 'R$'.. FuelPrice .. '/KWh',
                  disabled = true },
                { type = "input", label = 'Carga Atual',
                  default = finalfuel .. ' KWh',
                  disabled = true },
                { type = "input", label = 'Carga Completa Necessária',
                  default = maxfuel,
                  disabled = true },
                { type = "slider", label = 'Custo da Carga Completa: R$' ..wholetankcostwithtax.. '',
                  default = maxfuel,
                  min = 0,
                  max = maxfuel
                },
            })
            

            if not Electricity then return end
            ElectricityAmount = tonumber(Electricity[4])

            if Electricity then
                if not ElectricityAmount then if Config.FuelDebug then print("ElectricityAmount is invalid!") end return end
                if not HoldingElectricNozzle then QBCore.Functions.Notify(Lang:t("electric_no_nozzle"), 'error', 7500) return end
                if (ElectricityAmount + finalfuel) >= 100 then
                    QBCore.Functions.Notify(Lang:t("tank_already_full"), "error")
                else
                    if GlobalTax(ElectricityAmount * FuelPrice) + (ElectricityAmount * FuelPrice) <= money then
                        TriggerServerEvent('cdn-fuel:server:electric:OpenMenu', ElectricityAmount, IsInGasStation(), false, purchasetype, FuelPrice)
                    else
                        QBCore.Functions.Notify(Lang:t("not_enough_money"), 'error', 7500)
                    end
                end
            end
        else
            Electricity = exports['qb-input']:ShowInput({
                header = "Selecione a quantidade de combustível <br> Preço atual: R$" ..
                FuelPrice .. " / KWh <br> Cobrança atual: " .. finalfuel .. " KWh <br> Custo de cobrança total: R$" ..
                wholetankcostwithtax .. "",
                submitText = "Insira o carregador",
                inputs = {{
                    type = 'number',
                    isRequired = true,
                    name = 'amount',
                    text = 'A bateria pode segurar ' .. maxfuel .. ' More KWh.'
                }}
            })
            if Electricity then
                if not Electricity.amount then print("Electricity.amount is invalid!") return end
                if not HoldingElectricNozzle then QBCore.Functions.Notify(Lang:t("electric_no_nozzle"), 'error', 7500) return end
                if (Electricity.amount + finalfuel) >= 100 then
                    QBCore.Functions.Notify(Lang:t("tank_already_full"), "error")
                else
                    if GlobalTax(Electricity.amount * FuelPrice) + (Electricity.amount * FuelPrice) <= money then
                        TriggerServerEvent('cdn-fuel:server:electric:OpenMenu', Electricity.amount, IsInGasStation(), false, purchasetype, FuelPrice)
                    else
                        QBCore.Functions.Notify(Lang:t("not_enough_money"), 'error', 7500)
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:client:electric:SendMenuToServer', function()
        local vehicle = GetClosestVehicle()
        local vehModel = GetEntityModel(vehicle)
        local vehiclename = string.lower(GetDisplayNameFromVehicleModel(vehModel))
        local currentFuel = GetFuel(vehicle)
        
        -- Check if vehicle is electric (using same logic as before)
        local isElectric = false
        if Config.ElectricVehicles[vehiclename] and Config.ElectricVehicles[vehiclename].isElectric then
             isElectric = true
        end

        if not isElectric then
            QBCore.Functions.Notify(Lang:t("electric_vehicle_not_electric"), 'error', 7500)
            return
        end

        if not IsHoldingElectricNozzle() then 
            QBCore.Functions.Notify(Lang:t("electric_no_nozzle"), 'error', 7500) 
            return 
        end

        if currentFuel >= 95 then
            QBCore.Functions.Notify(Lang:t("tank_already_full"), 'error')
            return
        end

         -- Open NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            data = {
                maxFuel = (100 - math.ceil(currentFuel)), -- Max kWh needed
                currentFuel = currentFuel,
                price = Config.ElectricChargingPrice,
                type = 'electric'
            }
        })
    end)

    RegisterNetEvent('cdn-fuel:client:electric:ChargeVehicle', function(purchasetype, fuelamounttotal)
        if Config.FuelDebug then print("Charging Vehicle: "..tostring(fuelamounttotal).." via "..tostring(purchasetype)) end
        local amount = 0
        local pType = purchasetype
        
        if type(purchasetype) == "table" then
            -- Fallback if somehow a table was passed
            pType = purchasetype.purchasetype or RefuelPurchaseType
            amount = purchasetype.fuelamounttotal or RefuelPossibleAmount
        else
            if not Config.RenewedPhonePayment or pType == "cash" then
                amount = fuelamounttotal
            else
                amount = RefuelPossibleAmount
            end
        end

        if not pType then pType = RefuelPurchaseType or "cash" end
        purchasetype = pType -- Set the outer scope variable if needed
        if not HoldingElectricNozzle then return end
        amount = tonumber(amount)
        if amount < 1 then return end
        if amount < 10 then fuelamount = string.sub(amount, 1, 1) else fuelamount = string.sub(amount, 1, 2) end
        local FuelPrice = (Config.ElectricChargingPrice * 1)
        local vehicle = GetClosestVehicle()

        -- Police Discount Math --
        if Config.EmergencyServicesDiscount['enabled'] == true and (Config.EmergencyServicesDiscount['emergency_vehicles_only'] == false or (Config.EmergencyServicesDiscount['emergency_vehicles_only'] == true and GetVehicleClass(vehicle) == 18)) then
            local discountedJobs = Config.EmergencyServicesDiscount['job']
            local plyJob = QBCore.Functions.GetPlayerData().job.name
            local shouldRecieveDiscount = false

            if type(discountedJobs) == "table" then
                for i = 1, #discountedJobs, 1 do
                    if plyJob == discountedJobs[i] then
                        shouldRecieveDiscount = true
                        break
                    end
                end
            elseif plyJob == discountedJobs then
                shouldRecieveDiscount = true
            end

            if shouldRecieveDiscount == true and not QBCore.Functions.GetPlayerData().job.onduty and Config.EmergencyServicesDiscount['ondutyonly'] then
                QBCore.Functions.Notify(Lang:t("you_are_discount_eligible"), 'primary', 7500)
				shouldRecieveDiscount = false
			end

            if shouldRecieveDiscount then
                local discount = Config.EmergencyServicesDiscount['discount']
                if discount > 100 then 
                    discount = 100 
                else 
                    if discount <= 0 then discount = 0 end
                end
                if discount ~= 0 then
                    if discount == 100 then
                        FuelPrice = 0
                        if Config.FuelDebug then
                            print("Your discount for Emergency Services is set @ "..discount.."% so fuel is free!")
                        end
                    else
                        discount = discount / 100
                        FuelPrice = FuelPrice - (FuelPrice*discount)

                        if Config.FuelDebug then
                            print("Your discount for Emergency Services is set @ "..discount.."%. Setting new price to: $"..FuelPrice)
                        end
                    end
                else
                    if Config.FuelDebug then
                        print("Your discount for Emergency Services is set @ "..discount.."%. It cannot be 0 or < 0!")
                    end
                end
            end
        end

        local refillCost = (amount * FuelPrice) + GlobalTax(amount * FuelPrice)
        local vehicle = GetClosestVehicle()
        local ped = PlayerPedId()
        local time = amount * Config.RefuelTime
        if amount < 10 then time = 10 * Config.RefuelTime end
        if not vehicle then return end
        local vehicleCoords = GetEntityCoords(vehicle)
        if IsInGasStation() then
            if IsPlayerNearVehicle() then
                RequestAnimDict(Config.RefuelAnimationDictionary)
                while not HasAnimDictLoaded('timetable@gardener@filling_can') do Wait(100) end
                if GetIsVehicleEngineRunning(vehicle) and Config.VehicleBlowUp then
                    local Chance = math.random(1, 100)
                    if Chance <= Config.BlowUpChance then
                        AddExplosion(vehicleCoords, 5, 50.0, true, false, true)
                        return
                    end
                end
                TaskPlayAnim(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 8.0, 1.0, -1, 1, 0, false, false, false)
                refueling = true
                Refuelamount = 0
                CreateThread(function()
                    while refueling do
                        if Refuelamount == nil then Refuelamount = 0 end
                        Wait(Config.RefuelTime)
                        Refuelamount = Refuelamount + 1
                        if Cancelledrefuel then
                            local finalrefuelamount = math.floor(Refuelamount)
                            local refillCost = (finalrefuelamount * FuelPrice) + GlobalTax(finalrefuelamount * FuelPrice)
                            if Config.RenewedPhonePayment and purchasetype == "bank" then
                                local remainingamount = (amount - Refuelamount)
                                MoneyToGiveBack = (GlobalTax(remainingamount * FuelPrice) + (remainingamount * FuelPrice))
                                TriggerServerEvent("cdn-fuel:server:phone:givebackmoney", MoneyToGiveBack)
                            else
                                local finalrefuelamount = math.floor(Refuelamount)
                                local finalCost = (finalrefuelamount * FuelPrice) + GlobalTax(finalrefuelamount * FuelPrice)
                                TriggerServerEvent('cdn-fuel:server:PayForFuel', finalCost, purchasetype, FuelPrice, true, nil, CurrentLocation, finalrefuelamount)
                            end
                            local curfuel = GetFuel(vehicle)
                            local finalfuel = (curfuel + Refuelamount)
                            if finalfuel >= 98 and finalfuel < 100 then
                                SetFuel(vehicle, 100)
                            else
                                SetFuel(vehicle, finalfuel)
                            end
                            if Config.RenewedPhonePayment then
                                RefuelCancelled = true
                                RefuelPossibleAmount = 0
                                RefuelPossible = false
                            end
                            Cancelledrefuel = false
                        end
                    end
                end)
                TriggerServerEvent("InteractSound_SV:PlayOnSource", "charging", 0.3)
                if Config.Ox.Progress then
                    if lib.progressCircle({
                        duration = time,
                        label = Lang:t("prog_electric_charging"),
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            move = true,
                            combat = true
                        },
                    }) then
                        refueling = false
                        if not Config.RenewedPhonePayment or purchasetype == 'cash' then 
                            TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, true, nil, CurrentLocation, amount) 
                        end
                        local curfuel = GetFuel(vehicle)
                        local finalfuel = (curfuel + amount)
                        if finalfuel > 99 and finalfuel < 100 then
                            SetFuel(vehicle, 100)
                        else
                            SetFuel(vehicle, finalfuel)
                        end
                        if Config.RenewedPhonePayment then
                            RefuelCancelled = true
                            RefuelPossibleAmount = 0
                            RefuelPossible = false
                        end
                        StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
                        TriggerServerEvent("InteractSound_SV:PlayOnSource", "chargestop", 0.4)
                    else
                        refueling = false
                        Cancelledrefuel = true
                        StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
                        TriggerServerEvent("InteractSound_SV:PlayOnSource", "chargestop", 0.4)                        
                    end
                else
                    QBCore.Functions.Progressbar("charge-car", Lang:t("prog_electric_charging"), time, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function()
                        refueling = false
                        if not Config.RenewedPhonePayment or purchasetype == 'cash' then 
                            TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, true, nil, CurrentLocation, amount) 
                        end
                        local curfuel = GetFuel(vehicle)
                        local finalfuel = (curfuel + amount)
                        if finalfuel > 99 and finalfuel < 100 then
                            SetFuel(vehicle, 100)
                        else
                            SetFuel(vehicle, finalfuel)
                        end
                        if Config.RenewedPhonePayment then
                            RefuelCancelled = true
                            RefuelPossibleAmount = 0
                            RefuelPossible = false
                        end
                        StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
                        TriggerServerEvent("InteractSound_SV:PlayOnSource", "chargestop", 0.4)
                    end, function()
                        refueling = false
                        Cancelledrefuel = true
                        StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
                        TriggerServerEvent("InteractSound_SV:PlayOnSource", "chargestop", 0.4)
                    end, "fas fa-charging-station")
                end
            end
        else return end
    end)

    RegisterNetEvent('cdn-fuel:client:grabelectricnozzle', function()
        local ped = PlayerPedId()
        if HoldingElectricNozzle then return end

        local grabbedCoords = GetEntityCoords(ped)
        
        -- Improved Location Detection Fallback
        if not CurrentLocation or CurrentLocation == 0 then
            local closestDist = 15.0
            for i = 1, #Config.GasStations do
                local station = Config.GasStations[i]
                if station and station.electricchargercoords then
                    local charCoords = type(station.electricchargercoords) == 'string' and json.decode(station.electricchargercoords) or station.electricchargercoords
                    if charCoords and charCoords.x then
                        local dist = #(grabbedCoords - vector3(charCoords.x, charCoords.y, charCoords.z))
                        if dist < closestDist then
                            closestDist = dist
                            CurrentLocation = i
                            if Config.FuelDebug then print("[CDN-FUEL] Electric Station fallback detected: " .. i) end
                        end
                    end
                end
            end
        end

        local function StartGrabbing()
            LoadAnimDict("anim@am_hold_up@male")
            TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
            Wait(300)
            StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)
            ElectricNozzle = CreateObject(joaat(Config.ElectricNozzleModel), 1.0, 1.0, 1.0, true, true, false)
            local lefthand = GetPedBoneIndex(ped, Config.ElectricNozzleAttachment.bone)
            local pos = Config.ElectricNozzleAttachment.pos
            local rot = Config.ElectricNozzleAttachment.rot
            AttachEntityToEntity(ElectricNozzle, ped, lefthand, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 0, 1, 0, 1, 0, 1)
            local grabbedelectricnozzlecoords = GetEntityCoords(ped)
            HoldingElectricNozzle = true
            if Config.PumpHose == true then
                local pumpCoords, pump = GetClosestPump(grabbedelectricnozzlecoords, true)
                RopeLoadTextures()
                while not RopeAreTexturesLoaded() do
                    Wait(0)
                    RopeLoadTextures()
                end
                while not pump do
                    Wait(0)
                end
                Rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, Config.RopeType['electric'], 1000.0, 0.0, 1.0, false, false, false, 1.0, true)
                while not Rope do
                    Wait(0)
                end
                ActivatePhysics(Rope)
                Wait(100)
                local nozzlePos = GetEntityCoords(ElectricNozzle)
                nozzlePos = GetOffsetFromEntityInWorldCoords(ElectricNozzle, -0.005, 0.185, -0.05)
                
                -- Electric Rope Offset Logic
                local ropeOffset = Config.ElectricRopeOffset or vec3(0.0, 0.0, 1.76)
                local attachCoords = GetOffsetFromEntityInWorldCoords(pump, ropeOffset.x, ropeOffset.y, ropeOffset.z)
                
                AttachEntitiesToRope(Rope, pump, ElectricNozzle, attachCoords.x, attachCoords.y, attachCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, 5.0, false, false, nil, nil)
            end
            CreateThread(function()
                while HoldingElectricNozzle do
                    local currentcoords = GetEntityCoords(ped)
                    local dist = #(grabbedelectricnozzlecoords - currentcoords)
                    if not TargetCreated then if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(true, true) end end
                    TargetCreated = true
                    if dist > 7.5 then
                        if TargetCreated then if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(false, true) end end
                        HoldingElectricNozzle = false
                        DeleteObject(ElectricNozzle)
                        QBCore.Functions.Notify(Lang:t("nozzle_cannot_reach"), 'error')
                        if Config.PumpHose == true then
                            RopeUnloadTextures()
                            DeleteRope(Rope)
                        end
                    end
                    Wait(2500)
                end
            end)
        end

        -- Verify Station Status before allowing grab
        if CurrentLocation and CurrentLocation ~= 0 then
            QBCore.Functions.TriggerCallback('cdn-fuel:server:electric:getStatus', function(status)
                if status == 0 or status == false then
                    QBCore.Functions.Notify("Este carregador está desativado por falta de pagamento do proprietário.", "error")
                else
                    StartGrabbing()
                end
            end, CurrentLocation)
        else
            StartGrabbing()
        end
    end)

    RegisterNetEvent('cdn-fuel:client:electric:RefuelMenu', function()
        if Config.RenewedPhonePayment then
            if not RefuelPossible then 
                TriggerEvent('cdn-fuel:client:electric:SendMenuToServer')
            else 
                if Config.RenewedPhonePayment then
                    if not Cancelledrefuel and not RefuelCancelled then
                        if RefuelPossibleAmount then
                            local purchasetype = "bank"
                            local fuelamounttotal = tonumber(RefuelPossibleAmount)
                            if Config.FuelDebug then print("Attempting to charge vehicle.") end
                            TriggerEvent('cdn-fuel:client:electric:ChargeVehicle', purchasetype, fuelamounttotal)
                        else
                            QBCore.Functions.Notify(Lang:t("electric_more_than_zero"), 'error', 7500)
                        end
                    end
                end
            end
        else
            TriggerEvent("cdn-fuel:client:electric:SendMenuToServer")
        end
    end)

    if Config.RenewedPhonePayment then
        RegisterNetEvent('cdn-fuel:client:electric:phone:PayForFuel', function(amount)
            FuelPrice = Config.ElectricChargingPrice
            
            -- Police Discount Math --
            if Config.EmergencyServicesDiscount['enabled'] == true then
                local discountedJobs = Config.EmergencyServicesDiscount['job']
                local plyJob = QBCore.Functions.GetPlayerData().job.name
                local shouldRecieveDiscount = false

                if type(discountedJobs) == "table" then
                    for i = 1, #discountedJobs, 1 do
                        if plyJob == discountedJobs[i] then
                            shouldRecieveDiscount = true
                            break
                        end
                    end
                elseif plyJob == discountedJobs then
                    shouldRecieveDiscount = true
                end

                if shouldRecieveDiscount == true and not QBCore.Functions.GetPlayerData().job.onduty and Config.EmergencyServicesDiscount['ondutyonly'] then
                    QBCore.Functions.Notify(Lang:t("you_are_discount_eligible"), 'primary', 7500)
                    shouldRecieveDiscount = false
                end

                if shouldRecieveDiscount then
                    local discount = Config.EmergencyServicesDiscount['discount']
                    if discount > 100 then 
                        discount = 100 
                    else 
                        if discount <= 0 then discount = 0 end
                    end
                    if discount ~= 0 then
                        if discount == 100 then
                            FuelPrice = 0
                            if Config.FuelDebug then
                                print("Your discount for Emergency Services is set @ "..discount.."% so fuel is free!")
                            end
                        else
                            discount = discount / 100
                            FuelPrice = FuelPrice - (FuelPrice*discount)

                            if Config.FuelDebug then
                                print("Your discount for Emergency Services is set @ "..discount.."%. Setting new price to: $"..FuelPrice)
                            end
                        end
                    else
                        if Config.FuelDebug then
                            print("Your discount for Emergency Services is set @ "..discount.."%. It cannot be 0 or < 0!")
                        end
                    end
                end
            end
            local cost = amount * FuelPrice
            local tax = GlobalTax(cost)
            local total = math.ceil(cost + tax)
            local success = exports['qb-phone']:PhoneNotification(Lang:t("electric_phone_header"), Lang:t("electric_phone_notification")..total, 'fas fa-bolt', '#9f0e63', "NONE", 'fas fa-check-circle', 'fas fa-times-circle')
            if success then
                if QBCore.Functions.GetPlayerData().money['bank'] <= (GlobalTax(amount) + amount) then
                    QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank"), "error")
                else
                    TriggerServerEvent('cdn-fuel:server:PayForFuel', total, "bank", FuelPrice, true, nil, CurrentLocation)
                    RefuelPossible = true
                    RefuelPossibleAmount = amount
                    RefuelPurchaseType = "bank"
                    RefuelCancelled = false
                end
            end
        end)
    end

    -- Threads (Legacy spawning removed, now handled dynamically in station_cl.lua)

    -- Resource Stop
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            if IsHoldingElectricNozzle() then DeleteObject(ElectricNozzle) end

            if Config.PumpHose then
                RopeUnloadTextures()
                if Rope then DeleteRope(Rope) end
            end
        end
    end)

    -- Target
    if Config.TargetResource == 'ox_target' then
        exports.ox_target:addModel(Config.ElectricChargerModel, {
            {
                name = 'grab_electric_nozzle',
                event = "cdn-fuel:client:grabelectricnozzle",
                icon = "fas fa-bolt",
                label = Lang:t("grab_electric_nozzle"),
                canInteract = function()
                    if not IsHoldingElectricNozzle() and not IsPedInAnyVehicle(PlayerPedId()) then
                        return true
                    end
                end,
                distance = 2.0
            },
            {
                name = 'return_nozzle',
                event = "cdn-fuel:client:returnnozzle",
                icon = "fas fa-hand",
                label = Lang:t("return_nozzle"),
                canInteract = function()
                    if IsHoldingElectricNozzle() and not refueling then
                        return true
                    end
                end,
                distance = 2.0
            },
        })
    else
        exports['qb-target']:AddTargetModel(Config.ElectricChargerModel, {
            options = {
                {
                    num = 1,
                    type = "client",
                    event = "cdn-fuel:client:grabelectricnozzle",
                    icon = "fas fa-bolt",
                    label = Lang:t("grab_electric_nozzle"),
                    canInteract = function()
                        if not IsHoldingElectricNozzle() and not IsPedInAnyVehicle(PlayerPedId()) then
                            return true
                        end
                    end
                },
                {
                    num = 2,
                    type = "client",
                    event = "cdn-fuel:client:returnnozzle",
                    icon = "fas fa-hand",
                    label = Lang:t("return_nozzle"),
                    canInteract = function()
                        if IsHoldingElectricNozzle() and not refueling then
                            return true
                        end
                    end
                },
            },
            distance = 2.0
        })
    end
end