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

RegisterNetEvent("cdn-fuel:server:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice, location)
	local src = source
	if not src then return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then return end
	if not amount then if Config.FuelDebug then print("Amount is invalid!") end TriggerClientEvent('QBCore:Notify', src, Lang:t("more_than_zero"), 'error') return end
	local FuelCost = amount*FuelPrice
	local tax = GlobalTax(FuelCost)
	local total = tonumber(FuelCost + tax)
	if inGasStation == true and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:phone:PayForFuel", src, amount)
		else
			if Config.FuelDebug then print("Skipping context menu (NUI override), starting refuel.") end
			TriggerClientEvent('cdn-fuel:client:RefuelVehicle', src, {
				fuelamounttotal = amount,
				purchasetype = purchasetype,
                location = location
			})

		end
	end
end)

RegisterNetEvent("cdn-fuel:server:PayForFuel", function(amount, purchasetype, FuelPrice, electric, cachedPrice, location, liters)
	local src = source
	if not src then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	local total = math.ceil(amount)
	if amount < 1 then
		total = 0
	end
	
    -- Sales Logging
    if not location or location == 0 then
        -- Fallback: try to find location by proximity if not passed (useful for some electric chargers)
        -- We can't easily do it here without coordinates, but usually location should be passed.
        if Config.FuelDebug then print("[CDN-FUEL] Warning: PayForFuel called with Location 0/nil") end
    end

    if location and location ~= 0 then
        local buyerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        local fuelAmount = liters or 0
        if (not fuelAmount or fuelAmount == 0) and FuelPrice and FuelPrice > 0 then
             -- Liter/kWh Amount = Total Money / (Price + Tax)
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
                    MySQL.Async.execute('UPDATE fuel_stations SET fuel = fuel - ? WHERE location = ? AND owned = 1', {fuelAmount, location})
                else
                    -- Track kWh consumption for the owner to pay later
                    MySQL.Async.execute('UPDATE fuel_stations SET electric_consumed = electric_consumed + ? WHERE location = ? AND owned = 1', {fuelAmount, location})
                    if Config.FuelDebug then print("[CDN-FUEL] Tracked "..fuelAmount.." kWh for Station #"..location) end
                end
             end
        end
    end

	local moneyremovetype = purchasetype
	if Config.FuelDebug then print("Player is attempting to purchase fuel with the money type: " ..moneyremovetype) end
	if Config.FuelDebug then print("Attempting to charge client: $"..total.." for Fuel @ "..FuelPrice.." PER LITER | PER KW") end
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	local payString = Lang:t("menu_pay_label_1") ..FuelPrice..Lang:t("menu_pay_label_2")
	if electric then payString = Lang:t("menu_electric_payment_label_1") ..FuelPrice..Lang:t("menu_electric_payment_label_2") end
	Player.Functions.RemoveMoney(moneyremovetype, total, payString)
end)

RegisterNetEvent("cdn-fuel:server:purchase:jerrycan", function(purchasetype, amount, location, isAviation)
	local src = source if not src then return end
    local amount = amount or 1
	local Player = QBCore.Functions.GetPlayer(src) if not Player then return end
	
    local basePrice = isAviation and Config.AviationJerryCanPrice or Config.JerryCanPrice
    local tax = GlobalTax(basePrice) 
    local total = math.ceil((basePrice + tax) * amount)
	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
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
                 MySQL.Async.execute('UPDATE fuel_stations SET fuel = fuel - ? WHERE location = ? AND owned = 1', {fuelToDeduct, location})
             end
        end
    end

	local itemName = 'jerrycan' -- Always use 'jerrycan' item
	local capacity = isAviation and Config.AviationJerryCanGas or Config.JerryCanGas
    local fuelType = isAviation and "aviation" or "gasoline"

	if Config.Ox.Inventory then
        local label = isAviation and "Galão de Jet A-1" or "Galão de Gasolina"
		local info = {
            _fuel = tostring(capacity),
            fuel_type = fuelType,
            label = label,
            description = string.format("**Tipo**: %s  \n**Combustível**: %sL", fuelType:gsub("^%l", string.upper), capacity)
        }
		exports.ox_inventory:AddItem(src, itemName, amount, info)
		local hasItem = exports.ox_inventory:GetItem(src, itemName, info, 1)
		if hasItem then
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
		end
	else
		local info = {
            gasamount = capacity,
            fuel_type = fuelType
        }
		if Player.Functions.AddItem(itemName, amount, false, info) then
			TriggerClientEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], "add", amount)
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
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
                local label = fuel_type == 'aviation' and "Galão de Jet A-1" or "Galão de Gasolina"
				if type == "add" then
					fuel_amount = fuel_amount + amount
				elseif type == "remove" then
					fuel_amount = fuel_amount - amount
				end
                itemdata.metadata._fuel = tostring(fuel_amount)
                itemdata.metadata.fuel_type = fuel_type
                itemdata.metadata.label = label
                itemdata.metadata.description = string.format("**Tipo**: %s  \n**Combustível**: %sL", fuel_type:gsub("^%l", string.upper), fuel_amount)
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
