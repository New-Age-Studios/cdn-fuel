import React from 'react';
import { fetchNui } from '../utils/nui';

interface StationPurchaseProps {
    stationName: string;
    price: number;
    tax?: number;
    onClose: () => void;
}

const StationPurchase: React.FC<StationPurchaseProps> = ({ 
    stationName, 
    price,
    tax,
    onClose 
}) => {
    
    const handleConfirm = () => {
        fetchNui('purchase:confirm');
        onClose();
    };

    const formatCurrency = (value: number) => {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(value);
    };

    return (
        <div className="fixed inset-0 flex items-center justify-center z-50 animate-in fade-in duration-300">
             {/* Transparent Backdrop (no blur or color as requested) */}
             <div className="absolute inset-0" onClick={onClose}></div>

            <div className="w-full max-w-md bg-dashboard-bg border border-border-color rounded-2xl p-6 shadow-2xl relative overflow-hidden z-10">
                {/* Close Button */}
                <button onClick={onClose} className="absolute top-4 right-4 text-text-muted hover:text-white transition-colors">
                    <span className="material-symbols-outlined">close</span>
                </button>

                {/* Header */}
                <div className="text-center mb-6">
                    <div className="inline-flex items-center justify-center p-4 rounded-full bg-neon-green/10 text-neon-green mb-4 ring-1 ring-neon-green/20">
                        <span className="material-symbols-outlined text-4xl">storefront</span>
                    </div>
                    <h2 className="text-2xl font-bold text-white tracking-tight">Comprar Propriedade</h2>
                    <p className="text-text-muted text-sm mt-1">Deseja adquirir este estabelecimento?</p>
                </div>

                {/* Details Card */}
                <div className="bg-dashboard-card rounded-xl p-4 mb-6 border border-border-color/50">
                    <div className="flex justify-between items-center mb-2">
                        <span className="text-sm text-text-muted">Estabelecimento</span>
                        <span className="font-medium text-white">{stationName}</span>
                    </div>
                    <div className="flex justify-between items-center mb-2">
                        <span className="text-sm text-text-muted">Valor do Posto</span>
                        <span className="font-medium text-white">{formatCurrency(price - (tax || 0))}</span>
                    </div>
                    {tax !== undefined && tax > 0 && (
                        <>
                             <div className="w-full h-px bg-border-color/50 my-2"></div>
                            <div className="flex justify-between items-center mb-2">
                                <span className="text-sm text-text-muted">Imposto</span>
                                <span className="font-medium text-text-muted">{formatCurrency(tax)}</span>
                            </div>
                        </>
                    )}
                     <div className="w-full h-px bg-border-color/50 my-2"></div>
                    <div className="flex justify-between items-center">
                        <span className="text-sm text-text-muted">Valor Total</span>
                        <span className="font-bold text-xl text-neon-green">{formatCurrency(price)}</span>
                    </div>
                </div>

                {/* Actions */}
                <div className="grid grid-cols-2 gap-3">
                    <button 
                        onClick={onClose}
                        className="p-3 rounded-xl border border-border-color text-text-muted hover:text-white hover:bg-white/5 transition-all font-medium text-sm"
                    >
                        CANCELAR
                    </button>
                    <button 
                        onClick={handleConfirm}
                        className="p-3 rounded-xl bg-neon-green !text-black font-black text-sm hover:bg-neon-green/90 transition-all shadow-[0_0_20px_-5px_rgba(34,197,94,0.4)] flex items-center justify-center gap-2"
                    >
                        <span>CONFIRMAR COMPRA</span>
                        <span className="material-symbols-outlined text-lg">check</span>
                    </button>
                </div>

            </div>
        </div>
    );
};

export default StationPurchase;
