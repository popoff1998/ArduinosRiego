-- activa watchdog de parada riego de emergencia
return {
    on = {
        devices = { 'CCR_Watchdog' },
        customEvents = { 'CCR_Watchdog' }
    },
    logging = {
        level = domoticz.LOG_INFO,
        -- level = domoticz.LOG_DEBUG,
        marker = "* CCR_WATCHDOG *"
    },
    execute = function(domoticz, item)
        local texto = nil
        -- Obtenemos el texto según el origen del disparo
        if item.isCustomEvent then
            texto = item.data
        else
            texto = item.text
        end
        
        if not texto or texto == '' then
            domoticz.log('Payload vacío o no válido', domoticz.LOG_ERROR)
            return
        else
            domoticz.log('texto recibido "' .. texto .. '"', domoticz.LOG_DEBUG)
        end
        
        -- Permite extraer el prefijo (mayusculas y opcionalmente guion bajo) tanto si viene seguido de ':' como si es solo el texto
        local prefijo, payload = texto:match("^([%u_]+):?(.*)$")

        -- Watchdog: formato WDG:idx:segundos
        -- (segundos>0 programa parada, 0 parada individual OK por la CCR, -1 solo limpia cola
        if prefijo == 'WDG' then
            local idxStr, segStr = payload:match("^(%d+):(%-?%d+)$") -- admite segundos negativos
            local idx = tonumber(idxStr)
            local segundos = tonumber(segStr)
    
            if not idx or not segundos then
                domoticz.log('WDG: formato inválido, esperado WDG:idx:segundos. Recibido: ' .. texto, domoticz.LOG_ERROR)
                return
            end
            
            local dev = domoticz.devices(idx)
            if not dev then
                domoticz.log('WDG: no existe el dispositivo con IDX ' .. idx, domoticz.LOG_ERROR)
                return
            end
    
            dev.cancelQueuedCommands() -- cancelamos posibles eventos previos en la cola
            
            if segundos > 0 then
                dev.switchOff().afterSec(segundos)
                domoticz.log('WDG programada parada IDX ' .. idx .. ' (' .. dev.name .. ') en ' .. segundos .. 's', domoticz.LOG_INFO)
            elseif segundos == 0 then
                domoticz.log(idx .. ' (' .. dev.name .. ') parado OK por CCR, cancelada parada emergencia', domoticz.LOG_INFO)
                domoticz.devices('CCR_Watchdog').updateText('CCR_OFF: recibido ' .. dev.name)
            elseif segundos == -1 then
                domoticz.log('WDG cola limpiada IDX ' .. idx .. ' (' .. dev.name .. ') [parada masiva]', domoticz.LOG_DEBUG)
            else
                domoticz.log('WDG: valor de segundos no válido: ' .. segundos, domoticz.LOG_ERROR)
            end
             
        -- solo genera log informativo    
        elseif prefijo == 'CCR_STOPALL' then
            domoticz.log('colas WDG limpiada (CCR_STOPALL)', domoticz.LOG_INFO)           
            
        -- prefijos sin proceso (evita segundo procesado al actualizar texto del device desde este mismo script)    
        elseif prefijo == 'CCR_OFF' then
            domoticz.log('prefijo ' .. prefijo .. ' no tratado', domoticz.LOG_DEBUG)

        elseif prefijo == 'NFO' then
            -- Futura acción NFO
            domoticz.log('NFO procesado', domoticz.LOG_INFO)
            
        else
            domoticz.log('Prefijo desconocido: ' .. tostring(prefijo), domoticz.LOG_ERROR)
        end
    end
}