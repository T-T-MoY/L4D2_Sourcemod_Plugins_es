#pragma semicolon 1
#pragma newdecls required // Sintaxis moderna obligatoria para SM 1.11 / 1.12+

#include <sourcemod>

#define PLUGIN_VERSION "2.0.0"
#define TAG_INFO "\x03[T-T]\x01" // Tu tag personalizado

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS  2
#define TEAM_INFECTED   3

// Variables para el Admin
ConVar g_cvEnableConnectMsg;
ConVar g_cvEnableTeamMsg;

// Arreglo para los timers de cada jugador
Handle g_hTimerTeamChange[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[L4D2] Mensajes de Unión de Jugadores mod [T-T]MoY",
	description = "Informa cuando un jugador se conecta y cambia de equipo.",
	author = "Dirka_Dirka,[T-T]MoY",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart() {
	// --- Comandos de Administrador (ConVars) ---
	g_cvEnableConnectMsg = CreateConVar("l4d2_joinmsg_connect", "0", "1 = Habilita el mensaje de conexion al servidor, 0 = Lo deshabilita.", FCVAR_NOTIFY);
	g_cvEnableTeamMsg    = CreateConVar("l4d2_joinmsg_team", "1", "1 = Habilita el mensaje de cambio de equipo, 0 = Lo deshabilita.", FCVAR_NOTIFY);

	AutoExecConfig(true, "l4d2_joinmessages"); // Crea un archivo .cfg automáticamente

	// Hook al evento de cambio de equipo
	HookEvent("player_team", Event_PlayerTeam);
}

// Usamos PutInServer en lugar de Connected para garantizar que el jugador ya puede recibir/emitir datos
public void OnClientPutInServer(int client) {
	if (IsValidPlayer(client) && !IsFakeClient(client)) {
		// Limpiamos cualquier timer residual
		g_hTimerTeamChange[client] = null;
		
		// Verificamos si el mensaje de conexión está activado
		if (g_cvEnableConnectMsg.BoolValue) {
			PrintToChatAll("%s \x04%N\x01 se ha conectado al servidor.", TAG_INFO, client);
		}
	}
}

public void OnClientDisconnect(int client) {
	if (IsValidPlayer(client)) {
		// Destruimos el timer si el jugador se desconecta antes de que se anuncie su equipo
		if (g_hTimerTeamChange[client] != null) {
			KillTimer(g_hTimerTeamChange[client]);
			g_hTimerTeamChange[client] = null;
		}
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	// Si el admin deshabilitó los mensajes de equipo, no hacemos nada
	if (!g_cvEnableTeamMsg.BoolValue) {
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");

	if (IsValidPlayer(client) && !IsFakeClient(client)) {
		// Si el jugador cambió de equipo muy rápido, cancelamos el aviso anterior
		if (g_hTimerTeamChange[client] != null) {
			KillTimer(g_hTimerTeamChange[client]);
			g_hTimerTeamChange[client] = null;
		}

		// Creamos un DataPack para enviar los datos al Timer con 1 segundo de retraso (evita spam)
		DataPack pack;
		g_hTimerTeamChange[client] = CreateDataTimer(1.0, Timer_AnnounceJoining, pack);
		pack.WriteCell(GetClientUserId(client));
		pack.WriteCell(team);
	}
	
	return Plugin_Continue;
}

public Action Timer_AnnounceJoining(Handle timer, DataPack pack) {
	// Reseteamos el pack para leer los datos
	pack.Reset();
	int userid = pack.ReadCell();
	int team = pack.ReadCell();

	int client = GetClientOfUserId(userid);

	// Verificamos que el cliente siga en el juego después del segundo de espera
	if (client > 0 && IsClientInGame(client)) {
		g_hTimerTeamChange[client] = null; // Liberamos el handle
		PrintJoinToAll(client, team);
	}

	return Plugin_Stop;
}

void PrintJoinToAll(int client, int team) {
	char sTeam[32];
	
	// Tus nombres personalizados
	switch (team) {
		case TEAM_SPECTATORS: Format(sTeam, sizeof(sTeam), "\x05Espectadores\x01");
		case TEAM_SURVIVORS:  Format(sTeam, sizeof(sTeam), "\x05Papus\x01");
		case TEAM_INFECTED:   Format(sTeam, sizeof(sTeam), "\x05Muertos\x01");
		default: return; // Si es un equipo no válido, cancelamos el mensaje
	}

	// Enviamos el mensaje a todos los jugadores menos al que se unió (para evitar redundancia)
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			if (i != client) {
				PrintToChat(i, "%s \x04%N\x01 se ha unido a los %s.", TAG_INFO, client, sTeam);
			}
		}
	}
}

// Función de validación para evitar errores de Index Out of Bounds
bool IsValidPlayer(int client) {
	return (client > 0 && client <= MaxClients);
}