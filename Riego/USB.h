#ifndef USB_h
#define USB_h
//Defines de configuracion
#define MY_NODE_ID 4
#define SKETCH_NAME "Gateway Usb"
#define SKETCH_VERSION "1.0"

//Defines del gateway
#define MY_GATEWAY_SERIAL

#include "Riego.h"

//Variables de actuadores
#define NUMBER_OF_RELAYS 9

struct sRELE Rele [] = {  {0, LED_BUILTIN , "LED-INT", HIGH, LOW, KEEP, true},
                          {1, 36 , "RELE1-INT", LOW, HIGH, SETOFF, true},
                          {2, 34 , "RELE2-INT", LOW, HIGH, SETOFF, true},
                          {3, 32 , "RELE3-INT", LOW, HIGH, SETOFF, true},
                          {4, 30 , "RELE4-INT", LOW, HIGH, SETOFF, true},
                          {5, 28 , "RELE5-INT", LOW, HIGH, SETOFF, true},
                          {6, 26 , "RELE6-INT", LOW, HIGH, SETOFF, true},
                          {7, 24 , "RELE7-INT", LOW, HIGH, SETOFF, true},
                          {8, 22 , "RELE8-INT", LOW, HIGH, SETOFF, true}
                       };

//Variables de los sensores
int NUMBER_OF_SENSORS=10;

struct sSENSOR Sensor [] = {  {10, A1, 31, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM1-INT", 0, ENABLED | POWERONREAD},
                              {11, A2, 33, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM2-INT", 0, ENABLED | POWERONREAD},
                              {12, A3, 35, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM3-INT", 0, ENABLED | POWERONREAD},
                              {14, 2, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP1-INT", 0, ENABLED},
                              {15, 3, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP2-INT", 0, ENABLED},
                              {18, A0, NONE, S_LIGHT_LEVEL, V_LEVEL, S_PHOTORESISTOR, NONE, "LUX1-INT", 0, ENABLED},
                              {20, 5, NONE, S_HUM, V_HUM, DDHHTT, NONE, "AHUM-INT", 0, ENABLED},
                              {21, 5, NONE, S_TEMP, V_TEMP, DDHHTT, NONE, "ATEMP-INT", 0, ENABLED},
                              {22, 0, NONE, S_INFO, V_TEXT, INFO, S_POLL_TIME, "POLLT-INT", 0, ENABLED | REQUESTABLE},
                              {23, 0, NONE, S_INFO, V_TEXT, INFO, S_MEMORY_FREE, "MFREE-INT", 0, ENABLED}
                           };

#endif

                  
