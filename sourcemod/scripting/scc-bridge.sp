//************************************************************************
// Simple Chat Colors Bridge for Chat-Processor
// Converts old SCC config format to work with Chat-Processor
// Compatible with SourceMod 1.12 and L4D2
//************************************************************************

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <chat-processor>

#define PLUGIN_VERSION "1.0.0"

// Player data storage
StringMap g_PlayerData[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Simple Chat Colors Bridge",
	author = "Converted for SM 1.12",
	description = "Reads old SCC configs and applies them via Chat-Processor",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("scc_bridge_version", PLUGIN_VERSION, "SCC Bridge Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_reloadscc", Command_Reload, ADMFLAG_CONFIG, "Reloads Simple Chat Colors config");
	RegAdminCmd("sm_printcolors", Command_PrintColors, ADMFLAG_GENERIC, "Prints available color codes");
	
	// Initialize all player data
	for (int i = 1; i <= MaxClients; i++)
	{
		g_PlayerData[i] = null;
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		LoadPlayerSettings(client);
	}
}

public void OnClientDisconnect(int client)
{
	if (g_PlayerData[client] != null)
	{
		delete g_PlayerData[client];
		g_PlayerData[client] = null;
	}
}

public Action Command_Reload(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			LoadPlayerSettings(i);
		}
	}
	
	ReplyToCommand(client, "[SCC] Config reloaded successfully");
	LogAction(client, -1, "[SCC] Config file has been reloaded");
	return Plugin_Handled;
}

public Action Command_PrintColors(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "This command must be used in-game");
		return Plugin_Handled;
	}
	
	PrintToChat(client, "\x01{N} - Default/White");
	PrintToChat(client, "\x04{G} - Green");
	PrintToChat(client, "\x05{L} - Light Green");
	PrintToChat(client, "\x03{T} - Team Color");
	PrintToChat(client, "\x07{R} - Red");
	PrintToChat(client, "\x0B{B} - Blue");
	PrintToChat(client, "\x10{OG} - Olive");
	
	return Plugin_Handled;
}

void LoadPlayerSettings(int client)
{
	// Clean up old data
	if (g_PlayerData[client] != null)
	{
		delete g_PlayerData[client];
	}
	
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/simple-chatcolors.cfg");
	
	if (!FileExists(sConfigPath))
	{
		LogError("[SCC] Config file not found: %s", sConfigPath);
		return;
	}
	
	KeyValues kv = new KeyValues("admin_colors");
	
	if (!kv.ImportFromFile(sConfigPath))
	{
		LogError("[SCC] Failed to parse config file");
		delete kv;
		return;
	}
	
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	
	bool bFound = false;
	
	do
	{
		char sSectionName[64];
		kv.GetSectionName(sSectionName, sizeof(sSectionName));
		
		// Check if this is a SteamID section
		if (StrContains(sSectionName, "STEAM_", false) != -1)
		{
			if (StrEqual(sSectionName, sSteamID, false))
			{
				ApplyPlayerSettings(client, kv);
				bFound = true;
				break;
			}
		}
		else
		{
			// Check if player has required flags
			char sFlags[32];
			kv.GetString("flag", sFlags, sizeof(sFlags));
			
			if (strlen(sFlags) > 0)
			{
				int iFlags = ReadFlagString(sFlags);
				if (iFlags != 0 && CheckCommandAccess(client, "scc_colors", iFlags, true))
				{
					ApplyPlayerSettings(client, kv);
					bFound = true;
					break;
				}
			}
		}
	}
	while (kv.GotoNextKey());
	
	delete kv;
	
	if (!bFound)
	{
		// Reset to default if no match found
		ChatProcessor_SetNameColor(client, "");
		ChatProcessor_SetChatColor(client, "");
		ChatProcessor_StripClientTags(client);
	}
}

void ApplyPlayerSettings(int client, KeyValues kv)
{
	char sTag[64], sTagColor[32], sNameColor[32], sTextColor[32];
	
	kv.GetString("tag", sTag, sizeof(sTag));
	kv.GetString("tagcolor", sTagColor, sizeof(sTagColor));
	kv.GetString("namecolor", sNameColor, sizeof(sNameColor));
	kv.GetString("textcolor", sTextColor, sizeof(sTextColor));
	
	// Strip old tags first
	ChatProcessor_StripClientTags(client);
	
	// Apply tag if exists
	if (strlen(sTag) > 0)
	{
		char sFullTag[96];
		
		if (strlen(sTagColor) > 0)
		{
			FormatEx(sFullTag, sizeof(sFullTag), "%s%s", sTagColor, sTag);
		}
		else
		{
			strcopy(sFullTag, sizeof(sFullTag), sTag);
		}
		
		ChatProcessor_AddClientTag(client, sFullTag);
	}
	
	// Apply name color
	if (strlen(sNameColor) > 0)
	{
		ChatProcessor_SetNameColor(client, sNameColor);
	}
	
	// Apply text/chat color
	if (strlen(sTextColor) > 0)
	{
		ChatProcessor_SetChatColor(client, sTextColor);
	}
}