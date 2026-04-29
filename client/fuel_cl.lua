-- Variables
local QBCore = exports[Config.Core]:GetCoreObject()
local fuelSynced = false
inGasStation = false
local inBlacklisted = false
local holdingnozzle = false
local Stations = {}
local refueling = false
local GasStationBlips = {} -- Used for managing blips on the client, so labels can be updated.
local RefuelingType = nil
local PlayerInSpecialFuelZone = false
local Rope = nil
local CachedFuelPrice = nil
ReserveLevels = 0
local lastVehicle = nil
local lastBlacklisted = false
local lastVehicleName = ""
local GroundJerryCanObj = nil
local PendingJerryCanData = nil
local PendingRefuelAmount = nil
local PendingFuelPrice = nil

-- Localize Natives
local PlayerPedId = PlayerPedId
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetEntityModel = GetEntityModel
local GetDisplayNameFromVehicleModel = GetDisplayNameFromVehicleModel
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetPedInVehicleSeat = GetPedInVehicleSeat
local IsVehicleEngineOn = IsVehicleEngineOn
local GetVehicleCurrentRpm = GetVehicleCurrentRpm
local GetVehicleClass = GetVehicleClass

-- Debug ---
if Config.FuelDebug then
	RegisterCommand('setfuel', function(source, args)
		if args[1] == nil then print("You forgot to put a fuel level!") return end
		local vehicle = GetClosestVehicle()
		SetFuel(vehicle, tonumber(args[1]))
		QBCore.Functions.Notify(Lang:t("set_fuel_debug")..' '..args[1]..'L', 'success')
	end, false)

	RegisterCommand('getCachedFuelPrice', function()
		print(CachedFuelPrice)
	end, false)

	RegisterCommand('getVehNameForBlacklist', function()
		local veh = GetVehiclePedIsIn(PlayerPedId(), false)
		if veh ~= 0 then
			print(string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh))))
		end
	end, false)
end

RegisterNetEvent('cdn-fuel:client:OpenMappingAdmin', function()
    QBCore.Functions.TriggerCallback('cdn-fuel:server:GetMappingAdminData', function(data)
        SendNUIMessage({
            action = "openMappingAdmin",
            data = data
        })
        SetNuiFocus(true, true)
    end)
end)

RegisterNUICallback('saveMapping', function(data, cb)
    QBCore.Functions.TriggerCallback('cdn-fuel:server:SaveMapping', function(newMappings)
        cb(newMappings)
    end, data)
end)

RegisterNUICallback('deleteMapping', function(data, cb)
    QBCore.Functions.TriggerCallback('cdn-fuel:server:DeleteMapping', function(newMappings)
        cb(newMappings)
    end, data)
end)

RegisterCommand('fueladmin', function()
    TriggerEvent('cdn-fuel:client:OpenMappingAdmin')
end, true) -- true = admin restricted

-- Global Gas Pump Visual Debug
if Config.FuelDebug then
	CreateThread(function()
		while true do
			local sleep = 1500
			local ped = PlayerPedId()
			local coords = GetEntityCoords(ped)
			local pumpCoords, pumpEntity = GetClosestPump(coords)

			if pumpEntity and pumpEntity ~= 0 then
				local dist = #(coords - pumpCoords)
				if dist < 10.0 then
					sleep = 0
					local mHash = GetEntityModel(pumpEntity)
					local rOffset = Config.PumpRopeOffsets["default"]
					local fModel = "default"
					for mName, off in pairs(Config.PumpRopeOffsets) do
						if joaat(mName) == mHash then
							rOffset = off
							fModel = mName
							break
						end
					end

					if fModel ~= "default" then
						local worldCoords = GetOffsetFromEntityInWorldCoords(pumpEntity, rOffset.x, rOffset.y, rOffset.z)
						local debugColor = HexToRGB(Config.DebugColor or "#FF00FF")
						DrawMarker(28, worldCoords.x, worldCoords.y, worldCoords.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, debugColor.r, debugColor.g, debugColor.b, 200, false, false, 2, false, nil, nil, false)
					end
					
					-- Optional: Print only once or every few seconds to not spam F8
					-- print("[CDN-FUEL DEBUG] Looking at Pump Model: "..fModel) 
				end
			end
			Wait(sleep)
		end
	end)
end



local function FetchStationInfo(info)
	if not Config.PlayerOwnedGasStationsEnabled then
        ReserveLevels = 1000
        StationFuelPrice = Config.CostMultiplier
        return
    end
	if Config.FuelDebug then print("Fetching Information for Location #" ..CurrentLocation) end
	QBCore.Functions.TriggerCallback('cdn-fuel:server:fetchinfo', function(result)
		if result then
			for _, v in pairs(result) do
				-- Reserves --
				if info == "all" or info == "reserves" then
					Currentreserveamount = math.floor(v.fuel)
					ReserveLevels = tonumber(Currentreserveamount) or 0
					if Config.FuelDebug then print("Fetched Reserve Levels: "..ReserveLevels.." Liters!") end
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
				-- Balance --
				if info == "all" or info == "balance" then
					StationBalance = v.balance
					if info == "balance" then
						return StationBalance
					end
				end
				----------------
			end
		else
			if Config.FuelDebug then print("Error, fetching information failed.") end
		end


        -- Check shutoff status
        QBCore.Functions.TriggerCallback('cdn-fuel:server:checkshutoff', function(isClosed)
            if isClosed == nil then isClosed = false end
            StationShutoff = isClosed
            if Config.FuelDebug then print("Station Shutoff State: " .. tostring(StationShutoff)) end
        end, CurrentLocation)

	end, CurrentLocation)
end

exports("FetchStationInfo", FetchStationInfo)
exports("FetchCurrentLocation", FetchCurrentLocation)
exports("IsInGasStation", IsInGasStation)

local function HandleFuelConsumption(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))
		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
        local rpm = GetVehicleCurrentRpm(vehicle)
        local fuelUsage = Config.FuelUsage[Round(rpm, 1)] or 1.0
        local classMultiplier = Config.Classes[GetVehicleClass(vehicle)] or 1.0
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - fuelUsage * classMultiplier / 10)
	end
end

-- Wrong Fuel Damage Thread
CreateThread(function()
    while true do
        local wait = 5000
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local isWrongFuel = Entity(vehicle).state.wrong_fuel
            if isWrongFuel then
                wait = Config.WrongFuelDamage.Interval or 5000
                if GetIsVehicleEngineRunning(vehicle) then
                    local currentHealth = GetVehicleEngineHealth(vehicle)
                    if currentHealth > 0 then
                        local damage = math.random(Config.WrongFuelDamage.Min or 5, Config.WrongFuelDamage.Max or 15) / 10.0
                        SetVehicleEngineHealth(vehicle, currentHealth - damage)
                        
                        -- Visual effects (smoke/stalling)
                        if currentHealth < 600 then
                            if math.random(1, 10) > 7 then
                                SetVehicleEngineCanDegrade(vehicle, true)
                            end
                        end

                        if currentHealth < 100 then
                            SetVehicleEngineOn(vehicle, false, true, true)
                            QBCore.Functions.Notify("O motor parou devido ao combustível incorreto!", "error")
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

local function CanAfford(price, purchasetype)
	local purchasetype = purchasetype
	if purchasetype == "bank" then Money = QBCore.Functions.GetPlayerData().money['bank'] elseif purchasetype == 'cash' then Money = QBCore.Functions.GetPlayerData().money['cash'] end
	if Money < price then
		return false
	else
		return true
	end
end

function IsVehicleAllowedForDiscount(vehicle)
    if not Config.EmergencyServicesDiscount['emergency_vehicles_only'] then return true end
    
    local isClass18 = GetVehicleClass(vehicle) == 18
    if isClass18 then return true end

    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))
    
    local allowedVehicles = Config.EmergencyServicesDiscount['vehicles'] or {}
    for _, allowedName in ipairs(allowedVehicles) do
        if string.lower(allowedName) == modelName then
            return true
        end
    end

    return false
end

function FetchCurrentLocation()
	if Config.FuelDebug then print("Fetching Current Location") end
	return CurrentLocation
end

function IsInGasStation()
	return inGasStation
end


-- Thread Stuff --

if Config.LeaveEngineRunning then
	CreateThread(function()
		while true do
			Wait(100)
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, false) and IsControlPressed(2, 75) and not IsEntityDead(ped) then
				local vehicle = GetVehiclePedIsIn(ped, true)
				local enginerunning = GetIsVehicleEngineRunning(vehicle)
				if Config.FuelDebug then if enginerunning then print('Engine is running!') else print('Engine is not running!') end end
				Wait(900)
				if IsPedInAnyVehicle(ped, false) and IsControlPressed(2, 75) and not IsEntityDead(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId()), -1) == PlayerPedId() then
					if enginerunning then SetVehicleEngineOn(vehicle, true, true, false) enginerunning = false end
					TaskLeaveVehicle(ped, veh, keepDooRopen and 256 or 0)
				end
			end
		end
	end)
end

if Config.ShowNearestGasStationOnly then
	RegisterNetEvent('cdn-fuel:client:updatestationlabels', function(location, newLabel)
		if not location then if Config.FuelDebug then print('location is nil') end return end
		if not newLabel then if Config.FuelDebug then print('newLabel is nil') end return end
		if Config.FuelDebug then print("Changing Label for Location #"..location..' to '..newLabel) end
		if Config.GasStations[location] then
			Config.GasStations[location].label = newLabel
		end
	end)

	CreateThread(function()
		if Config.PlayerOwnedGasStationsEnabled then
			TriggerServerEvent('cdn-fuel:server:updatelocationlabels')
		end
		Wait(1000)
		local currentGasBlip = 0
		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords
			local closestLocation
			local location = 0
			local label = "Gas Station" -- Prevent nil just in case, set default name.
			for _, ourCoords in pairs(Config.GasStations) do
				location = location + 1
				if not (location > #Config.GasStations) then -- Make sure we are not going over the amount of locations available.
                    local station = Config.GasStations[location]
					if station and station.pedcoords then
                        local gasStationCoords = vector3(station.pedcoords.x, station.pedcoords.y, station.pedcoords.z)
                        local dstcheck = #(coords - gasStationCoords)
                        if dstcheck < closest then
                            closest = dstcheck
                            closestCoords = gasStationCoords
                            closestLocation = location
                            label = Config.GasStations[closestLocation].label
                        end
                    end
				else
					break
				end
			end
			if closestCoords then
                if DoesBlipExist(currentGasBlip) then
                    RemoveBlip(currentGasBlip)
                end
                currentGasBlip = CreateBlip(closestCoords, label)
            end
			Wait(10000)
		end
	end)
else
	RegisterNetEvent('cdn-fuel:client:updatestationlabels', function(location, newLabel)
		if not location then if Config.FuelDebug then print('location is nil') end return end
		if not newLabel then if Config.FuelDebug then print('newLabel is nil') end return end
		if Config.FuelDebug then print("Changing Label for Location #"..location..' to '..newLabel) end
		Config.GasStations[location].label = newLabel
		local coords = vector3(Config.GasStations[location].pedcoords.x, Config.GasStations[location].pedcoords.y, Config.GasStations[location].pedcoords.z)
		RemoveBlip(GasStationBlips[location])
		GasStationBlips[location] = CreateBlip(coords, Config.GasStations[location].label)
	end)

	CreateThread(function()
		TriggerServerEvent('cdn-fuel:server:updatelocationlabels')
		Wait(1000)
		local gasStationCoords
		for i = 1, #Config.GasStations, 1 do
			local location = i
            local station = Config.GasStations[location]
            if station and station.pedcoords then
                gasStationCoords = vector3(station.pedcoords.x, station.pedcoords.y, station.pedcoords.z)
                GasStationBlips[location] = CreateBlip(gasStationCoords, station.label)
            end
		end
	end)
end

CreateThread(function()
	for station_id = 1, #Config.GasStations, 1 do
        local station = Config.GasStations[station_id]
        if station and station.zones and #station.zones >= 3 then
            Stations[station_id] = PolyZone:Create(station.zones, {
                name = "CDN_FUEL_GAS_STATION_"..station_id,
                minZ = station.minz,
                maxZ = station.maxz,
                debugPoly = Config.PolyDebug
            })
            Stations[station_id]:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    inGasStation = true
                    CurrentLocation = station_id
                    if Config.FuelDebug then print("New Location: "..station_id) end
                    if Config.PlayerOwnedGasStationsEnabled then
                        TriggerEvent('cdn-fuel:stations:updatelocation', station_id)
                    end
                else
                    TriggerEvent('cdn-fuel:stations:updatelocation', nil)
                    inGasStation = false
                end
            end)
        else
            print("[CDN-FUEL] Warning: Station #" .. station_id .. " has invalid zones (missing or < 3 points). PolyZone skipped.")
        end
	end
end)

CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)
	while true do
		local ped = PlayerPedId()
		if IsPedInAnyVehicle(ped, false) then
			local vehicle = GetVehiclePedIsIn(ped, false)
            
            -- Only re-check blacklist if vehicle changed
            if vehicle ~= lastVehicle then
                lastVehicle = vehicle
                local model = GetEntityModel(vehicle)
                lastVehicleName = string.lower(GetDisplayNameFromVehicleModel(model))
                lastBlacklisted = IsVehicleBlacklisted(vehicle, lastVehicleName)
            end

			if not lastBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				HandleFuelConsumption(vehicle)
			end
            Wait(1000)
		else
            lastVehicle = nil
			if fuelSynced then fuelSynced = false end
			if inBlacklisted then inBlacklisted = false end
			Wait(1500) -- Longer wait when not in vehicle
		end
	end
end)

-- Client Events
if Config.RenewedPhonePayment then
	RegisterNetEvent('cdn-fuel:client:phone:PayForFuel', function(amount)
		if Config.PlayerOwnedGasStationsEnabled and RefuelingType ~= 'special' then
			FetchStationInfo("fuelprice")
			Wait(100)
		else
			FuelPrice = Config.CostMultiplier
		end
		if Config.AirAndWaterVehicleFueling['enabled'] then
			local vehClass = GetVehicleClass(vehicle)
			if vehClass == 14 then
				FuelPrice = Config.AirAndWaterVehicleFueling['water_fuel_price']
			elseif vehClass == 15 or vehClass == 16 then
				FuelPrice = Config.AirAndWaterVehicleFueling['air_fuel_price']
			end
		end
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
						CachedFuelPrice = FuelPrice
						FuelPrice = 0
						if Config.FuelDebug then
							print("Your discount for Emergency Services is set @ "..discount.."% so fuel is free!")
						end
					else
						discount = discount / 100
						if Config.FuelDebug then
							print(FuelPrice, FuelPrice*discount)
						end
						CachedFuelPrice = FuelPrice
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
		local success = exports['qb-phone']:PhoneNotification(Lang:t("fuel_phone_header"), Lang:t("phone_notification")..total, 'fas fa-gas-pump', '#9f0e63', "NONE", 'fas fa-check-circle', 'fas fa-times-circle')
		if success then
			if QBCore.Functions.GetPlayerData().money['bank'] <= total then
				QBCore.Functions.Notify(Lang:t("not_enough_money"), "error")
			else
				TriggerServerEvent('cdn-fuel:server:PayForFuel', total, "bank", FuelPrice, true, nil, CurrentLocation)
				RefuelPossible = true
				RefuelPossibleAmount = amount
				RefuelCancelledFuelCost = FuelPrice
				RefuelPurchaseType = "bank"
				RefuelCancelled = false
			end
		end
	end)
