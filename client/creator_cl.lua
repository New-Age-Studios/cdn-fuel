local QBCore = exports[Config.Core]:GetCoreObject()
local creating = false
local placingPed = false
local placingCharger = false
local points = {}
local tempBlips = {}
local tempLines = {}
local placingUnload = false

local function ClearCreation()
    creating = false
    placingPed = false
    placingCharger = false
    placingUnload = false
    placingPumps = false
    points = {}
    for _, blip in pairs(tempBlips) do RemoveBlip(blip) end
    tempBlips = {}
    tempLines = {}
end

-- Forward Declarations
local StartElectricChargerPlacement
local StartFuelPumpPlacement
local StartPedPlacement
local StartUnloadPlacement
local FinalizeStation

local function CreateBlipForPoint(coords, index)
    local blip = AddBlipForCoord(coords)
    SetBlipSprite(blip, 162) -- Small circle
    SetBlipScale(blip, 0.5)
    SetBlipColour(blip, 3) -- Blue
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Ponto #" .. index)
    EndTextCommandSetBlipName(blip)
    table.insert(tempBlips, blip)
end

FinalizeStation = function(pedCoords, elecCoords, pumpCoordsList, unloadCoords)
    -- Calculate height defaults from points
    local sumZ = 0
    for _, p in ipairs(points) do sumZ = sumZ + p.z end
    local avgZ = sumZ / #points

    local input = lib.inputDialog('Configurar Posto', {
        {type = 'input', label = 'Nome do Posto', required = true},
        {type = 'number', label = 'Preço de Compra', default = 150000, required = true},
        {type = 'checkbox', label = 'Status do Posto (Marcado = Ativo)', checked = true},
        {type = 'input', label = 'Modelo do Ped', default = 'a_m_m_indian_01', required = true},
        {type = 'select', label = 'Tipo de Posto', options = {
            { value = 'car', label = 'Veículos (Padrão)' },
            { value = 'air', label = 'Aeronaves (Avião/Heli)' },
            { value = 'water', label = 'Embarcações (Barcos)' }
        }, default = 'car', required = true}
    })

    if not input then 
        ClearCreation()
        return 
    end

    local label = input[1]
    local cost = input[2]
    local isActive = input[3]
    local isActive = input[3]
    local pedModel = input[4] or 'a_m_m_indian_01'
    local stationType = input[5] or 'car'
    local shutoff = not isActive -- If Active (true), Shutoff is false.
    
    -- Auto-calculate height (hidden from user)
    local minz = math.floor(avgZ - 3)
    local maxz = math.ceil(avgZ + 8)
    
    -- prepare points for server
    local zonePoints = {}
    for _, p in ipairs(points) do
        table.insert(zonePoints, {x = p.x, y = p.y})
    end

    local electricchargercoords = nil
    if elecCoords then
        electricchargercoords = {x=elecCoords.x, y=elecCoords.y, z=elecCoords.z, w=elecCoords.w}
    end

    local fuelpumpcoords = {}
    if pumpCoordsList then
        for _, p in ipairs(pumpCoordsList) do
            table.insert(fuelpumpcoords, {x=p.x, y=p.y, z=p.z, w=p.w})
        end
    end

    TriggerServerEvent('cdn-fuel:server:createStation', {
        label = label,
        cost = cost,
        zones = zonePoints,
        pedcoords = {x=pedCoords.x, y=pedCoords.y, z=pedCoords.z, w=pedCoords.w},
        electricchargercoords = electricchargercoords,
        unloadcoords = unloadCoords,
        fuelpumpcoords = fuelpumpcoords,
        minz = minz,
        maxz = maxz,
        minz = minz,
        maxz = maxz,
        shutoff = shutoff,
        pedmodel = pedModel,
        type = stationType
    })
    
    ClearCreation()
end

