import React, { useState, useEffect } from "react";
import { ThemeProvider } from "./context/ThemeContext";
import FuelSelector from "./components/FuelSelector";
import PaymentConfirm from "./components/PaymentConfirm";
import TransactionSummary from "./components/TransactionSummary";
import Management from "./components/Management/Management";
import FuelMappingAdmin from "./components/Management/FuelMappingAdmin";
import InteractionMenu from "./components/InteractionMenu";
import StationPurchase from "./components/StationPurchase";
import FuelTypeSelector from "./components/FuelTypeSelector";
import { fetchNui, debugData } from "./utils/nui";

// Mock data for development
debugData([
  {
    action: "open",
    data: {
      maxFuel: 60,
      currentFuel: 10,
      price: 3.5,
      type: "fuel",
      tax: 15,
    },
  },
  {
    action: "openManagement",
    data: {
      stationName: "Snow Posto",
      balance: 57500,
      fuelStock: 0,
      dieselStock: 0,
      ethanolStock: 0,
      maxStock: 0,
      fuelPrice: 0,
      dieselPrice: 0,
      ethanolPrice: 0,
      ownerName: "John Doe",
      stockLevel: 1,
      upgrades: [
        { level: 0, label: "Padrão", capacity: 10000, price: 0 },
        { level: 1, label: "Level 1", capacity: 20000, price: 5000 },
      ],
      loyaltyLevel: 0,
      loyaltyUpgrades: [
        { level: 0, label: "Bronze", fuelPrice: 3, price: 0, color: "#CD7F32" },
        { level: 1, label: "Prata", fuelPrice: 2, price: 10000, color: "#C0C0C0" },
      ],
    },
  },
  {
    action: "openInteraction",
    data: {
      stationName: "Snow Posto",
      isOwner: true,
      canPurchase: false,
      pumpState: "enabled",
      shutoffDisabled: false,
    },
  },
  {
    action: "openPurchase",
    data: {
      stationName: "Snow Posto",
      price: 150000,
    },
  },
]);

interface SyphonData {
  kitFuel: number;
  kitCap: number;
  itemData: any;
}

interface JerryCanData {
  fuel: number;
  cap: number;
  itemData: any;
}

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

interface ManagementData {
  balance: number;
  fuelStock: number;
  dieselStock: number;
  ethanolStock: number;
  maxStock: number;
  fuelPrice: number;
  dieselPrice: number;
  ethanolPrice: number;
  ownerName: string;
  stationName: string;
  logo?: string;
  stockLevel: number;
  upgrades: UpgradeTier[];
  loyaltyLevel: number;
  loyaltyUpgrades: LoyaltyTier[];
  stationType: string;
}

interface MappingData {
  mappings: any[];
  classes: string[];
}