end


if Config.Ox.Inventory then
	if LocalPlayer.state['isLoggedIn'] then
		exports.ox_inventory:displayMetadata({
			cdn_fuel = "Fuel",
		})
        -- Send colors on start/restart if player is logged in
        SendNUIMessage({
            action = "setColors",
            data = {
                primary = Config.HexToRGB(Config.Colors.primary),
                hover = Config.HexToRGB(Config.Colors.hover)
            }
        })
	end
	AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
		if GetResourceState('ox_inventory'):match("start") then
			exports.ox_inventory:displayMetadata({
				cdn_fuel = "Fuel",
			})
		end
        -- Send colors on player load
        SendNUIMessage({
            action = "setColors",
            data = {
                primary = Config.HexToRGB(Config.Colors.primary),
                hover = Config.HexToRGB(Config.Colors.hover)
            }
        })
	end)
end

-- Also ensure it sends when the resource starts even if not using Ox Inventory logic above
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    Wait(1000) -- Small wait to ensure NUI is ready
    SendNUIMessage({
        action = "setColors",
        data = {
            primary = Config.HexToRGB(Config.Colors.primary),
            hover = Config.HexToRGB(Config.Colors.hover)
        }
    })
end)

if Config.Ox.Menu then
	RegisterNetEvent('cdn-fuel:client:OpenContextMenu', function(total, fuelamounttotal, purchasetype)
		if Config.FuelDebug then print("OpenContextMenu for OX sent from server.") end
		lib.registerContext({
			id = 'cdnconfirmationmenu',
			title = Lang:t("menu_purchase_station_header_1")..math.ceil(total)..Lang:t("menu_purchase_station_header_2"),
			options = {
				{
					title = Lang:t("menu_purchase_station_confirm_header"),
					description = Lang:t("menu_refuel_accept"),
					icon = "fas fa-check-circle",
					arrow = false, -- puts arrow to the right
					event = 'cdn-fuel:client:RefuelVehicle',
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
		lib.showContext('cdnconfirmationmenu')
	end)
end

RegisterNetEvent('cdn-fuel:client:RefuelMenu', function(type)
	if Config.FuelDebug then print("cdn-fuel:client:refuelmenu") end
	if not type then type = nil end
	if Config.RenewedPhonePayment then
		if not RefuelPossible then
			TriggerEvent('cdn-fuel:client:SendMenuToServer', type)
		else
			if not Cancelledrefuel and not RefuelCancelled then
				if RefuelPossibleAmount then
					local purchasetype = "bank"
					local fuelamounttotal = tonumber(RefuelPossibleAmount)
					TriggerEvent('cdn-fuel:client:RefuelVehicle', purchasetype, fuelamounttotal)
				else
					if Config.FuelDebug then
						print("RefuelMenu: MORE THAN ZERO!")
					end
					QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error', 7500)
				end
			end
		end
	else
		TriggerEvent('cdn-fuel:client:SendMenuToServer', type)
	end
end)

RegisterNetEvent('cdn-fuel:client:grabnozzle', function()
    local function StartGrabbing()
        local ped = PlayerPedId()
        if holdingnozzle then return end
        LoadAnimDict("anim@am_hold_up@male")
        TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
        Wait(300)
        StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)
        fuelnozzle = CreateObject(joaat('prop_cs_fuel_nozle'), 1.0, 1.0, 1.0, true, true, false)
        local lefthand = GetPedBoneIndex(ped, 18905)
        AttachEntityToEntity(fuelnozzle, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)
        local grabbednozzlecoords = GetEntityCoords(ped)
        if Config.PumpHose then
            local pumpCoords, pump = GetClosestPump(grabbednozzlecoords)
            -- Load Rope Textures
            RopeLoadTextures()
            while not RopeAreTexturesLoaded() do
                Wait(0)
                RopeLoadTextures()
            end
            -- Wait for Pump to exist.
            while not pump do
                Wait(0)
            end
            Rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, Config.RopeType['fuel'], 8.0 --[[ DO NOT SET THIS TO 0.0!!! GAME WILL CRASH!]], 0.0, 1.0, false, false, false, 1.0, true)
            while not Rope do
                Wait(0)
            end
            ActivatePhysics(Rope)
            Wait(100)
            local nozzlePos = GetEntityCoords(fuelnozzle)
            if Config.FuelDebug then print("NOZZLE POS ".. nozzlePos) end
            nozzlePos = GetOffsetFromEntityInWorldCoords(fuelnozzle, 0.0, -0.033, -0.195)
            
            -- Per-Model Rope Offset Logic
            local modelHash = GetEntityModel(pump)
            local ropeOffset = Config.PumpRopeOffsets["default"]
            local foundModel = "default"

            -- Check Aviation Offsets First
            for modelName, data in pairs(Config.AviationPumpOffsets) do
                if joaat(modelName) == modelHash then
                    ropeOffset = data.ropeOffset or data.rope
                    foundModel = "aviation:"..modelName
                    break
                end
            end

            -- Check Maritime Platform Offsets
            if joaat(Config.MaritimePlatform.Model) == modelHash then
                local ped = PlayerPedId()
                local pedCoords = GetEntityCoords(ped)
                local closestDist = 1000.0
                
                for _, pumpDef in ipairs(Config.MaritimePlatform.PumpOffsets) do
                    local absPos = GetOffsetFromEntityInWorldCoords(pump, pumpDef.rope.x, pumpDef.rope.y, pumpDef.rope.z)
                    local dist = #(pedCoords - absPos)
                    if dist < closestDist then
                        closestDist = dist
                        ropeOffset = pumpDef.rope
                    end
                end
                foundModel = "boat_platform"
            end

            -- If not an aviation pump, check standard pump offsets
            if foundModel == "default" then
                for modelName, offset in pairs(Config.PumpRopeOffsets) do
                    if joaat(modelName) == modelHash then
                        ropeOffset = offset
                        foundModel = modelName
                        break
                    end
                end
            end

            if Config.FuelDebug then
                print("[CDN-FUEL] Pump Model Hash: "..modelHash.." | Detected Model Name: "..foundModel)
            end

            local PumpHeightAdd = ropeOffset.z
            
            -- Priority: Model-specific Offset wins. Only check station override if using default.
            if Config.GasStations[CurrentLocation] and Config.GasStations[CurrentLocation].pumpheightadd ~= nil then
                if ropeOffset == Config.PumpRopeOffsets["default"] then
                    PumpHeightAdd = Config.GasStations[CurrentLocation].pumpheightadd
                end
            end
            
            local attachCoords = GetOffsetFromEntityInWorldCoords(pump, ropeOffset.x, ropeOffset.y, PumpHeightAdd)
            AttachEntitiesToRope(Rope, pump, fuelnozzle, attachCoords.x, attachCoords.y, attachCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)
            
            if Config.FuelDebug then
                print("Hose Properties:")
                print(Rope, pump, fuelnozzle, attachCoords.x, attachCoords.y, attachCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length)
                SetEntityDrawOutline(fuelnozzle --[[ Entity ]], true --[[ boolean ]])
            end
        end
        holdingnozzle = true
        CreateThread(function()
            while holdingnozzle do
                local currentcoords = GetEntityCoords(ped)
                local dist = #(grabbednozzlecoords - currentcoords)
                if not TargetCreated then if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(true) end end
                TargetCreated = true
                if dist > 7.5 then
                    if TargetCreated then if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(false) end end
                    TargetCreated = true
                    holdingnozzle = false
                    DeleteObject(fuelnozzle)
                    QBCore.Functions.Notify(Lang:t("nozzle_cannot_reach"), 'error')
                    if Config.PumpHose == true then
                        RopeUnloadTextures()
                        DeleteRope(Rope)
                    end
                    if Config.FuelNozzleExplosion then
                        AddExplosion(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z, 'EXP_TAG_PROPANE', 1.0, true,false, 5.0)
                        StartScriptFire(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z - 1,25,false)
                        SetFireSpreadRate(10.0)
                        Wait(5000)
                        StopFireInRange(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z - 1, 3.0)
                    end
                end
                Wait(2500)
            end
        end)
    end

    if Config.PlayerOwnedGasStationsEnabled then
        QBCore.Functions.TriggerCallback('cdn-fuel:server:checkshutoff', function(result)
            if result == true then
                QBCore.Functions.Notify(Lang:t("station_shutoff_active"), 'error', 7500)
                ShutOff = true
                return
            else
                ShutOff = false
                StartGrabbing()
            end
        end, CurrentLocation)
    else
        ShutOff = false
        StartGrabbing()
    end
end)

RegisterNetEvent('cdn-fuel:client:returnnozzle', function()
	if Config.ElectricVehicleCharging then
		if IsHoldingElectricNozzle() then
			SetElectricNozzle("putback")
		else
			holdingnozzle = false
			TargetCreated = false
			TriggerServerEvent("InteractSound_SV:PlayOnSource", "putbacknozzle", 0.4)
			Wait(250)
			if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(false) end
			DeleteObject(fuelnozzle)
		end
	else
		holdingnozzle = false
		TargetCreated = false
		TriggerServerEvent("InteractSound_SV:PlayOnSource", "putbacknozzle", 0.4)
		Wait(250)
		if Config.FuelTargetExport then exports[Config.TargetResource]:AllowRefuel(false) end
		DeleteObject(fuelnozzle)
	end
	if Config.PumpHose then
		if Config.FuelDebug then print("Removing Hose.") end
		RopeUnloadTextures()
		DeleteRope(Rope)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		DeleteObject(fuelnozzle)
		DeleteObject(SpecialFuelNozzleObj)
		if Config.PumpHose then
			RopeUnloadTextures()
			DeleteObject(Rope)
		end
		if Config.TargetResource == 'ox_target' then
			exports.ox_target:removeGlobalVehicle('cdn-fuel:options:1')
			exports.ox_target:removeGlobalVehicle('cdn-fuel:options:2')
		end
		-- Remove Blips from map so they dont double up.
		for i = 1, #GasStationBlips, 1 do
			RemoveBlip(GasStationBlips[i])
		end
	end
end)

RegisterNetEvent('cdn-fuel:client:FinalMenu', function(purchasetype)
	if Config.FuelDebug then
		print('cdn-fuel:client:FinalMenu', purchasetype)
	end
	if RefuelingType == nil then
		FetchStationInfo("all")
		Wait(Config.WaitTime)
		if Config.PlayerOwnedGasStationsEnabled and not Config.UnlimitedFuel then
			if (ReserveLevels or 0) < 1 then
				QBCore.Functions.Notify(Lang:t("station_no_fuel"), 'error', 7500) return
			end
		end
		if Config.PlayerOwnedGasStationsEnabled then
			FuelPrice = (1 * StationFuelPrice)
		end
	end
	local money = nil
	if purchasetype == "bank" then money = QBCore.Functions.GetPlayerData().money['bank'] elseif purchasetype == 'cash' then money = QBCore.Functions.GetPlayerData().money['cash'] end
	if not Config.PlayerOwnedGasStationsEnabled then
		FuelPrice = (1 * Config.CostMultiplier)
	end
	local vehicle = GetClosestVehicle()
	local curfuel = GetFuel(vehicle)
	local finalfuel
	if curfuel < 10 then finalfuel = string.sub(curfuel, 1, 1) else finalfuel = string.sub(curfuel, 1, 2) end
	local maxfuel = (100 - finalfuel - 1)
	if Config.AirAndWaterVehicleFueling['enabled'] or Config.AviationFuelEnabled then
		local vehClass = GetVehicleClass(vehicle)
		if vehClass == 14 then
			FuelPrice = Config.AirAndWaterVehicleFueling['water_fuel_price']
			RefuelingType = 'special'
		elseif vehClass == 15 or vehClass == 16 then
            -- Use Aviation Specific Pricing if enabled
            if Config.AviationFuelEnabled then
                FuelPrice = Config.AviationCostMultiplier
            else
			    FuelPrice = Config.AirAndWaterVehicleFueling['air_fuel_price']
            end
			RefuelingType = 'special'
		end
	end
	-- Police Discount Math --
    local currentTax = Config.GlobalTax
    local activeDiscount = 0
    local vehicle = GetClosestVehicle()
	if Config.EmergencyServicesDiscount['enabled'] == true and IsVehicleAllowedForDiscount(vehicle) then
		local discountedJobs = Config.EmergencyServicesDiscount['job']
		local plyJob = QBCore.Functions.GetPlayerData().job.name
        local onDuty = QBCore.Functions.GetPlayerData().job.onduty
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
			shouldRecieveDiscount = false
		end
		if shouldRecieveDiscount then
            currentTax = 0
			local discount = Config.EmergencyServicesDiscount['discount']
            activeDiscount = discount
			if discount > 100 then
				discount = 100
			else
				if discount <= 0 then discount = 0 end
			end
			if Config.FuelDebug then print("Before we apply the discount the FuelPrice is: $"..FuelPrice) end
			if discount ~= 0 then
				if discount == 100 then
					CachedFuelPrice = FuelPrice
					FuelPrice = 0
					if Config.FuelDebug then
						print("Your discount for Emergency Services is set @ "..discount.."% so fuel is free!")
					end
				else
					discount = discount / 100
					if Config.FuelDebug then
						print("Math( Current Fuel Price: "..FuelPrice.. " - " ..FuelPrice * discount.. "<<-- FuelPrice * Discount)")
					end
					CachedFuelPrice = FuelPrice
					FuelPrice = (FuelPrice) - (FuelPrice*discount)
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
	local wholetankcost = (tonumber(FuelPrice) * maxfuel)
	local wholetankcostwithtax = math.ceil(tonumber(FuelPrice) * maxfuel + GlobalTax(wholetankcost))

    local stationLabel = nil
    local stationObject = nil

    if RefuelingType == 'special' then
        stationLabel = "Veículo de Reabastecimento"
    elseif CurrentLocation and Config.GasStations[CurrentLocation] then
        stationLabel = Config.GasStations[CurrentLocation].label
        stationObject = Config.GasStations[CurrentLocation]
    else
        -- Fallback: Find closest station if CurrentLocation is nil (e.g. Jerry Can purchase edge case)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closestDist = 50.0 -- Max distance to consider being "at" a station
        
        for k, v in pairs(Config.GasStations) do
            local stationCoords = vector3(v.pedcoords.x, v.pedcoords.y, v.pedcoords.z)
            local dist = #(coords - stationCoords)
            if dist < closestDist then
                closestDist = dist
                stationObject = v
            end
        end
        
        if stationObject then
            stationLabel = stationObject.label
        end
    end

    local fuels = {
        { id = 'gasoline', label = 'Gasolina', price = stationObject and stationObject.fuelprice or Config.CostMultiplier, icon = 'local_gas_station', color = '#FFA500', description = 'Combustível padrão para a maioria dos veículos de passeio.' },
        { id = 'diesel', label = 'Diesel', price = stationObject and stationObject.dieselprice or (Config.CostMultiplier * 1.2), icon = 'rv_hookup', color = '#555555', description = 'Ideal para SUVs, caminhões e veículos de carga pesada.' },
        { id = 'ethanol', label = 'Etanol', price = stationObject and stationObject.ethanolprice or (Config.CostMultiplier * 0.8), icon = 'eco', color = '#008000', description = 'Combustível renovável de alto desempenho para carros esportivos.' }
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        data = {
            maxFuel = maxfuel,
            currentFuel = curfuel,
            price = FuelPrice,
            type = 'fuel',
            availableFuels = fuels,
            tax = currentTax,
            discount = activeDiscount,
            stationName = stationLabel,
            logo = stationObject and stationObject.logo
        }
    })

end)

RegisterNetEvent('cdn-fuel:client:SendMenuToServer', function(type)
	local vehicle = GetClosestVehicle()
	local NotElectric = false
	if Config.ElectricVehicleCharging then
		local isElectric = GetCurrentVehicleType(vehicle)
		if isElectric == 'electricvehicle' then
			QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500) return
		end
		NotElectric = true
	else
		NotElectric = true
	end
	Wait(50)
	if NotElectric then
		local CurFuel = GetVehicleFuelLevel(vehicle)
		local playercashamount = QBCore.Functions.GetPlayerData().money['cash']
		if not holdingnozzle and not type == 'special' then return end
		if type == 'special' then
			header = "Veículo de reabastecimento"
			RefuelingType = 'special'
		else
            local vClass = GetVehicleClass(vehicle)
            local isAviationVeh = Config.AviationVehicleClasses[vClass] or false
            local currentStation = Config.GasStations[CurrentLocation]
            
            if currentStation and currentStation.type == 'air' then
                if not isAviationVeh then
                    QBCore.Functions.Notify("Este posto fornece apenas combustível Jet A-1 para aeronaves!", 'error')
                    return
                end
            else
                if isAviationVeh then
                    QBCore.Functions.Notify("Aeronaves não podem ser abastecidas com gasolina comum!", 'error')
                    return
                end
            end

			header = Config.GasStations[CurrentLocation].label
		end
		if CurFuel < 95 then
            TriggerEvent('cdn-fuel:client:FinalMenu', nil)
		else
			QBCore.Functions.Notify(Lang:t("tank_already_full"), 'error')
		end
	else
		QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500)
	end
