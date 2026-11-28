-- Este script gestiona el watchdog de parada de emergencia de una EV abierta por la CCR y que esta no ha podido parar
-- Los mensajes que la CCR envia al text-device "CCR_Watchdog" lo activan o desactivan
-- Este temporizador de parada que se pierde en caso de reinicio se recupera con este mismo script,
-- RETRASO_RECUPERA segundos despues del arranque (evento RECUPERA_WDG), cuando ya se ha sincronizado el estado real de las EV

-- funcion para rehabilitar posibles eventos de parada que se hayan perdido tras un arranque,
-- para ello lee la cola persistente domoticz.data.limitesParada.
-- Las entradas NO se borran aqui: solo las borra un off confirmado por la CCR (WDG:idx:0, WDG:idx:-1) o CCR_STOPALL.
-- salvo en el caso de Limite de antiguedad: pasado este tiempo desde el limite vencido, el watchdog de los Arduino (60 min)
-- ya habra cerrado la EV, asi que se ignora y se borra la entrada.
local MAX_ANTIGUEDAD = 3600  -- 60 minutos adicionales a la hora limite
local CHECK_MARGEN_S = 10     -- seg entre la hora del Off y su CHECK_WDG: tiempo para que llegue el ACK del Arduino (hasta ~5 s con reintento)
local RETRASO_RECUPERA = 90   -- seg Debe ser mayor que el retraso del SYNC que pide GruposRiego_factorizado (RETRASO_SYNC, 70 s)

-- El estado de una EV es valido si Domoticz lo ha recibido del Arduino despues del arranque (su "last seen" es posterior):
-- eso indica que el SYNC se ejecuto para esa EV. Si no, el estado es el guardado antes de la caida y no es fiable.
local function estadoValido(dev, ahora, tArranque)
    return dev.lastUpdate ~= nil and dev.lastUpdate.secondsAgo < (ahora - tArranque)
end

local function handleStartup(domoticz)
    local ahora = os.time()
    domoticz.log('Recuperando colas watchdog desde persistencia...', domoticz.LOG_INFO)

    for idxStr, horaLimite in pairs(domoticz.data.limitesParada) do
        local idx = tonumber(idxStr)
        if idx and horaLimite and horaLimite > 0 then
            domoticz.log('DEBUG PERSISTENCIA -> IDX: ' .. idxStr .. ' | Hora Límite abs: ' .. os.date('%Y-%m-%d %H:%M:%S', horaLimite), domoticz.LOG_DEBUG)
            local segundosRestantes = horaLimite - ahora
            if -segundosRestantes >= MAX_ANTIGUEDAD then
                -- vencida hace demasiado: se ignora y se borra
                domoticz.data.limitesParada[idxStr] = nil
                domoticz.log('WATCHDOG DESCARTADO: IDX ' .. idx .. ' vencido hace ' .. (-segundosRestantes) .. 's (>= ' .. MAX_ANTIGUEDAD .. 's), se ignora', domoticz.LOG_INFO)
            else
                local dev = domoticz.devices(idx)
                if dev then
                    if segundosRestantes > 0 then
                        -- aun no vencida: se vuelve a programar el Off (se anula antes cualquier Off ya encolado)
                        dev.cancelQueuedCommands()
                        dev.switchOff().afterSec(segundosRestantes)
                        domoticz.emitEvent('CHECK_WDG',  idx .. ':' .. horaLimite).afterSec(segundosRestantes + CHECK_MARGEN_S)
                        domoticz.log('WATCHDOG RECONSTRUIDO: IDX ' .. idx .. ' (' .. dev.name .. ') re-programado para apagar en ' .. segundosRestantes .. 's', domoticz.LOG_INFO)
                    elseif estadoValido(dev, ahora, domoticz.data.tArranque) and not dev.bState then
                        -- vencida, pero el estado real (tras el SYNC) dice que la EV ya esta cerrada: no hay nada que cerrar
                        domoticz.data.limitesParada[idxStr] = nil
                        domoticz.log('WATCHDOG VENCIDO: IDX ' .. idx .. ' (' .. dev.name .. ') hace ' .. (-segundosRestantes) .. 's, la EV ya esta cerrada', domoticz.LOG_INFO)
                    else
                        -- vencida y la EV esta abierta, o su estado no es fiable (no hubo SYNC para ella): se cierra sin condiciones
                        dev.cancelQueuedCommands()
                        dev.switchOff()
                        domoticz.emitEvent('CHECK_WDG',  idx .. ':' .. horaLimite).afterSec(CHECK_MARGEN_S)
                        domoticz.log('WATCHDOG RECUPERADO: IDX ' .. idx .. ' (' .. dev.name .. ') vencido hace ' .. (-segundosRestantes) .. 's, apagando' ..
                                     (estadoValido(dev, ahora, domoticz.data.tArranque) and '' or ' (estado no verificado por SYNC)'), domoticz.LOG_ERROR)
                    end
                else
                    -- el dispositivo puede no estar disponible aun: se conserva la entrada
                    domoticz.log('WATCHDOG: no existe/disponible el dispositivo IDX ' .. idx .. ', se conserva la entrada', domoticz.LOG_ERROR)
                end
            end    
        end
    end
