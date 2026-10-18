-- Actualiza en el panel de control el dispositivo virtual con el valor de la variable modificada 'TIEMPO-*'
-- tambien se ejecuta cada hora para evitar que se marque en rojo el dispositivo virtual por falta de actualizacion
-- Nombres de las variables; cada una debe tener un dispositivo virtual con el mismo nombre
local NOMBRES = { 'TIEMPO-CESPED', 'TIEMPO-GOTEOS', 'TIEMPO-HUERTO', 'TIEMPO-PATIO' }

return {
    on = {
        variables = NOMBRES,
        timer = { 'every hour' }
    },
    logging = {
        level = domoticz.LOG_INFO,
        marker = "TIEMPOS_RIEGO"
    },
    execute = function(domoticz, trigger)
        local lista = NOMBRES
        if trigger.isVariable then lista = { trigger.name } end
    
        for _, nombre in ipairs(lista) do
            local valor = domoticz.variables(nombre).value
            domoticz.devices(nombre).update(0, tostring(valor))

            if trigger.isVariable and trigger.name == nombre then
                domoticz.log('Script para ' .. nombre .. ' ejecutado. Valor modificado a: ' .. tostring(valor) .. ' minutos', domoticz.LOG_INFO)
            end
        end    
    end
}