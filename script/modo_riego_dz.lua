-- Actualiza en el panel de control el dispositivo virtual con el valor de la variable modificada 'MODO-RIEGO'
-- Este script se ejecuta cuando se modifica la variable 'MODO-RIEGO'
return {
    on = {
        variables = { 'MODO-RIEGO' }
    },
	logging = {
	    level = domoticz.LOG_DEBUG,
	    marker = "MYDEBUG"
	},
    execute = function(domoticz, trigger)
        local dispositivo = 'MODO-RIEGO'
        local valor_variable = domoticz.variables('MODO-RIEGO').value
        domoticz.devices(dispositivo).update(0, tostring(valor_variable))
        domoticz.log('Script para ' .. dispositivo .. ' ejecutado. Cambiado a: ' .. valor_variable .. ' ', domoticz.LOG_DEBUG)

    end
}