-- Variables
local QBCore = exports[Config.Core]:GetCoreObject()

-- Functions
local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

-- Events
RegisterNetEvent("cdn-fuel:server:electric:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice)
	local src = source
	if not src then print("SRC is nil!") return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then print("Player is nil!") return end
	local FuelCost = amount*FuelPrice
	local tax = GlobalTax(FuelCost)
	local total = tonumber(FuelCost + tax)
	if not amount then if Config.FuelDebug then print("Electric Recharge Amount is invalid!") end TriggerClientEvent('QBCore:Notify', src, Lang:t("electric_more_than_zero"), 'error') return end
	Wait(50)
    if inGasStation and not hasWeapon then
        -- Check if Electric Charger is active (not disabled due to debt)
        local result = MySQL.Sync.fetchAll('SELECT electric_status FROM fuel_stations WHERE location = ?', {location})
        if result and result[1] and result[1].electric_status == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Este carregador está temporariamente desativado por falta de pagamento do proprietário.", 'error')
            return
        end

		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:electric:phone:PayForFuel", src, amount)
		else
			if Config.Ox.Menu then
				TriggerClientEvent('cdn-electric:client:OpenContextMenu', src, math.ceil(total), amount, purchasetype)
			else
				TriggerClientEvent('qb-menu:client:openMenu', src, {
					{
						header = Lang:t("menu_electric_header"),
						isMenuHeader = true,
						icon = "fas fa-bolt",
					},
					{
						header = "",
						icon = "fas fa-info-circle",
						isMenuHeader = true,
						txt = Lang:t("menu_purchase_station_header_1")..math.ceil(total)..Lang:t("menu_purchase_station_header_2"),
					},
					{
						header = Lang:t("menu_purchase_station_confirm_header"),
						icon = "fas fa-check-circle",
						txt = Lang:t("menu_electric_accept"),
						params = {
							event = "cdn-fuel:client:electric:ChargeVehicle",
							args = {
								fuelamounttotal = amount,
								purchasetype = purchasetype,
							}
						}
					},
					{
						header = Lang:t("menu_header_close"),
						txt = Lang:t("menu_electric_cancel"),
						icon = "fas fa-times-circle",
						params = {
							event = "qb-menu:closeMenu",
						}
					},
				})
			end
		end
	end
end)

-------------------------------------------------------------------------------
-- [ GESTÃO DE FATURAS E COBRANÇA ELÉTRICA ]
-------------------------------------------------------------------------------

local function GetNextBillingDate()
    local seconds = 86400 -- Default daily
    if Config.ElectricManagement.BillingInterval == "weekly" then seconds = 604800
    elseif Config.ElectricManagement.BillingInterval == "monthly" then seconds = 2592000
    elseif Config.ElectricManagement.BillingInterval == "seconds" then seconds = 30 -- 30 seconds for test
    end
    return os.date('%Y-%m-%d %H:%M:%S', os.time() + seconds)
end

-- Loop de Cobrança Automática (Roda a cada 30 minutos)
CreateThread(function()
    while true do
        if Config.ElectricManagement.Enabled then
            local results = MySQL.Sync.fetchAll('SELECT * FROM fuel_stations WHERE owned = 1 AND (electric_consumed > 0 OR electric_debt > 0)')
            local now = os.time()

            for _, station in ipairs(results) do
                local location = station.location
                local kwh = station.electric_consumed or 0
                local debt = station.electric_debt or 0
                local loyalty = station.electric_loyalty_level or 0
                local dueAt = station.electric_bill_due and os.time(os.date("!*t", station.electric_bill_due)) or nil
                
                -- Se não tem data de vencimento, define a primeira
                if not dueAt then
                    dueAt = os.time() + (24 * 60 * 60) -- Próxima fatura em 24h por padrão inicial
                    MySQL.Async.execute('UPDATE fuel_stations SET electric_bill_due = ? WHERE location = ?', {os.date('%Y-%m-%d %H:%M:%S', dueAt), location})
                end

                -- Verifica se a fatura venceu
                if now > dueAt then
                    -- Calcula o valor baseado no plano de fidelidade
                    local discount = Config.ElectricManagement.LoyaltyPlans[loyalty] and Config.ElectricManagement.LoyaltyPlans[loyalty].discount or 0
                    local pricePerKwh = Config.ElectricManagement.KwhPriceForOwners * (1 - (discount / 100))
                    local billAmount = math.ceil(kwh * pricePerKwh)

                    if billAmount > 0 then
                        -- Adiciona à dívida, zera o consumo e define a data de início da dívida se for a primeira
                        MySQL.Async.execute([[
                            UPDATE fuel_stations 
                            SET electric_debt = electric_debt + ?, 
                                electric_consumed = 0, 
                                electric_bill_due = ?,
                                electric_debt_since = IFNULL(electric_debt_since, NOW())
                            WHERE location = ?
                        ]], {billAmount, GetNextBillingDate(), location})
                        
                        if Config.FuelDebug then print("[CDN-FUEL] Fatura gerada para posto #"..location..": R$"..billAmount.." (kWh: "..kwh..")") end
                    end
                end

                -- Verifica Carência e Bloqueio
                if debt > 0 then
                    -- Buscamos a data em que a dívida começou
                    local debtSince = station.electric_debt_since and os.time(os.date("!*t", station.electric_debt_since)) or now
                    local graceTime = Config.ElectricManagement.GracePeriodDays * 24 * 60 * 60
                    
                    if now >= (debtSince + graceTime) then
                        if station.electric_status == 1 or station.electric_status == true then
                            MySQL.Async.execute('UPDATE fuel_stations SET electric_status = 0 WHERE location = ?', {location})
                            if Config.FuelDebug then print("[CDN-FUEL] Posto #"..location.." BLOQUEADO por carência expirada.") end
                            
                            TriggerClientEvent('cdn-fuel:station:client:updateNUI', -1, { 
                                electricManagement = { status = 0 }
                            })
                        end
                    end
                end
            end
        end
        local sleepTime = (Config.ElectricManagement.BillingInterval == "seconds") and 10000 or (30 * 60 * 1000)
        Wait(sleepTime) -- 10 seconds for test mode, else 30 mins
    end
end)

