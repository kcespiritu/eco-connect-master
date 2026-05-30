import { Link } from "react-router-dom";

function AdminTestPage({ process, onMarkBottleValid, onRejectBottle, onOpenServoGate, onCloseServoGate, onManualOpenServo, onManualCloseServo, onTriggerIrReward, onResetProcess, onEndAllSessions, busy }) {
  const cooldownRemainingMs = Math.max(0, (process?.cooldownUntil || 0) - Date.now());
  const cooldownSeconds = Math.ceil(cooldownRemainingMs / 1000);
  const hasPortalRequest = Boolean(process?.requestActive);
  const canValidateBottle = hasPortalRequest && process?.yoloDecision === "pending";
  const canOpenServo = hasPortalRequest && process?.yoloDecision === "valid" && !process?.servoGateOpened;
  const canTriggerIrReward = hasPortalRequest && process?.yoloDecision === "valid" && process?.servoGateOpened && cooldownRemainingMs === 0;

  return (
    <main className="mx-auto w-full max-w-6xl pb-6 pt-2">
      <header className="glass-panel p-4 animate-fadeUp">
        <p className="text-xs uppercase tracking-[0.35em] text-eco-muted">Admin Test Mode</p>
        <h1 className="mt-2 text-2xl font-black leading-tight text-eco-text sm:text-4xl">
          Webhook and Sensor Simulator
        </h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-eco-muted">
          These controls now drive backend-controlled process state. The user must start from the portal, then admin simulates camera and YOLO, servo release, and the final chute IR reward trigger.
        </p>
      </header>

      <section className="mt-4 grid gap-4 lg:grid-cols-2">
        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Current process state</p>
          <p className="mt-2 text-sm text-eco-text">Portal request: {hasPortalRequest ? "Active" : "Idle"}</p>
          <p className="mt-1 text-sm text-eco-text">Camera and YOLO: {process?.cameraActive ? "Running" : process?.yoloDecision === "valid" ? "Valid bottle" : process?.yoloDecision === "invalid" ? "Rejected bottle" : "Idle"}</p>
          <p className="mt-2 text-sm text-eco-text">IR bottom sensor: {process?.irBottomDetected ? "Detected" : "Idle"}</p>
          <p className="mt-1 text-sm text-eco-text">Servo gate: {process?.servoGateOpened ? "Opened" : "Closed"}</p>
          <p className="mt-1 text-sm text-eco-text">Pipeline: {process?.pipelineStatus || "Waiting for bottle..."}</p>
          <p className="mt-1 text-sm text-eco-text">Cooldown: {cooldownSeconds > 0 ? `${cooldownSeconds}s remaining` : "Ready"}</p>
        </article>

        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Quick navigation</p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link to="/kiosk" className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text">
              Open kiosk view
            </Link>
            <Link to="/portal" className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text">
              Open portal view
            </Link>
          </div>
        </article>
      </section>

      <section className="mt-4 grid gap-4 lg:grid-cols-2">
        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Portal lock</p>
          <p className="mt-2 text-sm leading-6 text-eco-muted">
            Only one bottle and one user are processed at a time. If a portal request is active or cooldown is running, no other user should be able to start another bottle flow.
          </p>
        </article>

        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Mock hardware steps</p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button
              type="button"
              disabled={busy || !canValidateBottle}
              onClick={onMarkBottleValid}
              className="rounded-xl border border-eco-edge bg-eco-neon/15 px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Mock valid camera + YOLO
            </button>
            <button
              type="button"
              disabled={busy || !canValidateBottle}
              onClick={onRejectBottle}
              className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Mock invalid bottle
            </button>
            <button
              type="button"
              disabled={busy || !canOpenServo}
              onClick={onOpenServoGate}
              className="rounded-xl border border-eco-edge bg-eco-neon/15 px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Open servo gate
            </button>
            <button
              type="button"
              disabled={busy || !process?.servoGateOpened}
              onClick={onCloseServoGate}
              className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Close servo gate
            </button>
          </div>
        </article>

        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Manual servo override (separate test)</p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={onManualOpenServo}
              className="rounded-xl border border-eco-edge bg-eco-neon/15 px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Manual open servo
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={onManualCloseServo}
              className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text disabled:opacity-60"
            >
              Manual close servo
            </button>
          </div>
          <p className="mt-2 text-xs leading-5 text-eco-muted">
            This sends direct hardware commands and does not run or change mock process flow transitions.
          </p>
        </article>

        <article className="glass-panel p-4 animate-fadeUp lg:col-span-2">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Final chute reward trigger</p>
          <div className="mt-3 flex flex-col gap-2">
            <button
              type="button"
              disabled={busy || !canTriggerIrReward}
              onClick={onTriggerIrReward}
              className="rounded-xl border border-eco-edge bg-eco-neon px-3 py-2 text-sm font-bold text-eco-bg disabled:opacity-60"
            >
              {busy ? "Triggering IR reward..." : "Trigger chute IR and reward bottle"}
            </button>
            <p className="text-xs leading-5 text-eco-muted">
              Reward is only granted here, after a valid bottle has been detected and the servo gate has already opened.
            </p>
            <button
              type="button"
              onClick={onResetProcess}
              className="rounded-xl border border-eco-edge px-3 py-2 text-sm font-semibold text-eco-text"
            >
              Reset process to initial
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={onEndAllSessions}
              className="rounded-xl border border-red-300/50 bg-red-500/15 px-3 py-2 text-sm font-bold text-red-100 disabled:opacity-60"
            >
              {busy ? "Ending all sessions..." : "End all sessions"}
            </button>
            <p className="text-xs leading-5 text-eco-muted">
              This force-expires every active session and revokes hotspot access for each one.
            </p>
          </div>
        </article>
      </section>

      <section className="mt-4">
        <article className="glass-panel p-4 animate-fadeUp">
          <p className="text-xs uppercase tracking-widest text-eco-muted">Suggested test steps</p>
          <ol className="mt-2 space-y-2 text-sm leading-6 text-eco-muted">
            <li>1. Open portal in another tab and press Add 10 mins with a bottle to start the request.</li>
            <li>2. Verify the portal button becomes locked, confirming one user and one bottle are being processed at a time.</li>
            <li>3. Click Mock valid camera + YOLO to simulate a valid bottle, or Mock invalid bottle to reject it immediately.</li>
            <li>4. If valid, click Open servo gate, then click Trigger chute IR and reward bottle to grant the reward.</li>
            <li>5. Wait for the automatic reset and cooldown, then confirm the portal button becomes available again once the cooldown finishes.</li>
          </ol>
        </article>
      </section>
    </main>
  );
}

export default AdminTestPage;
