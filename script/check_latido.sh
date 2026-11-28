#!/bin/sh
# Comprueba el latido que escribe SCD_Latido.lua en el text-device "Latido".
# Salida 0 = latido reciente; 1 = viejo, ausente o Domoticz no responde.
IDX=999            # <-- IDX del text-device "Latido"
MAX_EDAD=120       # segundos; con latido cada 60 s son 2 latidos perdidos
URL="http://127.0.0.1:8080/json.htm?type=command&param=getdevices&rid=$IDX"

LAST=$(curl -s --max-time 10 "$URL" | sed -n 's/.*"Data"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\) .*/\1/p' | head -n 1)
[ -z "$LAST" ] && exit 1

NOW=$(date +%s)
[ $((NOW - LAST)) -le "$MAX_EDAD" ] && exit 0
exit 1

# Comprobación en monit:
# Con maxedad=120 seg y ciclo de monit de 60 seg, reiniciaria a los 4 o 5 minutos sin latido
#  check program domoticz_latido with path "/usr/local/bin/check_latido.sh"
#    with timeout 20 seconds
#    if status != 0 for 3 cycles then exec "/bin/systemctl restart domoticz"