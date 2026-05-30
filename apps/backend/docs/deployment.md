# EcoConnect Backend Deployment Guide

## Prerequisites

- Node.js v18+ installed
- systemd available (Linux/Raspberry Pi)
- `better-sqlite3` and all npm dependencies installed

## Installation

1. **Clone and setup**
   ```bash
   git clone <repo> ecoconnect
   cd ecoconnect/backend
   npm install
   ```

2. **Environment Configuration**
   Create `.env` file:
   ```bash
   DETECTOR_TOKEN=your-secure-token-here
   CONFIDENCE_THRESHOLD=0.8
   REWARD_PLASTIC_BOTTLE=5
   REWARD_DEFAULT=0
   REWARD_MODE=allow_zero
   PORT=3000
   ```

3. **Copy systemd units**
   ```bash
   sudo cp deploy/systemd/ecoconnect-backend.service /etc/systemd/system/
   sudo cp deploy/systemd/ecoconnect-detect.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

## Running the Backend

### One-Command Deploy Helper

Use the included script from project root:

```bash
./deploy.sh dev
```

This will:
- create `.env` from `.env.example` if missing
- run `pnpm install`
- start backend in dev mode (background)

For Linux/systemd deployment:

```bash
./deploy.sh prod
```

### Development
```bash
npm run dev
```
Server starts on `http://localhost:3000`

### Production with systemd
```bash
# Enable auto-start on boot
sudo systemctl enable ecoconnect-backend
sudo systemctl enable ecoconnect-detect

# Start services
sudo systemctl start ecoconnect-backend
sudo systemctl start ecoconnect-detect

# Check status
sudo systemctl status ecoconnect-backend
sudo systemctl status ecoconnect-detect

# View logs
sudo journalctl -u ecoconnect-backend -f
sudo journalctl -u ecoconnect-detect -f
```

## API Health Check

```bash
curl http://localhost:3000/api/health
```

Expected response:
```json
{
  "status": "online",
  "database": true
}
```

## Troubleshooting

- **Service fails to start**: Check logs with `journalctl -u ecoconnect-backend -n 50`
- **Database locked**: Ensure only one instance is running. Check for orphaned processes.
- **Port 3000 in use**: Change `PORT` in `.env` or kill conflicting process.

