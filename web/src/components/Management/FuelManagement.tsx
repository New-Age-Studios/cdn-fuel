import React, { useState } from 'react';

interface FuelManagementProps {
    stock: number;
    maxStock: number;
    price: number;
    reservePrice: number; // Cost to buy reserves
    onAction: (action: string, data?: any) => void;
}

const FuelManagement: React.FC<FuelManagementProps> = ({ stock, maxStock, price, reservePrice, onAction }) => {
    const [newPrice, setNewPrice] = useState<string>(price.toString());
    const [buyAmount, setBuyAmount] = useState<string>('');
    
    // Convert to numbers safely
    const currentPrice = Number(newPrice);
    const amountToBuy = Number(buyAmount);
    const totalCost = amountToBuy * reservePrice;
    
    // Quick add buttons
    const fillAmount = maxStock - stock;
    const availableSpace = maxStock - stock;
    const fuelPercentage = (stock / maxStock) * 100;

    // Helper to format currency for very large numbers
    const formatValue = (val: number) => {
        if (val > 999999999999) return `R$ ${(val/1000000000).toFixed(1)}B`;
        if (val > 999999999) return `R$ ${(val/1000000).toFixed(1)}M`;
        return `R$ ${val.toLocaleString()}`;
    };

    // Helper for progress bar color logic
    const getBarColor = () => {
        if (fuelPercentage < 25) return 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.3)]';
        if (fuelPercentage < 50) return 'bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.3)]';
        if (fuelPercentage < 75) return 'bg-yellow-500 shadow-[0_0_10px_rgba(234,179,8,0.3)]';
        return 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.3)]';
    };

    return (
        <div className="p-6 h-full flex flex-col gap-5 overflow-y-auto custom-scrollbar pb-16">
            
            {/* Header */}
            <div className="px-2">
                 <h2 className="text-2xl font-bold text-primary mb-0.5">Gerenciamento de Combustível</h2>
                 <p className="text-sm text-text-muted">Controle o estoque e ajuste os preços de venda</p>
            </div>

            <div className="flex flex-col gap-5 w-full max-w-5xl mx-auto">
                {/* 1. Buy Stock Section (TOP) */}
                <div className="bg-dashboard-card border border-border-color rounded-2xl p-6 hover:border-red-500/10 transition-all group shadow-sm">
                     <div className="flex items-center justify-between mb-6">
                        <div className="flex items-center gap-3">
                            <div className="p-3 rounded-xl bg-red-500/10 text-red-500 group-hover:rotate-6 transition-transform">
                                <span className="material-symbols-outlined text-2xl">local_shipping</span>
                            </div>
                            <div>
                                <h3 className="text-lg font-black text-primary uppercase tracking-tight">Repor Estoque</h3>
                                <p className="text-xs text-text-muted">Custo de importação: <span className="text-red-400 font-bold">R${reservePrice.toFixed(2)} / L</span></p>
                            </div>
                        </div>
                        
                        <div className="hidden md:flex gap-5">
                            <div className="text-right">
                                <p className="text-[9px] font-black text-text-muted uppercase tracking-widest mb-0.5 opacity-50">Nível Atual</p>
                                <p className="text-lg font-black text-primary">{stock.toLocaleString()} L</p>
                            </div>
                            <div className="w-[1px] h-8 bg-border-color/50 self-center"></div>
                            <div className="text-right">
                                <p className="text-[9px] font-black text-text-muted uppercase tracking-widest mb-0.5 opacity-50">Espaço Livre</p>
                                <p className="text-lg font-black text-green-500">{availableSpace.toLocaleString()} L</p>
                            </div>
                        </div>
                     </div>
                    
                     {/* Progress Bar Container - DYNAMIC COLOR LOGIC */}
                     <div className="mb-8 bg-dashboard-element/20 p-4 rounded-xl border border-border-color/30">
                         <div className="relative">
                            <div className="flex justify-between text-[10px] font-black text-text-muted uppercase mb-3 px-1">
                                <div className="flex gap-4">
                                    <span className="flex items-center gap-1.5"><span className={`w-2 h-2 rounded-full ${fuelPercentage < 25 ? 'bg-red-500 animate-pulse' : 'bg-red-900'}`}></span> Crítico</span>
                                    <span className="flex items-center gap-1.5"><span className={`w-2 h-2 rounded-full ${fuelPercentage >= 25 && fuelPercentage < 50 ? 'bg-orange-500' : 'bg-orange-900'}`}></span> Alerta</span>
                                    <span className="flex items-center gap-1.5"><span className={`w-2 h-2 rounded-full ${fuelPercentage >= 50 && fuelPercentage < 75 ? 'bg-yellow-500' : 'bg-yellow-900'}`}></span> Estável</span>
                                    <span className="flex items-center gap-1.5"><span className={`w-2 h-2 rounded-full ${fuelPercentage >= 75 ? 'bg-green-500' : 'bg-green-900'}`}></span> Ideal</span>
                                </div>
                                <span className="text-primary bg-dashboard-element px-2 py-0.5 rounded-md border border-border-color/30 font-black">{fuelPercentage.toFixed(1)}%</span>
                            </div>
                            <div className="w-full h-4 bg-dashboard-element rounded-full overflow-hidden p-0.5 border border-border-color/50 shadow-inner">
                                <div 
                                    className={`h-full rounded-full transition-all duration-1000 ${getBarColor()}`} 
                                    style={{ width: `${fuelPercentage}%` }}
                                >
                                    {/* Glass Shine Effect */}
                                    <div className="w-full h-full bg-gradient-to-b from-white/20 to-transparent opacity-50"></div>
                                </div>
                            </div>
                         </div>
                     </div>

                     {/* Action Controls */}
                     <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 items-stretch">
                        <div className="space-y-2 flex flex-col h-full">
                            <label className="block text-[9px] font-black text-text-muted uppercase tracking-[0.15em] ml-1">Quantidade em Litros</label>
                            <div className="relative flex-1">
                                <input 
                                    type="number" 
                                    className="w-full h-[60px] bg-dashboard-element border border-border-color rounded-xl py-3 px-4 text-xl font-black text-primary focus:outline-none focus:border-red-500/50 transition-all placeholder:text-text-muted/20 pr-32 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                                    placeholder="Ex: 5000"
                                    value={buyAmount}
                                    onChange={(e) => setBuyAmount(e.target.value)}
                                />
                                <button 
                                    onClick={() => setBuyAmount(fillAmount.toString())}
                                    className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-2 bg-red-500 text-white hover:bg-red-600 font-black rounded-lg transition-all active:scale-95 text-[9px] uppercase tracking-wider"
                                >
                                    Encher Tudo
                                </button>
                            </div>
                        </div>

                        <div className="space-y-2 flex flex-col h-full">
                            <label className="block text-[9px] font-black text-text-muted uppercase tracking-[0.15em] ml-1">Processamento de Pedido</label>
                            <div className="bg-dashboard-element/40 rounded-xl p-1.5 border border-border-color/30 flex items-stretch gap-2 flex-1 h-[60px]">
                                <div className="flex-1 bg-dashboard-card/50 rounded-lg px-3 flex flex-col justify-center overflow-hidden border border-border-color/10">
                                    <p className="text-[8px] font-black text-text-muted uppercase tracking-widest opacity-70">Total</p>
                                    <p className={`font-black text-primary truncate ${totalCost > 1000000000 ? 'text-sm' : 'text-base'}`}>
                                        {formatValue(totalCost)}
                                    </p>
                                </div>
                                <button 
                                    onClick={() => onAction('manage:buyStock', { amount: amountToBuy, price: totalCost })}
                                    disabled={!amountToBuy || amountToBuy <= 0 || (stock + amountToBuy) > maxStock}
                                    className="px-6 rounded-lg font-black text-[10px] bg-red-500 text-white hover:bg-red-600 transition-all shadow-md shadow-red-500/10 disabled:opacity-30 disabled:cursor-not-allowed active:scale-95 uppercase tracking-widest"
                                >
                                    Confirmar
                                </button>
                            </div>
                        </div>
                     </div>
                </div>

                {/* 2. Change Price Section (BOTTOM) */}
                <div className="bg-dashboard-card border border-border-color rounded-2xl p-6 hover:border-blue-500/10 transition-all group shadow-sm">
                     <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                        <div className="flex items-center gap-3">
                            <div className="p-3 rounded-xl bg-blue-500/10 text-blue-500 group-hover:-rotate-6 transition-transform">
                                <span className="material-symbols-outlined text-2xl">payments</span>
                            </div>
                            <div>
                                <h3 className="text-lg font-black text-primary uppercase tracking-tight">Preço de Venda</h3>
                                <p className="text-xs text-text-muted">Ajuste o valor na bomba</p>
                            </div>
                        </div>

                        <div className="flex flex-1 max-w-lg items-end gap-3">
                            <div className="flex-1 space-y-2">
                                <label className="block text-[9px] font-black text-text-muted uppercase tracking-[0.15em] ml-1">Preço por Litro</label>
                                <div className="relative">
                                    <span className="absolute left-4 top-1/2 -translate-y-1/2 text-xl font-black text-blue-500">R$</span>
                                    <input 
                                        type="number" 
                                        className="w-full h-[54px] bg-dashboard-element border border-border-color rounded-xl py-3 pl-12 pr-4 text-2xl font-black text-primary focus:outline-none focus:border-blue-500/50 transition-all [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                                        value={newPrice}
                                        onChange={(e) => setNewPrice(e.target.value)}
                                    />
                                </div>
                            </div>
                            <button 
                                onClick={() => onAction('manage:changePrice', { price: currentPrice })}
                                className="h-[54px] px-8 rounded-xl font-black text-[10px] bg-blue-500 text-white hover:bg-blue-600 transition-all shadow-md shadow-blue-500/10 active:scale-95 uppercase tracking-widest"
                            >
                                Atualizar
                            </button>
                        </div>
                     </div>
                     
                     <div className="mt-4 flex items-center gap-2 text-[10px] text-text-muted bg-blue-500/5 px-3 py-2 rounded-lg border border-blue-500/10 self-start">
                        <span className="material-symbols-outlined text-blue-500 text-xs">trending_up</span>
                        <p>Estimativa: Lucro de <span className="text-blue-400 font-bold">R${(currentPrice * 0.4).toFixed(2)}</span> / L.</p>
                     </div>
                </div>
            </div>
        </div>
    );
};

export default FuelManagement;