end)

RegisterNetEvent('cdn-fuel:client:RefuelVehicle', function(data)
    local amount = data.fuelamounttotal
    local fuelType = data.fuelType or "gasoline"
    local purchasetype = data.purchasetype
	if RefuelingType == nil then
		FetchStationInfo("all")
		Wait(100)
	end
	local purchasetype, amount, fuelamount, fuelType
	if not Config.RenewedPhonePayment then
		purchasetype = data.purchasetype
	elseif data.purchasetype == "cash" then
		purchasetype = "cash"
	else
		purchasetype = RefuelPurchaseType
	end
    fuelType = data.fuelType or "gasoline"
	if Config.FuelDebug then print("Tipo de compra: "..purchasetype) end
	if not Config.RenewedPhonePayment then
		amount = data.fuelamounttotal
	elseif data.purchasetype == "cash" then
		amount = data.fuelamounttotal
	elseif not data.fuelamounttotal then
		amount = RefuelPossibleAmount
	end
	if Config.PlayerOwnedGasStationsEnabled and RefuelingType == nil then
		FuelPrice = (1 * StationFuelPrice)
	else
		FuelPrice = (1 * Config.CostMultiplier)
	end
	if not holdingnozzle and RefuelingType == nil and not data.isAirSea then return end
	amount = tonumber(amount)
	if amount < 1 then return end
    
    -- Check if station is closed
    if Config.PlayerOwnedGasStationsEnabled and StationShutoff then
        QBCore.Functions.Notify(Lang:t("station_shutoff_active"), 'error')
        return
    end

	if amount < 10 then fuelamount = string.sub(amount, 1, 1) else fuelamount = string.sub(amount, 1, 2) end
	local vehicle = GetClosestVehicle()
	if Config.AirAndWaterVehicleFueling['enabled'] then
		local vehClass = GetVehicleClass(vehicle)
		if vehClass == 14 then
			FuelPrice = Config.AirAndWaterVehicleFueling['water_fuel_price']
		elseif vehClass == 15 or vehClass == 16 then
			FuelPrice = Config.AirAndWaterVehicleFueling['air_fuel_price']
		end
	end
	-- Police Discount Math --
    local shouldRecieveDiscount = false
	if Config.EmergencyServicesDiscount['enabled'] == true and IsVehicleAllowedForDiscount(vehicle) then
		local discountedJobs = Config.EmergencyServicesDiscount['job']
        local plyData = QBCore.Functions.GetPlayerData()
        local plyJob = plyData.job.name
        local onDuty = plyData.job.onduty
		shouldRecieveDiscount = false
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

		if shouldRecieveDiscount == true and not onDuty and Config.EmergencyServicesDiscount['ondutyonly'] then
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
			if Config.FuelDebug then print("Antes de aplicarmos o desconto, o price de combustível é: R$"..FuelPrice) end
            local currentTax = Config.GlobalTax
			if discount ~= 0 then
				if discount == 100 then
					CachedFuelPrice = FuelPrice
					FuelPrice = 0
                    currentTax = 0
					if Config.FuelDebug then
						print("Seu desconto para serviços de emergência está definido @ |"..discount .."% |Então o combustível é grátis!")
					end
				else
					discount = discount / 100
					if Config.FuelDebug then
						print("Matemática (preço atual do combustível:"..FuelPrice.. " - " ..FuelPrice * discount.. "<<- FuelPrice * desconto)")
					end
                    currentTax = 0
					CachedFuelPrice = FuelPrice
					FuelPrice = FuelPrice - (FuelPrice*discount)

					if Config.FuelDebug then
						print("Seu desconto para serviços de emergência está definido@ "..discount.."%. Definindo novo preço para: $"..FuelPrice)
					end
				end
			else
				if Config.FuelDebug then
					print("Seu desconto para serviços de emergência está definido@ "..discount.."%. Não pode ser 0 ou <0!")
				end
			end
		end
	end
	local refillCost = (amount * FuelPrice) + GlobalTax(amount * FuelPrice)
    if shouldRecieveDiscount then
        local taxAmount = 0 -- Using logic where tax is 0 if discounted
        refillCost = (amount * FuelPrice) + taxAmount
    end

    if not CanAfford(refillCost, purchasetype) then
        if purchasetype == "bank" then
            QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank"), 'error')
        else
            QBCore.Functions.Notify(Lang:t("not_enough_money_in_cash"), 'error')
        end
        return
    end
	local ped = PlayerPedId()
	local time = amount * Config.RefuelTime
	if amount < 10 then time = 10 * Config.RefuelTime end
	local vehicleCoords = GetEntityCoords(vehicle)
	if inGasStation then
		if IsPlayerNearVehicle() then
			RequestAnimDict(Config.RefuelAnimationDictionary)
			while not HasAnimDictLoaded(Config.RefuelAnimationDictionary) do Wait(100) end
			if GetIsVehicleEngineRunning(vehicle) and Config.VehicleBlowUp then
				local Chance = math.random(1, 100)
				if Chance <= Config.BlowUpChance then
					AddExplosion(vehicleCoords, 5, 50.0, true, false, true)
					return
				end
			end
			if Config.FaceTowardsVehicle and RefuelingType ~= 'special' then
				local bootBoneIndex = GetEntityBoneIndexByName(vehicle --[[ Entity ]], 'boot' --[[ string ]])
				local vehBootCoords = GetWorldPositionOfEntityBone(vehicle --[[ Entity ]],  joaat(bootBoneIndex)--[[ integer ]])
				if Config.FuelDebug then
					print("Vehicle Boot Bone Coords: "..vehBootCoords.x, vehBootCoords.y, vehBootCoords.z)
				end
				TaskTurnPedToFaceCoord(PlayerPedId(), vehBootCoords, 500)
				Wait(500)
			end
			TaskPlayAnim(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
			refueling = true
			Refuelamount = 0
			-- Start Refuel Loop
			CreateThread(function()
				while refueling do
					if Refuelamount == nil then Refuelamount = 0 end
					Wait(Config.RefuelTime)
					Refuelamount = Refuelamount + 1
					if Cancelledrefuel then
						local finalrefuelamount = math.floor(Refuelamount)
						local refillCost = (finalrefuelamount * FuelPrice) + GlobalTax(finalrefuelamount * FuelPrice)
                        if shouldRecieveDiscount then
                            local taxLoop = 0
                            refillCost = (finalrefuelamount * FuelPrice) + taxLoop
                        end
						if Config.RenewedPhonePayment and purchasetype == "bank" then
							local remainingamount = (amount - Refuelamount)
							MoneyToGiveBack = (GlobalTax(remainingamount * RefuelCancelledFuelCost) + (remainingamount * RefuelCancelledFuelCost))
							TriggerServerEvent("cdn-fuel:server:phone:givebackmoney", MoneyToGiveBack)
							CachedFuelPrice = nil
						else
							TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, false, CachedFuelPrice, CurrentLocation, finalrefuelamount, fuelType)
							CachedFuelPrice = nil
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
							RefuelCancelledFuelCost = 0
						end
						Cancelledrefuel = false
					end
				end
			end)

            local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):upper()
            QBCore.Functions.TriggerCallback('cdn-fuel:server:GetVehicleFuelType', function(requiredFuel)
                if requiredFuel ~= fuelType then
                    if Config.FuelDebug then print("[DEBUG] WRONG FUEL DETECTED! Required: " .. tostring(requiredFuel) .. " | Used: " .. tostring(fuelType)) end
                    QBCore.Functions.Notify("AVISO: Você está colocando o combustível errado! Isso causará danos ao motor.", "error", 10000)
                    Entity(vehicle).state:set('wrong_fuel', true, true)
                end
            end, modelName, GetVehicleClass(vehicle))
			-- TriggerServerEvent("InteractSound_SV:PlayOnSource", "refuel", 0.3)
			if Config.Ox.Progress then
				if lib.progressCircle({
					duration = time,
					label = Lang:t("prog_refueling_vehicle"),
					position = 'bottom',
					useWhileDead = false,
					canCancel = true,
					disable = {
						move = true,
						combat = true
					},
				}) then
					refueling = false
					if purchasetype == "cash" then
						TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, false, CachedFuelPrice, CurrentLocation, amount, fuelType)
					elseif purchasetype == "bank" then
						if not Config.RenewedPhonePayment then
							TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, false, CachedFuelPrice, CurrentLocation, amount, fuelType)
						end
					end
					local curfuel = GetFuel(vehicle)
					local finalfuel = (curfuel + amount)
					if finalfuel > 99 and finalfuel < 100 then
						SetFuel(vehicle, 100)
					else
						SetFuel(vehicle, finalfuel)
					end
					StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
					TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)
					if Config.RenewedPhonePayment then
						RefuelPossible = false
						RefuelPossibleAmount = 0
						RefuelPurchaseType = "bank"
					end
				else
					refueling = false
					Cancelledrefuel = true
					StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
					TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)
				end
			else
				QBCore.Functions.Progressbar("refuel-car", Lang:t("prog_refueling_vehicle"), time, false, true, {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = true,
				}, {}, {}, {}, function()
					refueling = false
					if not Config.RenewedPhonePayment or purchasetype == "cash" then
						TriggerServerEvent('cdn-fuel:server:PayForFuel', refillCost, purchasetype, FuelPrice, false, CachedFuelPrice, CurrentLocation, amount, fuelType)
					end
					local curfuel = GetFuel(vehicle)
					local finalfuel = (curfuel + amount)
					if finalfuel > 99 and finalfuel < 100 then
						SetFuel(vehicle, 100)
					else
						SetFuel(vehicle, finalfuel)
					end
					StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
					TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)
					if Config.RenewedPhonePayment then
						RefuelPossible = false
						RefuelPossibleAmount = 0
						RefuelPurchaseType = "bank"
					end
				end, function()
					refueling = false
					Cancelledrefuel = true
					StopAnimTask(ped, Config.RefuelAnimationDictionary, Config.RefuelAnimation, 3.0, 3.0, -1, 2, 0, 0, 0, 0)
					TriggerServerEvent("InteractSound_SV:PlayOnSource", "fuelstop", 0.4)
				end, "fas fa-gas-pump")
			end
		end
	else
		return
	end
end)

-- Jerry Can --
RegisterNetEvent('cdn-fuel:jerrycan:refuelmenu', function(itemData)
	if IsPedInAnyVehicle(PlayerPedId(), false) then QBCore.Functions.Notify(Lang:t("cannot_refuel_inside"), 'error') return end
	if Config.FuelDebug then print("Item Data: " .. json.encode(itemData)) end
	local vehicle = GetClosestVehicle()
	local vehiclecoords = GetEntityCoords(vehicle)
	local pedcoords = GetEntityCoords(PlayerPedId())
	if GetVehicleBodyHealth(vehicle) < 100 then QBCore.Functions.Notify(Lang:t("vehicle_is_damaged"), 'error') return end

	local class = GetVehicleClass(vehicle)
	local isAviationVeh = Config.AviationVehicleClasses[class] or false
	local fuelType = 'gasoline'
    if Config.Ox.Inventory then
        fuelType = itemData.metadata.fuel_type or 'gasoline'
    else
        fuelType = itemData.info.fuel_type or 'gasoline'
    end
    local isAviationCan = (fuelType == 'aviation')

	if isAviationVeh and not isAviationCan then
		QBCore.Functions.Notify("Aeronaves precisam de combustível especial (Jet A-1)!", "error")
		return
	end
	if not isAviationVeh and isAviationCan then
		QBCore.Functions.Notify("Esse combustível de aviação vai destruir o motor deste veículo!", "error")
		return
	end

	local jerrycanamount
	if Config.Ox.Inventory then
		jerrycanamount = tonumber(itemData.metadata._fuel)
	else
		jerrycanamount = itemData.info.gasamount
	end
	
    if holdingnozzle then
        QBCore.Functions.Notify("Use a interação na bomba de combustível para reabastecer seus galões!", "info")
        return
    end

    -- Not holding nozzle - Check for vehicle refuel intent
    if #(vehiclecoords - pedcoords) > 2.5 then return end
    
    if jerrycanamount < 1 then 
        QBCore.Functions.Notify(Lang:t("menu_jerry_can_footer_no_gas"), 'error') 
        return 
    end
    
    -- Direct Trigger to NUI event
    TriggerEvent('cdn-fuel:jerrycan:refuelvehicle', {itemData = itemData})
end)
local pendingJerryCanIsAviation = false