StartPedPlacement = function(elecCoords, pumpPoints, unloadCoords)
    creating = false
    placingCharger = false
    placingPed = true
    lib.notify({
        title = 'Definir NPC',
        description = 'Vá até o local do NPC.\n[E] Confirmar Posição\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local pedModel = joaat('mp_m_shopkeep_01')
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do Wait(10) end
        
        local tempPed = CreatePed(4, pedModel, 0, 0, 0, 0, false, true)
        SetEntityAlpha(tempPed, 200, false)
        SetEntityCollision(tempPed, false, false)

        while placingPed do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            
            SetEntityCoords(tempPed, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, false)
            SetEntityHeading(tempPed, heading)
            
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end

            if IsControlJustPressed(0, 38) then -- E
                FinalizeStation(vector4(coords.x, coords.y, coords.z - 1.0, heading), elecCoords, pumpPoints, unloadCoords)
                DeleteEntity(tempPed)
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 DeleteEntity(tempPed)
                 ClearCreation()
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(tempPed) then DeleteEntity(tempPed) end
    end)
end

local placingPumps = false

StartFuelPumpPlacement = function()
    creating = false
    placingCharger = false
    placingPed = false
    placingPumps = true
    
    local pumpPoints = {}
    local pumpProps = {}
    
    lib.notify({
        title = 'Adicionar Bombas de Combustível',
        description = 'Vá até onde quer a bomba.\n[E] Adicionar Bomba\n[G] Pular/Finalizar Bombas\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local pumpModel = GetHashKey('prop_gas_pump_1d')
        RequestModel(pumpModel)
        while not HasModelLoaded(pumpModel) do Wait(10) end
        
        local ghostPump = CreateObject(pumpModel, 0, 0, 0, false, true, false)
        SetEntityAlpha(ghostPump, 150, false)
        SetEntityCollision(ghostPump, false, false)

        while placingPumps do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            -- Visualize ghost pump
            SetEntityCoords(ghostPump, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, false)
            SetEntityHeading(ghostPump, heading)

            -- Draw zone lines for context
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end

            if IsControlJustPressed(0, 38) then -- E (Add Pump)
                local pCoords = vector4(coords.x, coords.y, coords.z - 1.0, heading)
                table.insert(pumpPoints, pCoords)
                
                -- Create a visual prop that stays there
                local prop = CreateObject(pumpModel, pCoords.x, pCoords.y, pCoords.z, false, true, false)
                SetEntityHeading(prop, heading)
                SetEntityAlpha(prop, 200, false)
                SetEntityCollision(prop, false, false)
                table.insert(pumpProps, prop)

                lib.notify({
                    title = 'Bomba Adicionada', 
                    description = 'Total: '..#pumpPoints..'\n[E] Adicionar Mais\n[G] Finalizar',
                    type = 'success'
                })
                Wait(500) -- Prevent double press
            end

            if IsControlJustPressed(0, 47) then -- G (Finish/Skip)
                -- Cleanup props
                for _, p in ipairs(pumpProps) do DeleteEntity(p) end
                DeleteEntity(ghostPump)
                
                StartElectricChargerPlacement(pumpPoints)
                return -- Break loop
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 for _, p in ipairs(pumpProps) do DeleteEntity(p) end
                 DeleteEntity(ghostPump)
                 ClearCreation()
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(ghostPump) then DeleteEntity(ghostPump) end
        for _, p in ipairs(pumpProps) do DeleteEntity(p) end
    end)
end

StartElectricChargerPlacement = function(pumpPoints)
    creating = false
    placingPumps = false
    placingCharger = true
    lib.notify({
        title = 'Definir Carregador Elétrico',
        description = 'Vá até o local do carregador.\n[E] Confirmar Posição\n[G] Pular (Sem Carregador)\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local chargerModel = GetHashKey(Config.ElectricChargerModel)
        RequestModel(chargerModel)
        while not HasModelLoaded(chargerModel) do Wait(10) end
        
        local tempCharger = CreateObject(chargerModel, 0, 0, 0, false, true, false)
        SetEntityAlpha(tempCharger, 200, false)
        SetEntityCollision(tempCharger, false, false)
        
        while placingCharger do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            -- The main script uses heading directly now, so we visualize it the same way
            -- to ensure What You See Is What You Get.
            -- Also subtracting 1.0 from Z to place it on the ground (foot level) instead of hip level
            SetEntityCoords(tempCharger, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, false)
            SetEntityHeading(tempCharger, heading)
            
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end

            if IsControlJustPressed(0, 38) then -- E
                -- Pass Z - 1.0 so it saves on the ground
                StartUnloadPlacement(vector4(coords.x, coords.y, coords.z - 1.0, heading), pumpPoints)
                DeleteEntity(tempCharger)
            end

            if IsControlJustPressed(0, 47) then -- G (Skip)
                StartUnloadPlacement(nil, pumpPoints) -- Pass nil for eleccoords, but keep pumpPoints
                DeleteEntity(tempCharger)
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 ClearCreation()
                 DeleteEntity(tempCharger)
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(tempCharger) then DeleteEntity(tempCharger) end
    end)
end

StartUnloadPlacement = function(elecCoords, pumpPoints, editStationId)
    creating = false
    placingPumps = false
    placingCharger = false
    placingUnload = true
    lib.notify({
        title = editStationId and 'Editar Ponto de Descarregamento' or 'Definir Ponto de Descarregamento',
        description = 'Vá até o local de descarregamento.\n[E] Confirmar Posição\n[G] Pular\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        print("[CDN-FUEL] Iniciando posicionamento do bocal...")
        local propName = Config.UnloadPropModel or 'prop_indus_pumps_01'
        local propModel = GetHashKey(propName)
        
        RequestModel(propModel)
        local timer = GetGameTimer()
        while not HasModelLoaded(propModel) do
            Wait(10)
            if GetGameTimer() - timer > 3000 then
                print("[CDN-FUEL] Timeout ao carregar modelo '"..propName.."', tentando fallback...")
                propName = 'prop_gas_pump_1d'
                propModel = GetHashKey(propName)
                RequestModel(propModel)
                timer = GetGameTimer()
            end
        end
        print("[CDN-FUEL] Modelo carregado com sucesso: " .. propName)
        
        local ghostProp = CreateObject(propModel, 0, 0, 0, false, true, false)
        SetEntityAlpha(ghostProp, 200, false)
        SetEntityCollision(ghostProp, false, false)
        
        while placingUnload do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            SetEntityCoords(ghostProp, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, false)
            SetEntityHeading(ghostProp, heading)
            
            -- Draw a marker to be sure they see the spot
            DrawMarker(1, coords.x, coords.y, coords.z, 0,0,0, 0,0,0, 0.8, 0.8, 0.2, 0, 255, 0, 150, false, false, 2, nil, nil, false)

            if IsControlJustPressed(0, 38) then -- E
                local finalCoords = {x=coords.x, y=coords.y, z=coords.z, w=heading}
                if editStationId then
                    TriggerServerEvent('cdn-fuel:server:updateUnloadCoords', editStationId, finalCoords)
                    lib.notify({title = 'Sucesso', description = 'Ponto de descarregamento atualizado!', type = 'success'})
                else
                    StartPedPlacement(elecCoords, pumpPoints, finalCoords)
                end
                DeleteEntity(ghostProp)
                placingUnload = false
            end

            if IsControlJustPressed(0, 47) then -- G (Skip)
                if not editStationId then
                    StartPedPlacement(elecCoords, pumpPoints, nil)
                end
                DeleteEntity(ghostProp)
                placingUnload = false
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 ClearCreation()
                 DeleteEntity(ghostProp)
                 placingUnload = false
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(ghostProp) then DeleteEntity(ghostProp) end
    end)
end

local function FinishZoneCreation()
    if #points < 3 then
        lib.notify({title = 'Erro', description = 'Você precisa de pelo menos 3 pontos!', type = 'error'})
        return
    end
    StartFuelPumpPlacement()
end

RegisterCommand('createfuel', function()
    if creating or placingPed or placingCharger then
        ClearCreation()
        lib.notify({description = 'Criação cancelada.', type = 'info'})
        return
    end

    creating = true
    lib.notify({
        title = 'Criador de Posto (Área)',
        description = '[E] Adicionar Ponto\n[Z] Desfazer\n[ENTER] Próximo (NPC)\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        while creating do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            -- Draw Marker at current pos
            DrawMarker(28, coords.x, coords.y, coords.z, 0,0,0, 0,0,0, 0.2, 0.2, 0.2, 255, 0, 0, 200, false, false, 2, nil, nil, false)
            
            -- Draw walls between existing points
            if #points > 0 then
                local wallHeight = 5.0 -- Height of the wall visualization
                local minZ = coords.z - 2.0
                local maxZ = coords.z + wallHeight

                for i=1, #points do
                    local p1 = points[i]
                    local p2 = points[i+1] or coords -- Link to next point, or to player if last

                    -- Draw Wall function inline logic
                    local bottomLeft = vector3(p1.x, p1.y, minZ)
                    local topLeft = vector3(p1.x, p1.y, maxZ)
                    local bottomRight = vector3(p2.x, p2.y, minZ)
                    local topRight = vector3(p2.x, p2.y, maxZ)

                    local primaryRGB = Config.HexToRGB(Config.Colors.primary)
                    -- Draw both sides (two triangles per side = 4 triangles total)
                    -- Side 1
                    DrawPoly(bottomLeft, topLeft, bottomRight, primaryRGB.r, primaryRGB.g, primaryRGB.b, 50)
                    DrawPoly(topLeft, topRight, bottomRight, primaryRGB.r, primaryRGB.g, primaryRGB.b, 50)
                    -- Side 2 (Reverse winding)
                    DrawPoly(bottomRight, topLeft, bottomLeft, primaryRGB.r, primaryRGB.g, primaryRGB.b, 50)
                    DrawPoly(bottomRight, topRight, topLeft, primaryRGB.r, primaryRGB.g, primaryRGB.b, 50)
                    
                    -- Keep red lines for clarity at the base
                    DrawLine(bottomLeft, bottomRight, 255, 0, 0, 255)
                end
                
                -- Close the loop visual if we have more than 2 points to imply the final shape
                if #points >= 2 then
                     local p1 = points[#points]
                     local p2 = points[1]
                     -- Optional: Draw a "closing" hint line in a different color?
                     -- For now, just the dynamic line to player covers the "next segment"
                end
            end

            if IsControlJustPressed(0, 38) then -- E
                table.insert(points, coords)
                CreateBlipForPoint(coords, #points)
            end

            if IsControlJustPressed(0, 48) then -- Z
                if #points > 0 then
                    local blip = table.remove(tempBlips)
                    RemoveBlip(blip)
                    table.remove(points)
                end
            end

            if IsControlJustPressed(0, 18) then -- Enter
                FinishZoneCreation()
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 ClearCreation()
                 lib.notify({description = 'Cancelado.'})
            end

            Wait(0)
        end
    end)
end)
RegisterCommand('editfuel', function(source, args)
    local stationId = tonumber(args[1])
    if not stationId then
        lib.notify({title = 'Erro', description = 'Uso correto: /editfuel [ID]', type = 'error'})
        return
    end
    
    StartUnloadPlacement(nil, nil, stationId)
end)
