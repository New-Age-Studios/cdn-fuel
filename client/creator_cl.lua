local QBCore = exports[Config.Core]:GetCoreObject()
local creating = false
local placingPed = false
local placingCharger = false
local placingPlatform = false
local points = {}
local tempBlips = {}
local tempLines = {}
local tempProps = {}
local placingUnload = false

local function ClearCreation()
    creating = false
    placingPed = false
    placingCharger = false
    placingUnload = false
    placingPumps = false
    placingPlatform = false
    points = {}
    for _, blip in pairs(tempBlips) do RemoveBlip(blip) end
    for _, prop in pairs(tempProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    tempBlips = {}
    tempLines = {}
    tempProps = {}
end

-- Forward Declarations
local StartElectricChargerPlacement
local StartFuelPumpPlacement
local StartPedPlacement
local StartUnloadPlacement
local FinalizeStation

-- Creator State Variables
local CurrentStationType = 'car'
local CurrentStationLabel = "Novo Posto"
local CurrentStationCost = 150000
local CurrentPedModel = 'a_m_m_indian_01'
local CurrentIsActive = true
local CurrentIsPurchasable = true

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

FinalizeStation = function(pedCoords, elecCoordsList, pumpCoordsList, unloadCoords)
    -- Calculate height defaults from points
    local sumZ = 0
    for _, p in ipairs(points) do sumZ = sumZ + p.z end
    local avgZ = sumZ / #points

    -- Auto-calculate height (hidden from user)
    local minz = math.floor(avgZ - 3)
    local maxz = math.ceil(avgZ + 8)
    
    -- prepare points for server
    local zonePoints = {}
    for _, p in ipairs(points) do
        table.insert(zonePoints, {x = p.x, y = p.y})
    end

    local pedcoords = nil
    if pedCoords then
        pedcoords = {x=pedCoords.x, y=pedCoords.y, z=pedCoords.z, w=pedCoords.w}
    end

    local electricchargercoords = nil
    if elecCoordsList and #elecCoordsList > 0 then
        electricchargercoords = {}
        for _, c in ipairs(elecCoordsList) do
            table.insert(electricchargercoords, {x=c.x, y=c.y, z=c.z, w=c.w})
        end
    end

    local fuelpumpcoords = {}
    if pumpCoordsList then
        for _, p in ipairs(pumpCoordsList) do
            -- Flatten the data for the server (x, y, z, w, model)
            table.insert(fuelpumpcoords, {
                x = p.coords.x, 
                y = p.coords.y, 
                z = p.coords.z, 
                w = p.coords.w,
                model = p.model
            })
        end
    end

    if Config.FuelDebug then
        print("[CDN-FUEL] Criador: ENVIANDO PARA SERVIDOR - Tipo: " .. tostring(CurrentStationType) .. " | Comprável: " .. tostring(CurrentIsPurchasable))
        print("[CDN-FUEL] Contagem: Bombas: " .. (fuelpumpcoords and #fuelpumpcoords or 0) .. " | Carregadores: " .. (electricchargercoords and #electricchargercoords or 0))
    end

    TriggerServerEvent('cdn-fuel:server:createStation', {
        label = CurrentStationLabel,
        cost = CurrentStationCost,
        zones = zonePoints,
        pedcoords = pedcoords,
        electricchargercoords = electricchargercoords,
        unloadcoords = unloadCoords,
        fuelpumpcoords = fuelpumpcoords,
        minz = minz,
        maxz = maxz,
        shutoff = not CurrentIsActive,
        pedmodel = CurrentPedModel,
        type = CurrentStationType,
        isPurchasable = CurrentIsPurchasable
    })
    
    ClearCreation()
end

StartPedPlacement = function(elecCoordsList, pumpPoints, unloadCoords)
    creating = false
    placingPumps = false
    placingCharger = false
    placingUnload = false
    placingPed = true
    Wait(500) -- Prevent key skip
    lib.notify({
        title = 'Definir Local do NPC',
        description = 'Vá até onde quer o NPC.\n[E] Confirmar\n[G] Pular\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local pedModel = joaat('mp_m_shopkeep_01')
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do Wait(10) end
        
        local ghostPed = CreatePed(4, pedModel, 0, 0, 0, 0, false, true)
        SetEntityAlpha(ghostPed, 200, false)
        SetEntityCollision(ghostPed, false, false)

        while placingPed do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local groundZ = coords.z - 1.0
            
            SetEntityCoords(ghostPed, coords.x, coords.y, groundZ, 0.0, 0.0, 0.0, false)
            SetEntityHeading(ghostPed, heading)

            -- Draw PolyZone Lines
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end
            
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end

            if IsControlJustPressed(0, 38) then -- E
                local pedCoords = {x=coords.x, y=coords.y, z=groundZ, w=heading}
                FinalizeStation(pedCoords, elecCoordsList, pumpPoints, unloadCoords)
                DeleteEntity(ghostPed)
                placingPed = false
            end
            
            if IsControlJustPressed(0, 47) then -- G (Skip)
                FinalizeStation(nil, elecCoordsList, pumpPoints, unloadCoords)
                DeleteEntity(ghostPed)
                placingPed = false
            end

            if IsControlJustPressed(0, 177) then -- Backspace
                 DeleteEntity(ghostPed)
                 ClearCreation()
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(ghostPed) then DeleteEntity(ghostPed) end
    end)
end

-- Available pump models logic
local function GetAvailablePumpModels(stationType)
    if stationType == 'air' then
        local models = {}
        if Config.AviationPumpOffsets then
            for modelName, _ in pairs(Config.AviationPumpOffsets) do
                table.insert(models, modelName)
            end
        end
        -- Fallback if table is empty
        if #models == 0 then table.insert(models, 'prop_gas_tank_02a') end
        return models
    elseif stationType == 'water' then
        return {'prop_gas_pump_1d'} -- Default for water or add Config.WaterPumpOffsets if needed
    else
        return {'prop_gas_pump_1d', 'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c', 'prop_vintage_pump', 'prop_gas_pump_old2', 'prop_gas_pump_old3'}
    end
end

StartFuelPumpPlacement = function()
    creating = false
    placingCharger = false
    placingPed = false
    placingPumps = true
    
    local pumpPoints = {}
    local availableModels = GetAvailablePumpModels(CurrentStationType)
    local currentModelIndex = 1
    
    local description = 'Vá até onde quer a bomba.\n[E] Adicionar\n[G] Finalizar\n[BACKSPACE] Cancelar'
    if #availableModels > 1 then
        description = 'Vá até onde quer a bomba.\n[E] Adicionar\n[← / →] Mudar Modelo\n[G] Finalizar\n[BACKSPACE] Cancelar'
    end

    lib.notify({
        title = 'Adicionar Bombas (' .. CurrentStationType .. ')',
        description = description,
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local function LoadAndCreateGhost(modelName)
            local mHash = GetHashKey(modelName)
            RequestModel(mHash)
            while not HasModelLoaded(mHash) do Wait(10) end
            local obj = CreateObject(mHash, 0, 0, 0, false, true, false)
            SetEntityAlpha(obj, 150, false)
            SetEntityCollision(obj, false, false)
            return obj, mHash
        end

        local ghostPump, pumpModelHash = LoadAndCreateGhost(availableModels[currentModelIndex])

        while placingPumps do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z + 1.0, coords.x, coords.y, coords.z - 2.0, 1, 0, 0)
            local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
            local groundZ = hit == 1 and endCoords.z or (coords.z - 1.0)

            -- Visualize ghost pump (Use GroundZ)
            SetEntityCoords(ghostPump, coords.x, coords.y, groundZ, 0.0, 0.0, 0.0, false)
            SetEntityHeading(ghostPump, heading)

            -- Draw PolyZone Lines
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end

            -- Switch Model Logic (Only if multiple models exist)
            if #availableModels > 1 then
                if IsControlJustPressed(0, 174) or IsControlJustPressed(0, 175) then -- Arrows
                    currentModelIndex = currentModelIndex + (IsControlJustPressed(0, 175) and 1 or -1)
                    if currentModelIndex < 1 then currentModelIndex = #availableModels end
                    if currentModelIndex > #availableModels then currentModelIndex = 1 end
                    
                    if DoesEntityExist(ghostPump) then DeleteEntity(ghostPump) end
                    ghostPump, pumpModelHash = LoadAndCreateGhost(availableModels[currentModelIndex])
                    Wait(200)
                end
            end


            if IsControlJustPressed(0, 38) then -- E (Add Pump)
                local pCoords = vector4(coords.x, coords.y, groundZ, heading)
                local pModelName = availableModels[currentModelIndex]
                table.insert(pumpPoints, {coords = pCoords, model = pModelName})
                
                -- Create a visual prop that stays there (Z Adjusted)
                local prop = CreateObject(joaat(pModelName), pCoords.x, pCoords.y, groundZ, false, true, false)
                SetEntityHeading(prop, heading)
                SetEntityAlpha(prop, 200, false)
                SetEntityCollision(prop, false, false)
                table.insert(tempProps, prop)

                lib.notify({
                    title = 'Bomba Adicionada', 
                    description = 'Modelo: '..pModelName..'\nTotal: '..#pumpPoints,
                    type = 'success'
                })
                Wait(500) -- Increased wait to prevent accidental finish
            end

            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 47) then -- ENTER or G (Done)
                
                -- Final cleanup of ghost only here
                if DoesEntityExist(ghostPump) then DeleteEntity(ghostPump) end
                
                if CurrentStationType == 'air' then
                    if not CurrentIsPurchasable then
                        FinalizeStation(nil, nil, pumpPoints, nil)
                    else
                        StartPedPlacement(nil, pumpPoints, nil)
                    end
                else
                    StartElectricChargerPlacement(pumpPoints)
                end
                
                placingPumps = false
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 if DoesEntityExist(ghostPump) then DeleteEntity(ghostPump) end
                 ClearCreation()
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
        if DoesEntityExist(ghostPump) then DeleteEntity(ghostPump) end
    end)
end

StartElectricChargerPlacement = function(pumpPoints)
    creating = false
    placingPumps = false
    placingCharger = true
    Wait(500) -- Prevent key skip from previous step
    
    local chargerPoints = {}
    
    lib.notify({
        title = 'Definir Carregadores Elétricos',
        description = 'Vá até o local do carregador.\n[E] Adicionar Carregador\n[ENTER/G] Finalizar e Continuar\n[BACKSPACE] Cancelar',
        duration = 10000,
        type = 'info'
    })

    CreateThread(function()
        local chargerModel = GetHashKey(Config.ElectricChargerModel)
        RequestModel(chargerModel)
        while not HasModelLoaded(chargerModel) do Wait(10) end
        
        local tempCharger = CreateObject(chargerModel, 0, 0, 0, false, true, false)
        SetEntityAlpha(tempCharger, 150, false)
        SetEntityCollision(tempCharger, false, false)
        
        while placingCharger do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z + 1.0, coords.x, coords.y, coords.z - 2.0, 1, 0, 0)
            local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
            local groundZ = hit == 1 and endCoords.z or (coords.z - 1.0)

            SetEntityCoords(tempCharger, coords.x, coords.y, groundZ, 0.0, 0.0, 0.0, false)
            SetEntityHeading(tempCharger, heading)
            
            -- Draw PolyZone Lines
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end
            
            if IsControlJustPressed(0, 38) then -- E (Add)
                local cCoords = vector4(coords.x, coords.y, groundZ, heading)
                table.insert(chargerPoints, cCoords)
                
                -- Create a visual prop that stays there
                local prop = CreateObject(chargerModel, cCoords.x, cCoords.y, cCoords.z, false, true, false)
                SetEntityHeading(prop, cCoords.w)
                SetEntityAlpha(prop, 200, false)
                SetEntityCollision(prop, false, false)
                table.insert(tempProps, prop)

                lib.notify({title = 'Carregador Adicionado', description = 'Total: '..#chargerPoints, type = 'success'})
                Wait(200)
            end

            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 47) then -- ENTER or G (Done/Skip)
                if not CurrentIsPurchasable then
                    FinalizeStation(nil, chargerPoints, pumpPoints, nil)
                else
                    StartUnloadPlacement(chargerPoints, pumpPoints)
                end
                
                -- Cleanup
                DeleteEntity(tempCharger)
                placingCharger = false
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                 ClearCreation()
                 DeleteEntity(tempCharger)
                 placingCharger = false
                 lib.notify({description = 'Cancelado.'})
            end
            
            Wait(0)
        end
    end)
end

StartUnloadPlacement = function(elecCoordsList, pumpPoints, editStationId)
    creating = false
    placingPumps = false
    placingCharger = false
    placingUnload = true
    Wait(500) -- Prevent key skip from previous step
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
        
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z + 1.0, coords.x, coords.y, coords.z - 2.0, 1, 0, 0)
        local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
        local groundZ = hit == 1 and endCoords.z or (coords.z - 1.0)

        local ghostProp = CreateObject(propModel, coords.x, coords.y, groundZ, false, true, false)
        SetEntityAlpha(ghostProp, 150, false)
        SetEntityCollision(ghostProp, false, false)
        
        while placingUnload do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z + 1.0, coords.x, coords.y, coords.z - 2.0, 1, 0, 0)
            local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
            local groundZ = hit == 1 and endCoords.z or (coords.z - 1.0)

            SetEntityCoords(ghostProp, coords.x, coords.y, groundZ, 0.0, 0.0, 0.0, false)
            SetEntityHeading(ghostProp, heading)
            
            -- Draw PolyZone Lines
            if #points > 0 then
                for i=1, #points-1 do DrawLine(points[i], points[i+1], 255, 255, 0, 255) end
                DrawLine(points[#points], points[1], 255, 255, 0, 255)
            end
            
            -- Draw a marker to be sure they see the spot
            DrawMarker(1, coords.x, coords.y, groundZ, 0,0,0, 0,0,0, 0.8, 0.8, 0.2, 0, 255, 0, 150, false, false, 2, nil, nil, false)

            if IsControlJustPressed(0, 38) then -- E
                local finalCoords = {x=coords.x, y=coords.y, z=groundZ, w=heading}
                if editStationId then
                    TriggerServerEvent('cdn-fuel:server:updateUnloadCoords', editStationId, finalCoords)
                    lib.notify({title = 'Sucesso', description = 'Ponto de descarregamento atualizado!', type = 'success'})
                else
                    StartPedPlacement(elecCoordsList, pumpPoints, finalCoords)
                end
                DeleteEntity(ghostProp)
                placingUnload = false
            end

            if IsControlJustPressed(0, 47) then -- G (Skip)
                if not editStationId then
                    StartPedPlacement(elecCoordsList, pumpPoints, nil)
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

local function StartMaritimePlatformPlacement()
    creating = false
    placingPlatform = true
    lib.notify({
        title = 'Posicionar Plataforma',
        description = 'SETAS (Cima/Baixo): Distância\nPAGE UP/DOWN: Altura (Afundar/Erguer)\nQ / E: Rotacionar\n[ENTER] Confirmar\n[BACKSPACE] Cancelar',
        duration = 15000,
        type = 'info'
    })

    CreateThread(function()
        local propModel = GetHashKey(Config.MaritimePlatform.Model)
        RequestModel(propModel)
        while not HasModelLoaded(propModel) do Wait(10) end

        local tempPlatform = CreateObject(propModel, 0.0, 0.0, 0.0, false, false, false)
        SetEntityCollision(tempPlatform, false, false)
        SetEntityAlpha(tempPlatform, 180, false)

        local distance = 15.0
        local heightOffset = 0.0
        local heading = 0.0

        while placingPlatform do
            local ped = PlayerPedId()
            
            if IsControlPressed(0, 172) then distance = distance + 0.2 end -- Up Arrow
            if IsControlPressed(0, 173) then distance = distance - 0.2 end -- Down Arrow
            if IsControlPressed(0, 10) then heightOffset = heightOffset + 0.1 end -- Page Up
            if IsControlPressed(0, 11) then heightOffset = heightOffset - 0.1 end -- Page Down
            if IsControlPressed(0, 44) then heading = heading + 1.0 end -- Q
            if IsControlPressed(0, 46) then heading = heading - 1.0 end -- E

            local fwd = GetEntityForwardVector(ped)
            local basePos = GetEntityCoords(ped)
            local pos = basePos + (fwd * distance)
            pos = vector3(pos.x, pos.y, basePos.z + heightOffset)

            SetEntityCoordsNoOffset(tempPlatform, pos.x, pos.y, pos.z, true, true, true)
            SetEntityHeading(tempPlatform, heading)

            if IsControlJustPressed(0, 191) then -- ENTER
                placingPlatform = false
                
                local pedcoords = nil
                if CurrentIsPurchasable then
                    local pedOffset = GetOffsetFromEntityInWorldCoords(tempPlatform, Config.MaritimePlatform.OwnerInteractionOffset.x, Config.MaritimePlatform.OwnerInteractionOffset.y, Config.MaritimePlatform.OwnerInteractionOffset.z)
                    pedcoords = {x = pedOffset.x, y = pedOffset.y, z = pedOffset.z, w = heading}
                end

                local fuelpumpcoords = {}

                -- Inject the platform itself as a special "pump" to avoid SQL schema changes
                table.insert(fuelpumpcoords, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    w = heading,
                    model = Config.MaritimePlatform.Model,
                    is_platform = true
                })

                -- Inject the invisible pumps
                for _, pump in ipairs(Config.MaritimePlatform.PumpOffsets) do
                    local pumpPos = GetOffsetFromEntityInWorldCoords(tempPlatform, pump.target.x, pump.target.y, pump.target.z)
                    table.insert(fuelpumpcoords, {
                        x = pumpPos.x,
                        y = pumpPos.y,
                        z = pumpPos.z,
                        w = heading,
                        model = 'maritime_invisible_pump'
                    })
                end

                local radius = 30.0
                local zonePoints = {
                    {x = pos.x - radius, y = pos.y - radius},
                    {x = pos.x + radius, y = pos.y - radius},
                    {x = pos.x + radius, y = pos.y + radius},
                    {x = pos.x - radius, y = pos.y + radius}
                }

                TriggerServerEvent('cdn-fuel:server:createStation', {
                    label = CurrentStationLabel,
                    cost = CurrentStationCost,
                    zones = zonePoints,
                    pedcoords = pedcoords,
                    electricchargercoords = nil,
                    unloadcoords = nil,
                    fuelpumpcoords = fuelpumpcoords,
                    minz = pos.z - 10.0,
                    maxz = pos.z + 15.0,
                    shutoff = not CurrentIsActive,
                    pedmodel = CurrentPedModel,
                    type = 'boat_platform',
                    isPurchasable = CurrentIsPurchasable
                })
                
                DeleteEntity(tempPlatform)
                ClearCreation()
                lib.notify({description = 'Plataforma marítima criada com sucesso!', type = 'success'})

            elseif IsControlJustPressed(0, 177) then -- BACKSPACE
                placingPlatform = false
                DeleteEntity(tempPlatform)
                ClearCreation()
                lib.notify({description = 'Cancelado.'})
            end
            Wait(0)
        end
    end)
end

RegisterCommand('createfuel', function()
    if creating or placingPed or placingCharger then
        ClearCreation()
        lib.notify({description = 'Criação cancelada.', type = 'info'})
        return
    end

    local input = lib.inputDialog('Configurar Novo Posto', {
        {type = 'input', label = 'Nome do Posto', required = true},
        {type = 'number', label = 'Preço de Compra', default = 150000, required = true},
        {type = 'checkbox', label = 'Posto Comprável (Dono)', checked = true},
        {type = 'checkbox', label = 'Status do Posto (Marcado = Ativo)', checked = true},
        {type = 'input', label = 'Modelo do Ped', default = 'a_m_m_indian_01', required = true},
        {type = 'select', label = 'Tipo de Posto', options = {
            { value = 'car', label = 'Veículos (Padrão)' },
            { value = 'air', label = 'Aeronaves (Avião/Heli)' },
            { value = 'water', label = 'Embarcações (Barcos)' },
            { value = 'boat_platform', label = 'Posto Barco (Plataforma Marítima)' }
        }, default = 'car', required = true}
    })

    if not input then return end

    CurrentStationLabel = input[1]
    CurrentStationCost = input[2]
    CurrentIsPurchasable = input[3]
    CurrentIsActive = input[4]
    CurrentPedModel = input[5] or 'a_m_m_indian_01'
    CurrentStationType = input[6] or 'car'

    if Config.FuelDebug then
        print("[CDN-FUEL] Criador: Tipo selecionado no menu: " .. tostring(CurrentStationType) .. " | Comprável: " .. tostring(CurrentIsPurchasable))
    end

    if CurrentStationType == 'boat_platform' then
        StartMaritimePlatformPlacement()
        return
    end

    creating = true
    lib.notify({
        title = 'Criador de Posto (Área)',
        description = '[E] Adicionar Ponto\n[Z] Desfazer\n[ENTER] Próximo (Pumps)\n[BACKSPACE] Cancelar',
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
