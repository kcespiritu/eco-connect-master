// Insert servo.ino script here <AGENT DO NOT TOUCH>#include <Servo.h>

Servo barrierServo;

const int servoPin = D5;

int closedPos = 10;
int openPos = 180;
int currentPos = 10;

void setup() {

  Serial.begin(115200);

  barrierServo.attach(servoPin);

  // start CLOSED immediately
  barrierServo.write(closedPos);
  currentPos = closedPos;

  Serial.println("Ready: o=open, c=close, +/-, s=status");
}

void loop() {

  if (!Serial.available()) return;

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