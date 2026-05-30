from picamera2 import Picamera2
import cv2

picam2 = Picamera2()

config = picam2.create_preview_configuration(
    main={"size": (640, 480)}
)

picam2.configure(config)
picam2.start()
picam2.set_controls({
	"AwbMode": True
})

print("Camera started...")

while True:
    frame = picam2.capture_array()
    frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

    # Save latest frame for YOLO process
    cv2.imwrite("/tmp/frame.jpg", frame)

    # Show camera preview on Pi monitor
    cv2.imshow("Pi Camera", frame)

    # ESC key to quit
    if cv2.waitKey(1) == 27:
        break

cv2.destroyAllWindows()
