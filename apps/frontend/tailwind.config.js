/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        eco: {
          bg: "#060f0e",
          panel: "#10211f",
          edge: "#264a45",
          neon: "#25f795",
          accent: "#62ffd6",
          text: "#e6fff4",
          muted: "#9db8af"
        }
      },
      boxShadow: {
        neon: "0 0 0 1px rgba(37, 247, 149, 0.24), 0 0 18px rgba(37, 247, 149, 0.18)"
      },
      keyframes: {
        pulseRing: {
          "0%": { transform: "scale(1)", opacity: "0.8" },
          "70%": { transform: "scale(1.08)", opacity: "0.2" },
          "100%": { transform: "scale(1.12)", opacity: "0" }
        },
        fadeUp: {
          "0%": { opacity: "0", transform: "translateY(8px)" },
          "100%": { opacity: "1", transform: "translateY(0)" }
        }
      },
      animation: {
        pulseRing: "pulseRing 1.7s ease-out infinite",
        fadeUp: "fadeUp 400ms ease-out"
      }
    }
  },
  plugins: []
};