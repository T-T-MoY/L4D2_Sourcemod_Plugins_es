#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "[TankRun] Full No Black and White",
    description = "Elimina completamente el efecto de blanco y negro en TankRun",
    author = "[T-T]MoY",
    version = "1.7",
    url = ""
};

// Sin verificación de tankrun — aplica siempre
// Si solo quieres en tankrun, descomenta las líneas marcadas con [TANKRUN]

public void OnPluginStart()
{
    HookEvent("round_start",       Event_RoundStart,    EventHookMode_PostNoCopy);
    HookEvent("map_transition",    Event_MapTransition, EventHookMode_PostNoCopy);
    HookEvent("player_spawn",      Event_PlayerSpawn,   EventHookMode_Post);
    HookEvent("player_death",      Event_PlayerDeath,   EventHookMode_PostNoCopy);
    HookEvent("player_first_spawn",Event_PlayerSpawn,   EventHookMode_Post);
    HookEvent("player_bot_replace",Event_BotReplace,    EventHookMode_Post);
    
    AddCommandListener(Cmd_Say, "say");
    AddCommandListener(Cmd_Say, "say_team");
    
    // Timer agresivo: cada 2 segundos revisa a todos
    CreateTimer(2.0, Timer_PeriodicCheck, _, TIMER_REPEAT);
}

// ── Eventos ──────────────────────────────────────────────

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Múltiples timers escalonados para cubrir el momento de carga
    CreateTimer(1.0,  Timer_CleanAllBW);
    CreateTimer(3.0,  Timer_CleanAllBW);
    CreateTimer(5.0,  Timer_CleanAllBW);
    CreateTimer(10.0, Timer_CleanAllBW);
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    // Limpiar ANTES de que el juego guarde el estado al siguiente mapa
    CleanBlackAndWhiteForAll();
    
    // Y también timers para cuando cargue el siguiente mapa
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
    // Cuando un bot reemplaza a un jugador o viceversa
    int client = GetClientOfUserId(event.GetInt("player"));
    if (IsValidSurvivor(client))
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
        
    client = GetClientOfUserId(event.GetInt("bot"));
    if (IsValidSurvivor(client))
        CreateTimer(0.5, Timer_CheckSinglePlayer, GetClientUserId(client));
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
    
    // Quitar tercera huelga (causa el B&W)
    if (GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
    {
        SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
    }
    
    // Quitar el buffer de salud temporal (el "incap buffer" que genera B&W)
    float hpBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    if (hpBuffer > 0.0)
    {
        SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
    }
    
    // Resetear salud para que el juego actualice visualmente
    int health = GetClientHealth(client);
    SetEntityHealth(client, (health > 0) ? health : 1);
    
    // Forzar limpieza del HUD hint que a veces queda
    PrintHintText(client, " ");
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