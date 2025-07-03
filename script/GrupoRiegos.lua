-- Los modos de riego pueden ser: VERANO, VERANO-HUERTO, CORDOBA, CORDOBA-HUERTO
-- Es importante que en la variable se use EXACTAMENTE el texto tal cual se pone aquí.
-- Ver las tablas de abajo para ver los circuitos de riego activados para cada modo



-- Para pruebas pongo a false
--abreGeneralabreGeneral = false
abreGeneral = true

-- Funciones de riego, terminacion y apertura de valvula general

local function RiegaHuerto(domoticz,tRiego)
    domoticz.devices('EV-GOTEOOLIVO').switchOn().afterMin(0).forMin(tRiego)
end
        
local function TerminaHuerto(domoticz)
    domoticz.devices('EV-GOTEOOLIVO').switchOff()
end

local function RiegaCesped(domoticz,delay,tRiego)
    for key,currentDevice in pairs(tablaCESPED) do
        domoticz.devices(currentDevice).switchOn().afterMin(delay).forMin(tRiego)
        delay  =  delay + tRiego
    end
end
        
local function TerminaCesped(domoticz)
    for key,currentDevice in pairs(tablaCESPED) do
        domoticz.devices(currentDevice).switchOff()
    end
end

local function RiegaGoteos(domoticz,delay,tRiego,tPatio)
    for key,currentDevice in pairs(tablaGOTEOS) do
        if(currentDevice == 'EV-PATIO') then
            _tRiego = tPatio
        else 
            _tRiego = tRiego
        end
        domoticz.devices(currentDevice).switchOn().afterMin(delay).forMin(_tRiego)
        delay  =  delay + _tRiego
    end
end

local function TerminaGoteos(domoticz)
    for key,currentDevice in pairs(tablaGOTEOS) do
        domoticz.devices(currentDevice).switchOff()
    end
end


local function AbreGeneral(domoticz,tiempo)
    if(abreGeneral) then
        domoticz.devices('EV-GENERAL').switchOn().forMin(tiempo)
    else
        domoticz.log('** abreGeneral es False: Tiempo de cierre es ' .. tiempo * 60 .. ' segundos **')
    end
end

