#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>

#define PLUGIN_VERSION "5.1.0"
#define ZOMBIECLASS_TANK 8

// --- ConVars ---
ConVar g_cvEnable, g_cvChanceRock, g_cvChanceTP, g_cvChanceThief, g_cvDamage, g_cvMinRocks, g_cvMaxRocks, g_cvCooldown;
ConVar g_cvEnableRockRain, g_cvEnableTP, g_cvEnableThiefPower, g_cvVersusMode;
ConVar g_cvRockRainCD, g_cvTeleportCD;

// --- Estado global ---
bool g_bPluginEnabled;
bool g_bVersusMode;
float g_fChanceRock, g_fChanceTP, g_fChanceThief, g_fDamage, g_fCooldown;
float g_fRockRainCD, g_fTeleportCD;
int g_iMinRocks, g_iMaxRocks;

// --- Estado por jugador ---
bool g_bInCooldown[MAXPLAYERS + 1];
bool g_bIsThief[MAXPLAYERS + 1];
bool g_bTankImmune[MAXPLAYERS + 1];
bool g_bTankFrozen[MAXPLAYERS + 1];
bool g_bTankRockImmune[MAXPLAYERS + 1];
Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];

// --- Cooldowns independientes ---
float g_fLastRockRain[MAXPLAYERS + 1];
float g_fLastTP[MAXPLAYERS + 1];

// --- Menú persistente ---
Handle g_hPowerMenu[MAXPLAYERS + 1];
bool g_bMenuOpen[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "Tank Abilities Ultimate (V5.1 Menu Edition)",
    author = "[T-T]MoY & Gemini AI",
    description = "TP, Meteoros con Delay, Thief Tank Blanco y Fuego - Menú Persistente",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart()
{
    // CVars originales
    g_cvEnable      = CreateConVar("l4d2_tank_skills_enable",    "1", "Habilitar habilidades", FCVAR_NOTIFY);
    g_cvChanceRock  = CreateConVar("l4d2_tank_rock_chance",      "80", "Probabilidad Lluvia de Rocas");
    g_cvChanceTP    = CreateConVar("l4d2_tank_tp_chance",        "80", "Probabilidad Grito de Manada");
    g_cvChanceThief = CreateConVar("l4d2_tank_thief_chance",     "80", "Probabilidad de ser Thief Tank Blanco");
    g_cvDamage      = CreateConVar("l4d2_tank_rock_damage",      "6",  "Daño rocas meteorito");
    g_cvMinRocks    = CreateConVar("l4d2_tank_min_rocks",        "15", "Mínimo de rocas");
    g_cvMaxRocks    = CreateConVar("l4d2_tank_max_rocks",        "20", "Máximo de rocas");
    g_cvCooldown    = CreateConVar("l4d2_tank_skill_cooldown",   "30", "Tiempo de espera global");

    // Switches independientes
    g_cvEnableRockRain   = CreateConVar("l4d2_enable_rockrain",   "1", "0=OFF 1=ON Lluvia de Rocas");
    g_cvEnableTP         = CreateConVar("l4d2_enable_teleport",   "1", "0=OFF 1=ON Teletransporte");
    g_cvEnableThiefPower = CreateConVar("l4d2_enable_thiefpower", "1", "0=OFF 1=ON Poderes Thief (robo+fuego)");
    g_cvVersusMode       = CreateConVar("l4d2_versus_mode",       "0", "0=Auto (Coop) 1=Manual (Versus con menú)");
    
    g_cvRockRainCD  = CreateConVar("l4d2_rockrain_cooldown",  "30", "Cooldown Lluvia de Rocas (segundos)");
    g_cvTeleportCD  = CreateConVar("l4d2_teleport_cooldown",  "40", "Cooldown Teletransporte (segundos)");

    AutoExecConfig(true, "l4d2_tank_skills_ultimate");
    LoadConVarValues();

    // Comandos para abrir menú
    RegConsoleCmd("sm_power", Command_PowerMenu, "Abrir menú de poderes Tank");
    RegConsoleCmd("sm_powers", Command_PowerMenu, "Abrir menú de poderes Tank");
    RegConsoleCmd("sm_tankmenu", Command_PowerMenu, "Abrir menú de poderes Tank");

    HookEvent("ability_use",  Event_AbilityUse);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt",  Event_PlayerHurt);
    HookEvent("round_start",  Event_RoundStart);
    HookEvent("round_end",    Event_RoundEnd);
}

void LoadConVarValues() 
{
    g_bPluginEnabled = g_cvEnable.BoolValue;
    g_bVersusMode    = g_cvVersusMode.BoolValue;
    g_fChanceRock    = g_cvChanceRock.FloatValue;
    g_fChanceTP      = g_cvChanceTP.FloatValue;
    g_fChanceThief   = g_cvChanceThief.FloatValue;
    g_fDamage        = g_cvDamage.FloatValue;
    g_iMinRocks      = g_cvMinRocks.IntValue;
    g_iMaxRocks      = g_cvMaxRocks.IntValue;
    g_fCooldown      = g_cvCooldown.FloatValue;
    g_fRockRainCD    = g_cvRockRainCD.FloatValue;
    g_fTeleportCD    = g_cvTeleportCD.FloatValue;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_SurvivorTakeDamage);
    g_fLastRockRain[client] = 0.0;
    g_fLastTP[client] = 0.0;
    g_bMenuOpen[client] = false;
    g_hPowerMenu[client] = null;
}

