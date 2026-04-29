-- Variables
local QBCore = exports[Config.Core]:GetCoreObject()

-- Functions
local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

--- Events
if Config.RenewedPhonePayment then
	RegisterNetEvent('cdn-fuel:server:phone:givebackmoney', function(amount)
		local src = source
		local player = QBCore.Functions.GetPlayer(src)
		player.Functions.AddMoney("bank", math.ceil(amount), Lang:t("phone_refund_payment_label"))
	end)
end

RegisterNetEvent("cdn-fuel:server:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice, location, fuelType)
	local src = source
	if not src then return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then return end
	local amount = tonumber(amount)
    local FuelPrice = tonumber(FuelPrice)
    if not amount or not FuelPrice then 
        if Config.FuelDebug then print("Amount or FuelPrice is invalid!", amount, FuelPrice) end 
        return 
    end
	local FuelCost = amount*FuelPrice
	local tax = GlobalTax(FuelCost)
	local total = tonumber(FuelCost + tax)
	if inGasStation == true and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:phone:PayForFuel", src, amount, fuelType)
		else
			if Config.FuelDebug then print("Skipping context menu (NUI override), starting refuel.") end
			TriggerClientEvent('cdn-fuel:client:RefuelVehicle', src, {
				fuelamounttotal = amount,
				purchasetype = purchasetype,
                location = location,
                fuelType = fuelType
			})

		end
	end
end)

RegisterNetEvent("cdn-fuel:server:PayForFuel", function(amount, purchasetype, FuelPrice, electric, cachedPrice, location, liters, fuelType)
	local src = source
	if not src then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	local total = math.ceil(amount)
	if amount < 1 then
		total = 0
	end
    
    local fuelType = fuelType or "gasoline"
	
    -- Sales Logging
    if location and location ~= 0 then
        local buyerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        local fuelAmount = liters or 0
        if (not fuelAmount or fuelAmount == 0) and FuelPrice and FuelPrice > 0 then
             fuelAmount = math.floor((total / (FuelPrice + GlobalTax(FuelPrice))) * 100) / 100
        end

        local insertData = "INSERT INTO fuel_station_sales (station_location, buyer_name, amount, cost, payment_type) VALUES (?, ?, ?, ?, ?)"
        MySQL.Async.execute(insertData, {location, buyerName, fuelAmount, total, purchasetype})

        -- Update Station Balance & Deduct Stock if owned
        if Config.PlayerOwnedGasStationsEnabled then
             -- Update Balance
             MySQL.Async.execute('UPDATE fuel_stations SET balance = balance + ? WHERE location = ? AND owned = 1', {total, location})
             
             -- Deduct Stock or Add Electric Consumption
             if fuelAmount > 0 then
                if not electric then
                    -- Deduct from specific stock based on fuelType
                    local stockColumn = "fuel" -- Default Gasoline
                    if fuelType == "diesel" then stockColumn = "diesel"
                    elseif fuelType == "ethanol" then stockColumn = "ethanol"
                    elseif fuelType == "aviation" then stockColumn = "fuel" -- Aviation usually uses main stock or dedicated
                    end
                    
                    MySQL.Async.execute(string.format('UPDATE fuel_stations SET %s = %s - ? WHERE location = ? AND owned = 1', stockColumn, stockColumn), {fuelAmount, location})
                else
                    -- Track kWh consumption for the owner to pay later
                    MySQL.Async.execute('UPDATE fuel_stations SET electric_consumed = electric_consumed + ? WHERE location = ? AND owned = 1', {fuelAmount, location})
                end
             end
        end
    end

	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	local payString = Lang:t("menu_pay_label_1") ..FuelPrice..Lang:t("menu_pay_label_2")
	if electric then payString = Lang:t("menu_electric_payment_label_1") ..FuelPrice..Lang:t("menu_electric_payment_label_2") end
	Player.Functions.RemoveMoney(moneyremovetype, total, payString)
end)

-- [ SISTEMA DE MAPEAMENTO DE COMBUSTÍVEL ]
local VehicleFuelMappings = {}

