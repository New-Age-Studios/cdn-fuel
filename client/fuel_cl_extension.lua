print("[DEBUG] Loading fuel_cl_extension.lua")

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
        ['draw_text'] = stationData.type == 'air' and "[Mangueira] Abastecer Aeronave" or "[G] Reabastecer Barco",
        ['type'] = stationData.type,
        ['whitelist'] = {
            ['enabled'] = false 
        }
    }

    -- Convert Zone Points
    local coords = {}
    for i, p in ipairs(stationData.zones) do
        table.insert(coords, vector2(p.x, p.y))
    end
    locationData['PolyZone']['coords'] = coords

    -- Skip Prop Spawning here, handled by station_cl.lua

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
                     end
                     
                     -- Input Thread
                     CreateThread(function()
                         while isPointInside do
                             Wait(0)
                             if IsControlJustReleased(0, Config.AirAndWaterVehicleFueling.refuel_button) then
                                 -- Trigger Refuel Logic
                                 TriggerEvent('cdn-fuel:client:RefuelVehicle', vehicle)
                             end
                             if not IsPedInAnyVehicle(PlayerPedId()) then break end
                         end
                     end)
                 end
            end
        else
            if Config.Ox.DrawText then lib.hideTextUI() else exports[Config.Core]:HideText() end
        end
    end)
    
    -- Store for cleanup?
    -- AirSeaFuelZones[GeneratedName] = Zone
end)
