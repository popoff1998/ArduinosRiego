-- Tabla MODOS con los nombres EXACTOS de los modos del selector MODO-RIEGO. los grupos y las EV que componen cada grupo
local MODOS = {
    ['VERANO'] = {
        cesped = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO' },
        goteos = { 'EV-GOTEOALTO', 'EV-GOTEOBAJO', 'EV-ROCALLA', 'EV-GOTEOOLIVO' }
    },
    ['VERANO-HUERTO'] = {
        cesped = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO' },
        goteos = { 'EV-GOTEOALTO', 'EV-GOTEOBAJO', 'EV-ROCALLA' }
    },
    ['CORDOBA'] = {
        cesped = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO', 'EV-PIEDRAS' },
        goteos = { 'EV-GOTEOALTO', 'EV-GOTEOBAJO', 'EV-ROCALLA', 'EV-GOTEOOLIVO', 'EV-PATIO' }
    },
    ['CORDOBA-HUERTO'] = {
        cesped = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO', 'EV-PIEDRAS' },
        goteos = { 'EV-GOTEOALTO', 'EV-GOTEOBAJO', 'EV-ROCALLA', 'EV-PATIO' }
    }
}

-- Para pruebas poner a false
local ABRE_GENERAL = true

local function RiegaHuerto(domoticz, tRiego)
    domoticz.devices('EV-GOTEOOLIVO').switchOn().afterMin(0).forMin(tRiego)
end

local function TerminaHuerto(domoticz)
    domoticz.devices('EV-GOTEOOLIVO').switchOff()
end

-- Riega una lista de EV en secuencia, factorizando por la descripción del dispositivo. 
-- Devuelve el tiempo total del grupo en minutos.
local function RiegaGrupo(domoticz, lista, delay, tRiego, tPatio)
    local delayInicial = delay
    for _, nombre in ipairs(lista) do
        local base = (nombre == 'EV-PATIO' and tPatio) or tRiego -- EV-PATIO tiene su propio tiempo
        local device = domoticz.devices(nombre)
        local factor = tonumber(device.description:match("^(%d+)")) or 100 -- extrae numero al princio del campo description (100 si no existe)
        local tiempoRiego = (base * factor) / 100
        domoticz.log('Riego ' .. nombre .. ' con factor ' .. factor .. ' y tiempo ' .. tiempoRiego .. ' minutos', domoticz.LOG_INFO)
        device.switchOn().afterMin(delay).forMin(tiempoRiego)
        delay = delay + tiempoRiego
    end
    local total = delay - delayInicial
    domoticz.log('Tiempo del grupo: ' .. total .. ' minutos', domoticz.LOG_INFO)
    return total
end

local function ParaGrupo(domoticz, lista)
    for _, nombre in ipairs(lista) do
        domoticz.devices(nombre).switchOff()
    end
end

local function AbreGeneral(domoticz, tiempo)
    if ABRE_GENERAL then
        domoticz.devices('EV-GENERAL').switchOn().forMin(tiempo)
    else
        domoticz.log('** ABRE_GENERAL es false: tiempo de cierre ' .. tiempo * 60 .. ' segundos **')
    end
end

