import React from 'react';

interface UpgradeTier {
    level: number;
    label: string;
    capacity: number;
    price: number;
}

interface LoyaltyTier {
    level: number;
    label: string;
    fuelPrice: number;
    price: number;
    color?: string;
}

interface UpgradesProps {
    currentLevel: number;
    upgrades: UpgradeTier[];
    loyaltyLevel: number;
    loyaltyUpgrades: LoyaltyTier[];
    onAction: (action: string, data?: any) => void;
}

const Upgrades: React.FC<UpgradesProps> = ({ currentLevel, upgrades, loyaltyLevel, loyaltyUpgrades, onAction }) => {
    
    // Helper to generate variations from the base color
    const getColorsFromHex = (hex: string = '#3b82f6') => {
        return {
            main: hex,
            bg: `${hex}1A`, // 10% opacity
            border: `${hex}4D`, // 30% opacity
            glow: `${hex}33` // 20% opacity for shadow
        };
    };

    return (
        <div className="p-8 h-full flex flex-col gap-12 overflow-y-auto custom-scrollbar pb-16">
            {/* Section 1: Stock Expansion */}
            <div className="flex flex-col gap-6">
                <div>
                     <h2 className="text-3xl font-bold text-primary mb-2">Expansão de Estoque</h2>
                     <p className="text-text-muted">Aumente a capacidade máxima de armazenamento do seu posto</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 xl:grid-cols-4 gap-6">
                    {upgrades.map((upgrade) => {
                        const isUnlocked = upgrade.level <= currentLevel;
                        const isNext = upgrade.level === currentLevel + 1;
                        const isLocked = upgrade.level > currentLevel + 1;

                        return (
                            <div 
                                key={upgrade.level} 
                                className={`bg-dashboard-card border rounded-2xl p-6 flex flex-col transition-all duration-300 ${
                                    isUnlocked 
                                    ? 'border-neon-green/30 shadow-lg shadow-neon-green/5' 
                                    : isNext 
                                        ? 'border-border-color hover:border-neon-green/50 cursor-pointer' 
                                        : 'border-border-color opacity-60'
                                }`}
                            >
                                <div className="flex justify-between items-start mb-4">
                                    <div className={`p-3 rounded-xl ${isUnlocked ? 'bg-neon-green/10 text-neon-green' : 'bg-dashboard-element text-text-muted'}`}>
                                        <span className="material-symbols-outlined text-3xl">
                                            {upgrade.level === 0 ? 'oil_barrel' : upgrade.level === 3 ? 'factory' : 'storage'}
                                        </span>
                                    </div>
                                    {isUnlocked && (
                                        <span className="bg-neon-green/20 text-neon-green text-[10px] font-black px-2 py-1 rounded uppercase tracking-wider">Ativo</span>
                                    )}
                                </div>

                                <h3 className="text-lg font-bold text-primary mb-1">{upgrade.label}</h3>
                                <p className="text-sm text-text-muted mb-6">Capacidade: <span className="text-primary font-bold">{upgrade.capacity.toLocaleString()}L</span></p>

                                <div className="mt-auto">
                                    <div className="text-2xl font-black text-primary mb-4">
                                        {upgrade.price > 0 ? `$${upgrade.price.toLocaleString()}` : 'Grátis'}
                                    </div>

                                    <button 
                                        disabled={isUnlocked || isLocked}
                                        onClick={() => onAction('manage:buyUpgrade', { level: upgrade.level, price: upgrade.price })}
                                        className={`w-full py-3 rounded-xl font-bold transition-all duration-200 ${
                                            isUnlocked 
                                            ? 'bg-dashboard-element text-text-muted cursor-default' 
                                            : isNext
                                                ? 'bg-neon-green text-black hover:bg-neon-green-hover shadow-lg shadow-neon-green/20'
                                                : 'bg-dashboard-element text-text-muted/50 cursor-not-allowed'
                                        }`}
                                    >
                                        {isUnlocked ? 'Já Adquirido' : isLocked ? 'Bloqueado' : 'Comprar Upgrade'}
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>

            {/* Section 2: Loyalty Plans */}
            <div className="flex flex-col gap-6">
                <div>
                     <h2 className="text-3xl font-bold text-primary mb-2">Plano de Fidelidade</h2>
                     <p className="text-text-muted">Reduza o custo de compra do combustível para o seu estoque</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 xl:grid-cols-4 gap-6">
                    {loyaltyUpgrades.map((tier) => {
                        const isUnlocked = tier.level <= loyaltyLevel;
                        const isNext = tier.level === loyaltyLevel + 1;
                        const isLocked = tier.level > loyaltyLevel + 1;
                        const colors = getColorsFromHex(tier.color);

                        return (
                            <div 
                                key={tier.level} 
                                className={`bg-dashboard-card border rounded-2xl p-6 flex flex-col transition-all duration-300 ${
                                    isUnlocked 
                                    ? 'shadow-lg shadow-black/20' 
                                    : isNext 
                                        ? 'border-border-color hover:shadow-xl' 
                                        : 'border-border-color opacity-60'
                                }`}
                                style={{
                                    borderColor: isUnlocked || isNext ? colors.main : undefined,
                                    borderWidth: isUnlocked ? '2px' : '1px'
                                }}
                            >
                                <div className="flex justify-between items-start mb-4">
                                    <div 
                                        className={`p-3 rounded-xl transition-colors`}
                                        style={{ backgroundColor: isUnlocked ? colors.bg : 'rgba(255,255,255,0.05)', color: isUnlocked ? colors.main : '#666' }}
                                    >
                                        <span className="material-symbols-outlined text-3xl">
                                            {tier.level === 0 ? 'card_membership' : tier.level === 3 ? 'military_tech' : 'workspace_premium'}
                                        </span>
                                    </div>
                                    {isUnlocked && (
                                        <span 
                                            className="text-[10px] font-black px-2 py-1 rounded uppercase tracking-wider"
                                            style={{ backgroundColor: colors.bg, color: colors.main }}
                                        >
                                            Ativo
                                        </span>
                                    )}
                                </div>

                                <h3 className="text-lg font-bold text-primary mb-1">{tier.label}</h3>
                                <p className="text-sm text-text-muted mb-6">Preço/L: <span className="text-primary font-bold">R${tier.fuelPrice.toFixed(2)}</span></p>

                                <div className="mt-auto">
                                    <div className="text-2xl font-black text-primary mb-4">
                                        {tier.price > 0 ? `$${tier.price.toLocaleString()}` : 'Grátis'}
                                    </div>

                                    <button 
                                        disabled={isUnlocked || isLocked}
                                        onClick={() => onAction('manage:buyLoyaltyUpgrade', { level: tier.level, price: tier.price })}
                                        className={`w-full py-3 rounded-xl font-bold transition-all duration-200 shadow-lg`}
                                        style={{
                                            backgroundColor: isUnlocked ? 'rgba(255,255,255,0.05)' : isNext ? colors.main : 'rgba(255,255,255,0.02)',
                                            color: isNext ? '#000' : '#666',
                                            opacity: isLocked ? 0.3 : 1,
                                            cursor: isUnlocked ? 'default' : isLocked ? 'not-allowed' : 'pointer',
                                            boxShadow: isNext ? `0 10px 15px -3px ${colors.glow}` : 'none'
                                        }}
                                    >
                                        {isUnlocked ? 'Já Adquirido' : isLocked ? 'Bloqueado' : 'Contratar Plano'}
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>
        </div>
    );
};

export default Upgrades;
