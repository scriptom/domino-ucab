program DominoGame;
{
	Universidad Católica Andrés Bello
	Esc. de Ing. Informática
	Algoritmos y Progamación I
	Proyecto final de semestre
	Integrantes: - Tomás El Fakih
				 - Robert González
				 - Luis Guerra
}
uses crt, sysutils;
type
	// Modos de Juego. Usamos Enums para poder tenerlos como tipo ordinario (Y poder iterar sobre estos)
	ModosJuego = (Individual, Multijugador, Espectador);
	// Orientaciones de las fichas. Usadas para saber como imprimir
	Orientaciones = (Vertical, Horizontal);
	// subrango de movimientos posible
	Movi = 1..25;
	// Esquinas del juego. Indica la direccion en la que se colocara la ficha
	Esquinas = (Izquierda, Derecha, nulo);
	// informacion relevante sobre una ficha
	RFicha = record
		cara1 : Byte;	 // valor de la primera cara (arriba si esta en vertical, izquierda si es horizontal)
		cara2 : Byte;    // Valor de la segunda cara (abajo si es vertical, derecha si es horizontal)
		owner : SmallInt;// dueño de la ficha (Coincide con algun Indice de jugador o iterador global)
	end;

	// configuracion de la partida
	RConfig = record
		ModoJuego : ModosJuego;  // esquema de juego a plantear
		puntajeObj : Byte;		 // puntaje objetivo de la partida
		CantidadJugadores : Byte;// cantidad de jugadores
		CantidadPersonas : Byte; // cantidad de personas
		CantidadPCs : Byte;		 // cantidad de bots
		MostrarTodo : Boolean;   // flag para saber si mostramos toda la informacion
		HabilitarPC : Boolean;	 // flag para saber si contabilizamos PCs
	end;

	// datos generales de un jugador de domino
	RJugador = record
		Nombre : String;				// nombre (nickname) del jugador
		Fichas : array[1..10] of RFicha;// su mano o coleccion de fichas
		Humano : Boolean;				// flag para determinar si debemos jugar por el
		Indice : Byte;					// su indice (Probablemente no sea necesario, pero por si acaso). debe coincidir con el iterador global
		PuntajeObtenido : Byte;			// puntaje del jugador
	end;

	// datos que nos interesan de un movimiento
	RMovimiento = record
		Esquina : Esquinas; // la esquina donde se jugo
		Ficha : RFicha;		// la ficha que se jugo
	end;

	// Registro para tener un control de las impresiones de la mesa (util para propositos esteticos)
	REsquina = record
		X : Byte;					// Coordenada X de la ultima ficha dibujada en una esquina
		Y : Byte;					// Coordenada Y de la ultima ficha dibujada en una esquina
		Ficha : RFicha;				// Ficha perteneciente a una esquina
		Orientacion : Orientaciones;// Orientacion de la ficha 
	end;
	
	// Registro de partida. Con esto se facilita mucho la carga/guardado de partidas
	RPartida = record
		UltimoMovimiento : Movi;			// indice de movimiento
		Mesa : array[Movi] of RMovimiento;  // historial de movimientos
		PoteJuego : array[1..14] of RFicha; // fichas no repartidas a los jugadores
		Jugadores : array[1..4] of RJugador;// listado de jugadores
		PrimerTurno : Byte;					// indice del primer turno
		JugadorActual : Byte;				// jugador cuyo turno se juega. Tambien sirve para iterar sobre el listado
		config : RConfig;					// configuraciones de la partia
		ganadoPartida: Boolean;				// detector de fin de partida (Para partidas guardadas)
	end;
const
	// Modos de juego, traducidos a String (Utiles para la impresion de los valores)
	MODOS : array[ModosJuego] of String = ('Individual', 'Multijugador', 'Espectador');
	// Aliases de algunos caracteres especiales (Usados para propositos esteticos. Ordenadas por codigo ASCII)
	BV  = #179; // │ Barra Vertical
	BVD = #180; // ┤ Barra Vertical Derecha     ┌───┐
	ESD = #191; // ┐ Esquina Superior Derecha   │ m │ ┌───┬───┐
	EII = #192; // └ Esquina Inferior Izquierda ├───┤ │ n │ m │
	BHI = #193; // ┴ Barra Horizontal Inferior  │ n │ └───┴───┘
	BHS = #194; // ┬ Barra Horizontal Superior  └───┘
	BVI = #195; // ├ Barra Vertical Izquierda
	BH  = #196; // ─ Barra Horizontal
	EID = #217; // ┘ Esquina Inferior Derecha
	ESI = #218; // ┌ Esquina Superior Izquierda

var
	// manejador de la opcion actual, usada para navegar durante la ejecucion del programa
	OpcionActual: Char;
	// Orientacion de los rectangulos
	Orientacion: Orientaciones;
	// Dimensiones de un rectangulo; varia respecto a la dimension (Vease SetDimension). El alto representa lineas y el ancho caracteres
	Alto, Ancho: byte;
	Pote: array[1..28] of RFicha;
	// Variables para recordar las coordenadas de las ultimas impresiones
	EsquinaIzquierda, EsquinaDerecha: REsquina;
	// Variable global de la partida
	Domino: RPartida;
	// flag para saber si tenemos que salir del juego
	SalirAplicacion: Boolean;
	// determinante de que la partida es guardada
	Guardada: Boolean;

procedure MenuPrincipal();forward;

procedure ImprimirTitulo();
begin
	clrscr;
	// Tope
	Writeln(ESI,BH,BH,BH,BH,BH,BH,BH,BH,ESD);
	// Contendio del recuadro
	Writeln(BV,' DOMINO ',BV);
	// Fondo
	Writeln(EII,BH,BH,BH,BH,BH,BH,BH,BH,EID);
end;

procedure SwapFicha(var Ficha: Rficha);
var
	aux: byte;	
begin
	aux := Ficha.Cara1;
	Ficha.Cara1 := Ficha.Cara2;
	Ficha.cara2 := aux;
end;

{
	MostrarFichas:
	Muestra las Fichas en un formato definido
	Parametros: Cara1, Cara2: byte; Representan las caras de una ficha actual
	Variables: i: byte; Controlador de las iteraciones para impresiones repetidas
	Usa las variables Globales de Dimension para saber como imprimir, y usa un algoritmo diferente dependiendo de la orientacion,
	la cual es determinada a partir del valor del ancho
}
procedure MostrarFicha(Ficha: RFicha);
var
	i: byte;
begin
	case Orientacion of
		Vertical: begin // Vertical (5x5)
			{ Primera linea }
			Write(ESI); // Esquina Superior Izquierda
			for i := 1 to 3 do // 3 barras Horizontales
				Write(BH);
			Write(ESD); // Esquina Superior Derecha
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Segunda linea }
			Write(BV, ' ', Ficha.Cara1, ' ', BV); // La primera cara, con espacios y barras
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Tercera linea }
			Write(BVI);
			for i := 1 to 3 do
				Write(BH);
			Write(BVD);
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Cuarta linea }
			Write(BV, ' ', Ficha.Cara2, ' ', BV); // La segunda cara, con espacios y barras
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Quinta linea }
			Write(EII); // Esquina Inferior Izquierda
			for i := 1 to 3 do // 3 barras Horizontales
				Write(BH);
			Write(EID); // Esquina Inferior Derecha
			// NO bajamos. Dejemos el cursor al final de la ficha
		end;
		Horizontal: begin // Horizontal (9x3)
			{ Primera linea }
			Write(ESI); // Esquina Superior Izquierda
			for i := 1 to 3 do // 3 barras horizontales
				Write(BH);
			Write(BHS); // Barra Horizontal Superior
			for i := 1 to 3 do // 3 barras horizontales
				Write(BH);
			Write(ESD); // Esquina Superior Derecha
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Segunda linea }
			Write(BV, ' ', Ficha.Cara1, ' ', BV, ' ', Ficha.Cara2, ' ', BV);
			GotoXY(WhereX - Ancho, WhereY + 1); // Regresamos el cursor a la izquierda como nos diga el ancho (Para quedar al nivel de ESD), y bajamos una linea
			{ Tercera linea }
			Write(EII); // Esquina Inferior Izquierda
			for i := 1 to 3 do // 3 barras horizontales
				Write(BH);
			Write(BHI); // Barra Horizontal Inferior
			for i := 1 to 3 do // 3 barras horizontales
				Write(BH);
			Write(EID); // Esquina Inferior Derecha
			// NO bajamos. Dejemos el cursor al final de la ficha
		end;
	end;
end;

{
	SetOrientacion:
	Cambia la orientacion global de las fichas. Afecta las dimensiones de impresion de estas.
	Parametros: NuevaOrientacion: Orientaciones; La nueva orientacion que tendran las fichas
	Estas dimensiones son usadas principalmente en el procedimiento MostrarFicha
}
procedure SetOrientacion(NuevaOrientacion: Orientaciones);
begin
	Orientacion := NuevaOrientacion;
	case NuevaOrientacion of
		Vertical: begin
			Ancho := 5;
			Alto := 5;
		end;
		Horizontal: begin
			Ancho := 9;
			Alto := 3;
		end;
	end;
end;

procedure MostrarPotejuego();
var
	aux: byte;
begin
	for aux := 1 to 14 do
	begin
		SetOrientacion(Vertical);
		if aux = 14 then
			gotoXY(1, WhereY + Alto);
		if Domino.PoteJuego[aux].owner = -2 then
		begin
			MostrarFicha(Domino.PoteJuego[aux]);
			gotoXY(WhereX + 1, WhereY - (Alto - 1));
		end;
	end;
end;

