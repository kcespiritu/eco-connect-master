import { useEffect, useState } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { io } from "socket.io-client";
import CaptivePortalPage from "./pages/CaptivePortalPage";
import KioskDisplayPage from "./pages/KioskDisplayPage";
import AdminTestPage from "./pages/AdminTestPage";
import {
  closeAllSessions,
  getProcessStatus,
  getStatus,
  setManualServo,
  resetProcessState,
  setProcessServo,
  startBottleProcess,
  submitProcessDecision,
  triggerProcessIrReward,
} from "./services/api";

const ADMIN_PASSWORD = "ChromeBoys";
const ADMIN_SESSION_KEY = "ecoConnectAdminUnlocked";

const INITIAL_PROCESS = {
  requestActive: false,
  cameraActive: false,
  requestId: null,
  sessionToken: null,
  cameraId: null,
  yoloDecision: "idle",
  irBottomDetected: false,
  servoGateOpened: false,
  pipelineStatus: "Waiting for bottle...",
  cooldownUntil: 0,
  lastOutcome: null,
  lastReason: null,
  cooldownRemainingMs: 0
};

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || (import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api").replace(/\/api\/?$/, "");

function getInitialStatus() {
  return {
    totalCredits: 0,
    totalBottles: 0,
    detectionStatus: "Waiting for bottle...",
    session: {
      connected: false,
      deviceLabel: "Eco-Connect Kiosk",
      remainingSeconds: 0,
      remainingMinutes: 0,
      qrLoginToken: "",
      voucherCode: ""
    },
    process: { ...INITIAL_PROCESS },
    health: {
      online: false,
      database: false
    }
  };
}

function App() {
  const location = useLocation();
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [healthLabel, setHealthLabel] = useState("Checking backend...");
  const [adminBusy, setAdminBusy] = useState(false);
  const [adminPasswordInput, setAdminPasswordInput] = useState("");
  const [adminAuthError, setAdminAuthError] = useState("");
  const [adminUnlocked, setAdminUnlocked] = useState(() => {
    try {
      return window.sessionStorage.getItem(ADMIN_SESSION_KEY) === "1";
    } catch {
      return false;
    }
  });
  const isKioskRoute = location.pathname === "/" || location.pathname.startsWith("/kiosk");

  const loadStatus = async ({ keepLoading = false } = {}) => {
    try {
      const [nextStatus, nextProcess] = await Promise.all([getStatus(), getProcessStatus()]);
      setStatus({
        ...nextStatus,
        process: {
          ...INITIAL_PROCESS,
          ...(nextProcess || {})
        },
        detectionStatus: nextProcess?.pipelineStatus || nextStatus.detectionStatus
      });
      setHealthLabel(
        nextStatus?.health?.online
          ? nextStatus?.health?.database
            ? "Backend online"
            : "Backend online (DB issue)"
          : "Backend offline"
      );
    } catch {
      setStatus(getInitialStatus());
      setHealthLabel("Backend offline");
    } finally {
      if (!keepLoading) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    loadStatus();
  }, []);

  useEffect(() => {
    const socket = io(SOCKET_URL, {
      transports: ["websocket", "polling"]
    });

    const onProcessStatus = (payload) => {
      const nextProcess = payload?.state;
      const reason = payload?.reason;

      if (nextProcess && typeof nextProcess === "object") {
        setStatus((previousStatus) => {
          const safePrevious = previousStatus || getInitialStatus();
          return {
            ...safePrevious,
            process: {
              ...INITIAL_PROCESS,
              ...nextProcess
            },
            detectionStatus: nextProcess.pipelineStatus || safePrevious.detectionStatus
          };
        });
      }

      // Keep session/credits in sync after reward events or first socket sync.
      if (reason === "CREDIT_ADDED" || reason === "INITIAL_SYNC") {
        loadStatus({ keepLoading: true });
      }
    };

    socket.on("process:status", onProcessStatus);

    return () => {
      socket.off("process:status", onProcessStatus);
      socket.disconnect();
    };
  }, []);

  const startBottleRequest = async () => {
    try {
      const result = await startBottleProcess();
      await loadStatus({ keepLoading: true });
      return { success: true, started: Boolean(result?.ok), addedMinutes: 0 };
    } catch (error) {
      await loadStatus({ keepLoading: true });
      return { success: false, addedMinutes: 0, reason: error?.response?.data?.error || error.message };
    }
  };

  const markBottleValid = () => {
    return submitProcessDecision("valid").finally(() => loadStatus({ keepLoading: true }));
  };

  const rejectBottle = () => {
    return submitProcessDecision("invalid").finally(() => loadStatus({ keepLoading: true }));
  };

  const openServoGate = () => {
    return setProcessServo(true).finally(() => loadStatus({ keepLoading: true }));
  };

  const closeServoGate = () => {
    return setProcessServo(false).finally(() => loadStatus({ keepLoading: true }));
  };

  const manualOpenServo = async () => {
    setAdminBusy(true);
    try {
      await setManualServo(true);
      await loadStatus({ keepLoading: true });
    } finally {
      setAdminBusy(false);
    }
  };

  const manualCloseServo = async () => {
    setAdminBusy(true);
    try {
      await setManualServo(false);
      await loadStatus({ keepLoading: true });
    } finally {
      setAdminBusy(false);
    }
  };

  const triggerIrReward = async () => {
    setAdminBusy(true);
    try {
      await triggerProcessIrReward();
      await loadStatus({ keepLoading: true });
    } finally {
      setAdminBusy(false);
    }
  };

  const resetProcess = () => resetProcessState().finally(() => loadStatus({ keepLoading: true }));

  const endAllSessions = async () => {
    setAdminBusy(true);
    try {
      await closeAllSessions();
      await loadStatus({ keepLoading: true });
    } finally {
      setAdminBusy(false);
    }
  };

  const submitAdminPassword = (event) => {
    event.preventDefault();

    if (adminPasswordInput === ADMIN_PASSWORD) {
      setAdminUnlocked(true);
      setAdminAuthError("");
      setAdminPasswordInput("");
      try {
        window.sessionStorage.setItem(ADMIN_SESSION_KEY, "1");
      } catch {
        // Ignore storage errors; keep in-memory unlock for this page session.
      }
      return;
    }

    setAdminAuthError("Incorrect password");
  };

  const lockAdmin = () => {
    setAdminUnlocked(false);
    setAdminPasswordInput("");
    setAdminAuthError("");
    try {
      window.sessionStorage.removeItem(ADMIN_SESSION_KEY);
    } catch {
      // Ignore storage errors.
    }
  };

  if (loading || !status) {
    return (
      <div className="app-shell app-shell--kiosk flex items-center justify-center">
        <div className="glass-panel px-6 py-5 text-center">
          <p className="text-xl font-bold text-eco-accent">Loading Eco Piso WiFi...</p>
          <p className="mt-2 text-sm text-eco-muted">{healthLabel}</p>
        </div>
      </div>
    );
  }

  return (
    <div className={`app-shell ${isKioskRoute ? "app-shell--kiosk" : "app-shell--portal"}`}>
      <div className="pointer-events-none fixed right-3 top-3 z-50">
        <span
          className={`inline-flex rounded-full border px-3 py-1 text-xs font-semibold ${
            status.health?.online && status.health?.database
              ? "border-emerald-300/50 bg-emerald-300/15 text-emerald-200"
              : "border-amber-300/50 bg-amber-300/15 text-amber-200"
          }`}
        >
          {healthLabel}
        </span>
      </div>
      <Routes>
        <Route path="/" element={<Navigate to="/portal" replace />} />
        <Route
          path="/kiosk"
          element={
            <KioskDisplayPage status={status} />
          }
        />
        <Route
          path="/portal"
          element={<CaptivePortalPage session={status.session} totalCredits={status.totalCredits} process={status.process} onExtendSession={startBottleRequest} />}
        />
        <Route
          path="/session"
          element={<Navigate to="/portal" replace />}
        />
        <Route
          path="/admin"
          element={
            adminUnlocked ? (
              <div className="mx-auto w-full max-w-6xl pb-6 pt-2">
                <div className="mb-3 flex justify-end">
                  <button
                    type="button"
                    onClick={lockAdmin}
                    className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text"
                  >
                    Lock admin
                  </button>
                </div>
                <AdminTestPage
                  process={status.process}
                  onMarkBottleValid={markBottleValid}
                  onRejectBottle={rejectBottle}
                  onOpenServoGate={openServoGate}
                  onCloseServoGate={closeServoGate}
                  onManualOpenServo={manualOpenServo}
                  onManualCloseServo={manualCloseServo}
                  onTriggerIrReward={triggerIrReward}
                  onResetProcess={resetProcess}
                  onEndAllSessions={endAllSessions}
                  busy={adminBusy}
                />
              </div>
            ) : (
              <main className="mx-auto flex min-h-[70vh] w-full max-w-md items-center justify-center pb-6 pt-2">
                <section className="glass-panel w-full p-5 animate-fadeUp">
                  <p className="text-xs uppercase tracking-[0.35em] text-eco-muted">Admin Access</p>
                  <h1 className="mt-2 text-2xl font-black leading-tight text-eco-text">Enter Admin Password</h1>
                  <p className="mt-2 text-sm leading-6 text-eco-muted">
                    This page is protected. Enter the admin password to continue.
                  </p>
                  <form className="mt-4 space-y-3" onSubmit={submitAdminPassword}>
                    <input
                      type="password"
                      value={adminPasswordInput}
                      onChange={(event) => setAdminPasswordInput(event.target.value)}
                      className="w-full rounded-xl border border-eco-edge bg-black/20 px-3 py-2 text-sm text-eco-text outline-none"
                      placeholder="Password"
                      autoFocus
                    />
                    {adminAuthError ? <p className="text-xs text-red-300">{adminAuthError}</p> : null}
                    <button
                      type="submit"
                      className="w-full rounded-xl border border-eco-edge bg-eco-neon px-3 py-2 text-sm font-bold text-eco-bg"
                    >
                      Unlock admin
                    </button>
                  </form>
                </section>
              </main>
            )
          }
        />
        <Route path="*" element={<Navigate to="/portal" replace />} />
      </Routes>
    </div>
  );
}

export default App;