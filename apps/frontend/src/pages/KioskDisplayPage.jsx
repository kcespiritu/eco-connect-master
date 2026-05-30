import { CircleDashed, LoaderCircle, QrCode, ScanLine, Sparkles } from "lucide-react";
import { QRCodeSVG } from "qrcode.react";

const DEFAULT_PORTAL_HOST = "10.42.0.1";

function isUsableHost(hostname) {
  if (!hostname) {
    return false;
  }

  const normalizedHost = String(hostname).trim().toLowerCase();
  return normalizedHost !== "localhost" && normalizedHost !== "127.0.0.1" && normalizedHost !== "::1";
}

function extractHostFromUrl(url) {
  if (!url) {
    return "";
  }

  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

function resolvePortalHost() {
  const currentHost = typeof window !== "undefined" ? window.location.hostname : "";

  if (isUsableHost(currentHost)) {
    return currentHost;
  }

  const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || "";
  const apiHost = extractHostFromUrl(apiBaseUrl);

  if (isUsableHost(apiHost)) {
    return apiHost;
  }

  return DEFAULT_PORTAL_HOST;
}

function buildPortalUrl() {
  const protocol = typeof window !== "undefined" ? window.location.protocol : "http:";
  const portalHost = resolvePortalHost();
  return `${protocol}//${portalHost}/portal`;
}

const STATUS_META = {
  "Waiting for bottle...": {
    title: "Ready",
    description: "Waiting for the next bottle.",
    icon: CircleDashed
  },
  "Detection process active": {
    title: "Portal request received",
    description: "A user started a bottle request. Camera and detector can run now.",
    icon: LoaderCircle
  },
  "Valid bottle detected": {
    title: "Valid bottle",
    description: "Camera and YOLO accepted the bottle.",
    icon: ScanLine
  },
  "Camera and YOLO validating": {
    title: "Validating",
    description: "Mock camera and YOLO are checking the bottle.",
    icon: LoaderCircle
  },
  "Credit added!": {
    title: "Done",
    description: "Credit was added successfully.",
    icon: Sparkles
  },
  "Bottle passed chute": {
    title: "IR confirmed",
    description: "Bottom IR sensor confirmed the bottle passed the chute.",
    icon: ScanLine
  },
  "Servo gate opened": {
    title: "Servo opened",
    description: "Gate opened to route the bottle.",
    icon: LoaderCircle
  },
  "Bottle rejected": {
    title: "Rejected",
    description: "Bottle did not pass validation, no credit was added.",
    icon: CircleDashed
  }
};

function KioskDisplayPage({ status }) {
  const detectionStatus = status?.detectionStatus ?? "Waiting for bottle...";
  const meta = STATUS_META[detectionStatus] ?? STATUS_META["Waiting for bottle..."];
  const StatusIcon = meta.icon;
  const qrValue = buildPortalUrl();
  const voucherCode = status?.session?.voucherCode ?? qrValue;
  const deviceLabel = status?.session?.deviceLabel ?? "Eco Piso WiFi kiosk";

  return (
    <main className="screen-frame kiosk-screen">
      <div className="screen-grid kiosk-grid">
        <section className="screen-stack">
          <header className="glass-panel screen-card kiosk-card p-4 animate-fadeUp">
            <p className="text-xs uppercase tracking-[0.35em] text-eco-muted">Kiosk View</p>
            <h1 className="mt-2 text-xl font-black leading-tight text-eco-text sm:text-2xl lg:text-3xl kiosk-title">
              Eco-Connect: Recycle for WiFi
            </h1>
          </header>

          <article className="glass-panel screen-card kiosk-card p-4 animate-fadeUp">
            <div className="flex items-start gap-3">
              <div className="rounded-2xl border border-eco-edge/60 bg-eco-neon/10 p-2 text-eco-neon">
                <StatusIcon className={`h-6 w-6 ${detectionStatus === "Validating..." ? "animate-spin" : ""}`} />
              </div>
              <div>
                <p className="text-xs uppercase tracking-widest text-eco-muted">Bottle scanner status</p>
                <p className="mt-1 text-2xl font-black text-eco-text kiosk-status-title">{meta.title}</p>
                <p className="mt-1 text-xs leading-5 text-eco-muted kiosk-body-text">{meta.description}</p>
              </div>
            </div>
          </article>

          <article className="glass-panel screen-card kiosk-card p-4 animate-fadeUp">
            <p className="text-xs uppercase tracking-widest text-eco-muted">What to do</p>
            <p className="mt-2 text-sm font-semibold text-eco-text kiosk-body-text">Connect to "EcoConnect", then scan the QR to open the portal, then click Add Bottle.</p>
            <p className="mt-1 text-xs leading-5 text-eco-muted kiosk-body-text">
              1 plastic bottle = 10 minutes of WiFi access. The more you recycle, the longer you can stay connected!
            </p>
          </article>
        </section>

        <aside className="screen-stack">
          <section className="glass-panel screen-card kiosk-card p-4 animate-fadeUp flex flex-col justify-between">
            <div className="flex items-center gap-2 text-sm uppercase tracking-wider text-eco-muted">
              <QrCode className="h-4 w-4 text-eco-neon" />
              Scan to connect
            </div>
            <div className="mt-3 flex flex-1 items-center justify-center rounded-3xl border border-eco-edge/60 bg-white p-3 kiosk-qr-wrap">
              <QRCodeSVG value={qrValue} size={160} className="kiosk-qr-code" />
            </div>
            <div className="mt-3 rounded-2xl border border-eco-edge/60 bg-black/20 p-3 kiosk-voucher">
              <p className="text-[11px] uppercase tracking-widest text-eco-muted">Optional voucher code</p>
              <p className="mt-1 break-all font-mono text-sm font-semibold text-eco-accent">{voucherCode}</p>
              <p className="mt-1 text-[11px] leading-4 text-eco-muted">Use this code if QR scanning is not available on the device.</p>
            </div>
            <p className="mt-3 text-xs leading-5 text-eco-muted kiosk-device-label">{deviceLabel}</p>
          </section>
        </aside>
      </div>
    </main>
  );
}

export default KioskDisplayPage;