RegisterNetEvent('cdn-fuel:client:jerrycanfinalmenu', function(purchasetype, amount, fuelType)
	Moneyamount = nil
	if purchasetype == 'bank' then
		Moneyamount = QBCore.Functions.GetPlayerData().money['bank']
	elseif purchasetype == 'cash' then
		Moneyamount = QBCore.Functions.GetPlayerData().money['cash']
	end
    
    local isAviation = pendingJerryCanIsAviation or false
    local basePrice = isAviation and Config.AviationJerryCanPrice or Config.JerryCanPrice
    local cost = (basePrice + GlobalTax(basePrice)) * (amount or 1)

    if Config.FuelDebug then print(string.format("[DEBUG] JerryCan Final Menu: Type=%s, Amount=%s, FuelType=%s, Location=%s, Cost=%s", purchasetype, amount, fuelType, CurrentLocation, cost)) end
    
    if Moneyamount >= math.ceil(cost) then
		TriggerServerEvent('cdn-fuel:server:purchase:jerrycan', purchasetype, amount, CurrentLocation, isAviation, fuelType)
	else
		if purchasetype == 'bank' then QBCore.Functions.Notify(Lang:t("not_enough_money_in_bank"), 'error') end
		if purchasetype == "cash" then QBCore.Functions.Notify(Lang:t("not_enough_money_in_cash"), 'error') end
	end
end)

RegisterNetEvent('cdn-fuel:client:purchasejerrycan', function()
    local totalCost = math.ceil(Config.JerryCanPrice + GlobalTax(Config.JerryCanPrice))
    
    local stationLabel = nil
    local stationObject = nil

    if CurrentLocation and Config.GasStations[CurrentLocation] then
        stationLabel = Config.GasStations[CurrentLocation].label
        stationObject = Config.GasStations[CurrentLocation]
    else
        -- Fallback: Find closest station by checking pumps or zone center
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closestDist = 100.0 -- Increased range for safety
        
        for k, v in pairs(Config.GasStations) do
            local stationCoords = nil
            
            -- Try to use the closest fuel pump
            if v.fuelpumpcoords and #v.fuelpumpcoords > 0 then
                for _, pump in ipairs(v.fuelpumpcoords) do
                    local pCoords = vector3(pump.x, pump.y, pump.z)
                    local dist = #(coords - pCoords)
                    if dist < closestDist then
                        closestDist = dist
                        stationObject = v
                    end
                end
            elseif v.pedcoords then
                -- Fallback to ped coords
                stationCoords = vector3(v.pedcoords.x, v.pedcoords.y, v.pedcoords.z)
                local dist = #(coords - stationCoords)
                if dist < closestDist then
                    closestDist = dist
                    stationObject = v
                end
            elseif v.zones and #v.zones > 0 then
                -- Fallback to first zone point
                stationCoords = vector3(v.zones[1].x, v.zones[1].y, coords.z)
                local dist = #(coords - stationCoords)
                if dist < closestDist then
                    closestDist = dist
                    stationObject = v
                end
            end
        end
        
        if stationObject then
            stationLabel = stationObject.label
        end
    end

    pendingJerryCanIsAviation = (stationObject and stationObject.type == 'air')
    local basePrice = pendingJerryCanIsAviation and Config.AviationJerryCanPrice or Config.JerryCanPrice

    local fuels = {
        { id = 'gasoline', label = 'Gasolina', price = stationObject and stationObject.fuelprice or Config.CostMultiplier, icon = 'local_gas_station', color = '#FFA500', description = 'Combustível padrão para a maioria dos veículos de passeio.' },
        { id = 'diesel', label = 'Diesel', price = stationObject and stationObject.dieselprice or (Config.CostMultiplier * 1.2), icon = 'rv_hookup', color = '#555555', description = 'Ideal para SUVs, caminhões e veículos de carga pesada.' },
        { id = 'ethanol', label = 'Etanol', price = stationObject and stationObject.ethanolprice or (Config.CostMultiplier * 0.8), icon = 'eco', color = '#008000', description = 'Combustível renovável de alto desempenho para carros esportivos.' }
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        data = {
            maxFuel = 1, -- Unused for jerry can but kept for structure
            currentFuel = 0,
            price = basePrice,
            type = 'jerrycan',
            availableFuels = fuels,
            tax = Config.GlobalTax,
            stationName = stationLabel,
            logo = stationObject and stationObject.logo
        }
    })
end)

RegisterNetEvent('cdn-fuel:jerrycan:refuelvehicle', function(data)
	local ped = PlayerPedId()
	local vehicle = GetClosestVehicle()
	local vehfuel = math.floor(GetFuel(vehicle))
	local maxvehrefuel = (100 - math.ceil(vehfuel))
	local itemData = data.itemData
	local jerrycanfuelamount
	if Config.Ox.Inventory then
		jerrycanfuelamount = tonumber(itemData.metadata._fuel)
	else
		jerrycanfuelamount = itemData.info.gasamount
	end
	
	local NotElectric = false
	if Config.ElectricVehicleCharging then
		local isElectric = GetCurrentVehicleType(vehicle)
		if isElectric == 'electricvehicle' then
			QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500) return
		end
		NotElectric = true
	else
		NotElectric = true
	end
	Wait(50)
	local itemCap = isAviationCan and Config.AviationJerryCanCap or Config.JerryCanCap

	if NotElectric then
		if maxvehrefuel < itemCap then
			maxvehrefuel = maxvehrefuel
		else
			maxvehrefuel = itemCap
		end
		if maxvehrefuel >= jerrycanfuelamount then maxvehrefuel = jerrycanfuelamount elseif maxvehrefuel < jerrycanfuelamount then maxvehrefuel = maxvehrefuel end
		
        -- NUI Logic or Processing
        local refuelAmount = nil
        
        if data.amount then
            refuelAmount = tonumber(data.amount)
        else
            -- Open NUI
            SendNUIMessage({
                action = "open",
                data = {
                    type = "jerrycanRefuel",
                    currentFuel = vehfuel,
                    maxFuel = 100,
                    price = 0,
                    jerryCanData = {
                        fuel = jerrycanfuelamount,
                        cap = itemCap,
                        itemData = itemData
                    }
                }
            })
            SetNuiFocus(true, true)
            return
        end

        if refuelAmount then
            if tonumber(refuelAmount) == 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuelAmount) < 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return end
            if tonumber(refuelAmount) > jerrycanfuelamount then QBCore.Functions.Notify(Lang:t("jerry_can_not_enough_fuel"), 'error') return end
            
            local refueltimer = Config.RefuelTime * tonumber(refuelAmount)
            if tonumber(refuelAmount) < 10 then refueltimer = Config.RefuelTime * 10 end
            if vehfuel + tonumber(refuelAmount) > 100 then QBCore.Functions.Notify(Lang:t("tank_cannot_fit"), 'error') return end
            
            local refuelAmount = tonumber(refuelAmount)
            JerrycanProp = CreateObject(joaat('w_am_jerrycan'), 1.0, 1.0, 1.0, true, true, false)
            local lefthand = GetPedBoneIndex(ped, 18905)
            AttachEntityToEntity(JerrycanProp, ped, lefthand, 0.11 --[[Left - Right (Kind of)]] , 0.0 --[[Up - Down]], 0.25 --[[Forward - Backward]], 15.0, 170.0, 90.42, 0, 1, 0, 1, 0, 1)
            
            local function OnFinish()
                DeleteObject(JerrycanProp)
                StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
                QBCore.Functions.Notify(Lang:t("jerry_can_success_vehicle"), 'success')
                local JerryCanItemData = data.itemData
                local srcPlayerData = QBCore.Functions.GetPlayerData()
                TriggerServerEvent('cdn-fuel:info', "remove", tonumber(refuelAmount), srcPlayerData, JerryCanItemData)
                SetFuel(vehicle, (vehfuel + refuelAmount))
            end

            local function OnCancel()
                DeleteObject(JerrycanProp)
                StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
                QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
            end

            if Config.Ox.Progress then
                if lib.progressCircle({
                    duration = refueltimer,
                    label = Lang:t("prog_refueling_vehicle"),
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { car = true, move = true, combat = true },
                    anim = { dict = Config.JerryCanAnimDict, clip = Config.JerryCanAnim },
                }) then
                    OnFinish()
                else
                    OnCancel()
                end
            else
                QBCore.Functions.Progressbar('refuel_gas', Lang:t("prog_refueling_vehicle"), refueltimer, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = Config.JerryCanAnimDict,
                    anim = Config.JerryCanAnim,
                    flags = 17,
                }, {}, {}, OnFinish, OnCancel, "jerrycan")
            end
        end
	else
		QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500) return
	end
end)

RegisterNetEvent('cdn-fuel:client:jerrycan:refillmenu', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local isAviationStation = false
    local stationLabel = nil
    local stationObject = nil

    if CurrentLocation and Config.GasStations[CurrentLocation] then
        stationLabel = Config.GasStations[CurrentLocation].label
        stationObject = Config.GasStations[CurrentLocation]
    else
        local closestDist = 100.0
        for k, v in pairs(Config.GasStations) do
            local stationCoords = nil
            if v.fuelpumpcoords and #v.fuelpumpcoords > 0 then
                for _, pump in ipairs(v.fuelpumpcoords) do
                    local pCoords = vector3(pump.x, pump.y, pump.z)
                    local dist = #(coords - pCoords)
                    if dist < closestDist then
                        closestDist = dist
                        stationObject = v
                    end
                end
            elseif v.pedcoords then
                stationCoords = vector3(v.pedcoords.x, v.pedcoords.y, v.pedcoords.z)
                local dist = #(coords - stationCoords)
                if dist < closestDist then
                    closestDist = dist
                    stationObject = v
                end
            elseif v.zones and #v.zones > 0 then
                stationCoords = vector3(v.zones[1].x, v.zones[1].y, coords.z)
                local dist = #(coords - stationCoords)
                if dist < closestDist then
                    closestDist = dist
                    stationObject = v
                end
            end
        end
    end

    isAviationStation = (stationObject and stationObject.type == 'air')
    local allowedCap = isAviationStation and Config.AviationJerryCanCap or Config.JerryCanCap

    local jerryCans = {}
    if Config.Ox.Inventory then
        local items = exports.ox_inventory:Search('slots', 'jerrycan')
        if items then
            for _, item in pairs(items) do
                local fuelAmount = tonumber(item.metadata._fuel) or 0
                local fuelType = item.metadata.fuel_type or 'gasoline'
                
                -- Se estiver vazio, pode abastecer em qualquer lugar. 
                -- Se tiver combustível, deve bater com o tipo do posto.
                if fuelAmount == 0 or (isAviationStation and fuelType == 'aviation') or (not isAviationStation and fuelType == 'gasoline') then
                    table.insert(jerryCans, {
                        fuel = fuelAmount,
                        cap = allowedCap,
                        itemData = item,
                        name = item.label or (isAviationStation and "Galão de Aviação" or "Galão de Combustível")
                    })
                end
            end
        end
    else
        local items = QBCore.Functions.GetPlayerData().items
        if items then
            for slot, item in pairs(items) do
                if item.name == 'jerrycan' then
                    local fuelAmount = tonumber(item.info.gasamount) or 0
                    local fuelType = item.info.fuel_type or 'gasoline'

                    if fuelAmount == 0 or (isAviationStation and fuelType == 'aviation') or (not isAviationStation and fuelType == 'gasoline') then
                        table.insert(jerryCans, {
                            fuel = fuelAmount,
                            cap = allowedCap,
                            itemData = item,
                            name = item.label or (isAviationStation and "Galão de Aviação" or "Galão de Combustível")
                        })
                    end
                end
            end
        end
    end

    if #jerryCans == 0 then
        QBCore.Functions.Notify("Você não tem nenhum galão!", "error")
        return
    end

    -- Update FuelPrice if owned
    if Config.PlayerOwnedGasStationsEnabled then
        FetchStationInfo("fuelprice")
        Wait(100)
    else
        FuelPrice = Config.CostMultiplier
    end

    local stationObject = Config.GasStations[CurrentLocation]
    local fuels = {
        { id = 'gasoline', label = 'Gasolina', price = stationObject and stationObject.fuelprice or Config.CostMultiplier, icon = 'local_gas_station', color = '#FFA500', description = 'Combustível padrão para a maioria dos veículos de passeio.' },
        { id = 'diesel', label = 'Diesel', price = stationObject and stationObject.dieselprice or (Config.CostMultiplier * 1.2), icon = 'rv_hookup', color = '#555555', description = 'Ideal para SUVs, caminhões e veículos de carga pesada.' },
        { id = 'ethanol', label = 'Etanol', price = stationObject and stationObject.ethanolprice or (Config.CostMultiplier * 0.8), icon = 'eco', color = '#008000', description = 'Combustível renovável de alto desempenho para carros esportivos.' }
    }

    SendNUIMessage({
        action = "open",
        data = {
            type = "jerrycanRefill",
            jerryCans = jerryCans,
            availableFuels = fuels,
            currentFuel = jerryCans[1].fuel, -- For initial UI state
            maxFuel = jerryCans[1].cap - jerryCans[1].fuel,
            price = FuelPrice,
            tax = Config.GlobalTax,
            stationName = Config.GasStations[CurrentLocation].label,
            logo = stationObject and stationObject.logo
        }
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('cdn-fuel:jerrycan:refueljerrycan', function(data)
	FetchStationInfo('all')
	Wait(100)
	if Config.PlayerOwnedGasStationsEnabled then
		FuelPrice = (1 * StationFuelPrice)
	else
		FuelPrice = (1 * Config.CostMultiplier)
	end
	local itemData = data.itemData
	if not itemData then
		if Config.FuelDebug then print("[DEBUG] refueljerrycan triggered with nil itemData") end
		return 
	end
	local jerrycanfuelamount
	if Config.Ox.Inventory then
		jerrycanfuelamount = tonumber(itemData.metadata._fuel)
	else
		jerrycanfuelamount = itemData.info.gasamount
	end

	local ped = PlayerPedId()

    local fuelType = 'gasoline'
    if Config.Ox.Inventory then
        fuelType = data.itemData.metadata.fuel_type or 'gasoline'
    else
        fuelType = data.itemData.info.fuel_type or 'gasoline'
    end
    local itemCap = (fuelType == 'aviation') and Config.AviationJerryCanCap or Config.JerryCanCap

    if jerrycanfuelamount == itemCap then QBCore.Functions.Notify(Lang:t("jerry_can_is_full"), 'error') return end
    
    local refuelAmount = data.amount
	if not refuelAmount then
        if Config.Ox.Input then
            local JerryCanMaxRefuel = (itemCap - jerrycanfuelamount)
            local refuel = lib.inputDialog(Lang:t("input_select_refuel_header"), {Lang:t("input_max_fuel_footer_1") .. JerryCanMaxRefuel .. Lang:t("input_max_fuel_footer_2")})
            if not refuel then return end
            refuelAmount = tonumber(refuel[1])
        else
            local JerryCanMaxRefuel = (itemCap - jerrycanfuelamount)
            local refuel = exports['qb-input']:ShowInput({
                header = Lang:t("input_select_refuel_header"),
                submitText = Lang:t("input_refuel_jerrycan_submit"),
                inputs = { {
                    type = 'number',
                    isRequired = true,
                    name = 'amount',
                    text = Lang:t("input_max_fuel_footer_1") .. JerryCanMaxRefuel .. Lang:t("input_max_fuel_footer_2")
                } }
            })
            if not refuel then return end
            refuelAmount = tonumber(refuel.amount)
        end
    end

    if refuelAmount then
        if tonumber(refuelAmount) == 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuelAmount) < 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return end
        if tonumber(refuelAmount) + tonumber(jerrycanfuelamount) > itemCap then QBCore.Functions.Notify(Lang:t("jerry_can_not_fit_fuel"), 'error') return end
        if tonumber(refuelAmount) > itemCap then QBCore.Functions.Notify(Lang:t("jerry_can_not_fit_fuel"), 'error') return end
        
        local price = (tonumber(refuelAmount) * FuelPrice) + GlobalTax(tonumber(refuelAmount) * FuelPrice)
        if not CanAfford(price, "cash") then QBCore.Functions.Notify(Lang:t("not_enough_money_in_cash"), 'error') return end

        -- Save Pending Data
        PendingJerryCanData = itemData
        PendingRefuelAmount = tonumber(refuelAmount)
        PendingFuelPrice = FuelPrice
        PendingFuelType = data.fuelType or 'gasoline'

        -- IMMERSIVE PART: Spawn on Ground
        if GroundJerryCanObj then DeleteObject(GroundJerryCanObj) end
        
        local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, -1.0)
        local model = joaat('prop_jerrycan_01a')
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        
        GroundJerryCanObj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
        PlaceObjectOnGroundProperly(GroundJerryCanObj)
        FreezeEntityPosition(GroundJerryCanObj, true)
        SetEntityAsMissionEntity(GroundJerryCanObj, true, true)

        QBCore.Functions.Notify("Galão colocado no chão. Pegue a mangueira e conecte para abastecer!", "info")

        -- Target for Ground Can
        if Config.Ox.Target then
            exports.ox_target:addLocalEntity(GroundJerryCanObj, {
                {
                    name = 'refill_ground_can',
                    label = 'Abastecer Galão',
                    icon = 'fas fa-gas-pump',
                    canInteract = function()
                        return holdingnozzle
                    end,
                    onSelect = function()
                        TriggerEvent('cdn-fuel:client:startGroundRefill')
                    end
                },
                {
                    name = 'pickup_ground_can',
                    label = 'Pegar Galão',
                    icon = 'fas fa-hand-holding',
                    onSelect = function()
                        DeleteObject(GroundJerryCanObj)
                        GroundJerryCanObj = nil
                        QBCore.Functions.Notify("Galão recolhido.", "info")
                    end
                }
            })
        else
            exports['qb-target']:AddTargetEntity(GroundJerryCanObj, {
                options = {
                    {
                        icon = "fas fa-gas-pump",
                        label = "Abastecer Galão",
                        action = function()
                            TriggerEvent('cdn-fuel:client:startGroundRefill')
                        end,
                        canInteract = function()
                            return holdingnozzle
                        end,
                    },
                    {
                        icon = "fas fa-hand-holding",
                        label = "Pegar Galão",
                        action = function()
                            DeleteObject(GroundJerryCanObj)
                            GroundJerryCanObj = nil
                            QBCore.Functions.Notify("Galão recolhido.", "info")
                        end,
                    },
                },
                distance = 2.0
            })
        end
    end
end)

RegisterNetEvent('cdn-fuel:client:startGroundRefill', function()
    local ped = PlayerPedId()
    if not GroundJerryCanObj or not PendingJerryCanData then return end
    
    local refueltimer = Config.RefuelTime * PendingRefuelAmount
    if PendingRefuelAmount < 10 then refueltimer = Config.RefuelTime * 10 end

    -- Animation: Bending down to the can
    TaskTurnPedToFaceEntity(ped, GroundJerryCanObj, 1000)
    Wait(1000)
    
    local finished = false
    if Config.Ox.Progress then
        finished = lib.progressCircle({
            duration = refueltimer,
            label = Lang:t("prog_jerry_can_refuel"),
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = "amb@world_human_gardener_plant@male@base",
                clip = "base"
            },
        })
    else
        QBCore.Functions.Progressbar('refuel_ground_can', Lang:t("prog_jerry_can_refuel"), refueltimer, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "amb@world_human_gardener_plant@male@base",
            anim = "base",
            flags = 1,
        }, {}, {}, function() -- Done
            finished = true
        end, function() -- Cancel
            finished = false
        end)
        
        local timer = 0
        while finished == false and timer < refueltimer + 1000 do
            Wait(100)
            timer = timer + 100
        end
    end

    if finished then
        QBCore.Functions.Notify(Lang:t("jerry_can_success"), 'success')
        local srcPlayerData = QBCore.Functions.GetPlayerData()
        local fuelType = PendingFuelType or 'gasoline'
        TriggerServerEvent('cdn-fuel:info', "add", PendingRefuelAmount, srcPlayerData, PendingJerryCanData, fuelType)

        local total = (PendingRefuelAmount * PendingFuelPrice) + GlobalTax(PendingRefuelAmount * PendingFuelPrice)
        TriggerServerEvent('cdn-fuel:server:PayForFuel', total, "cash", PendingFuelPrice, false, nil, CurrentLocation, PendingRefuelAmount, fuelType)
        
        -- Cleanup
        DeleteObject(GroundJerryCanObj)
        GroundJerryCanObj = nil
        PendingJerryCanData = nil
        PendingRefuelAmount = nil
        StopAnimTask(ped, "amb@world_human_gardener_plant@male@base", "base", 1.0)
    else
        QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
        StopAnimTask(ped, "amb@world_human_gardener_plant@male@base", "base", 1.0)
    end
