import React from "react";
import { fetchNui } from "../utils/nui";
import { useTheme } from "../context/ThemeContext";

interface InteractionMenuProps {
  stationName: string;
  isOwner: boolean;
  canPurchase: boolean;
  pumpState: string; // "enabled" | "disabled" | "nil"
  shutoffDisabled: boolean;
  onClose: () => void;
}

const InteractionMenu: React.FC<InteractionMenuProps> = ({
  stationName,
  isOwner,
  canPurchase,
  pumpState,
  shutoffDisabled,
  onClose,
}) => {
  const { theme, toggleTheme } = useTheme();

  const handleAction = (action: string) => {
    fetchNui(`interaction:${action}`);
    if (action === "shutoff") {
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 animate-in fade-in duration-300">
      <div className="w-full max-w-lg bg-dashboard-bg border border-border-color rounded-2xl p-6 shadow-2xl relative overflow-hidden">
        {/* Theme Toggle */}
        <button
          onClick={toggleTheme}
          className="absolute top-4 left-4 text-text-muted hover:text-primary transition-colors"
          title="Mudar Tema"
        >
          <span className="material-symbols-outlined">
            {theme === "dark" ? "light_mode" : "dark_mode"}
          </span>
        </button>

        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-text-muted hover:text-primary transition-colors"
        >
          <span className="material-symbols-outlined">close</span>
        </button>

        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center p-3 rounded-xl bg-neon-green/10 text-neon-green mb-4">
            <span className="material-symbols-outlined text-3xl">
              local_gas_station
            </span>
          </div>
          <h2 className="text-2xl font-bold text-primary tracking-tight">
            {stationName}
          </h2>
          <p className="text-text-muted text-sm mt-1">
            Selecione uma opção abaixo
          </p>
        </div>

        {/* Grid */}
        <div className="grid grid-cols-1 gap-4">
          {/* Enable specific button based on state */}

          {/* Management Button */}
          <button
            onClick={() => handleAction("manage")}
            disabled={!isOwner}
            className={`group relative p-4 rounded-xl border transition-all duration-300 flex items-center gap-4 text-left
                            ${
                              isOwner
                                ? "bg-dashboard-card border-border-color hover:border-neon-green hover:shadow-[0_0_15px_-5px_rgba(34,197,94,0.3)]"
                                : "bg-dashboard-card/50 border-border-color/50 opacity-50 cursor-not-allowed hidden" // Hide if not owner to keep clean? Or show disabled?
                            }
                        `}
          >
            {/* Only showing if owner or just disabled? The original menu shows disabled options. Let's keep it but simplified. actually conditional rendering is cleaner */}
            {isOwner && (
              <>
                <div className="p-3 rounded-lg bg-blue-500/10 text-blue-500 group-hover:bg-blue-500/20 transition-colors">
                  <span className="material-symbols-outlined">dashboard</span>
                </div>
                <div className="flex-1">
                  <h3 className="font-bold text-primary group-hover:text-blue-400 transition-colors">
                    Gerenciar Posto
                  </h3>
                  <p className="text-xs text-text-muted">
                    Acesse o painel administrativo
                  </p>
                </div>
                <span className="material-symbols-outlined text-text-muted group-hover:translate-x-1 transition-transform">
                  chevron_right
                </span>
              </>
            )}
          </button>

          {/* Purchase Button */}
          {!isOwner && canPurchase && (
            <button
              onClick={() => handleAction("purchase")}
              className="group relative p-4 rounded-xl border border-border-color bg-dashboard-card hover:border-neon-green hover:shadow-[0_0_15px_-5px_rgba(34,197,94,0.3)] transition-all duration-300 flex items-center gap-4 text-left"
            >
              <div className="p-3 rounded-lg bg-neon-green/10 text-neon-green group-hover:bg-neon-green/20 transition-colors">
                <span className="material-symbols-outlined">
                  currency_exchange
                </span>
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-primary group-hover:text-neon-green transition-colors">
                  Comprar Propriedade
                </h3>
                <p className="text-xs text-text-muted">
                  Adquira este posto de combustível
                </p>
              </div>
              <span className="material-symbols-outlined text-text-muted group-hover:translate-x-1 transition-transform">
                chevron_right
              </span>
            </button>
          )}

          {/* Emergency Shutoff */}
          {!shutoffDisabled && (
            <button
              onClick={() => handleAction("shutoff")}
              className="group relative p-4 rounded-xl border border-border-color bg-dashboard-card hover:border-danger-red hover:shadow-[0_0_15px_-5px_rgba(239,68,68,0.3)] transition-all duration-300 flex items-center gap-4 text-left"
            >
              <div
                className={`p-3 rounded-lg transition-colors ${pumpState === "enabled" ? "bg-danger-red/10 text-danger-red" : "bg-neon-green/10 text-neon-green"}`}
              >
                <span className="material-symbols-outlined">
                  power_settings_new
                </span>
              </div>
              <div className="flex-1">
                <h3
                  className={`font-bold transition-colors ${pumpState === "enabled" ? "text-primary group-hover:text-danger-red" : "text-primary group-hover:text-neon-green"}`}
                >
                  {pumpState === "enabled"
                    ? "Desligamento de Emergência"
                    : "Religar Bombas"}
                </h3>
                <p className="text-xs text-text-muted">
                  {pumpState === "enabled"
                    ? "Cortar o fornecimento de combustível"
                    : "Restabelecer fornecimento"}
                </p>
              </div>
              {/* Status Indicator */}
              <div className="flex flex-col items-end">
                <span
                  className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded ${pumpState === "enabled" ? "bg-neon-green/10 text-neon-green" : "bg-red-500/10 text-red-500"}`}
                >
                  {pumpState === "enabled" ? "ATIVO" : "DESLIGADO"}
                </span>
              </div>
            </button>
          )}
        </div>

        {/* Footer */}
        <div className="mt-6 text-center">
          <button
            onClick={onClose}
            className="text-xs font-bold text-text-muted hover:text-primary uppercase tracking-wider transition-colors"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  );
};

export default InteractionMenu;
