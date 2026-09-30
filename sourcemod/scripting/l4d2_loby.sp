#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

bool g_bAllowDisconnect = false;

public Plugin myinfo =
{
	name = "Block Auto Return to Lobby (+ Admin Force)",
	author = "MasterMind420 / Fixed",
	description = "Prevents all return to lobby requests other than from votes or admins",
	version = "1.2",
	url = ""
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("VotePass"), OnUserMessage, true);
	HookUserMessage(GetUserMessageId("DisconnectToLobby"), OnUserMessage, true);
	
	// Registramos el nuevo comando para administradores (requiere flag de cambio de mapa/genérico)
	RegAdminCmd("sm_forcelobby", Command_ForceLobby, ADMFLAG_CHANGEMAP, "Fuerza el regreso de todos los jugadores al lobby.");
}

// Acción que se ejecuta cuando el admin usa !forcelobby
public Action Command_ForceLobby(int client, int args)
{
	// 1. Autorizamos temporalmente la desconexión saltándonos la votación
	g_bAllowDisconnect = true;
	
	// 2. Avisamos a los jugadores en el chat
	PrintToChatAll("\x04[SM] \x01Un administrador ha forzado el regreso al lobby.");
	
	// 3. Generamos el mensaje del motor para enviarlos al lobby
	Handle msg = StartMessageAll("DisconnectToLobby");
	if (msg != null)
	{
		EndMessage();
	}
	else
	{
		// Si por alguna razón el motor falla al crear el mensaje, reseteamos la variable
		g_bAllowDisconnect = false;
		ReplyToCommand(client, "[SM] Error interno: No se pudo forzar el lobby.");
	}
	
	return Plugin_Handled;
}

public Action OnUserMessage(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (msg_id == GetUserMessageId("VotePass"))
	{
		char sBuffer[64];
		bf.ReadString(sBuffer, sizeof(sBuffer));

		if (StrContains(sBuffer, "vote_passed_return_to_lobby") > -1 || StrContains(sBuffer, "vote_passed") > -1)
		{
			g_bAllowDisconnect = true;
		}
		
		return Plugin_Continue;
	}
	else if (msg_id == GetUserMessageId("DisconnectToLobby"))
	{
		if (g_bAllowDisconnect)
		{
			g_bAllowDisconnect = false;
			return Plugin_Continue;
		}
		
		return Plugin_Handled;
	}

	return Plugin_Continue;
}