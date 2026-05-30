import { useEffect, useMemo, useState } from "react";

export function useSessionCountdown(initialSeconds) {
  const [remainingSeconds, setRemainingSeconds] = useState(initialSeconds);

  useEffect(() => {
    setRemainingSeconds(initialSeconds);
  }, [initialSeconds]);

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