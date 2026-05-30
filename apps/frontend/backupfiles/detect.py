from ultralytics import YOLO
import cv2
import time
import os

# Load YOLO model
model = YOLO("yolov8n.pt")

print("YOLO Bottle Detection started (HEADLESS MODE)...")

# Optional: save output frames
save_output = False
output_dir = "output_frames"

if save_output:
    os.makedirs(output_dir, exist_ok=True)

frame_count = 0

while True:

    # Read latest frame
    frame = cv2.imread("/tmp/frame.jpg")

    if frame is None:
        time.sleep(0.1)
        continue

    # Run detection
    results = model(
        frame,
        conf=0.30,
        imgsz=640,
        verbose=False
    )

    bottle_found = False

    # Process detections
    for box in results[0].boxes:

        cls_id = int(box.cls[0])
        name = model.names[cls_id]
        conf = float(box.conf[0])

        if name == "bottle":
            bottle_found = True

            x1, y1, x2, y2 = map(int, box.xyxy[0])

            print(f"Bottle detected | Conf: {conf:.2f} | Box: {x1},{y1},{x2},{y2}")

            # Draw box (still useful if saving frames)
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 3)
            cv2.putText(
                frame,
                f"Bottle {conf:.2f}",
                (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (0, 255, 0),
                2
            )

    if not bottle_found:
        print("No bottle detected")

    # Optional: save frames instead of displaying
    if save_output:
        cv2.imwrite(f"{output_dir}/frame_{frame_count}.jpg", frame)
        frame_count += 1

    # Small delay to prevent CPU overload
    time.sleep(0.01)