-- Evento para Pagar Dívida Elétrica
RegisterNetEvent('cdn-fuel:server:electric:payBill', function(location)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local result = MySQL.Sync.fetchAll('SELECT balance, electric_debt FROM fuel_stations WHERE location = ?', {location})
    if not result or not result[1] then return end

    local balance = result[1].balance or 0
    local debt = result[1].electric_debt or 0

    if debt <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Não há dívidas elétricas pendentes.", 'error')
        return
    end

    if balance < debt then
        TriggerClientEvent('QBCore:Notify', src, "O caixa do posto não tem saldo suficiente para pagar a fatura!", 'error')
        return
    end

    local newBalance = balance - debt
    MySQL.Async.execute('UPDATE fuel_stations SET balance = ?, electric_debt = 0, electric_status = 1, electric_debt_since = NULL WHERE location = ?', {newBalance, location})
    
    -- Log financeiro
    MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', 
        {location, "Pagamento Fatura Elétrica", debt, os.date('%Y-%m-%d %H:%M:%S')})

    TriggerClientEvent('QBCore:Notify', src, "Fatura elétrica paga com sucesso! Carregadores reativados.", 'success')
    
    -- Atualiza NUI
    TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { 
        balance = newBalance, 
        electricManagement = {
            debt = 0,
            status = 1
        }
    })
end)

-- Evento para Comprar Plano de Fidelidade Elétrica
RegisterNetEvent('cdn-fuel:server:electric:buyLoyalty', function(location, level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plan = Config.ElectricManagement.LoyaltyPlans[level]
    if not plan then return end

    local result = MySQL.Sync.fetchAll('SELECT balance, electric_loyalty_level FROM fuel_stations WHERE location = ?', {location})
    if not result or not result[1] then return end

    local balance = result[1].balance or 0
    local currentLevel = result[1].electric_loyalty_level or 0

    if level <= currentLevel then
        TriggerClientEvent('QBCore:Notify', src, "Você já possui este plano ou um superior.", 'error')
        return
    end

    if balance < plan.price then
        TriggerClientEvent('QBCore:Notify', src, "Saldo insuficiente no caixa do posto.", 'error')
        return
    end

    local newBalance = balance - plan.price
    MySQL.Async.execute('UPDATE fuel_stations SET balance = ?, electric_loyalty_level = ? WHERE location = ?', {newBalance, level, location})
    
    -- Log financeiro
    MySQL.Async.execute('INSERT INTO fuel_finance (station_id, type, amount, date) VALUES (?, ?, ?, ?)', 
        {location, "Upgrade Plano Elétrico: "..plan.label, plan.price, os.date('%Y-%m-%d %H:%M:%S')})

    TriggerClientEvent('QBCore:Notify', src, "Plano "..plan.label.." adquirido com sucesso!", 'success')
    
    -- Atualiza NUI
    TriggerClientEvent('cdn-fuel:station:client:updateNUI', src, { 
        balance = newBalance, 
        electricManagement = {
            loyaltyLevel = level
        }
    })
end)

-- Callback para verificar status antes de pegar o bico
QBCore.Functions.CreateCallback('cdn-fuel:server:electric:getStatus', function(source, cb, location)
    local result = MySQL.Sync.fetchAll('SELECT electric_status FROM fuel_stations WHERE location = ?', {location})
    if result and result[1] then
        cb(result[1].electric_status)
    else
        cb(1) -- Ativado por padrão se não encontrar
    end
end)