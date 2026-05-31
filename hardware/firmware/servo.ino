// Insert servo.ino script here <AGENT DO NOT TOUCH>#include <Servo.h>

Servo barrierServo;

const int servoPin = D5;

int closedPos = 10;
int openPos = 180;
int currentPos = 10;

const unsigned long keepAliveIntervalMs = 5000;  // every 20s — tighter margin for power banks
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
  unsigned long now = millis();
  if (now - lastKeepAliveMs >= keepAliveIntervalMs) {
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