-- Programa principal
return {
    active = true,
	on = {
		devices = {
		    'COMPLETO',
			'CESPED',
			'GOTEOS',
			'HUERTO'
		}
	},
	logging = {
	    level = domoticz.LOG_DEBUG,
	    marker = "MYDEBUG"
	},
	data = {
	    -- semaforo controlara si se esta regando en un riego de grupo
	    semaforo = { initial = false },
	    -- offInterno conrolara si ha sido el propio script quien ha apagado el boton
	    offInterno = { initial = false },
	    -- Almacenará el contador de agua al comenzar el riego
        contadorInicial = { initial = 0 },
        -- Tabla de estados de los botones
        estado = { initial = {['COMPLETO'] = false, ['CESPED'] = false, ['GOTEOS'] = false, ['HUERTO'] = false }}
	},
	execute = function(domoticz,boton)
	    
	    -- Leemos el modo de riego
	    modoRiego = domoticz.variables('MODO-RIEGO').value
        domoticz.log('MODO RIEGO ES ' .. modoRiego , domoticz.LOG_FORCE)

        -- Ajustamos las tablas de lo que hay que regar en funcion del modo
        if(modoRiego ==  'VERANO') then
            tablaCESPED = {'EV-TURBINAS' , 'EV-PORCHE' , 'EV-CUARTILLO'} 
            tablaGOTEOS = {'EV-GOTEOALTO' , 'EV-GOTEOBAJO' ,'EV-ROCALLA' , 'EV-GOTEOOLIVO'}
        elseif(modoRiego == 'VERANO-HUERTO') then
            tablaCESPED = {'EV-TURBINAS' , 'EV-PORCHE' , 'EV-CUARTILLO'} 
            tablaGOTEOS = {'EV-GOTEOALTO' , 'EV-GOTEOBAJO' ,'EV-ROCALLA'}
        elseif(modoRiego == 'CORDOBA') then
            tablaCESPED = {'EV-TURBINAS' , 'EV-PORCHE' , 'EV-CUARTILLO' , 'EV-PIEDRAS'} 
            tablaGOTEOS = {'EV-GOTEOALTO' , 'EV-GOTEOBAJO' ,'EV-ROCALLA' , 'EV-GOTEOOLIVO', 'EV-PATIO'}
        elseif(modoRiego == 'CORDOBA-HUERTO') then
            tablaCESPED = {'EV-TURBINAS' , 'EV-PORCHE' , 'EV-CUARTILLO' , 'EV-PIEDRAS'} 
            tablaGOTEOS = {'EV-GOTEOALTO' , 'EV-GOTEOBAJO' ,'EV-ROCALLA' , 'EV-PATIO'}
        end

        -- Leemos los valores de los tiempos salvo tPatio que leeremos despues si existe
        local tCesped = domoticz.variables('TIEMPO-CESPED').value
		local tGoteos = domoticz.variables('TIEMPO-GOTEOS').value
		local tHuerto = domoticz.variables('TIEMPO-HUERTO').value
		local tPatio = 0
		
		-- Contamos el numero de riegos
		local nriegosCESPED = 0
		local nriegosGOTEOS = 0

		for _ in pairs(tablaCESPED) do nriegosCESPED = nriegosCESPED + 1 end
		for k,v in pairs(tablaGOTEOS) do 
			if (v == 'EV-PATIO') then
		        tPatio = domoticz.variables('TIEMPO-PATIO').value
			else
				nriegosGOTEOS = nriegosGOTEOS + 1 
			end
		end

        -- EL BOTON SE ENCIENDE
        -- Antes que nada deshabilitamos los dobles clicks de botones de grupos
	    if(boton.state == 'On' and domoticz.data.semaforo) then
	        -- Mandamos la notificacion
	        domoticz.notify('RIEGOERROR','*Riego ' .. boton.name .. ' no activado por bloqueo de semaforo*',domoticz.PRIORITY_HIGH)
	        -- Comprobamos que no es un "rebote" por programacion
	        if(not domoticz.data.estado[boton.name]) then
	            domoticz.data.offInterno = true
                boton.switchOff()
            else
                domoticz.notify('RIEGOINFO','*Riego ' .. boton.name .. ' debia ser una programacion de un riego lanzado a mano antes*',domoticz.PRIORITY_HIGH)
            end
	    elseif(boton.state == 'On') then
	        -- Mandamos la notificacion
	        domoticz.notify('RIEGOON','*Riego ' .. boton.name .. ' comenzado modo ' .. modoRiego .. '*', domoticz.PRIORITY_HIGH)
            -- Habilitamos el semaforo
	        domoticz.data.semaforo = true
	        -- Cambiamos su estado
	        domoticz.data.estado[boton.name] = true
	        -- Leemos el contador
	        domoticz.data.contadorInicial = domoticz.devices('CONTADOR AGUA').counter
	        domoticz.log('CONTADOR: ' .. domoticz.data.contadorInicial,domoticz.LOG_FORCE)
	        -- Operamos segun el boton pulsado
	        if(boton.name == 'COMPLETO') then
			    tiempoTotal = (nriegosCESPED * tCesped) + (nriegosGOTEOS * tGoteos) + tPatio
                AbreGeneral(domoticz, tiempoTotal)
                RiegaCesped(domoticz,0,tCesped)
                RiegaGoteos(domoticz,nriegosCESPED * tCesped,tGoteos,tPatio)
                boton.switchOff().afterMin(tiempoTotal)            
	        elseif(boton.name == 'CESPED') then
                AbreGeneral(domoticz,nriegosCESPED * tCesped)
                RiegaCesped(domoticz,0,tCesped)
                boton.switchOff().afterMin(nriegosCESPED * tCesped)            
            elseif(boton.name == 'GOTEOS') then
                AbreGeneral(domoticz,(nriegosGOTEOS * tGoteos) + tPatio)
                RiegaGoteos(domoticz,0,tGoteos,tPatio)
                boton.switchOff().afterMin((nriegosGOTEOS * tGoteos) + tPatio)   
            elseif(boton.name == 'HUERTO') then
                AbreGeneral(domoticz,tHuerto)
                RiegaHuerto(domoticz,tHuerto)
                boton.switchOff().afterMin(tHuerto)   
            end
        end
        
        -- EL BOTON SE APAGA
	    if(boton.state == 'Off') then
            domoticz.log('DEVICE: ' .. boton.name .. 
                         ' Estados: ' .. tostring(domoticz.data.estado['COMPLETO']) .. 
                         ' ' .. tostring(domoticz.data.estado['CESPED']) .. 
                         ' ' .. tostring(domoticz.data.estado['GOTEOS']) ..
                         ' ' .. tostring(domoticz.data.estado['HUERTO']) ,
                         domoticz.LOG_FORCE)
	        if(domoticz.data.offInterno) then
                -- El off se ha producido por un doble click y lo ignoramos
                domoticz.data.offInterno = false
            -- PROBLEMA:    Aqui vamos a llegar tanto por el apagado a mano como por el apagado por el temporizador
            --              Hay que evitar que si llegamos por el temporizador de alguno que se apago a mano
            --              se cumpla la condicion ya que semaforo pertenece a otro boton distinto. Voy a hacer una comprobacion ...
            --elseif(domoticz.data.semaforo) then
            elseif(domoticz.data.estado[boton.name]) then
                -- Se ha producido el off y estabamos regando
        	    -- Mandamos el mensaje del consumo
        	    local consumo = domoticz.devices('CONTADOR AGUA').counter - domoticz.data.contadorInicial
        	    domoticz.notify('CONSUMO','*Consumidos ' .. consumo .. ' m3*',domoticz.PRIORITY_LOW)
    	        -- Mandamos la notificacion
        	    domoticz.notify('RIEGOFF','*Riego ' .. boton.name .. ' terminado*',domoticz.PRIORITY_HIGH)
                -- Deshabilitamos el semaforo
                domoticz.data.semaforo = false
                -- Cambiamos su estado
    	        domoticz.data.estado[boton.name] = false
    	        -- Paramos el/los riegos
    	        domoticz.devices('EV-GENERAL').switchOff()
    	        if(boton.name == 'COMPLETO') then
        	        TerminaCesped(domoticz)
    	            TerminaGoteos(domoticz)
    	        elseif(boton.name == 'CESPED') then
        	        TerminaCesped(domoticz)
                elseif(boton.name == 'GOTEOS') then
    	            TerminaGoteos(domoticz)
                elseif(boton.name == 'HUERTO') then
    	            TerminaHuerto(domoticz)
                end	       
    	   end
    	   -- Si no se ha cumplido ninguna de las dos anteriores no hacemos nada
    	   -- pues el off se ha producido por el temporizador que se puso en el on.
        end
	end
}