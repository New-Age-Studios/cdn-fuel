local QBCore = exports[Config.Core]:GetCoreObject()

props = {
	"prop_gas_pump_1d",
	"prop_gas_pump_1a",
	"prop_gas_pump_1b",
	"prop_gas_pump_1c",
	"prop_vintage_pump",
	"prop_gas_pump_old2",
	"prop_gas_pump_old3",
	"denis3d_prop_gas_pump", -- Gabz Ballas Gas Station Pump.
	"prop_gas_tank_02a",    -- Aviation Tank
}

function GetClosestPump(coords, isElectric)
	if isElectric then
		local electricPump = nil
		electricPump = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, joaat(Config.ElectricChargerModel), true, true, true)
		local pumpCoords = GetEntityCoords(electricPump)
		return pumpCoords, electricPump
	else
		local pump = nil
		local pumpCoords
		for i = 1, #props, 1 do
			local currentPumpModel = props[i]
			pump = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, joaat(currentPumpModel), true, true, true)
			pumpCoords = GetEntityCoords(pump)
			if pump ~= 0 then break end
		end
		return pumpCoords, pump
	end
end

-- Wrong Fuel Damage Thread
CreateThread(function()
    while true do
        local sleep = 2000
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local state = Entity(vehicle).state
            if state.wrong_fuel then
                sleep = 1000
                local engineHealth = GetVehicleEngineHealth(vehicle)
                if Config.FuelDebug then print("[DEBUG] VEHICLE HAS WRONG FUEL! Engine Health: " .. engineHealth) end
                if engineHealth > 100.0 then
                    local damage = Config.WrongFuelDamage and Config.WrongFuelDamage.DamagePerSecond or 5.0
                    SetVehicleEngineHealth(vehicle, engineHealth - damage) -- Damage engine
                    if engineHealth < 400.0 then
                        SetVehicleEngineOn(vehicle, false, true, true) -- Start failing
                    end
                    if Config.FuelDebug then print("[DEBUG] Wrong Fuel Damage: Engine Health = " .. engineHealth) end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('testwrongfuel', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        Entity(vehicle).state:set('wrong_fuel', true, true)
        QBCore.Functions.Notify("DEBUG: Estado 'wrong_fuel' aplicado ao veículo!", "success")
    else
        QBCore.Functions.Notify("Entre em um veículo primeiro!", "error")
    end
end, false)

-- Vehicle Entry Debug & State Sync
local lastVeh = nil
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 and vehicle ~= lastVeh then
            lastVeh = vehicle
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):upper()
            local class = GetVehicleClass(vehicle)
            
            QBCore.Functions.TriggerCallback('cdn-fuel:server:GetVehicleFuelType', function(fuelType)
                local hasWrongFuel = Entity(vehicle).state.wrong_fuel
                local statusMsg = hasWrongFuel and "STATUS: [ERRO DE COMBUSTÍVEL]" or "STATUS: [OK]"
                
                if Config.FuelDebug then
                    QBCore.Functions.Notify(string.format("VEÍCULO: %s | TIPO: %s | %s", model, fuelType, statusMsg), "primary", 5000)
                    print(string.format("[DEBUG] Entry: Model=%s, Class=%s, FuelType=%s, WrongFuel=%s", model, class, fuelType, tostring(hasWrongFuel)))
                end
            end, model, class)
        elseif vehicle == 0 then
            lastVeh = nil
        end
        Wait(2000)
    end
end)

function GetFuel(vehicle)
	return DecorGetFloat(vehicle, Config.FuelDecor)
end

function SetFuel(vehicle, fuel)
	if type(fuel) == 'number' and fuel >= 0 and fuel <= 100 then
		SetVehicleFuelLevel(vehicle, fuel + 0.0)
		DecorSetFloat(vehicle, Config.FuelDecor, GetVehicleFuelLevel(vehicle))
	end
end

function LoadAnimDict(dict)
	while (not HasAnimDictLoaded(dict)) do
		RequestAnimDict(dict)
		Wait(5)
	end
end

