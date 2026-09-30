/**
 * ============================================================================
 * TANK MULTI-ROCK & HERD CALL - V3.4.0 (AIM FIX)
 * ============================================================================
 * Descripción: 
 * - Tipo B: Lluvia de Meteoritos con TRAYECTORIA CALCULADA.
 * - Fix: Ahora el lanzador rota físicamente para apuntar al superviviente 
 * antes de disparar, evitando el "ángulo fijo".
 * - Mantiene el fix de altura Z y detección de techos.
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>

#define PLUGIN_VERSION "3.4.0-AimFix"
#define ZOMBIECLASS_TANK 8

public Plugin myinfo = 
{
    name = "Tank Multi-Rock & Herd Call L4D2_AIM",
    author = "[T-T]MoY",
    description = "Tank lanza rocas con puntería dinámica real.",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_cvEnable;
ConVar g_cvChance;
ConVar g_cvDamage;
ConVar g_cvMinRocks;
ConVar g_cvMaxRocks;
ConVar g_cvHerdCallChance;

// Variables Globales
bool g_bPluginEnabled = true;
float g_fChanceValue = 25.0;
float g_fDamageValue = 20.0;
int g_iMinRocksValue = 1;
int g_iMaxRocksValue = 2;
float g_fHerdCallChance = 10.0;

// Variables de estado
bool g_bTankImmune[MAXPLAYERS + 1];
bool g_bTankFrozen[MAXPLAYERS + 1];
bool g_bTankRockImmune[MAXPLAYERS + 1]; 
Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("l4d2_multi_rock_enable", "1", "0:deshabilitado, 1:habilitado", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvChance = CreateConVar("l4d2_multi_rock_chance_throw", "25.0", "Probabilidad throw [0.0, 100.0]", FCVAR_NONE, true, 0.0, true, 100.0);
    g_cvDamage = CreateConVar("l4d2_multi_rock_damage", "20", "Daño rocas [1.0, 100.0]", FCVAR_NONE, true, 1.0, true, 100.0);
    g_cvMinRocks = CreateConVar("l4d2_multi_rock_min", "1", "Mínimo rocas [1-20]", FCVAR_NONE, true, 1.0, true, 20.0);
    g_cvMaxRocks = CreateConVar("l4d2_multi_rock_max", "2", "Máximo rocas [1-20]", FCVAR_NONE, true, 1.0, true, 20.0);
    g_cvHerdCallChance = CreateConVar("l4d2_tank_herdcall_chance", "10.0", "Probabilidad Herd Call [0.0, 100.0]", FCVAR_NONE, true, 0.0, true, 100.0);

    AutoExecConfig(true, "l4d2_tank_abilities"); 
    LoadConVarValues();
    
    g_cvEnable.AddChangeHook(OnConVarChanged);
    g_cvChance.AddChangeHook(OnConVarChanged);
    g_cvDamage.AddChangeHook(OnConVarChanged);
    g_cvMinRocks.AddChangeHook(OnConVarChanged);
    g_cvMaxRocks.AddChangeHook(OnConVarChanged);
    g_cvHerdCallChance.AddChangeHook(OnConVarChanged);
    
    HookEvent("ability_use", Event_AbilityUse);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
    
    RegAdminCmd("sm_tankabilities", Command_TankAbilities, ADMFLAG_GENERIC, "Toggle Tank Abilities");
    RegAdminCmd("sm_tankabilities_reload", Cmd_ReloadValues, ADMFLAG_ROOT, "Recargar valores");
}

void LoadConVarValues()
{
    g_bPluginEnabled = g_cvEnable.BoolValue;
    g_fChanceValue = g_cvChance.FloatValue;
    g_fDamageValue = g_cvDamage.FloatValue;
    g_iMinRocksValue = g_cvMinRocks.IntValue;
    g_iMaxRocksValue = g_cvMaxRocks.IntValue;
    g_fHerdCallChance = g_cvHerdCallChance.FloatValue;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LoadConVarValues();
}

public Action Command_TankAbilities(int client, int args)
{
    if (!client) return Plugin_Handled;
    g_bPluginEnabled = !g_bPluginEnabled;
    g_cvEnable.SetBool(g_bPluginEnabled);
    PrintToChatAll("[SM] Tank Abilities: %s", g_bPluginEnabled ? "\x04Activado" : "\x02Desactivado");
    return Plugin_Handled;
}

public Action Cmd_ReloadValues(int client, int args)
{
    LoadConVarValues();
    ReplyToCommand(client, "[Tank Abilities] Valores recargados.");
    return Plugin_Handled;
}

public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    return Plugin_Continue;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{   
    if(!g_bPluginEnabled) return Plugin_Continue;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;
    if(GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK) return Plugin_Continue;
    
    char ability[32];
    event.GetString("ability", ability, sizeof(ability));
    
    if(StrEqual(ability, "ability_throw", true))
    {   
        float random_rock = GetRandomFloat(0.0, 100.0);
        float random_herdcall = GetRandomFloat(0.0, 100.0);

        if(random_rock < g_fChanceValue)
        {   
            int rockCount = GetRandomInt(g_iMinRocksValue, g_iMaxRocksValue);
            
            g_bTankImmune[client] = true;
            SDKHook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage);
            
            // Efectos visuales
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
            SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 10);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 25600);
            
            if(rockCount > 5)
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
            
            DataPack pack;
            CreateDataTimer(0.5, Timer_MultiRock, pack, TIMER_FLAG_NO_MAPCHANGE);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(rockCount);
            
            float freezeTime = rockCount > 5 ? (2.5 + ((rockCount - 5) * 0.3)) : 2.5;
            CreateTimer(freezeTime + 0.5, Timer_RemoveGlow, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
            
            if(g_hImmunityTimer[client] != null) KillTimer(g_hImmunityTimer[client]);
            g_hImmunityTimer[client] = CreateTimer(freezeTime, Timer_RemoveImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
            
            if(rockCount > 5)
            {
                if(g_hFreezeTimer[client] != null) KillTimer(g_hFreezeTimer[client]);
                g_hFreezeTimer[client] = CreateTimer(freezeTime, Timer_UnfreezeTank, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
                
                if(g_hRockImmuneTimer[client] != null) KillTimer(g_hRockImmuneTimer[client]);
                g_hRockImmuneTimer[client] = CreateTimer(freezeTime + 1.0, Timer_RemoveRockImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
            }
        }
        else if (random_herdcall < g_fHerdCallChance)
        {
            if (CountAliveTanks() >= 2) TeleportOtherTanks(client);
        }
    }
    return Plugin_Continue;
}

// --- UTILIDADES ---
int CountAliveTanks()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK) count++;
    return count;
}

void TeleportOtherTanks(int client)
{
    PrintToChatAll("\x04[Tank] \x03¡GRITO! \x05¡Llamando a la MANADA!");
    float targetPos[3];
    int teleportedCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client) continue;
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
        {
            if (FindSafeTeleportSpot(client, targetPos))
            {
                TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR);
                PrintToChat(i, "\x04[Tank] \x05¡La manada te llama!");
                teleportedCount++;
            }
        }
    }
}

bool FindSafeTeleportSpot(int client, float targetPos[3])
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);
    float angle = GetRandomFloat(0.0, 360.0);
    float radius = GetRandomFloat(200.0, 400.0);
    float spawnPos[3];
    spawnPos[0] = tankPos[0] + (Cosine(DegToRad(angle)) * radius);
    spawnPos[1] = tankPos[1] + (Sine(DegToRad(angle)) * radius);
    spawnPos[2] = tankPos[2]; 
    float traceStart[3], traceEnd[3];
    traceStart = spawnPos; traceStart[2] += 200.0;
    traceEnd = spawnPos; traceEnd[2] -= 400.0;
    Handle trace = TR_TraceHullFilterEx(traceStart, traceEnd, {-32.0, -32.0, 0.0}, {32.0, 32.0, 100.0}, MASK_PLAYERSOLID, TraceFilter_IgnoreTank, client);
    bool foundSpot = false;
    if (TR_DidHit(trace)) { TR_GetEndPosition(targetPos, trace); targetPos[2] += 1.0; foundSpot = true; }
    CloseHandle(trace); 
    return foundSpot;
}

// --- HELPERS TARGETING ---
int GetClosestSurvivor(int client, int[] survivors, int survivorCount)
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);
    int closest = -1;
    float minDist = 999999.0;
    for(int i = 0; i < survivorCount; i++)
    {
        int survivor = survivors[i];
        if(!IsValidClient(survivor) || !IsPlayerAlive(survivor)) continue;
        float survivorPos[3];
        GetClientAbsOrigin(survivor, survivorPos);
        float dist = GetVectorDistance(tankPos, survivorPos);
        if(dist < minDist) { minDist = dist; closest = survivor; }
    }
    return closest;
}

// --- GENERACION ROCAS ---
public Action Timer_MultiRock(Handle timer, DataPack pack)
{ 
    pack.Reset();
    int userid = pack.ReadCell();
    int rockCount = pack.ReadCell();
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
    {
        float eyePos[3];
        GetClientEyePosition(client, eyePos);
        LaunchMultipleRocks(client, eyePos, rockCount);
    }
    return Plugin_Stop;
}

void LaunchMultipleRocks(int client, float eyePos[3], int rockCount)
{ 
    int survivors[MAXPLAYERS + 1];
    int survivorCount = 0;
    for(int i = 1; i <= MaxClients; i++)
        if(IsValidClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) survivors[survivorCount++] = i;
    
    if(survivorCount == 0) return;
    
    char damageStr[32];
    IntToString(RoundToNearest(g_fDamageValue), damageStr, sizeof(damageStr));
    
    float tankAngles[3];
    GetClientEyeAngles(client, tankAngles);
    
    for(int rock = 0; rock < rockCount; rock++)
    {
        float delay = rock < 5 ? (0.1 * rock) : (0.5 + (0.15 * (rock - 5)));
        int ent = CreateEntityByName("env_rock_launcher");
        if(!IsValidEntity(ent)) continue;
        
        DispatchKeyValue(ent, "rockdamageoverride", damageStr);
        // NO HACEMOS DISPATCHSPAWN AUN, primero posicionamos y rotamos

        float launchPos[3];
        int targetEntity;
        int dummyRef = 0;

        // TIPO A: Rocas normales
        if(rock < 5)
        {
            DispatchSpawn(ent); // Para rocas normales spawn inmediato esta bien
            
            int target = survivors[GetRandomInt(0, survivorCount - 1)];
            if(!IsValidClient(target) || !IsPlayerAlive(target)) { AcceptEntityInput(ent, "Kill"); continue; }
            targetEntity = target;

            float direction[3];
            GetDirectionalVector(rock, tankAngles, direction);
            launchPos[0] = eyePos[0] + (direction[0] * 300.0);
            launchPos[1] = eyePos[1] + (direction[1] * 300.0);
            launchPos[2] = eyePos[2] + (direction[2] * 300.0);
            TeleportEntity(ent, launchPos, NULL_VECTOR, NULL_VECTOR);
        }
        // TIPO B: Lluvia INTELIGENTE (Fix Aim + Fix Height)
        else
        {
            // 1. Elegir objetivo
            int targetSurvivor;
            if(GetRandomFloat(0.0, 100.0) < 50.0) targetSurvivor = GetClosestSurvivor(client, survivors, survivorCount);
            else targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            
            if(targetSurvivor == -1 || !IsValidClient(targetSurvivor)) targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            if(!IsValidClient(targetSurvivor)) { AcceptEntityInput(ent, "Kill"); continue; }

            // 2. Obtener posición "Auxiliar" (Destino)
            float survivorPos[3];
            GetClientAbsOrigin(targetSurvivor, survivorPos);
            
            // Dispersión
            float progressRatio = float(rock - 5) / float(rockCount - 5);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6)); 
            float radius = GetRandomFloat(20.0, maxRadius); // Min 20 para que no sea injusto perfecto
            float angle = GetRandomFloat(0.0, 360.0);
            
            float targetX = survivorPos[0] + (Cosine(DegToRad(angle)) * radius);
            float targetY = survivorPos[1] + (Sine(DegToRad(angle)) * radius);
            float targetZ = survivorPos[2]; // Pies del survivor

            // 3. Calcular posición de Spawn (Origen) en el cielo
            float traceStart[3], traceEnd[3];
            traceStart[0] = targetX; traceStart[1] = targetY; traceStart[2] = targetZ + 10.0;
            traceEnd[0] = targetX; traceEnd[1] = targetY; traceEnd[2] = targetZ + 1200.0;
            
            Handle trace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_WorldOnly);
            float spawnHeightZ;
            if(TR_DidHit(trace)) { float hitPos[3]; TR_GetEndPosition(hitPos, trace); spawnHeightZ = hitPos[2] - 80.0; }
            else { float heightBonus = float(rock - 5) * 40.0; spawnHeightZ = targetZ + 800.0 + heightBonus; }
            CloseHandle(trace);

            launchPos[0] = targetX;
            launchPos[1] = targetY;
            launchPos[2] = spawnHeightZ;
            
            // 4. CREAR DUMMY TARGET (La posición auxiliar fija)
            int dummyTarget = CreateEntityByName("info_target");
            if (!IsValidEntity(dummyTarget)) { AcceptEntityInput(ent, "Kill"); continue; }
            float groundPos[3]; groundPos[0] = targetX; groundPos[1] = targetY; groundPos[2] = targetZ;
            TeleportEntity(dummyTarget, groundPos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(dummyTarget);
            targetEntity = dummyTarget;
            dummyRef = EntIndexToEntRef(dummyTarget); 

            // 5. CALCULO DE ANGULO (El Fix clave)
            // Vector Origen -> Destino
            float vectorDir[3], aimAngles[3];
            SubtractVectors(groundPos, launchPos, vectorDir);
            GetVectorAngles(vectorDir, aimAngles);
            
            // 6. Spawnear lanzador YA ROTADO mirando al objetivo
            DispatchSpawn(ent);
            TeleportEntity(ent, launchPos, aimAngles, NULL_VECTOR);
        }

        SetVariantEntity(targetEntity);
        AcceptEntityInput(ent, "SetTarget");
        
        DataPack pack;
        CreateDataTimer(delay, Timer_LaunchRock, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(EntIndexToEntRef(ent));
        if (rock < 5) { pack.WriteCell(GetClientUserId(targetEntity)); pack.WriteCell(0); }
        else { pack.WriteCell(0); pack.WriteCell(dummyRef); }
    }
}

// --- VECTORES Y FISICA ---
void GetDirectionalVector(int rockIndex, float tankAngles[3], float direction[3])
{
    float yaw = tankAngles[1]; float pitch = tankAngles[0];
    switch(rockIndex) {
        case 0: { direction[0] = Cosine(DegToRad(yaw)); direction[1] = Sine(DegToRad(yaw)); direction[2] = -Sine(DegToRad(pitch)); }
        case 1: { direction[0] = Cosine(DegToRad(yaw + 90.0)); direction[1] = Sine(DegToRad(yaw + 90.0)); direction[2] = 0.0; }
        case 2: { direction[0] = Cosine(DegToRad(yaw - 90.0)); direction[1] = Sine(DegToRad(yaw - 90.0)); direction[2] = 0.0; }
        case 3: { direction[0] = Cosine(DegToRad(yaw + 180.0)); direction[1] = Sine(DegToRad(yaw + 180.0)); direction[2] = 0.0; }
        case 4: { direction[0] = Cosine(DegToRad(yaw)); direction[1] = Sine(DegToRad(yaw)); direction[2] = 1.0; }
    }
    NormalizeVector(direction, direction);
}

public Action Timer_LaunchRock(Handle timer, DataPack pack)
{
    pack.Reset();
    int entRef = pack.ReadCell();
    int userid = pack.ReadCell();
    int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef);
    if(ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        if (userid != 0) {
            int target = GetClientOfUserId(userid);
            if(IsValidClient(target) && IsPlayerAlive(target)) { SetVariantEntity(target); AcceptEntityInput(ent, "SetTarget"); }
        }
        AcceptEntityInput(ent, "LaunchRock");
        DataPack pack_remove;
        CreateDataTimer(0.1, Timer_RemoveLauncher, pack_remove, TIMER_FLAG_NO_MAPCHANGE);
        pack_remove.WriteCell(entRef);
        pack_remove.WriteCell(dummyRef);
    }
    return Plugin_Stop;
}

public Action Timer_RemoveLauncher(Handle timer, DataPack pack) 
{
    pack.Reset(); 
    int entRef = pack.ReadCell(); 
    int dummyRef = pack.ReadCell(); 
    int ent = EntRefToEntIndex(entRef);
    if(ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) AcceptEntityInput(ent, "Kill");
    if (dummyRef != 0) { int dummy = EntRefToEntIndex(dummyRef); if(dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy)) AcceptEntityInput(dummy, "Kill"); }
    return Plugin_Stop;
}

// --- LIMPIEZA TIMERS ---
public Action Timer_RemoveGlow(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client)) { SetEntProp(client, Prop_Send, "m_iGlowType", 0); SetEntProp(client, Prop_Send, "m_glowColorOverride", 0); }
    return Plugin_Stop;
}
public Action Timer_RemoveImmunity(Handle timer, any userid) { int client = GetClientOfUserId(userid); if(IsValidClient(client)) { g_bTankImmune[client] = false; g_hImmunityTimer[client] = null; SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage); } return Plugin_Stop; }
public Action Timer_UnfreezeTank(Handle timer, any userid) { int client = GetClientOfUserId(userid); if(IsValidClient(client)) { g_bTankFrozen[client] = false; SetEntityMoveType(client, MOVETYPE_WALK); g_hFreezeTimer[client] = null; PrintToChatAll("\x04[Tank] \x05¡Movimiento restaurado!"); } return Plugin_Stop; }
public Action Timer_RemoveRockImmunity(Handle timer, any userid) { int client = GetClientOfUserId(userid); if(IsValidClient(client)) { g_bTankRockImmune[client] = false; g_hRockImmuneTimer[client] = null; SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage); } return Plugin_Stop; }
public Action Hook_TankRockDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) { if(g_bTankRockImmune[victim] && IsValidEntity(inflictor)) { char cls[64]; GetEdictClassname(inflictor, cls, sizeof(cls)); if(StrEqual(cls, "tank_rock")) return Plugin_Handled; } return Plugin_Continue; }
public Action Hook_TankTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) { if(g_bTankImmune[victim]) return Plugin_Handled; return Plugin_Continue; }
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) { int client = GetClientOfUserId(event.GetInt("userid")); CleanUpTank(client); return Plugin_Continue; }
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) { for(int i=1; i<=MaxClients; i++) CleanUpTank(i); return Plugin_Continue; }
void CleanUpTank(int client) {
    if(!IsValidClient(client)) return;
    g_bTankImmune[client]=false; g_bTankFrozen[client]=false; g_bTankRockImmune[client]=false;
    if(g_hImmunityTimer[client]!=null){KillTimer(g_hImmunityTimer[client]); g_hImmunityTimer[client]=null;}
    if(g_hFreezeTimer[client]!=null){KillTimer(g_hFreezeTimer[client]); g_hFreezeTimer[client]=null;}
    if(g_hRockImmuneTimer[client]!=null){KillTimer(g_hRockImmuneTimer[client]); g_hRockImmuneTimer[client]=null;}
    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage); SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);
}
bool IsValidClient(int client) { return (client > 0 && client <= MaxClients && IsClientInGame(client)); }
public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data) { return (entity != data); }
public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data) { return entity == 0; }