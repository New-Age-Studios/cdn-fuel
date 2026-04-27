import React, { useState, useEffect } from 'react';
import { fetchNui } from '../../utils/nui';

interface LogEntry {
    id: number;
    station_location: number;
    start_date: string;
    end_date: string;
    total_liters: number;
    peak_liters: number;
    total_revenue: number;
}

interface DailySale {
    day: string;
    total_liters: number;
    total_revenue: number;
}

interface StatsData {
    totalLiters: number;
    totalRevenue: number;
    weekLiters: number;
    weekRevenue: number;
    peakDay: { day: string; liters: number };
}

const Analytics: React.FC = () => {
    const [dailySales, setDailySales] = useState<DailySale[]>([]);
    const [weeklyLogs, setWeeklyLogs] = useState<LogEntry[]>([]);
    const [stats, setStats] = useState<StatsData | null>(null);
    const [loading, setLoading] = useState(true);
    
    // Modal State
    const [showModal, setShowModal] = useState(false);
    const [startDate, setStartDate] = useState('');
    const [endDate, setEndDate] = useState('');

    const fetchAnalytics = async () => {
        setLoading(true);
        try {
            const data = await fetchNui<any>('manage:getAnalytics');
            setDailySales(data.dailySales || []);
            setWeeklyLogs(data.weeklyLogs || []);
            setStats(data.stats || null);
        } catch (e) {
            console.error(e);
            // Mock for dev
             setDailySales([
                { day: '2023-10-01', total_liters: 1500, total_revenue: 7500 },
                { day: '2023-10-02', total_liters: 2200, total_revenue: 11000 },
                { day: '2023-10-03', total_liters: 1800, total_revenue: 9000 },
                { day: '2023-10-04', total_liters: 2500, total_revenue: 12500 },
                { day: '2023-10-05', total_liters: 3000, total_revenue: 15000 },
                { day: '2023-10-06', total_liters: 2800, total_revenue: 14000 },
                { day: '2023-10-07', total_liters: 3200, total_revenue: 16000 },
            ]);
            setStats({
                totalLiters: 45000,
                totalRevenue: 225000,
                weekLiters: 15000,
                weekRevenue: 75000,
                peakDay: { day: '2023-10-07', liters: 3200 }
            });
        }
        setLoading(false);
    };

    useEffect(() => {
        fetchAnalytics();
        
        // Default dates for modal
        const now = new Date();
        const weekAgo = new Date();
        weekAgo.setDate(now.getDate() - 7);
        setEndDate(now.toISOString().split('T')[0]);
        setStartDate(weekAgo.toISOString().split('T')[0]);
    }, []);

    const handleCloseWeek = async () => {
        try {
            await fetchNui('manage:closeWeek', { startDate, endDate });
            setShowModal(false);
            fetchAnalytics(); // Refresh data
        } catch (e) {
            console.error(e);
        }
    };

    // Calculate chart path
    const w = 600;
    const h = 200;
    const maxVal = Math.max(...dailySales.map(d => d.total_liters), 100);
    const getX = (i: number) => (i / (dailySales.length - 1)) * w;
    const getY = (v: number) => h - (v / maxVal) * h;

    const linePath = dailySales.map((d, i) => `${i === 0 ? 'M' : 'L'} ${getX(i)} ${getY(d.total_liters)}`).join(' ');
    const areaPath = `${linePath} L ${getX(dailySales.length - 1)} ${h} L 0 ${h} Z`;

    const formatDate = (dateStr: string) => {
        if (!dateStr || dateStr === "N/A") return "N/A";
        return new Date(dateStr).toLocaleDateString('pt-BR');
    };

    if (loading) {
        return (
            <div className="h-full flex items-center justify-center text-white/50">
                <span className="material-symbols-outlined animate-spin text-4xl">sync</span>
            </div>
        );
    }

    return (
        <div className="h-full flex flex-col gap-6 p-2 overflow-y-auto custom-scrollbar pr-4 relative">
            
            {/* Stats Cards Row */}
            <div className="grid grid-cols-4 gap-4">
                <div className="bg-dashboard-card p-4 rounded-2xl border border-border-color relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <span className="material-symbols-outlined text-4xl text-primary">database</span>
                    </div>
                    <p className="text-text-muted text-xs font-medium uppercase tracking-wider">Histórico Total</p>
                    <h4 className="text-xl font-bold text-primary mt-1">
                        {stats?.totalLiters.toLocaleString() || 0} <span className="text-[10px] text-orange-400 font-normal">L</span>
                    </h4>
                    <p className="text-[10px] text-emerald-400 mt-0.5">R$ {stats?.totalRevenue.toLocaleString() || 0}</p>
                </div>

                <div className="bg-dashboard-card p-4 rounded-2xl border border-border-color relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <span className="material-symbols-outlined text-4xl text-primary">calendar_view_week</span>
                    </div>
                    <p className="text-text-muted text-xs font-medium uppercase tracking-wider">Volume Semanal</p>
                    <h4 className="text-xl font-bold text-primary mt-1">
                        {stats?.weekLiters.toLocaleString() || 0} <span className="text-[10px] text-indigo-400 font-normal">L</span>
                    </h4>
                    <p className="text-[10px] text-text-muted mt-0.5">Últimos 7 dias</p>
                </div>

                <div className="bg-dashboard-card p-4 rounded-2xl border border-border-color relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <span className="material-symbols-outlined text-4xl text-primary">payments</span>
                    </div>
                    <p className="text-text-muted text-xs font-medium uppercase tracking-wider">Receita Semanal</p>
                    <h4 className="text-xl font-bold text-primary mt-1 underline decoration-emerald-500/30 underline-offset-4">
                        <span className="text-xs font-normal text-text-muted">R$</span> {stats?.weekRevenue.toLocaleString() || 0}
                    </h4>
                    <p className="text-[10px] text-emerald-500/80 mt-0.5">+ Lucro líquido</p>
                </div>

                <div className="bg-dashboard-card p-4 rounded-2xl border border-border-color relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <span className="material-symbols-outlined text-4xl text-primary">auto_graph</span>
                    </div>
                    <p className="text-text-muted text-xs font-medium uppercase tracking-wider">Recorde Diário</p>
                    <h4 className="text-xl font-bold text-primary mt-1">
                        {stats?.peakDay.liters.toLocaleString() || 0} <span className="text-[10px] text-emerald-400 font-normal">L</span>
                    </h4>
                    <p className="text-[10px] text-text-muted font-mono mt-0.5 uppercase">DIA: {formatDate(stats?.peakDay.day || "")}</p>
                </div>
            </div>

            {/* Charts Section */}
            <div className="bg-dashboard-card p-6 rounded-2xl border border-border-color">
                <div className="flex justify-between items-center mb-6">
                    <div>
                        <h3 className="text-xl font-bold text-primary">
                            Tendência de Vendas
                        </h3>
                        <p className="text-xs text-text-muted">Volume de litros nos últimos 7 dias</p>
                    </div>
                    <button 
                        onClick={() => setShowModal(true)}
                        className="px-4 py-2 bg-indigo-500 hover:bg-indigo-600 text-white rounded-lg transition-colors text-sm font-medium shadow-lg shadow-indigo-500/20 flex items-center gap-2"
                    >
                        <span className="material-symbols-outlined text-sm">event_repeat</span>
                        Fechar Período
                    </button>
                </div>
                
                <div className="h-64 w-full relative">
                    {dailySales.length < 2 ? (
                        <div className="w-full h-full flex items-center justify-center text-text-muted">
                            Aguardando mais dados para gerar o gráfico...
                        </div>
                    ) : (
                        <svg viewBox={`0 0 ${w} ${h}`} className="w-full h-full overflow-visible">
                            <defs>
                                <linearGradient id="gradient" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="0%" stopColor="#6366f1" stopOpacity="0.3" />
                                    <stop offset="100%" stopColor="#6366f1" stopOpacity="0" />
                                </linearGradient>
                            </defs>
                            
                            {/* Grid Lines */}
                            {[0, 0.25, 0.5, 0.75, 1].map(p => (
                                <line key={p} x1="0" y1={h * p} x2={w} y2={h * p} stroke="rgba(128,128,128,0.1)" strokeWidth="1" />
                            ))}

                            <path d={areaPath} fill="url(#gradient)" />
                            <path d={linePath} fill="none" stroke="#6366f1" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                            
                            {dailySales.map((d, i) => (
                                <g key={i} className="group/dot cursor-pointer">
                                    <circle cx={getX(i)} cy={getY(d.total_liters)} r="4" fill="#6366f1" className="hover:r-6 transition-all" />
                                    {/* SVG Tooltip Replacement */}
                                    <foreignObject x={getX(i) - 40} y={getY(d.total_liters) - 50} width="80" height="40" className="pointer-events-none opacity-0 group-hover/dot:opacity-100 transition-opacity">
                                        <div className="bg-dashboard-element text-[10px] p-1.5 rounded border border-border-color text-center shadow-2xl">
                                            <p className="font-bold text-primary">{d.total_liters}L</p>
                                            <p className="text-emerald-400">R${d.total_revenue}</p>
                                        </div>
                                    </foreignObject>
                                </g>
                            ))}
                        </svg>
                    )}
                </div>
                {/* X labels */}
                <div className="flex justify-between mt-4 px-2">
                    {dailySales.map((d, i) => (
                        <span key={i} className="text-[10px] text-text-muted uppercase font-bold tracking-tighter">
                            {new Date(d.day).toLocaleDateString('pt-BR', { weekday: 'short' })}
                        </span>
                    ))}
                </div>
            </div>

            {/* Weekly Logs Section */}
            <div className="bg-dashboard-card p-6 rounded-2xl border border-border-color flex-1 overflow-hidden flex flex-col">
                <h3 className="text-xl font-bold mb-4 text-primary">
                    Histórico de Fechamentos
                </h3>
                <div className="overflow-y-auto pr-2 custom-scrollbar">
                    <table className="w-full text-left border-collapse">
                        <thead className="sticky top-0 bg-dashboard-card/90 backdrop-blur-sm z-10">
                            <tr className="text-text-muted border-b border-border-color text-[10px] uppercase tracking-[0.2em]">
                                <th className="p-4 font-bold">Período</th>
                                <th className="p-4 font-bold text-right">Rec. Diário</th>
                                <th className="p-4 font-bold text-right">Litros</th>
                                <th className="p-4 font-bold text-right">Total (R$)</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border-color">
                            {weeklyLogs.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="p-12 text-center text-text-muted italic">
                                        Nenhum fechamento registrado.
                                    </td>
                                </tr>
                            ) : (
                                weeklyLogs.map((log) => (
                                    <tr key={log.id} className="text-sm hover:bg-dashboard-element/50 transition-colors group">
                                        <td className="p-4 text-text-muted group-hover:text-primary transition-colors">
                                            {formatDate(log.start_date)} — {formatDate(log.end_date)}
                                        </td>
                                        <td className="p-4 text-right font-medium text-orange-400/80">
                                            {log.peak_liters?.toLocaleString() || 0} <span className="text-[10px] opacity-50">L</span>
                                        </td>
                                        <td className="p-4 text-right font-medium text-text-muted">
                                            {log.total_liters?.toLocaleString() || 0} <span className="text-[10px] opacity-50">L</span>
                                        </td>
                                        <td className="p-4 text-right font-bold text-emerald-500">
                                            R$ {log.total_revenue?.toLocaleString() || 0}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Closure Modal */}
            {showModal && (
                <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-[100] p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-3xl p-8 max-w-md w-full shadow-[0_32px_64px_-12px_rgba(0,0,0,0.8)]">
                        <div className="flex items-center gap-4 mb-6">
                            <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-500">
                                <span className="material-symbols-outlined text-3xl">event_available</span>
                            </div>
                            <div>
                                <h3 className="text-2xl font-bold text-white">Fechar Período</h3>
                                <p className="text-zinc-500 text-sm">Selecione o intervalo de reconciliação</p>
                            </div>
                        </div>

                        <div className="space-y-4 mb-8">
                            <div className="space-y-1.5">
                                <label className="text-zinc-400 text-xs font-bold uppercase tracking-widest pl-1">Data Início</label>
                                <input 
                                    type="date" 
                                    value={startDate}
                                    onChange={(e) => setStartDate(e.target.value)}
                                    className="w-full bg-black/40 border border-white/5 rounded-xl p-3 text-white focus:outline-none focus:border-indigo-500 transition-colors"
                                />
                            </div>
                            <div className="space-y-1.5">
                                <label className="text-zinc-400 text-xs font-bold uppercase tracking-widest pl-1">Data Fim</label>
                                <input 
                                    type="date" 
                                    value={endDate}
                                    onChange={(e) => setEndDate(e.target.value)}
                                    className="w-full bg-black/40 border border-white/5 rounded-xl p-3 text-white focus:outline-none focus:border-indigo-500 transition-colors"
                                />
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                            <button 
                                onClick={() => setShowModal(false)}
                                className="px-6 py-3 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl font-bold transition-all"
                            >
                                Cancelar
                            </button>
                            <button 
                                onClick={handleCloseWeek}
                                className="px-6 py-3 bg-indigo-500 hover:bg-indigo-600 text-white rounded-xl font-bold shadow-xl shadow-indigo-500/30 transition-all"
                            >
                                Confirmar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Analytics;
