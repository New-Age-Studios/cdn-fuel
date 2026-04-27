import React from 'react';
import { useTheme } from '../context/ThemeContext';

interface TransactionSummaryProps {
  amount: number;
  price: number;
  tax?: number; // Tax percentage
  discount?: number; // Discount percentage
  method: 'cash' | 'bank' | null;
  isJerryCan?: boolean;
  isElectric?: boolean;
  isSyphon?: boolean;
  isJerryCanRefuel?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

const TransactionSummary: React.FC<TransactionSummaryProps> = ({ amount, price, tax = 0, discount = 0, method, isJerryCan, isElectric, isSyphon, isJerryCanRefuel, onConfirm, onCancel }) => {
  const subtotal = amount * price;
  const taxAmount = Math.ceil(subtotal * (tax / 100));
  const total = subtotal + taxAmount;
  const { theme, toggleTheme } = useTheme();

  return (
    <div className="flex w-full max-w-lg bg-dashboard-bg border border-border-color rounded-xl overflow-hidden shadow-2xl animate-in fade-in zoom-in duration-300 relative">
       
       <button 
         onClick={toggleTheme} 
         className="absolute top-4 right-4 size-8 rounded-lg bg-dashboard-element hover:bg-dashboard-element/80 text-text-muted hover:text-primary flex items-center justify-center transition-colors"
         title="Mudar Tema"
       >
          <span className="material-symbols-outlined text-lg">{theme === 'dark' ? 'light_mode' : 'dark_mode'}</span>
       </button>

       <div className="flex-1 p-8 flex flex-col items-center text-center">
          
          <div className="size-16 rounded-2xl bg-dashboard-element flex items-center justify-center mb-6 shadow-lg shadow-black/20">
             <span className={`material-symbols-outlined text-4xl ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>verified</span>
          </div>

          <h1 className="text-2xl font-bold text-primary tracking-tight uppercase">Confirmar Pedido</h1>
          <p className="text-text-muted text-sm mt-1 max-w-[280px]">Verifique os detalhes abaixo antes de finalizar</p>

          <div className="w-full bg-dashboard-card rounded-xl border border-border-color p-4 mt-8 flex flex-col gap-4">
              {!isSyphon && !isJerryCanRefuel && (
              <div className="flex justify-between items-center pb-3 border-b border-border-color">
                  <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Método</span>
                  <div className="flex items-center gap-2">
                       <span className={`material-symbols-outlined text-sm ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>
                           {method === 'cash' ? 'payments' : 'credit_card'}
                       </span>
                       <span className="text-sm font-bold text-primary capitalize">
                           {method === 'cash' ? 'Dinheiro' : 'Débito'}
                       </span>
                  </div>
              </div>
              )}
              <div className="flex justify-between items-center pb-3 border-b border-border-color">
                  <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
                      {isJerryCan ? 'Item' : isElectric ? 'Energia' : isSyphon || isJerryCanRefuel ? 'Volume' : 'Combustível'}
                  </span>
                  <span className="text-sm font-bold text-primary">
                      {isJerryCan ? `Galão (${amount}x)` : isElectric ? `${amount} kWh` : `${amount} Litros`}
                  </span>
              </div>
              
              {!isSyphon && !isJerryCanRefuel && (
                 <>
                   <div className="flex justify-between items-center">
                      <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Subtotal</span>
                      <span className="text-sm font-medium text-primary">${Math.ceil(subtotal)}</span>
                   </div>
                   {discount > 0 && (
                       <div className="flex justify-between items-center animate-pulse">
                          <span className="text-xs font-bold text-electric-yellow uppercase tracking-wider">Desconto ({discount}%)</span>
                          <span className="text-xs font-bold text-electric-yellow uppercase tracking-wider">APLICADO</span>
                       </div>
                   )}
                   {tax > 0 && (
                       <div className="flex justify-between items-center">
                          <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Imposto ({tax}%)</span>
                          <span className="text-sm font-medium text-red-400">+ ${taxAmount}</span>
                       </div>
                   )}
                   <div className="flex justify-between items-center pt-3 border-t border-border-color mt-1">
                      <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Total</span>
                      <span className={`text-xl font-bold ${isElectric ? 'text-electric-yellow' : 'text-neon-green'}`}>${total}</span>
                   </div>
                 </>
              )}
          </div>

          <div className="w-full flex gap-3 mt-8">
              <button 
                onClick={onCancel}
                className="flex-1 py-3 bg-dashboard-card hover:bg-dashboard-element hover:text-primary border border-border-color rounded-lg text-text-muted font-bold text-sm uppercase tracking-wider transition-all"
              >
                  Cancelar
              </button>
              <button 
                onClick={onConfirm}
                className={`flex-[2] py-3 ${isElectric ? 'bg-electric-yellow hover:bg-electric-yellow-hover shadow-electric-yellow/20' : 'bg-neon-green hover:bg-neon-green-hover shadow-neon-green/20'} !text-black font-black text-sm uppercase tracking-wider rounded-lg shadow-lg transition-all active:scale-[0.98]`}
              >
                  Confirmar
              </button>
          </div>

       </div>
    </div>
  );
};

export default TransactionSummary;
