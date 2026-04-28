local QBCore = exports[Config.Core]:GetCoreObject()

-- Helper to ensure data is a table (handles oxmysql auto-json-parsing)
local function EnsureTable(data)
    if type(data) == "string" then
        local decoded = json.decode(data)
        return type(decoded) == "table" and decoded or {}
    end
    return type(data) == "table" and data or {}
end

-- DATABASE LOADING LOGIC --
local function LoadStationsFromDB()
    MySQL.Async.fetchAll('SELECT * FROM fuel_stations', {}, function(stations)
        if stations then
            local count = 0
            for _, dbStation in ipairs(stations) do
                local id = tonumber(dbStation.location)
                
                -- Parse JSON fields safely
                local zones = EnsureTable(dbStation.zones)
                local convertedZones = {}
                for _, z in ipairs(zones) do
                    if type(z) == "table" and z.x and z.y then
                        table.insert(convertedZones, vector2(z.x, z.y))
                    end
                end

                local pedcoords = EnsureTable(dbStation.pedcoords)
                local pedVec = (pedcoords and pedcoords.x) and vector4(pedcoords.x, pedcoords.y, pedcoords.z, pedcoords.w) or nil

                local elecCoords = EnsureTable(dbStation.electricchargercoords)
                local elecDataList = {}
                if elecCoords then
                    if elecCoords.x then -- Old format (single point)
                        table.insert(elecDataList, vector4(elecCoords.x, elecCoords.y, elecCoords.z, elecCoords.w))
                    else -- New format (array of points)
                        for _, c in ipairs(elecCoords) do
                            if c.x then
                                table.insert(elecDataList, vector4(c.x, c.y, c.z, c.w))
                            end
                        end
                    end
                end
                local elecVec = #elecDataList > 0 and elecDataList or nil

                local unloadCoords = EnsureTable(dbStation.unloadcoords)
                local unloadVec = (unloadCoords and unloadCoords.x) and vector4(unloadCoords.x, unloadCoords.y, unloadCoords.z, unloadCoords.w) or nil

                local pumpCoords = EnsureTable(dbStation.fuelpumpcoords)
                local pumpDataList = {}
                for _, p in ipairs(pumpCoords) do
                    if type(p) == "table" and p.x and p.y then
                        -- Preserve model if exists
                        table.insert(pumpDataList, {
                            x = p.x,
                            y = p.y,
                            z = p.z,
                            w = p.w,
                            model = p.model
                        })
                    end
                end

                -- Validation
                local isPurchasable = (dbStation.is_purchasable == nil or dbStation.is_purchasable == 1 or dbStation.is_purchasable == true)
                if not pedVec and isPurchasable then
                    print("^3[CDN-FUEL] Warning: Station ID " .. id .. " (" .. dbStation.label .. ") has missing or invalid pedcoords.^7")
                end
                if #convertedZones < 3 then
                    print("^3[CDN-FUEL] Warning: Station ID " .. id .. " (" .. dbStation.label .. ") has invalid zones (less than 3 points).^7")
                end

                -- Update Config
                Config.GasStations[id] = {
                    label = dbStation.label,
                    cost = tonumber(dbStation.cost),
                    zones = convertedZones,
                    pedcoords = pedVec,
                    minz = tonumber(dbStation.minz),
                    maxz = tonumber(dbStation.maxz),
                    pedmodel = dbStation.pedmodel,
                    pumpheightadd = tonumber(dbStation.pumpheightadd) or 2.1,
                    shutoff = dbStation.shutoff == 1 or dbStation.shutoff == true,
                    electricchargercoords = elecVec,
                    unloadcoords = unloadVec,
                    fuelpumpcoords = pumpDataList,
                    logo = dbStation.logo,
                    type = dbStation.type or 'car',
                    is_purchasable = (dbStation.is_purchasable == nil or dbStation.is_purchasable == 1 or dbStation.is_purchasable == true)
                }
                count = count + 1
            end
            print("^2[CDN-FUEL] Loaded " .. count .. " gas stations from DATABASE.^7")
            
            -- Force Sync to all clients after load
            for id, station in pairs(Config.GasStations) do
                TriggerClientEvent('cdn-fuel:client:syncStations', -1, id, station)
            end
        end
    end)
end

-- Main function called to load stations
function LoadDynamicStations()
    LoadStationsFromDB()
end

