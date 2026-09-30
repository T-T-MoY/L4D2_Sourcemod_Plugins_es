//l4d2_tank_tp.sp
/**
 * ============================================================================
 * [Tank-Ability] Herd Call TP - MÓDULO MODULAR v4.1.0
 * ============================================================================
 * Lógica 100% del OLD (FindSafeTeleportSpot, TeleportOtherTanks, CountAliveTanks).
 * Cambios mínimos para funcionar como módulo:
 *   - Entry point: forward L4D2_OnTankAbilityElse
 *     (solo se dispatcha cuando las rocas NO se activaron ese throw, reproduciendo el "else" del OLD)
 *   - CloseHandle -> delete
 */

#include <sourcemod>
#include <sdktools>
#include <sdktools_trace>
#include <tank_abilities>

#define PLUGIN_VERSION "4.1.0"

public Plugin myinfo = {
    name = "[Tank-Ability] Herd Call TP",
    author = "[T-T]MoY",
    description = "Teletransporta otros Tanks cuando el Tank lanza roca (sin activar rocas extra).",
    version = PLUGIN_VERSION,
    url = ""
}

// --- ConVar ---
ConVar g_cvTPChance;
float  g_fTPChance = 10.0;

public void OnPluginStart() {
    g_cvTPChance = CreateConVar("l4d_tank_herdcall_chance", "10.0", "Probabilidad Herd Call [0.0, 100.0]", FCVAR_NONE, true, 0.0, true, 100.0);
    
    AutoExecConfig(true, "l4d2_tank_tp");
    g_fTPChance = g_cvTPChance.FloatValue;
    g_cvTPChance.AddChangeHook(OnCVarChange);
}

public void OnCVarChange(ConVar cv, const char[] old, const char[] new_) 
{ 
    g_fTPChance = g_cvTPChance.FloatValue; 
}

// ==========================================================================
// FORWARD "ELSE" - Solo se dispara cuando las rocas NO se activaron
// Esto reproduce exactamente el "else if" del OLD
// ==========================================================================
public void L4D2_OnTankAbilityElse(int client, const char[] ability)
{
    if (!StrEqual(ability, "ability_throw", true)) return;

    // Mismo random check del OLD
    float random_herdcall = GetRandomFloat(0.0, 100.0);
    if (random_herdcall >= g_fTPChance) return;

    // Solo ejecutar si hay al menos 2 tanks vivos (exacto del OLD)
    if (CountAliveTanks() >= 2) 
        TeleportOtherTanks(client);
}

// ==========================================================================
// UTILIDADES - Exactas del OLD
// ==========================================================================
int CountAliveTanks()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) 
            count++;
    return count;
}

void TeleportOtherTanks(int client)
{
    PrintToChatAll("\x04[Tank] \x03¡GRITO! \x05¡Llamando a la MANADA!");
    float targetPos[3];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client) continue;
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
        {
            if (FindSafeTeleportSpot(client, targetPos))
            {
                TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR);
                PrintToChat(i, "\x04[Tank] \x05¡La manada te llama!");
            }
        }
    }
}

// Exacto del OLD: trace desde Z+200 hacia abajo hasta Z-400 para buscar piso sólido.
// Si el trace impacta, usa esa posición + 1 unit (evita quedarse dentro del piso).
bool FindSafeTeleportSpot(int client, float targetPos[3])
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);

    float angle  = GetRandomFloat(0.0, 360.0);
    float radius = GetRandomFloat(200.0, 400.0);

    float spawnPos[3];
    spawnPos[0] = tankPos[0] + (Cosine(DegToRad(angle)) * radius);
    spawnPos[1] = tankPos[1] + (Sine(DegToRad(angle)) * radius);
    spawnPos[2] = tankPos[2]; 

    // Trace desde arriba hacia abajo buscando piso (exacto del OLD)
    float traceStart[3], traceEnd[3];
    traceStart[0] = spawnPos[0]; traceStart[1] = spawnPos[1]; traceStart[2] = spawnPos[2] + 200.0;
    traceEnd[0]   = spawnPos[0]; traceEnd[1]   = spawnPos[1]; traceEnd[2]   = spawnPos[2] - 400.0;

    Handle trace = TR_TraceHullFilterEx(traceStart, traceEnd, {-32.0, -32.0, 0.0}, {32.0, 32.0, 100.0}, MASK_PLAYERSOLID, TraceFilter_IgnoreTank, client);
    bool foundSpot = false;
    if (TR_DidHit(trace)) 
    { 
        TR_GetEndPosition(targetPos, trace); 
        targetPos[2] += 1.0;  // +1 unit para que no quede dentro del piso
        foundSpot = true; 
    }
    delete trace; 
    return foundSpot;
}

// ==========================================================================
// TRACE FILTERS
// ==========================================================================
// Ignora al tank que originó el comando, permite todo lo demás (mundo, otros objetos)
public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data) { return (entity != data); }

stock bool IsValidClient(int client) { return (client > 0 && client <= MaxClients && IsClientInGame(client)); }
