#ifndef platform_h
#define platform_h
//Seleccionar la plataform W5100 o USB o TEST
#define W5100GATEWAY
//#define W5100TEST
//#define USBGATEWAY
#endif

//Para que mysensors sepa como comportarse
#ifdef W5100GATEWAY
    #define MY_GATEWAY_W5100
    #include "W5100.h"
#endif

#ifdef USBGATEWAY
    #define MY_GATEWAY_SERIAL
    #include "USB.h"
#endif
