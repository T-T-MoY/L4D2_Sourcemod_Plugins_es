#include <sourcemod>
#include <sdktools>

#define ORIGINAL_MAPS "addons/sourcemod/data/l4d1maps.txt"	// File with L4D1 mapnames

new Handle:Arr_Original_Maps = INVALID_HANDLE;			// Handle with arrays L4D1 mapnames
new Handle:cvarGameMode = INVALID_HANDLE;			// Handle with mp_gamemode cvar
new Handle:cvarDisableGlowSurvivors = INVALID_HANDLE;		// Handle with sv_disable_glow_survivors cvar
new Handle:cvarDisableGlowFaritems = INVALID_HANDLE;		// Handle with sv_disable_glow_faritems cvar
new Handle:cvarConsistency = INVALID_HANDLE;			// Handle with sv_consistency cvar
new Handle:cvarEnablePlugin = INVALID_HANDLE;			// Handle with sm_handfix_enable cvar
new Handle:cvarEnableVersus = INVALID_HANDLE;			// Handle with sm_handfix_versus cvar

static bool Restore[MAXPLAYERS + 1]  = false;

public Plugin:myinfo = 
{
	name = "L4D 2 Hands and icons in l4d1 campaigns fixer",
	author = "Magical",
	description = "L4D 2 Hands and icons in l4d1 campaigns fixer",
	version = "1.2",
	url = ""
}


public OnPluginStart()
{
	cvarGameMode = FindConVar("mp_gamemode");
	cvarDisableGlowSurvivors = FindConVar("sv_disable_glow_survivors");
	cvarDisableGlowFaritems = FindConVar("sv_disable_glow_faritems");
	cvarConsistency = FindConVar("sv_consistency");
	cvarEnablePlugin = CreateConVar("sm_handfix_enable", "1", "Hands fix: 0 - Disabled, 1 - Enabled (only from l4d1maps.txt maps), 2 - Enabled (every maps).", FCVAR_SPONLY,true,0.00,true,2.00);
	cvarEnableVersus = CreateConVar("sm_handfix_versus", "0", "Hands fix in versus: 0 - Disabled, 1 - Enabled.", FCVAR_SPONLY,true,0.00,true,1.00);
	HookEvent("player_spawn", HookPlayerSpawn);
	if(FileExists(ORIGINAL_MAPS))
		LoadL4D1Maps();
}

// When player joined, doing these
public OnClientPutInServer(client)
{
	if (GetConVarInt(cvarEnablePlugin) >= 1)	// If plugin is enabled
	{
		if((!IsVersusMode()) || (GetConVarInt(cvarEnableVersus)))				// If is NOT versus mode or cvarEnableVersus is enabled
		{
			if (!IsFakeClient(client))			// If client isn't bot
			{
				new String:map[30];
				GetCurrentMap(map, sizeof(map));
				if (((Arr_Original_Maps != INVALID_HANDLE) && (FindStringInArray(Arr_Original_Maps, map) != -1)) || (GetConVarInt(cvarEnablePlugin) == 2))
				{
					if (strcmp(map, "c2m2_fairgrounds", false) == 0)
						SendConVarValue(client, cvarGameMode, "dash");			// Send mp_gamemode cvar value to player to dash
					else
						SendConVarValue(client, cvarGameMode, "shootzones");	// Send mp_gamemode cvar value to player to shootzones

					// When user's game mode is changed, its sv_consistency cvar value becomes 1 and we need to send this to 0 if server's consistency is disabled.
					// In some custom campaigns without this when server's sv_consistency value is 0, but user's is 1, it may kick player.

					if (GetConVarInt(cvarConsistency) == 0)
						SendConVarValue(client, cvarConsistency, "0");
					else
						SendConVarValue(client, cvarConsistency, "1");

					// If server game mode is realism, without this user can see teammates through walls while we sent shootzones game mode value and we need send these two cvars.

					if (GetConVarInt(cvarDisableGlowSurvivors) == 1)
					{
						SendConVarValue(client, cvarDisableGlowSurvivors, "1");
						SendConVarValue(client, cvarDisableGlowFaritems, "1");
					}

					Restore[client] = true;
				}
			}
		}
	}
}

// When player spawned, start timer for restore actual game mode value to player.
public HookPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iUserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(iUserId);

	if (!IsFakeClient(client))
	{
		if (Restore[client])
		{
			CreateTimer(5.0, RestoreGameMode, client);
			Restore[client] = false;
		}
	}
}

// Restoring user's game mode cvar value to actual.
public Action:RestoreGameMode(Handle:timer, any:value)
{
	if (IsValidClient(value))
	{
		decl String:GameMode[30]
		GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode))				

		//PrintToServer("Connected for testing restored player");		
		SendConVarValue(value, cvarGameMode, GameMode);

		if (GetConVarInt(cvarConsistency) == 0)
			SendConVarValue(value, cvarConsistency, "0");
		else
			SendConVarValue(value, cvarConsistency, "1");
	}
}

// Versus game modes
char versus_modes[22][] =
{
	"versus",	"mutation12",	"mutation11",	"mutation15",
	"mutation18",	"mutation19",	"community3",	"community6",
	"l4d1vs",	"teamversus",	"teammutation12",	"teammutation11",
	"teammutation15",	"teammutation18",	"teammutation19",	"teamcommunity3",
	"teamcommunity6",	"teaml4d1vs",	"scavenge",	"mutation13",
	"teamscavenge",		"teammutation13"
};

// Checking when game mode is Versus
bool IsVersusMode()
{	
	char gameMode[16];
	FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
	
	for (int i = 0; i < sizeof(versus_modes); i++)
	{
		if (StrEqual(gameMode, versus_modes[i], false))
		{
			return true;
		}
	}
	return false;
}

LoadL4D1Maps()
{
	new Handle:fOriginalList = OpenFile(ORIGINAL_MAPS, "rt");

	if (fOriginalList == INVALID_HANDLE)
	{
		SetFailState("Unable to load file: %s", ORIGINAL_MAPS);
	}

	Arr_Original_Maps = CreateArray(256);

	new String:auth[256];

	while (!IsEndOfFile(fOriginalList) && ReadFileLine(fOriginalList, auth, sizeof(auth)))
	{
		ReplaceString(auth, sizeof(auth), "\r", "");
		ReplaceString(auth, sizeof(auth), "\n", "");
		// Maybe use TrimString instead of the two ReplaceStrings here?
	
		PushArrayString(Arr_Original_Maps, auth);
	}
	
	CloseHandle(fOriginalList);
}

public IsValidClient(client)
{
	if (client == 0)
		return false;

	if (!IsClientConnected(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	//if (!IsPlayerAlive(client))
		//return false;

	if (!IsValidEntity(client))
		return false;

	return true;
}
