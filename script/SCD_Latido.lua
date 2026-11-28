-- Latido del SCD: escribe cada minuto la hora actual (epoch + fecha legible) en el text-device "Latido".
-- Monit lo consulta (check_latido.sh) y, si se queda viejo, reinicia Domoticz.
-- Script deliberadamente minimo e independiente de cualquier otro: un error de logica en otro script
-- no debe poder parar el latido (provocaria un reinicio innecesario).
-- Solo escribe en el log si hay un problema (nivel ERROR).
return {
    on = {
        timer = { 'every minute' }
    },
    logging = {
        level = domoticz.LOG_ERROR,
        marker = '* LATIDO *'
    },
    execute = function(domoticz)
        local dev = domoticz.devices('Latido')
        if not dev then
            domoticz.log('No existe el text-device "Latido"', domoticz.LOG_ERROR)
            return
        end
        -- El texto cambia siempre (epoch), asi no depende de como trate Domoticz un update con valor identico
        local ahora = os.time()
        dev.updateText(ahora .. ' ' .. os.date('%Y-%m-%d %H:%M:%S', ahora))
    end
}
