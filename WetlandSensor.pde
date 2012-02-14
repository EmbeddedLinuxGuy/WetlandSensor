/* -*- c++ -*- 

  Wetland Sensor - reads from AquaTroll sensor, emails data over cell phone
  
  Free Software GPL3+ thanks to ModbusMaster library
  Copyright 2009, 2010 Doc Walker <dfwmountaineers at gmail dot com>
  
*/

#include <NewSoftSerial.h>
#include "SSerial2Mobile.h"
#include "ModbusMaster.h"

uint32_t zReadRegs(uint16_t addr, uint16_t count);
#define RXpin 10 //Green
#define TXpin 11 //Red

// instantiate ModbusMaster object as serial port 1 slave ID 1
ModbusMaster node(1, 1);

int email_sent = 0;
int attempt = 0;

int send_email(void);
int send_email2(void);

int data_ready = 1; //0
uint32_t temperature;
uint32_t pressure;

#define PRESSURE_REG 45
#define TEMPERATURE_REG 37

void setup()
{
    pinMode(DE_PIN, OUTPUT);

  // initialize Modbus communication baud rate
  node.begin(19200);

  //UCSR0C = UCSR0C | B00100000;
//UCSR0C = UCSR0C & B11101111;

  // Set Serial 1 (Node) to 8E1
  //http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1243894373/all
  UCSR1C |= B00100000;
  UCSR1C &= B11101111;

  //  Serial1.begin(19200);
  Serial.begin(19200);
  Serial.println("Press ENTER to start reading data.");
  attempt = 0;
}


uint32_t zReadRegs(uint16_t addr, uint16_t count) {
  uint8_t j, result;
  uint16_t data[6];
  uint32_t value = 0;

  delay(1000);
  result = node.readHoldingRegisters(addr, count);
  if (result == node.ku8MBSuccess) {
    Serial.write("data: {");
    for (j = 0; j < count; j++) {
      data[j] = node.getResponseBuffer(j);
      Serial.write('[');
      Serial.print(data[j], DEC);
      Serial.write(']');
    }
    Serial.write("}\n");
    value |= data[0];
    value <<= 16;
    value |= data[1];
  } else {
    Serial.write("error: ");
    switch(result) {
      case 0xE2: Serial.write("Response Timed Out"); break;
      case 0xE0: Serial.write("Invalid Slave ID"); break;
      default: Serial.print(result, DEC);
      }
    Serial.write("\n");
    value = 0xdeadbeef;
  }
  return value;
}

void loop()
{
  static uint32_t i;
  uint8_t j, result;
  uint16_t data[6];

  // Wait on serial console input to start sensing
  if (attempt <= 1 && !Serial.available()) {
    return;
  }

  while (Serial.available()) {
    Serial.read();
    attempt = 1;
  }

  attempt--;

  if (!data_ready) {
      Serial.write("Initial register read: ");
      zReadRegs(0, 1);
      Serial.write("Temperature: ");
      temperature = zReadRegs(TEMPERATURE_REG, 8);
      Serial.write("Pressure: ");
      pressure = zReadRegs(PRESSURE_REG, 8);
      if (temperature != 0xdeadbeef && pressure != 0xdeadbeef) {
	  data_ready = 1;
      }
  }
  if (!email_sent && data_ready) {
      send_email2();
      email_sent = 1;
  }
}

int send_email(void) {
    SSerial2Mobile phone = SSerial2Mobile(RXpin, TXpin);
    Serial.println("About to send email: please wait 60 seconds.");
    delay(3000);
    phone.on();
    delay(57000);
    Serial.print("Sending...");
    phone.sendEmail("embeddedlinuxguy@gmail.com", "HEY WATSON! EMAIL IS CRAZY! I NEED YOU!!");
    Serial.println(" sent.");
    return 0;
}

int send_email2(void) {
    SSerial2Mobile phone = SSerial2Mobile(RXpin, TXpin);
    phone.begin();
    phone.on();
    //  returnVal=phone.isOK();
    // Serial.println(returnVal, DEC);
    Serial.println("Please wait 60 seconds for the phone to turn on");
    delay(60000);

    Serial.print("Batt: ");
    Serial.print(phone.batt());
    Serial.println("%");
    
    Serial.print("RSSI: ");
    Serial.println(phone.rssi());
  // Any RSSI over >=5 should be fine for SMS
  // SMS:  5
  // voice:  10
  // data:  20
  
  
    delay(1000);
    //  Serial.println("Sending Text");
    //  phone.sendTxt("+14153122169","To what doth it do???");
    //  phone.sendTxt("+14153597320","To what doth it do???");
    
    phone.sendTickle();
    Serial.println("Sent tickle");
    //  delay(60000);

    // phone.sendTxtMode();
    //Serial.println("Sent text mode command");
    //phone.sendTxtNumber("+14153597320");
    //Serial.println("Sent number");
    //phone.sendTxtMsg("To what doth it do???");
    //Serial.println("Sent message");

    Serial.print("Sending email...");
    phone.sendEmail("embeddedlinuxguy@gmail.com", "dO THe Fnord");
    Serial.println(" sent.");
}
