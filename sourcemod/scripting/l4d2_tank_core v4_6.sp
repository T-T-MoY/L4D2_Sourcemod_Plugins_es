#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>

#define PLUGIN_VERSION "5.4.0" // Versión con Rayo TP y Modo Sigiloso Experto
#define ZOMBIECLASS_TANK 8

// --- ConVars ---
ConVar g_cvEnable, g_cvChanceRock, g_cvChanceTP, g_cvChanceThief, g_cvDamage, g_cvMinRocks, g_cvMaxRocks, g_cvCooldown;
ConVar g_cvEnableRockRain, g_cvEnableTP, g_cvEnableThiefPower, g_cvVersusMode;
ConVar g_cvRockRainCD, g_cvTeleportCD;
ConVar g_cvHideMsgExpert; // NUEVA VAR: Ocultar mensajes en Experto

// --- ConVar de dificultad del juego (nativa de L4D2) ---
ConVar g_cvDifficulty;

// --- Estado global ---
bool g_bPluginEnabled;
bool g_bVersusMode;
bool g_bHideMsgExpert;
float g_fChanceRock, g_fChanceTP, g_fChanceThief, g_fDamage, g_fCooldown;
float g_fRockRainCD, g_fTeleportCD;
int g_iMinRocks, g_iMaxRocks;

// --- Estado por jugador ---
bool g_bInCooldown[MAXPLAYERS + 1];
bool g_bIsThief[MAXPLAYERS + 1];
bool g_bTankImmune[MAXPLAYERS + 1];
bool g_bTankFrozen[MAXPLAYERS + 1];
bool g_bTankRockImmune[MAXPLAYERS + 1];

// --- Timers ---
Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];
Handle g_hDeathVisualTimer[MAXPLAYERS + 1];

// --- Cooldowns independientes ---
float g_fLastRockRain[MAXPLAYERS + 1];
float g_fLastTP[MAXPLAYERS + 1];

// --- Menú persistente ---
Handle g_hPowerMenu[MAXPLAYERS + 1];
bool g_bMenuOpen[MAXPLAYERS + 1];

// --- Modelos para el efecto del Rayo ---
int g_iLightningModel;
int g_iHaloModel;

// ============================================================================
// CONSTANTES DE DAÑO POR DIFICULTAD
// ============================================================================
#define EXPERT_THIEF_MAX_DAMAGE     50.0   // Daño máximo del Thief Tank en Experto
#define DIFFICULTY_EXPERT           "expert"