local function LoadVehicleFuelMappings()
    MySQL.Async.fetchAll('SELECT * FROM fuel_vehicle_mappings', {}, function(results)
        VehicleFuelMappings = {}
        if results then
            for _, data in ipairs(results) do
                VehicleFuelMappings[data.name:upper()] = {
                    fuel_type = data.fuel_type,
                    is_model = data.is_model == 1
                }
            end
        end
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        LoadVehicleFuelMappings()
    end
end)

QBCore.Functions.CreateCallback('cdn-fuel:server:GetVehicleFuelType', function(source, cb, model, class)
    local model = tostring(model):upper()
    local className = Config.VehicleClasses[class] or tostring(class)
    
    -- 1. Check specific model mapping
    if VehicleFuelMappings[model] then
        cb(VehicleFuelMappings[model].fuel_type)
        return
    end
    
    -- 2. Check class mapping
    if VehicleFuelMappings[className] then
        cb(VehicleFuelMappings[className].fuel_type)
        return
    end
    
    -- 3. Fallback to config defaults
    cb(Config.ClassFuelDefaults[class] or 'gasoline')
end)

QBCore.Functions.CreateCallback('cdn-fuel:server:GetMappings', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM fuel_vehicle_mappings', {}, function(results)
        cb(results or {})
    end)
end)

local VehicleClassesList = {
    "Compacts", "Sedans", "SUVs", "Coupes", "Muscle", "Sports Classics", 
    "Sports", "Super", "Motorcycles", "Off-Road", "Industrial", "Utility", 
    "Vans", "Cycles", "Boats", "Helicopters", "Planes", "Service", "Emergency", 
    "Military", "Commercial", "Trains", "Open Wheel"
}

QBCore.Functions.CreateCallback('cdn-fuel:server:SaveMapping', function(source, cb, data)
    local src = source
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then return end
    
    local name = data.name:upper()
    local fuelType = data.fuel_type
    local isModel = data.is_model

    MySQL.Async.execute('INSERT INTO fuel_vehicle_mappings (name, fuel_type, is_model) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE fuel_type = ?', 
        {name, fuelType, isModel and 1 or 0, fuelType}, function(rowsChanged)
        LoadVehicleFuelMappings()
        MySQL.Async.fetchAll('SELECT * FROM fuel_vehicle_mappings', {}, function(newMappings)
            cb(newMappings)
        end)
    end)
end)

QBCore.Functions.CreateCallback('cdn-fuel:server:DeleteMapping', function(source, cb, data)
    local src = source
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then return end
    
    local name = data.name:upper()

    MySQL.Async.execute('DELETE FROM fuel_vehicle_mappings WHERE name = ?', {name}, function(rowsChanged)
        LoadVehicleFuelMappings()
        MySQL.Async.fetchAll('SELECT * FROM fuel_vehicle_mappings', {}, function(newMappings)
            cb(newMappings)
        end)
    end)
end)

QBCore.Functions.CreateCallback('cdn-fuel:server:GetMappingAdminData', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM fuel_vehicle_mappings', {}, function(results)
        cb({
            mappings = results or {},
            classes = VehicleClassesList
        })
    end)
end)

-- Command to manage fuel mappings via NUI
QBCore.Commands.Add('fueladmin', 'Abrir painel de gerenciamento de combustíveis', {}, false, function(source)
    TriggerClientEvent('cdn-fuel:client:OpenMappingAdmin', source)
end, 'admin')

