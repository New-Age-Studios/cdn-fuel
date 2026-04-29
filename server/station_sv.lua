if Config.PlayerOwnedGasStationsEnabled then -- This is so Player Owned Gas Stations are a Config Option, instead of forced. Set this option in shared/config.lua!
    
    -- Variables
    local QBCore = exports[Config.Core]:GetCoreObject()
    local FuelPickupSent = {} -- This is in case of an issue with vehicles not spawning when picking up vehicles.

    -- Functions
    local function GetAdjustedTime()
        -- Use os.date("!*t") to get UTC time as a base, then apply offset
        local utcSeconds = os.time(os.date("!*t"))
        local offset = Config.TimezoneOffsets[Config.Timezone] or 0
        return os.date('%Y-%m-%d %H:%M:%S', utcSeconds + offset)
    end

    local function GlobalTax(value)
        local tax = (value / 100 * Config.GlobalTax)
        return tax
    end

    function math.percent(percent, maxvalue)
        if tonumber(percent) and tonumber(maxvalue) then
            return (maxvalue*percent)/100
        end
        return false
    end

    local function UpdateStationLabel(location, newLabel, src)
        if not newLabel or newLabel == nil then
            if Config.FuelDebug then print('Attempting to fetch label for Location #'..location) end
            MySQL.Async.fetchAll('SELECT label FROM fuel_stations WHERE location = ?', {location}, function(result)
                if result then
                    local data = result[1]
                    if data == nil then return end
                    local newLabel = data.label
                    TriggerClientEvent('cdn-fuel:client:updatestationlabels', -1, location, newLabel)
                else
                    if Config.FuelDebug then print('No Result! (UpdateStationLabel() line 29 station_sv.lua)') end
                    cb(false)
                end
            end)
        else
            if Config.FuelDebug then print(newLabel, location) end
            MySQL.Async.execute('UPDATE fuel_stations SET label = ? WHERE `location` = ?', {newLabel, location})
            if src then
                TriggerClientEvent('cdn-fuel:client:updatestationlabels', src, location, newLabel)
            else
                TriggerClientEvent('cdn-fuel:client:updatestationlabels', -1, location, newLabel)
            end
        end
    end
    
    -- Events
    RegisterNetEvent('cdn-fuel:server:updatelocationlabels', function()
        local src = source
        MySQL.Async.fetchAll('SELECT location, label FROM fuel_stations', {}, function(results)
            if results then
                for _, data in ipairs(results) do
                    if data.location and data.label then
                        TriggerClientEvent('cdn-fuel:client:updatestationlabels', src, data.location, data.label)
                    end
                end
            end
        end)
    end)

    RegisterNetEvent('cdn-fuel:server:buyStation', function(location, CitizenID)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local CostOfStation = Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost)
        if Player.Functions.RemoveMoney("bank", CostOfStation, Lang:t("station_purchased_location_payment_label")..Config.GasStations[location].label) then
            MySQL.Async.execute('UPDATE fuel_stations SET owned = ?, owner = ?, fuel = ? WHERE `location` = ?', {1, CitizenID, Config.DefaultFuelOnPurchase or 5000, location})
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:server:sellstation', function(location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local GasStationCost = Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost)
        local SalePrice = math.percent(Config.GasStationSellPercentage, GasStationCost)
        if Player.Functions.AddMoney("bank", SalePrice, Lang:t("station_sold_location_payment_label")..Config.GasStations[location].label) then
            MySQL.Async.execute('UPDATE fuel_stations SET owned = ? WHERE `location` = ?', {0, location})
            MySQL.Async.execute('UPDATE fuel_stations SET owner = ? WHERE `location` = ?', {0, location})
            TriggerClientEvent('QBCore:Notify', src, Lang:t("station_sold_success"), 'success')

        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("station_cannot_sell"), 'error')
        end
    end)

    RegisterNetEvent('cdn-fuel:station:server:Withdraw', function(amount, location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        -- Fetch fresh balance from DB for safety
        local result = MySQL.Sync.fetchAll('SELECT balance FROM fuel_stations WHERE `location` = ?', {location})
        if not result or not result[1] then return end
        
        local StationBalance = result[1].balance
        local setamount = (StationBalance - amount)
        
        if Config.FuelDebug then print("Attempting to withdraw $"..amount.." from Location #"..location.."'s Balance!") end
        if amount > StationBalance then TriggerClientEvent('QBCore:Notify', src, Lang:t("station_withdraw_too_much"), 'error') return end
        
        MySQL.Async.execute('UPDATE fuel_stations SET balance = ? WHERE `location` = ?', {setamount, location})
        
        -- Log Transaction
        MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', {location, "Saque", amount, GetAdjustedTime()})

        Player.Functions.AddMoney("bank", amount, Lang:t("station_withdraw_payment_label")..Config.GasStations[location].label)
        TriggerClientEvent('QBCore:Notify', src, Lang:t("station_success_withdrew_1")..amount..Lang:t("station_success_withdrew_2"), 'success')
        
        -- Update NUI
        TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { balance = setamount })
    end)

    RegisterNetEvent('cdn-fuel:station:server:Deposit', function(amount, location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        -- Fetch fresh balance from DB for safety
        local result = MySQL.Sync.fetchAll('SELECT balance FROM fuel_stations WHERE `location` = ?', {location})
        if not result or not result[1] then return end
        
        local StationBalance = result[1].balance
        local setamount = (StationBalance + amount)
        
        if Config.FuelDebug then print("Attempting to deposit $"..amount.." to Location #"..location.."'s Balance!") end
        if Player.Functions.RemoveMoney("bank", amount, Lang:t("station_deposit_payment_label")..Config.GasStations[location].label) then
            MySQL.Async.execute('UPDATE fuel_stations SET balance = ? WHERE `location` = ?', {setamount, location})
            
            -- Log Transaction
            MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', {location, "Depósito", amount, GetAdjustedTime()})

            TriggerClientEvent('QBCore:Notify', src, Lang:t("station_success_deposit_1")..amount..Lang:t("station_success_deposit_2"), 'success')
            
            -- Update NUI
            TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { balance = setamount })
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("station_cannot_afford_deposit")..amount.."!", 'error')
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:server:Shutoff', function(location)
        local src = source
        if Config.FuelDebug then print("Toggling Emergency Shutoff Valves for Location #"..location) end
        Config.GasStations[location].shutoff = not Config.GasStations[location].shutoff
        
        -- Persist to Database
        local shutoffState = Config.GasStations[location].shutoff and 1 or 0
        MySQL.Async.execute('UPDATE fuel_stations SET shutoff = ? WHERE location = ?', {shutoffState, location})

        Wait(5)
        TriggerClientEvent('QBCore:Notify', src, Lang:t("station_shutoff_success"), 'success')
        if Config.FuelDebug then print('Successfully altered the shutoff valve state for location #'..location..'!') end
        if Config.FuelDebug then print(Config.GasStations[location].shutoff) end
    end)

    RegisterNetEvent('cdn-fuel:station:server:updatefuelprice', function(fuelprice, location, fuelType)
        local src = source
        local fuelType = fuelType or "gasoline"
        local column = "fuelprice"
        if fuelType == "diesel" then column = "dieselprice"
        elseif fuelType == "ethanol" then column = "ethanolprice" end
        
        if Config.FuelDebug then print('Attempting to update Location #'..location.."'s "..fuelType.." Price to a new price: $"..fuelprice) end
        MySQL.Async.execute(string.format('UPDATE fuel_stations SET %s = ? WHERE `location` = ?', column), {fuelprice, location})
        TriggerClientEvent('QBCore:Notify', src, Lang:t("station_fuel_price_success")..fuelprice..Lang:t("station_per_liter"), 'success')
        
        -- Update NUI
        local updateData = {}
        updateData[fuelType == "gasoline" and "fuelPrice" or fuelType.."Price"] = fuelprice
        TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, updateData)
    end)

    RegisterNetEvent('cdn-fuel:station:server:buyUpgrade', function(data)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local location = data.location
        local level = data.level
        local price = data.price

        if not location or not level then return end

        -- Fetch fresh balance and current level for safety
        local result = MySQL.Sync.fetchAll('SELECT balance, stock_level FROM fuel_stations WHERE `location` = ?', {location})
        if not result or not result[1] then return end
        
        local stationBalance = result[1].balance
        local currentLevel = result[1].stock_level or 0

        if level <= currentLevel then
            TriggerClientEvent('QBCore:Notify', src, "Você já possui este upgrade ou um nível superior!", 'error')
            return
        end

        if stationBalance < price then
            TriggerClientEvent('QBCore:Notify', src, "O posto não tem saldo suficiente no caixa para este upgrade!", 'error')
            return
        end

        local newBalance = stationBalance - price
        MySQL.Async.execute('UPDATE fuel_stations SET balance = ?, stock_level = ? WHERE `location` = ?', {newBalance, level, location}, function(rowsChanged)
            if rowsChanged > 0 then
                -- Log Transaction
                MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', {location, "Upgrade de Estoque", price, GetAdjustedTime()})
                
                local newCapacity = Config.StationUpgrades and Config.StationUpgrades[level] and Config.StationUpgrades[level].capacity or "N/A"
                TriggerClientEvent('QBCore:Notify', src, "Upgrade realizado com sucesso! Nova capacidade: " .. newCapacity .. "L", 'success')
                
                -- Update NUI for the player
                local upgrades = {}
                if Config.StationUpgrades then
                    for k, v in pairs(Config.StationUpgrades) do
                        table.insert(upgrades, { level = k, label = v.label, capacity = v.capacity, price = v.price })
                    end
                end
                table.sort(upgrades, function(a, b) return a.level < b.level end)

                TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { 
                    balance = newBalance, 
                    stockLevel = level, 
                    maxStock = Config.StationUpgrades and Config.StationUpgrades[level] and Config.StationUpgrades[level].capacity or Config.MaxFuelReserves,
                    upgrades = upgrades
                })
            end
        end)
    end)

    RegisterNetEvent('cdn-fuel:station:server:buyLoyaltyUpgrade', function(data)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local location = data.location
        local level = data.level
        local price = data.price

        if not location or not level then return end

        -- Fetch fresh balance and current level for safety
        local result = MySQL.Sync.fetchAll('SELECT balance, loyalty_level FROM fuel_stations WHERE `location` = ?', {location})
        if not result or not result[1] then return end
        
        local stationBalance = result[1].balance
        local currentLevel = result[1].loyalty_level or 0

        if level <= currentLevel then
            TriggerClientEvent('QBCore:Notify', src, "Você já possui este plano ou um superior!", 'error')
            return
        end

        if stationBalance < price then
            TriggerClientEvent('QBCore:Notify', src, "O posto não tem saldo suficiente no caixa para este plano!", 'error')
            return
        end

        local newBalance = stationBalance - price
        MySQL.Async.execute('UPDATE fuel_stations SET balance = ?, loyalty_level = ? WHERE `location` = ?', {newBalance, level, location}, function(rowsChanged)
            if rowsChanged > 0 then
                -- Log Transaction
                MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', {location, "Plano de Fidelidade", price, GetAdjustedTime()})
                
                local newFuelPrice = Config.LoyaltyUpgrades and Config.LoyaltyUpgrades[level] and Config.LoyaltyUpgrades[level].fuelPrice or "N/A"
                TriggerClientEvent('QBCore:Notify', src, "Plano de fidelidade atualizado! Novo preço por litro: R$" .. newFuelPrice, 'success')
                
                -- Update NUI for the player
                local loyaltyUpgrades = {}
                if Config.LoyaltyUpgrades then
                    for k, v in pairs(Config.LoyaltyUpgrades) do
                        table.insert(loyaltyUpgrades, { level = k, label = v.label, fuelPrice = v.fuelPrice, price = v.price, color = v.color or "#3b82f6" })
                    end
                end
                table.sort(loyaltyUpgrades, function(a, b) return a.level < b.level end)

                TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { 
                    balance = newBalance, 
                    loyaltyLevel = level, 
                    reservePrice = Config.LoyaltyUpgrades and Config.LoyaltyUpgrades[level] and Config.LoyaltyUpgrades[level].fuelPrice or 3.0,
                    loyaltyUpgrades = loyaltyUpgrades
                })
            end
        end)
    end)

    RegisterNetEvent('cdn-fuel:station:server:updatereserves', function(reason, amount, currentlevel, location)
        if reason == "remove" then
            NewLevel = (currentlevel - amount)
        elseif reason == "add" then
            NewLevel = (currentlevel + amount)
        else
            if Config.FuelDebug then print("Reason is not a valid string! It should be 'add' or 'remove'!") end
        end
        if Config.FuelDebug then print('Attempting to '..reason..' '..amount..' to / from Location #'..location.."'s Reserves!") end
        MySQL.Async.execute('UPDATE fuel_stations SET fuel = ? WHERE `location` = ?', {NewLevel, location})
        if Config.FuelDebug then print('Successfully executed the previous SQL Update!') end
    end)

    RegisterNetEvent('cdn-fuel:station:server:updatebalance', function(reason, amount, StationBalance, location, FuelPrice)
        if Config.FuelDebug then print("Amount: "..amount) end
        local Price = (FuelPrice * tonumber(amount))
        local StationGetAmount = math.floor(Config.StationFuelSalePercentage * Price)
        if reason == "remove" then
            NewBalance = (StationBalance - StationGetAmount)
        elseif reason == "add" then
            NewBalance = (StationBalance + StationGetAmount)
        else
            if Config.FuelDebug then print("Reason is not a valid string! It should be 'add' or 'remove'!") end
        end
        if Config.FuelDebug then print('Attempting to '..reason..' '..StationGetAmount..' to / from Location #'..location.."'s Balance!") end
        MySQL.Async.execute('UPDATE fuel_stations SET balance = ? WHERE `location` = ?', {NewBalance, location})
        if Config.FuelDebug then print('Successfully executed the previous SQL Update!') end
    end)


    RegisterNetEvent('cdn-fuel:stations:server:buyreserves', function(location, price, amount, fuelType)
        local location = location
        local price = math.ceil(price)
        local amount = amount
        local src = source
        local fuelType = fuelType or "gasoline"
        local Player = QBCore.Functions.GetPlayer(src)
        local OldBalance = 0
        local ReserveBuyPossible = false
        local NewAmount = 0
        local OldAmount = 0

        local result = MySQL.Sync.fetchAll('SELECT * FROM fuel_stations WHERE `location` = ?', {location})
        if result and result[1] then
            local v = result[1]
            local stockLevel = v.stock_level or 0
            local maxCapacity = Config.StationUpgrades[stockLevel] and Config.StationUpgrades[stockLevel].capacity or Config.MaxFuelReserves
            
            -- Select correct stock column
            local stockColumn = "fuel"
            if fuelType == "diesel" then stockColumn = "diesel"
            elseif fuelType == "ethanol" then stockColumn = "ethanol" end

            OldAmount = tonumber(v[stockColumn]) or 0
            if OldAmount + amount > maxCapacity then
                ReserveBuyPossible = false
                TriggerClientEvent('QBCore:Notify', src, Lang:t("station_reserves_over_max"), 'error')
            else
                OldBalance = tonumber(v.balance) or 0
                if OldBalance >= price then
                    ReserveBuyPossible = true
                    NewAmount = OldAmount + amount
                else
                    ReserveBuyPossible = false
                    TriggerClientEvent('QBCore:Notify', src, 'O posto não tem dinheiro suficiente no caixa para comprar reservas!', 'error')
                end
            end
        end
        
        if ReserveBuyPossible then
            local newBalance = OldBalance - price
            MySQL.Async.execute('UPDATE fuel_stations SET balance = ? WHERE `location` = ?', {newBalance, location})

            -- Log Transaction
            MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', {location, "Compra de " .. fuelType:gsub("^%l", string.upper), price, os.date('%Y-%m-%d %H:%M:%S')})

            if not Config.OwnersPickupFuel then
                local stockColumn = "fuel"
                if fuelType == "diesel" then stockColumn = "diesel"
                elseif fuelType == "ethanol" then stockColumn = "ethanol" end

                MySQL.Async.execute(string.format('UPDATE fuel_stations SET %s = ? WHERE `location` = ?', stockColumn), {NewAmount, location})
                TriggerClientEvent('QBCore:Notify', src, "Reserva comprada com o dinheiro do posto! Descontado: $"..price, 'success')
                
                -- Update NUI
                local updateData = { balance = newBalance }
                updateData[fuelType == "gasoline" and "fuelStock" or fuelType.."Stock"] = NewAmount
                TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, updateData)
            else
                FuelPickupSent[location] = {
                    ['src'] = src,
                    ['refuelAmount'] = NewAmount,
                    ['amountBought'] = amount,
                    ['fuelType'] = fuelType
                }
                -- Compatibility with delivery scripts might need fuelType support
                TriggerClientEvent("md-refuelcdn:client:set", -1, amount, NewAmount, location)
                TriggerEvent("md-refuelcdn:server:set")
                TriggerClientEvent('QBCore:Notify', -1, "Um novo carregamento de "..fuelType.." está disponível!", 'success', 30000)
                TriggerClientEvent('QBCore:Notify', src, "Reserva solicitada com o dinheiro do posto! Descontado: $"..price, 'success')
                
                -- Update NUI
                TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { balance = newBalance })
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:station:server:fuelpickup:failed', function(location)
        local src = source
        if location then
            if FuelPickupSent[location] then
                local cid = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
                MySQL.Async.execute('UPDATE fuel_stations SET fuel = ? WHERE `location` = ?', {FuelPickupSent[location]['refuelAmount'], location})
                TriggerClientEvent('QBCore:Notify', src, Lang:t("fuel_pickup_failed"), 'success')
                -- This will print player information just in case someone figures out a way to exploit this.
                print("User encountered an error with fuel pickup, so we are updating the fuel level anyways, and cancelling the pickup. SQL Execute Update: fuel_station level to: "..FuelPickupSent[location].refuelAmount.. " | Source: "..src.." | Citizen Id: "..cid..".")
                FuelPickupSent[location] = nil
            else
                if Config.FuelDebug then
                    print("`cdn-fuel:station:server:fuelpickup:failed` | FuelPickupSent[location] is not valid! Location: "..location)
                end
                -- They are probably exploiting in some way/shape/form.
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:station:server:fuelpickup:unload', function(location)
        local src = source
        if location then
            if FuelPickupSent[location] then
                MySQL.Async.execute('UPDATE fuel_stations SET fuel = ? WHERE `location` = ?', {FuelPickupSent[location].refuelAmount, location})
                if Config.FuelDebug then
                    print("User unloaded fuel truck, updating station level. SQL Execute Update: fuel_station level to: "..FuelPickupSent[location].refuelAmount.. " | Source: "..src)
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:station:server:fuelpickup:finished', function(location, amount)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local amount = amount * 0.5
        Player.Functions.AddMoney("bank", amount, "Pagamento por Reabastecimento de Posto")
        TriggerClientEvent('QBCore:Notify', src, "Recebeu R$"..amount.." de pagamento pelo serviço!", 'success', 10000)
        exports["cw-rep"]:updateSkill(source, "trucker", 5)
        if location then
            if FuelPickupSent[location] then
                local cid = Player.PlayerData.citizenid
                TriggerClientEvent('QBCore:Notify', src, string.format(Lang:t("fuel_pickup_success"), tostring(tonumber(FuelPickupSent[location].refuelAmount))), 'success')
                -- This will print player information just in case someone figures out a way to exploit this.
                if Config.FuelDebug then
                    print("User successfully returned fuel truck, clearing the pickup table. | Source: "..src.." | Citizen Id: "..cid..".")
                end
                FuelPickupSent[location] = nil
            else
                if Config.FuelDebug then
                    print("FuelPickupSent[location] is not valid! Location: "..location)
                end
                -- They are probably exploiting in some way/shape/form.
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:station:server:updatelocationname', function(newName, location)
        local src = source
        if Config.FuelDebug then print('Attempting to set name for Location #'..location..' to: '..newName) end
        MySQL.Async.execute('UPDATE fuel_stations SET label = ? WHERE `location` = ?', {newName, location})
        
        -- Update Config Server Side
        if Config.GasStations[location] then
            Config.GasStations[location].label = newName
        end

        if Config.FuelDebug then print('Successfully executed the previous SQL Update!') end
        TriggerClientEvent('QBCore:Notify', src, Lang:t("station_name_change_success")..newName.."!", 'success')
        TriggerClientEvent('cdn-fuel:client:updatestationlabels', -1, location, newName)
    end)

    RegisterNetEvent('cdn-fuel:station:server:updatelogo', function(logoUrl, location)
        local src = source
        -- Basic validation
        if not logoUrl or logoUrl == "" then 
            logoUrl = nil 
        end

        MySQL.Async.execute('UPDATE fuel_stations SET logo = ? WHERE `location` = ?', {logoUrl, location})
        
        -- Update Config Server Side
        if Config.GasStations[location] then
            Config.GasStations[location].logo = logoUrl
        end

        TriggerClientEvent('QBCore:Notify', src, "Logo atualizado com sucesso!", 'success')
        TriggerClientEvent('cdn-fuel:client:updatestationlogo', -1, location, logoUrl)
    end)

    -- Callbacks 
    QBCore.Functions.CreateCallback('cdn-fuel:server:locationpurchased', function(source, cb, location)
        if Config.FuelDebug then print("Working on it.") end
        local result = MySQL.Sync.fetchAll('SELECT * FROM fuel_stations WHERE `location` = ?', {location})
        if result then
            for k, v in pairs(result) do
                local gasstationinfo = json.encode(v)
                if Config.FuelDebug then print(gasstationinfo) end
                local owned = false
                if Config.FuelDebug then print(v.owned) end
                if v.owned == 1 then
                    owned = true
                    if Config.FuelDebug then print("Owned Status: True") end
                elseif v.owned == 0 then
                    owned = false
                    if Config.FuelDebug then print("Owned Status: False") end
                else
                    if Config.FuelDebug then print("Owned State (v.owned ~= 1 or 0) It must be 1 or 0! 1 = True, 0 = False!") end
                end
                cb(owned)
            end
        else
            if Config.FuelDebug then print("No Result Fetched!!") end
        end
	end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:doesPlayerOwnStation', function(source, cb)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local citizenid = Player.PlayerData.citizenid
        if Config.FuelDebug then print("Checking if Player Already Owns Another Station...") end
        local result = MySQL.Sync.fetchAll('SELECT * FROM fuel_stations WHERE `owner` = ?', {citizenid})
        local tableEmpty = next(result) == nil
        if result and not tableEmpty then
            if Config.FuelDebug then print("Player already owns another station!") print("Result: "..json.encode(result)) end
            cb(true)
        else
            if Config.FuelDebug then print("No Result Sadge!") end
            cb(false)
        end
	end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:isowner', function(source, cb, location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then cb(false) return end
        local citizenid = Player.PlayerData.citizenid
        if Config.FuelDebug then print("working on it.") end
        local result = MySQL.Sync.fetchAll('SELECT * FROM fuel_stations WHERE `owner` = ? AND location = ?', {citizenid, location})
        if result then
            if Config.FuelDebug then print("Got result!") print("Result: "..json.encode(result)) end
            for _, v in pairs(result) do
                if Config.FuelDebug then print("Owned State: "..v.owned) print("Owner: "..v.owner) end
                if v.owner == citizenid and v.owned == 1 then
                    cb(true) if Config.FuelDebug then print(citizenid.." is the owner.. owner state == "..v.owned) end
                else
                    cb(false) if Config.FuelDebug then print("The owner is: "..v.owner) end
                end
            end
        else
            if Config.FuelDebug then print("No Result Sadge!") end
            cb(false)
        end
	end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:fetchinfo', function(source, cb, location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if Config.FuelDebug then print("Fetching Information for Location: "..location) end
        MySQL.Async.fetchAll('SELECT * FROM fuel_stations WHERE location = ?', {location}, function(result)
            if result then
                cb(result)
                if Config.FuelDebug then print(json.encode(result)) end
            else
                cb(false)
            end
	    end)
	end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:checkshutoff', function(source, cb, location)
        if Config.FuelDebug then print("Fetching Shutoff State for Location: "..location) end
        cb(Config.GasStations[location].shutoff)
	end)
    
    QBCore.Functions.CreateCallback('cdn-fuel:server:fetchlabel', function(source, cb, location)
        if Config.FuelDebug then print("Fetching Shutoff State for Location: "..location) end
        MySQL.Async.fetchAll('SELECT label FROM fuel_stations WHERE location = ?', {location}, function(result)
            if result then
                cb(result)
                if Config.FuelDebug then print(result) end
            else
                cb(false)
            end
	    end)
	end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:getAnalytics', function(source, cb, location)
        if Config.FuelDebug then print("CDN-Fuel: Analytics requested for location: " .. tostring(location)) end
        -- Fetch last 7 days of sales aggregated by day
        local query = [[
            SELECT DATE(date) as day, SUM(amount) as total_liters, SUM(cost) as total_revenue
            FROM fuel_station_sales 
            WHERE station_location = ? AND date >= DATE(NOW()) - INTERVAL 7 DAY
            GROUP BY DATE(date)
            ORDER BY day ASC
        ]]
        
        MySQL.Async.fetchAll(query, {location}, function(dailySales)
            if Config.FuelDebug then print("CDN-Fuel: Daily sales fetched: " .. tostring(dailySales and #dailySales or 0)) end
            
            -- Calculate Advanced Stats
            local weekLiters = 0
            local weekRevenue = 0
            local peakDay = { day = "N/A", liters = 0 }
            
            if dailySales then
                for _, s in pairs(dailySales) do
                    weekLiters = weekLiters + (s.total_liters or 0)
                    weekRevenue = weekRevenue + (s.total_revenue or 0)
                    if (s.total_liters or 0) > peakDay.liters then
                        peakDay.liters = s.total_liters
                        peakDay.day = s.day
                    end
                end
            end

            -- Fetch Total Liters & Revenue (Lifetime)
            MySQL.Async.fetchAll('SELECT SUM(amount) as total_liters, SUM(cost) as total_revenue FROM fuel_station_sales WHERE station_location = ?', {location}, function(totalsResult)
                local lifetime = totalsResult and totalsResult[1] or { total_liters = 0, total_revenue = 0 }

                -- Fetch weekly logs
                MySQL.Async.fetchAll('SELECT * FROM fuel_station_weekly_logs WHERE station_location = ? ORDER BY end_date DESC LIMIT 10', {location}, function(weeklyLogs)
                    if Config.FuelDebug then print("CDN-Fuel: Weekly logs fetched: " .. tostring(weeklyLogs and #weeklyLogs or 0)) end
                    cb({
                        dailySales = dailySales or {},
                        weeklyLogs = weeklyLogs or {},
                        stats = {
                            totalLiters = lifetime.total_liters or 0,
                            totalRevenue = lifetime.total_revenue or 0,
                            weekLiters = weekLiters,
                            weekRevenue = weekRevenue,
                            peakDay = peakDay
                        }
                    })
                end)
            end)
        end)
    end)

    RegisterNetEvent('cdn-fuel:server:closeWeek', function(location, startDate, endDate)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid

        if Config.FuelDebug then 
            print("^2CDN-Fuel: closeWeek Debug^7")
            print("Location:", location)
            print("NUI Start:", startDate)
            print("NUI End:", endDate)
            print("CitizenID:", citizenid)
        end

        -- Check ownership directly
        MySQL.Async.fetchAll('SELECT owner FROM fuel_stations WHERE location = ?', {location}, function(result)
            if result and result[1] and result[1].owner == citizenid then
                -- Normalization: If dates are just YYYY-MM-DD, expand them to full days
                if startDate and startDate ~= "" and #startDate <= 10 then startDate = startDate .. " 00:00:00" end
                if endDate and endDate ~= "" and #endDate <= 10 then endDate = endDate .. " 23:59:59" end

                -- Fallback to default range if not provided (empty or nil)
                if not startDate or startDate == "" or not endDate or endDate == "" then
                   if Config.FuelDebug then print("CDN-Fuel: Dates missing/empty, using fallback.") end
                   local lastLogResult = MySQL.Sync.fetchAll('SELECT end_date FROM fuel_station_weekly_logs WHERE station_location = ? ORDER BY end_date DESC LIMIT 1', {location})
                   startDate = (lastLogResult and lastLogResult[1]) and lastLogResult[1].end_date or "1970-01-01 00:00:00"
                   endDate = os.date('%Y-%m-%d %H:%M:%S')
                end

                if Config.FuelDebug then 
                    print("Final Start:", startDate)
                    print("Final End:", endDate)
                end

                -- Calculate totals for this period
                local query = [[
                    SELECT SUM(amount) as total_liters, SUM(cost) as total_revenue
                    FROM fuel_station_sales 
                    WHERE station_location = ? AND date >= ? AND date <= ?
                ]]

                MySQL.Async.fetchAll(query, {location, startDate, endDate}, function(totals)
                    local liters = totals[1].total_liters or 0
                    local revenue = totals[1].total_revenue or 0

                    if liters > 0 then
                        -- Fetch daily peak for this specific period
                        local peakQuery = [[
                            SELECT SUM(amount) as daily_total
                            FROM fuel_station_sales
                            WHERE station_location = ? AND date >= ? AND date <= ?
                            GROUP BY DATE(date)
                            ORDER BY daily_total DESC
                            LIMIT 1
                        ]]
                        MySQL.Async.fetchAll(peakQuery, {location, startDate, endDate}, function(peakResult)
                            local peak = (peakResult and peakResult[1]) and peakResult[1].daily_total or 0
                            
                            MySQL.Async.execute('INSERT INTO fuel_station_weekly_logs (station_location, start_date, end_date, total_liters, peak_liters, total_revenue) VALUES (?, ?, ?, ?, ?, ?)',
                                {location, startDate, endDate, liters, peak, revenue})
                            TriggerClientEvent('QBCore:Notify', src, "Semana fechada com sucesso!", "success")
                        end)
                    else
                        TriggerClientEvent('QBCore:Notify', src, "Não houve vendas neste período para fechar.", "error")
                    end
                end)
            else
                if Config.FuelDebug then print("Unauthorized closeWeek attempt by " .. tostring(citizenid)) end
            end
        end)
    end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:getSales', function(source, cb, location)
        MySQL.Async.fetchAll('SELECT * FROM fuel_station_sales WHERE station_location = ? ORDER BY date DESC LIMIT 50', {location}, function(result)
            cb(result)
        end)
    end)

    QBCore.Functions.CreateCallback('cdn-fuel:server:getFinanceLogs', function(source, cb, location)
        MySQL.Async.fetchAll('SELECT * FROM fuel_finance WHERE station_id = ? ORDER BY date DESC LIMIT 50', {location}, function(result)
            cb(result)
        end)
    end)

    RegisterNetEvent('cdn-fuel:station:server:clearFinanceHistory', function(location)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or not location then return end
        
        MySQL.Async.execute('DELETE FROM fuel_finance WHERE station_id = ?', {location}, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('QBCore:Notify', src, "Histórico financeiro limpo com sucesso!", 'success')
            end
        end)
    end)

    -- Startup Process
    local function Startup()
        if Config.FuelDebug then print("Startup process check...") end
        
        local function ContinueStartup()
            -- Load Dynamic Stations First
            LoadDynamicStations()

            local location = 0
            for value in ipairs(Config.GasStations) do
                location = location + 1
                UpdateStationLabel(location)
            end
            print("^2[CDN-Fuel] Database integration active & Verified.^7")
        end

        -- Check if table exists
        MySQL.Async.fetchAll("SHOW TABLES LIKE 'fuel_stations'", {}, function(result)
            if result and #result > 0 then
                ContinueStartup()
            else
                print("^3[CDN-FUEL] Database tables missing! Attempting auto-installation...^7")
                local sqlContent = LoadResourceFile(GetCurrentResourceName(), "assets/sql/cdn-fuel.sql")
                if sqlContent then
                    -- Clean comments and split queries
                    -- Removes comments lines starting with --
                    sqlContent = sqlContent:gsub("%-%-[^\n]*", "") 
                    
                    local queries = {}
                    for query in string.gmatch(sqlContent, "([^;]+)") do
                        local cleanQuery = query:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
                        if cleanQuery ~= "" then
                            table.insert(queries, cleanQuery)
                        end
                    end

                    local totalQueries = #queries
                    local completed = 0

                    if totalQueries == 0 then
                        print("^1[CDN-FUEL] SQL file found but no valid queries extracted.^7")
                        return
                    end

                    print("^2[CDN-FUEL] Installing tables... ("..totalQueries.." queries)^7")

                    for i, query in ipairs(queries) do
                        MySQL.Async.execute(query, {}, function(rows)
                            completed = completed + 1
                            if completed == totalQueries then
                                print("^2[CDN-FUEL] SQL installed successfully! Starting resource...^7")
                                Wait(500)
                                ContinueStartup()
                            end
                        end)
                    end
                else
                    print("^1[CDN-FUEL] CRITICAL: assets/sql/cdn-fuel.sql not found! Cannot install database.^7")
                end
            end
        end)
    end

    AddEventHandler('onResourceStart', function(resource)
        if resource == GetCurrentResourceName() then
            Startup()
        end
    end)

end -- For Config.PlayerOwnedGasStationsEnabled check, don't remove!\