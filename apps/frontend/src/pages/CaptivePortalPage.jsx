import { useState } from "react";
import { ArrowRight, Clock3, Smartphone, Wifi } from "lucide-react";
import { useSessionCountdown } from "../hooks/useSessionCountdown";

function parseRemainingSeconds(session) {
  if (Number.isFinite(session?.remainingSeconds)) {
    return Math.max(0, Math.floor(session.remainingSeconds));
  }

  if (Number.isFinite(session?.remainingMinutes)) {
    return Math.max(0, Math.floor(session.remainingMinutes * 60));
  }

  return 0;
}

function getCreditBankDisplay(remainingSeconds, fallbackMinutes) {
  const safeFallbackMinutes = Number.isFinite(fallbackMinutes) ? Math.max(0, Math.floor(fallbackMinutes)) : 0;

  if (!Number.isFinite(remainingSeconds)) {
    return {
      minutes: safeFallbackMinutes,
      isApproximate: false
    };
  }

  const safeSeconds = Math.max(0, Math.floor(remainingSeconds));
  const wholeMinutes = Math.floor(safeSeconds / 60);
  const hasPartialMinute = safeSeconds % 60 !== 0;

  if (!hasPartialMinute) {
    return {
      minutes: wholeMinutes,
      isApproximate: false
    };
  }

  // Conservative approximation: do not round up on partial minutes.
  return {
    minutes: Math.max(1, wholeMinutes),
    isApproximate: true
  };
}

function getPortalActionState(process) {
  const now = Date.now();
  const cooldownUntil = process?.cooldownUntil || 0;
  const isCoolingDown = cooldownUntil > now;
  const isProcessActive = Boolean(
    process?.requestActive || process?.cameraActive || process?.servoGateOpened
  );

  if (isProcessActive) {
    return {
      disabled: true,
      label: "Bottle process in progress"
    };
  }

  if (isCoolingDown) {
    return {
      disabled: true,
      label: "System cooling down"
    };
  }

  return {
    disabled: false,
    label: "Add 10 mins with a bottle"
  };
}

function CaptivePortalPage({ session, totalCredits, process, onExtendSession }) {
  const [isExtending, setIsExtending] = useState(false);
  const remainingSeconds = parseRemainingSeconds(session);
  const { formatted, extendByMinutes } = useSessionCountdown(remainingSeconds);
  const creditBankDisplay = getCreditBankDisplay(remainingSeconds, totalCredits);
  const actionState = getPortalActionState(process);

  const handleExtend = async () => {
    setIsExtending(true);

    try {
      const result = await onExtendSession();
      if (result?.addedMinutes > 0) {
        extendByMinutes(result.addedMinutes);
      }
    } finally {
      setIsExtending(false);
    }
  };

  return (
    <main className="mx-auto w-full max-w-6xl pb-6 pt-2">
      <header className="glass-panel p-4 animate-fadeUp">
        <p className="text-xs uppercase tracking-[0.35em] text-eco-muted">Captive Portal</p>
        <h1 className="mt-2 text-2xl font-black leading-tight text-eco-text sm:text-4xl">
          You&apos;re connected to Eco-Connect WiFi
        </h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-eco-muted">
          This portal shows your session details and allows you to extend your connection by adding more bottles at the kiosk.
        </p>
      </header>

      <section className="mt-4 grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-4">
          <article className="glass-panel p-4 animate-fadeUp">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-2xl border border-eco-edge/60 bg-eco-neon/10 p-2.5 text-eco-neon">
                  <Clock3 className="h-5 w-5" />
                </div>
                <div>
                  <p className="text-xs uppercase tracking-widest text-eco-muted">Remaining time</p>
                  <p className="mt-1 text-3xl font-black text-eco-accent sm:text-5xl">{formatted}</p>
                </div>
              </div>
              <p className="max-w-sm text-sm leading-6 text-eco-muted">
                If your session runs low, add another bottle at the kiosk to extend the connection.
              </p>
            </div>
          </article>

          <div className="grid gap-4 sm:grid-cols-2">
            <article className="glass-panel p-4 animate-fadeUp">
              <div className="flex items-center gap-3 text-eco-muted">
                <Smartphone className="h-4 w-4 text-eco-neon" />
                <span className="text-xs uppercase tracking-widest">Connected device</span>
              </div>
              <p className="mt-2 text-lg font-bold text-eco-text">
                {session.connected ? session.deviceLabel : "No device connected"}
              </p>
              <p className="mt-1 text-xs leading-5 text-eco-muted">This label is what the kiosk uses to track the active session.</p>
            </article>

            <article className="glass-panel p-4 animate-fadeUp">
              <div className="flex items-center gap-3 text-eco-muted">
                <Wifi className="h-4 w-4 text-eco-neon" />
                <span className="text-xs uppercase tracking-widest">Credit bank</span>
              </div>
              <p className="mt-2 text-3xl font-black text-eco-accent">
                {creditBankDisplay.isApproximate ? `~${creditBankDisplay.minutes}` : creditBankDisplay.minutes} min
              </p>
              <p className="mt-1 text-xs leading-5 text-eco-muted">Shared pool available for the kiosk and portal session.</p>
            </article>
          </div>

          <article className="glass-panel p-4 animate-fadeUp">
            <button
              type="button"
              onClick={handleExtend}
              disabled={isExtending || actionState.disabled}
              className="touch-btn flex w-full items-center justify-center gap-2 rounded-2xl border border-eco-edge bg-eco-neon px-4 py-3 text-base font-bold text-eco-bg transition active:scale-[0.98] disabled:opacity-60"
            >
              {isExtending ? "Starting bottle process..." : actionState.label}
              <ArrowRight className="h-5 w-5" />
            </button>
            <p className="mt-2 text-xs leading-5 text-eco-muted">
              Only one bottle and one user can use the reward path at a time. New requests stay locked while a bottle is being processed or while cooldown is active.
            </p>
          </article>
        </div>

        <aside className="space-y-4">
          <article className="glass-panel p-4 animate-fadeUp">
            <p className="text-xs uppercase tracking-widest text-eco-muted">Portal steps</p>
            <ol className="mt-2 space-y-2 text-sm leading-6 text-eco-muted">
              <li>1. Join the WiFi network.</li>
              <li>2. Keep this captive portal open on your phone.</li>
              <li>3. Add bottles at the kiosk to extend your time.</li>
            </ol>
          </article>
        </aside>
      </section>
    </main>
  );
}

export default CaptivePortalPage;