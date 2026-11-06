#ifndef W5100_h
#define W5100_h
//Defines de configuracion
#define MY_NODE_ID 5
#define SKETCH_NAME "Gateway Ethernet_TEST"
#define SKETCH_VERSION "1.2"

//Defines del gateway
#define MY_IP_ADDRESS 192, 168, 1, 61 // If this is disabled, DHCP is used to retrieve address
#define MY_PORT 5003
#define MY_MAC_ADDRESS 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xEC   // direccion MAC que se usara para el Gateway (asignada aqui, no repetir en la misma lan)

#include <Ethernet.h>
#include "EthernetICMP.h"

#endif