public Plugin myinfo = 
{
    name = "Tank Abilities Ultimate (V5.4 Lightning Edition)",
    author = "[T-T]MoY & Gemini AI",
    description = "TP con Rayo, Meteoros con Delay, Thief Tank Dinámico y Mensajes Ocultos",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart()
{
    g_cvEnable      = CreateConVar("l4d2_tank_skills_enable",    "1", "Habilitar habilidades", FCVAR_NOTIFY);
    g_cvChanceRock  = CreateConVar("l4d2_tank_rock_chance",      "80", "Probabilidad Lluvia de Rocas (0-100)");
    g_cvChanceTP    = CreateConVar("l4d2_tank_tp_chance",        "80", "Probabilidad Grito de Manada (0-100)");
    g_cvChanceThief = CreateConVar("l4d2_tank_thief_chance",     "20", "Probabilidad de ser Thief Tank Blanco (0-100)");
    g_cvDamage      = CreateConVar("l4d2_tank_rock_damage",      "6",  "Daño rocas meteorito");
    g_cvMinRocks    = CreateConVar("l4d2_tank_min_rocks",        "15", "Mínimo de rocas");
    g_cvMaxRocks    = CreateConVar("l4d2_tank_max_rocks",        "20", "Máximo de rocas");
    g_cvCooldown    = CreateConVar("l4d2_tank_skill_cooldown",   "30", "Tiempo de espera global");

    g_cvEnableRockRain   = CreateConVar("l4d2_enable_rockrain",   "1", "0=OFF 1=ON Lluvia de Rocas");
    g_cvEnableTP         = CreateConVar("l4d2_enable_teleport",   "1", "0=OFF 1=ON Teletransporte");
    g_cvEnableThiefPower = CreateConVar("l4d2_enable_thiefpower", "1", "0=OFF 1=ON Poderes Thief (robo+fuego)");
    g_cvVersusMode       = CreateConVar("l4d2_versus_mode",       "0", "0=Auto (Coop) 1=Manual (Versus con menú)");
    
    g_cvRockRainCD  = CreateConVar("l4d2_rockrain_cooldown",  "30", "Cooldown Lluvia de Rocas (segundos)");
    g_cvTeleportCD  = CreateConVar("l4d2_teleport_cooldown",  "40", "Cooldown Teletransporte (segundos)");

    g_cvHideMsgExpert = CreateConVar("l4d2_tank_hide_msg_expert", "1", "1=Oculta mensajes de pantalla en Experto, 0=Muestra siempre");

    g_cvDifficulty = FindConVar("z_difficulty");

    AutoExecConfig(true, "l4d2_tank_skills_ultimate");
    LoadConVarValues();

    HookConVarChange(g_cvEnable, OnConVarChanged);
    HookConVarChange(g_cvChanceRock, OnConVarChanged);
    HookConVarChange(g_cvChanceTP, OnConVarChanged);
    HookConVarChange(g_cvChanceThief, OnConVarChanged);
    HookConVarChange(g_cvDamage, OnConVarChanged);
    HookConVarChange(g_cvMinRocks, OnConVarChanged);
    HookConVarChange(g_cvMaxRocks, OnConVarChanged);
    HookConVarChange(g_cvCooldown, OnConVarChanged);
    HookConVarChange(g_cvEnableRockRain, OnConVarChanged);
    HookConVarChange(g_cvEnableTP, OnConVarChanged);
    HookConVarChange(g_cvEnableThiefPower, OnConVarChanged);
    HookConVarChange(g_cvVersusMode, OnConVarChanged);
    HookConVarChange(g_cvRockRainCD, OnConVarChanged);
    HookConVarChange(g_cvTeleportCD, OnConVarChanged);
    HookConVarChange(g_cvHideMsgExpert, OnConVarChanged);

    RegConsoleCmd("sm_power", Command_PowerMenu, "Abrir menú de poderes Tank");
    RegConsoleCmd("sm_powers", Command_PowerMenu, "Abrir menú de poderes Tank");
    RegConsoleCmd("sm_tankmenu", Command_PowerMenu, "Abrir menú de poderes Tank");
    
    RegAdminCmd("sm_tankreload", Command_ReloadConfig, ADMFLAG_CONFIG, "Recargar configuración del plugin Tank");

    HookEvent("ability_use",  Event_AbilityUse);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt",  Event_PlayerHurt);
    HookEvent("round_start",  Event_RoundStart);
    HookEvent("round_end",    Event_RoundEnd);
}

// Cargar materiales del rayo al iniciar el mapa
public void OnMapStart()
{
    g_iLightningModel = PrecacheModel("materials/sprites/lghtning.vmt");
    g_iHaloModel = PrecacheModel("materials/sprites/halo01.vmt");
    PrecacheSound("ambient/energy/zap9.wav", true);
}

// ============================================================================
// HELPER: VERIFICAR SI LA DIFICULTAD ES EXPERTO Y SISTEMA DE MENSAJES
// ============================================================================
bool IsExpertDifficulty()
{
    if (g_cvDifficulty == null) return false;
    
    char diff[32];
    g_cvDifficulty.GetString(diff, sizeof(diff));
    
    return (StrEqual(diff, DIFFICULTY_EXPERT, false) || StrEqual(diff, "Impossible", false));
}

// Envoltorio para ocultar mensajes automáticamente si está en experto
void PrintMsgToAll(const char[] format, any ...)
{
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    
    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToChatAll("%s", buffer);
}

void PrintMsgToClient(int client, const char[] format, any ...)
{
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    
    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 3);
    PrintToChat(client, "%s", buffer);
}

