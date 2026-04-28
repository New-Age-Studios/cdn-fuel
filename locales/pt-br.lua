local Translations = {
    -- Fuel
    set_fuel_debug = "Defina o combustível para:",
    cancelled = "Cancelado.",
    not_enough_money = "Você não tem dinheiro suficiente!",
    not_enough_money_in_bank = "Você não tem dinheiro suficiente no banco!",
    not_enough_money_in_cash = "Você não tem dinheiro suficiente no bolso!",
    more_than_zero = "Você precisa abastecer mais do que 0 litros!",
    emergency_shutoff_active = "As bombas estão atualmente desligadas através do sistema de desligamento de emergência.",
    nozzle_cannot_reach = "O bico não pode alcançar tão longe!",
    station_no_fuel = "Esta estação está sem combustível!",
    station_not_enough_fuel = "A estação não tem tanto combustível!",
    show_input_key_special = "Pressione [G] quando estiver perto do veículo para abastecê-lo!",
    tank_cannot_fit = "Seu tanque não pode suportar isso!",
    tank_already_full = "Seu veículo já está cheio!",
    need_electric_charger = "Preciso ir a um carregador elétrico!",
    cannot_refuel_inside = "Você não pode abastecer de dentro do veículo!",
    
    -- 2.1.2 -- Reservas Pickup ---
    fuel_order_ready = "Seu pedido de combustível está disponível para retirada! Dê uma olhada no seu GPS para encontrar o local de retirada!",
    draw_text_fuel_dropoff = "[E] Descarregar Caminhão",
    fuel_pickup_success = "Reabastecimento do posto - Agora o total é de: %s litros",
    fuel_pickup_failed = "A Ron Oil acabou de entregar o combustível para sua estação!",
    trailer_too_far = "O reboque não está acoplado ao caminhão ou está muito longe!",
    fuel_unload_success = "Combustível descarregado! Agora leve o caminhão de volta para a central para receber o pagamento.",
    draw_text_fuel_return = "[E] Devolver Veículo",
    grab_hose_trailer = "Pegar Mangueira do Reboque",
    connect_hose_station = "Conectar Mangueira ao Posto",
    unloading_fuel = "Descarregando Combustível...",

    -- 2.1.0
    no_nozzle = "Você não tem o bico!",
    vehicle_is_damaged = "O veículo está muito danificado para abastecer!",
    vehicle_too_far = "Você está muito longe para abastecer este veículo!",
    inside_vehicle = "Você não pode abastecer de dentro do veículo!",
    you_are_discount_eligible = "Se você entrar em serviço, poderá receber um desconto no combustível!",
    no_fuel = "Sem combustível..",

    -- Electric
    electric_more_than_zero = "Você precisa carregar mais do que 0KW!",
    electric_vehicle_not_electric = "Seu veículo não é elétrico!",
    electric_no_nozzle = "Seu veículo não é elétrico!",

    -- Phone --
    electric_phone_header = "Carregador Elétrico",
    electric_phone_notification = "Custo Total da Eletricidade: R$",
    fuel_phone_header = "Posto de Gasolina",
    phone_notification = "Custo Total: R$",
    phone_refund_payment_label = "Reembolso no Posto de Gasolina!",

    -- Stations
    station_per_liter = " / Litro!",
    station_already_owned = "Este local já está em sua posse!",
    station_cannot_sell = "Você não pode vender este local!",
    station_sold_success = "Você vendeu este local com sucesso!",
    station_not_owner = "Você não é o proprietário do local!",
    station_amount_invalid = "A quantidade é inválida!",
    station_more_than_one = "Você precisa comprar mais do que 1 litro!",
    station_price_too_high = "Este preço é muito alto!",
    station_price_too_low = "Este preço é muito baixo!",
    station_name_invalid = "Este nome é inválido!",
    station_name_too_long = "O nome não pode ter mais de "..Config.NameChangeMaxChar.." caracteres.",
    station_name_too_short = "O nome deve ter mais de "..Config.NameChangeMinChar.." caracteres.",
    station_withdraw_too_much = "Você não pode sacar mais do que a estação tem!",
    station_withdraw_too_little = "Você não pode sacar menos de R$1!",
    station_success_withdrew_1 = "Retirado com sucesso R$",
    station_success_withdrew_2 = " do saldo desta estação!", -- Leave the space @ the front!
    station_deposit_too_much = "Você não pode depositar mais do que você tem!",
    station_deposit_too_little = "Você não pode depositar menos de R$1!",
    station_success_deposit_1 = "Depositado com sucesso R$",
    station_success_deposit_2 = " no saldo desta estação!", -- Leave the space @ the front!
    station_cannot_afford_deposit = "Você não pode pagar para depositar R$",
    station_shutoff_success = "Estado da válvula de desligamento de emergência alterado com sucesso para este local!",
    station_fuel_price_success = "Preço do combustível alterado com sucesso para R$",
    station_reserve_cannot_fit = "As reservas não podem conter isso!",
    station_reserves_over_max =  "Você não pode comprar essa quantidade, pois será maior que o máximo de "..Config.MaxFuelReserves.." litros",
    station_name_change_success = "Nome alterado com sucesso para: ", -- Leave the space @ the end!
    station_shutoff_active = "Este posto está fechado no momento e as bombas estão travadas.",
    station_purchased_location_payment_label = "Local de Posto de Gasolina Comprado: ",
    station_sold_location_payment_label = "Local de Posto de Gasolina Vendido: ",
    station_withdraw_payment_label = "Dinheiro retirado do Posto de Gasolina. Local: ",
    station_deposit_payment_label = "Dinheiro depositado no Posto de Gasolina. Local: ",
    -- All Progress Bars
    prog_refueling_vehicle = "Abastecendo o Veículo..",
    prog_electric_charging = "Carregando..",
    prog_jerry_can_refuel = "Abastecendo o Galão..",
    prog_syphoning = "Sifonando Combustível..",

    -- Menus
    
    menu_header_cash = "Dinheiro",
    menu_header_bank = "Banco",
    menu_header_close = "Cancelar",
    menu_pay_with_cash = "Pagar com dinheiro.  \nVocê tem: R$",
    menu_pay_with_bank = "Pagar com banco.", 
    menu_refuel_header = "Posto de Gasolina",
    menu_refuel_accept = "Eu gostaria de comprar o combustível.",
    menu_refuel_cancel = "Na verdade, vou fazer outra coisa.",
    menu_pay_label_1 = "Gasolina @ ",
    menu_pay_label_2 = " / L",
    menu_header_jerry_can = "Galão",
    menu_header_refuel_jerry_can = "Abastecer Galão",
    menu_header_refuel_vehicle = "Abastecer Veículo",

    menu_electric_cancel = "Na verdade, eu não quero mais carregar meu carro.",
    menu_electric_header = "Carregador Elétrico",
    menu_electric_accept = "Eu gostaria de pagar pela eletricidade.",
    menu_electric_payment_label_1 = "Eletricidade @ ",
    menu_electric_payment_label_2 = " / KW",


    -- Station Menus

    menu_ped_manage_location_header = "Gerenciar Este Local",
    menu_ped_manage_location_footer = "Se você é o proprietário, pode gerenciar este local.",

    menu_ped_purchase_location_header = "Comprar Este Local",
    menu_ped_purchase_location_footer = "Se ninguém possui este local, você pode comprá-lo.",

    menu_ped_emergency_shutoff_header = "Alternar Desligamento de Emergência",
    menu_ped_emergency_shutoff_footer = "Desligue o combustível em caso de emergência.   \n As bombas estão atualmente ",
    
    menu_ped_close_header = "Cancelar Conversa",
    menu_ped_close_footer = "Na verdade, não quero discutir mais nada.",

    menu_station_reserves_header = "Comprar Reservas para ",
    menu_station_reserves_purchase_header = "Comprar reservas por: R$",
    menu_station_reserves_purchase_footer = "Sim, quero comprar reservas de combustível por R$",
    menu_station_reserves_cancel_footer = "Na verdade, não quero comprar mais reservas!",
    
    menu_purchase_station_header_1 = "O custo total será: R$",
    menu_purchase_station_header_2 = " incluindo impostos.",
    menu_purchase_station_confirm_header = "Confirmar",
    menu_purchase_station_confirm_footer = "Quero comprar este local por R$",
    menu_purchase_station_cancel_footer = "Na verdade, não quero comprar este local mais. Esse preço é absurdo!",

    menu_sell_station_header = "Vender ",
    menu_sell_station_header_accept = "Vender Posto de Gasolina",
    menu_sell_station_footer_accept = "Sim, quero vender este local por R$",
    menu_sell_station_footer_close = "Na verdade, não tenho mais nada a discutir.",

    menu_manage_header = "Gerenciamento de ",
    menu_manage_reserves_header = "Reservas de Combustível  \n",
    menu_manage_reserves_footer_1 =  " Litros de ",
    menu_manage_reserves_footer_2 =  " Litros  \nVocê pode comprar mais reservas abaixo!",
    
    menu_manage_purchase_reserves_header = "Comprar Mais Combustível para Reservas",
    menu_manage_purchase_reserves_footer = "Quero comprar mais reservas de combustível por R$",
    menu_manage_purchase_reserves_footer_2 = " / L!",

    menu_alter_fuel_price_header = "Alterar Preço do Combustível",
    menu_alter_fuel_price_footer_1 = "Quero mudar o preço do combustível no meu posto de gasolina!  \nAtualmente, é R$",
    
    menu_manage_company_funds_header = "Gerenciar Fundos da Empresa",
    menu_manage_company_funds_footer = "Quero gerenciar os fundos deste local.",
    menu_manage_company_funds_header_2 = "Gerenciamento de Fundos de ",
    menu_manage_company_funds_withdraw_header = "Retirar Fundos",
    menu_manage_company_funds_withdraw_footer = "Retire fundos da conta do posto.",
    menu_manage_company_funds_deposit_header = "Depositar Fundos",
    menu_manage_company_funds_deposit_footer = "Deposite fundos na conta do posto.",
    menu_manage_company_funds_return_header = "Retornar",
    menu_manage_company_funds_return_footer = "Quero discutir outra coisa!",

    menu_manage_change_name_header = "Alterar Nome do Local",
    menu_manage_change_name_footer = "Quero mudar o nome do local.",

    menu_manage_sell_station_footer = "Venda seu posto de gasolina por R$",

    menu_manage_close = "Na verdade, não tenho mais nada a discutir!", 

    menu_jerry_can_purchase_header = "Comprar Galão de Combustível por R$",
    menu_jerry_can_footer_full_gas = "Seu galão de combustível está cheio!",
    menu_jerry_can_footer_refuel_gas = "Abasteça seu galão de combustível!",
    menu_jerry_can_footer_use_gas = "Coloque sua gasolina para usar e abasteça o veículo!",
    menu_jerry_can_footer_no_gas = "Você não tem gasolina em seu galão de combustível!",
    menu_jerry_can_footer_close = "Na verdade, não quero mais um galão de combustível.",
    menu_jerry_can_close = "Na verdade, não quero usar isso mais.",

    menu_syphon_kit_full = "Seu kit de sifão está cheio! Ele só cabe " .. Config.SyphonKitCap .. "L!",
    menu_syphon_vehicle_empty = "O tanque de combustível deste veículo está vazio.",
    menu_syphon_allowed = "Roube combustível de uma vítima desavisada!",
    menu_syphon_refuel = "Coloque sua gasolina roubada para usar e abasteça o veículo!",
    menu_syphon_empty = "Coloque sua gasolina roubada para usar e abasteça o veículo!",
    menu_syphon_cancel = "Na verdade, não quero usar isso mais. Vou mudar de vida!",
    menu_syphon_header = "Sifão",
    menu_syphon_refuel_header = "Abastecer",


    input_select_refuel_header = "Selecione quanto combustível abastecer.",
    input_refuel_submit = "Abastecer Veículo",
    input_refuel_jerrycan_submit = "Abastecer Galão de Combustível",
    input_max_fuel_footer_1 = "Até ",
    input_max_fuel_footer_2 = "L de combustível.",
    input_insert_nozzle = "Insira o Bico", -- Usado também para Target!

    input_purchase_reserves_header_1 = "Comprar Reservas  \nPreço Atual: R$",
    input_purchase_reserves_header_2 = Config.FuelReservesPrice .. " / Litro  \nReservas Atuais: ",
    input_purchase_reserves_header_3 = " Litros  \nCusto Total das Reservas: R$",
    input_purchase_reserves_submit_text = "Comprar Reservas",
    input_purchase_reserves_text = 'Comprar Reservas de Combustível.',

    input_alter_fuel_price_header_1 = "Alterar Preço do Combustível   \nPreço Atual: R$",
    input_alter_fuel_price_header_2 = " / Litro",
    input_alter_fuel_price_submit_text = "Mudar Preço do Combustível",

    input_change_name_header_1 = "Alterar Nome de ",
    input_change_name_header_2 = ".",
    input_change_name_submit_text = "Enviar Alteração de Nome",
    input_change_name_text = "Novo Nome..",

    input_withdraw_funds_header = "Retirar Fundos  \nSaldo Atual: R$",
    input_withdraw_submit_text = "Retirar",
    input_withdraw_text = "Retirar Fundos",

    input_deposit_funds_header = "Depositar Fundos  \nSaldo Atual: R$",
    input_deposit_submit_text = "Depositar",
    input_deposit_text = "Depositar Fundos",

    
    -- Target
    grab_electric_nozzle = "Pegar Bico Elétrico",
    insert_electric_nozzle = "Inserir Bico Elétrico",
    grab_nozzle = "Pegar Bico",
    return_nozzle = "Devolver Bico",
    grab_special_nozzle = "Pegar Bico Especial",
    return_special_nozzle = "Devolver Bico Especial",
    buy_jerrycan = "Comprar Galão de Combustível",
    station_talk_to_ped = "Conversar com Atendente do Posto de Gasolina",

    -- Jerry Can
    jerry_can_full = "Seu galão de combustível está cheio!",
    jerry_can_refuel = "Abasteça seu galão de combustível!",
    jerry_can_not_enough_fuel = "O galão de combustível não tem tanto combustível!",
    jerry_can_not_fit_fuel = "O galão de combustível não pode conter tanto combustível!",
    jerry_can_success = "Encheu o galão de combustível com sucesso!",
    jerry_can_success_vehicle = "Abasteceu o veículo com sucesso com o galão de combustível!",
    jerry_can_payment_label = "Galão de Combustível Comprado.",

    -- Syphoning
    syphon_success = "Retirou combustível com sucesso do veículo!",
    syphon_success_vehicle = "Abasteceu o veículo com sucesso com o kit de sifão!",
    syphon_electric_vehicle = "Este veículo é elétrico!",
    syphon_no_syphon_kit = "Você precisa de algo para sifonar gasolina.",
    syphon_inside_vehicle = "Você não pode sifonar de dentro do veículo!",
    syphon_more_than_zero = "Você precisa roubar mais do que 0L!",
    syphon_kit_cannot_fit_1 = "Você não pode sifonar tanto, seu recipiente não vai caber! Você só pode colocar: ",
    syphon_kit_cannot_fit_2 = " Litros.",
    syphon_not_enough_gas = "Você não tem gasolina suficiente para abastecer tanto!",
    syphon_dispatch_string = "(10-90) - Roubo de Gasolina",

    -- Electric Management (Dono)
    ev_manage_header = "Gestão de Energia Elétrica",
    ev_manage_consumed = "Consumo Atual: ",
    ev_manage_debt = "Dívida Pendente: R$",
    ev_manage_bill_due = "Vencimento da Fatura: ",
    ev_manage_status = "Status do Carregador: ",
    ev_manage_status_active = "ATIVO",
    ev_manage_status_disabled = "DESATIVADO (Dívida)",
    ev_manage_pay_bill = "Pagar Fatura Elétrica",
    ev_manage_loyalty_upgrade = "Melhorar Plano de Energia",
    ev_manage_kwh_price = "Preço por kWh (Custo): R$",
    ev_manage_grace_period = "Período de Carência: ",
    ev_manage_days = " dias",
}
Lang = Locale:new({phrases = Translations, warnOnMissing = true})