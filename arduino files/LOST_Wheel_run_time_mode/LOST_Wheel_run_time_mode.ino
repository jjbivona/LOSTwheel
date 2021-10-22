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
//////////////////////////////////////////////////////////////////
//////THIS IS ALL THAT NEEDS TO BE CHANGED////////////////////////
//////////////////////////////////////////////////////////////////
////                                                          ////
double thresholdInMin = .1; //maximum running time (in min)   ////
////                                                          ////
//////////////////////////////////////////////////////////////////


double threshold = thresholdInMin*60; //converting min threshold to seconds


int lockedpos = 120;  //servo position to lock
int openpos = 100; //servo position to unlock
Servo myservo; // servo
int hallsensor = 2; //hall sensor pin

volatile long count; //rotation count

U8X8_SSD1306_128X64_NONAME_SW_I2C u8x8(A5, A4);

enum states
{
  lock,
  unlock,
  relocked
};

byte currentState;

unsigned long currentTime;
unsigned long printTime;
long stopTime;
unsigned long relockedPeriod;
float oldDistance ;
float deltaDistance;
float distance;
unsigned long previousTime = 0;
float runTimeCount;
unsigned long elapsedTime = 0;
unsigned long distanceCopy;
void setup()
{
  Serial.begin(9600);
  while (!Serial);
  currentState = lock;

  count = 0;

  u8x8.begin();
  u8x8.setFlipMode(1);
  u8x8.setFont(u8x8_font_amstrad_cpc_extended_r);
  u8x8.setInverseFont(1);
  u8x8.setCursor(1, 0);
  u8x8.print("current status");

  u8x8.setCursor(1, 3);
  u8x8.print("distance (m)");
  u8x8.setCursor(1, 6);
  u8x8.print("time (min)");
  u8x8.setInverseFont(0);
  u8x8.setCursor(1, 1);
  u8x8.print("locked");

  attachInterrupt(digitalPinToInterrupt(hallsensor), sensor, FALLING); //attach interrupt
  pinMode(hallsensor, INPUT); //setup hall sensor
  myservo.attach(9); //setup pin for servo
  myservo.write(lockedpos); //default state is locked

}

void loop()
{
 
  currentTime = millis();
  switch (currentState)
  {
    case lock:
      if (runTimeCount < threshold)
      {
        myservo.write(openpos); //open servo when condition reached


        currentState = unlock;
        u8x8.setCursor(1, 1);
        u8x8.print("unlocked"); //update screen
stopTime = currentTime/1000/60;
        break;
      }
    case unlock:
      if (runTimeCount >= threshold)
      {
        myservo.write(lockedpos); //relocking the wheel


        currentState = relocked;
        u8x8.clearLine(1);
        u8x8.setCursor(1, 1);
        u8x8.print("locked AT ");
        u8x8.print(stopTime);//update screen
       
        break;
      }

  }

  unsigned long serialTime = millis();
  screen();
  
distance = (count * .054 * 2 * 3.14 / 2);
elapsedTime = serialTime - previousTime;
deltaDistance = distance - oldDistance;
//print over serial port once per second 

  if (elapsedTime >= 1000) { //communicating with serial port for logger app
   Serial.print(float(millis() / 1000.0));
   Serial.print(" , ");
   Serial.print(count * .054 * 2 * 3.14 / 2);
   Serial.println("\n");

    oldDistance = distance;
    previousTime = serialTime;
    if (deltaDistance >= 0.3){ //taking advantage of 1 second intervals to calculate a velocity. threshold = 0.3 m/s
      runTimeCount++;
      
      
      
    }

  }


}

   


void sensor () { //interrupt to measure rotations
  count++; //every time hall effect sensor goes off, add 1 to count

}
void screen () { //function to update screen and serial monitor

  noInterrupts();
  long countCopy = count;  //make a copy of count with interrupts turned off
  interrupts();
  printTime = millis() / 1000 / 60 ; //time in minutes since power on



  u8x8.setCursor(1, 4);
  u8x8.print(countCopy * .054 * 2 * 3.14 / 2); //distance in meters (2 * pi * r)/2 magnets



  u8x8.setCursor(1, 7);
  u8x8.print(printTime); //printing time

}