{
	Esta funcion contabiliza las fichas de un jugador
	Parametros: Jugador - Un jugador
	Return: byte - El numero de fichas que tenga Jugador
}
function NumeroFichas(Jug : RJugador): byte;
var
	i: byte;
begin
	NumeroFichas := 0;
	for i := 1 to 10 do
		if Jug.Fichas[i].owner = Jug.Indice then
			NumeroFichas := NumeroFichas + 1;
end;
{
	Este procedimiento se encarga de mostrar el reparto de fichas al inicio de una ronda.
	Es llamado cuando el jugador haya habilitado mostrar todo en las opciones
}
procedure MostrarReparto();
var
	// Indican la instancia actual de los arreglos correspondientes (Jugador y las Fichas de este)
	jugador, ficha: byte;
begin

	SetOrientacion(Horizontal);
	for jugador := 1 to Domino.config.cantidadJugadores do
	begin
		// por cada jugador, mostremos su nombre
		Writeln('Fichas de ', Domino.Jugadores[jugador].nombre);
		for ficha := 1 to NumeroFichas(Domino.Jugadores[Jugador]) do
		begin
			// mostramos sus fichas una por una
			MostrarFicha(Domino.Jugadores[jugador].Fichas[ficha]);
			// Movemos manualmente el cursor para dejar un margen y que esten las fichas a la misma altura
			GotoXY(WhereX + 1, WhereY - (Alto - 1));
		end;
		GotoXY(1, WhereY + Alto); // Pegamos al margen izquierdo y bajamos 4 lineas
	end;
	if Domino.config.CantidadJugadores < 4 then
	begin
		Writeln('El pote sera este:');
		MostrarPoteJuego;
		gotoXY(1, WhereY + alto);
	end;
	WriteLn('Presione Enter para continuar.');
	repeat
		OpcionActual := ReadKey;
	until OpcionActual = #13;
end;


{
	Procedimiento para repartir fichas
	en este procedure se reparten las fichas a cada jugador del arreglo global Jugadores.
	Las fichas restantes se agregan al arreglo global PoteJuego.
}
procedure RepartirFichas();
var
	// jugador: indice del jugador actual en Jugadores
	// fichaJug: indice de la mano de algun jugador (RJugador.Fichas)
	// fichaPot: indice en el Pote de una ficha a agregar
	// aux: auxiliar para el indice de PoteJuego
	jugador, fichaJug, fichaPot, aux: byte;
begin
	(*
		Sea un jugador J y una ficha F:
		Cada jugador tiene un set de 7 fichas, estos sets se pueden reperesentar asi:

		J[1] = {F[1] ,F[2] ,F[3] ,F[4] ,F[5] ,F[6] ,F[7] }
		J[2] = {F[8] ,F[9] ,F[10],F[11],F[12],F[13],F[14]}
		J[3] = {F[15],F[16],F[17],F[18],F[19],F[20],F[21]}
		J[4] = {F[22],F[23],F[24],F[25],F[26],F[27],F[28]}
		
		Representandolo en funcion del numero 7:

		J[1] = {F[7*0+1],F[7*0+2],F[7*0+3],F[7*0+4],F[7*0+5],F[7*0+6],F[7*0+7]}
		J[2] = {F[7*1+1],F[7*1+2],F[7*1+3],F[7*1+4],F[7*1+5],F[7*1+6],F[7*1+7]}
		J[3] = {F[7*2+1],F[7*2+2],F[7*2+3],F[7*2+4],F[7*2+5],F[7*2+6],F[7*2+7]}
		J[4] = {F[7*3+1],F[7*3+2],F[7*3+3],F[7*3+4],F[7*3+5],F[7*3+6],F[7*3+7]}

		Conclusiones: 
		-El numero de columna se repite por cada iteracion de jugador
		-El multiplo de 7 para cada columna es el numero de la fila - 1
	*)
	for jugador := 1 to Domino.config.cantidadJugadores do
	begin
		for fichaJug := 1 to 7 do
		begin
			// esta operacion viene dada porque la ficha del pote que se le va a asignar al jugador se puede expresar como: el indice de la ficha que le daremos al jugador + 7*el indice del jugador -1 (representado visualmente arriba)
			fichaPot := fichaJug + (7 * (jugador - 1));
			// declaramos en el pote que esta ficha sera del jugador
			Pote[fichaPot].owner := jugador;
			Domino.Jugadores[jugador].Fichas[fichaJug] := Pote[fichaPot];
		end;
	end;
	aux := 1;
	for fichaPot := fichaPot + 1 to 28 do
	begin
		Domino.PoteJuego[aux] := Pote[fichaPot];
		Pote[fichaPot].owner := -2;
		Domino.PoteJuego[aux] := Pote[fichaPot];
		aux := aux + 1;
	end;
	if Domino.config.MostrarTodo then
		MostrarReparto;
end;


{
	GenerarPote:
	Crea aleatoriamente la coleccion de fichas. Es llamada antes de siquiera darselas a los jugadores.
	Es el equivalente de abrir el estuche de fichas y revolverlas.
	Variables: 
	- SlotVacio, SlotLleno: byte; Controladores de iteracion en el array Pote.
	- esRepetida: Boolean; Control de fichas repetidas, alterado al generar el candidato y al encontrar igualdad de fichas
	- PosiFicha: RFicha; Posible ficha a ser agregada al pote
}
procedure GenerarPote();
	{
		MostrarPote:
		Se encarga de llamar repetidas veces a MostrarFicha, pasandole cada ficha del pote
		Variables: ficha: byte; Indice para iterar sobre Pote
	}
	procedure MostrarPote();
	var
		ficha: byte;			
	begin
		// Especificamos la Orientacion como vertical
		SetOrientacion(Vertical);
		Writeln('Pote de juego inicial:');
		// Empezamos a iterar
		for ficha := 1 to 28 do
		begin
			// Mostramos la ficha actual
			MostrarFicha(Pote[ficha]);
			// Movemos manualmente el cursor para dejar un margen y que esten las fichas a la misma altura
			GotoXY(WhereX + 1, WhereY - (Alto - 1));
			// Para tener un poco mas de espacio, cuando hayamos mostrado 14 fichas, dejemos una linea de por medio, y reiniciemos el cursor
			if ficha mod 13 = 0 then
				GotoXY(1, WhereY + Alto); // Pegamos al margen izquierdo y bajamos 2 lineas
		end;
	end;
var
	SlotVacio, SlotLleno: byte;
	esRepetida: Boolean;
	PosiFicha: RFicha;
begin
	SlotVacio := 1; 
	randomize;
	repeat
		// Generar candidato y lo colocamos. Despues validamos si esta repetida
		PosiFicha.Cara1 := random(7);
		PosiFicha.Cara2 := random(7);
		esRepetida := false;
		SlotLleno := 1;
		while ((SlotLleno < SlotVacio) and not esRepetida) do
		begin
			// La primera conjuncion compara las caras de forma lineal
			// La segunda conjuncion compara las caras de forma cruzada
			if (((Pote[SlotLleno].Cara1 = PosiFicha.Cara1) and (Pote[SlotLleno].Cara2 = PosiFicha.Cara2))
			or ((Pote[SlotLleno].Cara1 = PosiFicha.Cara2) and (Pote[SlotLleno].Cara2 = PosiFicha.Cara1))) then
				esRepetida := true;
			SlotLleno := SlotLleno + 1;
		end;
		if not esRepetida then
		begin
			// No es repetida, colocamos el candidato en el pote
			Pote[SlotVacio] := PosiFicha;
			// nos movemos al siguiente slot vacio
			SlotVacio := SlotVacio + 1;
		end;
	until (SlotVacio > 28);
	 if Domino.config.MostrarTodo then
	 begin
		MostrarPote;
	 	gotoXY(1, WhereY + Alto);
	 end;
end;

function PoteRestante(): byte;
var
	ficha: byte;
begin
	PoteRestante := 0;
	for ficha := 1 to 14 do
		if Domino.Potejuego[ficha].owner = -2 then
			PoteRestante := PoteRestante + 1;
end;

function ComprobarPote():Boolean;
var
   fichaActual: byte;
   vacio: boolean;
begin
	// si hay 4 jugadores, logicamente no hay pote, asignamos false y devolvemos
	if Domino.config.cantidadJugadores = 4 then
		ComprobarPote := False
	else // Si va a haber pote, veamos que aun haya
	begin
		fichaActual := 1;
		vacio := true;
		while ((fichaActual <= 14) and not(Vacio)) do
		begin
			if Domino.PoteJuego[FichaActual].owner = 0 then
			begin
				ComprobarPote := true;
				vacio := true;
			end;
            fichaActual := fichaActual + 1;
		end;
	end;
end;
{
	AgarrarPote:
	Selecciona la siguiente ficha del pote disponible y se la asigna a un jugador
	Variables: Jugador: byte; Indice del jugador al que le daremos ficha
}
procedure AgarrarPote();
var
   fichaPote, huecoJug: byte;
   fichaAux: RFicha;
   Agarrada: Boolean;
