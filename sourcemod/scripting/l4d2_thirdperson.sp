#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION 		"2.0-Public-HUD"
#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Thirdperson\x04] \x01"

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bMapStarted, g_bThirdView[MAXPLAYERS+1];
Handle g_hTimerReset[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[L4D2] Survivor Thirdperson (Public & HUD Fix)",
	author = "SilverShot (Edited for Public Use)",
	description = "Survivor thirdperson view for ALL players with HUD.",
	version = PLUGIN_VERSION,
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	// Cvars
	g_hCvarAllow = CreateConVar("l4d2_third_allow", "1", "0=Plugin desactivado, 1=Plugin activado para todos.", CVAR_FLAGS);
	g_hCvarModes = CreateConVar("l4d2_third_modes", "", "Activar plugin en estos modos (separar por comas). Vacio = todos.", CVAR_FLAGS);
	g_hCvarModesOff = CreateConVar("l4d2_third_modes_off", "", "Desactivar plugin en estos modos.", CVAR_FLAGS);
	g_hCvarModesTog = CreateConVar("l4d2_third_modes_tog", "0", "Filtro de modos numérico.", CVAR_FLAGS);
	CreateConVar("l4d2_third_version", PLUGIN_VERSION, "Survivor Thirdperson plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig(true, "l4d2_third");

	// Comandos Públicos (RegConsoleCmd permite acceso a todos)
	RegConsoleCmd("sm_3rdoff", CmdTP_Off, "Apaga la tercera persona.");
	RegConsoleCmd("sm_3rdon", CmdTP_On, "Enciende la tercera persona.");
	RegConsoleCmd("sm_3rd", CmdThird, "Alterna la tercera persona (!3rd).");
	RegConsoleCmd("sm_tp", CmdThird, "Alterna la tercera persona (!tp).");
	RegConsoleCmd("sm_third", CmdThird, "Alterna la tercera persona (!third).");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);

	// Desbloquear comandos nativos para todos los clientes (Quita el sv_cheats)
	int flags = GetCommandFlags("thirdpersonshoulder");
	SetCommandFlags("thirdpersonshoulder", flags & ~FCVAR_CHEAT);

	flags = GetCommandFlags("firstperson");
	SetCommandFlags("firstperson", flags & ~FCVAR_CHEAT);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			g_bThirdView[i] = false;
			if( IsPlayerAlive(i) )
			{
				ClientCommand(i, "firstperson");
			}
		}
	}
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}

		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("charger_impact", Event_ChargerImpact);
	}
	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;

		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("charger_impact", Event_ChargerImpact);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) )
				RemoveEdict(entity);
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bThirdView[client] = false;

	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_bThirdView[i] = false;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client )
	{
		if( g_bThirdView[client] )
		{
			ClientCommand(client, "thirdpersonshoulder");
		}
	}
}

public void OnClientDisconnect(int client)
{
	delete g_hTimerReset[client];
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( g_bThirdView[victim] && damagetype == DMG_CLUB && victim > 0 && victim <= MaxClients && attacker > 0 && attacker <= MaxClients && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 3 )
	{
		delete g_hTimerReset[victim];
		g_hTimerReset[victim] = CreateTimer(1.0, TimerReset, GetClientUserId(victim), TIMER_REPEAT);
		ClientCommand(victim, "thirdpersonshoulder");
	}

	return Plugin_Continue;
}

Action TimerReset(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && g_bThirdView[client] )
	{
		ClientCommand(client, "thirdpersonshoulder");
	}

	g_hTimerReset[client] = null;
	return Plugin_Stop;
}

// ====================================================================================================
//					COMMANDS (PUBLIC)
// ====================================================================================================

Action CmdTP_Off(int client, int args)
{
	if( g_bCvarAllow && client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		g_bThirdView[client] = false;
		ClientCommand(client, "firstperson");
		PrintToChat(client, "%s%t", CHAT_TAG, "Off");
	}

	return Plugin_Handled;
}

Action CmdTP_On(int client, int args)
{
	if( g_bCvarAllow && client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		g_bThirdView[client] = true;
		ClientCommand(client, "thirdpersonshoulder");
		PrintToChat(client, "%s%t", CHAT_TAG, "On");
	}

	return Plugin_Handled;
}

Action CmdThird(int client, int args)
{
	if( g_bCvarAllow && client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		if( g_bThirdView[client] == false )
		{
			g_bThirdView[client] = true;
			ClientCommand(client, "thirdpersonshoulder");
			PrintToChat(client, "%s%t", CHAT_TAG, "On");
		}
		else
		{
			g_bThirdView[client] = false;
			ClientCommand(client, "firstperson");
			PrintToChat(client, "%s%t", CHAT_TAG, "Off");
		}
	}

	return Plugin_Handled;
}