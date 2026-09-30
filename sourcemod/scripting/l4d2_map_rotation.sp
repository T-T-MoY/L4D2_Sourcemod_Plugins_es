#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ArrayList g_hMapList;
StringMap g_smMapNames;
char g_sNextMap[64];

public Plugin myinfo = 
{
	name = "L4D2 Votemap & Smart Rotation",
	author = "[T-T]MoY",
	description = "Votación de mapas estilo CS2, panel de admin y auto-rotación",
	version = "2.0",
	url = ""
};

public void OnPluginStart()
{
	g_hMapList = new ArrayList(ByteCountToCells(64));
	g_smMapNames = new StringMap();
	
	// Diccionario de traducciones de mapas oficiales
	SetupMapTranslations();
	LoadMapCycle();
	
	// Evento para ejecutar el cambio al terminar los créditos
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);

	// Comandos
	RegConsoleCmd("sm_votemap", Command_VoteMap, "Abre la votación del siguiente mapa");
	RegAdminCmd("sm_mapadmin", Command_MapAdmin, ADMFLAG_CHANGEMAP, "Menú de control de mapas para admins");
	RegAdminCmd("sm_reloadmaps", Command_ReloadMaps, ADMFLAG_CONFIG, "Recarga el map_cycle.txt");
}

public void OnMapStart()
{
	// Limpiamos el próximo mapa al iniciar uno nuevo
	strcopy(g_sNextMap, sizeof(g_sNextMap), "");
}

// ─── COMANDO: !votemap (Jugadores y Admins) ───────────────────────────────
public Action Command_VoteMap(int client, int args)
{
	if (client == 0) return Plugin_Handled;

	// Evitar inanición: Si ya hay un voto activo, rechazar.
	if (IsVoteInProgress()) {
		PrintToChat(client, "\x03[T-T]\x01 Ya hay una votación en curso, papu. ¡Vota en el menú!");
		return Plugin_Handled;
	}

	// Verificar si es mapa final. Si no lo es, solo un admin puede forzarlo.
	bool isFinal = L4D_IsMissionFinalMap();
	bool isAdmin = CheckCommandAccess(client, "sm_mapadmin", ADMFLAG_CHANGEMAP);

	if (!isFinal && !isAdmin) {
		PrintToChat(client, "\x03[T-T]\x01 Este comando solo se puede usar en el capitulo final de la campaña.");
		return Plugin_Handled;
	}

	StartMapVote(client);
	return Plugin_Handled;
}

// ─── COMANDO: !mapadmin (Solo Admins) ─────────────────────────────────────
public Action Command_MapAdmin(int client, int args)
{
	if (client == 0) return Plugin_Handled;
	ShowAdminMenu(client);
	return Plugin_Handled;
}

// ─── LOGICA DE VOTACIÓN ───────────────────────────────────────────────────
void StartMapVote(int client)
{
	if (g_hMapList.Length == 0) {
		PrintToChat(client, "\x03[T-T]\x01 El archivo de configuración de mapas está vacío.");
		return;
	}

	Menu voteMenu = new Menu(MenuHandler_VoteMap);
	voteMenu.SetTitle("¿Qué mapa jugamos después?");

	char sCurrentMap[64], sCurrentPrefix[32];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	GetCampaignPrefix(sCurrentMap, sCurrentPrefix, sizeof(sCurrentPrefix));

	char sLoopMap[64], sLoopPrefix[32], sDisplayName[128], sTranslated[64];

	// Construir la lista de mapas
	for (int i = 0; i < g_hMapList.Length; i++)
	{
		g_hMapList.GetString(i, sLoopMap, sizeof(sLoopMap));
		GetCampaignPrefix(sLoopMap, sLoopPrefix, sizeof(sLoopPrefix));

		// Buscar si tiene traducción en español
		if (!g_smMapNames.GetString(sLoopMap, sTranslated, sizeof(sTranslated))) {
			strcopy(sTranslated, sizeof(sTranslated), sLoopMap); // Si es custom, usa el nombre del archivo
		}

		// Si el mapa del ciclo es de la misma campaña que estamos jugando ahora
		if (StrEqual(sCurrentPrefix, sLoopPrefix, false)) {
			Format(sDisplayName, sizeof(sDisplayName), "%s [En juego]", sTranslated);
			voteMenu.AddItem(sLoopMap, sDisplayName, ITEMDRAW_DISABLED); // No se puede votar
		} else {
			voteMenu.AddItem(sLoopMap, sTranslated); // Mapa elegible
		}
	}

	voteMenu.ExitButton = false;
	voteMenu.DisplayVoteToAll(20); // 20 segundos para votar
	PrintToChatAll("\x04[Rotación]\x01 \x03%N\x01 ha iniciado una votación de mapa.", client);
}

