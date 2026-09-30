#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define ZOMBIECLASS_TANK 8
#define EXPERT_TANK_HP 8000

public Plugin myinfo =
{
    name = "L4D2 Tank: HP Expert + Aggressive AI",
    author = "Gemini",
    description = "Tank con 8000 HP y comportamiento agresivo (IA), sin mensajes.",
    version = "1.4",
    url = ""
};

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    ForceAggressiveCVars();
}

public void OnMapStart()
{
    ForceAggressiveCVars();
}

void ForceAggressiveCVars()
{
    ConVar cv;
    
    // Puntería perfecta
    cv = FindConVar("tank_throw_aim_error");
    if (cv != null) cv.SetFloat(0.0);

    // Resistencia al fuego (75s)
    cv = FindConVar("tank_burn_duration");
    if (cv != null) cv.SetInt(75);

    // Intervalo de ataque reducido
    cv = FindConVar("z_tank_attack_interval");
    if (cv != null) cv.SetFloat(0.5);
    
    // Mejor visibilidad para detectar supervivientes
    cv = FindConVar("tank_stuck_visibility_tolerance");
    if (cv != null) cv.SetFloat(0.0);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(client)) return;
    
    if (GetClientTeam(client) == 3) // Equipo infectado
    {
        int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if (zombieClass == ZOMBIECLASS_TANK)
        {
            CreateTimer(0.1, Timer_SetTankHP, client);
            ForceAggressiveCVars(); 
        }
    }
}

public Action Timer_SetTankHP(Handle timer, int client)
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        SetEntProp(client, Prop_Data, "m_iMaxHealth", EXPERT_TANK_HP);
        SetEntProp(client, Prop_Send, "m_iHealth", EXPERT_TANK_HP);
    }
    return Plugin_Stop;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}