return {
    active = true,
    on = {
        devices = { 'COMPLETO', 'CESPED', 'GOTEOS', 'HUERTO' }
    },
    logging = {
        -- level = domoticz.LOG_DEBUG,
        level = domoticz.LOG_INFO,
        marker = "* GRUPO_RIEGOS *"
    },
    data = {
        semaforo        = { initial = false },
        offInterno      = { initial = false },
        contadorInicial = { initial = 0 },
        modoActivo      = { initial = '' },
        estado = { initial = { ['COMPLETO'] = false, ['CESPED'] = false, ['GOTEOS'] = false, ['HUERTO'] = false } }
    },
    execute = function(domoticz, boton)

        -- Leemos el modo de riego
        local modoRiego = domoticz.devices('MODO-RIEGO').levelName
        local cfg = MODOS[modoRiego]
        domoticz.log(boton.name .. ' - MODO RIEGO ES ' .. tostring(modoRiego), domoticz.LOG_FORCE)

        -- Leemos los valores de los tiempos de sus variables
        local tCesped = domoticz.variables('TIEMPO-CESPED').value
        local tGoteos = domoticz.variables('TIEMPO-GOTEOS').value
        local tHuerto = domoticz.variables('TIEMPO-HUERTO').value
        local tPatio  = domoticz.variables('TIEMPO-PATIO').value

        -- EL BOTON SE ENCIENDE
        -- Antes que nada deshabilitamos los dobles clicks de botones de grupos
        if boton.state == 'On' and domoticz.data.semaforo then
            domoticz.notify('RIEGOERROR', '*Riego ' .. boton.name .. ' no activado por bloqueo de semaforo*', domoticz.PRIORITY_HIGH)
            if not domoticz.data.estado[boton.name] then
                domoticz.data.offInterno = true
                boton.switchOff()
            else
                domoticz.notify('RIEGOINFO', '*Riego ' .. boton.name .. ' debia ser una programacion de un riego lanzado a mano antes*', domoticz.PRIORITY_HIGH)
            end

        elseif boton.state == 'On' then

            -- Validamos modo correcto
            if not cfg then
                domoticz.log('Modo de riego no válido: ' .. tostring(modoRiego), domoticz.LOG_ERROR)
                domoticz.notify('RIEGOERROR', '*Riego ' .. boton.name .. ' NO activado: modo no válido (' .. tostring(modoRiego) .. ')*', domoticz.PRIORITY_HIGH)
                boton.switchOff()
                return
            end

            -- Preparamos variables
            domoticz.notify('RIEGOON ' .. boton.name, '*Riego ' .. boton.name .. ' comenzado modo ' .. tostring(modoRiego) .. '* (factorizado)', domoticz.PRIORITY_HIGH)
            domoticz.data.semaforo = true
            domoticz.data.estado[boton.name] = true
            domoticz.data.modoActivo = modoRiego
            domoticz.data.contadorInicial = domoticz.devices('CONTADOR AGUA').counter
            domoticz.log('CONTADOR (inicial): ' .. domoticz.data.contadorInicial, domoticz.LOG_FORCE)

            -- Operamos segun el boton pulsado
            if boton.name == 'COMPLETO' then
                local tC = RiegaGrupo(domoticz, cfg.cesped, 0, tCesped)
                local tG = RiegaGrupo(domoticz, cfg.goteos, tC, tGoteos, tPatio)
                local tiempoTotal = tC + tG
                AbreGeneral(domoticz, tiempoTotal)
                boton.switchOff().afterMin(tiempoTotal)
            elseif boton.name == 'CESPED' then
                local tC = RiegaGrupo(domoticz, cfg.cesped, 0, tCesped)
                AbreGeneral(domoticz, tC)
                boton.switchOff().afterMin(tC)
            elseif boton.name == 'GOTEOS' then
                local tG = RiegaGrupo(domoticz, cfg.goteos, 0, tGoteos, tPatio)
                AbreGeneral(domoticz, tG)
                boton.switchOff().afterMin(tG)
            elseif boton.name == 'HUERTO' then
                AbreGeneral(domoticz, tHuerto)
                RiegaHuerto(domoticz, tHuerto)
                boton.switchOff().afterMin(tHuerto)
            end
        end

        -- EL BOTON SE APAGA
        if boton.state == 'Off' then
            domoticz.log('DEVICE: ' .. boton.name ..
                         ' Estados: ' .. tostring(domoticz.data.estado['COMPLETO']) ..
                         ' ' .. tostring(domoticz.data.estado['CESPED']) ..
                         ' ' .. tostring(domoticz.data.estado['GOTEOS']) ..
                         ' ' .. tostring(domoticz.data.estado['HUERTO']),
                         domoticz.LOG_DEBUG)

            if domoticz.data.offInterno then
                -- Off provocado por el propio script (doble click): se ignora
                domoticz.data.offInterno = false

            elseif domoticz.data.estado[boton.name] then
                -- Se estaba regando: usamos el modo guardado al empezar, no el actual
                local cfgActiva = MODOS[domoticz.data.modoActivo]

                local consumo = domoticz.devices('CONTADOR AGUA').counter - domoticz.data.contadorInicial
                domoticz.notify('CONSUMO ' .. consumo .. ' m3*', '*Consumidos ' .. consumo .. ' m3*', domoticz.PRIORITY_LOW)
                domoticz.notify('RIEGOFF '.. boton.name, '*Riego ' .. boton.name .. ' terminado*', domoticz.PRIORITY_HIGH)
                domoticz.log(boton.name .. ' consumidos ' .. consumo .. ' m3*', domoticz.LOG_FORCE)

                domoticz.data.semaforo = false
                domoticz.data.estado[boton.name] = false
                domoticz.devices('EV-GENERAL').switchOff()

                if boton.name == 'HUERTO' then
                    TerminaHuerto(domoticz)
                elseif cfgActiva then
                    if boton.name == 'COMPLETO' or boton.name == 'CESPED' then
                        ParaGrupo(domoticz, cfgActiva.cesped)
                    end
                    if boton.name == 'COMPLETO' or boton.name == 'GOTEOS' then
                        ParaGrupo(domoticz, cfgActiva.goteos)
                    end
                else
                    domoticz.log('No hay modo activo guardado; solo se ha cerrado EV-GENERAL', domoticz.LOG_ERROR)
                end
            end
            -- Si no se cumple ninguna, el off viene del temporizador de otro botón: no se hace nada
        end
    end
}