public int MenuHandler_VoteMap(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_VoteEnd)
	{
		char sWinner[64], sTranslated[64];
		menu.GetItem(param1, sWinner, sizeof(sWinner));
		
		strcopy(g_sNextMap, sizeof(g_sNextMap), sWinner);

		if (!g_smMapNames.GetString(sWinner, sTranslated, sizeof(sTranslated))) {
			strcopy(sTranslated, sizeof(sTranslated), sWinner);
		}

		PrintToChatAll("\x04[Rotación]\x01 La votación terminó. Próximo mapa: \x05%s", sTranslated);
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("\x04[Rotación]\x01 Nadie votó. El mapa se elegirá automáticamente.");
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

// ─── MENÚ DE ADMIN ────────────────────────────────────────────────────────
void ShowAdminMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_AdminMenu);
	hMenu.SetTitle("Menú de Control de Mapas");

	hMenu.AddItem("force_vote", "★ Forzar Votación Ahora");
	hMenu.AddItem("force_map",  "▶ Elegir Siguiente Mapa (Sin voto)");
	hMenu.AddItem("cancel",     "✖ Cancelar Votación Actual");
	hMenu.AddItem("lobby",      "⌂ Forzar regreso al Lobby");

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if (StrEqual(sInfo, "force_vote")) {
			if (IsVoteInProgress()) CancelVote(); // Limpia la pista antes de lanzar otra
			StartMapVote(param1);
		}
		else if (StrEqual(sInfo, "force_map")) {
			ShowForceMapMenu(param1);
		}
		else if (StrEqual(sInfo, "cancel")) {
			if (IsVoteInProgress()) {
				CancelVote();
				PrintToChatAll("\x04[Rotación]\x01 Un Admin canceló la votación.");
			} else {
				PrintToChat(param1, "\x03[T-T]\x01 No hay ninguna votación en curso.");
				ShowAdminMenu(param1);
			}
		}
		else if (StrEqual(sInfo, "lobby")) {
			PrintToChatAll("\x04[Rotación]\x01 Regresando al Lobby...");
			CreateTimer(3.0, Timer_ReturnLobby);
		}
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
	return 0;
}

void ShowForceMapMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_ForceMap);
	hMenu.SetTitle("Selecciona el próximo mapa:");

	char sLoopMap[64], sTranslated[64];
	for (int i = 0; i < g_hMapList.Length; i++) {
		g_hMapList.GetString(i, sLoopMap, sizeof(sLoopMap));
		if (!g_smMapNames.GetString(sLoopMap, sTranslated, sizeof(sTranslated))) {
			strcopy(sTranslated, sizeof(sTranslated), sLoopMap);
		}
		hMenu.AddItem(sLoopMap, sTranslated);
	}
	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ForceMap(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sChosen[64], sTranslated[64];
		menu.GetItem(param2, sChosen, sizeof(sChosen));

		if (IsVoteInProgress()) CancelVote(); // Mata el voto si el admin se salta las reglas

		strcopy(g_sNextMap, sizeof(g_sNextMap), sChosen);
		if (!g_smMapNames.GetString(sChosen, sTranslated, sizeof(sTranslated))) {
			strcopy(sTranslated, sizeof(sTranslated), sChosen);
		}

		PrintToChatAll("\x04[Rotación]\x01 Un Admin ha fijado el próximo mapa a: \x05%s", sTranslated);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
		ShowAdminMenu(param1);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
	return 0;
}

// ─── FINAL DE CAMPAÑA (ROTACIÓN EJECUCIÓN) ────────────────────────────────
public void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	// Si nadie votó o la votación se canceló, elegimos automáticamente el siguiente de la lista
	if (g_sNextMap[0] == '\0') {
		if (ResolveNextMap()) {
			PrintToChatAll("\x04[Rotación]\x01 Ningún mapa fue votado. Rotación automática en progreso...");
		} else {
			return; // Error al leer config
		}
	}

	char sTranslated[64];
	if (!g_smMapNames.GetString(g_sNextMap, sTranslated, sizeof(sTranslated))) {
		strcopy(sTranslated, sizeof(sTranslated), g_sNextMap);
	}

	PrintToChatAll("\x04[Rotación]\x01 ¡Campaña superada! Cambiando a \x05%s\x01 en unos segundos.", sTranslated);
	CreateTimer(4.5, Timer_ExecuteChangeLevel);
}