RegisterNetEvent("cdn-fuel:server:purchase:jerrycan", function(purchasetype, amount, location, isAviation, fuelType)
	local src = source if not src then return end
    local amount = amount or 1
	local Player = QBCore.Functions.GetPlayer(src) if not Player then return end
    local fuelType = fuelType or (isAviation and "aviation" or "gasoline")
	
    local basePrice = isAviation and Config.AviationJerryCanPrice or Config.JerryCanPrice
    local tax = GlobalTax(basePrice) 
    local total = math.ceil((basePrice + tax) * amount)
	local moneyremovetype = (purchasetype == "bank") and "bank" or "cash"

    if Player.Functions.GetMoney(moneyremovetype) < total then
        TriggerClientEvent('QBCore:Notify', src, "Dinheiro insuficiente!", "error")
        return
    end

    -- Sales Logging & Station Balance
    if location and location ~= 0 then
        local buyerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        local capacity = isAviation and Config.AviationJerryCanGas or Config.JerryCanGas
        local fuelToDeduct = (capacity or 0) * (amount or 1)
        
        -- Log the total fuel amount (Liters), not the quantity of items
        local insertData = "INSERT INTO fuel_station_sales (station_location, buyer_name, amount, cost, payment_type) VALUES (?, ?, ?, ?, ?)"
        MySQL.Async.execute(insertData, {location, buyerName, fuelToDeduct, total, purchasetype})

        -- Update Station Balance & Deduct Stock if owned
        if Config.PlayerOwnedGasStationsEnabled then
             -- Update Balance
             MySQL.Async.execute('UPDATE fuel_stations SET balance = balance + ? WHERE location = ? AND owned = 1', {total, location})
             
             -- Deduct Stock
             if fuelToDeduct > 0 then
                 local stockColumn = "fuel"
                 if fuelType == "diesel" then stockColumn = "diesel"
                 elseif fuelType == "ethanol" then stockColumn = "ethanol"
                 elseif fuelType == "aviation" then stockColumn = "fuel"
                 end
                 
                 MySQL.Async.execute(string.format('UPDATE fuel_stations SET %s = %s - ? WHERE location = ? AND owned = 1', stockColumn, stockColumn), {fuelToDeduct, location})
             end
        end
    end

	local itemName = 'jerrycan'
	local capacity = isAviation and Config.AviationJerryCanGas or Config.JerryCanGas
    local fuelLabel = fuelType:gsub("^%l", string.upper)
    if fuelType == "aviation" then fuelLabel = "Jet A-1" end

    local amount = tonumber(amount) or 1

    print(string.format("[cdn-fuel] INFO: Purchasing Jerry Can: Item=%s, Amount=%s, FuelType=%s, TotalCost=%s", itemName, amount, fuelType, total)) 
    if not QBCore.Shared.Items[itemName] then
        print(string.format("[cdn-fuel] ERROR: Item '%s' does not exist in QBCore.Shared.Items!", itemName))
    end

	if Config.Ox.Inventory then
        local label = "Galão de " .. fuelLabel
		local info = {
            _fuel = tostring(capacity),
            fuel_type = fuelType,
            label = label,
            description = string.format("Tipo: %s  \nCombustivel: %sL", fuelLabel, capacity)
        }
		if exports.ox_inventory:AddItem(src, itemName, amount, info) then
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
            if Config.FuelDebug then print("[DEBUG] Jerry Can added successfully to Ox Inventory") end
		else
            if Config.FuelDebug then print("[DEBUG] Ox Inventory REJECTED AddItem (Check weight or item existence)") end
            TriggerClientEvent('QBCore:Notify', src, "Erro ao entregar o galão (Inventário cheio?)", "error")
        end
	else
		local info = {
            gasamount = capacity,
            fuel_type = fuelType
        }
		if Player.Functions.AddItem(itemName, amount, false, info) then
			TriggerClientEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], "add", amount)
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
            if Config.FuelDebug then print("[DEBUG] Jerry Can added successfully to QB Inventory") end
		else
            if Config.FuelDebug then print("[DEBUG] QB Inventory REJECTED AddItem (Check weight or item existence)") end
            TriggerClientEvent('QBCore:Notify', src, "Erro ao entregar o galão (Inventário cheio?)", "error")
        end
	end
end)

--- Jerry Can
if Config.UseJerryCan then
	QBCore.Functions.CreateUseableItem("jerrycan", function(source, item)
		local src = source
		if Config.Ox.Inventory then
            local updated = false
			if not item.metadata or item.metadata._fuel == nil then
				item.metadata = item.metadata or {}
				item.metadata._fuel = '0'
                updated = true
			end
            if not item.metadata.fuel_type then
                item.metadata.fuel_type = 'gasoline' -- Default to gasoline if missing
                updated = true
            end
            if not item.metadata.label then
                item.metadata.label = item.metadata.fuel_type == 'aviation' and "Galão de Jet A-1" or "Galão de Gasolina"
                updated = true
            end
            if not item.metadata.description or updated then
                item.metadata.description = string.format("**Tipo**: %s  \n**Combustível**: %sL", item.metadata.fuel_type:gsub("^%l", string.upper), item.metadata._fuel or '0')
                updated = true
            end
            if updated then
                exports.ox_inventory:SetMetadata(src, item.slot, item.metadata)
            end
		end
		TriggerClientEvent('cdn-fuel:jerrycan:refuelmenu', src, item)
	end)
