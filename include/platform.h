#ifndef platform_h
#define platform_h
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

#ifdef W5100TEST
    #define MY_GATEWAY_W5100
    #include "W5100TEST.h"
#endif

