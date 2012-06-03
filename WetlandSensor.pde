/* -*- c++ -*- 

  Wetland Sensor - reads from AquaTroll sensor, emails data over cell phone
  
  Free Software GPL3+ thanks to ModbusMaster library
  Copyright 2009, 2010 Doc Walker <dfwmountaineers at gmail dot com>
  
*/

#undef WAIT_ON_INPUT

#include <NewSoftSerial.h>
#include "SSerial2Mobile.h"
#include "ModbusMaster.h"

#define RXpin 10 //Green
#define TXpin 11 //Red
#define PHONE_PIN 9

#define PRESSURE_REG 37
#define TEMPERATURE_REG 45

int data_ready = 1; //0

uint32_t zReadRegs(uint16_t addr, uint16_t count);
int send_email(void);

// instantiate ModbusMaster object as serial port 1 slave ID 1
ModbusMaster node(1, 1);
SSerial2Mobile phone = SSerial2Mobile(RXpin, TXpin);

uint32_t temperature;
uint32_t pressure;

int email_sent = 0;
int attempt = 0;

void setup()
{
    pinMode(DE_PIN, OUTPUT);
    pinMode(PHONE_PIN, OUTPUT);
    digitalWrite(PHONE_PIN, LOW);

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
#ifdef WAIT_FOR_INPUT
  // Wait on serial console input to start sensing
  if (attempt <= 1 && !Serial.available()) {
    return;
  }

  while (Serial.available()) {
    Serial.read();
    attempt = 1;
  }

  attempt--;
#endif
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
      send_email();
      email_sent = 1;
  }
}

int send_email(void) {
    digitalWrite(PHONE_PIN, HIGH);
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
    phone.sendTickle();
    Serial.println("Sent tickle");
    Serial.print("Sending email...");
    phone.sendEmail("embeddedlinuxguy@gmail.com", "dO THe Fnord");
    Serial.println(" sent.");
    delay(3000);
    digitalWrite(PHONE_PIN, LOW);
}
