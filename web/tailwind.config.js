/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        "dashboard-bg": "rgb(var(--bg-dashboard) / <alpha-value>)", 
        "dashboard-card": "rgb(var(--bg-card) / <alpha-value>)", 
        "dashboard-element": "rgb(var(--bg-element) / <alpha-value>)", 
        "neon-green": "rgb(var(--color-neon-green) / <alpha-value>)", 
        "neon-green-hover": "rgb(var(--color-neon-hover) / <alpha-value>)", 
        "primary": "rgb(var(--color-primary-text) / <alpha-value>)",
        "text-muted": "rgb(var(--color-muted-text) / <alpha-value>)",
        "border-color": "rgb(var(--color-border) / <alpha-value>)",
        "electric-yellow": "#facc15", // Keep unchanged for now
        "electric-yellow-hover": "#eab308",
        "danger-red": "#ef4444",
      },
      fontFamily: {
        "sans": ["Inter", "sans-serif"], // Clean sans-serif
      },
      borderRadius: {
        "lg": "0.5rem",
        "xl": "0.75rem",
        "2xl": "1rem",
      },
      boxShadow: {
        'glow-green': '0 0 20px -5px rgba(34, 197, 94, 0.3)',
      }
    },
  },
  plugins: [],
}
