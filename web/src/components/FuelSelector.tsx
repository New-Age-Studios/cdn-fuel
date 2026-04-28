import React, { useState, useEffect } from 'react';
import { useTheme } from '../context/ThemeContext';

interface FuelSelectorProps {
  maxFuel: number;
  currentFuel: number;
  price: number;
  isJerryCan?: boolean;
  isElectric?: boolean;
  isSyphon?: boolean;
  isJerryCanRefuel?: boolean;
  isJerryCanRefill?: boolean;
  jerryCans?: any[];
  selectedJerryCanIndex?: number;
  onJerryCanSelect?: (index: number) => void;
  syphonMode?: 'in' | 'out'; // 'in' = refuel car, 'out' = siphon from car
  onConfirm: (amount: number) => void;
  onClose: () => void;
}

const FuelSelector: React.FC<FuelSelectorProps> = ({ 
  maxFuel, 
  currentFuel, 
  price, 
  isJerryCan, 
  isElectric, 
  isSyphon, 
  isJerryCanRefuel, 
  isJerryCanRefill,
  jerryCans = [],
  selectedJerryCanIndex = 0,
  onJerryCanSelect,
  syphonMode, 
  onConfirm, 
  onClose 
}) => {
  const [amount, setAmount] = useState<number>(0);
  const { theme, toggleTheme } = useTheme();

  useEffect(() => {
    setAmount(maxFuel);
  }, [maxFuel]);

  const handleSliderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setAmount(Number(e.target.value));
  };

  const getTitle = () => {
      if (isJerryCanRefill) return 'Reabastecer Galão';
      if (isJerryCanRefuel) return 'Abastecendo com Galão';
      if (isSyphon) return syphonMode === 'out' ? 'Drenando Veículo' : 'Abastecendo Veículo';
      if (isJerryCan) return 'Quantidade';
      if (isElectric) return 'Carregamento';
      return 'Abastecimento';
  }

  const getSubtitle = () => {
      if (isJerryCanRefill) return 'Quanto deseja abastecer no galão?';
      if (isJerryCanRefuel) return 'Quanto deseja colocar no veículo?';
      if (isSyphon) return syphonMode === 'out' ? 'Quanto deseja retirar?' : 'Quanto deseja colocar?';
      if (isJerryCan) return 'Quantos galões deseja comprar?';
      if (isElectric) return 'Defina a carga desejada';
      return 'Defina a quantidade de combustível';
  }

  return (
    <div className="flex w-full max-w-5xl bg-dashboard-bg border border-border-color rounded-xl overflow-hidden shadow-2xl animate-in fade-in zoom-in duration-300">
      
       {/* Sidebar / Decoration Left */}
       <div className="w-20 bg-dashboard-card border-r border-border-color flex flex-col items-center py-6 gap-6 shrink-0">
        <div className={`size-10 bg-dashboard-element rounded-lg flex items-center justify-center shadow-inner ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>
          <span className="material-symbols-outlined text-2xl drop-shadow-sm">
              {isJerryCan ? 'propane_tank' : isElectric ? 'bolt' : isSyphon ? 'construction' : isJerryCanRefuel || isJerryCanRefill ? 'propane_tank' : 'local_gas_station'}
          </span>
        </div>
        
        <div className="flex-1 w-full px-4 flex flex-col gap-4">
               {/* Spacer */}
        </div>

        <button onClick={toggleTheme} className="size-10 rounded-lg hover:bg-dashboard-element text-text-muted hover:text-primary flex items-center justify-center transition-colors" title="Mudar Tema">
             <span className="material-symbols-outlined">{theme === 'dark' ? 'light_mode' : 'dark_mode'}</span>
        </button>

        <button onClick={onClose} className="size-10 rounded-lg hover:bg-dashboard-element text-text-muted hover:text-primary flex items-center justify-center transition-colors">
            <span className="material-symbols-outlined">arrow_back</span>
        </button>
      </div>

      {/* Jerry Can Selection List (If applicable) */}
      {isJerryCanRefill && jerryCans.length > 1 && (
        <div className="w-64 bg-dashboard-card border-r border-border-color p-4 flex flex-col gap-3 overflow-y-auto max-h-[600px] scrollbar-hide shrink-0">
            <h2 className="text-xs font-black text-text-muted uppercase tracking-widest mb-2 px-1">Meus Galões</h2>
            {jerryCans.map((can, idx) => (
                <button
                    key={idx}
                    onClick={() => onJerryCanSelect?.(idx)}
                    className={`p-4 rounded-xl border transition-all flex flex-col gap-2 text-left ${
                        selectedJerryCanIndex === idx 
                        ? 'bg-neon-green/10 border-neon-green text-primary shadow-lg shadow-neon-green/5' 
                        : 'bg-dashboard-element/50 border-border-color hover:border-text-muted/30 text-text-muted'
                    }`}
                >
                    <div className="flex items-center justify-between w-full">
                        <span className="text-xs font-black uppercase tracking-tight">Galão #{idx + 1}</span>
                        <span className={`material-symbols-outlined text-lg ${selectedJerryCanIndex === idx ? 'text-neon-green' : 'text-text-muted/30'}`}>
                            {selectedJerryCanIndex === idx ? 'check_circle' : 'radio_button_unchecked'}
                        </span>
                    </div>
                    <div className="flex items-baseline gap-1">
                        <span className="text-xl font-black">{Math.floor(can.fuel)}</span>
                        <span className="text-[10px] font-bold opacity-60">/ {can.cap}L</span>
                    </div>
                    <div className="w-full bg-black/20 h-1 rounded-full overflow-hidden">
                        <div 
                            className={`h-full transition-all duration-500 ${selectedJerryCanIndex === idx ? 'bg-neon-green' : 'bg-text-muted/30'}`} 
                            style={{ width: `${(can.fuel / can.cap) * 100}%` }}
                        />
                    </div>
                </button>
            ))}
        </div>
      )}

      <div className="flex-1 p-8 flex flex-col min-h-0">
          <div className="flex items-center justify-between mb-8">
            <div>
                <h1 className="text-2xl font-bold text-primary tracking-tight">
                    {getTitle()}
                </h1>
                <div className="flex items-center gap-2 mt-1">
                    <span className={`px-2 py-0.5 rounded ${isElectric ? 'bg-electric-yellow/10 text-electric-yellow' : 'bg-neon-green/10 text-neon-green'} text-xs font-bold uppercase tracking-wider`}>Passo 2 / 2</span>
                    <p className="text-text-muted text-sm font-medium">
                        {getSubtitle()}
                    </p>
                </div>
            </div>
            {!isSyphon && !isJerryCanRefuel && (
                <div className="flex items-center justify-center px-4 py-2 bg-dashboard-card rounded-lg border border-border-color shadow-sm">
                    <span className="text-primary font-bold text-lg">${Math.ceil(amount * price)}</span>
                    <span className="text-text-muted text-xs ml-2 uppercase font-bold tracking-wider">Total</span>
                </div>
            )}
        </div>

        {/* Stats Cards */}
        <div className={`grid ${isJerryCan ? 'grid-cols-1' : 'grid-cols-2'} gap-4 mb-6`}>
             <div className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group shadow-sm">
                  <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                      <span className="material-symbols-outlined text-6xl text-primary">
                          {isJerryCan ? 'shopping_bag' : isElectric ? 'charging_station' : isSyphon && syphonMode === 'out' ? 'output' : 'water_drop'}
                      </span>
                  </div>
                  <p className="text-xs font-black text-text-muted uppercase tracking-wider">
                      {isJerryCan ? 'Quantidade' : isElectric ? 'Energia Selecionada' : 'Volume Selecionado'}
                  </p>
                  <div className="mt-2 flex items-baseline gap-1">
                      <span className="text-4xl font-black text-primary tracking-tighter">{amount}</span>
                      <span className={`text-sm font-bold ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>
                          {isJerryCan ? 'UNIDADES' : isElectric ? 'kWh' : 'LITROS'}
                      </span>
                  </div>
             </div>

             {!isJerryCan && (
             <div className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group shadow-sm">
                  <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                      <span className="material-symbols-outlined text-6xl text-primary">
                          {isElectric ? 'battery_charging_full' : isSyphon ? 'local_gas_station' : isJerryCanRefuel || isJerryCanRefill ? 'local_gas_station' : 'ev_station'}
                      </span>
                  </div>
                  <p className="text-xs font-black text-text-muted uppercase tracking-wider">
                      {isElectric ? 'Bateria Prevista' : (isJerryCanRefill ? 'Galão Previsto' : 'Tanque Previsto')}
                  </p>
                  <div className="mt-2 flex items-baseline gap-1">
                      <span className="text-4xl font-black text-primary tracking-tighter">
                          {isJerryCanRefill 
                            ? Math.min(jerryCans[selectedJerryCanIndex]?.cap || 100, Math.round(currentFuel + amount))
                            : Math.min(100, Math.round(currentFuel + (isSyphon && syphonMode === 'out' ? -amount : amount)))
                          }{isJerryCanRefill ? 'L' : '%'}
                      </span>
                      <span className="text-sm font-bold text-text-muted">{isElectric ? 'CARREGADA' : (isJerryCanRefill ? 'VOLUME' : 'CHEIO')}</span>
                  </div>
                  {/* Mini Progress */}
                  <div className="w-full bg-dashboard-element h-1.5 rounded-full mt-3 overflow-hidden shadow-inner">
                       <div className={`h-full ${isElectric ? 'bg-electric-yellow shadow-[0_0_10px_#facc15]' : 'bg-neon-green shadow-[0_0_10px_rgba(34,197,94,0.5)]'} transition-all duration-300`} 
                            style={{ 
                                width: `${
                                    isJerryCanRefill 
                                    ? (Math.min(jerryCans[selectedJerryCanIndex]?.cap || 100, Math.round(currentFuel + amount)) / (jerryCans[selectedJerryCanIndex]?.cap || 100)) * 100
                                    : Math.min(100, Math.round(currentFuel + (isSyphon && syphonMode === 'out' ? -amount : amount)))
                                }%` 
                            }}
                       ></div>
                  </div>
             </div>
             )}
        </div>

        {/* Slider Section */}
        <div className="flex-1 bg-dashboard-card border border-border-color rounded-xl p-6 flex flex-col justify-center gap-6 shadow-sm">
             <div className="flex items-center justify-between">
                  <span className="text-sm font-black text-primary uppercase tracking-wider">Ajuste Manual</span>
                  <span className="text-xs font-black text-text-muted">
                      {amount} {isJerryCan ? 'UN' : isElectric ? 'kWh' : 'L'} / {maxFuel} {isJerryCan ? 'UN' : isElectric ? 'kWh' : 'L'}
                  </span>
             </div>

             <div className="relative h-8 w-full flex items-center group">
                <input 
                  type="range" 
                  min="0" 
                  max={maxFuel} 
                  value={amount} 
                  onChange={handleSliderChange}
                  className={`w-full h-8 opacity-0 z-20 cursor-pointer absolute top-0 left-0`}
                />
                {/* Visual Track */}
                <div className="w-full h-2.5 bg-dashboard-element rounded-full relative z-10 pointer-events-none shadow-inner border border-border-color/10">
                     <div 
                        className={`h-full ${isElectric ? 'bg-electric-yellow' : 'bg-neon-green'} rounded-full relative shadow-[0_0_10px_rgba(0,0,0,0.1)]`} 
                        style={{ width: `${(amount / maxFuel) * 100}%` }}
                     >
                        {/* Slider Handle */}
                        <div className={`absolute right-0 top-1/2 -translate-y-1/2 size-10 bg-white rounded-full shadow-[0_4px_12px_rgba(0,0,0,0.2)] translate-x-1/2 flex items-center justify-center border-4 ${isElectric ? 'border-electric-yellow' : 'border-neon-green'} transition-transform group-hover:scale-110 active:scale-95 cursor-grab active:cursor-grabbing z-30`}>
                            <span className={`material-symbols-outlined text-xl ${isElectric ? 'text-electric-yellow' : 'text-neon-green'} drop-shadow-sm`}>
                                {isElectric ? 'bolt' : 'local_gas_station'}
                            </span>
                        </div>
                     </div>
                </div>
             </div>
             
             <div className="flex justify-between gap-4 mt-2">
                 <button onClick={() => setAmount(0)} className="flex-1 py-3 rounded-xl bg-dashboard-element hover:bg-dashboard-element/80 border border-border-color text-primary font-bold transition-all text-sm uppercase tracking-wide active:scale-95">
                    Nivel Atual
                 </button>
                 <button onClick={() => setAmount(maxFuel)} className={`flex-1 py-3 rounded-xl ${isElectric ? 'bg-electric-yellow/10 hover:bg-electric-yellow/20' : 'bg-neon-green/10 hover:bg-neon-green/20'} border border-border-color/50 text-primary font-black transition-all text-sm uppercase tracking-wide active:scale-95`}>
                    Completar
                 </button>
             </div>

             <button onClick={() => onConfirm(amount)} className={`w-full py-4 mt-auto rounded-2xl ${isElectric ? 'bg-electric-yellow hover:bg-electric-yellow-hover' : 'bg-neon-green hover:bg-neon-green-hover'} !text-black hover:!text-black font-black uppercase tracking-[0.15em] transition-all shadow-xl active:scale-[0.97] border-b-4 border-black/10`}>
                {isJerryCan ? 'Comprar Agora' : 'Confirmar'}
             </button>
        </div>
      </div>
    </div>
  );
};

export default FuelSelector;
