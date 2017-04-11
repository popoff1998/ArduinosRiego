//Debemos procesar independientemente el de humedad y temperatura
#include "platform.h"
#include "Riego.h"
#include "externs.h"

#ifdef W5100GATEWAY
  #include "W5100_Sensors.h"
#else
  #include "USB_Sensors.h"
#endif

#include <core/MySensorsCore.h>
#include "MemoryFree.h"

//Defines de parametros de sensores
#define LDR_VCC 360
#define LDR_LUX 320

//Funciones Utilitarias

  //Devuelve el elemento de la estructura de sensores a partir del id
int getSensorIdxFromId(int id)
{
  for(int i=0; i<NUMBER_OF_SENSORS;i++) {
    if(Sensor[i].id == id) return i;
  }
  return NOTFOUND;
}

//Temperatura arduino
double GetArduinoTemp(void)
{
  unsigned int wADC;
  double t;

  // The internal temperature has to be used
  // with the internal reference of 1.1V.
  // Channel 8 can not be selected with
  // the analogRead function yet.
  // Set the internal reference and mux.
  ADMUX = (_BV(REFS1) | _BV(REFS0) | _BV(MUX3));
  ADCSRA |= _BV(ADEN);  // enable the ADC
  delay(20);            // wait for voltages to become stable.
  ADCSRA |= _BV(ADSC);  // Start the ADC
  // Detect end-of-conversion
  while (bit_is_set(ADCSRA,ADSC));
  // Reading register "ADCW" takes care of how to read ADCL and ADCH.
  wADC = ADCW;
  // The offset of 324.31 could be wrong. It is just an indication.
  t = (wADC - 337.0 ) / 1.22;
  // The returned temperature is in degrees Celsius.
  return (t);
}

void process_sensor_arduino_temp(sSENSOR _Sensor)
{

  double temperatura = GetArduinoTemp();
  #ifdef DEBUG
    Serial.print("Temperatura Arduino: "); Serial.print(temperatura); Serial.println(" grados");
  #endif
  send(_Sensor.msg->set(temperatura,1));
}


//Para pseudo sensores tio INFO
#ifdef HAVE_INFO
void process_sensor_INFO(sSENSOR _Sensor)
{
  switch(_Sensor.HWsubtype) {
    case S_POLL_TIME:
      #ifdef DEBUG
        Serial.print("---> ");Serial.print(_Sensor.desc); Serial.print(": ");Serial.println(pollTime);
      #endif
      send(_Sensor.msg->set(pollTime));
      break;
    case S_MEMORY_FREE:
      int free_memory = freeMemory();
      #ifdef DEBUG
        Serial.print("---> ");Serial.print(_Sensor.desc); Serial.print(": ");Serial.println(free_memory);
      #endif
      send(_Sensor.msg->set(free_memory));
      break;
  }
}

void setup_sensor_INFO(sSENSOR _Sensor)
{
  if(_Sensor.HWsubtype == S_POLL_TIME) send(_Sensor.msg->set(POLL_TIME));
}

void receive_sensor_INFO(MyMessage msg)
{
  int i = getSensorIdxFromId(msg.sensor);
  if(i==NOTFOUND) return;

  if(Sensor[i].HWsubtype == S_POLL_TIME)
  {
    pollTime=msg.getLong();
    #ifdef EXTRADEBUG
      Serial.print("Cambiando valor de pollTime a: ");Serial.println(pollTime);
    #endif
  }
}
#endif

#ifdef HAVE_DHT11
  // SENSOR_DHT11
  #include <Adafruit_Sensor.h>
  #include <DHT.h>
  #include <DHT_U.h>
  //OJO: Mirar donde pongo esto despues ....
  DHT_Unified dht(3, DHT11);
  sensors_event_t event;

  void process_sensor_DHT11(sSENSOR _Sensor)
  {
    switch(_Sensor.MSpresentType) {
      case S_TEMP:
      {
        dht.temperature().getEvent(&event);
        #ifdef DEBUG
          Serial.print("Temperatura DHT11: ");Serial.println(event.temperature);
        #endif
        send(_Sensor.msg->set(event.temperature,1));
      } break;
      case S_HUM:
      {
        dht.humidity().getEvent(&event);
        #ifdef DEBUG
          Serial.print("Humedad DHT11: ");Serial.println(event.relative_humidity);
        #endif
        send(_Sensor.msg->set(event.relative_humidity,1));
      } break;
    }
  }

  void setup_sensor_DHT11(sSENSOR _Sensor)
  {
    dht.begin();
  }
#endif

#ifdef HAVE_DALLAS_18B20
  //SENSOR_DALLAS_18B20
  #include <DallasTemperature.h>
  #include <OneWire.h>

  void process_sensor_18B20(sSENSOR _Sensor)
  {
    OneWire oneWire(_Sensor.pin);
    DallasTemperature sensors(&oneWire);
    sensors.requestTemperatures();
    float temperatura = sensors.getTempCByIndex(0);
    #ifdef DEBUG
      Serial.print("Temperatura Dallas: ");Serial.print(temperatura);Serial.println(" grados");
    #endif
    send(_Sensor.msg->set(temperatura,1));
  }
#endif

