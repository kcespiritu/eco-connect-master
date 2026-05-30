from gpiozero import InputDevice
import requests
from time import sleep

# -----------------------------
# IR SENSOR SETUP
# -----------------------------
ir_sensor = InputDevice(17)  # GPIO17

# Your captive portal URL (CHANGE THIS)
PORTAL_URL = "http://10.42.0.1:3000/trigger"
# Example: http://192.168.1.1/trigger or your PHP endpoint

print("IR Sensor System Running...")

# -----------------------------
# MAIN LOOP
# -----------------------------
while True:

    # IR sensor detects object (usually LOW = detected)
    if ir_sensor.value == 0:

        print("Object Detected!")

        try:
            # Send signal to captive portal
            response = requests.get(PORTAL_URL)

            print("Portal triggered:", response.status_code)

        except Exception as e:
            print("Failed to contact portal:", e)

        # simple anti-spam delay
        sleep(2)

    sleep(0.1)