void PrintCenterMsgToAll(const char[] format, any ...)
{
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    
    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintCenterTextAll("%s", buffer);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LoadConVarValues();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && CheckCommandAccess(i, "sm_tankreload", ADMFLAG_CONFIG))
        {
            char cvarName[64];
            convar.GetName(cvarName, sizeof(cvarName));
            PrintToChat(i, "\x04[Tank Config] \x03%s \x05cambiado: \x03%s → \x05%s", cvarName, oldValue, newValue);
        }
    }
}

void LoadConVarValues() 
{
    g_bPluginEnabled = g_cvEnable.BoolValue;
    g_bVersusMode    = g_cvVersusMode.BoolValue;
    g_bHideMsgExpert = g_cvHideMsgExpert.BoolValue;
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

public Action Command_ReloadConfig(int client, int args)
{
    LoadConVarValues();
    
    if (client > 0)
    {
        PrintToChat(client, "\x04[Tank Config] \x05Configuración recargada exitosamente");
        PrintToChat(client, "\x04[Estado] \x03Sigilo Experto: %s | Versus: %s", 
            g_bHideMsgExpert ? "ON" : "OFF",
            g_bVersusMode ? "ON" : "OFF");
    }
    
    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage,      Hook_SurvivorTakeDamage_Fire);
    SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_SurvivorTakeDamageAlive_Cap);
    
    g_fLastRockRain[client] = 0.0;
    g_fLastTP[client] = 0.0;
    g_bMenuOpen[client] = false;
    g_hPowerMenu[client] = null;
    g_hDeathVisualTimer[client] = null; 
}

public void OnClientDisconnect(int client)
{
    CloseMenuIfOpen(client);
    CleanUpTankLogic(client);
    ResetTankVisuals(client);
}

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
// SISTEMA DE SPAWN Y COLOR (THIEF TANK DINÁMICO)
// ============================================================================
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client))
    {
        if (GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
        {
            CreateTimer(0.2, Timer_ApplyTankType, GetClientUserId(client));
        }
        else
        {
            ResetTankVisuals(client);
        }
    }
}

public Action Timer_ApplyTankType(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;

    bool canBeThief = g_cvEnableThiefPower.BoolValue && (g_fChanceThief > 0.0);
    
    if (canBeThief && GetRandomFloat(0.0, 100.0) < g_fChanceThief)
    {
        g_bIsThief[client] = true;
        
        if (IsExpertDifficulty())
        {
            SetEntityRenderColor(client, 0, 0, 0, 255);
            SetEntProp(client, Prop_Send, "m_iGlowType", 0);
            
            PrintMsgToAll("\x04[Tank] \x05¡Apareció un Thief Fire Tank (Negro)!");
            PrintMsgToAll("\x04[Tank] \x03[Experto] \x05El Thief Tank NO incapacita de un golpe");
        }
        else
        {
            SetEntityRenderColor(client, 255, 255, 255, 255);
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
            
            PrintMsgToAll("\x04[Tank] \x05¡Apareció un Thief Fire Tank (Blanco)!");
        }
        
        if (g_bVersusMode)
        {
            PrintMsgToClient(client, "\x04[Powers] \x03Escribe \x05!power \x03para abrir el menú");
        }
    }
    else
    {
        g_bIsThief[client] = false;
        PrintMsgToAll("\x04[Tank] \x03¡Apareció un Tank Normal!");
        
        if (g_bVersusMode)
        {
            PrintMsgToClient(client, "\x04[Powers] \x03Escribe \x05!power \x03para abrir el menú");
        }
    }
    return Plugin_Stop;
}

