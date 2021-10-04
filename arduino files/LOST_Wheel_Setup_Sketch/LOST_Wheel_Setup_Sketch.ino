#include <Servo.h>
#include <Arduino.h>
#include <U8g2lib.h>
#include <U8x8lib.h>
#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif


int lockedpos = 120;  //servo position to lock
int openpos = 100; //servo position to unlock
Servo myservo; // servo
int hallsensor = 2; //hall sensor pin

volatile long count; //rotation count

U8X8_SSD1306_128X64_NONAME_SW_I2C u8x8(A5, A4);


bool lock = true;

unsigned long previousMillis = 0;


void setup() {
  // put your setup code here, to run once:

  count = 0;

  u8x8.begin();
  u8x8.setFlipMode(1);
  u8x8.setFont(u8x8_font_amstrad_cpc_extended_r);
  u8x8.setInverseFont(1);
  u8x8.setCursor(1, 0);
  u8x8.print("setup sketch");

  u8x8.setCursor(1, 3);
  u8x8.print("sensor count");


  attachInterrupt(digitalPinToInterrupt(hallsensor), sensor, FALLING); //attach interrupt
  pinMode(hallsensor, INPUT); //setup hall sensor
  myservo.attach(9); //setup pin for servo
  myservo.write(lockedpos); //default state is locked

  u8x8.setCursor(1, 5);
  u8x8.print("lock");




}

void loop() {

  unsigned long currentMillis = millis();

  screen();

  if (currentMillis - previousMillis >= 10000) {
    // save the last time you blinked the LED
    previousMillis = currentMillis;


    if (myservo.read() == lockedpos) {
      myservo.write(openpos);
      u8x8.setCursor(1, 5);
      u8x8.print("open");
    } else {
      myservo.write(lockedpos);
      u8x8.setCursor(1, 5);
      u8x8.print("lock");
    }
  }
}

void sensor () { //interrupt to measure rotations
  count++;
}

void screen () { //function to update screen and serial monitor

  noInterrupts();
  long count_copy = count;  //make a copy of count with interrupts turned off
  interrupts();


  u8x8.setCursor(1, 4);
  u8x8.print(count_copy);


}
