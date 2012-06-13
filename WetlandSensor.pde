/* -*- c++ -*- 

  Wetland Sensor - reads from AquaTroll sensor, emails data over cell phone
  
  Free Software GPL3+ thanks to ModbusMaster library
  Copyright 2009, 2010 Doc Walker <dfwmountaineers at gmail dot com>
  
*/

#undef WAIT_FOR_USER // define if there is a console connected
int data_ready = 0; // set to 1 if there is no sensor

#define RXpin 10 //Green
#define TXpin 11 //Red
#define PHONE_PIN 9

#define PRESSURE_REG 37
#define TEMPERATURE_REG 45
#define LEVEL_REG 53
#define SALINITY_REG 77

#include <NewSoftSerial.h>
#include "SSerial2Mobile.h"
#include "ModbusMaster.h"

uint32_t zReadRegs(uint16_t addr, uint16_t count);
int send_email(void);

// instantiate ModbusMaster object as serial port 1 slave ID 1
ModbusMaster node(1, 1);

int email_sent = 0;
int attempt = 0;

//uint32_t temperature;
uint32_t pressure;
uint32_t salinity;
uint32_t level;

//http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1243894373/all
#define _8e1_or  B00100000
#define _8e1_and B11101111
#define sensor_baud_rate 19200
#define debug_baud_rate 19200

void setup()
{
    pinMode(TXpin, INPUT); // high impedance
    pinMode(RXpin, INPUT);

    pinMode(DE_PIN, OUTPUT);

    pinMode(PHONE_PIN, OUTPUT);
    digitalWrite(PHONE_PIN, LOW);

    // initialize Modbus
    node.begin(sensor_baud_rate);

    // Set Serial 1 (Node) to 8E1 (Serial 0 == UCSR0C)
    UCSR1C |= _8e1_or;
    UCSR1C &= _8e1_and;

    Serial.begin(debug_baud_rate);
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

#ifdef WAIT_FOR_USER
  // Wait on serial console input to start sensing
  if (attempt <= 1 && !Serial.available()) {
    return;
  }

  while (Serial.available()) {
    Serial.read();
    attempt = 1;
  }

  attempt--;
#endif // WAIT_FOR_USER

  if (!data_ready) {
      Serial.write("Initial register read: ");
      zReadRegs(0, 1);
      Serial.write("Salinity: ");
      salinity = zReadRegs(SALINITY_REG, 8);
      Serial.write("Level: ");
      level = zReadRegs(LEVEL_REG, 8);
      Serial.write("Pressure: ");
      pressure = zReadRegs(PRESSURE_REG, 8);
      // XXX substitute invalid floating point value for 0xdeadbeef
      if (salinity != 0xdeadbeef && pressure != 0xdeadbeef && pressure != 0xdeadbeef) {
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
    SSerial2Mobile phone = SSerial2Mobile(RXpin, TXpin);

    Serial.println("Please wait 5 seconds for the phone to power up");
    //    delay(30000);
    delay(5000);
    Serial.println("Initializing serial port / Soft Reset and waiting 30 seconds");
    phone.begin();
    phone.on();
    delay(30000);

    //    Serial.println("Please wait 60 seconds for the phone to turn on");
    //    delay(1000);
    //  returnVal=phone.isOK();
    // Serial.println(returnVal, DEC);
    //    Serial.println("Please wait 60 seconds for the phone to get ready");
    //    delay(1000);

    phone.sendTickle();
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
    /*
     phone.sendTxtMode();
    Serial.println("Sent text mode command");
    phone.sendTxtNumber("+14153597320");
    Serial.println("Sent number");
    phone.sendTxtMsg("To what doth it do???");
    Serial.println("Sent message");
    */
    Serial.print("About to send email...");

    unsigned long *sval = (unsigned long *)&salinity;
    unsigned long *pval = (unsigned long *)&pressure;
    unsigned long *lval = (unsigned long *)&level;

    unsigned long mask = 0x0000003f;
    char msg[7];
    for (int i = 0; i < 6; ++i) {
	msg[i] = ' ' + (char)(mask & (*sval >> 6*i));
    }
    msg[6] = 0;
 
   
    phone.sendEmail("embeddedlinuxguy@gmail.com", "FNORD HELLO HELLO");
    Serial.println(" sent. Waiting 15 seconds for phone to finish.");

    for (int i = 0; i < 15; ++i) {
	Serial.println(i);
	delay(1000);
    }


    // Normally NewSoftSerial manages these two pins, but we want to
    // keep TXpin in high impedance when it's not needed. The
    // destructor of NewSoftSerial is called after this, but it
    // doesn't monkey with TXpin (although it will clear a bit on
    // RXpin)

    pinMode(TXpin, INPUT); // high impedance
    pinMode(RXpin, INPUT);

    digitalWrite(PHONE_PIN, LOW);
}
