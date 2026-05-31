import os
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["DISPLAY"] = ""

from picamera2 import Picamera2
import cv2
import time

FRAME_PATH = os.getenv("SHARED_FRAME_PATH", "/tmp/frame.jpg")
FRAME_DIR = os.path.dirname(FRAME_PATH)

if FRAME_DIR:
    os.makedirs(FRAME_DIR, exist_ok=True)

picam2 = Picamera2()

# IMPORTANT: NO preview, NO GUI pipeline
config = picam2.create_video_configuration(
    main={"size": (3280, 2464)},
    controls={"FrameRate": 10}
)

picam2.configure(config)
picam2.start()

print("Camera started (FULL HEADLESS MODE)...")

while True:
    frame = picam2.capture_array()

    # Save directly (NO GUI libraries involved)
    cv2.imwrite(FRAME_PATH, frame)

    time.sleep(0.05)