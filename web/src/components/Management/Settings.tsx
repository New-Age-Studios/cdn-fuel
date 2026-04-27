import React, { useState } from 'react';

interface SettingsProps {
    stationName: string;
    logo?: string;
    onAction: (action: string, data?: any) => void;
}

const Settings: React.FC<SettingsProps> = ({ stationName, logo, onAction }) => {
    const [newName, setNewName] = useState(stationName);
    const [logoUrl, setLogoUrl] = useState(logo || '');
    const [confirmSell, setConfirmSell] = useState(false);

    const handleRename = () => {
        if (!newName || newName.length < 3) return;
        onAction('manage:renameStation', { name: newName });
    };

    const handleUpdateLogo = () => {
        let finalUrl = logoUrl.trim();
        
        // Auto-fix Imgur links (convert gallery link to direct image)
        if (finalUrl.includes('imgur.com') && !finalUrl.includes('i.imgur.com')) {
             const parts = finalUrl.split('/');
             const id = parts[parts.length - 1];
             if (id && !id.includes('.')) {
                 finalUrl = `https://i.imgur.com/${id}.png`;
             }
        }

        onAction('manage:updateLogo', { url: finalUrl });
    };

    const handleSell = () => {
        if (confirmSell) {
            onAction('manage:sellStation');
        } else {
            setConfirmSell(true);
        }
    };

    return (
        <div className="p-8 h-full flex flex-col gap-8 overflow-y-auto custom-scrollbar">
             <div>
                 <h2 className="text-3xl font-bold text-primary mb-2">Configurações</h2>
                 <p className="text-text-muted">Gerenciamento geral da propriedade</p>
            </div>

            <div className="space-y-6 max-w-2xl">
                {/* Rename Section */}
                <div className="bg-dashboard-card border border-border-color rounded-2xl p-6">
                     <h3 className="text-lg font-bold text-primary mb-4">Renomear Posto</h3>
                     <div className="flex gap-4">
                         <input 
                            type="text" 
                            className="flex-1 bg-dashboard-element border border-border-color rounded-xl px-4 py-3 text-primary focus:outline-none focus:border-neon-green transition-colors"
                            value={newName}
                            onChange={(e) => setNewName(e.target.value)}
                            minLength={3}
                            maxLength={30}
                            placeholder="Novo nome do posto"
                         />
                         <button 
                            onClick={handleRename}
                            className="bg-dashboard-element hover:bg-dashboard-element/80 text-primary font-bold px-6 py-3 rounded-xl transition-colors"
                         >
                             Salvar
                         </button>
                     </div>
                     <p className="text-xs text-text-muted mt-2">O nome deve ter entre 3 e 30 caracteres.</p>
                </div>

                {/* Logo Section */}
                <div className="bg-dashboard-card border border-border-color rounded-2xl p-6">
                     <h3 className="text-lg font-bold text-primary mb-4">Logo do Posto</h3>
                     <div className="flex gap-4">
                         <input 
                            type="text" 
                            className="flex-1 bg-dashboard-element border border-border-color rounded-xl px-4 py-3 text-primary focus:outline-none focus:border-neon-green transition-colors"
                            value={logoUrl}
                            onChange={(e) => setLogoUrl(e.target.value)}
                            placeholder="URL da Imagem (Ex: https://imgur.com/...)"
                         />
                         <button 
                            onClick={handleUpdateLogo}
                            className="bg-dashboard-element hover:bg-dashboard-element/80 text-primary font-bold px-6 py-3 rounded-xl transition-colors"
                         >
                             Atualizar
                         </button>
                     </div>
                     <p className="text-xs text-text-muted mt-2">
                         Use um link direto de imagem (deve terminar em .png). Recomendado: Hospedar sua imagem no{' '}
                         <button 
                            onClick={() => (window as any).invokeNative ? (window as any).invokeNative('openUrl', 'https://fivemerr.com/') : window.open('https://fivemerr.com/', '_blank')}
                            className="text-neon-green hover:underline font-bold bg-transparent border-none p-0 cursor-pointer"
                         >
                             fivemerr.com
                         </button>
                         {' '}e copiar o link e colar aqui.
                     </p>
                </div>

                {/* Sell Section */}
                <div className="bg-red-500/5 border border-red-500/20 rounded-2xl p-6">
                     <h3 className="text-lg font-bold text-red-500 mb-2">Zona de Perigo</h3>
                     <p className="text-red-400/80 text-sm mb-6">
                         Vender o posto é uma ação irreversível. Todo o estoque e saldo serão liquidados de acordo com a taxa de mercado.
                     </p>
                     
                     <div className="flex items-center gap-4">
                         {confirmSell ? (
                             <div className="flex items-center gap-4 w-full animate-in fade-in slide-in-from-left-2">
                                  <button 
                                      onClick={handleSell}
                                      className="bg-red-500 hover:bg-red-600 text-white font-bold px-6 py-3 rounded-xl transition-colors shadow-lg shadow-red-500/20 flex-1"
                                  >
                                      CONFIRMAR VENDA
                                  </button>
                                  <button 
                                      onClick={() => setConfirmSell(false)}
                                      className="bg-dashboard-element hover:bg-dashboard-element/80 text-primary font-bold px-6 py-3 rounded-xl transition-colors"
                                  >
                                      Cancelar
                                  </button>
                             </div>
                         ) : (
                             <button 
                                onClick={handleSell}
                                className="bg-red-500/10 hover:bg-red-500 hover:text-white text-red-500 border border-red-500/50 font-bold px-6 py-3 rounded-xl transition-all"
                             >
                                 Vender Propriedade
                             </button>
                         )}
                     </div>
                </div>
            </div>
        </div>
    );
};

export default Settings;
