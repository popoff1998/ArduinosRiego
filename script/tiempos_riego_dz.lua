-- Actualiza en el panel de control el dispositivo virtual con el valor de la variable modificada 'TIEMPO-*'
-- tambien se ejecuta cada hora para evitar que se marque en rojo el dispositivo virtual por falta de actualizacion
-- (el nombre de la variable debe ser el mismo que el del dispositivo virtual)

return {
    on = {
        variables = { 'TIEMPO-CESPED', 'TIEMPO-GOTEOS', 'TIEMPO-HUERTO', 'TIEMPO-PATIO' },
        timer = { 'every hour' }
    },
    logging = {
        level = domoticz.LOG_DEBUG,
        marker = "MYDEBUG"
    },
    execute = function(domoticz, trigger)
        local variables = { 'TIEMPO-CESPED', 'TIEMPO-GOTEOS', 'TIEMPO-HUERTO', 'TIEMPO-PATIO' }
        for _, nombre in ipairs(variables) do
            local valor = domoticz.variables(nombre).value
            domoticz.devices(nombre).update(0, tostring(valor))
            -- domoticz.log('Script para ' .. nombre .. ' ejecutado. Valor modificado a: ' .. valor .. ' minutos', domoticz.LOG_DEBUG)
        end
    end
}