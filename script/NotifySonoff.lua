DEBUG = false

return {
	on = {
		devices = {
			'SONOFF-UPTIME'
		}
	},
	data = {
	    -- Ultimo contador
	    lastCounter = { initial = 0 },
	    lastState = { initial = 'Off' }
	},
	execute = function(domoticz, device)
        if(device.name == 'SONOFF-UPTIME') then
            if(DEBUG) then
    		    domoticz.log('Device ' .. device.name .. ' was changed ' .. ' COUNTER: ' .. tostring(device.counter) .. ' LAST: ' .. domoticz.data.lastCounter, domoticz.LOG_FORCE)
    		end
    		domoticz.data.lastState = domoticz.devices('LUZ PORCHE').state
    		if(tonumber(device.counter) < domoticz.data.lastCounter) then
    		    domoticz.notify('SONOFFRESET','*SONOFF reseteado tras ' .. domoticz.data.lastCounter .. ' minutos*',domoticz.PRIORITY_HIGH)
    		    -- Volvemos a poner el estado que tuviera antes la luz
    		    -- No se si esto funcionará ....
    		    domoticz.log('LUZ PORCHE: State: '  .. domoticz.devices('LUZ PORCHE').state .. ' Last: ' .. domoticz.data.lastState, domoticz.LOG_FORCE)
                if(domoticz.data.lastState == 'On') then
                    domoticz.devices('LUZ PORCHE').switchOn()
                else
                    domoticz.devices('LUZ PORCHE').switchOff()
                end                    
    		end
    		domoticz.data.lastCounter = tonumber(device.counter)
    	end
	end
}