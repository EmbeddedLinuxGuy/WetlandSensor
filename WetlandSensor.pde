extern int GLOBAL_TIMEOUT;
/* -*- c++ -*- 

  Wetland Sensor - reads from AquaTroll sensor, emails data over cell phone
  
  Free Software GPL3+ thanks to ModbusMaster library
  Copyright 2009, 2010 Doc Walker <dfwmountaineers at gmail dot com>
  
*/
#undef WAIT_FOR_USER // define if there is a console connected
int data_ready = 0; // set to 1 if there is no sensor
int test = 1; // don't really send email

#include "GSMSerial.h"
#define CONTACT "121"
#define RXpin 10 //Green
#define TXpin 11 //Red
#define PHONE_PIN 9

GSMSerial phone(RXpin, TXpin); //(RX) green, (TX) red

#define PRESSURE_REG 37
#define TEMPERATURE_REG 45
#define LEVEL_REG 53
#define SALINITY_REG 77

#include <SoftwareSerial.h>
#include "ModbusMaster.h"
#include "LowPower.h"

uint32_t zReadRegs(uint16_t addr, uint16_t count);
int send_email(void);

// instantiate ModbusMaster object as serial port 0 slave ID 1, 1000ms timeout
ModbusMaster node(0, 1, 1000);

// rx, tx
SoftwareSerial console(3, 2);

uint8_t result; // last Modbus result code
int email_sent = 0; // bool true if email has been sent
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
    pinMode(DE_PIN, OUTPUT);

    pinMode(PHONE_PIN, OUTPUT);
    digitalWrite(PHONE_PIN, LOW);

    // initialize Modbus
    node.begin(sensor_baud_rate);

    // Set Serial 0 (Node) to 8E1
    UCSR0C |= _8e1_or;
    UCSR0C &= _8e1_and;

    console.begin(debug_baud_rate);
    console.println("Press ENTER to start reading data.");
    attempt = 0;
}

void loop()
{
  static uint32_t i;
  uint8_t j, result;
  uint16_t data[6];

#ifdef WAIT_FOR_USER
  // Wait on serial console input to start sensing
  if (attempt <= 1 && !console.available()) {
    return;
  }

  while (console.available()) {
    console.read();
    attempt = 1;
  }

  attempt--;
#endif // WAIT_FOR_USER

  if (!data_ready) {
      console.write("Initial register read: ");
      
      zReadRegs(0, 1);
      console.write("Level: ");
      level = zReadRegs(LEVEL_REG, 8);
      console.write("Pressure: ");
      pressure = zReadRegs(PRESSURE_REG, 8);
      console.write("Salinity: ");
      salinity = zReadRegs(SALINITY_REG, 8);
      // XXX substitute invalid floating point value for 0xdeadbeef
      if (salinity != 0xdeadbeef && pressure != 0xdeadbeef && level != 0xdeadbeef) {
	  data_ready = 1;
	  console.print("Got data!\r\n");
      } else {
	  console.print("Did not get valid data.\r\n");
      }
  }
  if (!email_sent && data_ready) {
      send_email();
      email_sent = 1;
  }

    console.write("Sleeping\r\n\r");
    LowPower.powerDown(SLEEP_8S, ADC_OFF, BOD_OFF);
}

int send_email(void) {
    digitalWrite(PHONE_PIN, HIGH);
    if(test){console.print("Testing phone (will not send email)\r\n");}
    console.println("Please wait 5 seconds for the phone to power on:\n");
    for (int i=5; i > 0; --i) {
	console.print(i); console.print(' ');
	delay(1000);
    }
    console.println("\nPlease wait 60 seconds for phone to find signal:\n");
    if(!test){phone.start();}
    if(!test){phone.reset();}

    for (int i=60; i > 0; --i) {
	console.print(i); console.print(' ');
	delay(1000);
    }

    if (! test) {
        console.println("Sending");
	phone.sendTxt(CONTACT, "embeddedlinuxguy@gmail.com Salinity, uv89czxo");
    } else {
	console.println("Test mode, not sending");
    }
    console.println("Done");

    return 0;

    //    double *fsal = &salinity;
    //    double *fpre = &pressure;
    //    double *flev = &level;
    
    if (0) {
            phone.openTxt(CONTACT);
            phone.inTxt("embeddedlinuxguy@gmail.com Salinity = ");
	    phone.inTxt(0.23);
	    //	    phone.inTxt(*fsal);
	    phone.inTxt(", Pressure = ");
	    phone.inTxt(1.44);
	    //	    phone.inTxt(*fpre);
	    phone.inTxt(", Level = ");
	    phone.inTxt(6.66);
	    //	    phone.inTxt(*flev);
	                phone.closeTxt();
    }
    //    phone.sendTxt(CONTACT, "embeddedlinuxguy@gmail.com Placeholder for data");

    unsigned long *sval = (unsigned long *)&salinity;
    unsigned long *pval = (unsigned long *)&pressure;
    unsigned long *lval = (unsigned long *)&level;

    unsigned long mask = 0x0000003f;
    char msg[7];
    for (int i = 0; i < 6; ++i) {
	msg[i] = ' ' + (char)(mask & (*sval >> 6*i));
    }
    msg[6] = 0;

    console.println(msg);
    console.println(" sent. Waiting 15 seconds for phone to finish.");
    for (int i = 0; i < 15; ++i) {
	console.println(i);
	delay(1000);
    }

    digitalWrite(PHONE_PIN, LOW);
}

uint32_t zReadRegs(uint16_t addr, uint16_t count) {
    uint8_t j;
  uint16_t data[6];
  uint32_t value = 0;

  //  delay(1000);
  result = node.readHoldingRegisters(addr, count);
  if (result == node.ku8MBSuccess) {
    console.write("data: {");
    for (j = 0; j < count; j++) {
      data[j] = node.getResponseBuffer(j);
      console.write('[');
      console.print(data[j], DEC);
      console.write(']');
    }
    console.write("}\r\n");
    value |= data[0];
    value <<= 16;
    value |= data[1];
  } else {
    console.write("error: ");
    switch(result) {
      case 0xE2: console.write("Response Timed Out"); break;
      case 0xE0: console.write("Invalid Slave ID"); break;
      default: console.print(result, DEC);
      }
    console.write("\r\n");
    value = 0xdeadbeef;
  }
  return value;
}
