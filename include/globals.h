//Variables Globales
#ifndef globals_h
#define globals_h
#include <Arduino.h>

bool Presented = false;
long pollTime;
int pingFailures;

//Variable del contador
//                           id,pin,unitDesc,desc           ,mV,mF,mode  ,MAXFLOW ,MILLISZEROFLOW, DEBOUNCEMICROSECS, PULSESFORLITER, Diez ceros
struct sCOUNTER Counter =   {30,18 ,"Litros","CONTADOR AGUA",0 ,0 ,RISING,140    ,10000,          1000L,              450,            0,0,0,0,0,0,0,0,0,0};

#ifdef MY_GATEWAY_W5100
    IPAddress pingAddr(192, 168, 100, 60);
    SOCKET pingSocket = 0;
    char buffer[256];
    EthernetICMPPing ping(pingSocket, (uint16_t)random(0, 255));
#endif

#endif