public void OnClientDisconnect(int client)
{
    CloseMenuIfOpen(client);
}

// --- Utilidades de Cliente ---
bool IsValidClient(int client) 
{ 
    return (client > 0 && client <= MaxClients && IsClientInGame(client)); 
}

bool IsTank(int client)
{
    return (IsValidClient(client) && GetClientTeam(client) == 3 && 
            GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK && IsPlayerAlive(client));
}

int CountAliveTanks() 
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsTank(i)) count++;
    }
    return count;
}

// ============================================================================
// SISTEMA DE SPAWN Y COLOR (THIEF TANK)
// ============================================================================
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client) && GetClientTeam(client) == 3)
    {
        if (GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
        {
            CreateTimer(0.2, Timer_ApplyTankType, GetClientUserId(client));
        }
    }
}

public Action Timer_ApplyTankType(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;

    // Spawn aleatorio
    if (GetRandomFloat(0.0, 100.0) < g_fChanceThief)
    {
        // THIEF TANK (BLANCO)
        g_bIsThief[client] = true;
        SetEntityRenderColor(client, 255, 255, 255, 255);
        
        SetEntProp(client, Prop_Send, "m_iGlowType", 3);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
        
        //PrintToChatAll("\x04[Tank] \x05¡Apareció un Thief Fire Tank (Blanco)!");
        
        if (g_bVersusMode)
        {
            PrintToChat(client, "\x04[Powers] \x03Escribe \x05!power \x03para abrir el menú");
            PrintToChat(client, "\x04[Info] \x05Lluvia de Fuego \x03+ \x05Robo de armas (pasivo)");
        }
    }
    else
    {
        // TANK NORMAL (ROJO)
        g_bIsThief[client] = false;
        //SetEntityRenderColor(client, 255, 0, 0, 255);
        
        //PrintToChatAll("\x04[Tank] \x03¡Apareció un Tank Normal!");
        
        if (g_bVersusMode)
        {
            PrintToChat(client, "\x04[Powers] \x03Escribe \x05!power \x03para abrir el menú");
            PrintToChat(client, "\x04[Info] \x05Lluvia de Rocas \x03+ \x05Teletransporte");
        }
    }
    return Plugin_Stop;
}

// ============================================================================
// SISTEMA DE MENÚ PERSISTENTE
// ============================================================================
public Action Command_PowerMenu(int client, int args)
{
    if (!g_bPluginEnabled)
    {
        PrintToChat(client, "\x04[Tank] \x03Plugin deshabilitado");
        return Plugin_Handled;
    }
    
    if (!g_bVersusMode)
    {
        PrintToChat(client, "\x04[Tank] \x03El menú solo está disponible en modo Versus");
        PrintToChat(client, "\x04[Info] \x03Usa \x05sm_cvar l4d2_versus_mode 1 \x03para habilitar");
        return Plugin_Handled;
    }
    
    if (!IsTank(client))
    {
        PrintToChat(client, "\x04[Tank] \x03Solo los Tanks pueden usar este menú");
        return Plugin_Handled;
    }
    
    ShowPowerMenu(client);
    return Plugin_Handled;
}

