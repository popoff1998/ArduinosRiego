#include "platform.h"
#include "Riego.h"
#include "globals.h"

#ifdef W5100GATEWAY
  #include "W5100.h"
  #include "W5100_Sensors.h"
#else
  #include "USB.h"
  #include "USB_Sensors.h"
#endif

#include <MySensors.h>

int getRelayIdxFromId(int id)
{
  for(int i=0; i<NUMBER_OF_RELAYS;i++) {
    if(Rele[i].id == id) return i;
  }
  return NOTFOUND;
}

void initRelays(const sRELE Rele[], int nRelays)
{
  for (int i=0 ; i<nRelays; i++) {
    if (Rele[i].enabled) {
      // Poner el rele en output mode
      pinMode(Rele[i].pin, OUTPUT);
      //Poner initState
      switch(Rele[i].initState) {
        case SETON:
          digitalWrite(Rele[i].pin, Rele[i].ON);
          break;
        case SETOFF:
          digitalWrite(Rele[i].pin, Rele[i].OFF);
          break;
        case KEEP:
            #ifdef EXTRADEBUG
              Serial.print("Rele ");Serial.print(i);Serial.print(" es en la eeprom ");Serial.println(loadState(i));
            #endif
          digitalWrite(Rele[i].pin, loadState(i)?Rele[i].ON:Rele[i].OFF);
          break;
        default:
          //Por defecto y por seguridad lo ponemos a OFF si está mal definido en la estructura
          digitalWrite(Rele[i].pin, Rele[i].OFF);
          break;
      }
    }
  }
}

void presentRelays(const sRELE Rele[], int nRelays)
{
  //Presentar los reles
  for (int i=0; i<nRelays; i++) {
    if (Rele[i].enabled) {
      // Registrar todos los reles al gw
      present(Rele[i].id, S_LIGHT,Rele[i].desc);
      // Le tenemos que mandar el estado que tiene.
      MyMessage relayMsg(Rele[i].id,S_LIGHT);
        #ifdef EXTRADEBUG
          Serial.print("El estado del rele ");Serial.print(Rele[i].desc);Serial.print(" es: ");Serial.println(digitalRead(Rele[i].pin));
        #endif
      send(relayMsg.set(digitalRead(Rele[i].pin)?Rele[i].ON:Rele[i].OFF));
    }
  }
}

void initSensors(sSENSOR Sensor[], int nSensors)
{
  for (int i=0; i<nSensors; i++) {
    if (Sensor[i].flags.enabled) {
      //Instanciamos un nuevo msg para cada sensor
      Sensor[i].msg = new MyMessage(Sensor[i].id,Sensor[i].MSmessageType);
      switch(Sensor[i].HWtype) {
        #ifdef HAVE_DHT11
          case DDHHTT: {
            setup_sensor_DHT11(Sensor[i]);
          } break;
        #endif
        #ifdef HAVE_YL38
          case YL38: {
            setup_sensor_YL38(Sensor[i]);
          } break;
        #endif
        #ifdef HAVE_INFO
          case INFO: {
            setup_sensor_INFO(Sensor[i]);
          } break;
        #endif
      }
    }
  }
}

void presentSensors(sSENSOR Sensor[], int nSensors)
{
  for (int i=0; i<nSensors; i++) {
    if (Sensor[i].flags.enabled) {
      Serial.print("Presentando sensor: ");Serial.print(Sensor[i].id);Serial.print(" ");Serial.println(Sensor[i].desc);
      present(Sensor[i].id,Sensor[i].MSpresentType,Sensor[i].desc);
    }
  }
}

void presentCounter()
{
  Serial.println("Presentando contador");
  present(Counter.id,S_WATER,Counter.desc);
}

