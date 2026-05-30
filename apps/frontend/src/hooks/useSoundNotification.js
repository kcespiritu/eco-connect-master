import { useCallback } from "react";

export function useSoundNotification() {
  const playCreditSound = useCallback(() => {
    try {
      const context = new window.AudioContext();
      const oscillator = context.createOscillator();
      const gainNode = context.createGain();

      oscillator.type = "sine";
      oscillator.frequency.value = 960;
      gainNode.gain.value = 0.07;

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);

      oscillator.start();
      oscillator.stop(context.currentTime + 0.13);
    } catch (_error) {
      // Placeholder hook: in kiosk mode this can be replaced with hardware buzzer/audio trigger.
    }
  }, []);

  return { playCreditSound };
}