void ShowPowerMenu(int client)
{
    if (!IsTank(client)) return;
    
    float currentTime = GetGameTime();
    
    Menu menu = new Menu(MenuHandler_Powers, MENU_ACTIONS_ALL);
    menu.SetTitle("═══ TANK POWERS ═══\n%s\n ", g_bIsThief[client] ? "Thief Fire Tank" : "Tank Normal");
    
    char item[128];
    
    // Opción 1: Lluvia de Rocas
    float cdRock = g_fRockRainCD - (currentTime - g_fLastRockRain[client]);
    if (cdRock > 0.0)
    {
        Format(item, sizeof(item), "🔥 Lluvia %s [CD: %.0fs]", g_bIsThief[client] ? "de Fuego" : "Normal", cdRock);
        menu.AddItem("rockrain_cd", item, ITEMDRAW_DISABLED);
    }
    else if (!g_cvEnableRockRain.BoolValue)
    {
        Format(item, sizeof(item), "🔥 Lluvia %s [DESHABILITADO]", g_bIsThief[client] ? "de Fuego" : "Normal");
        menu.AddItem("rockrain_disabled", item, ITEMDRAW_DISABLED);
    }
    else
    {
        Format(item, sizeof(item), "🔥 Lluvia %s [LISTO]", g_bIsThief[client] ? "de Fuego" : "Normal");
        menu.AddItem("rockrain", item);
    }
    
    // Opción 2: Teletransporte (solo Tank Normal)
    if (g_bIsThief[client])
    {
        menu.AddItem("tp_blocked", "🚫 Teletransporte [NO DISPONIBLE]", ITEMDRAW_DISABLED);
    }
    else
    {
        float cdTP = g_fTeleportCD - (currentTime - g_fLastTP[client]);
        if (cdTP > 0.0)
        {
            Format(item, sizeof(item), "🌀 Teletransporte [CD: %.0fs]", cdTP);
            menu.AddItem("tp_cd", item, ITEMDRAW_DISABLED);
        }
        else if (!g_cvEnableTP.BoolValue)
        {
            menu.AddItem("tp_disabled", "🌀 Teletransporte [DESHABILITADO]", ITEMDRAW_DISABLED);
        }
        else if (CountAliveTanks() < 2)
        {
            menu.AddItem("tp_notanks", "🌀 Teletransporte [MIN 2 TANKS]", ITEMDRAW_DISABLED);
        }
        else
        {
            menu.AddItem("tp", "🌀 Teletransporte [LISTO]");
        }
    }
    
    // Opción 3: Info Pasivo Thief
    if (g_bIsThief[client])
    {
        menu.AddItem("", "━━━━━━━━━━━━━━━━", ITEMDRAW_DISABLED);
        menu.AddItem("", "💀 Pasivo: Robo de armas", ITEMDRAW_DISABLED);
        menu.AddItem("", "🔥 Rocas queman supervivientes", ITEMDRAW_DISABLED);
    }
    
    menu.AddItem("", "━━━━━━━━━━━━━━━━", ITEMDRAW_DISABLED);
    menu.AddItem("close", "❌ Cerrar Menú");
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    g_bMenuOpen[client] = true;
    g_hPowerMenu[client] = menu;
}