end

-- funcion para procesar el msg WDG
local function handleWDG(domoticz, texto, payload)
    local idxStr, segStr = payload:match("^(%d+):(%-?%d+)$")
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

    dev.cancelQueuedCommands()

    if segundos > 0 then
        local tiempoLimite = os.time() + segundos
        dev.switchOff().afterSec(segundos)
        domoticz.data.limitesParada[tostring(idx)] = tiempoLimite
        domoticz.log('DEBUG WDG -> Guardado en persistencia [Key: ' .. tostring(idx) .. '] = ' .. tiempoLimite, domoticz.LOG_DEBUG)
        domoticz.emitEvent('CHECK_WDG',  idx .. ':' .. tiempoLimite).afterSec(segundos + CHECK_MARGEN_S)
        
        domoticz.log('WDG programada parada IDX ' .. idx .. ' (' .. dev.name .. ') en ' .. segundos .. 's', domoticz.LOG_INFO)
    elseif segundos == 0 then
        domoticz.data.limitesParada[tostring(idx)] = nil
        domoticz.log(idx .. ' (' .. dev.name .. ') parado OK por CCR, cancelada parada emergencia', domoticz.LOG_INFO)
        domoticz.devices('CCR_Watchdog').updateText('CCR_OFF: recibido ' .. dev.name).silent()
    elseif segundos == -1 then
        domoticz.data.limitesParada[tostring(idx)] = nil
        domoticz.log('WDG cola limpiada IDX ' .. idx .. ' (' .. dev.name .. ') [parada masiva]', domoticz.LOG_DEBUG)
    else
        domoticz.log('WDG: valor de segundos no válido: ' .. segundos, domoticz.LOG_ERROR)
    end
end

-- funcion para verificar si se tuvo que ejecutar el watchdog
local function handleCheckWDG(domoticz, data)
    local idxStr, limStr = tostring(data):match('^(%d+):(%d+)$')
    if not idxStr then
        domoticz.log('CHECK_WDG: formato inválido: ' .. tostring(data), domoticz.LOG_ERROR)
        return
    end
    local actual = domoticz.data.limitesParada[idxStr]
    if actual and actual == tonumber(limStr) then
        -- La CCR no confirmo la parada. Se verifica que el Off del watchdog haya llegado a cerrar la EV
        -- (Domoticz no actualiza su estado si no recibe el ACK del Arduino).
        local dev = domoticz.devices(tonumber(idxStr))
        local devName = dev and dev.name or ('IDX ' .. idxStr)

        if dev and dev.bState then
            -- Sigue abierta: se reenvia el Off una vez. NO se borra la entrada ni se toca el texto "WDG:idx:seg":
            -- asi SCD_Watchdog sigue viendo un riego de la CCR pendiente de parar y avisa/cierra por su cuenta.
            -- Cuando Domoticz vea la EV en Off, SCD_Watchdog limpia el texto y la entrada (WDG:idx:-1).
            dev.switchOff()
            local msg = 'WATCHDOG: ' .. devName .. ' SIGUE ABIERTA tras su Off, reintentando'
            domoticz.log(msg .. ' (expiró sin confirmación de CCR)', domoticz.LOG_ERROR)
            domoticz.notify('RIEGOERROR', msg, domoticz.PRIORITY_HIGH)
        else
            -- EV cerrada (o desconocida): el watchdog actuo. Limpiamos para que no vuelva a saltar y lo dejamos visible en el texto
            domoticz.data.limitesParada[idxStr] = nil
            local msg = 'ACTUÓ WATCHDOG: ' .. devName
            domoticz.devices('CCR_Watchdog').updateText(msg).silent()
            domoticz.log(msg .. ' (expiró sin confirmación de CCR)', domoticz.LOG_ERROR)
            domoticz.notify('RIEGOERROR', msg, domoticz.PRIORITY_HIGH)
        end
    elseif actual then
        domoticz.log('CHECK_WDG: IDX ' .. idxStr .. ' rearmado, check obsoleto', domoticz.LOG_DEBUG)
    else
        domoticz.log('CHECK_WDG: IDX ' .. idxStr .. ' ya sin entrada (parada OK previa)', domoticz.LOG_DEBUG)
    end