// El motor que autocalcula si nadie votó (ignora la campaña actual)
bool ResolveNextMap()
{
	int iSize = g_hMapList.Length;
	if (iSize <= 0) return false;

	char sCurrentMap[64], sCurrentPrefix[32];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	GetCampaignPrefix(sCurrentMap, sCurrentPrefix, sizeof(sCurrentPrefix));

	int iCurrentIndex = -1;
	char sTempMap[64], sTempPrefix[32];

	for (int i = 0; i < iSize; i++) {
		g_hMapList.GetString(i, sTempMap, sizeof(sTempMap));
		GetCampaignPrefix(sTempMap, sTempPrefix, sizeof(sTempPrefix));
		if (StrEqual(sCurrentPrefix, sTempPrefix, false)) {
			iCurrentIndex = i;
			break;
		}
	}

	int iNextIndex = (iCurrentIndex + 1 >= iSize) ? 0 : iCurrentIndex + 1;
	g_hMapList.GetString(iNextIndex, g_sNextMap, sizeof(g_sNextMap));

	// Salto de seguridad para no repetir campaña
	int iSafety = 0;
	char sNextPrefix[32];
	while (iSafety < iSize) {
		GetCampaignPrefix(g_sNextMap, sNextPrefix, sizeof(sNextPrefix));
		if (!StrEqual(sCurrentPrefix, sNextPrefix, false)) break;

		iNextIndex++;
		if (iNextIndex >= iSize) iNextIndex = 0;
		g_hMapList.GetString(iNextIndex, g_sNextMap, sizeof(g_sNextMap));
		iSafety++;
	}
	return true;
}

// ─── UTILERÍA Y HELPERS ───────────────────────────────────────────────────
public Action Timer_ExecuteChangeLevel(Handle timer)
{
	if (IsMapValid(g_sNextMap)) {
		ForceChangeLevel(g_sNextMap, "Rotación por Voto/Auto");
	} else {
		LogError("[Rotación] El mapa %s no es válido o no está instalado.", g_sNextMap);
	}
	return Plugin_Stop;
}

public Action Timer_ReturnLobby(Handle timer)
{
	// En L4D2 esto apaga la sesión de matchmaking y limpia el server mandando a todos al lobby real.
	ServerCommand("sv_crash"); 
	return Plugin_Stop;
}

void GetCampaignPrefix(const char[] mapName, char[] buffer, int maxlength)
{
	strcopy(buffer, maxlength, mapName);
	int underscorePos = FindCharInString(buffer, '_');
	int mPos = FindCharInString(buffer, 'm');
	
	if (mPos != -1 && (underscorePos == -1 || mPos < underscorePos)) {
		buffer[mPos] = '\0';
	} 
	else if (underscorePos != -1) {
		buffer[underscorePos] = '\0';
	}
}

void SetupMapTranslations()
{
	g_smMapNames.SetString("c1m1_hotel", "Dead Center (Punto Muerto)");
	g_smMapNames.SetString("c2m1_highway", "Dark Carnival (Feria Siniestra)");
	g_smMapNames.SetString("c3m1_plankcountry", "Swamp Fever (Pantanos)");
	g_smMapNames.SetString("c4m1_milltown_a", "Hard Rain (El Diluvio)");
	g_smMapNames.SetString("c5m1_waterfront", "The Parish (La Parroquia)");
	g_smMapNames.SetString("c6m1_riverbank", "The Passing (Defunción)");
	g_smMapNames.SetString("c7m1_docks", "The Sacrifice (El Sacrificio)");
	g_smMapNames.SetString("c8m1_apartment", "No Mercy (Alta Médica)");
	g_smMapNames.SetString("c9m1_alleys", "Crash Course (Terapia de Choque)");
	g_smMapNames.SetString("c10m1_caves", "Death Toll (Toque de Difuntos)");
	g_smMapNames.SetString("c11m1_greenhouse", "Dead Air (Último Vuelo)");
	g_smMapNames.SetString("c12m1_hilltop", "Blood Harvest (Cosecha de Sangre)");
	g_smMapNames.SetString("c13m1_alpinecreek", "Cold Stream (Aguas Turbulentas)");
	g_smMapNames.SetString("c14m1_junkyard", "The Last Stand (La Batalla Final)");
}

public Action Command_ReloadMaps(int client, int args)
{
	LoadMapCycle();
	ReplyToCommand(client, "\x04[Rotación]\x01 map_cycle.txt recargado con éxito.");
	return Plugin_Handled;
}

void LoadMapCycle()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/map_cycle.txt");

	File hFile = OpenFile(sPath, "r");
	if (hFile != null) {
		g_hMapList.Clear();
		char sBuffer[64];
		while (hFile.ReadLine(sBuffer, sizeof(sBuffer))) {
			TrimString(sBuffer);
			if (sBuffer[0] != '\0' && sBuffer[0] != ';' && sBuffer[0] != '/' && sBuffer[0] != '#') {
				g_hMapList.PushString(sBuffer);
			}
		}
		delete hFile;
	} else {
		File hNewFile = OpenFile(sPath, "w");
		if (hNewFile != null) delete hNewFile;
	}
}