public int MenuHandler_Powers(Menu menu, MenuAction action, int client, int param)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param, info, sizeof(info));
            
            if (StrEqual(info, "rockrain"))
            {
                PrepareRockRain(client, g_bIsThief[client]);
                g_fLastRockRain[client] = GetGameTime();
                PrintToChat(client, "\x04[Power] \x05¡Lluvia de %s activada!", g_bIsThief[client] ? "FUEGO" : "Rocas");
                
                // Reabrir menú automáticamente
                CreateTimer(0.1, Timer_ReopenMenu, GetClientUserId(client));
            }
            else if (StrEqual(info, "tp"))
            {
                TeleportOtherTanks(client);
                g_fLastTP[client] = GetGameTime();
                PrintToChat(client, "\x04[Power] \x05¡Grito de Manada activado!");
                
                CreateTimer(0.1, Timer_ReopenMenu, GetClientUserId(client));
            }
            else if (StrEqual(info, "close"))
            {
                g_bMenuOpen[client] = false;
                PrintToChat(client, "\x04[Tank] \x03Menú cerrado. Usa \x05!power \x03para reabrir");
            }
            else
            {
                // Cualquier opción deshabilitada, reabrir menú
                CreateTimer(0.1, Timer_ReopenMenu, GetClientUserId(client));
            }
        }
        
        case MenuAction_Cancel:
        {
            if (param == MenuCancel_Exit || param == MenuCancel_ExitBack)
            {
                g_bMenuOpen[client] = false;
            }
        }
        
        case MenuAction_End:
        {
            if (g_hPowerMenu[client] == menu)
            {
                g_hPowerMenu[client] = null;
            }
        }
    }
    
    return 0;
}

public Action Timer_ReopenMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsTank(client))
    {
        ShowPowerMenu(client);
    }
    return Plugin_Stop;
}

void CloseMenuIfOpen(int client)
{
    if (g_bMenuOpen[client])
    {
        g_bMenuOpen[client] = false;
        if (g_hPowerMenu[client] != null)
        {
            CancelMenu(g_hPowerMenu[client]);
            g_hPowerMenu[client] = null;
        }
    }
}

// ============================================================================
// GESTOR DE ABILIDADES (MODO AUTOMATICO - COOP)
// ============================================================================
public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPluginEnabled) return Plugin_Continue;
    if (g_bVersusMode) return Plugin_Continue;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || GetClientTeam(client) != 3) return Plugin_Continue;
    if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK) return Plugin_Continue;
    if (g_bInCooldown[client]) return Plugin_Continue;

    char ability[32];
    event.GetString("ability", ability, sizeof(ability));
    
    if (StrEqual(ability, "ability_throw", true))
    {
        bool triggered = false;

        if (g_cvEnableRockRain.BoolValue && GetRandomFloat(0.0, 100.0) < g_fChanceRock)
        {
            PrepareRockRain(client, g_bIsThief[client]); 
            triggered = true;
        }

        if (!g_bIsThief[client] && g_cvEnableTP.BoolValue && GetRandomFloat(0.0, 100.0) < g_fChanceTP)
        {
            if (CountAliveTanks() >= 2)
            {
                TeleportOtherTanks(client);
                triggered = true;
            }
        }

        if (triggered)
        {
            g_bInCooldown[client] = true;
            CreateTimer(g_fCooldown, Timer_ResetCooldown, GetClientUserId(client));
        }
    }
    return Plugin_Continue;
}

// ============================================================================
// PODER: THIEF TANK (GOLPE, ROBO Y FUEGO EN ROCAS)
// ============================================================================
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnableThiefPower.BoolValue) return;
    
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsValidClient(attacker) && IsValidClient(victim) && g_bIsThief[attacker])
    {
        if (GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
        {
            float vAngles[3], vVelocity[3];
            GetClientEyeAngles(attacker, vAngles);
            GetAngleVectors(vAngles, vVelocity, NULL_VECTOR, NULL_VECTOR);
            ScaleVector(vVelocity, 450.0); 
            vVelocity[2] = 350.0; 
            TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vVelocity);

            DropItemsPhysically(victim);
            PrintToChat(victim, "\x04[Thief Tank] \x05¡Te despojó de tus armas!");
        }
    }
}

public Action Hook_SurvivorTakeDamage(int victim, int &attacker, int &inflictor, 
    float &damage, int &damagetype)
{
    if (!g_cvEnableThiefPower.BoolValue) return Plugin_Continue;
    if (!IsValidClient(victim) || GetClientTeam(victim) != 2) return Plugin_Continue;
    if (!IsValidClient(attacker) || !g_bIsThief[attacker]) return Plugin_Continue;
    
    if (IsValidEntity(inflictor))
    {
        char classname[64];
        GetEdictClassname(inflictor, classname, sizeof(classname));
        
        if (StrEqual(classname, "tank_rock"))
        {
            IgniteEntity(victim, 5.0);
            PrintToChat(victim, "\x04[Thief Tank] \x05¡Roca de FUEGO!");
        }
    }
    
    return Plugin_Continue;
}