begin
	// Primero iteramos sobre el pote de juego
	Agarrada := false;
	fichaPote := 1;
	while ((fichaPote <= 14) and not(Agarrada)) do
	begin
		if (Domino.PoteJuego[fichaPote].owner = -2) then
		begin                           // HAY QUE HACER UNA COMPROBACION DEL ESPACIO EN LA MANO DE UN JUGADOR. ABAJO, PREFERIBLEMENTE
			huecoJug := NumeroFichas(Domino.Jugadores[Domino.JugadorActual]) + 1;
			// si encontramos una ficha que aun este en el pote, entonces empezamos a iterar sobre las fichas del jugador actual
			Domino.Jugadores[Domino.JugadorActual].fichas[huecoJug] := Domino.PoteJuego[fichaPote];
			Domino.jugadores[Domino.JugadorActual].fichas[huecoJug].owner := Domino.JugadorActual;
			Domino.PoteJuego[fichaPote].owner := Domino.JugadorActual;
			Agarrada := true;
		end;
		fichaPote := fichaPote + 1;
	end;
	for fichaPote := 1 to PoteRestante do
		if Domino.PoteJuego[fichaPote].owner <> -2 then
		begin
			fichaAux := Domino.PoteJuego[fichaPote];
			Domino.PoteJuego[fichaPote] := Domino.PoteJuego[fichaPote + 1];
			Domino.PoteJuego[fichaPote + 1] := fichaAux;
		end;
end;

procedure PeticionCompletacion();
var
	Salir: Boolean;