end

--- Syphoning
if Config.UseSyphoning then
	QBCore.Functions.CreateUseableItem("syphoningkit", function(source, item)
		local src = source
		if Config.Ox.Inventory then
			if item.metadata._fuel == nil or not item.metadata.description then
				item.metadata._fuel = item.metadata._fuel or '0'
                item.metadata.description = string.format("**Combustível**: %sL", item.metadata._fuel)
				exports.ox_inventory:SetMetadata(src, item.slot, item.metadata)
			end
		end
		TriggerClientEvent('cdn-syphoning:syphon:menu', src, item)
	end)
end

RegisterNetEvent('cdn-fuel:info', function(type, amount, srcPlayerData, itemdata, newFuelType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local srcPlayerData = srcPlayerData
	local ItemName = itemdata.name

	if Config.Ox.Inventory then
		if itemdata == "jerrycan" or itemdata == "syphoningkit" then
			if amount < 1 or amount > (itemdata == "jerrycan" and Config.JerryCanCap or Config.SyphonKitCap) then return end
		end
		if ItemName ~= nil then
			-- Ignore --
			itemdata.metadata = itemdata.metadata
			itemdata.slot = itemdata.slot
			if ItemName == 'jerrycan' then
				local fuel_amount = tonumber(itemdata.metadata._fuel)
                local fuel_type = newFuelType or itemdata.metadata.fuel_type or 'gasoline'
                local fuelLabel = fuel_type:gsub("^%l", string.upper)
                if fuel_type == "aviation" then fuelLabel = "Jet A-1" end
                local label = "Galão de " .. fuelLabel
				if type == "add" then
					fuel_amount = fuel_amount + amount
				elseif type == "remove" then
					fuel_amount = fuel_amount - amount
				end
                itemdata.metadata._fuel = tostring(fuel_amount)
                itemdata.metadata.fuel_type = fuel_type
                itemdata.metadata.label = label
                itemdata.metadata.description = string.format("Tipo: %s  \nCombustivel: %sL", fuelLabel, fuel_amount)
                exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			elseif ItemName == 'syphoningkit' then
				local fuel_amount = tonumber(itemdata.metadata._fuel)
				if type == "add" then
					fuel_amount = fuel_amount + amount
				elseif type == "remove" then
					fuel_amount = fuel_amount - amount
				end
                itemdata.metadata._fuel = tostring(fuel_amount)
                itemdata.metadata.description = string.format("**Combustível**: %sL", fuel_amount)
                exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			end
		end
	else
		if itemdata.info.name == "jerrycan" then
			if amount < 1 or amount > Config.JerryCanCap then return end
		elseif itemdata.info.name == "syphoningkit" then
			if amount < 1 or amount > Config.SyphonKitCap then return end
		end

		if type == "add" then
			if not srcPlayerData.items[itemdata.slot].info.gasamount then
				srcPlayerData.items[itemdata.slot].info = {
					gasamount = amount,
                    fuel_type = newFuelType or 'gasoline'
				}
			else
				srcPlayerData.items[itemdata.slot].info.gasamount = srcPlayerData.items[itemdata.slot].info.gasamount + amount
                if newFuelType then srcPlayerData.items[itemdata.slot].info.fuel_type = newFuelType end
			end
			Player.Functions.SetInventory(srcPlayerData.items)
		elseif type == "remove" then
			srcPlayerData.items[itemdata.slot].info.gasamount = srcPlayerData.items[itemdata.slot].info.gasamount - amount
			Player.Functions.SetInventory(srcPlayerData.items)
		else
			if Config.SyphonDebug then print("error, type is invalid!") end
		end
	end
end)

RegisterNetEvent('cdn-syphoning:callcops', function(coords)
    TriggerClientEvent('cdn-syphoning:client:callcops', -1, coords)
end)
