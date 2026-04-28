import React, { useState } from "react";
import { useTheme } from "../../context/ThemeContext";

interface SidebarProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  stationName: string;
  logo?: string;
}

const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  onTabChange,
  stationName,
  logo,
}) => {
  const { theme, toggleTheme } = useTheme();
  const [imgError, setImgError] = useState(false);

  // Reset error state if logo changes
  React.useEffect(() => {
    setImgError(false);
  }, [logo]);

  const menuItems = [
    { id: "dashboard", label: "Dashboard", icon: "dashboard" },
    { id: "analytics", label: "Estatísticas", icon: "bar_chart" },
    { id: "finance", label: "Financeiro", icon: "account_balance_wallet" },
    { id: "fuel", label: "Combustível", icon: "local_gas_station" },
    { id: "electric", label: "Energia Elétrica", icon: "bolt" },
    { id: "upgrades", label: "Upgrades", icon: "upgrade" },
    { id: "settings", label: "Configurações", icon: "settings" },
  ];

  return (
    <div className="w-64 h-[85vh] bg-dashboard-card border-r border-border-color flex flex-col rounded-l-2xl">
      <div className="p-6 flex items-center gap-3">
        <div className="size-10 bg-gradient-to-br from-neon-green to-neon-green-hover rounded-lg flex items-center justify-center shadow-lg shadow-neon-green/20 shrink-0">
          <span className="material-symbols-outlined text-black font-bold text-xl">
            local_gas_station
          </span>
        </div>
        <div className="min-w-0">
          <h1
            className="text-primary font-bold text-lg leading-tight truncate max-w-[140px] uppercase tracking-tighter"
            title={stationName}
          >
            {stationName}
          </h1>
          <p className="text-text-muted text-xs font-medium">Gerenciamento</p>
        </div>
      </div>

      {logo && (
        <div className="px-6 mb-6 flex justify-center">
          <div className="size-24 relative rounded-full overflow-hidden shadow-lg border-2 border-neon-green/30 bg-black/20 group flex items-center justify-center">
            {!imgError ? (
              <img
                src={logo}
                alt="Station Logo"
                className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                onError={() => setImgError(true)}
                referrerPolicy="no-referrer"
              />
            ) : (
              <span className="material-symbols-outlined text-4xl text-text-muted/50">
                storefront
              </span>
            )}
          </div>
        </div>
      )}

      <div className="flex-1 px-4 py-2 flex flex-col gap-2 overflow-y-auto">
        {menuItems.map((item) => (
          <button
            key={item.id}
            onClick={() => onTabChange(item.id)}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 group ${
              activeTab === item.id
                ? "bg-neon-green text-black font-bold shadow-lg shadow-neon-green/20"
                : "text-text-muted hover:bg-dashboard-element hover:text-primary"
            }`}
          >
            <span
              className={`material-symbols-outlined ${activeTab === item.id ? "text-black" : "text-text-muted group-hover:text-primary"}`}
            >
              {item.icon}
            </span>
            <span className="text-sm tracking-wide">{item.label}</span>
          </button>
        ))}
      </div>

      <div className="p-4 border-t border-border-color">
        <button
          onClick={toggleTheme}
          className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-dashboard-element hover:bg-dashboard-element/80 text-text-muted hover:text-primary transition-all duration-200"
        >
          <span className="material-symbols-outlined">
            {theme === "dark" ? "light_mode" : "dark_mode"}
          </span>
          <span className="text-sm font-medium">
            {theme === "dark" ? "Modo Claro" : "Modo Escuro"}
          </span>
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