void DropItemsPhysically(int client)
{
    float vPos[3], vForce[3], vAngVel[3];
    GetClientAbsOrigin(client, vPos);
    vPos[2] += 35.0;

    for (int i = 0; i < 5; i++)
    {
        int weapon = GetPlayerWeaponSlot(client, i);
        if (weapon != -1 && IsValidEntity(weapon))
        {
            SDKHooks_DropWeapon(client, weapon);
            vForce[0] = GetRandomFloat(-200.0, 200.0);
            vForce[1] = GetRandomFloat(-200.0, 200.0);
            vForce[2] = GetRandomFloat(300.0, 450.0);
            TeleportEntity(weapon, vPos, NULL_VECTOR, vForce);

            vAngVel[0] = GetRandomFloat(-400.0, 400.0);
            vAngVel[1] = GetRandomFloat(-400.0, 400.0);
            vAngVel[2] = GetRandomFloat(-400.0, 400.0);
            SetEntPropVector(weapon, Prop_Data, "m_vecAngularVelocity", vAngVel);
        }
    }
}

// ============================================================================
// PODER: LLUVIA DE ROCAS (CON FUEGO SI ES THIEF)
// ============================================================================
void PrepareRockRain(int client, bool isFire)
{
    int count = GetRandomInt(g_iMinRocks, g_iMaxRocks);
    
    PrintCenterTextAll(isFire ? "⚠ METEORITOS DE FUEGO ⚠" : "⚠ LLUVIA DE METEORITOS ⚠");
    EmitSoundToAll("weapons/hegrenade/explode3.wav", client);

    DataPack pack;
    CreateDataTimer(1.5, Timer_StartMultiRock, pack);
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(count);
    pack.WriteCell(isFire ? 1 : 0);
}

public Action Timer_StartMultiRock(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int count = pack.ReadCell();
    bool isFire = pack.ReadCell() == 1;

    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        ExecuteMultiRock(client, count, isFire);
    }
    return Plugin_Stop;
}

void ExecuteMultiRock(int client, int count, bool isFire)
{
    g_bTankImmune[client] = true;
    SDKHook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage);
    
    SetEntProp(client, Prop_Send, "m_iGlowType", 3);
    SetEntProp(client, Prop_Send, "m_glowColorOverride", isFire ? 16711680 : 25600);

    if (count > 5)
    {
        g_bTankFrozen[client] = true;
        g_bTankRockImmune[client] = true;
        SetEntityMoveType(client, MOVETYPE_NONE);
        SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);
    }

    float eyePos[3];
    GetClientEyePosition(client, eyePos);
    LaunchMultipleRocks(client, eyePos, count);

    float duration = count > 5 ? (2.5 + ((count - 5) * 0.3)) : 2.5;

    CreateTimer(duration + 0.5, Timer_RemoveGlow, GetClientUserId(client));
    g_hImmunityTimer[client] = CreateTimer(duration, Timer_RemoveImmunity, GetClientUserId(client));

    if (count > 5)
    {
        g_hFreezeTimer[client] = CreateTimer(duration, Timer_UnfreezeTank, GetClientUserId(client));
        g_hRockImmuneTimer[client] = CreateTimer(duration + 1.0, Timer_RemoveRockImmunity, GetClientUserId(client));
    }
}

