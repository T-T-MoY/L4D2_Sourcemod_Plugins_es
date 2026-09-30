#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1.0"
#define TEAM_INFECTED 3
#define ZOMBIE_CLASS_TANK 8
#define PI 3.141592653
#define MAX_VELOCITY_HOR 240.0

ConVar g_cvEnabled;
Handle g_hBhopTimer = null;

// --- NUEVA VARIABLE GLOBAL: Persistente entre capítulos ---
bool g_bEnabled = true;

public Plugin myinfo = 
{
    name = "[L4D2] Tank Auto Bhop",
    author = "[T-T]Moy",
    description = "Tank AI hace bunny hop automático en modos cooperativo.",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart()
{
    // --- ConVar con FCVAR_NONE para persistencia global ---
    g_cvEnabled = CreateConVar("sm_tankbhop_enable", "1", "Habilitar/Deshabilitar Tank Auto Bhop para IA (0=Off, 1=On) - Persiste entre capítulos", FCVAR_NONE, true, 0.0, true, 1.0);
    
    // Comando admin para toggle rápido
    RegAdminCmd("sm_tankbhop", Command_ToggleTankBhop, ADMFLAG_GENERIC, "Toggle Tank Bhop On/Off");
    
    // Hook eventos
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
    
    // Hook ConVar
    g_cvEnabled.AddChangeHook(OnConVarChanged);
    
    // --- Cargar valor inicial ---
    LoadConVarValue();
    
    // AutoExecConfig crea el archivo .cfg automáticamente
    AutoExecConfig(true, "tank_bhop");
    
    PrintToServer("[Tank Bhop AI] Plugin loaded! (Persistent Config)");
}

// --- NUEVA FUNCIÓN: Cargar valor de ConVar a variable global ---
void LoadConVarValue()
{
    g_bEnabled = g_cvEnabled.BoolValue;
}

// --- MODIFICADO: Hook que actualiza variable global ---
public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LoadConVarValue();
    
    if (!g_bEnabled && g_hBhopTimer != null)
    {
        KillTimer(g_hBhopTimer);
        g_hBhopTimer = null;
    }
    
    PrintToServer("[Tank Bhop AI] Configuración actualizada - Persistente entre capítulos");
}

// --- MODIFICADO: Toggle usando variable global ---
public Action Command_ToggleTankBhop(int client, int args)
{
    if (args >= 1)
    {
        char arg[8];
        GetCmdArg(1, arg, sizeof(arg));
        int value = StringToInt(arg);

        if (value == 0 || value == 1)
        {
            g_bEnabled = (value == 1);
            g_cvEnabled.SetBool(g_bEnabled);
            ReplyToCommand(client, "[Tank Bhop] %s", g_bEnabled ? "Activado" : "Desactivado");
            return Plugin_Handled;
        }
    }

    // Sin argumentos: Toggle
    g_bEnabled = !g_bEnabled;
    g_cvEnabled.SetBool(g_bEnabled);
    
    if (g_bEnabled)
        ReplyToCommand(client, "[Tank Bhop] Activado");
    else
        ReplyToCommand(client, "[Tank Bhop] Desactivado");
    
    return Plugin_Handled;
}

public void OnMapStart()
{
    // NO resetear g_bEnabled aquí - mantener configuración
    if (g_hBhopTimer != null)
    {
        KillTimer(g_hBhopTimer);
        g_hBhopTimer = null;
    }
}

// --- NUEVO EVENTO: Mantener configuración en transiciones de mapa ---
public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[Tank Bhop AI] Transición de mapa detectada - Manteniendo configuración");
    return Plugin_Continue;
}

