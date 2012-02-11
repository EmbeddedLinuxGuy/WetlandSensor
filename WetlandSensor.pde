/*

  Wetland Sensor - reads from AquaTroll sensor, emails data over cell phone
  
  Free Software GPL3+ thanks to ModbusMaster library
  Copyright 2009, 2010 Doc Walker <dfwmountaineers at gmail dot com>
  
*/

uint8_t zReadRegs(uint16_t addr, uint16_t count);

#include "ModbusMaster.h"

// instantiate ModbusMaster object as serial port 1 slave ID 1
ModbusMaster node(1, 1);

int attempt = 0;


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
  attempt = 0;
}


uint8_t zReadRegs(uint16_t addr, uint16_t count) {
  uint8_t j, result;
  uint16_t data[6];
  
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
  } else {
    Serial.write("error: ");
    switch(result) {
      case 0xE2: Serial.write("Response Timed Out"); break;
      case 0xE0: Serial.write("Invalid Slave ID"); break;
      default: Serial.print(result, DEC);
      }
    Serial.write("\n");
  }
  return result;
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
    attempt = 5;
  }

  attempt--;

  Serial.write("Initial register read: ");
  zReadRegs(0, 1);
   Serial.write("Temperature: ");
   zReadRegs(37, 8);
   Serial.write("Pressure: ");
   zReadRegs(45, 8);

#if 0
  Serial.write("ID: ");
  zReadRegs(1, 1);
  Serial.write("Serial No.: ");
  zReadRegs(2, 2);
  Serial.write("Status: ");
  zReadRegs(4, 1);
  Serial.write("Last calibration: ");
  zReadRegs(5, 3);
  Serial.write("Next calibration: ");
  zReadRegs(8, 3);
#endif
}
