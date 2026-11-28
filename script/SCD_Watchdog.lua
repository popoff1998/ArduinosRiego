-- SCD_Watchdog: vigilancia general del SCD: cada minuto revisa que ninguna EV (ni EV-GENERAL) lleve abierta mas tiempo del debido.
-- Clasifica quien la abrio sin necesitar datos de otros scripts:
--   CCR    -> el text-device "CCR_Watchdog" contiene "WDG:idx:seg" con el idx de esa EV (la CCR riega siempre en secuencia)
--   SCD    -> hay algun boton de grupo (COMPLETO, CESPED, GOTEOS, HUERTO) en On (el riego de grupo tambien es secuencial)
--   MANUAL -> ninguna de las dos: avisos a los 15-30-45 min (a los 60 corta el watchdog del Arduino); EV-GENERAL sigue cada 30 min desde los 60
-- El estado que ve Domoticz es el de la ultima orden o el ultimo que notifico el Arduino (tambien notifica el Off cuando corta a los 60 min).
-- Antes del aviso de >60 min se pide el estado real a los Arduino con los pseudo-reles SYNC-EXT/SYNC-INT (opcional: SYNC_ANTES_AVISO).
-- Caudal: si FLUJO AGUA (l/min) supera el umbral de forma sostenida se avisa (tuberia rota, grifo abierto, fuga).
-- Un circuito de EV consume 12-18 l/min. 0 l/min con una EV abierta NO es error en casa (bypass abierto),
-- pero SI lo es en un riego de grupo estando fuera (MODO-RIEGO = CORDOBA*): ahi el bypass debe estar cerrado.

local EVS = { 'EV-TURBINAS', 'EV-PORCHE', 'EV-CUARTILLO', 'EV-PIEDRAS', 'EV-PATIO',
              'EV-ROCALLA', 'EV-GOTEOOLIVO', 'EV-GOTEOALTO', 'EV-GOTEOBAJO' }
local GENERAL = 'EV-GENERAL'
local BOTONES = { 'COMPLETO', 'CESPED', 'GOTEOS', 'HUERTO' }
local SYNC_BOTONES   = { 'SYNC-EXT', 'SYNC-INT' } -- pseudo-reles que piden a cada Arduino su estado real de reles