RegisterNetEvent('cdn-fuel:server:requestDynamicStations', function()
    local src = source
    for id, station in pairs(Config.GasStations) do
        TriggerClientEvent('cdn-fuel:client:syncStations', src, id, station)
    end
end)

RegisterNetEvent('cdn-fuel:server:createStation', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or (not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god')) then
        return
    end

    local newId = #Config.GasStations + 1
    
    local newStation = {
        label = data.label,
        cost = tonumber(data.cost) or 100000,
        zones = data.zones,
        pedcoords = data.pedcoords,
        electricchargercoords = data.electricchargercoords,
        unloadcoords = data.unloadcoords,
        minz = data.minz,
        maxz = data.maxz,
        pumpheightadd = 2.1,
        shutoff = data.shutoff or false,
        type = data.type or 'car',
        is_purchasable = data.isPurchasable
    }

    if Config.FuelDebug then
        print("[CDN-FUEL] Servidor: Recebido tipo de posto: " .. tostring(newStation.type) .. " | Comprável: " .. tostring(newStation.is_purchasable))
    end

    local memStation = {
        label = newStation.label,
        cost = newStation.cost,
        zones = {},
        pedcoords = newStation.pedcoords and vector4(newStation.pedcoords.x, newStation.pedcoords.y, newStation.pedcoords.z, newStation.pedcoords.w) or nil,
        minz = newStation.minz,
        maxz = newStation.maxz,
        pumpheightadd = 2.1,
        shutoff = newStation.shutoff,
        pedmodel = data.pedmodel,
        type = newStation.type,
        is_purchasable = newStation.is_purchasable,
        electricchargercoords = nil
    }
    
    if newStation.electricchargercoords then
        if newStation.electricchargercoords.x then -- Single point
            memStation.electricchargercoords = vector4(newStation.electricchargercoords.x, newStation.electricchargercoords.y, newStation.electricchargercoords.z, newStation.electricchargercoords.w)
        else -- Multiple points
            memStation.electricchargercoords = {}
            for _, c in ipairs(newStation.electricchargercoords) do
                table.insert(memStation.electricchargercoords, vector4(c.x, c.y, c.z, c.w))
            end
        end
    end
    
    if newStation.unloadcoords then
        memStation.unloadcoords = vector4(newStation.unloadcoords.x, newStation.unloadcoords.y, newStation.unloadcoords.z, newStation.unloadcoords.w)
    end
    
    memStation.fuelpumpcoords = {}
    if data.fuelpumpcoords then
        for _, p in ipairs(data.fuelpumpcoords) do
            table.insert(memStation.fuelpumpcoords, {x=p.x, y=p.y, z=p.z, w=p.w, model=p.model})
        end
    end

    for _, z in ipairs(newStation.zones) do
        table.insert(memStation.zones, vector2(z.x, z.y))
    end
    
    Config.GasStations[newId] = memStation

    local zonesJson = json.encode(newStation.zones)
    local pedCoordsJson = json.encode(newStation.pedcoords)
    local elecCoordsJson = json.encode(newStation.electricchargercoords)
    local unloadCoordsJson = json.encode(newStation.unloadcoords)
    local fuelPumpCoordsJson = json.encode(data.fuelpumpcoords)
    local stationType = newStation.type

    MySQL.Async.execute('INSERT INTO fuel_stations (location, label, cost, fuel, fuelprice, balance, zones, minz, maxz, pedmodel, pedcoords, shutoff, pumpheightadd, electricchargercoords, unloadcoords, fuelpumpcoords, type, stock_level, is_purchasable) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            newId, 
            newStation.label, 
            newStation.cost, 
            Config.DefaultFuelOnPurchase or 5000, 
            3, 
            0,
            zonesJson, 
            newStation.minz, 
            newStation.maxz, 
            data.pedmodel or "a_m_m_indian_01", 
            pedCoordsJson, 
            newStation.shutoff, 
            2.1, 
            elecCoordsJson, 
            unloadCoordsJson, 
            fuelPumpCoordsJson, 
            stationType, 
            0,
            newStation.is_purchasable
        }, function(rows)
            if rows > 0 then
                TriggerClientEvent('QBCore:Notify', src, 'Posto criado com sucesso! ID: ' .. newId, 'success')
                TriggerClientEvent('cdn-fuel:client:syncStations', -1, newId, memStation)
            else
                TriggerClientEvent('QBCore:Notify', src, 'Erro ao criar posto no banco de dados.', 'error')
            end
    end)
end)

