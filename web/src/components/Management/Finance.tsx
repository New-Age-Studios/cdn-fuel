import React, { useState, useEffect } from 'react';
import { fetchNui } from '../../utils/nui';

interface FinanceLog {
    id: number;
    type: string;
    amount: number;
    date: string;
}

interface FinanceProps {
    balance: number;
    onAction: (action: string, data?: any) => void;
}

const Finance: React.FC<FinanceProps> = ({ balance, onAction }) => {
    const [mode, setMode] = useState<'deposit' | 'withdraw'>('deposit');
    const [amount, setAmount] = useState<string>('');
    const [logs, setLogs] = useState<FinanceLog[]>([]);
    const [loading, setLoading] = useState(true);
    const [confirmDelete, setConfirmDelete] = useState(false);

    const fetchLogs = async () => {
        setLoading(true);
        try {
            const result = await fetchNui<FinanceLog[]>('manage:getFinanceLogs');
            if (result) setLogs(result);
        } catch (e) {
            console.error("Failed to fetch finance logs", e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchLogs();
    }, []);

    const handleConfirm = async () => {
        const val = Number(amount);
        if (!val || val <= 0) return;

        if (mode === 'withdraw' && val > balance) return; 

        onAction(`manage:${mode}`, { amount: val });
        setAmount('');
        
        // Refresh logs after a small delay to allow DB to update
        setTimeout(fetchLogs, 500);
    };

    const handleDeleteHistory = async () => {
        if (!confirmDelete) {
            setConfirmDelete(true);
            setTimeout(() => setConfirmDelete(false), 3000); // Reset confirmation after 3s
            return;
        }

        try {
            await fetchNui('manage:clearFinanceHistory');
            setLogs([]);
            setConfirmDelete(false);
        } catch (e) {
            console.error("Failed to clear history", e);
        }
    };

    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        return date.toLocaleString('pt-BR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    return (
        <div className="p-8 h-full flex flex-col gap-6 relative">
             <div>
                 <h2 className="text-3xl font-bold text-primary mb-1">Financeiro</h2>
                 <p className="text-sm text-text-muted">Gerencie o fluxo de caixa do seu posto</p>
             </div>

             {/* Main Grid with Fixed Height for Alignment */}
             <div className="grid grid-cols-1 lg:grid-cols-5 gap-6 h-[550px] min-h-0">
                {/* Left Section: Balance & Actions */}
                <div className="lg:col-span-2 flex flex-col gap-6 h-full">
                    {/* BALANCE CARD */}
                    <div className="bg-dashboard-card border border-border-color rounded-3xl p-7 shadow-sm transition-all flex-shrink-0">
                        <div className="flex justify-between items-center mb-6">
                            <div className="flex flex-col gap-1">
                                <span className="text-[10px] font-black text-text-muted uppercase tracking-[0.2em] flex items-center gap-2">
                                    <span className="w-1.5 h-1.5 rounded-full bg-neon-green"></span>
                                    Caixa do Posto
                                </span>
                                <h4 className="text-lg font-black text-primary tracking-tight">Saldo Disponível</h4>
                            </div>
                            <div className="p-4 rounded-2xl bg-neon-green/10 text-neon-green border border-neon-green/20">
                                <span className="material-symbols-outlined text-3xl">account_balance_wallet</span>
                            </div>
                        </div>
                        
                        <div className="space-y-1">
                            <h3 className="text-5xl font-black text-primary tracking-tighter">
                                <span className="text-xl font-bold text-text-muted mr-2 opacity-50">R$</span>
                                {balance.toLocaleString()}
                            </h3>
                            <div className="pt-4">
                                <div className="h-1.5 w-full bg-dashboard-element rounded-full overflow-hidden">
                                    {/* Set to full width as requested */}
                                    <div className="h-full bg-neon-green w-full opacity-80"></div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-dashboard-card border border-border-color rounded-3xl p-6 shadow-sm flex flex-col overflow-hidden">
                        <div className="flex bg-dashboard-element rounded-2xl p-1.5 mb-6 border border-border-color/30 flex-shrink-0">
                            <button 
                                onClick={() => setMode('deposit')}
                                className={`flex-1 py-3 text-[10px] font-black uppercase tracking-widest rounded-xl transition-all ${mode === 'deposit' ? 'bg-neon-green !text-black shadow-lg shadow-neon-green/20' : 'text-text-muted hover:text-primary'}`}
                            >
                                Depositar
                            </button>
                            <button 
                                onClick={() => setMode('withdraw')}
                                className={`flex-1 py-3 text-[10px] font-black uppercase tracking-widest rounded-xl transition-all ${mode === 'withdraw' ? 'bg-red-500 text-white shadow-lg shadow-red-500/20' : 'text-text-muted hover:text-primary'}`}
                            >
                                Sacar
                            </button>
                        </div>

                        <div className="space-y-6 flex-shrink-0">
                            <div>
                                <label className="block text-[9px] font-black text-text-muted uppercase tracking-widest mb-3 ml-1">Valor da Operação</label>
                                <div className="relative">
                                    <span className="absolute left-5 top-1/2 -translate-y-1/2 text-lg font-black text-text-muted">R$</span>
                                    <input 
                                        type="number" 
                                        className={`w-full bg-dashboard-element border border-border-color rounded-2xl py-4 pl-12 pr-4 text-xl font-black text-primary focus:outline-none transition-all [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none ${mode === 'deposit' ? 'focus:border-neon-green/40' : 'focus:border-red-500/40'}`}
                                        placeholder="0.00"
                                        value={amount}
                                        onChange={(e) => setAmount(e.target.value)}
                                    />
                                </div>
                            </div>
                            
                            <button 
                                onClick={handleConfirm}
                                disabled={!amount || Number(amount) <= 0}
                                className={`w-full py-4 rounded-2xl font-black text-[11px] uppercase tracking-[0.2em] transition-all active:scale-95 shadow-xl ${
                                    mode === 'deposit' 
                                    ? 'bg-neon-green !text-black hover:bg-neon-green/90 shadow-neon-green/20 disabled:opacity-30' 
                                    : 'bg-red-500 text-white hover:bg-red-600 shadow-red-500/20 disabled:opacity-30'
                                }`}
                            >
                                {mode === 'deposit' ? 'Confirmar Depósito' : 'Confirmar Saque'}
                            </button>
                        </div>
                        
                        <div className="flex-1"></div>
                    </div>
                </div>

                {/* Right Section: History */}
                <div className="lg:col-span-3 bg-dashboard-card border border-border-color rounded-3xl p-6 shadow-sm flex flex-col h-full overflow-hidden">
                    <div className="flex items-center justify-between mb-6 flex-shrink-0">
                        <div className="flex items-center gap-3">
                            <div className="p-2.5 rounded-xl bg-primary/5 text-primary">
                                <span className="material-symbols-outlined text-xl">history</span>
                            </div>
                            <h3 className="text-lg font-black text-primary uppercase tracking-tight">Histórico de Transações</h3>
                        </div>
                        
                        <div className="flex items-center gap-2">
                            {/* Delete History Button */}
                            <button 
                                onClick={handleDeleteHistory}
                                className={`p-2.5 rounded-xl transition-all flex items-center gap-2 group ${
                                    confirmDelete 
                                    ? 'bg-red-500 text-white px-4 ring-4 ring-red-500/20' 
                                    : 'bg-dashboard-element text-text-muted hover:text-red-500 border border-border-color/30'
                                }`}
                                title={confirmDelete ? "Clique novamente para confirmar" : "Limpar Histórico"}
                            >
                                <span className={`material-symbols-outlined text-xl ${confirmDelete ? 'animate-pulse' : ''}`}>
                                    {confirmDelete ? 'warning' : 'delete_sweep'}
                                </span>
                                {confirmDelete && <span className="text-[10px] font-black uppercase tracking-widest">Confirmar?</span>}
                            </button>

                            {/* Refresh Button */}
                            <button 
                                onClick={fetchLogs}
                                className="p-2.5 bg-dashboard-element text-text-muted hover:text-primary rounded-xl border border-border-color/30 transition-all hover:rotate-180 duration-500"
                                title="Atualizar"
                            >
                                <span className="material-symbols-outlined text-xl">refresh</span>
                            </button>
                        </div>
                    </div>

                    <div className="flex-1 overflow-y-auto custom-scrollbar pr-2 -mr-2 min-h-0">
                        {loading ? (
                            <div className="h-full flex items-center justify-center text-text-muted italic text-[11px] font-bold uppercase tracking-widest">
                                Carregando histórico...
                            </div>
                        ) : logs.length === 0 ? (
                            <div className="h-full flex flex-col items-center justify-center text-text-muted gap-4 opacity-30">
                                <span className="material-symbols-outlined text-6xl">receipt_long</span>
                                <p className="text-[10px] font-black uppercase tracking-[0.2em]">Nenhuma transação encontrada</p>
                            </div>
                        ) : (
                            <div className="space-y-3 pb-2">
                                {logs.map((log) => (
                                    <div key={log.id} className="bg-dashboard-element/20 border border-border-color/20 rounded-2xl p-4 flex items-center justify-between group hover:border-border-color/50 transition-all">
                                        <div className="flex items-center gap-4">
                                            <div className={`p-3 rounded-2xl ${
                                                log.type.includes('Saque') || log.type.includes('Compra') || log.type.includes('Upgrade') || log.type.includes('Fidelidade')
                                                ? 'bg-red-500/10 text-red-500' 
                                                : 'bg-green-500/10 text-green-500'
                                            }`}>
                                                <span className="material-symbols-outlined text-2xl">
                                                    {log.type.includes('Saque') ? 'account_balance_wallet' : 
                                                     log.type.includes('Depósito') ? 'savings' : 
                                                     log.type.includes('Compra') ? 'local_shipping' : 'unarchive'}
                                                </span>
                                            </div>
                                            <div className="space-y-0.5">
                                                <p className="text-sm font-black text-primary uppercase tracking-tight leading-tight">{log.type}</p>
                                                <div className="flex items-center gap-1.5 text-text-muted">
                                                    <span className="material-symbols-outlined text-[14px]">calendar_today</span>
                                                    <p className="text-[11px] font-bold tracking-wide">{formatDate(log.date)}</p>
                                                </div>
                                            </div>
                                        </div>
                                        <div className="text-right">
                                            <p className={`text-lg font-black leading-none ${
                                                log.type.includes('Saque') || log.type.includes('Compra') || log.type.includes('Upgrade') || log.type.includes('Fidelidade')
                                                ? 'text-red-500' 
                                                : 'text-green-500'
                                            }`}>
                                                {log.type.includes('Saque') || log.type.includes('Compra') || log.type.includes('Upgrade') || log.type.includes('Fidelidade') ? '-' : '+'} R$ {log.amount.toLocaleString()}
                                            </p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>
             </div>
        </div>
    );
};

export default Finance;
