-- SCD_Watchdog: vigilancia general del SCD: cada minuto revisa que ninguna EV (ni EV-GENERAL) lleve abierta mas tiempo del debido.
-- Clasifica quien la abrio sin necesitar datos de otros scripts:
--   CCR    -> el text-device "CCR_Watchdog" contiene "WDG:idx:seg" con el idx de esa EV (la CCR riega siempre en secuencia)
--   SCD    -> hay algun boton de grupo (COMPLETO, CESPED, GOTEOS, HUERTO) en On (el riego de grupo tambien es secuencial)
--   MANUAL -> ninguna de las dos: avisos a los 15-30-45 min (a los 60 corta el watchdog del Arduino); EV-GENERAL sigue cada 30 min desde los 60
-- El estado que ve Domoticz es el de la ultima orden, no el real del rele (no hay feedback CEV->SCD todavia):
-- por eso los avisos de >60 min dicen "figura abierta" y piden revisar, sin afirmar que el watchdog del Arduino ha fallado.
-- Caudal: si FLUJO AGUA (l/min) supera el umbral de forma sostenida se avisa (tuberia rota, grifo abierto, fuga).
-- Un circuito de EV consume 12-18 l/min. 0 l/min con una EV abierta NO es error en casa (bypass abierto),
-- pero SI lo es en un riego de grupo estando fuera (MODO-RIEGO = CORDOBA*): ahi el bypass debe estar cerrado.

local EVS = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO', 'EV-PIEDRAS', 'EV-PATIO',
              'EV-ROCALLA', 'EV-GOTEOOLIVO', 'EV-GOTEOALTO', 'EV-GOTEOBAJO' }
local GENERAL = 'EV-GENERAL'
local BOTONES = { 'COMPLETO', 'CESPED', 'GOTEOS', 'HUERTO' }

-- AJUSTAR
local SINC_BOTONES   = { 'SINC-EXT', 'SINC-INT' } -- botones que piden a cada Arduino su estado real de reles
local SINC_ESPERA_S   = 50   -- s que se espera tras pedir la sincronizacion antes de dar el aviso de 62 min
local ESCALONES_MANUAL = { 15, 30, 45 } -- min: avisos por EV abierta a mano (a los 60 min corta el watchdog del Arduino)
local GRACIA_ARRANQUE   = 180  -- s tras arrancar Domoticz sin vigilar (los estados no son fiables)
local MARGEN_CCR_MIN    = 5    -- min sobre el tiempo del WDG antes de avisar de que la EV sigue On
local LIMITE_EV_MIN     = 62   -- min maximo de cualquier EV de riego abierta, sea cual sea su origen (el Arduino corta a los 60)
local REAVISO_ARDUINO_MIN = 30 -- min entre avisos mientras siga abierta pasado el limite
local LIMITE_GRUPO_MIN  = 180  -- min maximo con un boton de grupo en On
local LIMITE_GENERAL_MIN = 180 -- min maximo de EV-GENERAL en un riego de la CCR o de grupo
local CAUDAL_MAX_LMIN   = 25   -- l/min: umbral de aviso con una o mas EV de riego abiertas
local CAUDAL_CERRADO    = 1    -- l/min: umbral con EV-GENERAL y todas las EV de riego cerradas (EV atascada, fuga)
local CAUDAL_EXTRA_EV   = 18   -- l/min que se suman al umbral por cada EV de riego abierta adicional (apertura manual de varias)
local CAUDAL_MUESTRAS   = 2    -- minutos seguidos por encima del umbral antes de avisar (con EV abierta)
local CAUDAL_MUESTRAS_CERRADO = 5 -- idem sin EV de riego abierta: da tiempo a que se vacie la tuberia tras un riego
local CAUDAL_REAVISO    = 15   -- min entre avisos mientras siga el exceso
local CAUDAL_EDAD_MAX   = 10   -- min: si FLUJO AGUA no se actualiza en este tiempo, su valor se ignora
local CAUDAL_MIN_RIEGO  = 5    -- l/min: por debajo, un riego de grupo estando fuera de casa se considera sin caudal
local SIN_CAUDAL_MUESTRAS = 3  -- minutos seguidos sin caudal antes de avisar
local SIN_CAUDAL_ESPERA_MIN = 2 -- min que debe llevar abierta una EV antes de exigirle caudal