void receive(const MyMessage &message) {
  // Procesamos los mensajes V_LIGTH
  int idx;
  if (message.type==V_LIGHT) {
    //Debemos traducir message.sensor al indice del array
    idx = getRelayIdxFromId(message.sensor);
    // Cambiar estado del rele
    #ifdef EXTRADEBUG
      Serial.print(Rele[idx].desc);Serial.print(": PIN= ");Serial.println(Rele[idx].pin);
      Serial.print("BOOL= ");Serial.println(message.getBool());
    #endif

    digitalWrite(Rele[idx].pin, message.getBool()?Rele[idx].ON:Rele[idx].OFF);
    // Almacenar estado en la eeprom independientemente de initState (por si acaso)
    saveState(idx, message.getBool());
    #ifdef DEBUG
     // Escribir informacion de debug
     Serial.print("Cambio entrante para sensor:"); Serial.print(message.sensor); Serial.print(", Nuevo status: "); Serial.println(message.getBool());
    #endif
  }
  //Procesamos los mensajes V_TEXT
  #ifdef HAVE_INFO
    if (message.type==V_TEXT) {
      #ifdef EXTRADEBUG
        Serial.print("Mensaje V_TEXT sensor: ");Serial.print(message.sensor);Serial.print(" valor: ");Serial.println(message.getLong());
      #endif
      receive_sensor_INFO(message);
    }
  #endif
}

void presentation()
{
  // Presentar los sensores y actuadores locales
  Serial.println("Comenzando presentacion");
  // Mandar la info del sketch
  sendSketchInfo(SKETCH_NAME, SKETCH_VERSION);
  presentRelays(Rele,NUMBER_OF_RELAYS);
  presentSensors(Sensor,NUMBER_OF_SENSORS);
  #ifdef HAVE_COUNTER
    presentCounter();
  #endif
  Presented = true;
  Serial.println("Finalizando presentacion");
}

void setup()
{
  //Inicializamos el tiempo de pollin al valor builtin
  pollTime = POLL_TIME;
  Presented = false;
  //Para los reles
   Serial.println("start call SETUP");
   initRelays(Rele,NUMBER_OF_RELAYS);
   #ifdef TRACE
    Serial.println("Despues de initRelays");
   #endif
   initSensors(Sensor,NUMBER_OF_SENSORS);
   #ifdef TRACE
    Serial.println("Despues de initSensors");
   #endif
  //Para el contador
  #ifdef HAVE_COUNTER
   setup_counter();
  #endif
   Serial.println("End call Setup");
  //En el caso de USB forzamos la presentacion
  #ifdef USBGATEWAY
    presentation();
  #endif
}

//MyMessage msg(0,0);

void loop() {
  if (!Presented)
  {
    #ifdef DEBUG
      Serial.println("Sensores aun no presentados, saliendo de loop");
    #endif
    wait(POLL_TIME);
    return;
  }
    //Procesar el contador
  #ifdef HAVE_COUNTER
    process_counter();
  #endif
    //Bucle para procesar todos los sensores
  for (int i=0; i<NUMBER_OF_SENSORS; i++) {
    //Creamos el mensaje
    if(Sensor[i].flags.enabled) {
      switch(Sensor[i].HWtype) {
        case DALLAS_18B20:
          #ifdef HAVE_DALLAS_18B20
            process_sensor_18B20(Sensor[i]);
          #endif
          break;
        case DDHHTT:
          #ifdef HAVE_DHT11
            process_sensor_DHT11(Sensor[i]);
          #endif
          break;
        case S_PHOTORESISTOR:
          #ifdef HAVE_PHOTORESISTOR
            process_sensor_PHOTORESISTOR(Sensor[i]);
          #endif
          break;
        case YL38:
          #ifdef HAVE_YL38
            process_sensor_YL38(Sensor[i]);
          #endif
          break;
        case INFO:
          #ifdef HAVE_INFO
            if(Sensor[i].flags.requestable) {
              #ifdef EXTRADEBUG
                Serial.print("Requesting sensor: "); Serial.println(i);
              #endif
              request(Sensor[i].id,V_TEXT);
            }
            process_sensor_INFO(Sensor[i]);
            break;
          #endif
        case S_ARDUINO_TEMP:
          process_sensor_arduino_temp(Sensor[i]);
          break;
      }
    }
  }
  wait(pollTime);
}