end)

--- Syphoning ---
local function PoliceAlert(coords)
	local chance = math.random(1, 100)
	if chance < Config.SyphonPoliceCallChance then
		if Config.SyphonDispatchSystem == "ps-dispatch" then
			exports['ps-dispatch']:SuspiciousActivity()
		elseif Config.SyphonDispatchSystem == "qb-dispatch" then
			TriggerServerEvent('qb-dispatch:911call', coords)
		elseif Config.SyphonDispatchSystem == "qb-default" then
			TriggerServerEvent('cdn-syphoning:callcops', coords)
		elseif Config.SyphonDispatchSystem == "custom" then
			-- Put your own dispatch system here
		else
			if Config.SyphonDebug then print("There was an attempt to call police but this dispatch system is not supported!") end
		end
	end
end

-- Events --
RegisterNetEvent('cdn-syphoning:syphon:menu', function(itemData)
	if IsPedInAnyVehicle(PlayerPedId(), false) then QBCore.Functions.Notify(Lang:t("syphon_inside_vehicle"), 'error') return end
	if Config.SyphonDebug then print("Item Data: " .. json.encode(itemData)) end
	local vehicle = GetClosestVehicle()
	local vehModel = GetEntityModel(vehicle)
	local vehiclename = string.lower(GetDisplayNameFromVehicleModel(vehModel))
	local vehiclecoords = GetEntityCoords(vehicle)
	local pedcoords = GetEntityCoords(PlayerPedId())
	if Config.ElectricVehicleCharging then
		NotElectric = true
		if Config.ElectricVehicles[vehiclename] and Config.ElectricVehicles[vehiclename].isElectric then
			NotElectric = false
			if Config.SyphonDebug then print("^2"..current.. "^5 has been found. It ^2matches ^5the Player's Vehicle: ^2"..vehiclename..". ^5This means syphoning will not be allowed.") end
			QBCore.Functions.Notify(Lang:t("syphon_electric_vehicle"), 'error', 7500) return
		end
	else
		NotElectric = true
	end
	if NotElectric then
		if #(vehiclecoords - pedcoords) > 2.5 then return end
		if GetVehicleBodyHealth(vehicle) < 100 then QBCore.Functions.Notify(Lang:t("vehicle_is_damaged"), 'error') return end
		
        -- NUI Logic
        local currentFuel = GetFuel(vehicle)
        local kitFuel = 0
        if Config.Ox.Inventory then
            kitFuel = tonumber(itemData.metadata._fuel) or 0
        else
            kitFuel = itemData.info.gasamount or 0
        end

        SendNUIMessage({
            action = "open",
            data = {
				type = "syphon",
                currentFuel = currentFuel, -- Vehicle Fuel
				maxFuel = 100, -- Vehicle Max Fuel (Usually 100)
                price = 0, -- No price for siphoning intent
				syphonData = {
					kitFuel = kitFuel,
					kitCap = Config.SyphonKitCap,
                    itemData = itemData
				}
            }
        })
        SetNuiFocus(true, true)
	end
end)

