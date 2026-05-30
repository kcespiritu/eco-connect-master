import axios from "axios";

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api").replace(/\/$/, "");

const STORAGE_SESSION_TOKEN = "ecoConnectSessionToken";
const STORAGE_CLIENT_MAC = "ecoConnectClientMac";
const STORAGE_TOTAL_BOTTLES = "ecoConnectTotalBottles";

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000
});

export async function checkHealth() {
  const response = await api.get("/health");
  const data = response?.data || {};

  return {
    online: data.status === "online",
    database: Boolean(data.database)
  };
}

function toUiSession(sessionData) {
  const remainingSeconds = parseBackendRemainingSeconds(sessionData);
  const remainingMinutes = Math.max(0, Math.ceil(remainingSeconds / 60));

  return {
    connected: Boolean(sessionData?.isActive ?? sessionData?.status === "ACTIVE"),
    deviceLabel: sessionData?.client_mac || "Eco-Connect Kiosk",
    remainingSeconds,
    remainingMinutes,
    qrLoginToken: sessionData?.session_token || "",
    voucherCode: sessionData?.session_token || ""
  };
}

function parseBackendRemainingSeconds(sessionData) {
  if (Number.isFinite(sessionData?.remaining)) {
    return Math.max(0, Math.floor(sessionData.remaining));
  }

  if (Number.isFinite(sessionData?.credits)) {
    return Math.max(0, Math.floor(sessionData.credits));
  }

  return 0;
}

function getStoredBottles() {
  const rawValue = window.localStorage.getItem(STORAGE_TOTAL_BOTTLES);
  const parsed = Number.parseInt(rawValue || "0", 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function getOrCreateClientMac() {
  const existing = window.localStorage.getItem(STORAGE_CLIENT_MAC);
  if (existing) {
    return existing;
  }

  const suffix = Math.random().toString(16).slice(2, 14).padEnd(12, "0").slice(0, 12);
  const mac = suffix.match(/.{1,2}/g).join(":");
  window.localStorage.setItem(STORAGE_CLIENT_MAC, mac);
  return mac;
}

async function openSession() {
  const clientMac = getOrCreateClientMac();
  const response = await api.post("/session/open", { clientMac });
  const sessionData = response?.data?.data;

  if (!sessionData?.session_token) {
    throw new Error("Backend did not return a session token");
  }

  window.localStorage.setItem(STORAGE_SESSION_TOKEN, sessionData.session_token);
  return sessionData;
}

async function fetchSessionByToken(sessionToken) {
  const response = await api.get(`/session/${encodeURIComponent(sessionToken)}`);
  return response?.data?.data || null;
}

function hasUsableSession(sessionData) {
  if (!sessionData) {
    return false;
  }

  return sessionData?.status !== "EXPIRED";
}

async function getOrCreateSession() {
  const sessionToken = window.localStorage.getItem(STORAGE_SESSION_TOKEN);

  if (!sessionToken) {
    return openSession();
  }

  try {
    const existingSession = await fetchSessionByToken(sessionToken);
    if (!hasUsableSession(existingSession)) {
      return openSession();
    }
    return existingSession;
  } catch (error) {
    if (error?.response?.status === 404) {
      return openSession();
    }
    throw error;
  }
}

function buildStatus(sessionData) {
  const session = toUiSession(sessionData);

  return {
    totalCredits: session.remainingMinutes,
    totalBottles: getStoredBottles(),
    detectionStatus: "Waiting for bottle...",
    session,
    health: {
      online: true,
      database: true
    }
  };
}

export async function getStatus() {
  const health = await checkHealth();
  const sessionData = await getOrCreateSession();
  return {
    ...buildStatus(sessionData),
    health
  };
}

export async function getProcessStatus() {
  const response = await api.get("/process/status");
  return response?.data?.data || null;
}

export async function startBottleProcess() {
  const sessionData = await getOrCreateSession();
  const sessionToken = sessionData?.session_token;

  if (!sessionToken) {
    throw new Error("No active session token available");
  }

  const response = await api.post("/process/start", { sessionToken });
  return response?.data?.data || null;
}

export async function submitProcessDecision(decision) {
  const response = await api.post("/process/admin/decision", { decision });
  return response?.data?.data || null;
}

export async function setProcessServo(opened) {
  const response = await api.post("/process/admin/servo", { opened });
  return response?.data?.data || null;
}

export async function setManualServo(opened) {
  const response = await api.post("/process/admin/servo/manual", { opened });
  return response?.data?.data || null;
}

export async function triggerProcessIrReward() {
  const response = await api.post("/process/admin/ir-trigger");
  return response?.data?.data || null;
}

export async function resetProcessState() {
  const response = await api.post("/process/reset");
  return response?.data?.data || null;
}

export async function closeAllSessions() {
  const response = await api.post("/session/close-all");
  return response?.data?.data || null;
}

export async function getSession() {
  const sessionData = await getOrCreateSession();
  return toUiSession(sessionData);
}