// --- NUEVO EVENTO: NO resetear valores en round_start ---
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Solo limpiar el timer si existe, NO resetear g_bEnabled
    // La configuración se mantiene entre rondas y capítulos
    return Plugin_Continue;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    // --- Usar variable global ---
    if (!g_bEnabled)
        return;
    
    int tank = GetClientOfUserId(event.GetInt("userid"));
    
    if (tank > 0 && IsClientInGame(tank) && IsFakeClient(tank))
    {
        // Solo iniciar timer si el Tank es IA (bot)
        if (g_hBhopTimer == null)
        {
            g_hBhopTimer = CreateTimer(0.06, Timer_TankBhop, _, TIMER_REPEAT);
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (victim > 0 && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED)
    {
        if (GetEntProp(victim, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_TANK)
        {
            // Verificar si quedan Tanks IA vivos
            if (!IsAnyAITankAlive())
            {
                if (g_hBhopTimer != null)
                {
                    KillTimer(g_hBhopTimer);
                    g_hBhopTimer = null;
                }
            }
        }
    }
}

public Action Timer_TankBhop(Handle timer)
{
    // --- Usar variable global ---
    if (!g_bEnabled)
    {
        g_hBhopTimer = null;
        return Plugin_Stop;
    }
    
    bool foundAITank = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        
        // Solo procesar si es IA (bot)
        if (!IsFakeClient(i))
            continue;
        
        if (GetClientTeam(i) != TEAM_INFECTED)
            continue;
        
        if (GetEntProp(i, Prop_Send, "m_zombieClass") != ZOMBIE_CLASS_TANK)
            continue;
        
        foundAITank = true;
        ProcessTankBhop(i);
    }
    
    if (!foundAITank)
    {
        g_hBhopTimer = null;
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

void ProcessTankBhop(int tank)
{
    int flags = GetEntityFlags(tank);
    int buttons = GetClientButtons(tank);
    
    // Si está en el suelo y presionando avanzar
    if ((flags & FL_ONGROUND) && (buttons & IN_FORWARD))
    {
        // Calcular velocidad de bhop
        float upSpeed = (flags & FL_DUCKING) ? 297.0 : 247.0;
        
        // Obtener ángulos del Tank
        float angles[3];
        GetClientEyeAngles(tank, angles);
        
        // Calcular dirección horizontal
        float radians = angles[1] * PI / 180.0;
        float vx = MAX_VELOCITY_HOR * Cosine(radians);
        float vy = MAX_VELOCITY_HOR * Sine(radians);
        
        // Aplicar base velocity para el bhop
        float baseVel[3];
        baseVel[0] = vx;
        baseVel[1] = vy;
        baseVel[2] = upSpeed;
        
        SetEntPropVector(tank, Prop_Data, "m_vecBaseVelocity", baseVel);
    }
    
    // Auto avanzar hacia supervivientes (para IA)
    int closest = GetClosestSurvivor(tank);
    if (closest != -1)
    {
        float tankPos[3], survivorPos[3];
        GetClientAbsOrigin(tank, tankPos);
        GetClientAbsOrigin(closest, survivorPos);
        
        float distance = GetVectorDistance(tankPos, survivorPos);
        bool hasVision = HasVisibleThreats(tank);
        
        // Si tiene visión y está lejos, forzar avanzar
        if (hasVision && distance > 180.0)
        {
            if (flags & FL_ONGROUND)
            {
                int forceButtons = GetEntProp(tank, Prop_Data, "m_afButtonForced");
                SetEntProp(tank, Prop_Data, "m_afButtonForced", forceButtons | IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT);
            }
        }
        else
        {
            int forceButtons = GetEntProp(tank, Prop_Data, "m_afButtonForced");
            SetEntProp(tank, Prop_Data, "m_afButtonForced", forceButtons & ~(IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT));
        }
    }
}

bool IsAnyAITankAlive()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        
        if (!IsFakeClient(i))
            continue;
        
        if (GetClientTeam(i) == TEAM_INFECTED && GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_TANK)
            return true;
    }
    return false;
}

int GetClosestSurvivor(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    int closest = -1;
    float closestDist = -1.0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
            
        if (GetClientTeam(i) != 2) // Team Survivor
            continue;
        
        float survivorPos[3];
        GetClientAbsOrigin(i, survivorPos);
        
        float dist = GetVectorDistance(tankPos, survivorPos);
        
        if (closest == -1 || dist < closestDist)
        {
            closest = i;
            closestDist = dist;
        }
    }
    
    return closest;
}

bool HasVisibleThreats(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
}