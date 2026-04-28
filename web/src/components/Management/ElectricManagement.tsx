import React from 'react';

interface LoyaltyPlan {
    label: string;
    price: number;
    discount: number;
}

interface ElectricManagementProps {
    data: {
        enabled: boolean;
        consumed: number;
        debt: number;
        loyaltyLevel: number;
        status: number | boolean;
        billDue: string;
        pricePerKwh: number;
        gracePeriod: number;
        loyaltyPlans: Record<number, LoyaltyPlan>;
    };
    onAction: (action: string, data?: any) => void;
}

const ElectricManagement: React.FC<ElectricManagementProps> = ({ data, onAction }) => {
    const { consumed, debt, loyaltyLevel, status, billDue, pricePerKwh, gracePeriod, loyaltyPlans } = data;
    const isOperational = status === 1 || status === true;

    const currentPlan = loyaltyPlans[loyaltyLevel];
    const discount = currentPlan?.discount || 0;
    const priceWithDiscount = pricePerKwh * (1 - (discount / 100));

    // Helper to format currency
    const formatCurrency = (val: number) => {
        return `R$ ${val.toLocaleString()}`;
    };

    // Helper to format date
    const formatDate = (dateVal: string | number) => {
        if (!dateVal) return 'N/A';
        try {
            const date = new Date(dateVal);
            if (isNaN(date.getTime())) return String(dateVal);
            return date.toLocaleString('pt-BR', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) {
            return String(dateVal);
        }
    };

    return (
        <div className="p-6 h-full flex flex-col gap-5 overflow-y-auto custom-scrollbar pb-16">
            
            {/* Header */}
            <div className="px-2">
                 <h2 className="text-2xl font-bold text-primary mb-0.5">Gestão de Energia Elétrica</h2>
                 <p className="text-sm text-text-muted">Monitore o consumo e gerencie as faturas de energia</p>
            </div>

            <div className="flex flex-col gap-5 w-full max-w-5xl mx-auto">
                
                {/* 1. Energy Usage & Bill Status */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                    
                    {/* Current Consumption */}
                    <div className="bg-dashboard-card border border-border-color rounded-2xl p-6 group">
                        <div className="flex items-center gap-3 mb-4">
                            <div className="p-3 rounded-xl bg-yellow-500/10 text-yellow-500">
                                <span className="material-symbols-outlined text-2xl">bolt</span>
                            </div>
                            <div>
                                <h3 className="text-sm font-black text-text-muted uppercase tracking-wider">Consumo Atual</h3>
                                <p className="text-2xl font-black text-primary">{consumed.toFixed(1)} kWh</p>
                            </div>
                        </div>
                        <div className="text-xs text-text-muted bg-dashboard-element/30 p-3 rounded-xl border border-border-color/20">
                            <p>Custo acumulado estimado: <span className="text-yellow-500 font-bold">{formatCurrency(consumed * priceWithDiscount)}</span></p>
                        </div>
                    </div>

                    {/* Pending Debt */}
                    <div className={`bg-dashboard-card border ${debt > 0 ? 'border-red-500/30 shadow-lg shadow-red-500/5' : 'border-border-color'} rounded-2xl p-6 relative overflow-hidden`}>
                        {debt > 0 && <div className="absolute top-0 left-0 w-1 h-full bg-red-500"></div>}
                        <div className="flex items-center justify-between mb-4">
                            <div className="flex items-center gap-3">
                                <div className={`p-3 rounded-xl ${debt > 0 ? 'bg-red-500/10 text-red-500' : 'bg-green-500/10 text-green-500'}`}>
                                    <span className="material-symbols-outlined text-2xl">{debt > 0 ? 'priority_high' : 'check_circle'}</span>
                                </div>
                                <div>
                                    <h3 className="text-sm font-black text-text-muted uppercase tracking-wider">Dívida Pendente</h3>
                                    <p className={`text-2xl font-black ${debt > 0 ? 'text-red-500' : 'text-green-500'}`}>{formatCurrency(debt)}</p>
                                </div>
                            </div>
                            {debt > 0 && (
                                <button 
                                    onClick={() => onAction('manage:payElectricBill')}
                                    className="px-4 py-2 bg-red-500 hover:bg-red-600 text-white font-bold rounded-xl transition-all active:scale-95 text-xs uppercase"
                                >
                                    Pagar Agora
                                </button>
                            )}
                        </div>
                        <div className="flex items-center gap-2 text-[11px] text-text-muted">
                            <span className="material-symbols-outlined text-xs">calendar_today</span>
                            <p>Próximo vencimento: <span className="text-primary font-bold">{formatDate(billDue)}</span></p>
                        </div>
                    </div>
                </div>

                {/* 2. Service Status & Info */}
                <div className="bg-dashboard-card border border-border-color rounded-2xl p-6">
                    <div className="flex items-center justify-between gap-6">
                        <div className="flex items-center gap-4">
                             <div className={`size-12 rounded-full flex items-center justify-center ${isOperational ? 'bg-green-500/20 text-green-500' : 'bg-red-500/20 text-red-500'}`}>
                                <span className={`material-symbols-outlined text-3xl ${isOperational ? '' : 'animate-pulse'}`}>
                                    {isOperational ? 'power' : 'power_off'}
                                </span>
                             </div>
                             <div>
                                <h3 className="text-lg font-black text-primary">Status do Serviço</h3>
                                <p className={`text-sm font-bold ${isOperational ? 'text-green-500' : 'text-red-500'}`}>
                                    {isOperational ? 'CARREGADORES OPERACIONAIS' : 'CARREGADORES DESATIVADOS'}
                                </p>
                             </div>
                        </div>
                        <div className="hidden lg:block max-w-sm text-xs text-text-muted text-right">
                            <p>Após o vencimento, você possui <span className="text-primary font-bold">{gracePeriod} dias</span> de carência antes do bloqueio automático por falta de pagamento.</p>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
};

export default ElectricManagement;