local TODAS = {}  -- todas las EV de riego mas la general
for _, n in ipairs(EVS) do TODAS[#TODAS + 1] = n end
TODAS[#TODAS + 1] = GENERAL

-- Cierre automatico: si CIERRE_AUTOMATICO = true, los avisos RIEGOERROR de abajo ademas mandan Off a la(s) EV afectada(s).
-- El cierre se envia junto con cada aviso (se repite cuando el aviso se repite). Cada tipo se puede activar/desactivar:
--   ccr              EV sigue abierta tras vencer el tiempo del WDG de la CCR      -> Off a esa EV
--   arduino          EV abierta > LIMITE_EV_MIN (fallo del watchdog del Arduino)   -> Off a esa EV
--   tope_grupo       boton de grupo en On > LIMITE_GRUPO_MIN                        -> Off al boton (GruposRiego cierra el grupo)
--   tope_general     EV-GENERAL abierta > LIMITE_GENERAL_MIN con riego              -> Off a EV-GENERAL
--   general_olvidada EV-GENERAL abierta sola >= 60 min fuera de casa                -> Off a EV-GENERAL
--   multi            varias EV abiertas a la vez en un riego secuencial             -> Off a todas las EV de riego abiertas
--   caudal_ev        caudal excesivo con EV(s) de riego abiertas                    -> Off a esas EV
--   caudal_general   caudal alto con solo EV-GENERAL abierta (fuera de casa)        -> Off a EV-GENERAL
--   caudal_cerrado   caudal con todo cerrado (EV sin cerrar o fuga)                 -> Off a todas las EV de riego y a EV-GENERAL
-- El aviso de riego sin caudal (bypass abierto, EV sin abrir) nunca cierra nada.
local CIERRE_AUTOMATICO = false
local CIERRA_EN_ERROR = {
    ccr = true, arduino = true, tope_grupo = true, tope_general = true, general_olvidada = true,
    multi = true, caudal_ev = true, caudal_general = true, caudal_cerrado = true
}
-- AJUSTAR
local SYNC_ANTES_AVISO = true -- true: antes del aviso de LIMITE_EV_MIN se pide el SYNC y se avisa solo si la EV sigue On; false: se avisa directamente
local SYNC_ESPERA_S   = 50   -- s que se espera tras pedir la sincronizacion antes de dar el aviso de 62 min
local ESCALONES_MANUAL = { 15, 30, 45 } -- min: avisos por EV abierta a mano (a los 60 min corta el watchdog del Arduino)
local GRACIA_ARRANQUE   = 180  -- s tras arrancar Domoticz sin vigilar (los estados no son fiables)
local MARGEN_CCR_MIN    = 5    -- min sobre el tiempo del WDG antes de avisar de que la EV sigue On
local REAVISO_CCR_MIN   = 15   -- min entre avisos mientras siga abierta una EV de la CCR pasado ese tiempo
local LIMPIA_TEXTO_CCR  = true -- true: si el text-device CCR_Watchdog conserva "WDG:idx:seg" y esa EV esta cerrada, se limpia (WDG:idx:-1)
local LIMPIA_TEXTO_MARGEN_S = 60 -- s que debe tener el texto, sobre su tiempo, antes de limpiarlo (evita pisar un riego recien iniciado)
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

-- *****************************
--    FUNCIONES AUXILIARES
-- *****************************

-- Pide a los Arduino que envien el estado real de sus reles (pseudo-reles SYNC-EXT y SYNC-INT).
-- Devuelve false si no existe ninguno de los botones (no se puede verificar).
local function pideSync(domoticz)
    local hay = false
    for _, n in ipairs(SYNC_BOTONES) do
        local d = domoticz.devices(n)
        if d then
            d.switchOn()
            hay = true
        end
    end
    return hay
end

-- Asigna a domoticz.data solo si el valor cambia (evita escrituras innecesarias en la base de datos)
local function setData(domoticz, clave, valor)
    if domoticz.data[clave] ~= valor then
        domoticz.data[clave] = valor
    end
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
-- 'tipo' y 'cerrar' (lista de dispositivos) son opcionales: si el cierre automatico esta activo para ese tipo,
-- se manda Off a esos dispositivos y se anota en el mensaje.
local function avisa(domoticz, nombre, clave, nivel, subject, msg, prioridad, tipo, cerrar)
    if marca(domoticz, nombre, clave, nivel) then
        if CIERRE_AUTOMATICO and tipo and CIERRA_EN_ERROR[tipo] and cerrar and #cerrar > 0 then
            local lista = {}
            for _, n in ipairs(cerrar) do
                local d = domoticz.devices(n)
                if d then
                    d.switchOff()
                    lista[#lista + 1] = n
                end
            end
            if #lista > 0 then
                msg = (msg:gsub('%*$', '')) .. ' - cierre automatico: ' .. table.concat(lista, ', ') .. '*'
            end
        end
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
              '*' .. msg .. ' (EV-GENERAL no tiene corte automatico): cerrar*', domoticz.PRIORITY_HIGH,
              'general_olvidada', { GENERAL })
    else
        avisa(domoticz, GENERAL, 'manual', nivel, 'RIEGOINFO', '*' .. msg .. ' (posible olvido)*', domoticz.PRIORITY_NORMAL)
    end
end

-- ***************************
--        PRINCIPAL
-- ***************************

return {
    on = {
        timer = { 'every minute' },
        system = { 'start' }
    },
    logging = {
        level = domoticz.LOG_INFO,
        --level = domoticz.LOG_DEBUG,
        marker = '* SCD_WATCHDOG *'
    },
    data = {
        abiertaDesde = { initial = {} },  -- nombre -> epoch en que se vio abierta por primera vez
        avisos       = { initial = {} },  -- nombre -> { clave = ultimo nivel avisado }
        tArranque    = { initial = 0 },
        multi        = { initial = 0 },   -- muestras seguidas con varias EV abiertas a la vez
        generalSola  = { initial = 0 },   -- muestras seguidas con EV-GENERAL sola (sin EV de riego ni origen conocido)
        syncPedida   = { initial = {} },  -- nombre -> epoch en que se pidio la sincronizacion antes de avisar de >62 min
        excesoCaudal = { initial = 0 },   -- minutos seguidos con caudal por encima del umbral
        sinCaudal    = { initial = 0 }    -- minutos seguidos de riego de grupo fuera de casa sin caudal
    },
    execute = function(domoticz, item)
        local ahora = os.time()

        if item.isSystemEvent then
            -- abiertaDesde y avisos se conservan: las EV solo las cierra el SCD (o el corte de 60 min del Arduino),
            -- asi que la hora de apertura guardada sigue siendo valida y se cuenta el tiempo real, parada incluida.
            -- Las EV que ya esten cerradas tras el SYNC se limpian solas en la primera pasada tras la gracia.
            domoticz.data.tArranque = ahora
            domoticz.data.syncPedida = {}
            domoticz.data.multi = 0
            domoticz.data.generalSola = 0
            domoticz.data.excesoCaudal = 0
            domoticz.data.sinCaudal = 0
            return
        end

        -- 0. Si no ha pasado el tiempo de gracia tras el arranque no hace nada
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
            if domoticz.data.abiertaDesde[nombre] ~= nil or domoticz.data.avisos[nombre] ~= nil
               or domoticz.data.syncPedida[nombre] ~= nil then
                domoticz.data.abiertaDesde[nombre] = nil
                domoticz.data.avisos[nombre] = nil
                domoticz.data.syncPedida[nombre] = nil
            end
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
        -- Un texto "WDG:idx:seg" pendiente solo tiene sentido mientras la EV siga abierta. Si Domoticz la ve cerrada y el texto es
        -- mas antiguo que su tiempo (+ margen), se limpia con el propio mensaje del protocolo (WDG:idx:-1): CCR_Watchdog borra
        -- asi su entrada y SCD_Watchdog deja de tratar esa EV como riego de la CCR.
        if ccrIdx and LIMPIA_TEXTO_CCR and wdg.lastUpdate and wdg.lastUpdate.secondsAgo > ccrSeg + LIMPIA_TEXTO_MARGEN_S then
            local nombreCCR
            for _, nombre in ipairs(EVS) do
                local d = domoticz.devices(nombre)
                if d and d.id == ccrIdx then nombreCCR = nombre end
            end
            if nombreCCR then
                local abierta = false
                for _, nombre in ipairs(abiertas) do
                    if nombre == nombreCCR then abierta = true end
                end
                if not abierta then
                    wdg.updateText('WDG:' .. ccrIdx .. ':-1')
                    domoticz.log('Limpiado texto WDG pendiente de ' .. nombreCCR .. ' (cerrada en Domoticz)', domoticz.LOG_INFO)
                    ccrIdx, ccrSeg = nil, nil
                end
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
                local limiteCCR = ccrSeg / 60 + MARGEN_CCR_MIN
                if min > limiteCCR then
                    avisa(domoticz, nombre, 'ccr', 1 + math.floor((min - limiteCCR) / REAVISO_CCR_MIN), 'RIEGOERROR',
                          '*' .. nombre .. ' sigue abierta ' .. math.floor(min) .. ' min tras un riego de la CCR de ' ..
                          math.floor(ccrSeg / 60) .. ' min: revisar*', domoticz.PRIORITY_HIGH,
                          'ccr', { nombre })
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
        --     Si SYNC_ANTES_AVISO, antes de avisar se piden los estados reales a los Arduino (SYNC-EXT/INT) y se espera SYNC_ESPERA_S:
        --     si el Arduino ya la habia cerrado y solo se perdio su notificacion, Domoticz la pasa a Off y no se avisa.
        for _, nombre in ipairs(abiertas) do
            local min = minutos(nombre)
            if min > LIMITE_EV_MIN then
                local pedida = domoticz.data.syncPedida[nombre]
                if SYNC_ANTES_AVISO and not pedida and pideSync(domoticz) then
                    domoticz.data.syncPedida[nombre] = ahora
                elseif not pedida or ahora - pedida >= SYNC_ESPERA_S then
                    local nivel = 1 + math.floor((min - LIMITE_EV_MIN) / REAVISO_ARDUINO_MIN)
                    avisa(domoticz, nombre, 'arduino', nivel, 'RIEGOERROR',
                          '*' .. nombre .. ' lleva ' .. math.floor(min) .. ' min abierta (mas de 60)' ..
                          (pedida and ', tambien tras sincronizar con los Arduino' or '') .. ': posible fallo del watchdog*',
                          domoticz.PRIORITY_HIGH, 'arduino', { nombre })
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
                      '*Boton ' .. nombre .. ' en On desde hace ' .. math.floor(min) .. ' min: revisar*', domoticz.PRIORITY_HIGH,
                      'tope_grupo', { nombre })
            end
        end

        -- 5. EV-GENERAL
        local sola = generalAbierta and #abiertas == 0 and not hayGrupo and not hayCCR
        setData(domoticz, 'generalSola', sola and (domoticz.data.generalSola + 1) or 0)
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
                      '*EV-GENERAL abierta ' .. math.floor(min) .. ' min: revisar*', domoticz.PRIORITY_HIGH,
                      'tope_general', { GENERAL })
            end
        end

        -- 6. Varias EV a la vez fuera de un riego manual: la CCR y los grupos riegan en secuencia
        local anomalo = #abiertas > 1 and (hayCCR or hayGrupo)
        setData(domoticz, 'multi', anomalo and (domoticz.data.multi + 1) or 0)
        if domoticz.data.multi >= 2 then
            avisa(domoticz, '_anomalia', 'multi', 1, 'RIEGOERROR',
                  '*Varias EV abiertas a la vez en un riego secuencial: ' .. table.concat(abiertas, ', ') .. '*',
                  domoticz.PRIORITY_HIGH, 'multi', abiertas)
        elseif domoticz.data.multi == 0 and domoticz.data.avisos['_anomalia'] then
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
            setData(domoticz, 'excesoCaudal', domoticz.data.excesoCaudal + 1)
            if domoticz.data.excesoCaudal >= muestras then
                local nivel = 1 + math.floor((domoticz.data.excesoCaudal - muestras) / CAUDAL_REAVISO)
                local msg, tipo, cerrar
                if sinEV and generalCerrada then
                    tipo, cerrar = 'caudal_cerrado', TODAS
                    msg = '*Caudal de ' .. flujo .. ' l/min con EV-GENERAL y todas las EV de riego cerradas (umbral ' .. umbral .. '): EV sin cerrar o fuga*'
                elseif sinEV then
                    tipo, cerrar = 'caudal_general', { GENERAL }
                    msg = '*Caudal de ' .. flujo .. ' l/min con EV-GENERAL abierta y ninguna EV de riego abierta (umbral ' .. umbral .. '): fuga o uso de la casa*'
                else
                    tipo, cerrar = 'caudal_ev', abiertas
                    msg = '*Caudal excesivo: ' .. flujo .. ' l/min (umbral ' .. umbral .. ') con ' .. table.concat(abiertas, ', ') .. '*'
                end
                avisa(domoticz, '_caudal', 'exceso', nivel, 'RIEGOERROR', msg, domoticz.PRIORITY_HIGH, tipo, cerrar)
            end
        else
            setData(domoticz, 'excesoCaudal', 0)
            if domoticz.data.avisos['_caudal'] then domoticz.data.avisos['_caudal'] = nil end
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
        setData(domoticz, 'sinCaudal', sinCaudalAhora and (domoticz.data.sinCaudal + 1) or 0)
        if domoticz.data.sinCaudal >= SIN_CAUDAL_MUESTRAS then
            avisa(domoticz, '_sincaudal', 'sin', 1, 'RIEGOERROR',
                  '*Riego de grupo ' .. table.concat(botonesOn, ', ') .. ' con ' .. table.concat(abiertas, ', ') ..
                  ' abierta y caudal ' .. flujo .. ' l/min (esperado 12-18): bypass abierto, EV sin abrir o suministro cortado*',
                  domoticz.PRIORITY_NORMAL)
        elseif domoticz.data.sinCaudal == 0 and domoticz.data.avisos['_sincaudal'] then
            domoticz.data.avisos['_sincaudal'] = nil
        end
    end
}