//Fichero de include comun a USB y W5100
#ifndef Riego_h
#define Riego_h

#include <Arduino.h>
#include <Time.h>

//Globales para los diferentes tipos de sensores. Mirar mas adelante para ver si soporta varios
//Defines y estructura para flags

//Funciones
void setup_sensor_DHT11(sSENSOR);
void setup_sensor_INFO(sSENSOR);
void setup_sensor_YL38(sSENSOR);
void setup_sensor_PRESS_SENSOR(sSENSOR);

void process_sensor_DHT11(sSENSOR);
void process_sensor_18B20(sSENSOR);
void process_sensor_PHOTORESISTOR(sSENSOR);
void process_sensor_INFO(sSENSOR);
void process_sensor_arduino_temp(sSENSOR);
void process_sensor_YL38(sSENSOR);
void process_sensor_PRESS_SENSOR(sSENSOR);


void receive_sensor_INFO(MyMessage);

void setup_counter();
void process_counter();

#endif
