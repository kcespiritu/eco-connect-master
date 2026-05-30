import { useCallback, useEffect, useRef, useState } from "react";

const FLOW = [
  { label: "Waiting for bottle...", delay: 600 },
  { label: "Bottle detected", delay: 800 },
  { label: "Validating...", delay: 900 },
  { label: "Credit added!", delay: 1200 }
];

export function useBottleDetection(onCreditAdded) {
  const [status, setStatus] = useState(FLOW[0].label);
  const [isRunning, setIsRunning] = useState(false);
  const timersRef = useRef([]);

  const clearTimers = () => {
    timersRef.current.forEach((id) => clearTimeout(id));
    timersRef.current = [];
  };

  useEffect(() => {
    return clearTimers;
  }, []);

  const runFlow = useCallback(() => {
    if (isRunning) {
      return;
    }

    setIsRunning(true);
    clearTimers();

    let elapsed = 0;

    FLOW.forEach((step, index) => {
      elapsed += step.delay;
      const timer = setTimeout(async () => {
        setStatus(step.label);

        if (index === FLOW.length - 1) {
          if (onCreditAdded) {
            await onCreditAdded();
          }

          const resetTimer = setTimeout(() => {
            setStatus(FLOW[0].label);
            setIsRunning(false);
          }, 900);

          timersRef.current.push(resetTimer);
        }
      }, elapsed);

      timersRef.current.push(timer);
    });
  }, [isRunning, onCreditAdded]);

  return {
    status,
    isRunning,
    runFlow
  };
}