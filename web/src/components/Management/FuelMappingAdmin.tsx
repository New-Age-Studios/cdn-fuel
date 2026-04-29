import React, { useState } from 'react';

interface Mapping {
    name: string;
    fuel_type: 'gasoline' | 'diesel' | 'ethanol' | 'aviation';
    is_model: boolean;
}

interface FuelMappingAdminProps {
    mappings: Mapping[];
    classes: string[];
    onSave: (mapping: Mapping) => void;
    onDelete: (name: string) => void;
    onClose: () => void;
}

const FuelMappingAdmin: React.FC<FuelMappingAdminProps> = ({ mappings, classes, onSave, onDelete, onClose }) => {
    const [activeTab, setActiveTab] = useState<'classes' | 'models'>('classes');
    const [searchTerm, setSearchTerm] = useState('');
    const [newModel, setNewModel] = useState('');
    const [selectedFuel, setSelectedFuel] = useState<'gasoline' | 'diesel' | 'ethanol' | 'aviation'>('gasoline');

    const filteredMappings = mappings.filter(m => 
        m.is_model === (activeTab === 'models') && 
        m.name.toLowerCase().includes(searchTerm.toLowerCase())
    );

    const fuelTypes = [
        { id: 'gasoline', label: 'Gasolina', color: 'text-orange-500', bg: 'bg-orange-500/10' },
        { id: 'diesel', label: 'Diesel', color: 'text-gray-400', bg: 'bg-gray-400/10' },
        { id: 'ethanol', label: 'Etanol', color: 'text-green-500', bg: 'bg-green-500/10' },
        { id: 'aviation', label: 'Aviation', color: 'text-blue-500', bg: 'bg-blue-500/10' },
    ];

    const handleSaveMapping = (name: string, type: any, isModel: boolean) => {
        onSave({ name, fuel_type: type, is_model: isModel });
    };

    return (
        <div className="flex w-full max-w-5xl bg-dashboard-bg border border-border-color rounded-3xl overflow-hidden shadow-2xl animate-in fade-in zoom-in duration-300 h-[700px]">
            {/* Sidebar */}
            <div className="w-64 bg-dashboard-element/20 border-r border-border-color p-6 flex flex-col gap-8">
                <div>
                    <h2 className="text-xl font-black text-primary tracking-tighter uppercase mb-1">Mapeamento</h2>
                    <p className="text-[10px] text-text-muted font-bold uppercase tracking-widest opacity-50">Configurações de Frota</p>
                </div>

                <div className="flex flex-col gap-2">
                    <button 
                        onClick={() => setActiveTab('classes')}
                        className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-black text-xs uppercase tracking-wider ${activeTab === 'classes' ? 'bg-primary text-dashboard-bg shadow-lg shadow-primary/20' : 'text-text-muted hover:bg-dashboard-element/50'}`}
                    >
                        <span className="material-symbols-outlined text-lg">category</span>
                        Classes
                    </button>
                    <button 
                        onClick={() => setActiveTab('models')}
                        className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-black text-xs uppercase tracking-wider ${activeTab === 'models' ? 'bg-primary text-dashboard-bg shadow-lg shadow-primary/20' : 'text-text-muted hover:bg-dashboard-element/50'}`}
                    >
                        <span className="material-symbols-outlined text-lg">directions_car</span>
                        Modelos (Exceções)
                    </button>
                </div>

                <div className="mt-auto">
                    <button 
                        onClick={onClose}
                        className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-xl border border-red-500/30 text-red-500 font-black text-xs uppercase tracking-widest hover:bg-red-500 hover:text-white transition-all active:scale-95"
                    >
                        <span className="material-symbols-outlined text-lg">close</span>
                        Sair
                    </button>
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 flex flex-col overflow-hidden bg-dashboard-bg/50 backdrop-blur-sm">
                <div className="p-8 border-b border-border-color/50 flex items-center justify-between">
                    <div className="relative flex-1 max-w-md">
                        <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-text-muted opacity-50">search</span>
                        <input 
                            type="text" 
                            placeholder={activeTab === 'classes' ? "Buscar classe..." : "Buscar modelo..."}
                            className="w-full bg-dashboard-element/30 border border-border-color/50 rounded-xl py-3 pl-12 pr-4 text-sm font-bold text-primary focus:outline-none focus:border-primary/50 transition-all"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>

                    {activeTab === 'models' && (
                        <div className="flex items-center gap-3">
                             <div className="flex bg-dashboard-element/40 p-1 rounded-xl border border-border-color/30">
                                {fuelTypes.map(f => (
                                    <button 
                                        key={f.id}
                                        onClick={() => setSelectedFuel(f.id as any)}
                                        className={`px-3 py-1.5 rounded-lg text-[9px] font-black uppercase transition-all ${selectedFuel === f.id ? 'bg-dashboard-card text-primary shadow-sm' : 'text-text-muted hover:text-primary'}`}
                                    >
                                        {f.label}
                                    </button>
                                ))}
                             </div>
                             <div className="flex items-center gap-2">
                                <input 
                                    type="text" 
                                    placeholder="NOME_MODELO"
                                    className="bg-dashboard-element/30 border border-border-color/50 rounded-xl py-2.5 px-4 text-xs font-black text-primary focus:outline-none w-32 uppercase"
                                    value={newModel}
                                    onChange={(e) => setNewModel(e.target.value)}
                                />
                                <button 
                                    onClick={() => { if(newModel) { handleSaveMapping(newModel, selectedFuel, true); setNewModel(''); } }}
                                    className="p-2.5 bg-primary text-dashboard-bg rounded-xl hover:scale-105 active:scale-95 transition-all shadow-lg shadow-primary/20"
                                >
                                    <span className="material-symbols-outlined text-lg">add</span>
                                </button>
                             </div>
                        </div>
                    )}
                </div>

                <div className="flex-1 overflow-y-auto p-8 custom-scrollbar">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {/* If Class Tab, show ALL classes even if not mapped */}
                        {activeTab === 'classes' ? (
                            classes.filter(c => c.toLowerCase().includes(searchTerm.toLowerCase())).map(className => {
                                const mapping = mappings.find(m => m.name.toUpperCase() === className.toUpperCase() && !m.is_model);
                                return (
                                    <div key={className} className="bg-dashboard-card/50 border border-border-color rounded-2xl p-5 hover:border-primary/30 transition-all group">
                                        <div className="flex items-center justify-between mb-4">
                                            <div className="flex items-center gap-3">
                                                <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                                                    <span className="material-symbols-outlined text-xl">category</span>
                                                </div>
                                                <h4 className="font-black text-sm text-primary uppercase tracking-tight">{className}</h4>
                                            </div>
                                            {mapping && (
                                                <button 
                                                    onClick={() => onDelete(mapping.name)}
                                                    className="opacity-0 group-hover:opacity-100 p-1.5 text-red-500/50 hover:text-red-500 transition-all"
                                                >
                                                    <span className="material-symbols-outlined text-lg">delete</span>
                                                </button>
                                            )}
                                        </div>

                                        <div className="grid grid-cols-2 gap-2">
                                            {fuelTypes.map(f => (
                                                <button
                                                    key={f.id}
                                                    onClick={() => handleSaveMapping(className, f.id, false)}
                                                    className={`px-3 py-2.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center justify-center gap-2 border ${
                                                        mapping?.fuel_type === f.id 
                                                        ? 'bg-primary text-dashboard-bg border-primary' 
                                                        : 'bg-dashboard-element/20 text-text-muted border-border-color/30 hover:border-primary/50'
                                                    }`}
                                                >
                                                    <span className="material-symbols-outlined text-xs">local_gas_station</span>
                                                    {f.label}
                                                </button>
                                            ))}
                                        </div>
                                    </div>
                                );
                            })
                        ) : (
                            /* Models List */
                            filteredMappings.length > 0 ? (
                                filteredMappings.map(m => (
                                    <div key={m.name} className="bg-dashboard-card/50 border border-border-color rounded-2xl p-5 flex items-center justify-between group animate-in slide-in-from-right-4 duration-300">
                                        <div className="flex items-center gap-4">
                                            <div className="w-12 h-12 rounded-2xl bg-dashboard-element/50 flex items-center justify-center text-primary border border-border-color/50">
                                                <span className="material-symbols-outlined">directions_car</span>
                                            </div>
                                            <div>
                                                <h4 className="font-black text-sm text-primary uppercase tracking-tight">{m.name}</h4>
                                                <div className="flex items-center gap-1.5 mt-1">
                                                    <span className={`w-1.5 h-1.5 rounded-full ${fuelTypes.find(f => f.id === m.fuel_type)?.bg.replace('/10', '') || 'bg-primary'}`}></span>
                                                    <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">
                                                        {fuelTypes.find(f => f.id === m.fuel_type)?.label}
                                                    </p>
                                                </div>
                                            </div>
                                        </div>

                                        <div className="flex items-center gap-2">
                                            <div className="flex bg-dashboard-element/40 p-1 rounded-xl border border-border-color/30 opacity-0 group-hover:opacity-100 transition-all scale-95 group-hover:scale-100">
                                                {fuelTypes.map(f => (
                                                    <button 
                                                        key={f.id}
                                                        onClick={() => handleSaveMapping(m.name, f.id, true)}
                                                        className={`p-1.5 rounded-lg transition-all ${m.fuel_type === f.id ? 'bg-primary text-dashboard-bg shadow-md' : 'text-text-muted hover:text-primary'}`}
                                                        title={f.label}
                                                    >
                                                        <span className="material-symbols-outlined text-sm">local_gas_station</span>
                                                    </button>
                                                ))}
                                            </div>
                                            <button 
                                                onClick={() => onDelete(m.name)}
                                                className="w-10 h-10 flex items-center justify-center text-red-500/40 hover:text-red-500 hover:bg-red-500/10 rounded-xl transition-all"
                                            >
                                                <span className="material-symbols-outlined">delete</span>
                                            </button>
                                        </div>
                                    </div>
                                ))
                            ) : (
                                <div className="col-span-full h-64 flex flex-col items-center justify-center text-text-muted opacity-30 border-2 border-dashed border-border-color rounded-3xl">
                                    <span className="material-symbols-outlined text-6xl mb-4">search_off</span>
                                    <p className="font-black text-xs uppercase tracking-[0.2em]">Nenhuma exceção encontrada</p>
                                </div>
                            )
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default FuelMappingAdmin;
