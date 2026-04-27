import React, { useState, useEffect } from "react";
import { fetchNui } from "../../utils/nui";

interface ManagementData {
  balance: number;
  fuelStock: number;
  maxStock: number;
  fuelPrice: number;
  ownerName: string;
  isClosed?: boolean;
}

interface SalesLogItem {
  id: number;
  buyer_name: string;
  amount: number;
  cost: number;
  payment_type: string;
  date: string;
}

interface DashboardHomeProps {
  data: ManagementData;
}

const DashboardHome: React.FC<DashboardHomeProps> = ({ data }) => {
  const [salesLog, setSalesLog] = useState<SalesLogItem[]>([]);
  const [isClosed, setIsClosed] = useState(data.isClosed || false);

  // React to props change if data updates from outside
  useEffect(() => {
    setIsClosed(data.isClosed || false);
  }, [data.isClosed]);

  const handleToggleStatus = () => {
    const newState = !isClosed;
    setIsClosed(newState);
    fetchNui("manage:toggleStatus");
  };

  // Calculate fuel percentage
  const fuelPercent = Math.min(
    100,
    Math.round((data.fuelStock / data.maxStock) * 100),
  );

  useEffect(() => {
    fetchNui<SalesLogItem[]>("manage:getSales")
      .then((data) => {
        if (Array.isArray(data)) {
          setSalesLog(data);
        }
      })
      .catch((e) => {
        console.error("Failed to fetch sales log", e);
      });
  }, []);

  const formatTime = (dateString: string) => {
    try {
      return new Date(dateString).toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch (e) {
      return "--:--";
    }
  };

  return (
    <div className="flex-1 h-full p-8 flex flex-col overflow-hidden">
      {/* Header */}
      <div className="flex justify-between items-center mb-8">
        <div>
          <h2 className="text-2xl font-bold text-primary tracking-tight">
            Dashboard
          </h2>
          <div className="flex items-center gap-2 mt-1">
            <div
              className={`size-2 rounded-full animate-pulse ${isClosed ? "bg-red-500" : "bg-neon-green/80"}`}
            ></div>
            <span
              className={`text-xs font-bold tracking-wider uppercase ${isClosed ? "text-red-500" : "text-neon-green"}`}
            >
              {isClosed ? "FECHADO" : "OPERACIONAL"}
            </span>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="text-right hidden sm:block">
            <p className="text-primary font-bold text-sm">{data.ownerName}</p>
            <p className="text-text-muted text-xs">Proprietário</p>
          </div>
          <div className="size-10 rounded-full bg-dashboard-element flex items-center justify-center border border-border-color text-text-muted">
            <span className="material-symbols-outlined">person</span>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {/* Balance Card */}
        <div className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group hover:border-neon-green/30 transition-colors">
          <div className="flex justify-between items-start mb-4">
            <div className="p-2 rounded-lg bg-orange-500/10 text-orange-500">
              <span className="material-symbols-outlined">
                account_balance_wallet
              </span>
            </div>
            <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
              Saldo
            </span>
          </div>
          <h3 className="text-2xl font-bold text-primary tracking-tight">
            ${data.balance.toLocaleString()}
          </h3>
          <p className="text-xs text-neon-green mt-1 flex items-center gap-1 font-medium">
            <span className="material-symbols-outlined text-sm">
              trending_up
            </span>
            <span>Atualizado agora</span>
          </p>
        </div>

        {/* Stock Card */}
        <div className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group hover:border-neon-green/30 transition-colors">
          <div className="flex justify-between items-start mb-4">
            <div className="p-2 rounded-lg bg-red-500/10 text-red-500">
              <span className="material-symbols-outlined">water_drop</span>
            </div>
            <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
              Estoque
            </span>
          </div>
          <h3 className="text-2xl font-bold text-primary tracking-tight">
            {data.fuelStock} L
          </h3>
          <div className="w-full h-1.5 bg-dashboard-bg mt-3 rounded-full overflow-hidden">
            <div
              className="h-full bg-red-500 rounded-full"
              style={{ width: `${fuelPercent}%` }}
            ></div>
          </div>
          <p className="text-xs text-text-muted mt-2">
            Capacidade: {data.maxStock} L
          </p>
        </div>

        {/* Price Card */}
        <div className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group hover:border-neon-green/30 transition-colors">
          <div className="flex justify-between items-start mb-4">
            <div className="p-2 rounded-lg bg-blue-500/10 text-blue-500">
              <span className="material-symbols-outlined">sell</span>
            </div>
            <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
              Preço / Litro
            </span>
          </div>
          <h3 className="text-2xl font-bold text-primary tracking-tight">
            ${data.fuelPrice}
          </h3>
          <p className="text-xs text-text-muted mt-1 font-medium">
            Valor de venda atual
          </p>
        </div>

        {/* Status Card (Interactive) */}
        <button
          onClick={handleToggleStatus}
          className="bg-dashboard-card border border-border-color rounded-xl p-5 relative overflow-hidden group hover:border-primary/20 transition-all text-left w-full cursor-pointer"
        >
          <div className="flex justify-between items-start mb-4">
            <div
              className={`p-2 rounded-lg ${isClosed ? "bg-red-500/10 text-red-500" : "bg-neon-green/10 text-neon-green"}`}
            >
              <span className="material-symbols-outlined">
                {isClosed ? "lock" : "check_circle"}
              </span>
            </div>
            <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
              Status
            </span>
          </div>
          <h3 className="text-2xl font-bold text-primary tracking-tight">
            {isClosed ? "Fechado" : "Ativo"}
          </h3>
          <p className="text-xs text-text-muted mt-1 font-medium group-hover:text-primary transition-colors">
            {isClosed ? "Clique para ABRIR posto" : "Clique para FECHAR posto"}
          </p>
        </button>
      </div>

      {/* Sales Log */}
      <div className="bg-dashboard-card border border-border-color rounded-xl overflow-hidden flex flex-col flex-1 min-h-0">
        <div className="p-5 border-b border-border-color flex justify-between items-center">
          <div className="flex items-center gap-2">
            <span className="material-symbols-outlined text-neon-green">
              history
            </span>
            <h3 className="text-lg font-bold text-primary">
              Registro de Vendas
            </h3>
          </div>
          <button
            className="text-neon-green text-xs font-bold uppercase hover:underline"
            onClick={() =>
              fetchNui<SalesLogItem[]>("manage:getSales").then(setSalesLog)
            }
          >
            Atualizar
          </button>
        </div>
        <div className="flex-1 p-0 overflow-y-auto custom-scrollbar">
          <table className="w-full text-left">
            <thead className="bg-dashboard-element text-xs text-text-muted uppercase font-bold tracking-wider sticky top-0 backdrop-blur-md">
              <tr>
                <th className="p-4">Cliente</th>
                <th className="p-4">Horário</th>
                <th className="p-4">Litros</th>
                <th className="p-4">Valor Total</th>
                <th className="p-4">Pagamento</th>
              </tr>
            </thead>
            <tbody className="text-sm text-primary divide-y divide-border-color">
              {salesLog.length > 0 ? (
                salesLog.map((item) => (
                  <tr
                    key={item.id}
                    className="hover:bg-dashboard-element/50 transition-colors"
                  >
                    <td className="p-4 font-bold text-primary">
                      {item.buyer_name || "Desconhecido"}
                    </td>
                    <td className="p-4 text-text-muted">
                      {formatTime(item.date)}
                    </td>
                    <td className="p-4 font-medium">
                      {item.amount ? item.amount.toFixed(1) : "N/A"} L
                    </td>
                    <td className="p-4 font-bold text-neon-green">
                      ${item.cost.toLocaleString()}
                    </td>
                    <td className="p-4">
                      <span
                        className={`px-2 py-1 rounded text-[10px] font-bold uppercase ${
                          item.payment_type === "cash"
                            ? "bg-orange-500/20 text-orange-500"
                            : "bg-white/10 text-white"
                        }`}
                      >
                        {item.payment_type === "cash" ? "Dinheiro" : "Débito"}
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-text-muted">
                    Nenhuma venda registrada recentemente.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default DashboardHome;