begin
	clrscr;
	Writeln('No se puede iniciar la partida con esta configuraci'#162'n. Por favor corrija:');
	if Domino.config.PuntajeObj = 0 then
		WriteLn('- Escoja un puntaje objetivo');
	if Domino.config.CantidadJugadores = 0 then
		Writeln('- No ha escrito cu'#160'ntos jugadores participar'#160'n');
	WriteLn('Presione ESC para volver');
	repeat
		OpcionActual := Readkey;
		if OpcionActual = #27 then
			Salir := True;
	until Salir;
end;

{
	TodoListo:
	Comprueba que las opciones que nos interesa llenar esten completas antes de iniciar un juego. Dichas condiciones son: Cantidad de jugadores y puntaje objetivo.
	(El modo de juego tambien importa, pero como siempre tiene un valor, nospodemos despreocupar)
	Devuelve: Boolean; Que tanto el puntaje objetivo como la cantidad de jugadores sean diferentes de 0
}
function TodoListo(): Boolean;
begin
	TodoListo := ( ( Domino.config.PuntajeObj <> 0 ) and ( Domino.config.CantidadJugadores <> 0 ) );
end;


procedure BuscarEsquinas(var Izq, Der: byte);
var
    mov: Movi;
begin
    for mov := 1 to Domino.UltimoMovimiento do
    begin
        case Domino.Mesa[mov].Esquina of
            nulo: begin
                Izq := Domino.Mesa[mov].Ficha.Cara1;
                Der := Domino.Mesa[mov].Ficha.Cara2;
            end;
            Izquierda: Izq := Domino.Mesa[mov].Ficha.Cara1;
            Derecha: Der := Domino.Mesa[mov].Ficha.Cara2;
        end;
    end;
end;

procedure JugarFicha(var Ficha: RFicha; Esquina: Esquinas);
var
	EsqIzq, EsqDer: byte;
	FichaAuxiliar: Rficha;
	fch: byte;
begin
	if Ficha.owner <> -1 then
	begin
		BuscarEsquinas(EsqIzq, EsqDer);
		Domino.UltimoMovimiento := Domino.UltimoMovimiento + 1;
		Domino.Mesa[Domino.UltimoMovimiento].Ficha := Ficha;
		Domino.Mesa[Domino.UltimoMovimiento].Esquina := Esquina;
		case Esquina of
			Izquierda:
				if Ficha.Cara1 = EsqIzq then
					SwapFicha(Domino.Mesa[Domino.UltimoMovimiento].Ficha);
			Derecha:
				if Ficha.Cara2 = EsqDer then
					SwapFicha(Domino.Mesa[Domino.UltimoMovimiento].Ficha);
		end;
		Ficha.owner := -1;
		for fch := 1 to NumeroFichas(Domino.Jugadores[Domino.jugadorActual]) do
		begin
			if Domino.Jugadores[Domino.JugadorActual].Fichas[fch].owner <> Domino.JugadorActual then
			begin
				FichaAuxiliar := Domino.Jugadores[Domino.JugadorActual].Fichas[fch];
				Domino.Jugadores[Domino.JugadorActual].Fichas[fch] := Domino.Jugadores[Domino.JugadorActual].Fichas[fch + 1];
				Domino.Jugadores[Domino.JugadorActual].Fichas[fch + 1] := FichaAuxiliar;
			end;
		end;
	end;
end;

procedure MostrarMesa;
var
	// iterador de movimientos
	mov: byte;
	// Ayudante para ancho de pantalla
	AnchoPantalla: Byte;
	// ficha a imprimir
	PrintFicha: RFicha;
begin
	// limpiamos la pantalla
	clrscr;
	// reiniciamos el cursor
	GotoXY(1,1);
	(*
		De acuerdo a la documentacion, WindMax devuelve la coordenada de la esquina inferior derecha de la pantalla,
		este valor en Base 10, y en SO Windows 7 (aun no probado en versiones mayores ni en otros SOs) es 11087 (0x2B4F).
		WindMax es un Word, que consta de 2 bytes: El Mayor contiene la coordenada en Y, mientras que el menor contiene la coordenada en X
		La representacion en binario de dicha variable es:
		00101011    01001111
		byte alto   byte bajo

		Si consideramos los operadores a nivel de bits, podemos concluir que nos podemos quedar con el byte que queramos aplicando 
		operaciones logicas:

		Para el byte bajo, un simple 'and' sirve (WindMax and 255)
			00101011  01001111 and
			00000000  11111111
			------------------
			00000000  01001111 <-- 79, ancho total de la ventana (Probado en Windows 7)
		
		Fuente de WindMax: https://www.freepascal.org/docs-html/rtl/crt/windmax.html
	*)
	// Nos interesa el byte bajo (coordenada x)
	AnchoPantalla := WindMax and 255;
	// inicializamos UltimaIzquierda y UltimaDerecha
	// mostramos la primera ficha de los movimientos (que siempre nos interesa que se muestre, por eso esta hardcoded
	for mov := 1 to Domino.UltimoMovimiento do
	begin
		if mov = Domino.UltimoMovimiento then
			textcolor(green);
		PrintFicha := Domino.Mesa[mov].Ficha;
		case Domino.Mesa[mov].Esquina of
			nulo:
			begin
				// empezamos colocando las fichas horizontalmente
				SetOrientacion(Horizontal);
				// colocamos el cursor en el medio para que imprima la primera ficha centrada
				GotoXY( (AnchoPantalla div 2) - 4, WhereY );
				MostrarFicha(PrintFicha);
				EsquinaIzquierda.X := WhereX - Ancho;
				EsquinaDerecha.X := WhereX;
				EsquinaIzquierda.Y := 1;
				EsquinaDerecha.Y := 1;
				EsquinaIzquierda.Orientacion := Horizontal;
				EsquinaDerecha.Orientacion := Horizontal;
				EsquinaIzquierda.Ficha := PrintFicha;
				EsquinaDerecha.Ficha := PrintFicha;
			end;
			Izquierda:
			begin
				if (EsquinaIzquierda.Orientacion = Horizontal) then
				begin
					if ((EsquinaIzquierda.X - 9) <= 5) then
					begin
						SetOrientacion(Vertical);
						GotoXY(EsquinaIzquierda.X - Ancho, 1);
						if PrintFicha.Cara2 = EsquinaIzquierda.Ficha.Cara1 then
							SwapFicha(PrintFicha);
						MostrarFicha(PrintFicha);
						EsquinaIzquierda.X := EsquinaIzquierda.X - Ancho;
						EsquinaIzquierda.Y := WhereY + 1;
						EsquinaIzquierda.Orientacion := Vertical;
					end
					else
					begin
						SetOrientacion(Horizontal);
						GotoXY(EsquinaIzquierda.X - Ancho, 1);
						if PrintFicha.Cara1 = EsquinaIzquierda.Ficha.Cara1 then
							SwapFicha(PrintFicha);
						MostrarFicha(PrintFicha);
						EsquinaIzquierda.X := EsquinaIzquierda.X - 9;
					end;
				end
				else
				begin
					SetOrientacion(Vertical);
					GotoXY(EsquinaIzquierda.X, EsquinaIzquierda.Y);
					if PrintFicha.Cara2 = EsquinaIzquierda.Ficha.Cara2 then
						SwapFicha(PrintFicha);
					MostrarFicha(PrintFicha);
					EsquinaIzquierda.Y := WhereY + 1;
				end;
				EsquinaIzquierda.Ficha := PrintFicha;
			end;
			Derecha:
			begin
				if (EsquinaDerecha.Orientacion = Horizontal) then
				begin
					if ((EsquinaDerecha.X + 9) >= (AnchoPantalla - 5)) then
					begin
						SetOrientacion(Vertical);
						GotoXY(EsquinaDerecha.X , 1);
						if PrintFicha.Cara2 = EsquinaDerecha.Ficha.Cara2 then
							SwapFicha(PrintFicha);
						MostrarFicha(PrintFicha);
						EsquinaDerecha.X := WhereX - Ancho;
						EsquinaDerecha.Y := WhereY + 1;
						EsquinaDerecha.Orientacion := Vertical;
					end
					else
					begin
						SetOrientacion(Horizontal);
						GotoXY(EsquinaDerecha.X, 1);
						if PrintFicha.Cara2 = EsquinaDerecha.Ficha.Cara2 then
							SwapFicha(PrintFicha);
						MostrarFicha(PrintFicha);
						EsquinaDerecha.X := WhereX;
					end;
				end
				else
				begin
					SetOrientacion(Vertical);
					GotoXY(EsquinaDerecha.X, EsquinaDerecha.Y);
					if PrintFicha.Cara2 = EsquinaDerecha.Ficha.Cara2 then
						SwapFicha(PrintFicha);
					MostrarFicha(PrintFicha);
					EsquinaDerecha.Y := WhereY + 1;
				end;
				EsquinaDerecha.Ficha := PrintFicha;
			end;
		end;
		if mov = Domino.UltimoMovimiento then
			textcolor(white);
	end;
end;

procedure MenuGuardado();
	procedure ImprimirMenuGuardado();
	begin
		WriteLn('Seleccione un Slot donde guardar la partida:');
		Writeln('A - Slot A');
		Writeln('B - Slot B');
		Writeln('C - Slot C');
		Writeln('ESC - Salir sin guardar');
	end;
var
	Slot: file of RPartida;
	DominoPath: String;
begin
	ImprimirMenuGuardado;
	repeat
		OpcionActual := Readkey;
		if ((UpCase(OpcionActual) < 'A') or (UpCase(OpcionActual) > 'C')) then
			WriteLn('Slot de guardado inexistente. Seleccione otro');
	until ((UpCase(OpcionActual) >= 'A') and (UpCase(OpcionActual) <= 'C') or (OpcionActual = #27));
	if OpcionActual = #27 then
		Exit;
	DominoPath := ExtractFilePath(ParamStr(0));
	Assign(Slot, DominoPath + 'Partida' + UpCase(OpcionActual) + '.domino' );
	Rewrite(Slot);
	Write(Slot, Domino);
	WriteLn('Partida guardada en "', DominoPath + 'Partida' + UpCase(OpcionActual) + '.domino', '"');
	Close(Slot);
	SalirAplicacion := true;
	delay(2500);
end;
{
	PlantearTurno:
	Procedimiento principal de turno del jugador actual.
	Tiene 2 modalidades: humano y bot. Independientemente de la modalidad, mostramos la mesa; luego comprobamos la humanidad del jugador,
	si es humano, le mostramos sus fichas y le damos la opcion de escoger la que desee. Si es un bot, entonces que realice una jugada automatica,
	la cual consiste en jugar la primera ficha disponible en su mano
	-Variables: Margen: Despues de mostrar la mano, colocamos las opciones a la derecha de las fichas. no obstante para diferentes lineas debemos dejar un margen
				para que no rompa la estructura de las fichas
				EsquinaIzq, EsquinaDer: Las esquinas en el momento de este turno
				ficha: iterador de fichas, usado para ambas modalidades para propositos similares
				Jugado: indicador sobre el estado del bot, util para saber cuando dejamos de iterar sobre sus fichas
				Pasar: Si la alternativa de turno final es pasar, esta variable ahorra ejecucion de codigo que esta reservada para cuando se tengan fichas
				LaEsquina: Guarda la primera esquina apta para jugar
}
procedure PlantearTurno();
	{
		MostrarMano:
		Procedimiento encargado de mostrar la mano al jugador (siempre cuando es humano, muestra la de los bots si el usuario habilito la opcion MostrarTodo)
	}
	procedure MostrarMano();
	var
		i: byte; // Iterador de fichas a mostrar en el menu
	begin
		// Cambiamos la orientacion de las fichas para mostrarle su mano al jugador
		SetOrientacion(Vertical);
		GotoXY(WhereX, WhereY +1);
		for i := 1 to NumeroFichas(Domino.Jugadores[Domino.JugadorActual]) do
		begin
			if (Domino.Jugadores[Domino.JugadorActual].Fichas[i].owner = Domino.JugadorActual) then
			begin
				// imprimimos las fichas una por una
				MostrarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[i]);
				// llevamos el cursor una linea hacia abajo y lo ponemos centrado debajo de la ficha mostrada
				GotoXY(WhereX - 3, WhereY + 1); // nos podemos dar la libertad de colocar -2 en la coord x porque sabemos que el ancho es	(ver SetOrientacion)
				// mostramos el numero que tiene que marcar el usuario para seleccionar la ficha en cuestion
				Write(i);
				// Movemos el cursor dejando un espacio entre ficha y ficha
				GotoXY( WhereX + 3, WhereY - Alto );
			end;
		end;
	end;
	{
		MenuPausa:
		Despliega un menu de pausa con 2 opciones: Salir de la partida o volver a la misma.
		Tiene a su vez otro submenu de salida, donde se le pregunta al usuario si desea guardar la partida o salir sin guardar
		-Variables: QuiereSalir: Indica si el jugador quiere salir de la partida. Dispara el submenu de salida
					DebeGuardar: si QuiereSalir es true, entonces esta variable contendra la decision del usuario de guardar o no al salir
	}
	procedure MenuPausa();
		{
			Simple procedimiento de impresion, para separar la parte logica de las impresiones
		}
		procedure ImprimirMenuPausa();
		begin
			ImprimirTitulo;
			WriteLn(#126' PAUSA '#126);
			Writeln('ESC - Salir de la partida');
			Writeln('ENTER - Regresar a la partida');
		end;
		{
			Simple procedimiento de impresion, para separar la parte logica de las impresiones
		}
		procedure ImprimirMenuSalida();
		begin
			Writeln;
			Writeln('Desea guardar la partida antes de salir?');
			Writeln('ENTER - Guardar Partida');
			Writeln('ESC - Salir sin Guardar');
			Writeln('C - Cancelar')
		end;
	var
		QuiereSalir, DebeGuardar: Boolean;
	begin
		repeat
			// mostramos el menu
			ImprimirMenuPausa;
			repeat
				// necesitamos una opcion valida
				OpcionActual := readkey;
				case OpcionActual of
					#27: QuiereSalir := true;
					#13: QuiereSalir := false;
				end;
			until ((OpcionActual = #27) or (OpcionActual = #13));
			if QuiereSalir then
			begin
				// debemos mostrar el submenu de salida
				repeat
					// mostramos el submenu de salida
					ImprimirMenuSalida;
					// requerimos de una opcion valida
					opcionActual := Readkey;
					case OpcionActual of
						#13: DebeGuardar := true;
						#27: DebeGuardar := false;
					end;
				until ((OpcionActual = #13) or (OpcionActual = #27) or (UpCase(OpcionActual) = 'C') or (SalirAplicacion));
				// Como 'C' solo nos importa para salir del ciclo y no hacemos nada con ella, comparamos contra su diferencia para seguir actuando, sino volvemos al ciclo de MenuPausa
				if UpCase(OpcionActual) <> 'C' then
				begin
					// si es diferente de 'C' si nos interesa el valor de DebeGuardar
					if DebeGuardar then
						// mostremos el menu de guardado
						MenuGuardado
					else 
						// salimos de una
						SalirAplicacion := true;
					// siempre nos devolvemos al menu principal
					MenuPrincipal
				end;
			end
			else
			begin
				// si no se quiere salir, entonces reiniciamos la OpcionActual
				OpcionActual := #0;
				// y replanteamos el turno
				// PlantearTurno;
			end;
		until ((OpcionActual = #27) or (SalirAplicacion) or (OpcionActual = #0));
	end;
	{
		PuedeJugar:
		Determina si una ficha puede ser puesta o no en la mesa. Para esto necesita saber cuales son las esquinas
		-Variables: Ficha: la ficha a comprobar si es jugable o no
					EsqIzq, EsqDer: Las esquinas actuales. Estas se pueden obtener con BuscarEsquinas
					LaEsquina: Parametro por referencia que guarda, en caso de ser jugable la ficha, la esquina donde lo es
		-Retorno: Boolean indicador de la jugabilidad de la ficha en cuestion
		Cabe a destacar que esta funcion no maneja los casos en los que una ficha puede ser jugada por ambas esquinas
	}
	function Puedejugar(var Ficha: Rficha; EsqIzq, EsqDer: byte; var LaEsquina: Esquinas): boolean;
	begin
		// la ficha debe pertenecer al jugador actual, sino automaticamente no es jugable
		if Ficha.owner = Domino.JugadorActual then
		begin
			// comparamos el valor numerico de la esquina izquierda con ambas caras de la ficha pasada para saber si es jugable por la izquierda
			if ((EsqIzq = Ficha.Cara1) or (EsqIzq = Ficha.Cara2)) then
			begin
				// de haber compatibilidad, asignamos la izquierda como la esquina disponible
				LaEsquina := Izquierda;
				// si se puede jugar
				PuedeJugar := True;
			end
			// sino, comparamos con la esquina derecha
			else if ((EsqDer = Ficha.Cara1) or (EsqDer = Ficha.Cara2)) then
			begin
				// si hubo exito, nuestra esquina sera la derecha
				LaEsquina := Derecha;
				// tambien se puede jugar
				PuedeJugar := True;
			end
			else
				/// si fallo ambas comparaciones, no se puede jugar la ficha
				PuedeJugar := False;
		end
		else
			// si no pertenece, no hacemos nada y devolvemos false
			PuedeJugar := false;
	end;

var
	Margen : byte; // Margen para saber el espacio que tenemos despues de imprimir las fichas (para el resto de las opciones)
	EsquinaIzq, EsquinaDer : byte;
	ficha: byte;
	Jugado, Pasar: boolean;
	LaEsquina: Esquinas;
	salir:Boolean;
begin
	repeat
		
	Salir:=False;
	// Mostramos la mesa completa
	MostrarMesa;
	// Pegamos al margen izquierdo y titulamos
	if EsquinaIzquierda.Y > EsquinaDerecha.Y then 
		GotoXY(1, EsquinaIzquierda.Y + 4)
	else 
		GotoXY(1, EsquinaDerecha.Y + 4);
	WriteLn('Turno de ', Domino.Jugadores[Domino.JugadorActual].nombre, ' (Fichas disponibles: ', NumeroFichas(Domino.Jugadores[Domino.JugadorActual]), ')');
	// Comprobamos si es bot o no (Logicas diferentes dependiendo de esa condicion
	if (Domino.Jugadores[Domino.JugadorActual].Humano) then // es humano, planteamos sus fichas etc
	begin
		if Domino.UltimoMovimiento = 0 then
			Writeln('Escoja la ficha con que desee empezar');
		// Mostramos su mano al jugador
		MostrarMano;
		// guardamos la distancia que hay entre el margen izquierdo de la pantalla y todas las fichas impresas
		Margen := WhereX;
		Write('ESC: Pausa');
		if (ComprobarPote) then
		begin
			// si tenemos pote, presentamos la opcion de agarrar de este
			GotoXY(Margen, WhereY + 1);
			Write('P: Agarrar del pote (',PoteRestante,' disponible)');
			GotoXY(1, WhereY + 6);
			if Domino.config.MostrarTodo then
			begin
				// y aprovechando que ya sabemos que hay pote, lo mostramos debajo de las opciones
				Writeln('Pote de Juego restante');
				MostrarPoteJuego;
				GotoXY(1, WhereY + 6);
			end;
		end
		else
			GotoXY(1, WhereY + 6);
		// si estamos en el primer movimiento, no vale la pena comprobar si se debe pasar
		if Domino.ultimoMovimiento <> 0 then
		begin
			// iteramos 
			ficha := 1;
			Pasar := true;
			BuscarEsquinas(EsquinaIzq, EsquinaDer);
			while ((ficha <= NumeroFichas(Domino.Jugadores[Domino.JugadorActual])) and (Pasar)) do
				if Puedejugar(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], EsquinaIzq, EsquinaDer, LaEsquina) then
					Pasar := false
				else
					ficha := ficha + 1;
			if Pasar then
			begin
				Write('No tiene fichas disponibles para jugar!'); 
				if ComprobarPote then
					Write(' Presione P para agarrar una ficha del pote')
				else
					Write(' Presione ENTER para pasar turno');
				writeln;
				
			end;
		end;
		// if ((Domino.UltimoMovimiento <> 0) and Pasar) then
		// begin
		// end;
		OpcionActual := readkey;
		case OpcionActual of
			#27: MenuPausa;
			// todos los digitos estan reservados para el maximo de fichas que puede tener un jugador (10)
			'0'..'9': begin
				// conversion del caracter de la ficha a numero
				ficha := Ord(OpcionActual)-48;
				// si es 0, es la ficha #10
				if ficha = 0 then
					ficha := 10;
				// en el primer movimiento de la ronda, cualquier ficha vale, pero debe tener una esquina nula
				if Domino.UltimoMovimiento = 0 then
					JugarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], nulo)
				else
				begin
					// buscamos las esquinas
					BuscarEsquinas(EsquinaIzq, EsquinaDer);
					// comprobamos que sea legal jugar por esa esquina
					if Puedejugar(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], EsquinaIzq, EsquinaDer, LaEsquina) then
						JugarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], LaEsquina)
					else
					begin
						Writeln('No se puede jugar esa ficha! Intente otra!');
						delay(925);
						OpcionActual := #0;
					end;
				end;
				MostrarMesa;
				if EsquinaIzquierda.Y > EsquinaDerecha.Y then 
					GotoXY(1, EsquinaIzquierda.Y + 6)
				else 
					GotoXY(1, EsquinaDerecha.Y + 6);
				Writeln('Has jugado! tu mano ha quedado asi:');
				MostrarMano;
				GotoXY(1, WhereY + 6);
				Writeln('Presione ENTER para ir al siguiente turno');
				Readln;
			end;
			// tecla reservada para el pote
			'p', 'P':
				if (ComprobarPote and Pasar) then
				begin
					AgarrarPote;
					Writeln('Has agarrado del pote! Presione ENTER para continuar');
					Readln;
					Exit;
				end;
			#13:
				if (Pasar and not(ComprobarPote)) then
					Exit
				else
				begin
					Writeln('No puede pasar turno! Pruebe otra opcion');
					delay(925);
				end;
		end;
	end
	else // es bot. Hay que hacer una jugada automatica
	begin
		// solamente mostramos la mano si nos indicaron para mostrar todo
		if Domino.config.MostrarTodo then
		begin
			MostrarMano; // mostramos
			GotoXY(1, WhereY + 6); // reposicionamos cursor
		end;
		// cuando salimos del menu de pausa, OpcionActual es #0, por lo que podemos usar ese valor para saber si venimos de ese menu, y asi evitamos jugadas dobles
		if OpcionActual <> #0 then
		begin
			// en el primer turno que juegue la primera ficha que tenga
			if Domino.UltimoMovimiento = 0 then
			begin
				JugarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[1], nulo);
				Jugado := true;
			end
			else // cualquier otro movimiento
			begin
				// conseguimos los valores de las esquinas
				BuscarEsquinas(EsquinaIzq, EsquinaDer);
				// inicializamos el iterador de las fichas
				ficha := 1;
				// asumimos que no ha jugado
				jugado := false;
				// iteramos sobre sus fichas mientras nos falte verlas todas y no hayamos jugado
				while (((ficha <= NumeroFichas(Domino.jugadores[Domino.JugadorActual])) and not (Jugado))) do
					if PuedeJugar(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], EsquinaIzq, EsquinaDer, LaEsquina) then
					begin
						// si podemos jugar, guardamos dicha esquina y jugamos esa ficha de una vez en esa esquina
						JugarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[ficha], LaEsquina);
						// no hace falta seguir viendo las fichas
						Jugado := True;
					end
					else
						// si aun no podemos jugar, vamos a la siguiente ficha
						ficha := ficha + 1;
			end;
			// si a estas alturas no jugamos, entonces tenemos que recurrir a otro recurso: agarrar del pote o pasar
	        if not(Jugado) then
	        begin
	        	// comprobamos si hay pote
				if ComprobarPote then
				begin
					// de ser asi, agarramos una ficha del pote
					AgarrarPote;
					WriteLn(Domino.Jugadores[Domino.JugadorActual].nombre, ' ha agarrado del pote!');
				end
				else
					// sino, pasamos turno
					Writeln(Domino.Jugadores[Domino.jugadorActual].nombre, ' ha pasado su turno!');
	        end
	        else
	        begin
	        	// mostremos la mesa actualizada
	        	MostrarMesa;
				if EsquinaIzquierda.Y > EsquinaDerecha.Y then 
					GotoXY(1, EsquinaIzquierda.Y + 6)
				else 
					GotoXY(1, EsquinaDerecha.Y + 6);
	        	// pudimos jugar, solo queda informarle al jugador
		        Writeln(Domino.jugadores[Domino.JugadorActual].nombre, ' ha jugado!');
	        end;
		end;
	    // actualizamos conteo de fichas y no aceleramos las cosas. Que el jugador apriete enter para ir al sig. turno
        Writeln('Fichas restantes: ', NumeroFichas(Domino.Jugadores[Domino.JugadorActual]));
        if Domino.config.MostrarTodo then
        begin
        	if Jugado then
        	begin
	        	MostrarMano;
				GotoXY(1, WhereY + 6);
        	end;
			if ComprobarPote then
			begin
				Writeln('Pote de Juego restante');
				MostrarPoteJuego;
				GotoXY(1, WhereY + 6);
			end;
        end;
		WriteLN('Presione ENTER para ir al siguiente turno');
		WriteLN('Presione ESC para ir al Menu de pausa');
    	OpcionActual := ReadKey;
    	if OpcionActual = #27 then
			MenuPausa;        		
	end;
	until ((Domino.Jugadores[Domino.JugadorActual].Humano) and (((Pasar and not(ComprobarPote)) and (OpcionActual = #13)) or (Pasar and (UpCase(OpcionActual) = 'P')) or ((OpcionActual >= '0') and (OpcionActual <= '9')))
			or (not(Domino.Jugadores[Domino.JugadorActual].Humano) and (OpcionActual = #13))
			or SalirAplicacion);
end;
{
	SumatoriaFichas
	Funcion que itera sobre las fichas de un jugador y devuelve la suma de las caras de las fichas restantes del mismo
	-Parametros: Jugador: Instancia de jugador de la partida
	-Variables: f: iterador de las fichas de la mano del jugador
	-Retorno: SumatoriaFichas: Suma de las caras de las fichas restantes del jugador
}
function SumatoriaFichas(var Jugador: RJugador): byte;
var
	f: byte;
begin
	// inicializamos la suma
	SumatoriaFichas := 0;
	// iteramos por todas las fichas del jugador
	for f := 1 to NumeroFichas(Jugador) do
		// comprobamos que la ficha aun le pertenezca usando su propiedad de indice (Esto puede que sea innecesario debido a que esta comprobacion ya la hacemos en NumeroFichas)
		if Jugador.Fichas[f].owner = Jugador.Indice then
			//  si es asi entonces agregamos a sumatoria los valores de la cara1 y la cara2
			SumatoriaFichas := SumatoriaFichas + Jugador.Fichas[f].Cara1 + Jugador.Fichas[f].Cara2;
end;

{
	InitRonda:
	Ciclo principal de una ronda. Se entiende por ronda como un ciclo de turnos, alternando jugadores, que continua hasta que alguna de las siguientes condiciones ocurra:
	- Un jugador se quede sin fichas
	- El juego quede trancado
	Al inicio de cada ronda, debemos generar un pote aleatorio (Es decir, revolver) para que las fichas repartidas a continuacion sean aleatorias
	-Variables: MenorPuntaje: en los juegos trancados, esta variable determina el ganador (el jugador cuya suma de fichas sea la menor)
				SumF: SUma de las caras de las fichas de un jugador
				perdedor: Iterador de los jugadores para sumar sus ptos
				ganador: Indice del jugador que se haya quedado sin fichas/tenga la menor suma
				FichaActual: Iterador de las fichas de un jugador
				Cochina: Indice de la cochina (para los primeros turnos de las partidas)
				CochinaUbicada: Determinante si vale la pena seguir iterando sobre las fichas del jgador si ya conseguimos la cochina
}
procedure InitRonda();
	{
		LimpiarMesa:
		Procedimiento que se encarga de reiniciar el array de Mesa, convirtiendo los owner de todas las fichas a -2 (Pote), y reiniciando el contador de movimientos
		-Variables: mov: subrango de los movimientos posibles (25), utilizado para iterar sobre los movimientos realizados
	}
	procedure LimpiarMesa();
	var
		mov: Movi;
	begin
		// limpiamos la pantalla
		clrscr;
		// iteramos sobre los movimientos de la ronda
		for mov := 1 to Domino.UltimoMovimiento do
			// cambiamos el owner a -2
			Domino.Mesa[mov].Ficha.owner := -2;
		// Reiniciamos el ultimo movimiento
		Domino.UltimoMovimiento := 0;
	end;
	{
		estaTrancado:
		Funcion para detectar si un juego esta trancado. Llamado al final de cada turno para comprobar si es necesario continuar con la ronda
		-Variables: ValorAComprobar: Valor numerico de la cara que se jugo, que probablemente este trancada
					Repeticiones: Cantidad de veces que se repite ValorAComprobar en la mesa
					EsquinaIzquierda, EsquinaDerecha: Valores numericos de las esquinas, usados para obtener ValorAComprobar
					mov: Iterador de los movimientos de la mesa
		-Retorno: estaTrancado: conclusion del analisis de la mesa
	}
	function estaTrancado(): Boolean;
	var
		ValorAComprobar, Repeticiones, EsquinaIzquierda, EsquinaDerecha: byte;
		mov: Movi;
	begin
		// primero, las esquinas deben ser iguales. Buscamos los valores de estas
		BuscarEsquinas(EsquinaIzquierda, EsquinaDerecha);
		// Los comparamos
		if (EsquinaIzquierda = EsquinaDerecha) then
		begin
			// como las esquinas son iguales, podemos asignar la variable que queramos a ValorAComprobar
			ValorAComprobar := EsquinaIzquierda;
			// Reiniciamos las repeticiones
			Repeticiones := 0;
			// Iteramos sobre los movimientos de la mesa
			for mov := 1 to Domino.UltimoMovimiento do
				// Por cada ficha evaluamos si alguna de sus caras es ValorAComprobar
				if ((Domino.Mesa[mov].Ficha.Cara1 = ValorAComprobar) or (Domino.Mesa[mov].Ficha.Cara2 = ValorAComprobar)) then
					// de ser asi, entonces aumentamos las repeticiones
					Repeticiones := Repeticiones + 1;
			// si encontramos ese valor 7 veces en la mesa, y aparte las esquinas son ese valor, entonces el juego esta trancado
			if Repeticiones = 7 then
				estaTrancado := True
			else
				// aun falta una ficha con ese valor por ser jugada`
				estaTrancado := False;
		end
		else
			// juego comun
			estaTrancado := False;
	end;
var
	MenorPuntaje, SumF, perdedor, ganador, FichaActual, Cochina: byte;
	CochinaUbicada: boolean;
begin
	Domino.ganadoPartida := false;
	// si la partida es guardada, usemos los valores de esa partida, no se puede reiniciar la mesa ni el reparto
	if not(Guardada) then
	begin
		// limpiamos la mesa
		LimpiarMesa;
		// Generamos el pote
		GenerarPote;
		// Repartimos las fichas
		RepartirFichas;
	end;
	// Reiniciamos las coordenadas de las fichas
	EsquinaIzquierda.X := 1;
	EsquinaDerecha.X := 1;
	EsquinaIzquierda.Y := 1;
	EsquinaDerecha.Y := 1;
	// condicional para saber si estamos en la primera ronda de la partida
	// hacemos esto para ubicar el doble 6 para que el primer turno sea del poseedor. En caso de que nadie la tenga (Juegos de < 4 jugadores),
	// se empezara con una ficha aleatoria del pote
	// solo probamos hasta 3 jugadores porque cuando sean 4 se juega en equipos, y los puntajes son sumados. Probamos 3 para el caso 3 jugadores
	if not(Guardada) then 
	begin
		if ((Domino.Jugadores[1].puntajeObtenido = 0) and (Domino.Jugadores[2].puntajeObtenido = 0) and (Domino.Jugadores[3].puntajeObtenido = 0)) then
		begin
			// inicializamos el iterador de las fichas
			Domino.JugadorActual := 1;
			// asumimos que no hemos encontrado la cochina
			CochinaUbicada := false;
			// mientras que no hayamos alcanzado la cantidad de jugadores y no ubiquemos la cochina, iteremos
			while ((Domino.JugadorActual <= Domino.config.cantidadJugadores) and not(CochinaUbicada)) do
			begin
				// reiniciamos el iterador de fichas
				FichaActual := 1;
				// mientras no hayamos visto las 7 fichas y no hayamos ubicado la Cochina, iteremos
				// Si entramos, estamos en la primera ronda, y los jugadores tendran 7 fichas, por tanto podemos poner como condicion del for to 7
				while ((FichaActual <= 7) and not(CochinaUbicada)) do
				begin
					// comparamos las caras de la ficha actual contra el doble 6
					if ((Domino.Jugadores[Domino.JugadorActual].Fichas[FichaActual].Cara1 = 6) and (Domino.Jugadores[Domino.JugadorActual].Fichas[FichaActual].Cara2 = 6)) then
					begin
						// si la encontramos, ya nos podemos salir. Colocamos el indicador a true
						CochinaUbicada := true;
						// guardamos el indice de la cochina
						Cochina := FichaActual;
					end;
					// aumentamos el indice
					FichaActual := FichaActual + 1;
				end;
				// si no la ubicamos, entonces aumentamos el indice de jugador (nos interesa que no se altere si lo ubicamos)
				if not(CochinaUbicada) then
					Domino.JugadorActual := Domino.JugadorActual + 1;
			end;
			// si no encontramos entre los jugadores, que se juegue la primera piedra del pote (Como en cada ronda es aleatoria, la primera lo sera tambien)
			if not(CochinaUbicada) then
			begin
				// jugamos la primera ficha del pote en la esquina nula
				JugarFicha(Domino.PoteJuego[1], nulo);
			end
			else
			begin
				// si la ubicamos, entonces jugamos esa ficha en la esquina nula
				JugarFicha(Domino.Jugadores[Domino.JugadorActual].Fichas[Cochina], nulo);
				// como guardamos el indice del jugador actual, ese fue el primer movimiento, guardemos su indice para las siguientes rondas
				Domino.primerTurno := Domino.JugadorActual;
				// aumentamos el iterador global para que empiece el jugador siguiente
				Domino.JugadorActual := Domino.JugadorActual + 1;
			end;
			// readln;
		end
		else
		// No es la primera ronda de la partida, entonces primerTurno ya tiene valor, solamente hay que aumentarlo teniendo en cuenta circularidad respecto a cantidadJugadores
		begin
			// como sabemos quien empezo la ronda anterior, tenemos que aumentar ese primerTurno
			Domino.primerTurno := Domino.primerTurno + 1;
			// si se pasa de la cantidad de jugadores, lo reiniciamos a 1 (circularidad)
			if Domino.primerTurno > Domino.config.cantidadJugadores then
				Domino.primerTurno := 1;
			// Asignamos primerTurno al iterador global
			Domino.JugadorActual := Domino.primerTurno;
		end;
	end;
	Guardada := false;

	// Ciclo mas externo: Ejecutado hasta que alguien se quede sin fichas o hasta que se tranque el juego
	repeat
		// si el iterador global es mayor que la cantidad de jugadores, reiniciamos el iterador a 1 (circularidad)
		if Domino.JugadorActual > Domino.config.cantidadJugadores then
			Domino.JugadorActual := 1;
		// Ciclo mas interno, itera sobre los jugadores y les plantea su turno. Reiniciamos cuando hayamos pasado por todos los jugadores o alguna condicion de victoria se cumpla
		// mientras que no hayan intentado jugar los jugadores, y el jugador actual aun tenga fichas y no este trancado el juego, iteremos
		while ((Domino.JugadorActual <= Domino.config.cantidadJugadores ) and (NumeroFichas(Domino.Jugadores[Domino.JugadorActual]) > 0) and (not estaTrancado) and not(SalirAplicacion)) do
		begin
			// planteamos el turno a cada jugador
			PlantearTurno;
			// si el numero de fichas del jugador actual es mayor a 0 despues de su turno, aumentemos el iterador; aun no hay ganador
			if (Numerofichas(Domino.Jugadores[Domino.JugadorActual]) > 0) then
				Domino.JugadorActual := Domino.JugadorActual + 1;
			// si llegamos a aumentar y nos pasamos del maximo, entonces reiniciemos (esto evita ganadores fantasmas en partidas de < 4 jugadores)
			if Domino.JugadorActual > Domino.config.cantidadJugadores then
				Domino.JugadorActual := 1;
		end;
	until ((NumeroFichas(Domino.Jugadores[Domino.JugadorActual]) = 0) or estaTrancado or SalirAplicacion);

	{ 
		CODIGO DE FINALIZACION DE RONDA 
		Este codigo solo se debe ejecutar cuando el ciclo anterior haya acabado --PORQUE SE ACABO LA RONDA-- Si termino porque el jugador se salio, vamos al final
	}
	if not(SalirAplicacion) then
	begin
		// Caso de final 1: El jugador actual se quedo sin fichas
		if (NumeroFichas(Domino.Jugadores[Domino.JugadorActual]) = 0) then
		begin
			// limpiamos pantalla
			clrscr;
			// mensaje de victoria
			Writeln('La ronda se ha acabado!! ', Domino.Jugadores[Domino.JugadorActual].Nombre, ' se ha quedado sin fichas');
			// hay que hacer un conteo algo diferente en el caso de 4 Domino.jugadores, ya que es por equipos
			if Domino.config.cantidadJugadores = 4 then 
			begin
				// si el indice del jugador actual es par, su equipo es 4 o 2; sumemos las fichas de 1 y 3
				if (Domino.jugadorActual mod 2 = 0) then
					Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido := SumatoriaFichas(Domino.Jugadores[1]) + SumatoriaFichas(Domino.Jugadores[3])
				// si es impar, su equipo es 1 o 3; sumemos las fichas de 2 y 4
				else
					Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido := SumatoriaFichas(Domino.Jugadores[2]) + SumatoriaFichas(Domino.Jugadores[4]);
				if Domino.JugadorActual > 2 then
					Domino.Jugadores[Domino.JugadorActual - 2].PuntajeObtenido := Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido
				// si el indice es mayor que 2, su equipo es él - 2. Caso contrario es él + 2
				else
					Domino.Jugadores[Domino.JugadorActual + 2].PuntajeObtenido := Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido;
			end
			else
				// en cualquier otro caso, ya sabemos que el jugador actual es el ganador, sumemos las fichas de los perdedores
				for perdedor := 1 to Domino.config.cantidadJugadores do
					// evitemos sumar las fichas del jugador Actual (Aunque esta suma daria 0 de todas formas)
					if perdedor <> Domino.JugadorActual then
						// Agregamos a su puntaje la sumatoria de cada perdedor
						Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido := Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido + SumatoriaFichas(Domino.Jugadores[perdedor]);
		end
		// Caso de final 2: el juego esta trancado 
		else if estaTrancado then 
		begin
			// mensaje de tranca
			Writeln('El Juego esta trancado, el que tenga la menor suma gana');
			// asumimos un puntaje muy alto como menor suma para hallar el minimo
			MenorPuntaje := 100;
			// consideramos a todos perdedores e iteramos sobre ellos
			for perdedor := 1 to Domino.config.cantidadJugadores do
			begin
				// guardamos la suma de las fichas en una variable (para no hacer tantas llamadas)
				SumF := SumatoriaFichas(Domino.Jugadores[perdedor]);
				// Escribimos la suma de las fichas del perdedor actual
				WriteLn('Suma de fichas de ', Domino.Jugadores[perdedor].nombre, ': ', SumF);
				// comparamos su suma contra el menor puntaje
				if SumF < MenorPuntaje then
				begin
					// de ser menor, sobreescribimos MenoPuntaje
					MenorPuntaje := SumF;
					// guardamos el indice del ganador
					ganador := perdedor;
				end;
			end;
			// Hay un caso especial para 4 jugadores. Es la misma consideracion de arriba
			if Domino.config.cantidadJugadores = 4 then
			begin
				if (ganador mod 2 = 0) then
					Domino.Jugadores[ganador].puntajeObtenido := Domino.Jugadores[ganador].puntajeObtenido + SumatoriaFichas(Domino.Jugadores[2]) + SumatoriaFichas(Domino.Jugadores[4])
				else
					Domino.Jugadores[ganador].puntajeObtenido := Domino.Jugadores[ganador].puntajeObtenido + SumatoriaFichas(Domino.Jugadores[1]) + SumatoriaFichas(Domino.Jugadores[3]);
				if (ganador > 2) then
					Domino.Jugadores[ganador - 2].puntajeObtenido := Domino.Jugadores[ganador].PuntajeObtenido
				else
					Domino.Jugadores[ganador + 2].puntajeObtenido := Domino.Jugadores[ganador].PuntajeObtenido;
			end
			else
				for perdedor := 1 to Domino.config.cantidadJugadores do
					if perdedor <> ganador then
						Domino.Jugadores[ganador].puntajeObtenido := Domino.Jugadores[ganador].puntajeObtenido + SumatoriaFichas(Domino.Jugadores[perdedor]);

		end;
		Writeln('El marcador esta de la siguiente forma:');
		for Domino.JugadorActual := 1 to Domino.config.cantidadJugadores do
		begin
			if (Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido >= Domino.Config.PuntajeObj) then
			begin
				Domino.ganadoPartida := True;
				ganador := Domino.JugadorActual;
			end;
			Writeln(Domino.Jugadores[Domino.JugadorActual].Nombre, ': ', Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido);
		end;
		if (Domino.ganadoPartida) then
		begin
			if Domino.config.cantidadJugadores = 4 then
			begin
				Write('Los jugadores ',Domino.Jugadores[ganador].Nombre,' y ');
				if ganador > 2 then
					Write(Domino.Jugadores[ganador - 2].Nombre)
				else
					Write(Domino.Jugadores[ganador + 2].Nombre);
				WriteLn(' han ganado la partida!!! Felicidades!');
			end
			else
				WriteLn('El jugador ', Domino.Jugadores[ganador].Nombre, ' ha ganado la partida!!! Felicidades!');
			WriteLn('Presione ENTER para volver al menu principal');
			SalirAplicacion := true;
			readln;
			// for Domino.JugadorActual:=1 to Domino.Config.CantidadJugadores do
			// 	Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido := 0; 
			// MenuPrincipal;
		end
		else
		begin
			Writeln('Presione ENTER para continuar con la siguiente ronda');
			Writeln('Presione ESC para guardar la partida y continuar luego');
			repeat
				OpcionActual := Readkey;
				case OpcionActual of
					#27: begin
						SalirAplicacion := true;
						MenuGuardado;
					end;
				end;
			until ((OpcionActual = #27) or (OpcionActual = #13) or (SalirAplicacion));
		end;
	end;
end;


{
	InitPartida:
	Ciclo principal de una partida de domino. Sencillamente este procedimiento se ejecuta hasta que se desee salir de la aplicacion o haya un ganador en la partida.
}
procedure InitPartida();
begin
	// solo nos interesa empezar a jugar si tenemos todas las configuraciones
	if TodoListo() then
	begin
		repeat
			// repetimos rondas hasta que haya un ganador o debamos salir
			InitRonda;
		// comparamos tambien el jugador 3 por los juegos de 3 jugadores
		until ((SalirAplicacion) or (Domino.Jugadores[1].PuntajeObtenido >= Domino.config.PuntajeObj) or (Domino.Jugadores[2].PuntajeObtenido >= Domino.config.PuntajeObj) or (Domino.Jugadores[3].PuntajeObtenido >= Domino.config.PuntajeObj));
			for Domino.JugadorActual := 1 to Domino.config.CantidadJugadores do
				// reiniciamos sus puntajes
				Domino.Jugadores[Domino.JugadorActual].PuntajeObtenido := 0
	end
	else
		PeticionCompletacion;
end;

{
	ToggleMostrarTodo
}
procedure ToggleMostrarTodo();
begin
	if Domino.config.MostrarTodo then
		Domino.config.MostrarTodo := False
	else 
		Domino.config.MostrarTodo := True;
end;


procedure SetModoJuego();
	procedure ImprimirMenuModoJuego();
	var
		m: ModosJuego;
	begin
		ImprimirTitulo;
		WriteLn('Seleccione el modo de juego');
		for m := Individual to Espectador do
			WriteLn(Ord(m)+1,': ',MODOS[m]);	
		WriteLn('ESC: Volver al men'#163' anterior');
	end;
var
	nuevoModo: ModosJuego; // Variable auxiliar cuyo proposito es comparar el modo de juego escogido con el que se tiene actualmente, para saber si vale la pena reiniciar la cantidad/clasif. de jugadores (solo vale la pena cuando el nuedo modo de juego es diferente al actual)
	Salir:Boolean;
begin
	Salir:=False;
	repeat
		ImprimirMenuModoJuego;
		OpcionActual := ReadKey;
		case OpcionActual of //menu donde el usuario escoge la cantidad y tipo de jugadores
			'1'..'3': nuevoModo := ModosJuego(Ord(OpcionActual) - 49); // Asignamos restando 49 para que quede como un numero mas alto que el char introducido (Porque los enum empiezan en 0, hay un offset)
			#27: Salir := true;
		end;
	until ((OpcionActual >= '1') and (OpcionActual <= '3') or Salir);
	if not(Salir) then
		if nuevoModo <> Domino.config.ModoJuego then
		begin
			Domino.config.ModoJuego := nuevoModo;
			Domino.config.cantidadJugadores := 0; 
			Domino.config.cantidadPersonas := 0; 
			Domino.config.cantidadPCs := 0;
		end;
end;

procedure CargarPartida();
	procedure ImprimirMenuCargarPartida();
	begin
		ImprimirTitulo;
		Writeln('Seleccione un Slot de Guardado'); //esta opcion te permite reanudar una partida guardada
		Writeln('A - SLOT A');
		Writeln('B - SLOT B');
		Writeln('C - SLOT C');
		Writeln('ESC: Volver al menu principal');
		Writeln('S: Salir de la aplicacion')
	end;
var
	Slot: file of RPartida;
	DominoPath: string;
	Intento: Word;
	Salir:Boolean;
begin
	Salir:=False;
	DominoPath := ExtractFilePath(ParamStr(0));
	repeat
		ImprimirMenuCargarPartida;
		// opcion actual en la carga de partida anterior
		OpcionActual := ReadKey;
		if ((OpcionActual = #83) or (OpcionActual = #115)) then
			SalirAplicacion := True
		else if OpcionActual = #27 then
			Salir := true
		else if ((UpCase(OpcionActual) < 'A') or (UpCase(OpcionActual) > 'C')) then
			Writeln('Slot de archivo invalido')
		else
		begin
			Assign(Slot, DominoPath + 'Partida' + UpCase(OpcionActual) + '.domino');
			{$I-}
			Reset(Slot);
			{$I+}
			Intento := IOResult;
			if Intento <> 0 then
			begin
				WriteLn('El archivo de guardado ',DominoPath + 'Partida' + UpCase(OpcionActual) + '.domino',' no existe o esta corrupto. Intente otro (presione ENTER para quitar este mensaje)');
				readln;
			end
			else
			begin
				Read(Slot, Domino);
				Close(Slot);
				Guardada := true;
				SalirAplicacion := false;
				InitPartida;
			end;
		end;
	until ((Salir) or (SalirAplicacion));
end;

procedure SetPuntajeObj();
	procedure ImprimirMenuPuntajeObj();
	begin
		ImprimirTitulo;
		Writeln('Escoja el puntaje objetivo'); //menu donde el usuario escoge el puntaje obtenido
		Writeln('1: 50 ptos');
		Writeln('2: 100 ptos');
		Writeln('ESC: Volver al men'#163' anterior');
	end;
var
	Salir: Boolean;
begin
	Salir := false;
	repeat
		ImprimirMenuPuntajeObj;
		OpcionActual := ReadKey;
		case OpcionActual of
			'1': Domino.config.PuntajeObj := 50;
			'2': Domino.config.PuntajeObj := 100;
			#27: Salir := true;
		end;
	until ((OpcionActual = '1') or (OpcionActual = '2') or Salir);
end;

procedure SetCantidadJugadores();
	procedure HabilitarPCPregunta();
	var
	   // Jugador actual (iterador)
	   Jugador: byte;
	begin
		repeat
			ImprimirTitulo;	
			Writeln('Presione enter para completar los jugadores restantes? (Presione ESC para no completar)'); //el programa le da la opcion al ususario de completar los jugadores restantes con pc
			OpcionActual := Readkey;
			case OpcionActual of
				#13: Domino.config.habilitarPC := true;
				#27: Domino.config.habilitarPC := false;
			end;
		until ((OpcionActual = #13) or (OpcionActual = #27));
		OpcionActual := #0;
		// Ahora tenemos que completar los jugadores
		if Domino.config.habilitarPC then
		begin
			// La cantidad de PCs sera lo maximo que se puede tener de jugadores menos la cantidad de personas.
			// Como la cantidad de personas en este punto es siempre igual a la cantidad de jugadores 
			Domino.config.cantidadJugadores := 4;
			Domino.config.cantidadPCs := Domino.config.cantidadJugadores - Domino.config.cantidadPersonas;
			// especificamos que los demas son bots
			for Jugador := (Domino.config.CantidadPersonas + 1) to 4 do
				Domino.Jugadores[Jugador].Humano := False;

		end;
	end;

	procedure SetNombres();
		procedure ImprimirMenuNombres(); //opcion para que el usuario introduzca los nombres de los jugadores
		begin
			ImprimirTitulo;
			if Domino.config.ModoJuego <> Espectador then
				Writeln('Ingrese a continuaci'#162'n los nombres de los jugadores que participar'#160'n');
		end;
	var
		i: byte;
	begin
		ImprimirMenuNombres;
		if Domino.config.ModoJuego <> Espectador then
		begin
			// habilitamos el cursor para la escritura
			CursorOn;
			for i := 1 to Domino.config.cantidadPersonas do
			begin
				Writeln('Nombre del jugador ', i);
				repeat
					Readln(Domino.Jugadores[i].nombre);
					if Domino.Jugadores[i].nombre = '' then
						WriteLn('El nombre no puede estar vac'#161'o')
				until Domino.Jugadores[i].nombre <> '';
				Domino.Jugadores[i].Humano := True;
				Domino.Jugadores[i].Indice := i;
			end;
			// lo desactivamos otra vez
			CursorOff;
		end;
		if Domino.config.habilitarPC then
			for i := (Domino.config.CantidadJugadores - Domino.config.cantidadPCs + 1) to Domino.config.cantidadJugadores do
			begin
				//si el usuario completo con pc llamara a los bots como "CPU"
				Domino.Jugadores[i].nombre := 'CPU' + chr(i + 48); //#48..#57 = '0'..'9'. Por lo que teniendo un digito en int, su valor ascii es: Digito + 48
				Domino.Jugadores[i].Humano := False;
				Domino.jugadores[i].Indice := i;
			end;
	end;
	procedure ImprimirMenuCantidadjugadores();
	begin
		ImprimirTitulo;
		Writeln('Escriba la cantidad de jugadores que desea (Min 2, Max 4).'); //menu donde el usuario escoge la cantidad de jugadores
		Writeln('Presione ESC para volver al men'#163' anterior');
	end;
Var
	Salir:Boolean;
begin
	Salir:=False;
	repeat
		ImprimirMenuCantidadjugadores;
		// Como necesitamos un numero entre 2 y 4, pero tambien la necesidad de que se salga con ESC,
		// Hacemos un readkey y case para la opcion actual. En caso de que sea ESC, salimos al menu anterior,
		// En cambio, si es un numero entre 2 y 4 ('2' al '4'), se lo asignamos a la cantidad de jugadores (Usando la funcion Ord()).
		OpcionActual := Readkey;
		case OpcionActual of
			'2'..'4': Domino.config.cantidadJugadores := Ord(OpcionActual)-48;
			#27: Salir := true;
		end;
	until (((OpcionActual >= '2') and (OpcionActual <= '4')) or Salir);
	if not(Salir) then
	begin
		(* La contabilizacion/clasificacion de los jugadores depende del modo de juego y si habilitaron PCs *)
		case Domino.config.ModoJuego of
			Individual: begin // si el modo de juego es individual, la cantidad de personas es 1 y el resto se calcula por diferencia de lo que introdujo el jugador - la cantidad de personas (1)
				Domino.config.cantidadPersonas := 1;
				Domino.config.cantidadPCs := Domino.config.cantidadJugadores - Domino.config.cantidadPersonas;
				Domino.config.habilitarPC := true;
			end;
			Multijugador: begin // si el modo de juego es multijugador, entonces la cantidad de personas es lo que ponga el jugador y y le preguntamos por completacion de bots
				Domino.config.cantidadPersonas := Domino.config.cantidadJugadores;
				if Domino.config.cantidadJugadores < 4 then
					HabilitarPCPregunta;
			end;
			Espectador: begin // en caso de que sea espectador, todos los jugadores seran computadoras. Ponemos la opcion de habilitar PCs como true para comprobaciones mas adelante
				Domino.config.habilitarPC := true;
				Domino.config.cantidadPersonas := 0;
				Domino.config.cantidadPCs := Domino.config.cantidadJugadores;
			end;
		end;
		SetNombres; // Llamamos al proceso de nombrar a los jugadores
	end;
end;



procedure NuevaPartida();
	procedure ImprimirMenuNuevaPartida();
	begin
		ImprimirTitulo;

		Writeln('Configure los aspectos de la partida');
			{--- OPCIONES ---}
			Writeln('1: Modo de juego (Actual: ',MODOS[Domino.config.ModoJuego],')');
			Writeln('2: Seleccionar cantidad de jugadores (Actual: ',Domino.config.CantidadJugadores,' => Humanos: ',Domino.config.cantidadPersonas,', PCs: ',Domino.config.cantidadPCs,')');
			Writeln('3: Cantidad de Puntos objetivo (Actual: ',Domino.config.PuntajeObj,')');
			Writeln('4: (Des)habilitar mostrado de todas las fichas? (Actual: ',Domino.config.MostrarTodo,')');
			Writeln('5: Iniciar Partida');
			Writeln('ESC: Volver al men'#163' principal');
			Writeln('S: Cerrar aplicacion ' )
	end;
var
	Salir: Boolean;
begin
	Salir:=False;
	// Mientras la opcion sea incorrecta, que siempre pueda darle a alguna tecla
	repeat
		ImprimirMenuNuevaPartida;
		// opcion actual en la creacion de nueva partida
		OpcionActual := ReadKey;
		case OpcionActual of
			'1': SetModoJuego;
			'2': SetCantidadJugadores;
			'3': SetPuntajeObj;
			'4': ToggleMostrarTodo;
			'5': begin
				Guardada := false;
				InitPartida;
			end;
			#27:  Salir := true;
			's','S': SalirAplicacion:=True;
		end;
	until (Salir or SalirAplicacion);
end;


procedure MenuPrincipal();
	procedure ImprimirMenuPrincipal();
	begin
		ImprimirTitulo;

		Writeln('Bienvenido al juego de domin'#162);
		Writeln('Escoja una de las siguientes opciones para comenzar:');
			{--- OPCIONES ---}
			Writeln('1: Iniciar nueva Partida');
			Writeln('2: Cargar Partida existente');
			Writeln('ESC: Salir de la aplicaci'#162'n');
	end;
var
	Salir: Boolean;
begin
	// ocultamos el cursor
	CursorOff;
	repeat
		ImprimirMenuPrincipal;
		// opcion actual del menu principal
		OpcionActual := ReadKey;
		case OpcionActual of
			'1': begin
				NuevaPartida; 
				SalirAplicacion := False;
			end;
			'2': begin
				CargarPartida;
				SalirAplicacion := false;
			end;
			// #27 = ESC
			#27: SalirAplicacion := true;
		end;
	until (SalirAplicacion);
end;
begin
	repeat
		MenuPrincipal;
	until SalirAplicacion;
end.