// ============================================================================
// LÓGICA DE LANZAMIENTO AVANZADA
// ============================================================================
void LaunchMultipleRocks(int client, float eyePos[3], int rockCount)
{
    int survivors[MAXPLAYERS + 1];
    int survivorCount = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
            survivors[survivorCount++] = i;
    
    if (survivorCount == 0) return;
    char damageStr[32]; IntToString(RoundToNearest(g_fDamage), damageStr, sizeof(damageStr));
    float tankAngles[3]; GetClientEyeAngles(client, tankAngles);
    
    for (int rock = 0; rock < rockCount; rock++)
    {
        float delay = rock < 5 ? (0.1 * rock) : (0.5 + (0.15 * (rock - 5)));
        int ent = CreateEntityByName("env_rock_launcher");
        if (!IsValidEntity(ent)) continue;
        DispatchKeyValue(ent, "rockdamageoverride", damageStr);

        float launchPos[3]; int targetEntity; int dummyRef = 0;

        if (rock < 5)
        {
            DispatchSpawn(ent);
            int target = survivors[GetRandomInt(0, survivorCount - 1)];
            targetEntity = target;
            float direction[3]; GetDirectionalVector(rock, tankAngles, direction);
            launchPos[0] = eyePos[0] + (direction[0] * 300.0);
            launchPos[1] = eyePos[1] + (direction[1] * 300.0);
            launchPos[2] = eyePos[2] + (direction[2] * 300.0);
            TeleportEntity(ent, launchPos, NULL_VECTOR, NULL_VECTOR);
        }
        else
        {
            int targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            float survivorPos[3]; GetClientAbsOrigin(targetSurvivor, survivorPos);
            float progressRatio = float(rock - 5) / float(rockCount - 5 > 0 ? rockCount - 5 : 1);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6));
            float radius = GetRandomFloat(20.0, maxRadius);
            float angle = GetRandomFloat(0.0, 360.0);
            float targetX = survivorPos[0] + (Cosine(DegToRad(angle)) * radius);
            float targetY = survivorPos[1] + (Sine(DegToRad(angle)) * radius);
            float targetZ = survivorPos[2];

            float traceStart[3], traceEnd[3];
            traceStart[0] = targetX; traceStart[1] = targetY; traceStart[2] = targetZ + 10.0;
            traceEnd[0] = targetX; traceEnd[1] = targetY; traceEnd[2] = targetZ + 1200.0;
            Handle trace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_WorldOnly);
            float spawnHeightZ = TR_DidHit(trace) ? (TR_GetEndPosition(traceEnd, trace), traceEnd[2] - 80.0) : (targetZ + 800.0 + (float(rock - 5) * 40.0));
            delete trace;

            launchPos[0] = targetX; launchPos[1] = targetY; launchPos[2] = spawnHeightZ;
            int dummyTarget = CreateEntityByName("info_target");
            float groundPos[3]; groundPos[0] = targetX; groundPos[1] = targetY; groundPos[2] = targetZ;
            TeleportEntity(dummyTarget, groundPos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(dummyTarget);
            targetEntity = dummyTarget; dummyRef = EntIndexToEntRef(dummyTarget);

            float vectorDir[3], aimAngles[3];
            SubtractVectors(groundPos, launchPos, vectorDir);
            GetVectorAngles(vectorDir, aimAngles);
            DispatchSpawn(ent);
            TeleportEntity(ent, launchPos, aimAngles, NULL_VECTOR);
        }

        SetVariantEntity(targetEntity);
        AcceptEntityInput(ent, "SetTarget");
        DataPack p; CreateDataTimer(delay, Timer_LaunchRock, p);
        p.WriteCell(EntIndexToEntRef(ent));
        p.WriteCell(rock < 5 ? GetClientUserId(targetEntity) : 0);
        p.WriteCell(dummyRef);
    }
}

public Action Timer_LaunchRock(Handle timer, DataPack pack)
{
    pack.Reset();
    int entRef   = pack.ReadCell();
    int userid   = pack.ReadCell();
    int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef);

    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        if (userid != 0) 
        {
            int target = GetClientOfUserId(userid);
            if (IsValidClient(target) && IsPlayerAlive(target)) 
            { 
                SetVariantEntity(target); 
                AcceptEntityInput(ent, "SetTarget"); 
            }
        }
        AcceptEntityInput(ent, "LaunchRock");
        DataPack packRemove;
        CreateDataTimer(0.1, Timer_RemoveLauncher, packRemove);
        packRemove.WriteCell(entRef);
        packRemove.WriteCell(dummyRef);
    }
    return Plugin_Stop;
}