const App: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [step, setStep] = useState<
    "fuelType" | "selector" | "payment" | "summary" | "management" | "mappingAdmin"
  >("payment");

  const [availableFuels, setAvailableFuels] = useState<any[]>([]);
  const [selectedFuel, setSelectedFuel] = useState<any>(null);

  const [fuelData, setFuelData] = useState({
    maxFuel: 60,
    currentFuel: 10,
    price: 3.5,
    tax: 0,
    discount: 0,
    type: "fuel", // 'fuel' | 'jerrycan' | 'electric' | 'syphon' | 'jerrycanRefuel' | 'jerrycanRefill'
    syphonData: undefined as SyphonData | undefined,
    jerryCanData: undefined as JerryCanData | undefined,
    jerryCans: [] as JerryCanData[], // List of cans for refill mode
    stationName: "",
    logo: undefined as string | undefined,
  });

  const [managementData, setManagementData] = useState<ManagementData | null>(
    null,
  );
  const [mappingData, setMappingData] = useState<MappingData>({ mappings: [], classes: [] });

  const [selectedAmount, setSelectedAmount] = useState(0);
  const [selectedMethod, setSelectedMethod] = useState<"cash" | "bank" | null>(
    null,
  );
  const [syphonMode, setSyphonMode] = useState<"in" | "out">("out"); // 'out' = siphon from car, 'in' = refuel car
  const [selectedJerryCanIndex, setSelectedJerryCanIndex] = useState(0);

  const [showInteraction, setShowInteraction] = useState(false);
  const [interactionData, setInteractionData] = useState<any>(null); // Type properly if possible

  const [showPurchase, setShowPurchase] = useState(false);
  const [purchaseData, setPurchaseData] = useState<any>(null);

  const closeTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const { action, data } = event.data;

      if (action === "open") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        const fuels = data.availableFuels || [
          { id: 'gasoline', label: 'Gasolina', price: data.price || 3, icon: 'local_gas_station', color: '#FFA500', description: 'Combustível padrão para a maioria dos veículos de passeio.' },
          { id: 'diesel', label: 'Diesel', price: data.dieselPrice || 4, icon: 'rv_hookup', color: '#555555', description: 'Ideal para SUVs, caminhões e veículos de carga pesada.' },
          { id: 'ethanol', label: 'Etanol', price: data.ethanolPrice || 2, icon: 'eco', color: '#008000', description: 'Combustível renovável de alto desempenho para carros esportivos.' }
        ];

        setAvailableFuels(fuels);
        setFuelData({
          ...data,
          type: data.type || "fuel",
          tax: data.tax || 0,
          discount: data.discount || 0,
          stationName: data.stationName, // Let component handle fallback
          logo: data.logo,
          jerryCans: data.jerryCans || [],
        });

        if (data.type === "fuel" || data.type === "jerrycanRefill" || data.type === "jerrycan") {
          setStep("fuelType");
          setSelectedMethod(null);
        } else if (data.type === "jerrycanRefuel") {
          setStep("selector");
          setSelectedMethod(null);
        } else {
          setStep("payment");
          setSelectedMethod(null);
        }

        setSelectedAmount(0);
        setSelectedFuel(null);
        setSelectedJerryCanIndex(0);
        setVisible(true);
      } else if (action === "openManagement") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        setManagementData({
          ...data,
          fuelStock: data.fuelStock,
          dieselStock: data.dieselStock || 0,
          ethanolStock: data.ethanolStock || 0,
          maxStock: data.maxStock,
          fuelPrice: data.fuelPrice,
          dieselPrice: data.dieselPrice || 0,
          ethanolPrice: data.ethanolPrice || 0,
          ownerName: data.ownerName,
        });
        setStep("management");
        setShowInteraction(false);
        setVisible(true);
      } else if (action === "openMappingAdmin") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        setMappingData({
          mappings: data.mappings || [],
          classes: data.classes || []
        });
        setStep("mappingAdmin");
        setShowInteraction(false);
        setVisible(true);
      } else if (action === "updateData") {
        setManagementData((prev: any) => {
          if (!prev) return prev;
          
          const newData = { ...prev };
          for (const key in data) {
            if (typeof data[key] === 'object' && data[key] !== null && !Array.isArray(data[key]) && prev[key]) {
              newData[key] = { ...prev[key], ...data[key] };
            } else {
              newData[key] = data[key];
            }
          }
          return newData;
        });
      } else if (action === "openInteraction") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        setInteractionData(data);
        setManagementData(null); // Clear management data to prevent precedence
        setStep("payment"); // Reset step to neutral
        setShowInteraction(true);
        setVisible(true);
      } else if (action === "openPurchase") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        setPurchaseData(data);
        // Clear others
        setManagementData(null);
        setInteractionData(null);
        setShowInteraction(false);
        setStep("payment");

        setShowPurchase(true);
        setVisible(true);
      } else if (action === "close") {
        handleClose();
      } else if (action === "setColors") {
        const { primary, hover } = data;
        const root = document.documentElement;
        // Tailwind uses space separated RGB values for these specific vars in index.css
        if (primary)
          root.style.setProperty(
            "--color-neon-green",
            `${primary.r} ${primary.g} ${primary.b}`,
          );
        if (hover)
          root.style.setProperty(
            "--color-neon-hover",
            `${hover.r} ${hover.g} ${hover.b}`,
          );
      }
    };

    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, []);

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (visible && e.key === "Escape") {
        handleClose();
      }
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [visible]);

  const handleClose = () => {
    fetchNui("close");
    setVisible(false);
    if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
    closeTimeoutRef.current = setTimeout(() => {
      setStep("payment");
      setManagementData(null);
      setInteractionData(null);
      setShowInteraction(false);
      setPurchaseData(null);
      setShowPurchase(false);
      closeTimeoutRef.current = null;
    }, 200);
  };

  const handleFuelTypeSelect = (fuel: any) => {
    setSelectedFuel(fuel);
    setFuelData(prev => ({ ...prev, price: fuel.price }));
    setStep("payment");
  };

  const handlePaymentSelect = (method: "cash" | "bank") => {
    setSelectedMethod(method);

    if (fuelData.type === "syphon") {
      // cash (left) -> Syphon (Steal) -> 'out'
      // bank (right) -> Refuel (Give) -> 'in'
      setSyphonMode(method === "cash" ? "out" : "in");
    }

    setStep("selector");
  };

  const handleSaveMapping = (mapping: any) => {
    fetchNui("saveMapping", mapping).then((updatedMappings: any) => {
      setMappingData(prev => ({ ...prev, mappings: updatedMappings }));
    });
  };

  const handleDeleteMapping = (name: string) => {
    fetchNui("deleteMapping", { name }).then((updatedMappings: any) => {
      setMappingData(prev => ({ ...prev, mappings: updatedMappings }));
    });
  };

  const handleFuelSelect = (amount: number) => {
    if (amount <= 0) return;
    setSelectedAmount(amount);
    setStep("summary");
  };

  const handleFinalConfirm = () => {
    fetchNui("pay", {
      amount: selectedAmount,
      method: selectedMethod,
      fuelType: selectedFuel?.id || "gasoline",
      price: fuelData.price,
      type: fuelData.type,
      syphonData: fuelData.type === "syphon" ? fuelData.syphonData : undefined,
      jerryCanData: fuelData.type === "jerrycanRefill" 
        ? fuelData.jerryCans[selectedJerryCanIndex]?.itemData 
        : fuelData.jerryCanData,
      // For Lua 'reason': 'syphon' (steal) or 'refuel' (give)
      reason:
        fuelData.type === "syphon"
          ? syphonMode === "out"
            ? "syphon"
            : "refuel"
          : undefined,
    });
    setVisible(false);
  };

  const handleBackToSelector = () => {
    setStep("selector");
  };

  const handleBackToPayment = () => {
    setStep("payment");
  };

  // Calculate Max for Selector based on mode
  const getMaxFuelForSelector = () => {
    if (fuelData.type === "jerrycan") return 10; // Buying jerry cans

    if (fuelData.type === "syphon" && fuelData.syphonData) {
      if (syphonMode === "out") {
        // Draining from Car: Limit is Car Fuel OR Kit Space (Cap - Current)
        const spaceInKit =
          fuelData.syphonData.kitCap - fuelData.syphonData.kitFuel;
        return Math.floor(Math.min(fuelData.currentFuel, spaceInKit));
      } else {
        // Refueling Car: Limit is Kit Fuel OR Car Space (100 - Current)
        const spaceInCar = 100 - fuelData.currentFuel;
        return Math.floor(Math.min(fuelData.syphonData.kitFuel, spaceInCar));
      }
    }

    if (fuelData.type === "jerrycanRefuel" && fuelData.jerryCanData) {
      // Refueling Car with Jerry Can
      // Limit is Jerry Can Content OR Car Space
      const spaceInCar = 100 - fuelData.currentFuel;
      return Math.floor(Math.min(fuelData.jerryCanData.fuel, spaceInCar));
    }

    if (fuelData.type === "jerrycanRefill" && fuelData.jerryCans.length > 0) {
      // Refueling a Jerry Can at the pump
      const currentCan = fuelData.jerryCans[selectedJerryCanIndex];
      return Math.floor(currentCan.cap - currentCan.fuel);
    }

    return fuelData.maxFuel;
  };

  if (!visible) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center p-6 font-sans select-none text-primary">
      <div className="relative z-10 w-full flex justify-center">
        {step === "management" && managementData ? (
          <Management data={managementData} onClose={handleClose} />
        ) : step === "mappingAdmin" ? (
          <FuelMappingAdmin 
              mappings={mappingData.mappings}
              classes={mappingData.classes}
              onSave={handleSaveMapping}
              onDelete={handleDeleteMapping}
              onClose={handleClose}
          />
        ) : showInteraction && interactionData ? (
          <InteractionMenu
            stationName={interactionData.stationName}
            isOwner={interactionData.isOwner}
            canPurchase={interactionData.canPurchase}
            pumpState={interactionData.pumpState}
            shutoffDisabled={interactionData.shutoffDisabled}
            onClose={handleClose}
          />
        ) : showPurchase && purchaseData ? (
          <StationPurchase
            stationName={purchaseData.stationName}
            price={purchaseData.price}
            tax={purchaseData.tax}
            onClose={handleClose}
          />
        ) : (
          <>
            {step === "fuelType" && (
                <FuelTypeSelector 
                    availableFuels={availableFuels}
                    stationName={fuelData.stationName}
                    onSelect={handleFuelTypeSelect}
                    onClose={handleClose}
                />
            )}
            {step === "payment" && (
              <PaymentConfirm
                amount={0}
                price={fuelData.price}
                isJerryCan={fuelData.type === "jerrycan"}
                isElectric={fuelData.type === "electric"}
                isSyphon={fuelData.type === "syphon"}
                stationName={fuelData.stationName}
                logo={fuelData.logo}
                onPay={handlePaymentSelect}
                onBack={fuelData.type === "fuel" || fuelData.type === "jerrycanRefill" ? () => setStep("fuelType") : handleClose}
              />
            )}
            {step === "selector" && (
              <FuelSelector
                maxFuel={getMaxFuelForSelector()}
                currentFuel={
                  fuelData.type === "jerrycanRefill" && fuelData.jerryCans.length > 0
                    ? fuelData.jerryCans[selectedJerryCanIndex].fuel
                    : fuelData.currentFuel
                }
                price={fuelData.price}
                isJerryCan={fuelData.type === "jerrycan"}
                isElectric={fuelData.type === "electric"}
                isSyphon={fuelData.type === "syphon"}
                isJerryCanRefuel={fuelData.type === "jerrycanRefuel"}
                isJerryCanRefill={fuelData.type === "jerrycanRefill"}
                jerryCans={fuelData.jerryCans}
                selectedJerryCanIndex={selectedJerryCanIndex}
                onJerryCanSelect={setSelectedJerryCanIndex}
                syphonMode={syphonMode}
                onConfirm={handleFuelSelect}
                onClose={
                  fuelData.type === "jerrycanRefuel" || fuelData.type === "jerrycanRefill"
                    ? (fuelData.type === "jerrycanRefill" ? () => setStep("payment") : handleClose)
                    : handleBackToPayment
                }
              />
            )}
            {step === "summary" && (
              <TransactionSummary
                amount={selectedAmount}
                price={fuelData.price}
                tax={fuelData.tax}
                discount={fuelData.discount}
                method={selectedMethod}
                isJerryCan={fuelData.type === "jerrycan"}
                isElectric={fuelData.type === "electric"}
                isSyphon={fuelData.type === "syphon"}
                isJerryCanRefuel={fuelData.type === "jerrycanRefuel"}
                onConfirm={handleFinalConfirm}
                onCancel={
                  fuelData.type === "jerrycan"
                    ? handleBackToPayment
                    : handleBackToSelector
                }
              />
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default () => (
  <ThemeProvider>
    <App />
  </ThemeProvider>
);
