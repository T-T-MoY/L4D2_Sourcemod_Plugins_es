/**
 * ============================================================================
 * TANK ABILITIES ULTIMATE - V4.5.5 (FIXED)
 * ============================================================================
 * Fixes aplicados desde V4.5.4:
 *   [FIX 1] DataPack: se usa el patrón correcto de CreateDataTimer (como V3).
 *           Antes se creaba con "new DataPack()" manualmente y se pasaba al timer,
 *           lo cual no funciona con CreateDataTimer en SourceMod.
 *   [FIX 2] Línea spawnZ: se eliminó el operador coma dentro del ternario
 *           que era sintaxis no estándar y generaba comportamiento indefinido.
 *   [FIX 3] Lógica de dispersión Tipo B: se restauró la dispersión progresiva
 *           de V3 (progressRatio + maxRadius que se reduce) en lugar de la
 *           dispersión fija ±150 que no convergía al objetivo.
 *   [FIX 4] Targeting Tipo B: se restauró la lógica de V3 que alterna entre
 *           GetClosestSurvivor y survivor random (50/50) para mejor puntería.
 *   [FIX 5] Cooldown: se agregó verificación de validez del cliente en
 *           Timer_ResetCooldown para evitar que quede bloqueado si el tank
 *           se desconecta durante el cooldown.
 *   [FIX 6] Cleanup: se agregó SDKUnhook en CleanUpTank para liberar hooks
 *           correctamente cuando el tank muere o el round restarta.
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>

#define PLUGIN_VERSION "4.5.5"
#define ZOMBIECLASS_TANK 8

public Plugin myinfo = 
{
    name = "Tank Abilities Ultimate (v4.5.5 Fixed)",
    author = "[T-T]MoY",
    description = "Rocas con puntería corregida y TP seguro.",
    version = PLUGIN_VERSION,
    url = ""
}

// --- ConVars ---
ConVar g_cvEnable, g_cvChanceRock, g_cvChanceTP, g_cvDamage, g_cvMinRocks, g_cvMaxRocks, g_cvCooldown;

// --- Estado global ---
bool g_bPluginEnabled;
float g_fChanceRock, g_fChanceTP, g_fDamage, g_fCooldown;
int g_iMinRocks, g_iMaxRocks;

// --- Estado por jugador ---
bool g_bInCooldown[MAXPLAYERS + 1];
bool g_bTankImmune[MAXPLAYERS + 1];
bool g_bTankFrozen[MAXPLAYERS + 1];
bool g_bTankRockImmune[MAXPLAYERS + 1];
Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];

// --- Utilidad básica ---
bool IsValidClient(int client) 
{ 
    return (client > 0 && client <= MaxClients && IsClientInGame(client)); 
}

int CountAliveTanks() 
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
        {
            if (GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
                count++;
        }
    }
    return count;
}

// ============================================================================
// INICIALIZACIÓN
// ============================================================================
public void OnPluginStart()
{
    g_cvEnable      = CreateConVar("l4d2_tank_skills_enable",    "1",    "Habilitar habilidades", FCVAR_NOTIFY);
    g_cvChanceRock  = CreateConVar("l4d2_tank_rock_chance",      "80", "Probabilidad Lluvia de Rocas [0-100]");
    g_cvChanceTP    = CreateConVar("l4d2_tank_tp_chance",        "80", "Probabilidad Grito de Manada [0-100]");
    g_cvDamage      = CreateConVar("l4d2_tank_rock_damage",      "6",   "Daño rocas meteorito");
    g_cvMinRocks    = CreateConVar("l4d2_tank_min_rocks",        "15",    "Mínimo de rocas");
    g_cvMaxRocks    = CreateConVar("l4d2_tank_max_rocks",        "20",   "Máximo de rocas");
    g_cvCooldown    = CreateConVar("l4d2_tank_skill_cooldown",   "30", "Tiempo de espera entre usos");

    AutoExecConfig(true, "l4d2_tank_skills_ultimate");
    LoadConVarValues();
    g_cvEnable.AddChangeHook(OnConVarChanged);

    HookEvent("ability_use",  Event_AbilityUse);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start",  Event_RoundStart);
}

void LoadConVarValues() 
{
    g_bPluginEnabled = g_cvEnable.BoolValue;
    g_fChanceRock    = g_cvChanceRock.FloatValue;
    g_fChanceTP      = g_cvChanceTP.FloatValue;
    g_fDamage        = g_cvDamage.FloatValue;
    g_iMinRocks      = g_cvMinRocks.IntValue;
    g_iMaxRocks      = g_cvMaxRocks.IntValue;
    g_fCooldown      = g_cvCooldown.FloatValue;
}

public void OnConVarChanged(ConVar c, const char[] o, const char[] n) 
{ 
    LoadConVarValues(); 
}

// ============================================================================
// GESTOR DE DECISIONES
// ============================================================================
// Lógica: Rock y TP son checks INDEPENDIENTES (ambos pueden activarse juntos).
// El cooldown bloquea ambos hasta que se resetee.
// ============================================================================
public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPluginEnabled) return Plugin_Continue;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || GetClientTeam(client) != 3) return Plugin_Continue;
    if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK) return Plugin_Continue;
    if (g_bInCooldown[client]) return Plugin_Continue;

    char ability[32];
    event.GetString("ability", ability, sizeof(ability));
    
    if (StrEqual(ability, "ability_throw", true))
    {
        bool triggered = false;

        // --- Check independiente: Lluvia de Rocas ---
        if (GetRandomFloat(0.0, 100.0) < g_fChanceRock)
        {
            ExecuteMultiRock(client);
            triggered = true;
        }

        // --- Check independiente: Grito de Manada ---
        if (GetRandomFloat(0.0, 100.0) < g_fChanceTP)
        {
            if (CountAliveTanks() >= 2)
            {
                TeleportOtherTanks(client);
                triggered = true;
            }
        }

        // Activar cooldown solo si algo se disparó
        if (triggered)
        {
            g_bInCooldown[client] = true;
            CreateTimer(g_fCooldown, Timer_ResetCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    return Plugin_Continue;
}

// ============================================================================
// LLUVIA DE ROCAS - EJECUCIÓN PRINCIPAL
// ============================================================================
void ExecuteMultiRock(int client)
{
    int count = GetRandomInt(g_iMinRocks, g_iMaxRocks);

    // --- Inmunidad al daño durante la lluvia ---
    g_bTankImmune[client] = true;
    SDKHook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage);
    
    // --- Efecto visual: glow verde ---
    SetEntProp(client, Prop_Send, "m_iGlowType", 3);
    SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 10);
    SetEntProp(client, Prop_Send, "m_glowColorOverride", 25600);

    // --- Si hay más de 5 rocas: freeze + inmunidad a rocas propias ---
    if (count > 5)
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

    // --- [FIX 1] DataPack correcto: CreateDataTimer crea el pack, luego escribimos ---
    DataPack pack;
    CreateDataTimer(0.5, Timer_MultiRock, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(count);

    // --- Calcular duración según cantidad de rocas ---
    float duration = count > 5 ? (2.5 + ((count - 5) * 0.3)) : 2.5;

    // --- Timers de limpieza ---
    // Glow se elimina un poco después de la inmunidad
    CreateTimer(duration + 0.5, Timer_RemoveGlow, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

    // Inmunidad general
    if (g_hImmunityTimer[client] != null) KillTimer(g_hImmunityTimer[client]);
    g_hImmunityTimer[client] = CreateTimer(duration, Timer_RemoveImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

    // Freeze y inmunidad a rocas (solo si count > 5)
    if (count > 5)
    {
        if (g_hFreezeTimer[client] != null) KillTimer(g_hFreezeTimer[client]);
        g_hFreezeTimer[client] = CreateTimer(duration, Timer_UnfreezeTank, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        if (g_hRockImmuneTimer[client] != null) KillTimer(g_hRockImmuneTimer[client]);
        g_hRockImmuneTimer[client] = CreateTimer(duration + 1.0, Timer_RemoveRockImmunity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

// ============================================================================
// TIMER: Lanza las rocas después del delay de 0.5s
// ============================================================================
public Action Timer_MultiRock(Handle timer, DataPack pack) 
{ 
    pack.Reset(); 
    int userid   = pack.ReadCell(); 
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

// ============================================================================
// GENERACIÓN DE ROCAS - LÓGICA COMPLETA (restaurada de V3 con dispersión progresiva)
// ============================================================================
// Tipo A (rocas 0-4): Ráfaga frontal, se lanza desde cerca del tank
//                      apuntando a un survivor random.
// Tipo B (rocas 5+):  Meteoritos desde el cielo con AIM FIX.
//                      - Detección de techo para calcular altura de spawn.
//                      - Dummy target en el suelo para que la roca apunte bien.
//                      - El lanzador se rota antes de hacer spawn (el fix clave).
//                      - Dispersión progresiva: las primeras rocas caen lejos,
//                        las últimas se acercan más al objetivo.
// ============================================================================
void LaunchMultipleRocks(int client, float eyePos[3], int rockCount)
{ 
    // Buscar survivors vivos
    int survivors[MAXPLAYERS + 1];
    int survivorCount = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
            survivors[survivorCount++] = i;
    
    if (survivorCount == 0) return;
    
    // Preparar string de daño para el lanzador
    char damageStr[32];
    IntToString(RoundToNearest(g_fDamage), damageStr, sizeof(damageStr));
    
    // Ángulos del tank (para calcular dirección del ráfaga frontal)
    float tankAngles[3];
    GetClientEyeAngles(client, tankAngles);
    
    for (int rock = 0; rock < rockCount; rock++)
    {
        // Delay escalonado: las primeras 5 se disparan rápido, las demás más espaciadas
        float delay = rock < 5 ? (0.1 * rock) : (0.5 + (0.15 * (rock - 5)));

        // Crear el lanzador (NO hacemos DispatchSpawn aún para Tipo B)
        int ent = CreateEntityByName("env_rock_launcher");
        if (!IsValidEntity(ent)) continue;
        DispatchKeyValue(ent, "rockdamageoverride", damageStr);

        float launchPos[3];
        int targetEntity;
        int dummyRef = 0;

        // ================================================================
        // TIPO A: Ráfaga frontal (rocas 0 a 4)
        // ================================================================
        if (rock < 5)
        {
            DispatchSpawn(ent); // Spawn inmediato está bien para Tipo A

            int target = survivors[GetRandomInt(0, survivorCount - 1)];
            if (!IsValidClient(target) || !IsPlayerAlive(target)) 
            { 
                AcceptEntityInput(ent, "Kill"); 
                continue; 
            }
            targetEntity = target;

            // Calcular posición de lanzamiento basada en la dirección del tank
            float direction[3];
            GetDirectionalVector(rock, tankAngles, direction);
            launchPos[0] = eyePos[0] + (direction[0] * 300.0);
            launchPos[1] = eyePos[1] + (direction[1] * 300.0);
            launchPos[2] = eyePos[2] + (direction[2] * 300.0);
            TeleportEntity(ent, launchPos, NULL_VECTOR, NULL_VECTOR);
        }
        // ================================================================
        // TIPO B: Meteoritos con AIM FIX (rocas 5 en adelante)
        // ================================================================
        else
        {
            // 1. Elegir objetivo: 50% closest survivor, 50% random
            int targetSurvivor;
            if (GetRandomFloat(0.0, 100.0) < 50.0)
                targetSurvivor = GetClosestSurvivor(client, survivors, survivorCount);
            else
                targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            
            // Fallback si GetClosestSurvivor retorna -1
            if (targetSurvivor == -1 || !IsValidClient(targetSurvivor))
                targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            if (!IsValidClient(targetSurvivor)) 
            { 
                AcceptEntityInput(ent, "Kill"); 
                continue; 
            }

            // 2. Posición base del objetivo
            float survivorPos[3];
            GetClientAbsOrigin(targetSurvivor, survivorPos);
            
            // 3. Dispersión PROGRESIVA (las últimas rocas se acercan más)
            float progressRatio = float(rock - 5) / float(rockCount - 5 > 0 ? rockCount - 5 : 1);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6)); // De 250 a 100
            float radius = GetRandomFloat(20.0, maxRadius);
            float angle  = GetRandomFloat(0.0, 360.0);
            
            float targetX = survivorPos[0] + (Cosine(DegToRad(angle)) * radius);
            float targetY = survivorPos[1] + (Sine(DegToRad(angle)) * radius);
            float targetZ = survivorPos[2]; // Pies del survivor

            // 4. [FIX 2] Detección de techo - sin operador coma
            float traceStart[3], traceEnd[3];
            traceStart[0] = targetX; traceStart[1] = targetY; traceStart[2] = targetZ + 10.0;
            traceEnd[0]   = targetX; traceEnd[1]   = targetY; traceEnd[2]   = targetZ + 1200.0;
            
            Handle trace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_WorldOnly);
            
            float spawnHeightZ;
            if (TR_DidHit(trace)) 
            { 
                float hitPos[3]; 
                TR_GetEndPosition(hitPos, trace); 
                spawnHeightZ = hitPos[2] - 80.0;   // 80 unidades por debajo del techo
            }
            else 
            { 
                // Sin techo: altura base + bonus progresivo
                float heightBonus = float(rock - 5) * 40.0;
                spawnHeightZ = targetZ + 800.0 + heightBonus; 
            }
            delete trace;

            // Posición final de spawn del lanzador (en el cielo)
            launchPos[0] = targetX;
            launchPos[1] = targetY;
            launchPos[2] = spawnHeightZ;
            
            // 5. Crear Dummy Target en el suelo (donde debe caer la roca)
            int dummyTarget = CreateEntityByName("info_target");
            if (!IsValidEntity(dummyTarget)) 
            { 
                AcceptEntityInput(ent, "Kill"); 
                continue; 
            }
            float groundPos[3]; 
            groundPos[0] = targetX; 
            groundPos[1] = targetY; 
            groundPos[2] = targetZ;
            TeleportEntity(dummyTarget, groundPos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(dummyTarget);
            
            targetEntity = dummyTarget;
            dummyRef = EntIndexToEntRef(dummyTarget);

            // 6. CALCULAR ÁNGULO DE CAÍDA (El fix clave del AIM)
            //    Vector: desde launchPos (cielo) hacia groundPos (suelo)
            float vectorDir[3], aimAngles[3];
            SubtractVectors(groundPos, launchPos, vectorDir);
            GetVectorAngles(vectorDir, aimAngles);
            
            // 7. Spawn del lanzador YA ROTADO apuntando al objetivo
            DispatchSpawn(ent);
            TeleportEntity(ent, launchPos, aimAngles, NULL_VECTOR);
        }

        // Asignar target al lanzador
        SetVariantEntity(targetEntity);
        AcceptEntityInput(ent, "SetTarget");
        
        // Crear timer para disparar la roca con el delay calculado
        DataPack pack;
        CreateDataTimer(delay, Timer_LaunchRock, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(EntIndexToEntRef(ent));
        if (rock < 5) 
        { 
            pack.WriteCell(GetClientUserId(targetEntity));  // Tipo A: userid del survivor
            pack.WriteCell(0);                               // No hay dummy
        }
        else 
        { 
            pack.WriteCell(0);        // Tipo B: no re-target al survivor
            pack.WriteCell(dummyRef); // Referencia al dummy para eliminarlo después
        }
    }
}

// ============================================================================
// TIMER: Dispara cada roca individual
// ============================================================================
public Action Timer_LaunchRock(Handle timer, DataPack pack)
{
    pack.Reset();
    int entRef   = pack.ReadCell();
    int userid   = pack.ReadCell();
    int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef);

    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        // Para Tipo A: re-verificar que el survivor sigue vivo y re-asignar target
        if (userid != 0) 
        {
            int target = GetClientOfUserId(userid);
            if (IsValidClient(target) && IsPlayerAlive(target)) 
            { 
                SetVariantEntity(target); 
                AcceptEntityInput(ent, "SetTarget"); 
            }
        }

        // Disparar la roca
        AcceptEntityInput(ent, "LaunchRock");

        // Timer para eliminar el lanzador y el dummy después de 0.1s
        DataPack packRemove;
        CreateDataTimer(0.1, Timer_RemoveLauncher, packRemove, TIMER_FLAG_NO_MAPCHANGE);
        packRemove.WriteCell(entRef);
        packRemove.WriteCell(dummyRef);
    }
    return Plugin_Stop;
}

// ============================================================================
// TIMER: Elimina el lanzador y el dummy
// ============================================================================
public Action Timer_RemoveLauncher(Handle timer, DataPack pack) 
{
    pack.Reset(); 
    int entRef   = pack.ReadCell(); 
    int dummyRef = pack.ReadCell(); 
    
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) 
        AcceptEntityInput(ent, "Kill");
    
    if (dummyRef != 0) 
    { 
        int dummy = EntRefToEntIndex(dummyRef); 
        if (dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy)) 
            AcceptEntityInput(dummy, "Kill"); 
    }
    return Plugin_Stop;
}

// ============================================================================
// HELPER: Obtiene el survivor más cercano al tank
// ============================================================================
int GetClosestSurvivor(int client, int[] survivors, int survivorCount)
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);
    int closest   = -1;
    float minDist = 999999.0;

    for (int i = 0; i < survivorCount; i++)
    {
        int survivor = survivors[i];
        if (!IsValidClient(survivor) || !IsPlayerAlive(survivor)) continue;

        float survivorPos[3];
        GetClientAbsOrigin(survivor, survivorPos);
        float dist = GetVectorDistance(tankPos, survivorPos);
        if (dist < minDist) 
        { 
            minDist = dist; 
            closest = survivor; 
        }
    }
    return closest;
}

// ============================================================================
// HELPER: Calcula vectores direccionales para la ráfaga frontal (Tipo A)
// ============================================================================
void GetDirectionalVector(int rockIndex, float tankAngles[3], float direction[3])
{
    float yaw   = tankAngles[1]; 
    float pitch = tankAngles[0];

    switch (rockIndex) 
    {
        case 0: // Centro (frontal)
        { 
            direction[0] =  Cosine(DegToRad(yaw)); 
            direction[1] =  Sine(DegToRad(yaw)); 
            direction[2] = -Sine(DegToRad(pitch)); 
        }
        case 1: // Derecha
        { 
            direction[0] = Cosine(DegToRad(yaw + 90.0)); 
            direction[1] = Sine(DegToRad(yaw + 90.0)); 
            direction[2] = 0.0; 
        }
        case 2: // Izquierda
        { 
            direction[0] = Cosine(DegToRad(yaw - 90.0)); 
            direction[1] = Sine(DegToRad(yaw - 90.0)); 
            direction[2] = 0.0; 
        }
        case 3: // Atrás
        { 
            direction[0] = Cosine(DegToRad(yaw + 180.0)); 
            direction[1] = Sine(DegToRad(yaw + 180.0)); 
            direction[2] = 0.0; 
        }
        case 4: // Arriba
        { 
            direction[0] = Cosine(DegToRad(yaw)); 
            direction[1] = Sine(DegToRad(yaw)); 
            direction[2] = 1.0; 
        }
    }
    NormalizeVector(direction, direction);
}

// ============================================================================
// TELEPORT: Grito de Manada (TP de otros tanks)
// ============================================================================
void TeleportOtherTanks(int client) 
{
    PrintToChatAll("\x04[Tank] \x03¡GRITO! \x05¡La manada se reúne!");
    float targetPos[3];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client) continue;
        if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
        {
            if (FindSafeTeleportSpot(client, targetPos)) 
            {
                TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR);
                PrintToChat(i, "\x04[Tank] \x05¡La manada te llama!");
            }
        }
    }
}

// Busca una posición segura cercana al tank con hull trace
bool FindSafeTeleportSpot(int client, float targetPos[3])
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);

    // Intentar hasta 15 veces encontrar un spot libre
    for (int i = 0; i < 15; i++)
    {
        float angle  = GetRandomFloat(0.0, 360.0);
        float radius = GetRandomFloat(200.0, 400.0);

        float spawnPos[3];
        spawnPos[0] = tankPos[0] + (Cosine(DegToRad(angle)) * radius);
        spawnPos[1] = tankPos[1] + (Sine(DegToRad(angle)) * radius);
        spawnPos[2] = tankPos[2];

        // Trace hacia abajo para encontrar el suelo
        float traceStart[3], traceEnd[3];
        traceStart[0] = spawnPos[0]; traceStart[1] = spawnPos[1]; traceStart[2] = spawnPos[2] + 200.0;
        traceEnd[0]   = spawnPos[0]; traceEnd[1]   = spawnPos[1]; traceEnd[2]   = spawnPos[2] - 400.0;

        Handle trace = TR_TraceHullFilterEx(traceStart, traceEnd, {-32.0, -32.0, 0.0}, {32.0, 32.0, 100.0}, MASK_PLAYERSOLID, TraceFilter_IgnoreTank, client);
        
        if (TR_DidHit(trace)) 
        { 
            TR_GetEndPosition(targetPos, trace); 
            targetPos[2] += 1.0; // Un pixel arriba del suelo
            delete trace; 
            return true; 
        }
        delete trace;
    }
    return false;
}

// ============================================================================
// TIMERS DE LIMPIEZA DE ESTADO DEL TANK
// ============================================================================

// [FIX 5] Resetear cooldown con verificación de validez
public Action Timer_ResetCooldown(Handle timer, any userid) 
{ 
    int c = GetClientOfUserId(userid); 
    if (c > 0 && c <= MaxClients)  // Verificar rango aunque no esté conectado
        g_bInCooldown[c] = false; 
    return Plugin_Stop; 
}

public Action Timer_RemoveGlow(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client)) 
    { 
        SetEntProp(client, Prop_Send, "m_iGlowType", 0); 
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 0); 
    }
    return Plugin_Stop;
}

public Action Timer_RemoveImmunity(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) 
    { 
        g_bTankImmune[client] = false; 
        g_hImmunityTimer[client] = null; 
        SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage); 
    } 
    return Plugin_Stop; 
}

public Action Timer_UnfreezeTank(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) 
    { 
        g_bTankFrozen[client] = false; 
        SetEntityMoveType(client, MOVETYPE_WALK); 
        g_hFreezeTimer[client] = null; 
        PrintToChatAll("\x04[Tank] \x05¡Movimiento restaurado!"); 
    } 
    return Plugin_Stop; 
}

public Action Timer_RemoveRockImmunity(Handle timer, any userid) 
{ 
    int client = GetClientOfUserId(userid); 
    if (IsValidClient(client)) 
    { 
        g_bTankRockImmune[client] = false; 
        g_hRockImmuneTimer[client] = null; 
        SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage); 
    } 
    return Plugin_Stop; 
}

// ============================================================================
// HOOKS DE DAÑO
// ============================================================================
// Bloquea TODO el daño al tank mientras está inmune (durante la lluvia)
public Action Hook_TankTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) 
{ 
    if (g_bTankImmune[victim]) return Plugin_Handled; 
    return Plugin_Continue; 
}

// Bloquea solo el daño de tank_rock al tank (para que sus propias rocas no lo dañen)
public Action Hook_TankRockDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) 
{ 
    if (g_bTankRockImmune[victim] && IsValidEntity(inflictor)) 
    { 
        char cls[64]; 
        GetEdictClassname(inflictor, cls, sizeof(cls)); 
        if (StrEqual(cls, "tank_rock")) return Plugin_Handled; 
    } 
    return Plugin_Continue; 
}

// ============================================================================
// EVENTOS DE LIMPIEZA
// ============================================================================
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{ 
    CleanUpTank(GetClientOfUserId(event.GetInt("userid"))); 
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{ 
    for (int i = 1; i <= MaxClients; i++) CleanUpTank(i); 
}

// [FIX 6] Cleanup completo: timers, hooks, flags, movetype
void CleanUpTank(int client) 
{
    if (client < 1 || client > MaxClients) return;

    // Resetear flags
    g_bTankImmune[client]     = false; 
    g_bTankFrozen[client]     = false; 
    g_bInCooldown[client]     = false; 
    g_bTankRockImmune[client] = false;

    // Restaurar movimiento
    SetEntityMoveType(client, MOVETYPE_WALK); 

    // Matar timers activos
    if (g_hImmunityTimer[client]   != null) { KillTimer(g_hImmunityTimer[client]);   g_hImmunityTimer[client]   = null; }
    if (g_hFreezeTimer[client]     != null) { KillTimer(g_hFreezeTimer[client]);     g_hFreezeTimer[client]     = null; }
    if (g_hRockImmuneTimer[client] != null) { KillTimer(g_hRockImmuneTimer[client]); g_hRockImmuneTimer[client] = null; }

    // Liberar hooks
    SDKUnhook(client, SDKHook_OnTakeDamage,      Hook_TankTakeDamage);
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);
}

// ============================================================================
// FILTROS DE TRACE
// ============================================================================
public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data) 
{ 
    return (entity != data); 
}

public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data) 
{ 
    return entity == 0; 
}
