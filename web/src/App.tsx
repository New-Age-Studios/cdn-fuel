import React, { useState, useEffect } from "react";
import { ThemeProvider } from "./context/ThemeContext";
import FuelSelector from "./components/FuelSelector";
import PaymentConfirm from "./components/PaymentConfirm";
import TransactionSummary from "./components/TransactionSummary";
import Management from "./components/Management/Management";
import InteractionMenu from "./components/InteractionMenu";
import StationPurchase from "./components/StationPurchase";
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
      fuelStock: 12450,
      maxStock: 20000,
      fuelPrice: 5.5,
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
  maxStock: number;
  fuelPrice: number;
  ownerName: string;
  stationName: string;
  logo?: string;
  stockLevel: number;
  upgrades: UpgradeTier[];
  loyaltyLevel: number;
  loyaltyUpgrades: LoyaltyTier[];
}

const App: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [step, setStep] = useState<
    "selector" | "payment" | "summary" | "management"
  >("payment");

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
        setFuelData({
          ...data,
          type: data.type || "fuel",
          tax: data.tax || 0,
          discount: data.discount || 0,
          stationName: data.stationName, // Let component handle fallback
          logo: data.logo,
          jerryCans: data.jerryCans || [],
        });

        if (data.type === "jerrycanRefuel" || data.type === "jerrycanRefill") {
          setStep("selector");
          if (data.type === "jerrycanRefill") {
            setSelectedMethod("cash"); // Default to cash for pump refill
          } else {
            setSelectedMethod(null);
          }
        } else {
          setStep("payment");
          setSelectedMethod(null);
        }

        setSelectedAmount(0);
        setSelectedJerryCanIndex(0);
        setVisible(true);
      } else if (action === "openManagement") {
        if (closeTimeoutRef.current) clearTimeout(closeTimeoutRef.current);
        setManagementData(data);
        setStep("management");
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

  const handlePaymentSelect = (method: "cash" | "bank") => {
    setSelectedMethod(method);

    if (fuelData.type === "syphon") {
      // cash (left) -> Syphon (Steal) -> 'out'
      // bank (right) -> Refuel (Give) -> 'in'
      setSyphonMode(method === "cash" ? "out" : "in");
    }

    setStep("selector");
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
                onBack={handleClose}
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
                    ? handleClose
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
