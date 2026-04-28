import React, { useState, useEffect } from 'react';
import Sidebar from './Sidebar';
import DashboardHome from './DashboardHome';
import Finance from './Finance';
import FuelManagement from './FuelManagement';
import Settings from './Settings';
import Analytics from './Analytics';
import Upgrades from './Upgrades';
import ElectricManagement from './ElectricManagement';
import { fetchNui } from '../../utils/nui';

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

interface LoyaltyPlan {
    label: string;
    price: number;
    discount: number;
}

interface ManagementData {
    balance: number;
    fuelStock: number;
    maxStock: number;
    fuelPrice: number;
    ownerName: string;
    stationName: string;
    reservePrice?: number;
    isClosed?: boolean;
    logo?: string;
    stockLevel: number;
    upgrades: UpgradeTier[];
    loyaltyLevel: number;
    loyaltyUpgrades: LoyaltyTier[];
    electricManagement?: {
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
}

interface ManagementProps {
    data: ManagementData;
    onClose: () => void;
}

const Management: React.FC<ManagementProps> = ({ data, onClose }) => {
    const [activeTab, setActiveTab] = useState('dashboard');
    const [localData, setLocalData] = useState<ManagementData>(data);

    // Sync local state when parent data changes (real-time updates from server)
    useEffect(() => {
        setLocalData(prev => ({ ...prev, ...data }));
    }, [data]);

    const handleAction = (action: string, payload?: any) => {
        console.log(`Action: ${action}`, payload);

        if (action === 'changePrice' || action === 'buyStock') {
            setActiveTab('fuel');
            return;
        }

        if (action === 'rename') {
            setActiveTab('settings');
            return;
        }

        if (action.startsWith('manage:')) {
            fetchNui(action, payload);
            
            if (action === 'manage:close') {
                onClose();
            }
        }
    };

    return (
        <div className="fixed inset-0 flex items-center justify-center p-6 z-50 animate-in fade-in duration-300">
             <div className="w-full max-w-7xl h-[85vh] bg-dashboard-bg border border-border-color rounded-2xl flex overflow-hidden shadow-2xl relative">
                  
                  {/* Close Button */}
                  <button onClick={onClose} className="absolute top-4 right-4 z-50 text-text-muted hover:text-white transition-colors">
                      <span className="material-symbols-outlined">close</span>
                  </button>

                  <Sidebar activeTab={activeTab} onTabChange={setActiveTab} stationName={localData.stationName} logo={localData.logo} />
                  
                   <div className="flex-1 h-full bg-dashboard-bg relative">
                        {activeTab === 'dashboard' && <DashboardHome data={localData} />}
                        
                        {activeTab === 'analytics' && <Analytics />}
                        
                        {activeTab === 'finance' && (
                          <Finance balance={localData.balance} onAction={handleAction} />
                       )}
                      
                      {activeTab === 'fuel' && (
                          <FuelManagement 
                               stock={localData.fuelStock} 
                               maxStock={localData.maxStock} 
                               price={localData.fuelPrice} 
                               reservePrice={localData.reservePrice || 2.0}
                               onAction={handleAction} 
                          />
                      )}

                      {activeTab === 'electric' && localData.electricManagement && (
                          <ElectricManagement 
                               data={localData.electricManagement}
                               onAction={handleAction}
                          />
                      )}
                      
                      {activeTab === 'settings' && (
                          <Settings stationName={localData.stationName} logo={localData.logo} onAction={handleAction} />
                      )}

                      {activeTab === 'upgrades' && (
                          <Upgrades 
                                currentLevel={localData.stockLevel} 
                                upgrades={localData.upgrades}
                                loyaltyLevel={localData.loyaltyLevel}
                                loyaltyUpgrades={localData.loyaltyUpgrades}
                                electricLoyaltyLevel={localData.electricManagement?.loyaltyLevel || 0}
                                electricLoyaltyPlans={localData.electricManagement?.loyaltyPlans || {}}
                                pricePerKwh={localData.electricManagement?.pricePerKwh || 0}
                                onAction={handleAction} 
                          />
                      )}

                      {activeTab === 'employees' && (
                          <div className="h-full flex flex-col items-center justify-center text-text-muted">
                              <span className="material-symbols-outlined text-6xl mb-4 opacity-20">group_off</span>
                              <p>Gestão de funcionários em breve.</p>
                          </div>
                      )}
                 </div>
            </div>
        </div>
    );
};

export default Management;