// ============================================================================
// SISTEMA DE MENÚ PERSISTENTE
// ============================================================================
public Action Command_PowerMenu(int client, int args)
{
    if (!g_bPluginEnabled) return Plugin_Handled;
    
    if (!g_bVersusMode)
    {
        PrintToChat(client, "\x04[Tank] \x03El menú solo está disponible en modo Versus");
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
    
    float cdRock = g_fRockRainCD - (currentTime - g_fLastRockRain[client]);
    if (cdRock > 0.0)
    {
        Format(item, sizeof(item), "Lluvia %s [CD: %.0fs]", g_bIsThief[client] ? "de Fuego" : "Normal", cdRock);
        menu.AddItem("rockrain_cd", item, ITEMDRAW_DISABLED);
    }
    else if (!g_cvEnableRockRain.BoolValue)
    {
        Format(item, sizeof(item), "Lluvia %s [DESHABILITADO]", g_bIsThief[client] ? "de Fuego" : "Normal");
        menu.AddItem("rockrain_disabled", item, ITEMDRAW_DISABLED);
    }
    else
    {
        Format(item, sizeof(item), "Lluvia %s [LISTO]", g_bIsThief[client] ? "de Fuego" : "Normal");
        menu.AddItem("rockrain", item);
    }
    
    if (g_bIsThief[client])
    {
        menu.AddItem("tp_blocked", "Teletransporte [NO DISPONIBLE]", ITEMDRAW_DISABLED);
    }
    else
    {
        float cdTP = g_fTeleportCD - (currentTime - g_fLastTP[client]);
        if (cdTP > 0.0)
        {
            Format(item, sizeof(item), "Teletransporte [CD: %.0fs]", cdTP);
            menu.AddItem("tp_cd", item, ITEMDRAW_DISABLED);
        }
        else if (!g_cvEnableTP.BoolValue)
        {
            menu.AddItem("tp_disabled", "Teletransporte [DESHABILITADO]", ITEMDRAW_DISABLED);
        }
        else if (CountAliveTanks() < 2)
        {
            menu.AddItem("tp_notanks", "Teletransporte [MIN 2 TANKS]", ITEMDRAW_DISABLED);
        }
        else
        {
            menu.AddItem("tp", "Teletransporte [LISTO]");
        }
    }
    
    if (g_bIsThief[client])
    {
        menu.AddItem("", "━━━━━━━━━━━━━━━━", ITEMDRAW_DISABLED);
        menu.AddItem("", "Pasivo: Robo de armas", ITEMDRAW_DISABLED);
        menu.AddItem("", "Rocas queman supervivientes", ITEMDRAW_DISABLED);
    }
    
    menu.AddItem("", "━━━━━━━━━━━━━━━━", ITEMDRAW_DISABLED);
    menu.AddItem("close", "Cerrar Menú");
    
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
                CreateTimer(0.1, Timer_ReopenMenu, GetClientUserId(client));
            }
            else if (StrEqual(info, "tp"))
            {
                TeleportOtherTanks(client);
                g_fLastTP[client] = GetGameTime();
                CreateTimer(0.1, Timer_ReopenMenu, GetClientUserId(client));
            }
            else if (StrEqual(info, "close"))
            {
                g_bMenuOpen[client] = false;
            }
            else
            {
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
            if (g_hPowerMenu[client] == menu) g_hPowerMenu[client] = null;
            delete menu;
        }
    }
    return 0;
}

public Action Timer_ReopenMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsTank(client)) ShowPowerMenu(client);
    return Plugin_Stop;
}

void CloseMenuIfOpen(int client)
{
    if (g_bMenuOpen[client])
    {
        g_bMenuOpen[client] = false;
        if (g_hPowerMenu[client] != null) CancelMenu(g_hPowerMenu[client]);
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
// PODER: THIEF TANK
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
            PrintMsgToClient(victim, "\x04[Thief Tank] \x05¡Te despojó de tus armas!");
        }
    }
}

public Action Hook_SurvivorTakeDamage_Fire(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
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
            PrintMsgToClient(victim, "\x04[Thief Tank] \x05¡Roca de FUEGO!");
        }
    }
    return Plugin_Continue;
}

