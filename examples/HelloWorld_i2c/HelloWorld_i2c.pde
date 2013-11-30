/*
 Based on the demonstration sketch for Adafruit i2c/SPI LCD backpack
 using MCP23008 I2C expander
 ( http://www.ladyada.net/products/i2cspilcdbackpack/index.html )
 Distributed as an example in the LiquidTWI2 library by Sam C. Lin / http://www.lincomatic.com
 
 More information on this adaptation http://blog.think3dprin3d.com including a circuit
 schematic

 Also uses PinChangeInt library version 2.19
 http://code.google.com/p/arduino-pinchangeint/
 
*/

// include the library code:
#include <Wire.h>
#include <LiquidTWI2.h>
#include <PinChangeInt.h>

uint8_t interruptPin = 30;

 #define LED_3 0x04
 #define LED_2 0x02
 #define LED_1 0x01
 #define LED_OFF 0x00
uint8_t backLightVal = LED_OFF;
// usually the rotary encoders three pins have the ground pin in the middle
uint8_t  clickButton = HIGH;   // click button
uint8_t encoderPos = 0;  // a counter
uint8_t intCap;
uint8_t lastReportedPos = 0;   // change management
uint8_t cursorPos =10; //start in the middle of the screen
volatile boolean rotating=false;     
// Connect via i2c, default address #0 (A0-A2 not jumpered)
LiquidTWI2 lcd(0);

void setup() {
   Serial.begin(115200);
  // set the LCD type
  lcd.setMCPType(LTI_TYPE_MCP23017); 
  // set up the LCD's number of rows and columns:
  lcd.begin(20, 4);
  lcd.setBacklight(backLightVal);
  //setup the button pins as interrupts
  lcd.setRegister(MCP23017_GPINTENA,0x07); //enable interrupts
  lcd.setRegister(MCP23017_DEFVALA,0x07); //set the default values as 1
  lcd.setRegister(MCP23017_INTCONA,0x07); //set to compare with register values set to 1 with DEFVALB
  lcd.setRegister(MCP23017_IOCONA,0x02); //enable active high
  //read the interrupt capture register to reset it
  uint8_t reg = lcd.readRegister(MCP23017_INTCAPA);
  pinMode(interruptPin, INPUT); //set A1 (pin 30) as input
  //attach an interrupt using the pinChangeInt library to interruptPin
  PCintPort::attachInterrupt(interruptPin, &quickInt, RISING); 
}

void loop() {
  // set the cursor to column 0, line 1
  // (note: line 1 is the second row, since counting begins with 0):
  lcd.setCursor(0, 1);
  // print the number of seconds since reset:
  lcd.print(millis()/1000);
 if (rotating){
    handleInterrupt();
  }
  //use the rotary encoder position to move a character on the LCD
  if (lastReportedPos > encoderPos) {
    lcd.clear();
    lcd.setCursor(--cursorPos,2);
    lcd.print("<");
    lastReportedPos = encoderPos;
  }
  if (lastReportedPos < encoderPos) {
    lcd.clear();
    lcd.setCursor(++cursorPos,2);
    lcd.print(">");
    lastReportedPos = encoderPos;
  }
  if (clickButton == LOW )  {
    lcd.buzz(100, 4000);
    encoderPos = 0;
    cursorPos = 10;
    lcd.clear();
    lcd.setCursor(cursorPos,2);
    lcd.print("|");
    clickButton = HIGH;
    switch(backLightVal)
    {
      case LED_3:
        backLightVal = LED_OFF;
      break;
      case LED_OFF:
        backLightVal = LED_1;
      break;
      default:
        backLightVal = (backLightVal <<1);
    }
    lcd.setBacklight(backLightVal);
  }
}

void quickInt()
{
  rotating=true;
}



void handleInterrupt() {
  //reset the flag
  rotating=false;   
  //get the interrupt status of the pins
  //this will clear the flag allowing further interrupts
  intCap=lcd.readRegister(MCP23017_INTCAPA);
  uint8_t test = intCap & 0b00000111;
  /*debug //comment out this line to print debugging output for the masks
  Serial.print("Interrupt Capture: "); Serial.println(intCap,BIN);
  Serial.print("test: "); Serial.println(test,BIN);
  //*/
  if (test == 0b101) encoderPos += 1;
  if (test == 0b110) encoderPos -= 1;
  //if (test == 0b001) encoderPos += 1; //interrupt routine does not work well for situations where buzzer is held down and encoder is turned
  //if (test == 0b010) encoderPos -= 1; //these are not recommended
  
  test &= 0b100;
  if (test == 0b000) clickButton = LOW;
  while(digitalRead(interruptPin) > 0)
  {
     // while interrupts are still occurring clear the register (eg switch bouncing)
      lcd.readRegister(MCP23017_INTCAPA);
      delay (1);
  }
}