RegisterNetEvent('cdn-syphoning:syphon', function(data)
	local reason = data.reason
	local ped = PlayerPedId()
	if Config.SyphonDebug then print('Item Data Syphon: ' .. json.encode(data.itemData)) end
	if Config.SyphonDebug then print('Reason: ' .. reason) end
	local vehicle = GetClosestVehicle()
	local NotElectric = false
	if Config.ElectricVehicleCharging then
		local isElectric = GetCurrentVehicleType(vehicle)
		if isElectric == 'electricvehicle' then
			QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500) return
		end
		NotElectric = true
	else
		NotElectric = true
	end
	Wait(50)
	if NotElectric then
		local currentsyphonamount = nil

		if Config.Ox.Inventory then
			currentsyphonamount = tonumber(data.itemData.metadata._fuel)
			HasSyphon = exports.ox_inventory:Search('count', 'syphoningkit')
		else
			currentsyphonamount = data.itemData.info.gasamount or 0
			HasSyphon = QBCore.Functions.HasItem("syphoningkit", 1)
		end

		if HasSyphon then
			local fitamount = (Config.SyphonKitCap - currentsyphonamount)
			local vehicle = GetClosestVehicle()
			local vehiclecoords = GetEntityCoords(vehicle)
			local pedcoords = GetEntityCoords(ped)
			if #(vehiclecoords - pedcoords) > 2.5 then return end
			local cargasamount = GetFuel(vehicle)
			local maxsyphon = math.floor(GetFuel(vehicle))
			if Config.SyphonKitCap <= 100 then
				if maxsyphon > Config.SyphonKitCap then
					maxsyphon = Config.SyphonKitCap
				end
			end
			if maxsyphon >= fitamount then
				Stealstring = fitamount
			else
				Stealstring = maxsyphon
			end
			if reason == "syphon" then
                local syphonAmount = nil
                local syphon = nil

                if data.amount then
                    syphonAmount = tonumber(data.amount)
                    syphon = true -- Skip input
                else
                    if Config.Ox.Input then
                        syphon = lib.inputDialog('Begin Syphoning', {{ type = "number", label = "You can steal " .. Stealstring .. "L from the car.", default = Stealstring }})
                        if not syphon then return end
                        syphonAmount = tonumber(syphon[1])
                    else
                        local dialog = exports['qb-input']:ShowInput({
                            header = Lang:t("menu_syphon_header"),
                            submitText = "Confirm",
                            inputs = {
                                {
                                    text = "Amount ("..Stealstring.."L)",
                                    name = "amt",
                                    type = "number",
                                    isRequired = true,
                                }
                            }
                        })
                        if dialog then
                            syphonAmount = tonumber(dialog.amt)
                            syphon = true
                        end
                    end
                end
                
				if syphon and syphonAmount then
					if syphon then
						if not syphonAmount then return end
						if tonumber(syphonAmount) < 0 then QBCore.Functions.Notify(Lang:t("syphon_more_than_zero"), 'error') return end
						if tonumber(syphonAmount) == 0 then QBCore.Functions.Notify(Lang:t("syphon_more_than_zero"), 'error') return end
						if tonumber(syphonAmount) > maxsyphon then QBCore.Functions.Notify(Lang:t("syphon_kit_cannot_fit_1").. fitamount .. Lang:t("syphon_kit_cannot_fit_2"), 'error') return end
						if currentsyphonamount + syphonAmount > Config.SyphonKitCap then QBCore.Functions.Notify(Lang:t("syphon_kit_cannot_fit_1").. fitamount .. Lang:t("syphon_kit_cannot_fit_2"), 'error') return end
						if (tonumber(syphonAmount) <= tonumber(cargasamount)) then
							local removeamount = (tonumber(cargasamount) - tonumber(syphonAmount))
							local syphontimer = Config.RefuelTime * syphonAmount
							if tonumber(syphonAmount) < 10 then syphontimer = Config.RefuelTime * 10 end
							if lib.progressCircle({
								duration = syphontimer,
								label = Lang:t("prog_syphoning"),
								position = 'bottom',
								useWhileDead = false,
								canCancel = true,
								disable = {
									car = true,
									move = true,
									combat = true
								},
								anim = {
									dict = Config.StealAnimDict,
									clip = Config.StealAnim
								},
							}) then
								StopAnimTask(ped, Config.StealAnimDict, Config.StealAnim, 1.0)
								if GetFuel(vehicle) >= syphonAmount then
									PoliceAlert(GetEntityCoords(ped))
									QBCore.Functions.Notify(Lang:t("syphon_success"), 'success')
									SetFuel(vehicle, removeamount)
									local syphonData = data.itemData
									local srcPlayerData = QBCore.Functions.GetPlayerData()
									TriggerServerEvent('cdn-fuel:info', "add", tonumber(syphonAmount), srcPlayerData, syphonData)
								else
									QBCore.Functions.Notify(Lang:t("menu_syphon_vehicle_empty"), 'error')
								end
							else
								PoliceAlert(GetEntityCoords(ped))
								StopAnimTask(ped, Config.StealAnimDict, Config.StealAnim, 1.0)
								QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
							end
						end
					end
				else
					local syphon = exports['qb-input']:ShowInput({
						header = "Select how much gas to steal.",
						submitText = "Begin Syphoning",
						inputs = {
							{
								type = 'number',
								isRequired = true,
								name = 'amount',
								text = 'You can steal ' .. Stealstring .. 'L from the car.'
							}
						}
					})
					if syphon then
						if not syphon.amount then return end
						if tonumber(syphon.amount) < 0 then QBCore.Functions.Notify(Lang:t("syphon_more_than_zero"), 'error') return end
						if tonumber(syphon.amount) == 0 then QBCore.Functions.Notify(Lang:t("syphon_more_than_zero"), 'error') return end
						if tonumber(syphon.amount) > maxsyphon then QBCore.Functions.Notify(Lang:t("syphon_kit_cannot_fit_1").. fitamount .. Lang:t("syphon_kit_cannot_fit_2"), 'error') return end
						if currentsyphonamount + syphon.amount > Config.SyphonKitCap then QBCore.Functions.Notify(Lang:t("syphon_kit_cannot_fit_1").. fitamount .. Lang:t("syphon_kit_cannot_fit_2"), 'error') return end
						if (tonumber(syphon.amount) <= tonumber(cargasamount)) then
							local removeamount = (tonumber(cargasamount) - tonumber(syphon.amount))
							local syphontimer = Config.RefuelTime * syphon.amount
							if tonumber(syphon.amount) < 10 then syphontimer = Config.RefuelTime * 10 end
							QBCore.Functions.Progressbar('syphon_gas', Lang:t("prog_syphoning"), syphontimer, false, true, { -- Name | Label | Time | useWhileDead | canCancel
								disableMovement = true,
								disableCarMovement = true,
								disableMouse = false,
								disableCombat = true,
							}, {
								animDict = Config.StealAnimDict,
								anim = Config.StealAnim,
								flags = 1,
							}, {}, {}, function() -- Play When Done
								if GetFuel(vehicle) >= tonumber(syphon.amount) then
									PoliceAlert(GetEntityCoords(ped))
									QBCore.Functions.Notify(Lang:t("syphon_success"), 'success')
									SetFuel(vehicle, removeamount)
									local syphonData = data.itemData
									local srcPlayerData = QBCore.Functions.GetPlayerData()
									TriggerServerEvent('cdn-fuel:info', "add", tonumber(syphon.amount), srcPlayerData, syphonData)
									StopAnimTask(ped, Config.StealAnimDict, Config.StealAnim, 1.0)
								else
									QBCore.Functions.Notify(Lang:t("menu_syphon_vehicle_empty"), 'error')
								end
							end, function() -- Play When Cancel
								PoliceAlert(GetEntityCoords(ped))
								StopAnimTask(ped, Config.StealAnimDict, Config.StealAnim, 1.0)
								QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
							end, "syphoningkit")
						end
					end
				end
			elseif reason == "refuel" then
				if 100 - math.ceil(cargasamount) < Config.SyphonKitCap then
					Maxrefuel = 100 - math.ceil(cargasamount)
					if Maxrefuel > currentsyphonamount then Maxrefuel = currentsyphonamount end
				else
					Maxrefuel = currentsyphonamount
				end

                local refuelAmount = nil
                local refuel = nil

                if data.amount then
                    refuelAmount = tonumber(data.amount)
                    refuel = true -- Skip input
                else
                    if Config.Ox.Input then
                        refuel = lib.inputDialog(Lang:t("input_select_refuel_header"), {{ type = "number", label = Lang:t("input_max_fuel_footer_1") .. Maxrefuel .. Lang:t("input_max_fuel_footer_2"), default = Maxrefuel }})
                        if not refuel then return end
                        refuelAmount = tonumber(refuel[1])
                    else
                        local dialog = exports['qb-input']:ShowInput({
                            header = Lang:t("input_select_refuel_header"),
                            submitText = Lang:t("input_refuel_submit"),
                            inputs = {
                                {
                                    text = Lang:t("input_max_fuel_footer_1") .. Maxrefuel .. Lang:t("input_max_fuel_footer_2"),
                                    name = "amt",
                                    type = "number",
                                    isRequired = true,
                                }
                            }
                        })
                        if dialog then
                            refuelAmount = tonumber(dialog.amt)
                            refuel = true
                        end
                    end
                end

				if refuel and refuelAmount then
					if refuel then
						if tonumber(refuelAmount) == 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuelAmount) < 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuelAmount) > 100 then QBCore.Functions.Notify("You can't refuel more than 100L!", 'error') return end
						if tonumber(refuelAmount) > tonumber(currentsyphonamount) then QBCore.Functions.Notify(Lang:t("syphon_not_enough_gas"), 'error') return end
						if tonumber(refuelAmount) + tonumber(cargasamount) > 100 then QBCore.Functions.Notify(Lang:t("tank_cannot_fit"), 'error') return end
						local refueltimer = Config.RefuelTime * tonumber(refuelAmount)
						if tonumber(refuelAmount) < 10 then refueltimer = Config.RefuelTime * 10 end
						if lib.progressCircle({
							duration = refueltimer,
							label = Lang:t("prog_refueling_vehicle"),
							position = 'bottom',
							useWhileDead = false,
							canCancel = true,
							disable = {
								car = true,
								move = true,
								combat = true
							},
							anim = {
								dict = Config.JerryCanAnimDict,
								clip = Config.JerryCanAnim
							},
						}) then
							StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
							QBCore.Functions.Notify(Lang:t("syphon_success_vehicle"), 'success')
							SetFuel(vehicle, cargasamount + tonumber(refuelAmount))
							local syphonData = data.itemData
							local srcPlayerData = QBCore.Functions.GetPlayerData()
							TriggerServerEvent('cdn-fuel:info', "remove", tonumber(refuelAmount), srcPlayerData, syphonData)
						else
							StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
							QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
						end
					end
				else
					local refuel = exports['qb-input']:ShowInput({
						header = Lang:t("input_select_refuel_header"),
						submitText = Lang:t("input_refuel_submit"),
						inputs = {
							{
								type = 'number',
								isRequired = true,
								name = 'amount',
								text = Lang:t("input_max_fuel_footer_1") .. Maxrefuel .. Lang:t("input_max_fuel_footer_2")
							}
						}
					})
					if refuel then
						if tonumber(refuel.amount) == 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuel.amount) < 0 then QBCore.Functions.Notify(Lang:t("more_than_zero"), 'error') return elseif tonumber(refuel.amount) > 100 then QBCore.Functions.Notify("You can't refuel more than 100L!", 'error') return end
						if tonumber(refuel.amount) > tonumber(currentsyphonamount) then QBCore.Functions.Notify(Lang:t("syphon_not_enough_gas"), 'error') return end
						if tonumber(refuel.amount) + tonumber(cargasamount) > 100 then QBCore.Functions.Notify(Lang:t("tank_cannot_fit"), 'error') return end
						local refueltimer = Config.RefuelTime * tonumber(refuel.amount)
						if tonumber(refuel.amount) < 10 then refueltimer = Config.RefuelTime * 10 end
						QBCore.Functions.Progressbar('refuel_gas', Lang:t("prog_refueling_vehicle"), refueltimer, false, true, { -- Name | Label | Time | useWhileDead | canCancel
							disableMovement = true,
							disableCarMovement = true,
							disableMouse = false,
							disableCombat = true,
						}, {
							animDict = Config.JerryCanAnimDict,
							anim = Config.JerryCanAnim,
							flags = 17,
						}, {}, {}, function() -- Play When Done
							StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
							QBCore.Functions.Notify(Lang:t("syphon_success_vehicle"), 'success')
							SetFuel(vehicle, cargasamount + tonumber(refuel.amount))
							local syphonData = data.itemData
							local srcPlayerData = QBCore.Functions.GetPlayerData()
							TriggerServerEvent('cdn-fuel:info', "remove", tonumber(refuel.amount), srcPlayerData, syphonData)
						end, function() -- Play When Cancel
							StopAnimTask(ped, Config.JerryCanAnimDict, Config.JerryCanAnim, 1.0)
							QBCore.Functions.Notify(Lang:t("cancelled"), 'error')
						end, "syphoningkit")
					end
				end
			end
		else
			QBCore.Functions.Notify(Lang:t("syphon_no_syphon_kit"), 'error', 7500)
		end
	else
		QBCore.Functions.Notify(Lang:t("need_electric_charger"), 'error', 7500) return
	end
end)