// ============================================================================
// SISTEMA DE TELETRANSPORTE MEJORADO (CON VALIDACIÓN ANTI-REFUGIO)
// ============================================================================
void TeleportOtherTanks(int client) 
{
    PrintToChatAll("\x04[Tank] \x03¡GRITO! \x05¡La manada se reúne!");
    
    float targetPos[3];
    int teleported = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client) continue;
        if (!IsTank(i)) continue;
        
        if (FindSafeTeleportSpot(client, targetPos)) 
        {
            TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR);
            PrintToChat(i, "\x04[Tank] \x05¡Has sido llamado!");
            teleported++;
        }
        else
        {
            PrintToChat(client, "\x04[Tank] \x03No se pudo encontrar posición segura para Tank #%d", i);
        }
    }
    
    if (teleported == 0)
    {
        PrintToChat(client, "\x04[Tank] \x03No se pudo teletransportar a ningún Tank (área no segura)");
    }
}

bool FindSafeTeleportSpot(int client, float targetPos[3])
{
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);
    
    for (int attempt = 0; attempt < 20; attempt++)
    {
        float angle = GetRandomFloat(0.0, 360.0);
        float radius = GetRandomFloat(200.0, 500.0);
        float testPos[3];
        
        testPos[0] = tankPos[0] + (Cosine(DegToRad(angle)) * radius);
        testPos[1] = tankPos[1] + (Sine(DegToRad(angle)) * radius);
        testPos[2] = tankPos[2];

        // Trace desde arriba hacia abajo para encontrar suelo
        float traceStart[3], traceEnd[3];
        traceStart[0] = testPos[0];
        traceStart[1] = testPos[1];
        traceStart[2] = testPos[2] + 300.0;
        
        traceEnd[0] = testPos[0];
        traceEnd[1] = testPos[1];
        traceEnd[2] = testPos[2] - 500.0;

        Handle trace = TR_TraceHullFilterEx(
            traceStart, 
            traceEnd, 
            view_as<float>({-16.0, -16.0, 0.0}), 
            view_as<float>({16.0, 16.0, 72.0}), 
            MASK_PLAYERSOLID, 
            TraceFilter_IgnoreTank, 
            client
        );
        
        if (TR_DidHit(trace))
        {
            TR_GetEndPosition(targetPos, trace);
            targetPos[2] += 10.0; // Elevar un poco del suelo
            
            delete trace;
            
            // Validaciones adicionales
            if (!IsPositionValid(targetPos, tankPos))
            {
                continue;
            }
            
            // Verificar que no esté en zona de refugio
            if (IsInsideSaferoom(targetPos))
            {
                continue;
            }
            
            // Verificar que no esté dentro de una pared
            if (IsInsideWall(targetPos))
            {
                continue;
            }
            
            return true;
        }
        
        delete trace;
    }
    
    return false;
}

bool IsPositionValid(float pos[3], float originPos[3])
{
    // Verificar distancia mínima/máxima
    float distance = GetVectorDistance(pos, originPos);
    if (distance < 150.0 || distance > 600.0)
    {
        return false;
    }
    
    // Verificar que no esté demasiado alto o bajo
    float heightDiff = FloatAbs(pos[2] - originPos[2]);
    if (heightDiff > 300.0)
    {
        return false;
    }
    
    return true;
}

bool IsInsideSaferoom(float pos[3])
{
    // Buscar entidades de checkpoint cercanas
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1)
    {
        char targetname[64];
        GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
        
        if (StrContains(targetname, "checkpoint", false) != -1 || 
            StrContains(targetname, "saferoom", false) != -1)
        {
            float entPos[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
            
            if (GetVectorDistance(pos, entPos) < 300.0)
            {
                return true;
            }
        }
    }
    
    // Verificar por info_survivor_position (marca spawn de supervivientes)
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1)
    {
        float entPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
        
        if (GetVectorDistance(pos, entPos) < 400.0)
        {
            return true;
        }
    }
    
    return false;
}

