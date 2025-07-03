-- actualiza en el panel de control el dispositivo virtual con el valor de la variable modificada 'TIEMPO-PATIO'
-- Este script se ejecuta cuando se modifica la variable 'TIEMPO-PATIO'
return {
    on = {
        variables = { 'TIEMPO-PATIO' }
    },
	logging = {
	    level = domoticz.LOG_DEBUG,
	    marker = "MYDEBUG"
	},
    execute = function(domoticz, trigger)
        local dispositivo = 'TIEMPO-PATIO'
        local valor_variable = domoticz.variables('TIEMPO-PATIO').value
        domoticz.devices(dispositivo).update(0, tostring(valor_variable))
        domoticz.log('Script para ' .. dispositivo .. ' ejecutado. Valor modificado a: ' .. valor_variable .. ' minutos', domoticz.LOG_DEBUG)

    end
}