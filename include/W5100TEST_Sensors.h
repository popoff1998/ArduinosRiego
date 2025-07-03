#ifndef W5100TEST_Sensors_h
#define W5100TEST_Sensors_h

//#define HAVE_DALLAS_18B20
//#define HAVE_DHT11
//#define HAVE_PHOTORESISTOR
#define HAVE_INFO
//#define HAVE_COUNTER
//#define HAVE_YL38

#endif
//Variables de actuadores
#define NUMBER_OF_RELAYS 10

struct sRELE Rele[] = {{0, LED_BUILTIN, "LED-EXT", HIGH, LOW, KEEP, 0, 0, true},
                       {1, 22, "RELE1-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {2, 24, "RELE2-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {3, 26, "RELE3-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {4, 28, "RELE4-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {5, 30, "RELE5-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {6, 32, "RELE6-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {7, 34, "RELE7-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {8, 36, "RELE8-EXT", LOW, HIGH, SETOFF, 3600, 0, true},
                       {9, 38, "RESET-EXT", HIGH, LOW, SETOFF, 0, 0, true}};

//Variables de los sensores
int NUMBER_OF_SENSORS = 11;

struct sSENSOR Sensor[] = {{10, A1, 31, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM1-EXT", 0, ENABLED | POWERONREAD},
                           {11, A2, 33, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM2-EXT", 0, ENABLED | POWERONREAD},
                           {12, A3, 35, S_MOISTURE, V_LEVEL, YL38, NONE, "SHUM3-EXT", 0, ENABLED | POWERONREAD},
                           {14, 2, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP1-EXT", 0, ENABLED},
                           {15, 3, NONE, S_TEMP, V_TEMP, DALLAS_18B20, NONE, "TEMP2-EXT", 0, ENABLED},
                           {18, A0, NONE, S_LIGHT_LEVEL, V_LEVEL, S_PHOTORESISTOR, NONE, "LUX1-EXT", 0, ENABLED},
                           {20, 5, NONE, S_HUM, V_HUM, DDHHTT, NONE, "AHUM-EXT", 0, ENABLED},
                           {21, 5, NONE, S_TEMP, V_TEMP, DDHHTT, NONE, "ATEMP-EXT", 0, ENABLED},
                           {22, 0, NONE, S_INFO, V_TEXT, INFO, S_POLL_TIME, "POLLT-EXT", 0, REQUESTABLE},
                           {23, 0, NONE, S_INFO, V_TEXT, INFO, S_MEMORY_FREE, "MFREE-EXT", 0, ENABLED},
                           {24, 0, NONE, S_INFO, V_TEXT, INFO, S_UPTIME, "UPTIME-EXT", 0, ENABLED}};