-- Presencia segun el selector MODO-RIEGO (nombres EXACTOS, los mismos que la tabla MODOS de GruposRiego_factorizado):
-- true = en casa (bypass del medidor normalmente abierto: caudal 0); false = fuera (bypass cerrado, el medidor mide)
local EN_CASA = {
    ['VERANO']         = true,
    ['VERANO-HUERTO']  = true,
    ['CORDOBA']        = false,
    ['CORDOBA-HUERTO'] = false
}

-- Pide a los Arduino que envien el estado real de sus reles (pseudo-reles SINC-EXT y SINC-INT).
-- Devuelve false si no existe ninguno de los botones (no se puede verificar).
local function pideSync(domoticz)
    local hay = false
    for _, n in ipairs(SINC_BOTONES) do
        local d = domoticz.devices(n)
        if d then
            d.switchOn()
            hay = true
        end
    end
    return hay
end

-- Marca que se ha avisado de 'nivel' para ese dispositivo y clave. Devuelve true solo si el nivel sube (aviso nuevo)
local function marca(domoticz, nombre, clave, nivel)
    local av = domoticz.data.avisos[nombre]
    if not av then
        av = {}
        domoticz.data.avisos[nombre] = av
    end
    if nivel > (av[clave] or 0) then
        av[clave] = nivel
        return true
    end
    return false
end

-- Aviso sin repeticion: solo si el nivel sube respecto al ultimo avisado para ese dispositivo y clave
local function avisa(domoticz, nombre, clave, nivel, subject, msg, prioridad)
    if marca(domoticz, nombre, clave, nivel) then
        domoticz.log(msg, domoticz.LOG_ERROR)
        domoticz.notify(subject, msg, prioridad)
    end
end

-- Escalon alcanzado por una apertura manual (0 si ninguno). EV-GENERAL no tiene corte automatico:
-- pasados los escalones sigue avisando cada 30 min a partir de los 60.
local function nivelManual(minutos, esGeneral)
    local nivel = 0
    for _, e in ipairs(ESCALONES_MANUAL) do
        if minutos >= e then nivel = e end
    end
    if esGeneral and minutos >= 60 then
        nivel = 60 + 30 * math.floor((minutos - 60) / 30)
    end
    return nivel
end

-- Apertura manual de EV-GENERAL
local function avisoManualGeneral(domoticz, minutos)
    local nivel = nivelManual(minutos, true)
    if nivel == 0 then return end
    local msg = GENERAL .. ' abierta a mano desde hace ' .. math.floor(minutos) .. ' min'
    if nivel >= 60 then
        avisa(domoticz, GENERAL, 'manual', nivel, 'RIEGOERROR',
              '*' .. msg .. ' (EV-GENERAL no tiene corte automatico): cerrar*', domoticz.PRIORITY_HIGH)
    else
        avisa(domoticz, GENERAL, 'manual', nivel, 'RIEGOINFO', '*' .. msg .. ' (posible olvido)*', domoticz.PRIORITY_NORMAL)
    end
end

