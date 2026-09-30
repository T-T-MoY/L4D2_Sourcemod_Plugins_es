//l4d2_tank_multirock.sp
/**
 * ============================================================================
 * [Tank-Ability] Multi-Rock - MÓDULO MODULAR v4.1.0
 * ============================================================================
 * Lógica 100% del OLD (V3.4.0 AIM FIX).
 * Cambios mínimos para funcionar como módulo:
 *   - Entry point: forward L4D2_OnTankAbility (retorna Plugin_Handled si activa rocas)
 *   - FIX: 3 DataPacks corregidos (new + escribir antes del CreateDataTimer)
 *   - CloseHandle -> delete
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>
#include <tank_abilities>

#define PLUGIN_VERSION "4.1.0"

public Plugin myinfo = 
{
    name = "[Tank-Ability] Multi-Rock",
    author = "[T-T]MoY",
    description = "Lluvia de rocas con puntería dinámica.",
    version = PLUGIN_VERSION,
    url = ""
}

// --- ConVars ---
ConVar g_cvEnable;
ConVar g_cvChance;
ConVar g_cvDamage;
ConVar g_cvMinRocks;
ConVar g_cvMaxRocks;

// --- Cache de valores (evita .FloatValue cada llamada) ---
bool   g_bEnabled     = true;
float  g_fChance      = 25.0;
float  g_fDamage      = 20.0;
int    g_iMinRocks    = 1;
int    g_iMaxRocks    = 2;

// --- Estado por jugador ---
bool   g_bTankImmune[MAXPLAYERS + 1];
bool   g_bTankFrozen[MAXPLAYERS + 1];
bool   g_bTankRockImmune[MAXPLAYERS + 1]; 
Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];
Handle g_hGlowTimer[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_cvEnable   = CreateConVar("l4d_multi_rock_enable",        "1",    "0:deshabilitado, 1:habilitado",      FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvChance   = CreateConVar("l4d_multi_rock_chance_throw",  "25.0", "Probabilidad throw [0.0, 100.0]",    FCVAR_NONE, true, 0.0, true, 100.0);
    g_cvDamage   = CreateConVar("l4d_multi_rock_damage",        "20",   "Daño rocas [1.0, 100.0]",            FCVAR_NONE, true, 1.0, true, 100.0);
    g_cvMinRocks = CreateConVar("l4d_multi_rock_min",           "1",    "Mínimo rocas [1-20]",                FCVAR_NONE, true, 1.0, true, 20.0);
    g_cvMaxRocks = CreateConVar("l4d_multi_rock_max",           "2",    "Máximo rocas [1-20]",                FCVAR_NONE, true, 1.0, true, 20.0);

    AutoExecConfig(true, "l4d2_tank_multirock"); 
    LoadCVars();
    
    g_cvEnable.AddChangeHook(OnCVarChange);
    g_cvChance.AddChangeHook(OnCVarChange);
    g_cvDamage.AddChangeHook(OnCVarChange);
    g_cvMinRocks.AddChangeHook(OnCVarChange);
    g_cvMaxRocks.AddChangeHook(OnCVarChange);
    
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start",  Event_RoundStart);
}

void LoadCVars()
{
    g_bEnabled  = g_cvEnable.BoolValue;
    g_fChance   = g_cvChance.FloatValue;
    g_fDamage   = g_cvDamage.FloatValue;
    g_iMinRocks = g_cvMinRocks.IntValue;
    g_iMaxRocks = g_cvMaxRocks.IntValue;
}

public void OnCVarChange(ConVar cv, const char[] old, const char[] new_) { LoadCVars(); }

// ==========================================================================
// FORWARD PRINCIPAL - Entry point
// Retorna Plugin_Handled si las rocas se activaron (el core no dispatcha el Else)
// Retorna Plugin_Continue si no se activaron (el core dispatcha el Else -> TP tiene chance)
// ==========================================================================
public Action L4D2_OnTankAbility(int client, const char[] ability)
{
    if (!g_bEnabled) return Plugin_Continue;
    if (!StrEqual(ability, "ability_throw", true)) return Plugin_Continue;

    float random_rock = GetRandomFloat(0.0, 100.0);

    // Si NO se activan las rocas, retornar Continue para que el core dispatche el Else
    if (random_rock >= g_fChance) return Plugin_Continue;

    // --- Las rocas SE ACTIVAN ---
    int rockCount = GetRandomInt(g_iMinRocks, g_iMaxRocks);
    
    // Inmunidad
    g_bTankImmune[client] = true;
    SDKHook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage);
    
    // Efectos visuales (exactos del OLD)
    SetEntProp(client, Prop_Send, "m_iGlowType", 3);
    SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 10);
    SetEntProp(client, Prop_Send, "m_glowColorOverride", 25600);
    
    if (rockCount > 5)
    {
        g_bTankFrozen[client] = true;
        g_bTankRockImmune[client] = true;
        SetEntityMoveType(client, MOVETYPE_NONE);
        SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);
        PrintToChatAll("\x04[Tank] \x03¡ALERTA! \x05¡LLUVIA DE ROCAS! \x03¡CUBRANCE!");
        PrintCenterTextAll("⚠ ¡LLUVIA DE ROCAS! ⚠");
    }
    else
    {
        PrintToChatAll("\x04[Tank] \x05¡Ráfaga de rocas!");
    }
    
    // FIX DataPack #1: new -> escribir -> pasar al timer
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(rockCount);
    CreateDataTimer(0.5, Timer_MultiRock, pack, TIMER_FLAG_NO_MAPCHANGE);
    
    // Timers de cleanup (exactos del OLD)
    float freezeTime = rockCount > 5 ? (2.5 + ((rockCount - 5) * 0.3)) : 2.5;

    if (g_hGlowTimer[client] != null) KillTimer(g_hGlowTimer[client]);
    g_hGlowTimer[client] = CreateTimer(freezeTime + 0.5, Timer_RemoveGlow, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    
    if (g_hImmunityTimer[client] != null) KillTimer(g_hImmunityTimer[client]);
    g_hImmunityTimer[client] = CreateTimer(freezeTime, Timer_RemoveImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    
    if (rockCount > 5)
    {
        if (g_hFreezeTimer[client] != null) KillTimer(g_hFreezeTimer[client]);
        g_hFreezeTimer[client] = CreateTimer(freezeTime, Timer_UnfreezeTank, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        
        if (g_hRockImmuneTimer[client] != null) KillTimer(g_hRockImmuneTimer[client]);
        g_hRockImmuneTimer[client] = CreateTimer(freezeTime + 1.0, Timer_RemoveRockImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    // Retornar Handled: le dice al core que este evento fue consumido, no dispatchar el Else
    return Plugin_Handled;
}

// ==========================================================================
// GENERACIÓN DE ROCAS
// ==========================================================================
public Action Timer_MultiRock(Handle timer, DataPack pack)
{ 
    pack.Reset();
    int userid    = pack.ReadCell();
    int rockCount = pack.ReadCell();
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
    {
        float eyePos[3];
        GetClientEyePosition(client, eyePos);
        LaunchMultipleRocks(client, eyePos, rockCount);
    }
    return Plugin_Stop;
}

void LaunchMultipleRocks(int client, float eyePos[3], int rockCount)
{ 
    // Cache survivors una sola vez para todo el loop
    int survivors[MAXPLAYERS + 1];
    int survivorCount = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
            survivors[survivorCount++] = i;
    
    if (survivorCount == 0) return;
    
    // Cache del string de daño una sola vez
    char damageStr[32];
    IntToString(RoundToNearest(g_fDamage), damageStr, sizeof(damageStr));
    
    float tankAngles[3];
    GetClientEyeAngles(client, tankAngles);
    
    for (int rock = 0; rock < rockCount; rock++)
    {
        float delay = rock < 5 ? (0.1 * rock) : (0.5 + (0.15 * (rock - 5)));
        int ent = CreateEntityByName("env_rock_launcher");
        if (!IsValidEntity(ent)) continue;
        
        DispatchKeyValue(ent, "rockdamageoverride", damageStr);

        float launchPos[3];
        int targetEntity;
        int dummyRef = 0;

        // =====================================================================
        // TIPO A: Rocas normales (rock 0-4) - exacto del OLD
        // =====================================================================
        if (rock < 5)
        {
            DispatchSpawn(ent);
            
            int target = survivors[GetRandomInt(0, survivorCount - 1)];
            if (!IsValidClient(target) || !IsPlayerAlive(target)) { AcceptEntityInput(ent, "Kill"); continue; }
            targetEntity = target;

            float direction[3];
            GetDirectionalVector(rock, tankAngles, direction);
            launchPos[0] = eyePos[0] + (direction[0] * 300.0);
            launchPos[1] = eyePos[1] + (direction[1] * 300.0);
            launchPos[2] = eyePos[2] + (direction[2] * 300.0);
            TeleportEntity(ent, launchPos, NULL_VECTOR, NULL_VECTOR);
        }
        // =====================================================================
        // TIPO B: Lluvia INTELIGENTE con AIM FIX (rock 5+) - exacto del OLD
        // =====================================================================
        else
        {
            // 1. Elegir objetivo: 50% closest, 50% random (exacto del OLD)
            int targetSurvivor;
            if (GetRandomFloat(0.0, 100.0) < 50.0) 
                targetSurvivor = GetClosestSurvivor(client, survivors, survivorCount);
            else 
                targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            
            if (targetSurvivor == -1 || !IsValidClient(targetSurvivor)) 
                targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            if (!IsValidClient(targetSurvivor)) { AcceptEntityInput(ent, "Kill"); continue; }

            // 2. Posición del objetivo + dispersión progresiva (exacto del OLD)
            float survivorPos[3];
            GetClientAbsOrigin(targetSurvivor, survivorPos);
            
            float progressRatio = float(rock - 5) / float(rockCount - 5);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6)); 
            float radius = GetRandomFloat(20.0, maxRadius);
            float angle = GetRandomFloat(0.0, 360.0);
            
            float targetX = survivorPos[0] + (Cosine(DegToRad(angle)) * radius);
            float targetY = survivorPos[1] + (Sine(DegToRad(angle)) * radius);
            float targetZ = survivorPos[2];

            // 3. Calcular altura con detección de techos (exacto del OLD)
            float traceStart[3], traceEnd[3];
            traceStart[0] = targetX; traceStart[1] = targetY; traceStart[2] = targetZ + 10.0;
            traceEnd[0]   = targetX; traceEnd[1]   = targetY; traceEnd[2]   = targetZ + 1200.0;
            
            Handle trace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_WorldOnly);
            float spawnHeightZ;
            if (TR_DidHit(trace)) 
            { 
                float hitPos[3]; 
                TR_GetEndPosition(hitPos, trace); 
                spawnHeightZ = hitPos[2] - 80.0; 
            }
            else 
            { 
                float heightBonus = float(rock - 5) * 40.0; 
                spawnHeightZ = targetZ + 800.0 + heightBonus; 
            }
            delete trace;

            launchPos[0] = targetX;
            launchPos[1] = targetY;
            launchPos[2] = spawnHeightZ;
            
            // 4. Crear dummy target en el punto de impacto (exacto del OLD)
            int dummyTarget = CreateEntityByName("info_target");
            if (!IsValidEntity(dummyTarget)) { AcceptEntityInput(ent, "Kill"); continue; }
            float groundPos[3]; 
            groundPos[0] = targetX; groundPos[1] = targetY; groundPos[2] = targetZ;
            TeleportEntity(dummyTarget, groundPos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(dummyTarget);
            targetEntity = dummyTarget;
            dummyRef = EntIndexToEntRef(dummyTarget); 

            // 5. Calcular ángulo: vector origen->destino (AIM FIX del OLD)
            float vectorDir[3], aimAngles[3];
            SubtractVectors(groundPos, launchPos, vectorDir);
            GetVectorAngles(vectorDir, aimAngles);
            
            // 6. Spawn del lanzador YA ROTADO apuntando al objetivo
            DispatchSpawn(ent);
            TeleportEntity(ent, launchPos, aimAngles, NULL_VECTOR);
        }

        // Asignar target al lanzador
        SetVariantEntity(targetEntity);
        AcceptEntityInput(ent, "SetTarget");
        
        // FIX DataPack #2: new -> escribir -> pasar al timer
        DataPack rockPack = new DataPack();
        rockPack.WriteCell(EntIndexToEntRef(ent));
        if (rock < 5) { rockPack.WriteCell(GetClientUserId(targetEntity)); rockPack.WriteCell(0); }
        else          { rockPack.WriteCell(0);                              rockPack.WriteCell(dummyRef); }
        CreateDataTimer(delay, Timer_LaunchRock, rockPack, TIMER_FLAG_NO_MAPCHANGE);
    }
}

// ==========================================================================
// TIMER: Lanzar roca individual
// ==========================================================================
public Action Timer_LaunchRock(Handle timer, DataPack pack)
{
    pack.Reset();
    int entRef   = pack.ReadCell();
    int userid   = pack.ReadCell();
    int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef);

    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        if (userid != 0) {
            int target = GetClientOfUserId(userid);
            if (IsValidClient(target) && IsPlayerAlive(target)) { 
                SetVariantEntity(target); 
                AcceptEntityInput(ent, "SetTarget"); 
            }
        }
        AcceptEntityInput(ent, "LaunchRock");

        // FIX DataPack #3: new -> escribir -> pasar al timer
        DataPack removePack = new DataPack();
        removePack.WriteCell(entRef);
        removePack.WriteCell(dummyRef);
        CreateDataTimer(0.1, Timer_RemoveLauncher, removePack, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Stop;
}

// ==========================================================================
// TIMER: Eliminar entidades
// ==========================================================================
public Action Timer_RemoveLauncher(Handle timer, DataPack pack) 
{
    pack.Reset(); 
    int entRef   = pack.ReadCell(); 
    int dummyRef = pack.ReadCell(); 

    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) 
        AcceptEntityInput(ent, "Kill");

    if (dummyRef != 0) { 
        int dummy = EntRefToEntIndex(dummyRef); 
        if (dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy)) 
            AcceptEntityInput(dummy, "Kill"); 
    }
    return Plugin_Stop;
}

// ==========================================================================
// HELPERS
// ==========================================================================
int GetClosestSurvivor(int client, int[] survivors, int survivorCount)
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);
    int closest = -1;
    float minDist = 999999.0;
    for (int i = 0; i < survivorCount; i++)
    {
        int survivor = survivors[i];
        if (!IsValidClient(survivor) || !IsPlayerAlive(survivor)) continue;
        float survivorPos[3];
        GetClientAbsOrigin(survivor, survivorPos);
        float dist = GetVectorDistance(tankPos, survivorPos);
        if (dist < minDist) { minDist = dist; closest = survivor; }
    }
    return closest;
}

void GetDirectionalVector(int rockIndex, float tankAngles[3], float direction[3])
{
    float yaw = tankAngles[1]; 
    float pitch = tankAngles[0];
    switch (rockIndex) {
        case 0: { direction[0] = Cosine(DegToRad(yaw));        direction[1] = Sine(DegToRad(yaw));        direction[2] = -Sine(DegToRad(pitch)); }
        case 1: { direction[0] = Cosine(DegToRad(yaw + 90.0)); direction[1] = Sine(DegToRad(yaw + 90.0)); direction[2] = 0.0; }
        case 2: { direction[0] = Cosine(DegToRad(yaw - 90.0)); direction[1] = Sine(DegToRad(yaw - 90.0)); direction[2] = 0.0; }
        case 3: { direction[0] = Cosine(DegToRad(yaw + 180.0));direction[1] = Sine(DegToRad(yaw + 180.0));direction[2] = 0.0; }
        case 4: { direction[0] = Cosine(DegToRad(yaw));        direction[1] = Sine(DegToRad(yaw));        direction[2] = 1.0; }
    }
    NormalizeVector(direction, direction);
}

// ==========================================================================
// TIMERS DE CLEANUP DEL ESTADO DEL TANK
// ==========================================================================
public Action Timer_RemoveGlow(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client)) { 
        SetEntProp(client, Prop_Send, "m_iGlowType", 0); 
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 0); 
    }
    g_hGlowTimer[client] = null;
    return Plugin_Stop;
}

public Action Timer_RemoveImmunity(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) { 
        g_bTankImmune[client] = false; 
        SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage); 
    } 
    g_hImmunityTimer[client] = null;
    return Plugin_Stop; 
}

public Action Timer_UnfreezeTank(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) { 
        g_bTankFrozen[client] = false; 
        SetEntityMoveType(client, MOVETYPE_WALK); 
        PrintToChatAll("\x04[Tank] \x05¡Movimiento restaurado!"); 
    } 
    g_hFreezeTimer[client] = null;
    return Plugin_Stop; 
}

public Action Timer_RemoveRockImmunity(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) { 
        g_bTankRockImmune[client] = false; 
        SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage); 
    } 
    g_hRockImmuneTimer[client] = null;
    return Plugin_Stop; 
}

// ==========================================================================
// HOOKS DE DAÑO
// ==========================================================================
public Action Hook_TankTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) 
{ 
    if (g_bTankImmune[victim]) return Plugin_Handled; 
    return Plugin_Continue; 
}

public Action Hook_TankRockDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) 
{ 
    if (g_bTankRockImmune[victim] && IsValidEntity(inflictor)) { 
        char cls[64]; 
        GetEdictClassname(inflictor, cls, sizeof(cls)); 
        if (StrEqual(cls, "tank_rock")) return Plugin_Handled; 
    } 
    return Plugin_Continue; 
}

// ==========================================================================
// EVENTOS + CLEANUP
// ==========================================================================
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{ 
    CleanUpTank(GetClientOfUserId(event.GetInt("userid"))); 
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{ 
    for (int i = 1; i <= MaxClients; i++) CleanUpTank(i); 
}

void CleanUpTank(int client) 
{
    if (!IsValidClient(client)) return;

    if (g_bTankImmune[client])     SDKUnhook(client, SDKHook_OnTakeDamage,      Hook_TankTakeDamage);
    if (g_bTankRockImmune[client]) SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);

    g_bTankImmune[client]     = false; 
    g_bTankFrozen[client]     = false; 
    g_bTankRockImmune[client] = false;

    if (g_hImmunityTimer[client]   != null) { KillTimer(g_hImmunityTimer[client]);   g_hImmunityTimer[client]   = null; }
    if (g_hFreezeTimer[client]     != null) { KillTimer(g_hFreezeTimer[client]);     g_hFreezeTimer[client]     = null; }
    if (g_hRockImmuneTimer[client] != null) { KillTimer(g_hRockImmuneTimer[client]); g_hRockImmuneTimer[client] = null; }
    if (g_hGlowTimer[client]       != null) { KillTimer(g_hGlowTimer[client]);       g_hGlowTimer[client]       = null; }
}

// ==========================================================================
// TRACE FILTERS + HELPERS
// ==========================================================================
stock bool IsValidClient(int client) { return (client > 0 && client <= MaxClients && IsClientInGame(client)); }
public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data) { return entity == 0; }