RegisterCommand('migrate_json_to_sql', function(source, args, rawCommand)
    if source ~= 0 then return end -- Console only
    local loadFile = LoadResourceFile(GetCurrentResourceName(), "data/locations.json")
    if not loadFile then print("No locations.json found.") return end
    local jsonStations = json.decode(loadFile)
    if not jsonStations then print("Failed to decode locations.json.") return end

    print("Migrating " .. #jsonStations .. " stations to SQL...")
    local count = 0
    local total = #jsonStations

    for i, station in ipairs(jsonStations) do
        local id = i
        local zonesJson = json.encode(station.zones)
        local pedCoordsJson = json.encode(station.pedcoords)
        local elecCoordsJson = station.electricchargercoords and json.encode(station.electricchargercoords) or nil
        
        local query = [[
            INSERT INTO fuel_stations (location, label, cost, fuel, fuelprice, balance, zones, minz, maxz, pedmodel, pedcoords, shutoff, pumpheightadd, electricchargercoords, unloadcoords, fuelpumpcoords, type, is_purchasable)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            zones = VALUES(zones),
            minz = VALUES(minz),
            maxz = VALUES(maxz),
            pedmodel = VALUES(pedmodel),
            pedcoords = VALUES(pedcoords),
            shutoff = VALUES(shutoff),
            pumpheightadd = VALUES(pumpheightadd),
            electricchargercoords = VALUES(electricchargercoords),
            unloadcoords = VALUES(unloadcoords),
            fuelpumpcoords = VALUES(fuelpumpcoords),
            label = VALUES(label),
            cost = VALUES(cost),
            type = VALUES(type),
            is_purchasable = VALUES(is_purchasable)
        ]]
        
        MySQL.Async.execute(query, {
            id,
            station.label,
            station.cost or 100000,
            Config.DefaultFuelOnPurchase or 5000, 3, 0,
            zonesJson,
            station.minz,
            station.maxz,
            station.pedmodel or "a_m_m_indian_01",
            pedCoordsJson,
            station.shutoff,
            station.pumpheightadd or 2.1,
            elecCoordsJson,
            station.unloadcoords and json.encode(station.unloadcoords) or nil,
            station.fuelpumpcoords and json.encode(station.fuelpumpcoords) or nil,
            station.type or 'car',
            true -- Default purchasable for migrated ones
        }, function()
            count = count + 1
            if count == total then
                print("^2[CDN-FUEL] Migração finalizada! " .. count .. " postos salvos no banco de dados.^7")
            end
        end)
    end
end, false)

RegisterNetEvent('cdn-fuel:server:updateUnloadCoords', function(stationId, coords)
    local src = source
    local station = Config.GasStations[stationId]
    if not station then return end
    
    local coordsJson = json.encode(coords)
    MySQL.Async.execute('UPDATE fuel_stations SET unloadcoords = ? WHERE location = ?', {coordsJson, stationId}, function(rows)
        if rows > 0 then
            Config.GasStations[stationId].unloadcoords = vector4(coords.x, coords.y, coords.z, coords.w)
            -- Sync the update to all clients
            TriggerClientEvent('cdn-fuel:client:syncStations', -1, stationId, Config.GasStations[stationId])
            print("^2[CDN-FUEL] Station #"..stationId.." unload coords updated!^7")
        end
    end)
end)

RegisterCommand('deletefuel', function(source, args)
    local src = source
    if src ~= 0 then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or (not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god')) then
            return
        end
    end

    local stationId = tonumber(args[1])
    if not stationId then
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, 'Uso: /deletefuel [ID]', 'error') end
        return
    end

    if not Config.GasStations[stationId] then
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, 'Posto não encontrado.', 'error') end
        return
    end

    MySQL.Async.execute('DELETE FROM fuel_stations WHERE location = ?', {stationId}, function(rows)
        if rows > 0 then
            Config.GasStations[stationId] = nil
            TriggerClientEvent('cdn-fuel:client:syncStations', -1, stationId, nil)
            TriggerClientEvent('cdn-fuel:client:deleteStationProps', -1, stationId) -- Cleanup props
            if src ~= 0 then
                TriggerClientEvent('QBCore:Notify', src, 'Posto #'..stationId..' deletado com sucesso!', 'success')
            else
                print("[CDN-FUEL] Posto #"..stationId.." deletado via console.")
            end
        end
    end)
end, false)
