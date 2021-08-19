//Opciones de depuracion
//#define MY_DEBUG
#define EXTRADEBUG
#define DEBUG
//#define VERBOSE
//#define COUNTERDEBUG
//#define COUNTEREXTRADEBUG
//#define TRACE

//Defines varios
#define NOTFOUND 255

//Definicion de initStates
#define SETOFF 0
#define SETON 1
#define KEEP 2

//defines de comportamiento
#define POLL_TIME 15000 //msec para chequear los sensores

//ID de childs para conseguir informacion del controller
#define CHILD_ID_POLL_TIME 64

// VALORES DE CONFIGURACION
//Tiempo de espera para alimentar sensores (en microsegundos)
#define POWERDELAY 10000
#define MOISTURE_MINSENSOR 300
#define MOISTURE_MAXCB 200
#define MAXTIMEFACTOR 1    //1 si ponemos el tiempo en segundos, 60 en minutos
#define MAXPINGFAILURES 10 //Maximo de fallos antes de resetear el arduino
#define RESETPIN 38        //Pseudopin para el pseudo switch de reset

//Defines de tipos HWtype
#define DALLAS_18B20 0
#define DDHHTT 1
#define S_PHOTORESISTOR 3
#define INFO 4
#define S_ARDUINO_TEMP 5
#define YL38 6

//Defines de tios HWsubtype
#define NONE 0
#define S_POLL_TIME 1
#define S_MEMORY_FREE 2
#define S_UPTIME 3

