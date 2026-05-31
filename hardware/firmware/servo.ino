// Insert servo.ino script here <AGENT DO NOT TOUCH>#include <Servo.h>

Servo barrierServo;

const int servoPin = D5;

int closedPos = 10;
int openPos = 180;
int currentPos = 10;

const unsigned long keepAliveIntervalMs = 25000;
const int keepAliveStep = 1;
const unsigned long keepAlivePulseMs = 120;

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

    int pulseTarget = currentPos + (keepAlivePositive ? keepAliveStep : -keepAliveStep);
    if (pulseTarget > 180) pulseTarget = 180;
    if (pulseTarget < 0) pulseTarget = 0;

    barrierServo.write(pulseTarget);
    delay(keepAlivePulseMs);
    barrierServo.write(currentPos);

    keepAlivePositive = !keepAlivePositive;
  }
}