# Eco Piso WiFi MVP

Frontend app for the recycling-based WiFi vending kiosk.

## Stack

- React + Vite
- Tailwind CSS
- React Router
- Backend API integration via Axios

## Features Included

- Kiosk display for scanner status, bottle flow, and QR handoff
- Captive portal display for phones joining the WiFi network
- Backend-controlled process status for scanner workflow
- Credit display (`1 bottle = 10 minutes`)
- Session countdown with extend action
- QR login display for the captive portal flow
- Optional sound notification hook placeholder

## Project Structure

src/
  components/
  hooks/
  pages/
  services/
  App.jsx
  main.jsx

Routes:

- `/kiosk` for the physical kiosk screen
- `/portal` for the captive portal screen
- `/session` redirects to `/portal`

## Run Locally

1. Install Node.js (if not yet installed).
2. Install dependencies:

```bash
npm install
```

3. Start dev server:

```bash
npm run dev
```

## One-Command Deploy Helper

Use the included script:

```bash
./deploy.sh dev
```

This will:
- optionally pull latest code (if `GIT_PULL=1`)
- create `.env.local` from `.env.example` if missing
- run `pnpm install`
- run `pnpm run dev:lan`

Production build:

```bash
./deploy.sh prod
```

Optional dist sync to web root:

```bash
DEPLOY_DIST=1 DEPLOY_TARGET_DIR=/var/www/ecoconnect ./deploy.sh prod
```

## LAN Testing (Phone + Multiple Devices)

1. Copy `.env.example` to `.env.local`.
2. Set `VITE_API_BASE_URL` in `.env.local` to your laptop LAN IP:

```bash
VITE_API_BASE_URL=http://<LAPTOP_IP>:3000/api
```

3. Start the frontend with explicit LAN binding:

```bash
npm run dev:lan
```

4. Open from another device on the same Wi-Fi:

```text
http://<LAPTOP_IP>:5173/portal
```

5. Ensure backend is running and reachable at:

```text
http://<LAPTOP_IP>:3000/api/health
```

## API Client

Frontend API helpers are in `src/services/api.js`.