function GlobalTax(value)
	if Config.GlobalTax < 0.1 then
		return 0
	end
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

function Comma_Value(amount)
	local formatted = amount
	while true do
	  formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	  if (k==0) then
		break
	  end
	end
	return formatted
end

function math.percent(percent, maxvalue)
	if tonumber(percent) and tonumber(maxvalue) then
		return (maxvalue*percent)/100
	end
	return false
end

function Round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function GetCurrentVehicleType(vehicle)
	if not vehicle then
		vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
	end
	if not vehicle then return false end
	local vehModel = GetEntityModel(vehicle)
	local vehiclename = string.lower(GetDisplayNameFromVehicleModel(vehModel))

	if Config.ElectricVehicles[vehiclename] and Config.ElectricVehicles[vehiclename].isElectric then
		return 'electricvehicle'
	else
		return 'gasvehicle'
	end
end

function CreateBlip(coords, label)
	local blip = AddBlipForCoord(coords)
	local vehicle = GetCurrentVehicleType()
	local electricbolt = Config.ElectricSprite -- Sprite
	if vehicle == 'electricvehicle' then
		SetBlipSprite(blip, electricbolt) -- This is where the fuel thing will get changed into the electric bolt instead of the pump.
		SetBlipColour(blip, 5)
	else
		SetBlipSprite(blip, 361)
		SetBlipColour(blip, 4)
	end
	SetBlipScale(blip, 0.6)
	SetBlipDisplay(blip, 4)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(label)
	EndTextCommandSetBlipName(blip)
	return blip
end

function GetClosestVehicle(coords)
    local ped = PlayerPedId()
    local vehicles = GetGamePool('CVehicle')
    local closestDistance = -1
    local closestVehicle = -1
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    for i = 1, #vehicles, 1 do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestVehicle = vehicles[i]
            closestDistance = distance
        end
    end
    return closestVehicle, closestDistance
end


function IsPlayerNearVehicle()
	if Config.FuelDebug then
		print("Checking if player is near a vehicle!")
	end
	local vehicle = GetClosestVehicle()
	local closestVehCoords = GetEntityCoords(vehicle)
	if #(GetEntityCoords(PlayerPedId(), closestVehCoords)) > 3.0 then
		return true
	end
	return false
end

function IsVehicleBlacklisted(veh, vehName)
	if Config.FuelDebug then print("IsVehicleBlacklisted("..tostring(veh)..")") end
	if veh and veh ~= 0 then
		local modelName = vehName or string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
		if Config.FuelDebug then print("Vehicle: "..modelName) end
		-- Puts Vehicles In Blacklist if you have electric charging on.
		if not Config.ElectricVehicleCharging then
			if Config.ElectricVehicles[modelName] and Config.ElectricVehicles[modelName].isElectric then
				if Config.FuelDebug then print("Vehicle: "..modelName.." is in the Blacklist.") end
				return true
			end
		end

		if Config.NoFuelUsage[modelName] and Config.NoFuelUsage[modelName].blacklisted then
			if Config.FuelDebug then print("Vehicle: "..modelName.." is in the Blacklist.") end
			-- If the veh equals a vehicle in the list then return true.
			return true
		end

		-- Default False
		if Config.FuelDebug then print("Vehicle is not blacklisted.") end
		return false
	else
		if Config.FuelDebug then print("veh is nil!") end
		return false
	end
end

function HexToRGB(hex)
    hex = hex:gsub("#","")
    local r, g, b, a
    if #hex == 8 then
        r = tonumber("0x"..hex:sub(1,2))
        g = tonumber("0x"..hex:sub(3,4))
        b = tonumber("0x"..hex:sub(5,6))
        a = tonumber("0x"..hex:sub(7,8))
    else
        r = tonumber("0x"..hex:sub(1,2))
        g = tonumber("0x"..hex:sub(3,4))
        b = tonumber("0x"..hex:sub(5,6))
        a = 255
    end
    return { r = r, g = g, b = b, a = a }
end

-- Compatibility for scripts still using Config.HexToRGB
Config.HexToRGB = HexToRGB