end

-- NOTA: system = { 'start' } funciona en Domoticz 2025.1 con dzVents 3.1.8 (verificado).
--       En Domoticz 2026.1 con dzVents 3.1.11 también existe 'at_startup'.
return {
    on = {
        devices = { 'CCR_Watchdog' },
        customEvents = { 'CHECK_WDG', 'RECUPERA_WDG' },
        system = { 'start' }
    },
    logging = {
        level = domoticz.LOG_DEBUG,
        --level = domoticz.LOG_INFO,
        marker = "* CCR_WATCHDOG *"
    },
    data = {
        limitesParada = { initial = {} },
        tArranque     = { initial = 0 }   -- hora del ultimo arranque de Domoticz
    },
    execute = function(domoticz, item)
        -- 1. Disparo de arranque
        if item.isSystemEvent and item.trigger == 'start' then
            domoticz.log('Disparo de sistema/arranque: recuperacion en ' .. RETRASO_RECUPERA .. 's', domoticz.LOG_DEBUG)
            domoticz.data.tArranque = os.time()
            domoticz.emitEvent('RECUPERA_WDG').afterSec(RETRASO_RECUPERA)
            return
        end

        -- 1b. Recuperacion diferida de los watchdogs (ya sincronizado el estado real de las EV)
        if item.isCustomEvent and item.trigger == 'RECUPERA_WDG' then
            handleStartup(domoticz)
            return
        end

        -- 2. Disparo por evento personalizado de verificación asíncrona
        if item.isCustomEvent and item.trigger == 'CHECK_WDG' then
            handleCheckWDG(domoticz, item.data)
            return
        end

        -- 3. Disparo por dispositivo CCR_Watchdog (mensajes WDG, CCR_STOPALL, etc.)
        local texto = item.text
        if not texto or texto == '' then
            domoticz.log('Payload vacío o no válido', domoticz.LOG_ERROR)
            return
        else
            domoticz.log('texto recibido "' .. texto .. '"', domoticz.LOG_DEBUG)
        end

        local prefijo, payload = texto:match("^([%u_]+):?(.*)$")

        if prefijo == 'WDG' then
            handleWDG(domoticz, texto, payload)
        elseif prefijo == 'CCR_STOPALL' then
            domoticz.data.limitesParada = {}
            domoticz.log('colas WDG limpiada y reseteada persistencia (CCR_STOPALL)', domoticz.LOG_INFO)           
        elseif prefijo == 'NFO' then
            domoticz.log('NFO procesado', domoticz.LOG_INFO)
        elseif prefijo == 'TEST_OLD' then
            -- TEMPORAL: TEST_OLD:idx:segundosDeAntiguedad
            local i, a = payload:match("^(%d+):(%d+)$")
            if i and a then
                domoticz.data.limitesParada[i] = os.time() - tonumber(a)
                domoticz.log('TEST: entrada IDX ' .. i .. ' con limite hace ' .. a .. 's', domoticz.LOG_INFO)
            end        
        else
            domoticz.log('Prefijo desconocido: ' .. tostring(prefijo), domoticz.LOG_ERROR)
        end
    end
}