//Fichero de include comun a USB y W5100
#ifndef Riego_h
#define Riego_h
#include "platform.h"
#include <Arduino.h>
#include <Time.h>

#ifdef W5100GATEWAY
  #include "W5100_Sensors.h"
#endif

#ifdef W5100TEST
  #include "W5100TEST_Sensors.h"
#endif

#ifdef USBGATEWAY
  #include "USB_Sensors.h"
#endif

#include "MyMessage.h"

//Globales para los diferentes tipos de sensores. Mirar mas adelante para ver si soporta varios
//Defines y estructura para flags
enum {
  ENABLED = 0x01,
  REQUESTABLE = 0x02,
  POWERONREAD = 0x04,
};

typedef union
{
  uint8_t all_flags;
  struct
  {
    uint8_t enabled :     1,
            requestable : 1,
            poweronread : 1,
            spare4 :      1,
            spare3 :      1,
            spare2 :      1,
            spare1 :      1,
            spare0 :      1;
  };
} S_FLAGS;

//Estructura de reles
struct sRELE {
  int id;
  int  pin;
  char desc[50];
  bool ON;
  bool OFF;
  int initState;
  int MaxTime;
  unsigned long EndMillis;
  bool enabled;
};

struct sSENSOR {
  int id;
  int pin;
  int auxPin;
  int MSpresentType;
  int MSmessageType;
  int HWtype;
  int HWsubtype;
  char desc[50];
  MyMessage *msg;
  S_FLAGS flags;
};

struct sCOUNTER {
  int id;
  int pin;
  char unitDesc[20];
  char desc[50];
  MyMessage *msgVolume;
  MyMessage *msgFlow;
  int mode;
            unsigned  long        MAXFLOW;
            unsigned  long        MILLISZEROFLOW;
            unsigned  long        DEBOUNCEMICROSECS;
                      long        PULSESFORLITER;
  volatile  unsigned  long        lastBlink;
  volatile  unsigned  long        newBlink;
                      double      volume;
                      double      oldVolume;
  volatile            double      flow;
                      double      oldFlow;
            unsigned  long        lastSend;
            unsigned  long        lastPulse;
  volatile  unsigned  long        pulseCount;
            unsigned  long        oldPulseCount;
};

//Defines varios
#define NOTFOUND 255

//Definicion de initStates
#define SETOFF  0
#define SETON   1
#define KEEP    2

//defines de comportamiento
#define POLL_TIME 15000 //msec para chequear los sensores

//ID de childs para conseguir informacion del controller
#define CHILD_ID_POLL_TIME 64

// VALORES DE CONFIGURACION
  //Tiempo de espera para alimentar sensores (en microsegundos)
  #define POWERDELAY 10000
  #define MOISTURE_MINSENSOR 300
  #define MOISTURE_MAXCB     200
  #define MAXTIMEFACTOR      1 //1 si ponemos el tiempo en segundos, 60 en minutos
  #define MAXPINGFAILURES    2 //Maximo de fallos antes de resetear el arduino
  #define RESETPIN          38//Pseudopin para el pseudo switch de reset

//Defines de tipos HWtype
#define DALLAS_18B20  0
#define DDHHTT        1
#define S_PHOTORESISTOR 3
#define INFO 4
#define S_ARDUINO_TEMP 5
#define YL38 6

//Defines de tios HWsubtype
#define NONE 0
#define S_POLL_TIME 1
#define S_MEMORY_FREE 2
#define S_UPTIME 3

//Opciones de depuracion
//#define MY_DEBUG
#define EXTRADEBUG
#define DEBUG
//#define VERBOSE
//#define COUNTERDEBUG
//#define COUNTEREXTRADEBUG
//#define TRACE

//Funciones
void setup_sensor_DHT11(sSENSOR);
void setup_sensor_INFO(sSENSOR);
void setup_sensor_YL38(sSENSOR);

void process_sensor_DHT11(sSENSOR);
void process_sensor_18B20(sSENSOR);
void process_sensor_PHOTORESISTOR(sSENSOR);
void process_sensor_INFO(sSENSOR);
void process_sensor_arduino_temp(sSENSOR);
void process_sensor_YL38(sSENSOR);


void receive_sensor_INFO(MyMessage);

void setup_counter();
void process_counter();

#endif