public Action Hook_SurvivorTakeDamageAlive_Cap(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!IsExpertDifficulty()) return Plugin_Continue;
    if (!IsValidClient(victim) || GetClientTeam(victim) != 2 || !IsPlayerAlive(victim)) return Plugin_Continue;
    if (!IsValidClient(attacker) || !g_bIsThief[attacker]) return Plugin_Continue;
    if (!(damagetype & DMG_CLUB)) return Plugin_Continue;

    int currentHP = GetClientHealth(victim);
    if (damage < float(currentHP)) return Plugin_Continue;

    float cappedDamage = float(currentHP) - 1.0;
    if (cappedDamage > EXPERT_THIEF_MAX_DAMAGE) cappedDamage = EXPERT_THIEF_MAX_DAMAGE;
    if (cappedDamage < 1.0) cappedDamage = 1.0;

    damage = cappedDamage;
    return Plugin_Changed;
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
// PODER: LLUVIA DE ROCAS (CON LÓGICA Y ÁREA CORREGIDAS)
// ============================================================================
void PrepareRockRain(int client, bool isFire)
{
    int count = GetRandomInt(g_iMinRocks, g_iMaxRocks);
    
    PrintCenterMsgToAll(isFire ? "⚠ METEORITOS DE FUEGO ⚠" : "⚠ LLUVIA DE METEORITOS ⚠");
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

void LaunchMultipleRocks(int client, float eyePos[3], int rockCount)
{
    int survivors[MAXPLAYERS + 1];
    int survivorCount = 0;
    
    float tankPos[3];
    GetClientAbsOrigin(client, tankPos);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
        {
            float survivorPos[3];
            GetClientAbsOrigin(i, survivorPos);
            
            if (GetVectorDistance(tankPos, survivorPos) > 2500.0) continue;
            if (IsInsideSaferoom(survivorPos)) continue;

            survivors[survivorCount++] = i;
        }
    }
    
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
            float survivorPosTarget[3]; GetClientAbsOrigin(targetSurvivor, survivorPosTarget);
            float progressRatio = float(rock - 5) / float(rockCount - 5 > 0 ? rockCount - 5 : 1);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6));
            float radius = GetRandomFloat(20.0, maxRadius);
            float angle = GetRandomFloat(0.0, 360.0);
            float targetX = survivorPosTarget[0] + (Cosine(DegToRad(angle)) * radius);
            float targetY = survivorPosTarget[1] + (Sine(DegToRad(angle)) * radius);
            float targetZ = survivorPosTarget[2];

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
// SISTEMA DE TELETRANSPORTE (CON EFECTO DE RAYO ELÉCTRICO)
// ============================================================================
void TeleportOtherTanks(int client) 
{
    PrintMsgToAll("\x04[Tank] \x03¡GRITO! \x05¡La manada se reúne!");
    
    float targetPos[3];
    int teleported = 0;
    
    // Mostramos el efecto de rayo donde está el Tank que gritó
    float callerPos[3];
    GetClientAbsOrigin(client, callerPos);
    ShowLightningEffect(callerPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client) continue;
        if (!IsTank(i)) continue;
        
        if (FindSafeTeleportSpot(client, targetPos)) 
        {
            // Efecto en la ubicación de ORIGEN (antes de ser teletransportado)
            float originPos[3];
            GetClientAbsOrigin(i, originPos);
            ShowLightningEffect(originPos);
            
            TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR);
            
            // Efecto en la ubicación de DESTINO (al lado del Tank)
            ShowLightningEffect(targetPos);
            
            PrintMsgToClient(i, "\x04[Tank] \x05¡Has sido llamado!");
            teleported++;
        }
        else
        {
            PrintMsgToClient(client, "\x04[Tank] \x03No se pudo encontrar posición segura para Tank #%d", i);
        }
    }
    
    if (teleported == 0)
    {
        PrintMsgToClient(client, "\x04[Tank] \x03No se pudo teletransportar a ningún Tank (área no segura)");
    }
}