RegisterNetEvent('cdn-syphoning:client:callcops', function(coords)
	local PlayerJob = QBCore.Functions.GetPlayerData().job
	if PlayerJob.name ~= "police" or not PlayerJob.onduty then return end
	local transG = 250
	local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(blip, 648)
	SetBlipColour(blip, 17)
	SetBlipDisplay(blip, 4)
	SetBlipAlpha(blip, transG)
	SetBlipScale(blip, 1.2)
	SetBlipFlashes(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentString(Lang:t("syphon_dispatch_string"))
	EndTextCommandSetBlipName(blip)
	while transG ~= 0 do
		Wait(180 * 4)
		transG = transG - 1
		SetBlipAlpha(blip, transG)
		if transG == 0 then
			SetBlipSprite(blip, 2)
			RemoveBlip(blip)
			return
		end
	end
end)

-- Helicopter Fueling --
RegisterNetEvent('cdn-fuel:client:grabnozzle:special', function()
	local ped = PlayerPedId()
	if HoldingSpecialNozzle then return end
	LoadAnimDict("anim@am_hold_up@male")
	TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	TriggerServerEvent("InteractSound_SV:PlayOnSource", "pickupnozzle", 0.4)
	Wait(300)
	StopAnimTask(ped, "anim@am_hold_up@male", "shoplift_high", 1.0)
	SpecialFuelNozzleObj = CreateObject(joaat('prop_cs_fuel_nozle'), 1.0, 1.0, 1.0, true, true, false)
	local lefthand = GetPedBoneIndex(ped, 18905)
	AttachEntityToEntity(SpecialFuelNozzleObj, ped, lefthand, 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0, 1, 0, 1, 0, 1)
	local grabbednozzlecoords = GetEntityCoords(ped)
	HoldingSpecialNozzle = true
	QBCore.Functions.Notify(Lang:t("show_input_key_special"))
	if Config.PumpHose then
		local pumpCoords, pump = GetClosestPump(grabbednozzlecoords)
		-- Load Rope Textures
		RopeLoadTextures()
		while not RopeAreTexturesLoaded() do
			Wait(0)
			RopeLoadTextures()
		end
		-- Wait for Pump to exist.
		while not pump do
			Wait(0)
		end
		Rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z + 2.0, 0.0, 0.0, 0.0, 3.0, Config.RopeType['fuel'], 8.0 --[[ DO NOT SET THIS TO 0.0!!! GAME WILL CRASH!]], 0.0, 1.0, false, false, false, 1.0, true)
		while not Rope do
			Wait(0)
		end
		ActivatePhysics(Rope)
		Wait(100)
		local nozzlePos = GetEntityCoords(SpecialFuelNozzleObj)
		if Config.FuelDebug then print("NOZZLE POS ".. nozzlePos) end
		nozzlePos = GetOffsetFromEntityInWorldCoords(SpecialFuelNozzleObj, 0.0, -0.033, -0.195)
		AttachEntitiesToRope(Rope, pump, SpecialFuelNozzleObj, pumpCoords.x, pumpCoords.y, pumpCoords.z + 2.1, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

		if Config.FuelDebug then
			print("Hose Properties:")
			print(Rope, pump, SpecialFuelNozzleObj, pumpCoords.x, pumpCoords.y, pumpCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length)

			SetEntityDrawOutline(SpecialFuelNozzleObj --[[ Entity ]], true --[[ boolean ]])
		end
	end
	CreateThread(function()
		while HoldingSpecialNozzle do
			local currentcoords = GetEntityCoords(ped)
			local dist = #(grabbednozzlecoords - currentcoords)
			TargetCreated = true
			if dist > Config.AirAndWaterVehicleFueling['nozzle_length'] or IsPedInAnyVehicle(ped, false) then
				HoldingSpecialNozzle = false
				DeleteObject(SpecialFuelNozzleObj)
				QBCore.Functions.Notify(Lang:t("nozzle_cannot_reach"), 'error')
				if Config.PumpHose then
					if Config.FuelDebug then print("Deleting Rope: "..tostring(Rope)) end
					RopeUnloadTextures()
					DeleteRope(Rope)
				end
				if Config.FuelNozzleExplosion then
					AddExplosion(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z, 'EXP_TAG_PROPANE', 1.0, true,false, 5.0)
					StartScriptFire(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z - 1,25,false)
					SetFireSpreadRate(10.0)
					Wait(5000)
					StopFireInRange(grabbednozzlecoords.x, grabbednozzlecoords.y, grabbednozzlecoords.z - 1, 3.0)
				end
			end
			Wait(2500)
		end
	end)
end)

RegisterNetEvent('cdn-fuel:client:returnnozzle:special', function()
	HoldingSpecialNozzle = false
	TriggerServerEvent("InteractSound_SV:PlayOnSource", "putbacknozzle", 0.4)
	Wait(250)
	DeleteObject(SpecialFuelNozzleObj)

	if Config.PumpHose then
		if Config.FuelDebug then print("Removing Hose.") end
		RopeUnloadTextures()
		DeleteRope(Rope)
	end
end)

local AirSeaFuelZones = {}
local vehicle = nil
-- Create Polyzones with In-Out functions for handling fueling --

AddEventHandler('onResourceStart', function(resource)
   if resource == GetCurrentResourceName() then
	  if LocalPlayer.state['isLoggedIn'] then
		for i = 1, #Config.AirAndWaterVehicleFueling['locations'], 1 do
			local currentLocation = Config.AirAndWaterVehicleFueling['locations'][i]
			local k = #AirSeaFuelZones+1
			local GeneratedName = "air_sea_fuel_zone_"..k

			AirSeaFuelZones[k] = {} -- Make a new table inside of the Vehicle Pullout Zones representing this zone.

			-- Get Coords for Zone from Config.
			AirSeaFuelZones[k].zoneCoords = currentLocation['PolyZone']['coords']

			-- Grab MinZ & MaxZ from Config.
			local minimumZ, maximumZ = currentLocation['PolyZone']['minmax']['min'], currentLocation['PolyZone']['minmax']['max']

			-- Create Zone
			AirSeaFuelZones[k].PolyZone = PolyZone:Create(AirSeaFuelZones[k].zoneCoords, {
				name = GeneratedName,
				minZ = minimumZ,
				maxZ = maximumZ,
				debugPoly = Config.PolyDebug
			})

			AirSeaFuelZones[k].name = GeneratedName

			-- Setup onPlayerInOut Events for zone that is created.
			AirSeaFuelZones[k].PolyZone:onPlayerInOut(function(isPointInside)
				if isPointInside then
					local canUseThisStation = false
					if Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['enabled'] then
						local whitelisted_jobs = Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['whitelisted_jobs']
						local plyJob = QBCore.Functions.GetPlayerData().job

						if Config.FuelDebug then
							print("Player Job: "..plyJob.name.." Is on Duty?: "..json.encode(plyJob.onduty))
						end

						if type(whitelisted_jobs) == "table" then
							for i = 1, #whitelisted_jobs, 1 do
								if plyJob.name == whitelisted_jobs[i] then
									if Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['on_duty_only'] then
										if plyJob.onduty == true then
											canUseThisStation = true
										else
											canUseThisStation = false
										end
									else
										canUseThisStation = true
									end
								end
							end
						end
					else
						canUseThisStation = true
					end

					if canUseThisStation then
						-- Inside
						PlayerInSpecialFuelZone = true
						inGasStation = true
						RefuelingType = 'special'

						local DrawText = Config.AirAndWaterVehicleFueling['locations'][i]['draw_text']

						if Config.Ox.DrawText then
							lib.showTextUI(DrawText, {
								position = 'right-center'
							})
						else
							exports[Config.Core]:DrawText(DrawText, 'left')
						end

						CreateThread(function()
							while PlayerInSpecialFuelZone do
								Wait(3000)
								vehicle = GetClosestVehicle()
							end
						end)

						CreateThread(function()
							while PlayerInSpecialFuelZone do
								Wait(0)
								if PlayerInSpecialFuelZone ~= true then
									break
								end
								if IsControlJustReleased(0, Config.AirAndWaterVehicleFueling['refuel_button']) --[[ Control in Config ]] then
									local vehCoords = GetEntityCoords(vehicle)
									local dist = #(GetEntityCoords(PlayerPedId()) - vehCoords)

									if not HoldingSpecialNozzle then
										QBCore.Functions.Notify(Lang:t("no_nozzle"), 'error', 1250)
									elseif dist > 4.5 then
										QBCore.Functions.Notify(Lang:t("vehicle_too_far"), 'error', 1250)
									elseif IsPedInAnyVehicle(PlayerPedId(), true) then
										QBCore.Functions.Notify(Lang:t("inside_vehicle"), 'error', 1250)
									else
										if Config.FuelDebug then print("Attempting to Open Fuel menu for special vehicles.") end
										TriggerEvent('cdn-fuel:client:RefuelMenu', 'special')
									end
								end
							end
						end)

						if Config.FuelDebug then
							print('Player has entered the Heli or Plane Refuel Zone: ('..GeneratedName..')')
						end
					end
				else
					if HoldingSpecialNozzle then
						QBCore.Functions.Notify(Lang:t("nozzle_cannot_reach"), 'error')
						HoldingSpecialNozzle = false
						if Config.PumpHose then
							if Config.FuelDebug then
								print("Deleting Rope: "..Rope)
							end
							RopeUnloadTextures()
							DeleteObject(Rope)
						end
						DeleteObject(SpecialFuelNozzleObj)
					end
					if Config.PumpHose then
						if Rope ~= nil then
							if Config.FuelDebug then
								print("Deleting Rope: "..Rope)
							end
							RopeUnloadTextures()
							DeleteObject(Rope)
						end
					end
					-- Outside
					if Config.Ox.DrawText then
						lib.hideTextUI()
					else
						exports[Config.Core]:HideText()
					end
					PlayerInSpecialFuelZone = false
					inGasStation = false
					RefuelingType = nil
					if Config.FuelDebug then
						print('Player has exited the Heli or Plane Refuel Zone: ('..GeneratedName..')')
					end
				end
			end)

			if currentLocation['prop'] then
				local model = currentLocation['prop']['model']
				local modelCoords = currentLocation['prop']['coords']
				local heading = modelCoords[4] - 180.0
				AirSeaFuelZones[k].prop = CreateObject(model, modelCoords.x, modelCoords.y, modelCoords.z, false, true, true)
				if Config.FuelDebug then print("Created Special Pump from Location #"..i) end
				SetEntityHeading(AirSeaFuelZones[k].prop, heading)
				FreezeEntityPosition(AirSeaFuelZones[k].prop, 1)
			else
				if Config.FuelDebug then print("Location #"..i.." for Special Fueling Zones (Air and Sea) doesn't have a prop set up, so players cannot fuel here.") end
			end

			if Config.FuelDebug then
				print("Created Location: "..GeneratedName)
			end
		end
	  end
   end
end)

AddEventHandler("QBCore:Client:OnPlayerLoaded", function ()
	for i = 1, #Config.AirAndWaterVehicleFueling['locations'], 1 do
		local currentLocation = Config.AirAndWaterVehicleFueling['locations'][i]
		local k = #AirSeaFuelZones+1
		local GeneratedName = "air_sea_fuel_zone_"..k

		AirSeaFuelZones[k] = {} -- Make a new table inside of the Vehicle Pullout Zones representing this zone.

		-- Get Coords for Zone from Config.
		AirSeaFuelZones[k].zoneCoords = currentLocation['PolyZone']['coords']

		-- Grab MinZ & MaxZ from Config.
		local minimumZ, maximumZ = currentLocation['PolyZone']['minmax']['min'], currentLocation['PolyZone']['minmax']['max']

		-- Create Zone
		AirSeaFuelZones[k].PolyZone = PolyZone:Create(AirSeaFuelZones[k].zoneCoords, {
			name = GeneratedName,
			minZ = minimumZ,
			maxZ = maximumZ,
			debugPoly = Config.PolyDebug
		})

		AirSeaFuelZones[k].name = GeneratedName

		-- Setup onPlayerInOut Events for zone that is created.
		AirSeaFuelZones[k].PolyZone:onPlayerInOut(function(isPointInside)
			if isPointInside then
				local canUseThisStation = false
				if Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['enabled'] then
					local whitelisted_jobs = Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['whitelisted_jobs']
					local plyJob = QBCore.Functions.GetPlayerData().job

					if Config.FuelDebug then
						print("Player Job: "..plyJob.name.." Is on Duty?: "..json.encode(plyJob.onduty))
					end

					if type(whitelisted_jobs) == "table" then
						for i = 1, #whitelisted_jobs, 1 do
							if plyJob.name == whitelisted_jobs[i] then
								if Config.AirAndWaterVehicleFueling['locations'][i]['whitelist']['on_duty_only'] then
									if plyJob.onduty == true then
										canUseThisStation = true
									else
										canUseThisStation = false
									end
								else
									canUseThisStation = true
								end
							end
						end
					end
				else
					canUseThisStation = true
				end

				if canUseThisStation then
					-- Inside
					PlayerInSpecialFuelZone = true
					inGasStation = true
					RefuelingType = 'special'

					local DrawText = Config.AirAndWaterVehicleFueling['locations'][i]['draw_text']

					if Config.Ox.DrawText then
						lib.showTextUI(DrawText, {
							position = 'right-center'
						})
					else
						exports[Config.Core]:DrawText(DrawText, 'left')
					end

					CreateThread(function()
						while PlayerInSpecialFuelZone do
							Wait(3000)
							vehicle = GetClosestVehicle()
						end
					end)

					CreateThread(function()
						while PlayerInSpecialFuelZone do
							Wait(0)
							if PlayerInSpecialFuelZone ~= true then
								break
							end
							if IsControlJustReleased(0, Config.AirAndWaterVehicleFueling['refuel_button']) --[[ Control in Config ]] then
								local vehCoords = GetEntityCoords(vehicle)
								local dist = #(GetEntityCoords(PlayerPedId()) - vehCoords)

								if not HoldingSpecialNozzle then
									QBCore.Functions.Notify(Lang:t("no_nozzle"), 'error', 1250)
								elseif dist > 4.5 then
									QBCore.Functions.Notify(Lang:t("vehicle_too_far"), 'error', 1250)
								elseif IsPedInAnyVehicle(PlayerPedId(), true) then
									QBCore.Functions.Notify(Lang:t("inside_vehicle"), 'error', 1250)
								else
									if Config.FuelDebug then print("Attempting to Open Fuel menu for special vehicles.") end
									TriggerEvent('cdn-fuel:client:RefuelMenu', 'special')
								end
							end
						end
					end)

					if Config.FuelDebug then
						print('Player has entered the Heli or Plane Refuel Zone: ('..GeneratedName..')')
					end
				end
			else
				if HoldingSpecialNozzle then
					QBCore.Functions.Notify(Lang:t("nozzle_cannot_reach"), 'error')
					HoldingSpecialNozzle = false
					if Config.PumpHose then
						if Config.FuelDebug then
							print("Deleting Rope: "..Rope)
						end
						RopeUnloadTextures()
						DeleteObject(Rope)
					end
					DeleteObject(SpecialFuelNozzleObj)
				end
				if Config.PumpHose then
					if Rope ~= nil then
						if Config.FuelDebug then
							print("Deleting Rope: "..Rope)
						end
						RopeUnloadTextures()
						DeleteObject(Rope)
					end
				end
				-- Outside
				if Config.Ox.DrawText then
					lib.hideTextUI()
				else
					exports[Config.Core]:HideText()
				end
				PlayerInSpecialFuelZone = false
				inGasStation = false
				RefuelingType = nil
				if Config.FuelDebug then
					print('Player has exited the Heli or Plane Refuel Zone: ('..GeneratedName..')')
				end
			end
		end)

		if currentLocation['prop'] then
			local model = currentLocation['prop']['model']
			local modelCoords = currentLocation['prop']['coords']
			local heading = modelCoords[4] - 180.0
			AirSeaFuelZones[k].prop = CreateObject(model, modelCoords.x, modelCoords.y, modelCoords.z, false, true, true)
			if Config.FuelDebug then print("Created Special Pump from Location #"..i) end
			SetEntityHeading(AirSeaFuelZones[k].prop, heading)
			FreezeEntityPosition(AirSeaFuelZones[k].prop, 1)
		else
			if Config.FuelDebug then print("Location #"..i.." for Special Fueling Zones (Air and Sea) doesn't have a prop set up, so players cannot fuel here.") end
		end

		if Config.FuelDebug then
			print("Created Location: "..GeneratedName)
		end
	end
end)

AddEventHandler("QBCore:Client:OnPlayerUnload", function()
	for i = 1, #AirSeaFuelZones, 1 do
		AirSeaFuelZones[i].PolyZone:destroy()
		if Config.FuelDebug then
			print("Destroying Air Fuel PolyZone: "..AirSeaFuelZones[i].name)
		end
		if AirSeaFuelZones[i].prop then
			if Config.FuelDebug then
				print("Destroying Air Fuel Zone Pump: "..i)
			end
			DeleteObject(AirSeaFuelZones[i].prop)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for i = 1, #AirSeaFuelZones, 1 do
			DeleteObject(AirSeaFuelZones[i].prop)
		end
	end
end)

CreateThread(function()
	local bones = {
		"petroltank",
		"petroltank_l",
		"petroltank_r",
		"wheel_rf",
		"wheel_rr",
		"petrolcap ",
		"seat_dside_r",
		"engine",
	}

	if Config.TargetResource == 'ox_target' then
		local options = {
			[1] = {
				name = 'cdn-fuel:options:1',
				icon = "fas fa-gas-pump",
				label = tostring(Lang:t("input_insert_nozzle")),
				canInteract = function(entity)
					if inGasStation and not refueling and holdingnozzle then
						local currentStation = Config.GasStations[CurrentLocation]
                        local vClass = GetVehicleClass(entity)
                        local isAviationVeh = Config.AviationVehicleClasses[vClass] or false
						if currentStation and currentStation.type == 'air' then
							if not isAviationVeh then
								return false
							end
                        else
                            if isAviationVeh then
                                return false
                            end
						end
						return true
					end
				end,
				event = 'cdn-fuel:client:RefuelMenu'
			},
			[2] = {
				name = 'cdn-fuel:options:2',
				icon = "fas fa-bolt",
				label = tostring(Lang:t("insert_electric_nozzle")),
				canInteract = function()
					if Config.ElectricVehicleCharging == true then
						if inGasStation and not refueling and IsHoldingElectricNozzle() then
							return true
						else
							return false
						end
					else
						return false
					end
				end,
				event = "cdn-fuel:client:electric:RefuelMenu",
			}
		}

		exports.ox_target:addGlobalVehicle(options)

		local modelOptions = {
			[1] = {
				name = "cdn-fuel:modelOptions:option_1",
				num = 1,
				type = "client",
				event = "cdn-fuel:client:grabnozzle",
				icon = "fas fa-gas-pump",
				label = Lang:t("grab_nozzle"),
				canInteract = function()
					if PlayerInSpecialFuelZone then return false end
					if not IsPedInAnyVehicle(PlayerPedId()) and not holdingnozzle and not HoldingSpecialNozzle and inGasStation == true and not PlayerInSpecialFuelZone then
						return true
					end
				end,
			},
			[2] = {
				name = "cdn-fuel:modelOptions:option_2",
				num = 2,
				type = "client",
				event = "cdn-fuel:client:purchasejerrycan",
				icon = "fas fa-fire-flame-simple",
				label = Lang:t("buy_jerrycan"),
				canInteract = function()
					if not IsPedInAnyVehicle(PlayerPedId()) and not holdingnozzle and not HoldingSpecialNozzle and inGasStation == true then
						return true
					end
				end,
			},
			[3] = {
				name = "cdn-fuel:modelOptions:option_3",
				num = 3,
				type = "client",
				event = "cdn-fuel:client:returnnozzle",
				icon = "fas fa-hand",
				label = Lang:t("return_nozzle"),
				canInteract = function()
					if holdingnozzle and not refueling then
						return true
					end
				end,
			},
			[4] = {
				name = "cdn-fuel:modelOptions:option_4",
				num = 4,
				type = "client",
				event = "cdn-fuel:client:grabnozzle:special",
				icon = "fas fa-gas-pump",
				label = Lang:t("grab_special_nozzle"),
				canInteract = function()
					if Config.FuelDebug then print("Is Player In Special Fuel Zone?: "..tostring(PlayerInSpecialFuelZone)) end
					if not HoldingSpecialNozzle and not IsPedInAnyVehicle(PlayerPedId()) and PlayerInSpecialFuelZone then
						return true
					end
				end,
			},
			[5] = {
				name = "cdn-fuel:modelOptions:option_5",
				num = 5,
				type = "client",
				event = "cdn-fuel:client:returnnozzle:special",
				icon = "fas fa-hand",
				label = Lang:t("return_special_nozzle"),
				canInteract = function()
					if HoldingSpecialNozzle and not IsPedInAnyVehicle(PlayerPedId()) then
						return true
					end
				end,
			},
			[6] = {
				name = "cdn-fuel:modelOptions:option_6",
				num = 6,
				type = "client",
				event = "cdn-fuel:client:jerrycan:refillmenu",
				icon = "fas fa-fill-drip",
				label = "Reabastecer Galão",
				canInteract = function()
					if not IsPedInAnyVehicle(PlayerPedId()) and inGasStation == true then
						return true
					end
				end,
			},
		}

		exports.ox_target:addModel(props, modelOptions)
	else
		exports[Config.TargetResource]:AddTargetBone(bones, {
			options = {
				{
					type = "client",
					action = function ()
						TriggerEvent('cdn-fuel:client:RefuelMenu')
					end,
					icon = "fas fa-gas-pump",
					label = Lang:t("input_insert_nozzle"),
					canInteract = function(entity)
						if inGasStation and not refueling and holdingnozzle then
							local currentStation = Config.GasStations[CurrentLocation]
                            local vClass = GetVehicleClass(entity)
                            local isAviationVeh = Config.AviationVehicleClasses[vClass] or false
							if currentStation and currentStation.type == 'air' then
								if not isAviationVeh then
									return false
								end
                            else
                                if isAviationVeh then
                                    return false
                                end
							end
							return true
						end
					end
				},
				{
					type = "client",
					action = function()
						TriggerEvent('cdn-fuel:client:electric:RefuelMenu')
					end,
					icon = "fas fa-bolt",
					label = Lang:t("insert_electric_nozzle"),
					canInteract = function()
						if Config.ElectricVehicleCharging == true then
							if inGasStation and not refueling and IsHoldingElectricNozzle() then
								return true
							else
								return false
							end
						else
							return false
						end
					end
				},
			},
			distance = 1.5,
		})

		exports[Config.TargetResource]:AddTargetModel(props, {
			options = {
				{
					num = 1,
					type = "client",
					event = "cdn-fuel:client:grabnozzle",
					icon = "fas fa-gas-pump",
					label = Lang:t("grab_nozzle"),
					canInteract = function()
						if PlayerInSpecialFuelZone then return false end
						if not IsPedInAnyVehicle(PlayerPedId()) and not holdingnozzle and not HoldingSpecialNozzle and inGasStation == true and not PlayerInSpecialFuelZone then
							return true
						end
					end,
				},
				{
					num = 2,
					type = "client",
					event = "cdn-fuel:client:purchasejerrycan",
					icon = "fas fa-fire-flame-simple",
					label = Lang:t("buy_jerrycan"),
					canInteract = function()
						if not IsPedInAnyVehicle(PlayerPedId()) and not holdingnozzle and not HoldingSpecialNozzle and inGasStation == true then
							return true
						end
					end,
				},
				{
					num = 3,
					type = "client",
					event = "cdn-fuel:client:returnnozzle",
					icon = "fas fa-hand",
					label = Lang:t("return_nozzle"),
					canInteract = function()
						if holdingnozzle and not refueling then
							return true
						end
					end,
				},
				{
					num = 4,
					type = "client",
					event = "cdn-fuel:client:grabnozzle:special",
					icon = "fas fa-gas-pump",
					label = Lang:t("grab_special_nozzle"),
					canInteract = function()
						if Config.FuelDebug then print("Is Player In Special Fuel Zone?: "..tostring(PlayerInSpecialFuelZone)) end
						if not HoldingSpecialNozzle and not IsPedInAnyVehicle(PlayerPedId()) and PlayerInSpecialFuelZone then
							return true
						end
					end,
				},
				{
					num = 5,
					type = "client",
					event = "cdn-fuel:client:jerrycan:refillmenu",
					icon = "fas fa-fill-drip",
					label = "Reabastecer Galão",
					canInteract = function()
						if not IsPedInAnyVehicle(PlayerPedId()) and inGasStation == true then
							return true
						end
					end,
				},
				{
					num = 6,
					type = "client",
					event = "cdn-fuel:client:returnnozzle:special",
					icon = "fas fa-hand",
					label = Lang:t("return_special_nozzle"),
					canInteract = function()
						if HoldingSpecialNozzle and not IsPedInAnyVehicle(PlayerPedId()) then
							return true
						end
					end
				},
			},
			distance = 2.0
		})
	end
end)

CreateThread(function()
	while true do
		Wait(3000)
		local vehPedIsIn = GetVehiclePedIsIn(PlayerPedId(), false)
		if not vehPedIsIn or vehPedIsIn == 0 then
			Wait(2500)
			if inBlacklisted then
				inBlacklisted = false
			end
		else
			local vehType = GetCurrentVehicleType(vehPedIsIn)
			if not Config.ElectricVehicleCharging and vehType == 'electricvehicle' then
				if Config.FuelDebug then
					print("Vehicle Type is Electric, so we will not remove shut the engine off.")
				end
			else
				if not IsVehicleBlacklisted(vehPedIsIn) then
					local vehFuelLevel = GetFuel(vehPedIsIn)
					local vehFuelShutoffLevel = Config.VehicleShutoffOnLowFuel['shutOffLevel'] or 1
					if vehFuelLevel <= vehFuelShutoffLevel then
						if GetIsVehicleEngineRunning(vehPedIsIn) then
							if Config.FuelDebug then
								print("Vehicle is running with zero fuel, shutting it down.")
							end
							-- If the vehicle is on, we shut the vehicle off:
							SetVehicleEngineOn(vehPedIsIn, false, true, true)
							-- Then alert the client with notify.
							QBCore.Functions.Notify(Lang:t("no_fuel"), 'error', 3500)
							-- Play Sound, if enabled in config.
							if Config.VehicleShutoffOnLowFuel['sounds']['enabled'] then
								RequestAmbientAudioBank("DLC_PILOT_ENGINE_FAILURE_SOUNDS", 0)
								PlaySoundFromEntity(l_2613, "Landing_Tone", vehPedIsIn, "DLC_PILOT_ENGINE_FAILURE_SOUNDS", 0, 0)
								Wait(1500)
								StopSound(l_2613)
							end
						end
					else
						if vehFuelLevel - 10 > vehFuelShutoffLevel then
							Wait(7500)
						end
					end
				end
			end
		end
	end
end)

if Config.VehicleShutoffOnLowFuel['shutOffLevel'] == 0 then
	Config.VehicleShutoffOnLowFuel['shutOffLevel'] = 0.55
end

-- This loop does use quite a bit of performance, but,
-- is needed due to electric vehicles running without fuel & normal vehicles driving backwards!
-- You can remove if you need the performance, but we believe it is very important.
CreateThread(function()
	while true do
		Wait(0)
		local ped = PlayerPedId()
		local veh = GetVehiclePedIsIn(ped, false)
		if veh ~= 0 and veh ~= nil then
			if not IsVehicleBlacklisted(veh) then
				-- Check if we are below the threshold for the Fuel Shutoff Level, if so, disable the "W" key, if not, enable it again.
				if IsPedInVehicle(ped, veh, false) and (GetIsVehicleEngineRunning(veh) == false) or GetFuel(veh) < (Config.VehicleShutoffOnLowFuel['shutOffLevel'] or 1) then
					DisableControlAction(0, 71, true)
				elseif IsPedInVehicle(ped, veh, false) and (GetIsVehicleEngineRunning(veh) == true) and GetFuel(veh) > (Config.VehicleShutoffOnLowFuel['shutOffLevel'] or 1) then
					EnableControlAction(0, 71, true)
				end
				-- Now, we check if the fuel level is currently 5 above the level it should shut off,
				-- if this is true, we will then enable the "W" key if currently disabled, and then,
				-- we will add a 5 second wait, in order to reduce system impact.
				if GetFuel(veh) > (Config.VehicleShutoffOnLowFuel['shutOffLevel'] + 5) then
					if not IsControlEnabled(0, 71) then
						-- Enable "W" Key if it is currently disabled.
						EnableControlAction(0, 71, true)
					end
					Wait(5000)
				end
			end
		else
			-- 1.75 Second Cooldown if the player is not inside of a vehicle.
			Wait(1750)
		end
	end
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('pay', function(data, cb)
    SetNuiFocus(false, false)
    local amount = data.amount
    local method = data.method
    local type = data.type

    if Config.FuelDebug then print("[DEBUG] pay callback: type=" .. tostring(type) .. ", amount=" .. tostring(amount)) end
    if type == 'syphon' then
        if not amount then return end
        TriggerEvent('cdn-syphoning:syphon', {
            itemData = data.syphonData.itemData,
            reason = data.reason,
            amount = amount
        })
    elseif type == 'jerrycanRefuel' then
        if not amount then return end
        TriggerEvent('cdn-fuel:jerrycan:refuelvehicle', {
            itemData = data.jerryCanData.itemData,
            amount = amount
        })
    elseif type == 'jerrycanRefill' then
        if not amount then return end
        TriggerEvent('cdn-fuel:jerrycan:refueljerrycan', {
            itemData = data.jerryCanData,
            amount = amount,
            fuelType = data.fuelType
        })
    else
        if not amount or not method then return end
        
        if type == 'jerrycan' then
            TriggerEvent('cdn-fuel:client:jerrycanfinalmenu', method, amount, data.fuelType)
        elseif type == 'electric' then
             TriggerEvent('cdn-fuel:client:electric:ChargeVehicle', {
                purchasetype = method,
                fuelamounttotal = amount
            })
        else
            local price = data.price or tonumber(FuelPrice) or Config.CostMultiplier
            TriggerServerEvent('cdn-fuel:server:OpenMenu', amount, inGasStation, false, method, price, CurrentLocation, data.fuelType)
        end
    end
    cb('ok')
end)

RegisterNetEvent('cdn-fuel:client:syncStations', function(newId, stationData)
    if not newId then return end

    if not stationData then
        -- Handle Deletion
        if Config.GasStations[newId] then
            if Stations[newId] then 
                Stations[newId]:destroy()
                Stations[newId] = nil
            end
            if CurrentLocation == newId then
                inGasStation = false
                CurrentLocation = 0
                TriggerEvent('cdn-fuel:stations:updatelocation', nil)
            end
            if GasStationBlips[newId] then
                RemoveBlip(GasStationBlips[newId])
                GasStationBlips[newId] = nil
            end
            Config.GasStations[newId] = nil
            if Config.FuelDebug then print("Posto #" .. newId .. " removido dinamicamente.") end
        end
        return
    end
    
    -- Update Config
    Config.GasStations[newId] = stationData
    
    -- Create PolyZone
    Stations[newId] = PolyZone:Create(stationData.zones, {
        name = "CDN_FUEL_GAS_STATION_"..newId,
        minZ = stationData.minz,
        maxZ = stationData.maxz,
        debugPoly = Config.PolyDebug
    })
    
    Stations[newId]:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inGasStation = true
            CurrentLocation = newId
            if Config.FuelDebug then print("New Location: "..newId) end
            if Config.PlayerOwnedGasStationsEnabled then
                TriggerEvent('cdn-fuel:stations:updatelocation', newId)
            end
        else
            TriggerEvent('cdn-fuel:stations:updatelocation', nil)
            inGasStation = false
        end
    end)
    
    -- Update Blips
    if not Config.ShowNearestGasStationOnly then
        local coords = vector3(stationData.pedcoords.x, stationData.pedcoords.y, stationData.pedcoords.z)
        GasStationBlips[newId] = CreateBlip(coords, stationData.label)
    end
    
    if Config.FuelDebug then print("Synced new dynamic station #" .. newId) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cdn-fuel:server:requestDynamicStations')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    TriggerServerEvent('cdn-fuel:server:requestDynamicStations')
end)

RegisterNetEvent('cdn-fuel:client:updatestationlogo', function(location, logoUrl)
    if not location then return end
    if Config.GasStations[location] then
        Config.GasStations[location].logo = logoUrl
    end
end)

print("[DEBUG] Loading fuel_cl_extension logic merged into fuel_cl.lua")

RegisterNetEvent('cdn-fuel:client:createDynamicAirSeaZone', function(stationId, stationData)
    print("[DEBUG] Event createDynamicAirSeaZone received for ID: " .. tostring(stationId))
    if not stationData or not stationData.zones then 
        print("[DEBUG] Missing stationData or zones")
        return 
    end

    -- Prepare location data format expected by AirSeaFuelZones
    local locationData = {
        ['PolyZone'] = {
            ['coords'] = {}, -- Will populate below
            ['minmax'] = {
                ['min'] = stationData.minz or -999,
                ['max'] = stationData.maxz or 999
            }
        },
        ['draw_text'] = stationData.type == 'air' and "[G] Reabastecer Aeronave" or "[G] Reabastecer Barco",
        ['type'] = stationData.type,
        -- Optional: Whitelist from station settings if implemented?
        ['whitelist'] = {
            ['enabled'] = false 
        },
        ['prop'] = {
            ['model'] = 'prop_gas_pump_1d', -- Default prop or customizable?
            ['coords'] = nil -- Vector4
        }
    }

    -- Convert Zone Points
    -- stationData.zones comes as array of {x, y}
    local coords = {}
    for i, p in ipairs(stationData.zones) do
        table.insert(coords, vector2(p.x, p.y))
    end
    locationData['PolyZone']['coords'] = coords

    -- Handle Props (Visual Only for Air/Sea typically, but system supports it)
    -- If user placed pumps in creator, we can use the first one as the 'main' prop location
    if stationData.fuelpumpcoords and #stationData.fuelpumpcoords > 0 then
        local p = stationData.fuelpumpcoords[1]
        locationData['prop']['coords'] = vector4(p.x, p.y, p.z, p.w)
        
        print("[DEBUG] Attempting to spawn pumps. Count: " .. #stationData.fuelpumpcoords)
        
        -- Note: We rely on station_cl.lua to handle ALL visual props.
        -- We do NOT spawn props here to prevent duplication and unmanaged entities.
    end
    
    -- Add to table and Create Zone
    -- We need a unique index. Since Config.AirAndWaterVehicleFueling.locations is an array, 
    -- and we are adding dynamic ones, we should start indexing after the config static ones.
    -- Or we can append?
    
    local nextId = #Config.AirAndWaterVehicleFueling.locations + 1 + stationId -- Simple offset to avoid collision
    -- Better: Just use a string key or high integer? 
    -- The existing loops use ipairs usually. 
    -- Let's just create the PolyZone directly here and register it to the existing AirSeaFuelZones table logic if possible.
    -- Looking at fuel_cl.lua (viewed earlier), it iterates Config on start.
    
    -- Actually, we can just call the internal function to create zone if we extract it, 
    -- OR we just run the same logic here:
    
    local GeneratedName = "cdn_fuel_air_sea_dynamic_" .. stationId
    local Zone = PolyZone:Create(locationData.PolyZone.coords, {
        name = GeneratedName,
        minZ = locationData.PolyZone.minmax.min,
        maxZ = locationData.PolyZone.minmax.max,
        debugPoly = Config.PolyDebug
    })
    
    Zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle and vehicle ~= 0 then
                 local vehClass = GetVehicleClass(vehicle)
                 -- Logic for checking class
                 local validClass = false
                 if stationData.type == 'air' and (vehClass == 15 or vehClass == 16) then validClass = true end
                 if stationData.type == 'water' and vehClass == 14 then validClass = true end
                 
                 if validClass then
                     -- Show Text
                     local text = locationData.draw_text
                     if Config.Ox.DrawText then
                         lib.showTextUI(text, { position = 'left-center' })
                     else
                         exports[Config.Core]:DrawText(text, 'left')
    -- G key logic disabled in favor of manual hose-based aviation refueling
--[[
                     -- Input Thread
                     CreateThread(function()
                         while isPointInside do
                             Wait(0)
                             if IsControlJustReleased(0, Config.AirAndWaterVehicleFueling.refuel_button) then
                                 -- Trigger Refuel Logic
                                 TriggerEvent('cdn-fuel:client:RefuelVehicle', { purchasetype = "cash", fuelamounttotal = 100, isAirSea = true })
                             end
                             if not IsPedInAnyVehicle(PlayerPedId()) then break end
                         end
                     end)
]]
                     end
                 end
            end
        else
            if Config.Ox.DrawText then lib.hideTextUI() else exports[Config.Core]:HideText() end
        end
    end)
    
    -- Store for cleanup?
    -- AirSeaFuelZones[GeneratedName] = Zone
end)
