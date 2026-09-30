#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "[TankRun] Full No Black and White",
    description = "Elimina completamente el efecto de blanco y negro en TankRun",
    author = "[T-T]MoY",
    version = "1.8",
    url = ""
};

public void OnPluginStart()
{
    HookEvent("round_start",        Event_RoundStart,    EventHookMode_PostNoCopy);
    HookEvent("map_transition",     Event_MapTransition, EventHookMode_PostNoCopy);
    HookEvent("player_spawn",       Event_PlayerSpawn,   EventHookMode_Post);
    HookEvent("player_death",       Event_PlayerDeath,   EventHookMode_PostNoCopy);
    HookEvent("player_first_spawn", Event_PlayerSpawn,   EventHookMode_Post);
    HookEvent("player_bot_replace", Event_BotReplace,    EventHookMode_Post);
    HookEvent("player_use",         Event_PlayerUse,     EventHookMode_Post);
    
    AddCommandListener(Cmd_Say, "say");
    AddCommandListener(Cmd_Say, "say_team");
    
    CreateTimer(2.0, Timer_PeriodicCheck, _, TIMER_REPEAT);
}

// ── Eventos ──────────────────────────────────────────────

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.0,  Timer_CleanAllBW);
    CreateTimer(3.0,  Timer_CleanAllBW);
    CreateTimer(5.0,  Timer_CleanAllBW);
    CreateTimer(10.0, Timer_CleanAllBW);
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    CleanBlackAndWhiteForAll();
    
    CreateTimer(1.0,  Timer_CleanAllBW);
    CreateTimer(3.0,  Timer_CleanAllBW);
    CreateTimer(5.0,  Timer_CleanAllBW);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.0, Timer_CleanAllBW);
    CreateTimer(3.0, Timer_CleanAllBW);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(client))
    {
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
        CreateTimer(1.0, Timer_CheckSinglePlayer, GetClientUserId(client));
        CreateTimer(2.0, Timer_CheckSinglePlayer, GetClientUserId(client));
    }
}

public void Event_BotReplace(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("player"));
    if (IsValidSurvivor(client))
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
        
    client = GetClientOfUserId(event.GetInt("bot"));
    if (IsValidSurvivor(client))
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
}

public void Event_PlayerUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(client))
    {
        // Delay porque el engine aplica efectos después del uso
        CreateTimer(0.2, Timer_CheckSinglePlayer, GetClientUserId(client));
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
        CreateTimer(1.0, Timer_CheckSinglePlayer, GetClientUserId(client));
    }
}

public Action Cmd_Say(int client, const char[] command, int argc)
{
    if (IsValidSurvivor(client))
        CreateTimer(0.1, Timer_CheckSinglePlayer, GetClientUserId(client));
    return Plugin_Continue;
}

// ── Timers ───────────────────────────────────────────────

public Action Timer_PeriodicCheck(Handle timer)
{
    CleanBlackAndWhiteForAll();
    return Plugin_Continue;
}

public Action Timer_CleanAllBW(Handle timer)
{
    CleanBlackAndWhiteForAll();
    return Plugin_Handled;
}

public Action Timer_CheckSinglePlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidSurvivor(client))
        RemoveBlackAndWhite(client);
    return Plugin_Handled;
}

// ── Lógica principal ─────────────────────────────────────

void CleanBlackAndWhiteForAll()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidSurvivor(i))
            RemoveBlackAndWhite(i);
    }
}

void RemoveBlackAndWhite(int client)
{
    if (!IsPlayerAlive(client)) return;
    
    // Solo limpiar third strike — causa real del B&W en TankRun
    if (GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
    {
        SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
    }
    
    // Forzar update visual del HUD
    int health = GetClientHealth(client);
    SetEntityHealth(client, (health > 0) ? health : 1);
    
    //PrintHintText(client, " ");
    
    // NOTA: m_healthBuffer NO se toca — es el HP temporal de pills/adre
}

bool IsValidSurvivor(int client)
{
    return (client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && !IsFakeClient(client)
        && GetClientTeam(client) == 2
        && IsPlayerAlive(client));
}