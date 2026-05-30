import { useEffect, useMemo, useState } from "react";

export function useSessionCountdown(initialSeconds) {
  const [remainingSeconds, setRemainingSeconds] = useState(() => Math.max(0, Math.floor(initialSeconds || 0)));

  useEffect(() => {
    setRemainingSeconds(Math.max(0, Math.floor(initialSeconds || 0)));
  }, [initialSeconds]);

  useEffect(() => {
    if (remainingSeconds <= 0) {
      return undefined;
    }

    const intervalId = setInterval(() => {
      setRemainingSeconds((previous) => Math.max(0, previous - 1));
    }, 1000);

    return () => clearInterval(intervalId);
  }, [remainingSeconds]);

  const formatted = useMemo(() => {
    const minutes = Math.floor(remainingSeconds / 60);
    const seconds = remainingSeconds % 60;
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }, [remainingSeconds]);

  const extendByMinutes = (minutes) => {
    setRemainingSeconds((prev) => prev + minutes * 60);
  };

  return {
    remainingSeconds,
    formatted,
    extendByMinutes
  };
}