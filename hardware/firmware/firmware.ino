// Barrier gate controller for the Wemos D1 R2 (ESP8266). Servo signal on D5 (GPIO14).
//
// Serial protocol at 115200 baud: 'o' open, 'c' close, '+' / '-' nudge 5 degrees,
// 's' report current position. Starts CLOSED on boot.
//
// The keep-alive pulse is not decorative: this servo runs off a USB power bank that
// sleeps when idle, and the pulse is what keeps it awake during a long event. Do not
// remove it, and keep the skip-while-open guard, without testing on real hardware.
#include <Servo.h>

Servo barrierServo;

const int servoPin = D5;

int closedPos = 10;
int openPos = 180;
int currentPos = 10;

const unsigned long keepAliveIntervalMs = 5000;  // 5s — tighter margin for power banks
const int keepAliveStep = 8;                       // 8 deg is enough to draw current without being visible
const unsigned long keepAlivePulseMs = 350;        // 350ms lets the servo physically move and load

unsigned long lastKeepAliveMs = 0;
bool keepAlivePositive = true;

void setup() {

  Serial.begin(115200);

  barrierServo.attach(servoPin);

  // start CLOSED immediately
  barrierServo.write(closedPos);
  currentPos = closedPos;

  Serial.println("Ready: o=open, c=close, +/-, s=status");
}

void loop() {

  if (Serial.available()) {
    char cmd = Serial.read();

    if (cmd == 'o') {
      barrierServo.write(openPos);
      currentPos = openPos;
      lastKeepAliveMs = millis();  // reset timer so keep-alive doesn't fire right after close
      Serial.println("OPEN");
    }

    else if (cmd == 'c') {
      barrierServo.write(closedPos);
      currentPos = closedPos;
      Serial.println("CLOSE");
    }

    else if (cmd == '+') {
      currentPos += 5;
      if (currentPos > 180) currentPos = 180;

      barrierServo.write(currentPos);
      Serial.println(currentPos);
    }

    else if (cmd == '-') {
      currentPos -= 5;
      if (currentPos < 0) currentPos = 0;

      barrierServo.write(currentPos);
      Serial.println(currentPos);
    }

    else if (cmd == 's') {
      Serial.println(currentPos);
    }
  }

  // Small pulse around the current position to keep power banks awake.
  // Skip while gate is open — movement during an active drop could interfere.
  unsigned long now = millis();
  if (currentPos != openPos && now - lastKeepAliveMs >= keepAliveIntervalMs) {
    lastKeepAliveMs = now;

    int direction = keepAlivePositive ? keepAliveStep : -keepAliveStep;
    int pulseTarget = currentPos + direction;
    if (pulseTarget > 180) pulseTarget = currentPos - keepAliveStep;  // bounce back if at ceiling
    if (pulseTarget < 0)   pulseTarget = currentPos + keepAliveStep;  // bounce back if at floor
    if (pulseTarget > 180) pulseTarget = 180;  // hard clamp
    if (pulseTarget < 0)   pulseTarget = 0;

    Serial.print("[KEEPALIVE] t=");
    Serial.print(now);
    Serial.print("ms  cur=");
    Serial.print(currentPos);
    Serial.print("  pulse=");
    Serial.print(pulseTarget);
    Serial.print("  dir=");
    Serial.println(keepAlivePositive ? "+" : "-");

    barrierServo.write(pulseTarget);
    delay(keepAlivePulseMs);
    barrierServo.write(currentPos);

    keepAlivePositive = !keepAlivePositive;

    Serial.println("[KEEPALIVE] done");
  }
}