// Función que genera el rayo, la luz y las chispas
void ShowLightningEffect(float pos[3])
{
    float topPos[3];
    topPos[0] = pos[0];
    topPos[1] = pos[1];
    topPos[2] = pos[2] + 800.0; // El rayo viene desde arriba

    // Rayo eléctrico principal
    TE_SetupBeamPoints(topPos, pos, g_iLightningModel, g_iHaloModel, 0, 0, 0.5, 10.0, 10.0, 0, 10.0, {150, 200, 255, 255}, 10);
    TE_SendToAll();

    // Chispas al golpear el suelo o el Tank
    TE_SetupSparks(pos, NULL_VECTOR, 100, 50);
    TE_SendToAll();

    // Efecto de sonido del rayo
    EmitSoundToAll("ambient/energy/zap9.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
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
            targetPos[2] += 10.0;
            
            delete trace;
            
            if (!IsPositionValid(targetPos, tankPos)) continue;
            if (IsInsideSaferoom(targetPos)) continue;
            if (IsInsideWall(targetPos)) continue;
            
            return true;
        }
        
        delete trace;
    }
    
    return false;
}

bool IsPositionValid(float pos[3], float originPos[3])
{
    float distance = GetVectorDistance(pos, originPos);
    if (distance < 150.0 || distance > 600.0) return false;
    
    float heightDiff = FloatAbs(pos[2] - originPos[2]);
    if (heightDiff > 300.0) return false;
    
    return true;
}

bool IsInsideSaferoom(float pos[3])
{
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
            
            if (GetVectorDistance(pos, entPos) < 300.0) return true;
        }
    }
    
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1)
    {
        float entPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
        
        if (GetVectorDistance(pos, entPos) < 400.0) return true;
    }
    
    return false;
}

bool IsInsideWall(float pos[3])
{
    float mins[3] = {-16.0, -16.0, 0.0};
    float maxs[3] = {16.0, 16.0, 72.0};
    
    Handle trace = TR_TraceHullFilterEx(
        pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilter_WorldOnly
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
            if (IsExpertDifficulty())
            {
                SetEntProp(client, Prop_Send, "m_iGlowType", 0);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
            }
            else
            {
                SetEntProp(client, Prop_Send, "m_iGlowType", 3);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
            }
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
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) AcceptEntityInput(ent, "Kill");
    
    if (dummyRef != 0)
    {
        int dummy = EntRefToEntIndex(dummyRef);
        if (dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy)) AcceptEntityInput(dummy, "Kill");
    }
    return Plugin_Stop;
}

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

public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data) { return (entity != data); }
public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data) { return entity == 0; }

// ============================================================================
// EVENTOS DE LIMPIEZA
// ============================================================================
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    CloseMenuIfOpen(client);
    CleanUpTankLogic(client);
    
    if (g_hDeathVisualTimer[client] != null) delete g_hDeathVisualTimer[client];
    g_hDeathVisualTimer[client] = CreateTimer(8.5, Timer_ResetVisuals, GetClientUserId(client));
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        CloseMenuIfOpen(i);
        CleanUpTankLogic(i);
        ResetTankVisuals(i); 
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++) CloseMenuIfOpen(i);
}

void CleanUpTankLogic(int client) 
{
    if (client < 1 || client > MaxClients) return;
    
    g_bIsThief[client] = false;
    g_bInCooldown[client] = false;
    g_bTankImmune[client] = false;
    g_bTankFrozen[client] = false;
    g_bTankRockImmune[client] = false;
    
    g_fLastRockRain[client] = 0.0;
    g_fLastTP[client] = 0.0;
    
    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage);
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage);
    
    if (g_hImmunityTimer[client] != null) { delete g_hImmunityTimer[client]; g_hImmunityTimer[client] = null; }
    if (g_hFreezeTimer[client] != null) { delete g_hFreezeTimer[client]; g_hFreezeTimer[client] = null; }
    if (g_hRockImmuneTimer[client] != null) { delete g_hRockImmuneTimer[client]; g_hRockImmuneTimer[client] = null; }
}

void ResetTankVisuals(int client)
{
    if (g_hDeathVisualTimer[client] != null)
    {
        delete g_hDeathVisualTimer[client];
        g_hDeathVisualTimer[client] = null;
    }
    
    if (IsValidClient(client))
    {
        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntProp(client, Prop_Send, "m_iGlowType", 0);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}

public Action Timer_ResetVisuals(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    g_hDeathVisualTimer[client] = null;
    ResetTankVisuals(client);
    return Plugin_Stop;
}