#ifdef HAVE_PHOTORESISTOR
  void setup_sensor_PHOTORESISTOR(sSENSOR _Sensor)
  {
  }

  void process_sensor_PHOTORESISTOR(sSENSOR _Sensor)
  {
    int sensorValue =  analogRead(_Sensor.pin);
    float lux = (float) LDR_LUX * ( (1024.0 - (float) sensorValue) / (1024.0 - (float) LDR_VCC) );
    #ifdef DEBUG
      Serial.print(" Lux PHOTORESISTOR: ");Serial.println(lux);
    #endif
    send(_Sensor.msg->set(lux,1));
  }
#endif

#ifdef HAVE_YL38
  void setup_sensor_YL38(sSENSOR _Sensor)
  {
    if(_Sensor.flags.poweronread)
    {
      #ifdef DEBUG
        Serial.print("YL38 ");Serial.print(_Sensor.desc);Serial.println(" configurado como POWERONREAD");
      #endif
      pinMode(_Sensor.auxPin, OUTPUT);
    }
  }

  void process_sensor_YL38(sSENSOR _Sensor)
  {
    if(_Sensor.flags.poweronread)
    {
      #ifdef TRACE
        Serial.println("Alimentando sensor de humedad");
      #endif
      digitalWrite(_Sensor.auxPin, HIGH);
      delayMicroseconds(POWERDELAY);
    }
    int sensorValue =  analogRead(_Sensor.pin);
    #ifdef EXTRADEBUG
      Serial.print(_Sensor.desc);Serial.print(" Analog Value: ");Serial.println(sensorValue);
    #endif
    //Los valores iran de 300 a 1023 (totalmente humedo a seco)
    //los debemos pasar a 0-200 cb, pero lo dejo en 150
    sensorValue = constrain(sensorValue, MOISTURE_MINSENSOR, 1023);
    int hum = map(sensorValue, MOISTURE_MINSENSOR, 1023, 0, MOISTURE_MAXCB);
    if(_Sensor.flags.poweronread) 
    {
      delayMicroseconds(POWERDELAY);
      digitalWrite(_Sensor.auxPin, LOW);
    }
    #ifdef DEBUG
      Serial.print(_Sensor.desc);Serial.print("Hum: ");Serial.println(hum);
    #endif
    send(_Sensor.msg->set(hum,1));
  }
#endif

#ifdef HAVE_COUNTER
void isr_counter()
{
  #ifdef COUNTEREXTRADEBUG
    Serial.println("ENTRANDO EN ISR");
  #endif
  cli();
  Counter.newBlink = micros();
  unsigned long interval = Counter.newBlink - Counter.lastBlink;
  Counter.lastBlink = Counter.newBlink;
  Counter.pulseCount++;
  sei();
  if (interval != 0)
  {
    Counter.lastPulse = millis();
    //Si el tiempo es menor al esperado ignoramos el pulso
    if (interval < Counter.DEBOUNCEMICROSECS)
    {
      #ifdef COUNTERDEBUG
        Serial.println("DEBOUNCED");
      #endif
      return;
    }
    //El flujo instantaneo por minuto será: 60 seg * 1.000.000 microsec dividido entre el intervalo en microsegundos
    Counter.flow = 60000000.0 / ((float)interval * (float)Counter.PULSESFORLITER);
  }
  #ifdef COUNTEREXTRADEBUG
    Serial.print("ISR pulsecount:"); Serial.println(Counter.pulseCount);
  #endif
}

void setup_counter()
{
  Counter.msgVolume = new MyMessage(Counter.id,V_VOLUME);
  Counter.msgFlow = new MyMessage(Counter.id,V_FLOW);
  pinMode(Counter.pin, INPUT_PULLUP);
  Counter.pulseCount = Counter.oldPulseCount = 0;
  Counter.lastSend = Counter.lastPulse = millis();
  attachInterrupt(digitalPinToInterrupt(Counter.pin),isr_counter, Counter.mode);
  Serial.println("Saliendo de setup counter");
}

void process_counter()
{
  unsigned long currentTime = millis();
  //Deshabilitamos las interrupciones
  cli();
  //Esta linea sobra creo
  Counter.lastSend = currentTime;

  if (Counter.flow != Counter.oldFlow)
  {
      Counter.oldFlow = Counter.flow;
      #ifdef COUNTERDEBUG
        Serial.print("l/min:"); Serial.println(Counter.flow);
      #endif

      if (Counter.flow < Counter.MAXFLOW)
      {
        send(Counter.msgFlow->set(Counter.flow,2));
      }
      else
      {
        #ifdef COUNTERDEBUG
          Serial.print("FLUJO EXCEDIDO:"); Serial.println(Counter.flow);
        #endif
      }
  }

  if (currentTime - Counter.lastPulse > Counter.MILLISZEROFLOW) Counter.flow=0;

  if (Counter.pulseCount !=  Counter.oldPulseCount)
  {
    Counter.oldPulseCount = Counter.pulseCount;
    #ifdef COUNTERDEBUG
      Serial.print("pulsecount:"); Serial.println(Counter.pulseCount);
    #endif
    //Mandar los pulsos al gw
    //Vendra aqui pero no se si es necesario

    Counter.volume = (((double)Counter.pulseCount / (double)Counter.PULSESFORLITER)) / 1000.0;
    if (Counter.volume != Counter.oldVolume)
    {
      Counter.oldVolume = Counter.volume;
      #ifdef COUNTERDEBUG
        Serial.print("volume:"); Serial.println(Counter.volume,3);
      #endif
      send(Counter.msgVolume->set(Counter.volume,3));
    }
  }
    //Habilitamos las interrupciones
  sei();
}
#endif