return {
    on = {
        timer = { 'every minute' },
        system = { 'start' }
    },
    logging = {
        level = domoticz.LOG_ERROR,
        --level = domoticz.LOG_DEBUG,
        marker = '* SCD_WATCHDOG *'
    },
    data = {
        abiertaDesde = { initial = {} },  -- nombre -> epoch en que se vio abierta por primera vez
        avisos       = { initial = {} },  -- nombre -> { clave = ultimo nivel avisado }
        tArranque    = { initial = 0 },
        multi        = { initial = 0 },   -- muestras seguidas con varias EV abiertas a la vez
        generalSola  = { initial = 0 },   -- muestras seguidas con EV-GENERAL sola (sin EV de riego ni origen conocido)
        sincPedida   = { initial = {} },  -- nombre -> epoch en que se pidio la sincronizacion antes de avisar de >62 min
        excesoCaudal = { initial = 0 },   -- minutos seguidos con caudal por encima del umbral
        sinCaudal    = { initial = 0 }    -- minutos seguidos de riego de grupo fuera de casa sin caudal
    },
    execute = function(domoticz, item)
        local ahora = os.time()

        if item.isSystemEvent then
            domoticz.data.tArranque = ahora
            domoticz.data.abiertaDesde = {}
            domoticz.data.avisos = {}
            domoticz.data.sincPedida = {}
            domoticz.data.multi = 0
            domoticz.data.generalSola = 0
            domoticz.data.excesoCaudal = 0
            domoticz.data.sinCaudal = 0
            return
        end

        if ahora - domoticz.data.tArranque < GRACIA_ARRANQUE then
            return
        end

        -- 1. Que esta abierto y desde cuando
        local function abierta(nombre)
            local dev = domoticz.devices(nombre)
            if dev and dev.bState then
                if not domoticz.data.abiertaDesde[nombre] then
                    domoticz.data.abiertaDesde[nombre] = ahora
                end
                return true
            end
            domoticz.data.abiertaDesde[nombre] = nil
            domoticz.data.avisos[nombre] = nil
            domoticz.data.sincPedida[nombre] = nil
            return false
        end
        local function minutos(nombre)
            return (ahora - domoticz.data.abiertaDesde[nombre]) / 60
        end

        local abiertas = {}
        for _, nombre in ipairs(EVS) do
            if abierta(nombre) then abiertas[#abiertas + 1] = nombre end
        end
        local generalAbierta = abierta(GENERAL)
        local botonesOn = {}
        for _, nombre in ipairs(BOTONES) do
            if abierta(nombre) then botonesOn[#botonesOn + 1] = nombre end
        end

        -- 2. Origen
        local ccrIdx, ccrSeg
        local wdg = domoticz.devices('CCR_Watchdog')
        if wdg then
            local i, s = tostring(wdg.text or ''):match('^WDG:(%d+):(%d+)$')
            if i and tonumber(s) > 0 then
                ccrIdx, ccrSeg = tonumber(i), tonumber(s)
            end
        end
        local hayCCR = ccrIdx ~= nil
        -- Presencia segun MODO-RIEGO (ver EN_CASA). Solo es 'en casa' si el modo figura como tal
        local mdev = domoticz.devices('MODO-RIEGO')
        local enCasa = mdev and EN_CASA[mdev.levelName]
        local enCasaSeguro = (enCasa == true)
        local hayGrupo = #botonesOn > 0

        -- 3. Cada EV de riego abierta segun su origen
        local pendManual, maxNivelManual = {}, 0
        for _, nombre in ipairs(abiertas) do
            local min = minutos(nombre)
            if hayCCR and domoticz.devices(nombre).id == ccrIdx then
                if min > ccrSeg / 60 + MARGEN_CCR_MIN then
                    avisa(domoticz, nombre, 'ccr', 1, 'RIEGOERROR',
                          '*' .. nombre .. ' sigue abierta ' .. math.floor(min) .. ' min tras un riego de la CCR de ' ..
                          math.floor(ccrSeg / 60) .. ' min: revisar*', domoticz.PRIORITY_HIGH)
                end
            elseif hayGrupo then
                -- riego de grupo: sin aviso propio de tiempo (lo cubre el limite general de 62 min de mas abajo)
            else
                -- apertura manual: se avisa una sola vez por escalon, agrupando todas las EV que lo alcanzan en este minuto
                local nivel = nivelManual(min, false)
                if nivel > 0 and marca(domoticz, nombre, 'manual', nivel) then
                    pendManual[#pendManual + 1] = nombre .. ' (' .. math.floor(min) .. ' min)'
                    if nivel > maxNivelManual then maxNivelManual = nivel end
                end
            end
        end

        -- 3b. Cualquier EV de riego (salvo la general) abierta mas de LIMITE_EV_MIN: no ha actuado el watchdog del Arduino.
        --     Antes de avisar se piden los estados reales a los Arduino (SINC-EXT/INT) y se espera al siguiente minuto:
        --     si el Arduino ya la habia cerrado y solo se perdio su notificacion, Domoticz la pasa a Off y no se avisa.
        for _, nombre in ipairs(abiertas) do
            local min = minutos(nombre)
            if min > LIMITE_EV_MIN then
                local pedida = domoticz.data.sincPedida[nombre]
                if not pedida and pideSync(domoticz) then
                    domoticz.data.sincPedida[nombre] = ahora
                elseif not pedida or ahora - pedida >= SINC_ESPERA_S then
                    local nivel = 1 + math.floor((min - LIMITE_EV_MIN) / REAVISO_ARDUINO_MIN)
                    avisa(domoticz, nombre, 'arduino', nivel, 'RIEGOERROR',
                          '*' .. nombre .. ' lleva ' .. math.floor(min) .. ' min abierta (mas de 60)' ..
                          (pedida and ', tambien tras sincronizar con los Arduino' or '') .. ': posible fallo del watchdog*',
                          domoticz.PRIORITY_HIGH)
                end
            end
        end

        if #pendManual > 0 then
            local ultimo = maxNivelManual >= ESCALONES_MANUAL[#ESCALONES_MANUAL]
            local msg = '*Abierta a mano: ' .. table.concat(pendManual, ', ') .. ' - posible olvido' ..
                        (ultimo and ' (a los 60 min corta el watchdog del Arduino)' or '') .. '*'
            domoticz.log(msg, domoticz.LOG_ERROR)
            domoticz.notify('RIEGOINFO', msg, ultimo and domoticz.PRIORITY_HIGH or domoticz.PRIORITY_NORMAL)
        end

        -- 4. Botones de grupo
        for _, nombre in ipairs(botonesOn) do
            local min = minutos(nombre)
            if min > LIMITE_GRUPO_MIN then
                avisa(domoticz, nombre, 'tope', 1, 'RIEGOERROR',
                      '*Boton ' .. nombre .. ' en On desde hace ' .. math.floor(min) .. ' min: revisar*', domoticz.PRIORITY_HIGH)
            end
        end

        -- 5. EV-GENERAL
        local sola = generalAbierta and #abiertas == 0 and not hayGrupo and not hayCCR
        domoticz.data.generalSola = sola and (domoticz.data.generalSola + 1) or 0
        if generalAbierta then
            local min = minutos(GENERAL)
            if sola then
                -- dos muestras seguidas, para no confundir el hueco entre dos EV de una secuencia con apertura manual
                -- en casa (VERANO*) la general abierta sola puede ser consumo normal: no se avisa
                if domoticz.data.generalSola >= 2 and not enCasaSeguro then
                    avisoManualGeneral(domoticz, min)
                end
            elseif min > LIMITE_GENERAL_MIN then
                avisa(domoticz, GENERAL, 'tope', 1, 'RIEGOERROR',
                      '*EV-GENERAL abierta ' .. math.floor(min) .. ' min: revisar*', domoticz.PRIORITY_HIGH)
            end
        end

        -- 6. Varias EV a la vez fuera de un riego manual: la CCR y los grupos riegan en secuencia
        local anomalo = #abiertas > 1 and (hayCCR or hayGrupo)
        domoticz.data.multi = anomalo and (domoticz.data.multi + 1) or 0
        if domoticz.data.multi >= 2 then
            avisa(domoticz, '_anomalia', 'multi', 1, 'RIEGOERROR',
                  '*Varias EV abiertas a la vez en un riego secuencial: ' .. table.concat(abiertas, ', ') .. '*',
                  domoticz.PRIORITY_HIGH)
        elseif domoticz.data.multi == 0 then
            domoticz.data.avisos['_anomalia'] = nil
        end

        -- 7. Caudal excesivo (FLUJO AGUA, l/min). Solo se avisa por valores altos: 0 l/min no significa nada
        local fdev = domoticz.devices('FLUJO AGUA')
        local flujo
        if fdev and fdev.lastUpdate.minutesAgo <= CAUDAL_EDAD_MAX then
            flujo = fdev.flow
            if flujo == nil then flujo = tonumber(fdev.sensorValue) end
            if flujo == nil and fdev.rawData then flujo = tonumber(fdev.rawData[1]) end
        end
        -- EV-GENERAL esta en serie con el medidor y un bypass manual rodea a ambos.
        -- Con la casa habitada el bypass esta abierto: caudal 0 y EV-GENERAL Off (la CCR no la toca).
        -- Con el medidor en linea: EV-GENERAL cerrada => no puede pasar agua; cualquier caudal es fallo (EV atascada, fuga).
        local sinEV = #abiertas == 0
        local generalCerrada = not generalAbierta
        local umbral, muestras
        if sinEV and generalCerrada then
            umbral, muestras = CAUDAL_CERRADO, CAUDAL_MUESTRAS_CERRADO
        elseif sinEV then
            -- EV-GENERAL abierta sin ninguna EV de riego: en casa es consumo normal (sin aviso);
            -- fuera, solo se avisa por caudal alto
            umbral, muestras = (enCasaSeguro and math.huge or CAUDAL_MAX_LMIN), CAUDAL_MUESTRAS_CERRADO
        else
            umbral, muestras = CAUDAL_MAX_LMIN + CAUDAL_EXTRA_EV * (#abiertas - 1), CAUDAL_MUESTRAS
        end
        domoticz.log('Caudal ' .. tostring(flujo) .. ' l/min, umbral ' .. umbral .. ', EV abiertas ' .. #abiertas, domoticz.LOG_DEBUG)
        if flujo and flujo >= umbral then
            domoticz.data.excesoCaudal = domoticz.data.excesoCaudal + 1
            if domoticz.data.excesoCaudal >= muestras then
                local nivel = 1 + math.floor((domoticz.data.excesoCaudal - muestras) / CAUDAL_REAVISO)
                local msg
                if sinEV and generalCerrada then
                    msg = '*Caudal de ' .. flujo .. ' l/min con EV-GENERAL y todas las EV de riego cerradas (umbral ' .. umbral .. '): EV sin cerrar o fuga*'
                elseif sinEV then
                    msg = '*Caudal de ' .. flujo .. ' l/min con EV-GENERAL abierta y ninguna EV de riego abierta (umbral ' .. umbral .. '): fuga o uso de la casa*'
                else
                    msg = '*Caudal excesivo: ' .. flujo .. ' l/min (umbral ' .. umbral .. ') con ' .. table.concat(abiertas, ', ') .. '*'
                end
                avisa(domoticz, '_caudal', 'exceso', nivel, 'RIEGOERROR', msg, domoticz.PRIORITY_HIGH)
            end
        else
            domoticz.data.excesoCaudal = 0
            domoticz.data.avisos['_caudal'] = nil
        end

        -- 8. Riego de grupo fuera de casa sin caudal: el bypass deberia estar cerrado y el medidor marcar 12-18 l/min.
        --    Posibles causas: bypass abierto (riego sin medir), EV que no abre o suministro cortado.
        local sinCaudalAhora = false
        if enCasa == false and hayGrupo and generalAbierta and #abiertas > 0 and flujo and flujo < CAUDAL_MIN_RIEGO then
            sinCaudalAhora = true
            for _, nombre in ipairs(abiertas) do
                if minutos(nombre) < SIN_CAUDAL_ESPERA_MIN then sinCaudalAhora = false end
            end
        end
        domoticz.data.sinCaudal = sinCaudalAhora and (domoticz.data.sinCaudal + 1) or 0
        if domoticz.data.sinCaudal >= SIN_CAUDAL_MUESTRAS then
            avisa(domoticz, '_sincaudal', 'sin', 1, 'RIEGOERROR',
                  '*Riego de grupo ' .. table.concat(botonesOn, ', ') .. ' con ' .. table.concat(abiertas, ', ') ..
                  ' abierta y caudal ' .. flujo .. ' l/min (esperado 12-18): bypass abierto, EV sin abrir o suministro cortado*',
                  domoticz.PRIORITY_NORMAL)
        elseif domoticz.data.sinCaudal == 0 then
            domoticz.data.avisos['_sincaudal'] = nil
        end
    end
}
