#ifndef W5100TEST_h
#define W5100TEST_h
//Defines de configuracion
#define MY_NODE_ID 5
#define SKETCH_NAME "Gateway Ethernet"
#define SKETCH_VERSION "1.0"

//Defines del gateway
#define MY_GATEWAY_W5100
#define MY_IP_ADDRESS 192,168,100,61   // If this is disabled, DHCP is used to retrieve address
#define MY_PORT 5003
#define MY_MAC_ADDRESS 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xEC

//#define MY_INCLUSION_MODE_FEATURE
//#define MY_INCLUSION_BUTTON_FEATURE
//#define MY_INCLUSION_MODE_DURATION 60
//#define MY_INCLUSION_MODE_BUTTON_PIN  3

#include "Riego.h"

//Variables de actuadores
#define NUMBER_OF_RELAYS 9

struct sRELE Rele [] = {  {0, LED_BUILTIN , "LED-EXT", HIGH, LOW, KEEP, 3600, 0, true},
                          {1, 22 , "RELE1-EXT", LOW, HIGH, SETOFF, 20, 0, true},
                          {2, 24 , "RELE2-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {3, 26 , "RELE3-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {4, 28 , "RELE4-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {5, 30 , "RELE5-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {6, 32 , "RELE6-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {7, 34 , "RELE7-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                          {8, 36 , "RELE8-EXT", LOW, HIGH, SETOFF, 3600, 0, true}
                       };

//Variables de los sensores
int NUMBER_OF_SENSORS=10;

struct sSENSOR Sensor [] = {  {10, A1, 31, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM1-EXT", 0, ENABLED | POWERONREAD},
                              {11, A2, 33, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM2-EXT", 0, ENABLED | POWERONREAD},
                              {12, A3, 35, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM3-EXT", 0, ENABLED | POWERONREAD},
                              {14, 2, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP1-EXT", 0, ENABLED},
                              {15, 3, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP2-EXT", 0, ENABLED},
                              {18, A0, NONE, S_LIGHT_LEVEL, V_LEVEL, S_PHOTORESISTOR, NONE, "LUX1-EXT", 0, ENABLED},
                              {20, 5, NONE, S_HUM, V_HUM, DDHHTT, NONE, "AHUM-EXT", 0, ENABLED},
                              {21, 5, NONE, S_TEMP, V_TEMP, DDHHTT, NONE, "ATEMP-EXT", 0, ENABLED},
                              {22, 0, NONE, S_INFO, V_TEXT, INFO, S_POLL_TIME, "POLLT-EXT", 0, ENABLED | REQUESTABLE},
                              {23, 0, NONE, S_INFO, V_TEXT, INFO, S_MEMORY_FREE, "MFREE-EXT", 0, ENABLED}
                           };


//Includes especificos de la plataforma
#include <Ethernet.h>

#endif

