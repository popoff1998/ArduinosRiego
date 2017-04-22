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
#endif