bool IsInsideWall(float pos[3])
{
    float mins[3] = {-16.0, -16.0, 0.0};
    float maxs[3] = {16.0, 16.0, 72.0};
    
    Handle trace = TR_TraceHullFilterEx(
        pos, 
        pos, 
        mins, 
        maxs, 
        MASK_PLAYERSOLID, 
        TraceFilter_WorldOnly
    );
    
    bool stuck = TR_DidHit(trace);
    delete trace;
    
    return stuck;
}

// ============================================================================
// HOOKS Y TIMERS
// ============================================================================
public Action Hook_TankTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) 
{ 
    if (g_bTankImmune[victim]) return Plugin_Handled; 
    return Plugin_Continue; 
}

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

public Action Timer_ResetCooldown(Handle timer, any userid) 
{ 
    int c = GetClientOfUserId(userid); 
    if (c > 0 && c <= MaxClients) g_bInCooldown[c] = false; 
    return Plugin_Stop; 
}

public Action Timer_RemoveGlow(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client)) 
    { 
        if (g_bIsThief[client])
        {
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
        }
        else
        {
            SetEntProp(client, Prop_Send, "m_iGlowType", 0);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
        }
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

public Action Timer_RemoveLauncher(Handle timer, DataPack pack) 
{
    pack.Reset();
    int entRef = pack.ReadCell();
    int dummyRef = pack.ReadCell();
    
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        AcceptEntityInput(ent, "Kill");
    }
    
    if (dummyRef != 0)
    {
        int dummy = EntRefToEntIndex(dummyRef);
        if (dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy))
        {
            AcceptEntityInput(dummy, "Kill");
        }
    }
    
    return Plugin_Stop;
}

// ============================================================================
// HELPERS
// ============================================================================
void GetDirectionalVector(int rockIndex, float tankAngles[3], float direction[3])
{
    float yaw = tankAngles[1];
    float pitch = tankAngles[0];
    
    switch (rockIndex)
    {
        case 0: { direction[0]=Cosine(DegToRad(yaw)); direction[1]=Sine(DegToRad(yaw)); direction[2]=-Sine(DegToRad(pitch)); }
        case 1: { direction[0]=Cosine(DegToRad(yaw+90.0)); direction[1]=Sine(DegToRad(yaw+90.0)); direction[2]=0.0; }
        case 2: { direction[0]=Cosine(DegToRad(yaw-90.0)); direction[1]=Sine(DegToRad(yaw-90.0)); direction[2]=0.0; }
        case 3: { direction[0]=Cosine(DegToRad(yaw+180.0)); direction[1]=Sine(DegToRad(yaw+180.0)); direction[2]=0.0; }
        case 4: { direction[0]=Cosine(DegToRad(yaw)); direction[1]=Sine(DegToRad(yaw)); direction[2]=1.0; }
    }
    
    NormalizeVector(direction, direction);
}

public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data)
{
    return (entity != data);
}

public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data)
{
    return entity == 0;
}

// ============================================================================
// EVENTOS DE LIMPIEZA
// ============================================================================
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    CloseMenuIfOpen(client);
    CleanUpTank(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        CloseMenuIfOpen(i);
        CleanUpTank(i);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        CloseMenuIfOpen(i);
    }
}

void CleanUpTank(int client) 
{
    if (client < 1 || client > MaxClients) return;
    
    g_bIsThief[client] = false;
    g_bInCooldown[client] = false;
    g_bTankImmune[client] = false;
    g_bTankFrozen[client] = false;
    g_bTankRockImmune[client] = false;
    
    g_fLastRockRain[client] = 0.0;
    g_fLastTP[client] = 0.0;
    
    if (g_hImmunityTimer[client] != null)
    {
        KillTimer(g_hImmunityTimer[client]);
        g_hImmunityTimer[client] = null;
    }
    if (g_hFreezeTimer[client] != null)
    {
        KillTimer(g_hFreezeTimer[client]);
        g_hFreezeTimer[client] = null;
    }
    if (g_hRockImmuneTimer[client] != null)
    {
        KillTimer(g_hRockImmuneTimer[client]);
        g_hRockImmuneTimer[client] = null;
    }
    
    if (IsValidClient(client))
    {
        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntProp(client, Prop_Send, "m_iGlowType", 0);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}