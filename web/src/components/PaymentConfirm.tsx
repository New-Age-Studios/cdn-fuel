import React from 'react';
import { useTheme } from '../context/ThemeContext';

interface PaymentConfirmProps {
  amount: number;
  price: number;
  isJerryCan?: boolean;
  isElectric?: boolean;
  isSyphon?: boolean;
  stationName?: string;
  logo?: string;
  onPay: (method: 'cash' | 'bank') => void;
  onBack: () => void;
}

const PaymentConfirm: React.FC<PaymentConfirmProps> = ({ price, isJerryCan, isElectric, isSyphon, stationName, logo, onPay, onBack }) => {
  const { theme, toggleTheme } = useTheme();

  return (
    <div className="flex w-full max-w-4xl bg-dashboard-bg border border-border-color rounded-xl overflow-hidden shadow-2xl animate-in fade-in zoom-in duration-300">
      
      {/* Sidebar / Decoration Left */}
      <div className="w-20 bg-dashboard-card border-r border-border-color flex flex-col items-center py-6 gap-6">
        <div className={`size-10 bg-dashboard-element rounded-lg flex items-center justify-center ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>
          <span className="material-symbols-outlined text-2xl">
              {isJerryCan ? 'propane_tank' : isElectric ? 'bolt' : isSyphon ? 'construction' : 'local_gas_station'}
          </span>
        </div>
        
        <div className="flex-1 w-full px-4 flex flex-col gap-4">
               {/* Spacer */}
        </div>
        
        <button onClick={toggleTheme} className="size-10 rounded-lg hover:bg-dashboard-element text-text-muted hover:text-primary flex items-center justify-center transition-colors" title="Mudar Tema">
             <span className="material-symbols-outlined">{theme === 'dark' ? 'light_mode' : 'dark_mode'}</span>
        </button>

        <button onClick={onBack} className="size-10 rounded-lg hover:bg-danger-red/20 text-text-muted hover:text-danger-red flex items-center justify-center transition-colors">
            <span className="material-symbols-outlined">power_settings_new</span>
        </button>
      </div>

      {/* Main Content */}
      <div className="flex-1 p-8">
        
        <div className="flex items-center justify-between mb-8">
            <div>
                <h1 className="text-2xl font-bold text-primary tracking-tight">
                    {isJerryCan ? 'Comprar Galão' : isElectric ? 'Estação de Carregamento' : isSyphon ? 'Kit de Sifão' : 'Método de Pagamento'}
                </h1>
                <div className="flex items-center gap-2 mt-1">
                    <span className={`px-2 py-0.5 rounded ${isElectric ? 'bg-electric-yellow/10 text-electric-yellow' : 'bg-neon-green/10 text-neon-green'} text-xs font-bold uppercase tracking-wider`}>Passo 1 / 2</span>
                    <p className="text-text-muted text-sm">{isSyphon ? 'O que deseja fazer com o combustível?' : isElectric ? 'Como deseja pagar pela energia?' : 'Como deseja pagar?'}</p>
                </div>
            </div>
            <div className="flex items-center gap-3 bg-dashboard-card px-4 py-2 rounded-lg border border-border-color">
                 <div className={`size-2 rounded-full ${isElectric ? 'bg-electric-yellow' : 'bg-neon-green'} animate-pulse`}></div>
                 <span className="text-sm font-medium text-primary">{isSyphon ? 'Modo Manual' : 'Sistema Online'}</span>
            </div>
        </div>

        <div className="grid grid-cols-2 gap-6">
            <button 
                onClick={() => onPay('cash')}
                className={`group relative h-40 bg-dashboard-card border border-border-color rounded-xl p-6 flex flex-col items-start justify-between ${isElectric ? 'hover:border-electric-yellow' : 'hover:border-neon-green'} transition-all duration-300 text-left`}
            >
                <div className={`absolute inset-0 bg-gradient-to-br ${isElectric ? 'from-electric-yellow/5' : 'from-neon-green/5'} to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300`}></div>
                <div className="relative z-10 size-12 rounded-lg bg-dashboard-element flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300">
                    <span className="material-symbols-outlined text-3xl text-primary">{isSyphon ? 'file_download' : 'payments'}</span>
                </div>
                <div className="relative z-10 w-full">
                    <h3 className="text-lg font-bold text-primary transition-colors">
                        {isSyphon ? 'Drenar Veículo' : 'Dinheiro'}
                    </h3>
                    <p className="text-text-muted text-xs mt-1">{isSyphon ? 'Retirar combustível do carro' : 'Pagamento com cédulas'}</p>
                </div>
                <div className={`absolute top-6 right-6 opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300`}>
                    <span className={`material-symbols-outlined ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>arrow_forward</span>
                </div>
            </button>

            <button 
                onClick={() => onPay('bank')}
                className={`group relative h-40 bg-dashboard-card border border-border-color rounded-xl p-6 flex flex-col items-start justify-between ${isElectric ? 'hover:border-electric-yellow' : 'hover:border-neon-green'} transition-all duration-300 text-left`}
            >
                <div className={`absolute inset-0 bg-gradient-to-br ${isElectric ? 'from-electric-yellow/5' : 'from-neon-green/5'} to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300`}></div>
                <div className="relative z-10 size-12 rounded-lg bg-dashboard-element flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300">
                     <span className="material-symbols-outlined text-3xl text-primary">{isSyphon ? 'file_upload' : 'credit_card'}</span>
                </div>
                <div className="relative z-10 w-full">
                    <h3 className="text-lg font-bold text-primary transition-colors">
                        {isSyphon ? 'Abastecer Veículo' : 'Débito Bancário'}
                    </h3>
                    <p className="text-text-muted text-xs mt-1">{isSyphon ? 'Colocar do kit no carro' : 'Descontado da conta'}</p>
                </div>
                <div className={`absolute top-6 right-6 opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300`}>
                    <span className={`material-symbols-outlined ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>arrow_forward</span>
                </div>
            </button>
        </div>

        <div className="mt-8 pt-6 border-t border-border-color flex items-center justify-between">
            <div className="flex items-center gap-4">
                 {!isSyphon && (
                     <>
                         {/* Logo in Footer */}
                         {logo && (
                             <div className="size-8 rounded-full overflow-hidden border border-border-color bg-black/20 mr-3 flex-shrink-0">
                                 <img src={logo} className="w-full h-full object-cover" alt="Station Logo" />
                             </div>
                         )}
                         <div className="flex flex-col">
                             <span className="text-[10px] text-text-muted font-bold uppercase tracking-widest">Posto</span>
                             <span className="text-primary font-mono text-xs truncate max-w-[150px]">{stationName || 'Posto Desconhecido'}</span>
                         </div>
                         <div className="w-px h-6 bg-border-color"></div>
                      </>
                 )}
                 <div className="flex flex-col">
                    <span className="text-[10px] text-text-muted font-bold uppercase tracking-widest">Preço</span>
                    <span className={`${isElectric ? 'text-electric-yellow' : 'text-neon-green'} font-mono text-xs`}>{isSyphon ? 'N/A' : `$${price}/${isElectric ? 'kWh' : 'L'}`}</span>
                 </div>
            </div>
            
            <button onClick={onBack} className="text-sm font-medium text-text-muted hover:text-primary transition-colors underline decoration-transparent hover:decoration-primary underline-offset-4">
                Cancelar Operação
            </button>
        </div>

      </div>
    </div>
  );
};

export default PaymentConfirm;
