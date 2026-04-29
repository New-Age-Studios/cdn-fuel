import React from 'react';
import { useTheme } from '../context/ThemeContext';

interface FuelType {
    id: string;
    label: string;
    price: number;
    color: string;
    icon: string;
    description: string;
}

interface FuelTypeSelectorProps {
    availableFuels: FuelType[];
    stationName: string;
    onSelect: (fuel: FuelType) => void;
    onClose: () => void;
}

const FuelTypeSelector: React.FC<FuelTypeSelectorProps> = ({ 
    availableFuels, 
    stationName, 
    onSelect, 
    onClose 
}) => {
    useTheme();

    return (
        <div className="flex w-full max-w-4xl bg-dashboard-bg border border-border-color rounded-2xl overflow-hidden shadow-2xl animate-in fade-in zoom-in duration-300">
            {/* Left Sidebar Decoration */}
            <div className="w-24 bg-dashboard-card border-r border-border-color flex flex-col items-center py-8 gap-8 shrink-0">
                <div className="size-12 bg-neon-green/10 rounded-xl flex items-center justify-center text-neon-green shadow-inner">
                    <span className="material-symbols-outlined text-3xl">local_gas_station</span>
                </div>
                
                <div className="flex-1" />

                <button 
                    onClick={onClose} 
                    className="size-12 rounded-xl bg-dashboard-element hover:bg-red-500/10 text-text-muted hover:text-red-500 flex items-center justify-center transition-all active:scale-90"
                >
                    <span className="material-symbols-outlined">close</span>
                </button>
            </div>

            <div className="flex-1 p-10 flex flex-col">
                <div className="mb-10">
                    <h1 className="text-3xl font-black text-primary tracking-tight uppercase italic">
                        {stationName || 'Posto de Combustível'}
                    </h1>
                    <div className="flex items-center gap-2 mt-2">
                        <span className="px-2.5 py-1 rounded bg-neon-green/10 text-neon-green text-[10px] font-black uppercase tracking-widest border border-neon-green/20">
                            Passo 1 / 3
                        </span>
                        <p className="text-text-muted text-sm font-bold uppercase tracking-tight">
                            Selecione o tipo de combustível desejado
                        </p>
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    {availableFuels.map((fuel) => (
                        <button
                            key={fuel.id}
                            onClick={() => onSelect(fuel)}
                            className="group relative bg-dashboard-card border border-border-color rounded-2xl p-6 text-left transition-all hover:border-primary hover:shadow-xl hover:shadow-primary/5 active:scale-[0.98] overflow-hidden"
                        >
                            {/* Accent Background */}
                            <div 
                                className="absolute top-0 right-0 size-32 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity translate-x-10 -translate-y-10"
                                style={{ color: fuel.color }}
                            >
                                <span className="material-symbols-outlined text-[120px]">{fuel.icon}</span>
                            </div>

                            <div 
                                className="size-12 rounded-xl flex items-center justify-center mb-6 shadow-lg"
                                style={{ backgroundColor: `${fuel.color}20`, color: fuel.color }}
                            >
                                <span className="material-symbols-outlined text-2xl">{fuel.icon}</span>
                            </div>

                            <h3 className="text-xl font-black text-primary uppercase mb-1">{fuel.label}</h3>
                            <p className="text-text-muted text-xs font-medium leading-relaxed mb-6 h-8 line-clamp-2">
                                {fuel.description}
                            </p>

                            <div className="flex items-baseline gap-1 mt-auto">
                                <span className="text-2xl font-black text-primary">${fuel.price}</span>
                                <span className="text-[10px] font-bold text-text-muted uppercase">/ Litro</span>
                            </div>

                            {/* Bottom bar indicator */}
                            <div 
                                className="absolute bottom-0 left-0 h-1.5 w-0 group-hover:w-full transition-all duration-500"
                                style={{ backgroundColor: fuel.color }}
                            />
                        </button>
                    ))}
                </div>

                <div className="mt-12 p-5 bg-dashboard-element/30 rounded-xl border border-border-color/50 flex items-center gap-4">
                    <span className="material-symbols-outlined text-neon-green text-xl">info</span>
                    <p className="text-[11px] text-text-muted font-bold uppercase tracking-tight leading-normal">
                        Certifique-se de escolher o combustível correto para o seu veículo. O uso de combustível incompatível causará danos severos ao motor.
                    </p>
                </div>
            </div>
        </div>
    );
};

export default FuelTypeSelector;
