-- Dispatcher general para eventos recibidos desde la CCR
-- type = CNT para contadores almacenados en variables de Domoticz (autodefinidas)
return {
    on = {
        customEvents = {
            'CCR_Event'
        }
    },
    logging = {
        -- level = domoticz.LOG_DEBUG,
        level = domoticz.LOG_INFO,
        marker = "* CCR_DISPATCHER *"
    },
    execute = function(domoticz, event)
        local data = event.json
        
        if not data or not data.type then
            domoticz.log('Formato inválido o campo "type" ausente. Recibido: ' .. tostring(event.data), domoticz.LOG_ERROR)
            return
        end
        
        -- Evento recibido {"type":"CNT","uservar":"nombre_variable"} -> incrementa en 1 el valor de la variable
        if data.type == 'CNT' then
            local nombreVar = data.uservar
            if nombreVar then
                -- Busca variable sin disparar error si no existe
                local var = domoticz.variables().find(function(v) return v.name == nombreVar end)
                
                if var == nil or var.value == nil then
                    domoticz.log('CNT: la variable no existe, creando uservar: ' .. nombreVar, domoticz.LOG_INFO)
                    domoticz.openURL({
                        url = 'http://127.0.0.1:8080/json.htm?type=command&param=adduservariable&vname=' .. domoticz.utils.urlEncode(nombreVar) .. '&vtype=0&vvalue=1'
                    })
                    domoticz.log('CNT ' .. nombreVar .. ' = 1 (creada)', domoticz.LOG_INFO)
                else
                    local contador = var.value
                    var.set(contador + 1)
                    domoticz.log('CNT ' .. nombreVar .. ' = ' .. (contador + 1), domoticz.LOG_INFO)
                end
            else
                domoticz.log('CNT: falta el campo "uservar"', domoticz.LOG_ERROR)
            end
            
        elseif data.type == 'CMD' then
            -- Futura acción CMD
            
        elseif data.type == 'NFO' then
            -- Futura acción NFO
            
        else
            domoticz.log('Tipo desconocido: ' .. tostring(data.type), domoticz.LOG_ERROR)
        end
    end
}