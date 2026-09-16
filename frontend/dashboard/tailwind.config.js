/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: {
          950: '#0b1220',
          900: '#0f172a',
          800: '#151f32',
          700: '#1c2942',
        },
        brand: {
          50: '#eef6ff',
          100: '#d9ecff',
          200: '#b8dcff',
          300: '#86c4ff',
          400: '#4da3ff',
          500: '#2280f5',
          600: '#1263d9',
          700: '#0f4fae',
          800: '#12428b',
          900: '#153a72',
        },
        volt: {
          400: '#c9f04a',
          500: '#aee022',
        },
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      boxShadow: {
        panel: '0 1px 2px rgba(15, 23, 42, 0.04), 0 8px 24px -8px rgba(15, 23, 42, 0.10)',
      },
    },
  },
  plugins: [],
}
