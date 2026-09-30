#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_trace>

#pragma newdecls required

#define PLUGIN_VERSION "15.0.0"
#define ZOMBIECLASS_TANK 8
#define EXPERT_THIEF_MAX_DAMAGE 50.0   
#define DIFFICULTY_EXPERT "expert"

// IDs de Mutaciones
#define TANK_NONE 0
#define TANK_FIRE 1
#define TANK_ICE 2
#define TANK_SPITTER 3
#define TANK_WARP 4
#define TANK_COBALT 5
#define TANK_SPAWN 6
#define TANK_KING 7
#define TANK_THIEF 8
#define TANK_ROGUE 9

// ================= VARIABLES ORIGINALES Y GLOBALES =================
ConVar g_cvEnable, g_cvChanceRock, g_cvChanceTP, g_cvChanceThief, g_cvDamage, g_cvMinRocks, g_cvMaxRocks, g_cvCooldown;
ConVar g_cvEnableRockRain, g_cvEnableTP, g_cvEnableThiefPower, g_cvVersusMode;
ConVar g_cvRockRainCD, g_cvTeleportCD, g_cvHideMsgExpert, g_cvDifficulty;

ConVar g_cvChanceFire, g_cvChanceIce, g_cvChanceSpit, g_cvChanceWarp;
ConVar g_cvChanceCobalt, g_cvChanceSpawn, g_cvChanceKing, g_cvChanceRogue;
ConVar g_cvChaosMode, g_cvPowerFire, g_cvPowerIce, g_cvPowerSpit, g_cvPowerWarp, g_cvPowerCobalt, g_cvPowerSpawn;

bool g_bPluginEnabled, g_bVersusMode, g_bHideMsgExpert;
float g_fChanceRock, g_fChanceTP, g_fChanceThief, g_fDamage, g_fCooldown;
float g_fRockRainCD, g_fTeleportCD;
int g_iMinRocks, g_iMaxRocks;

int g_iLightningModel, g_iHaloModel;
Handle g_hFling = null;
Handle g_hVomit = null;
Handle g_hSpitBurst = null;

// ================= ESTADO DE JUGADOR =================
int g_iTankType[MAXPLAYERS + 1];
bool g_bInCooldown[MAXPLAYERS + 1];
bool g_bTankImmune[MAXPLAYERS + 1];
bool g_bTankFrozen[MAXPLAYERS + 1];
bool g_bTankRockImmune[MAXPLAYERS + 1];
float g_fLastRockRain[MAXPLAYERS + 1];
float g_fLastTP[MAXPLAYERS + 1];
float g_fNextWarp[MAXPLAYERS + 1];

Handle g_hImmunityTimer[MAXPLAYERS + 1];
Handle g_hFreezeTimer[MAXPLAYERS + 1];
Handle g_hRockImmuneTimer[MAXPLAYERS + 1];
Handle g_hDeathVisualTimer[MAXPLAYERS + 1];
Handle g_hPowerMenu[MAXPLAYERS + 1];
bool g_bMenuOpen[MAXPLAYERS + 1];

int g_iRockType[2048]; 

bool g_bForceSpawn = false;
int g_iForcedType = 0;

public Plugin myinfo = {
    name = "Tank Abilities Ultimate (King & Elementals)",
    author = "Moises",
    description = "Unificacion perfecta: GameData, Lluvia de Rocas y Elementos.",
    version = PLUGIN_VERSION
};

public void OnPluginStart() {
    LoadPluginGameData();

    // Variables Legacy de Tank Core
    g_cvEnable      = CreateConVar("l4d2_tank_skills_enable",    "1", "Habilitar habilidades");

    g_cvChanceRock  = CreateConVar("l4d2_tank_rock_chance",      "80", "Probabilidad Lluvia de Rocas (0-100)");
    g_cvChanceTP    = CreateConVar("l4d2_tank_tp_chance",        "80", "Probabilidad Grito de Manada (0-100)");
   
    g_cvDamage      = CreateConVar("l4d2_tank_rock_damage",      "6",  "Daño rocas meteorito");
    g_cvMinRocks    = CreateConVar("l4d2_tank_min_rocks",        "15", "Mínimo de rocas");
    g_cvMaxRocks    = CreateConVar("l4d2_tank_max_rocks",        "20", "Máximo de rocas");
    g_cvCooldown    = CreateConVar("l4d2_tank_skill_cooldown",   "30", "Tiempo de espera global");
    g_cvEnableRockRain   = CreateConVar("l4d2_enable_rockrain",   "1", "0=OFF 1=ON Lluvia de Rocas");
    g_cvEnableTP         = CreateConVar("l4d2_enable_teleport",   "1", "0=OFF 1=ON Teletransporte");
    g_cvEnableThiefPower = CreateConVar("l4d2_enable_thiefpower", "1", "0=OFF 1=ON Poderes Thief (robo+fuego)");
    g_cvVersusMode       = CreateConVar("l4d2_versus_mode",       "0", "0=Auto (Coop) 1=Manual (Versus con menú)");
    g_cvRockRainCD  = CreateConVar("l4d2_rockrain_cooldown",  "30", "Cooldown Lluvia de Rocas");
    g_cvTeleportCD  = CreateConVar("l4d2_teleport_cooldown",  "40", "Cooldown Teletransporte");
    g_cvHideMsgExpert = CreateConVar("l4d2_tank_hide_msg", "1", "Oculta mensajes");
    g_cvDifficulty = FindConVar("z_difficulty");

    // Variables de Mutaciones
    g_cvChanceFire   = CreateConVar("sm_chance_fire", "15", "Probabilidad Fire Tank");
    g_cvChanceIce    = CreateConVar("sm_chance_ice", "15", "Probabilidad Ice Tank");
    g_cvChanceSpit   = CreateConVar("sm_chance_spit", "15", "Probabilidad Spitter Tank");
    g_cvChanceWarp   = CreateConVar("sm_chance_warp", "15", "Probabilidad Warp Tank");
    g_cvChanceCobalt = CreateConVar("sm_chance_cobalt", "10", "Probabilidad Cobalt Tank");
    g_cvChanceSpawn  = CreateConVar("sm_chance_spawn", "10", "Probabilidad Spawn Tank");
    g_cvChanceKing   = CreateConVar("sm_chance_king", "10", "Probabilidad King Tank (Jefe)");
    g_cvChanceRogue  = CreateConVar("sm_chance_rogue", "10", "Probabilidad Rogue Tank");
     g_cvChanceThief = CreateConVar("l4d2_tank_thief_chance",     "20", "Probabilidad Thief Tank Negro (0-100)");
    
    // Toggles Elementales
    g_cvChaosMode = CreateConVar("sm_tank_chaos_mode", "0", "Modo Caos: Todos los tanks usan lluvia");
    g_cvPowerFire = CreateConVar("sm_power_fire", "1", "Habilitar rocas y puños de fuego");
    g_cvPowerIce = CreateConVar("sm_power_ice", "1", "Habilitar congelacion");
    g_cvPowerSpit = CreateConVar("sm_power_spit", "1", "Habilitar charcos de acido");
    g_cvPowerWarp = CreateConVar("sm_power_warp", "1", "Habilitar auto-teletransporte");
    g_cvPowerCobalt = CreateConVar("sm_power_cobalt", "1", "Habilitar velocidad extrema");
    g_cvPowerSpawn = CreateConVar("sm_power_spawn", "1", "Habilitar vomito al golpear");
    //power_king
    //power_rouge
    //power_thief

    AutoExecConfig(true, "l4d2_tank_ultimate");
    LoadConVarValues();

    HookConVarChange(g_cvEnable, OnConVarChanged);
    HookConVarChange(g_cvChanceRock, OnConVarChanged);

    RegConsoleCmd("sm_power", Command_PowerMenu);
    RegConsoleCmd("sm_powers", Command_PowerMenu);
    RegAdminCmd("sm_tankmenu", Command_AdminTankMenu, ADMFLAG_ROOT);
    RegAdminCmd("sm_tankreload", Command_ReloadConfig, ADMFLAG_CONFIG);

    HookEvent("ability_use",  Event_AbilityUse);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt",  Event_PlayerHurt);
    HookEvent("round_start",  Event_RoundStart);
    HookEvent("round_end",    Event_RoundEnd);

    CreateTimer(0.2, Timer_TankEngine, _, TIMER_REPEAT);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) OnClientPutInServer(i);
    }
}

void LoadPluginGameData() {
    Handle hGameConf = LoadGameConfigFile("l4d2_tank_ultimate");
    if (hGameConf == null) SetFailState("¡ERROR! Falta gamedata/l4d2_tank_ultimate.txt");

    StartPrepSDKCall(SDKCall_Player);
    if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer_Fling")) {
        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
        g_hFling = EndPrepSDKCall();
    }
    
    StartPrepSDKCall(SDKCall_Player);
    if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon")) {
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        g_hVomit = EndPrepSDKCall();
    }
    
    StartPrepSDKCall(SDKCall_Player);
    if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CSpitterProjectile_Detonate")) {
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        g_hSpitBurst = EndPrepSDKCall();
    }
    delete hGameConf;
}

public void OnMapStart() {
    g_iLightningModel = PrecacheModel("materials/sprites/lghtning.vmt", true);
    g_iHaloModel = PrecacheModel("materials/sprites/halo01.vmt", true);
    PrecacheModel("models/infected/hulk.mdl", true); 
    PrecacheSound("ambient/energy/zap9.wav", true);
    PrecacheSound("ambient/energy/zap1.wav", true);
    PrecacheSound("weapons/hegrenade/explode3.wav", true);
    PrecacheSound("player/tank/voice/pain/tank_fire_08.wav", true);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) { LoadConVarValues(); }

void LoadConVarValues() {
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

bool IsExpertDifficulty() {
    if (g_cvDifficulty == null) return false;
    char diff[32]; g_cvDifficulty.GetString(diff, sizeof(diff));
    return (StrEqual(diff, DIFFICULTY_EXPERT, false) || StrEqual(diff, "Impossible", false));
}

void PrintMsgToAll(const char[] format, any ...) {
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    char buffer[256]; VFormat(buffer, sizeof(buffer), format, 2); PrintToChatAll("%s", buffer);
}
void PrintMsgToClient(int client, const char[] format, any ...) {
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    char buffer[256]; VFormat(buffer, sizeof(buffer), format, 3); PrintToChat(client, "%s", buffer);
}
void PrintCenterMsgToAll(const char[] format, any ...) {
    if (g_bHideMsgExpert && IsExpertDifficulty()) return;
    char buffer[256]; VFormat(buffer, sizeof(buffer), format, 2); PrintCenterTextAll("%s", buffer);
}

// ============================================================================
// CONEXIONES Y LIMPIEZA
// ============================================================================
public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage_Core);
    g_fLastRockRain[client] = 0.0;
    g_fLastTP[client] = 0.0;
    g_iTankType[client] = TANK_NONE;
    g_bMenuOpen[client] = false;
    g_hPowerMenu[client] = null;
    g_hDeathVisualTimer[client] = null; 
}

public void OnClientDisconnect(int client) {
    CloseMenuIfOpen(client); CleanUpTankLogic(client); ResetTankVisuals(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_iTankType[i] = TANK_NONE;
        CleanUpTankLogic(i); ResetTankVisuals(i);
    }
    for (int i = 0; i < 2048; i++) g_iRockType[i] = TANK_NONE;
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) CloseMenuIfOpen(i);
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients) {
        if (g_iTankType[client] == TANK_FIRE || g_iTankType[client] == TANK_KING) ExtinguishEntity(client);
        g_iTankType[client] = TANK_NONE;
        CloseMenuIfOpen(client); CleanUpTankLogic(client);
        if (g_hDeathVisualTimer[client] != null) delete g_hDeathVisualTimer[client];
        g_hDeathVisualTimer[client] = CreateTimer(8.5, Timer_ResetVisuals, GetClientUserId(client));
    }
    return Plugin_Continue;
}

public Action Command_ReloadConfig(int client, int args) {
    LoadConVarValues();
    if (client > 0) PrintToChat(client, "\x04[Tank] \x05Configuración recargada exitosamente");
    return Plugin_Handled;
}

bool IsValidClient(int client) { return (client > 0 && client <= MaxClients && IsClientInGame(client)); }
bool IsTank(int client) { return (IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK && IsPlayerAlive(client)); }
int CountAliveTanks() { int count = 0; for (int i = 1; i <= MaxClients; i++) if (IsTank(i)) count++; return count; }

// ============================================================================
// ASIGNACIÓN Y SPAWN DE TANKS (RULETA DE PROBABILIDADES)
// ============================================================================
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client)) {
        if (GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK) {
            CreateTimer(0.2, Timer_ApplyTankType, GetClientUserId(client));
        } else {
            ResetTankVisuals(client);
        }
    }
}

public Action Timer_ApplyTankType(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
    if (!g_bPluginEnabled) return Plugin_Stop;

    if (g_bForceSpawn) {
        g_iTankType[client] = g_iForcedType;
        g_bForceSpawn = false;
    } else {
        float wFire = g_cvChanceFire.FloatValue; float wIce = g_cvChanceIce.FloatValue;
        float wSpit = g_cvChanceSpit.FloatValue; float wWarp = g_cvChanceWarp.FloatValue;
        float wCobalt = g_cvChanceCobalt.FloatValue; float wSpawn = g_cvChanceSpawn.FloatValue;
        float wKing = g_cvChanceKing.FloatValue; float wThief = g_cvChanceThief.FloatValue; float wRogue = g_cvChanceRogue.FloatValue;

        float totalWeight = wFire + wIce + wSpit + wWarp + wCobalt + wSpawn + wKing + wThief + wRogue;

        if (totalWeight <= 0.0) { g_iTankType[client] = TANK_NONE; } 
        else {
            float random = GetRandomFloat(0.0, totalWeight);
            if (random < wFire) g_iTankType[client] = TANK_FIRE;
            else if (random < wFire + wIce) g_iTankType[client] = TANK_ICE;
            else if (random < wFire + wIce + wSpit) g_iTankType[client] = TANK_SPITTER;
            else if (random < wFire + wIce + wSpit + wWarp) g_iTankType[client] = TANK_WARP;
            else if (random < wFire + wIce + wSpit + wWarp + wCobalt) g_iTankType[client] = TANK_COBALT;
            else if (random < wFire + wIce + wSpit + wWarp + wCobalt + wSpawn) g_iTankType[client] = TANK_SPAWN;
            else if (random < wFire + wIce + wSpit + wWarp + wCobalt + wSpawn + wKing) g_iTankType[client] = TANK_KING;
            else if (random < wFire + wIce + wSpit + wWarp + wCobalt + wSpawn + wKing + wThief) g_iTankType[client] = TANK_THIEF;
            else g_iTankType[client] = TANK_ROGUE;
        }
    }
    
    ApplyTankTraits(client, g_iTankType[client]);
    if (g_bVersusMode) PrintMsgToClient(client, "\x04[Powers] \x03Escribe \x05!power \x03para abrir el menú");
    return Plugin_Stop;
}

void ApplyTankTraits(int client, int type) {
    SetEntityRenderFx(client, RENDERFX_PULSE_FAST);
    SetEntProp(client, Prop_Send, "m_iGlowType", 0); SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);

    switch (type) {
        case TANK_FIRE: { SetEntityRenderColor(client, 255, 30, 0, 255); IgniteEntity(client, 99999.0); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank de \x07FF0000FUEGO\x01!"); }
        case TANK_ICE: { SetEntityRenderMode(client, RENDER_TRANSCOLOR); SetEntityRenderColor(client, 0, 100, 255, 180); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank de \x0700A5FFHIELO\x01!"); }
        case TANK_SPITTER: { SetEntityRenderColor(client, 50, 255, 50, 255); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank de \x0732FF32ACIDO\x01!"); }
        case TANK_WARP: { SetEntityRenderColor(client, 150, 0, 255, 255); g_fNextWarp[client] = GetGameTime() + GetRandomFloat(10.0, 15.0); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank \x079600FFWARP\x01!"); }
        case TANK_COBALT: { SetEntityRenderColor(client, 0, 105, 255, 255); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank \x070069FFCOBALTO\x01!"); }
        case TANK_SPAWN: { SetEntityRenderColor(client, 75, 95, 105, 255); PrintMsgToAll("\x04[MUTACIÓN]\x01 Ha aparecido un Tank \x074B5F69INFECCIOSO\x01!"); }
        case TANK_KING: { SetEntityRenderColor(client, 255, 215, 0, 255); CreateKingCrown(client); PrintMsgToAll("\x04[JEFE]\x01 Ha aparecido el \x07FFD700KING TANK (Dios)\x01!"); }
        case TANK_THIEF: { SetEntityRenderColor(client, 0, 0, 0, 255); PrintMsgToAll("\x04[JEFE]\x01 Ha aparecido un \x07000000THIEF TANK (Ladrón)\x01!"); }
        case TANK_ROGUE: { SetEntityRenderColor(client, 0, 0, 139, 255); PrintMsgToAll("\x04[JEFE]\x01 Ha aparecido un \x0700008BROGUE TANK (Cobalto+Ladrón)\x01!"); }
        default: { PrintMsgToAll("\x04[Tank] \x03¡Apareció un Tank Normal!"); }
    }
}

void CreateKingCrown(int client) {
    int aura = CreateEntityByName("beam_spotlight");
    if (aura != -1) {
        char tName[64]; Format(tName, sizeof(tName), "King%d", client);
        DispatchKeyValue(client, "targetname", tName);
        DispatchKeyValue(aura, "targetname", "KingCrown");
        DispatchKeyValue(aura, "parentname", tName);
        DispatchKeyValue(aura, "spotlightwidth", "40");
        DispatchKeyValue(aura, "spotlightlength", "200");
        DispatchKeyValue(aura, "rendercolor", "255 215 0");
        DispatchKeyValue(aura, "renderamt", "255");
        DispatchSpawn(aura);
        SetVariantString(tName); AcceptEntityInput(aura, "SetParent", aura, aura);
        SetVariantString("mouth"); AcceptEntityInput(aura, "SetParentAttachment");
        AcceptEntityInput(aura, "Enable");
    }
}

// ============================================================================
// MOTOR CONTÍNUO (FUEGO, BLUR, AUTO-WARP)
// ============================================================================
public Action Timer_TankEngine(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && g_iTankType[i] != TANK_NONE) {
            float vel[3], pos[3]; GetEntPropVector(i, Prop_Data, "m_vecVelocity", vel); GetClientAbsOrigin(i, pos);
            float speed = GetVectorLength(vel);

            if (g_cvPowerFire.BoolValue && g_iTankType[i] == TANK_FIRE && speed > 50.0) {
                int fire = CreateEntityByName("env_fire");
                if (fire != -1) {
                    DispatchKeyValue(fire, "firesize", "50"); DispatchKeyValue(fire, "health", "2"); DispatchKeyValue(fire, "fireattack", "2");
                    DispatchSpawn(fire); TeleportEntity(fire, pos, NULL_VECTOR, NULL_VECTOR); AcceptEntityInput(fire, "StartFire");
                    char out[64]; Format(out, sizeof(out), "OnUser1 !self:kill::2.0:1");
                    SetVariantString(out); AcceptEntityInput(fire, "AddOutput"); AcceptEntityInput(fire, "FireUser1");
                }
            }
            
            if (g_cvPowerCobalt.BoolValue && (g_iTankType[i] == TANK_COBALT || g_iTankType[i] == TANK_ROGUE)) {
                SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.5); 
                if (speed > 50.0) CreateBlurEffect(i, pos, (g_iTankType[i] == TANK_ROGUE));
            }
            
            if (g_cvPowerWarp.BoolValue && g_iTankType[i] == TANK_WARP) {
                if (GetGameTime() >= g_fNextWarp[i]) { WarpToSurvivor(i); g_fNextWarp[i] = GetGameTime() + GetRandomFloat(10.0, 15.0); }
            }
        }
    }
    return Plugin_Continue;
}

void CreateBlurEffect(int client, float pos[3], bool isRogue) {
    float ang[3]; GetClientAbsAngles(client, ang);
    int anim = GetEntProp(client, Prop_Send, "m_nSequence");
    int entity = CreateEntityByName("prop_dynamic");
    if (entity != -1) {
        DispatchKeyValue(entity, "model", "models/infected/hulk.mdl"); DispatchSpawn(entity);
        AcceptEntityInput(entity, "DisableCollision"); SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
        if (isRogue) SetEntityRenderColor(entity, 0, 0, 139, 100); else SetEntityRenderColor(entity, 0, 105, 255, 100);
        SetEntProp(entity, Prop_Send, "m_nSequence", anim); SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 0.0);
        TeleportEntity(entity, pos, ang, NULL_VECTOR);
        char out[64]; Format(out, sizeof(out), "OnUser1 !self:kill::0.25:1");
        SetVariantString(out); AcceptEntityInput(entity, "AddOutput"); AcceptEntityInput(entity, "FireUser1");
    }
}

void WarpToSurvivor(int tank) {
    int valid[MAXPLAYERS]; int count = 0;
    for (int i = 1; i <= MaxClients; i++) { if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) valid[count++] = i; }
    if (count > 0) {
        int target = valid[GetRandomInt(0, count - 1)]; float survPos[3], warpPos[3]; GetClientAbsOrigin(target, survPos);
        float angle = GetRandomFloat(0.0, 360.0) * 3.14159 / 180.0; float distance = GetRandomFloat(300.0, 450.0);
        warpPos[0] = survPos[0] + (distance * Cosine(angle)); warpPos[1] = survPos[1] + (distance * Sine(angle)); warpPos[2] = survPos[2] + 20.0;
        Handle trace = TR_TraceRayFilterEx(survPos, warpPos, MASK_SOLID, RayType_EndPoint, TraceFilter_IgnoreTank, tank);
        if (TR_DidHit(trace)) {
            TR_GetEndPosition(warpPos, trace); float dir[3]; MakeVectorFromPoints(warpPos, survPos, dir);
            NormalizeVector(dir, dir); ScaleVector(dir, 50.0); AddVectors(warpPos, dir, warpPos);
        }
        delete trace;
        TeleportEntity(tank, warpPos, NULL_VECTOR, NULL_VECTOR); EmitSoundToAll("ambient/energy/zap1.wav", tank);
    }
}

// ============================================================================
// HABILIDADES AUTOMÁTICAS & COUNTER (PIPE BOMB)
// ============================================================================
public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) {
    if (!g_bPluginEnabled || g_bVersusMode) return Plugin_Continue;
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsTank(client) || g_bInCooldown[client]) return Plugin_Continue;

    char ability[32]; event.GetString("ability", ability, sizeof(ability));
    
    if (StrEqual(ability, "ability_throw", true)) {
        bool triggered = false; int t = g_iTankType[client];

        // Lluvia de Rocas
        if (g_cvEnableRockRain.BoolValue) {
            int rocks = 0; bool isFire = false;
            if (t == TANK_KING && GetRandomFloat(0.0, 100.0) < g_cvChanceRock.FloatValue) { rocks = 20; isFire = true; }
            else if ((t == TANK_THIEF || t == TANK_ROGUE) && GetRandomFloat(0.0, 100.0) < g_cvChanceRock.FloatValue) { rocks = 10; isFire = true; }
            else if (g_cvChaosMode.BoolValue && GetRandomFloat(0.0, 100.0) < g_cvChanceRock.FloatValue) { rocks = GetRandomInt(8, 12); }
            else if (GetRandomFloat(0.0, 100.0) < g_fChanceRock) { rocks = GetRandomInt(g_iMinRocks, g_iMaxRocks); }

            if (rocks > 0) { TriggerRockRainCast(client, rocks, isFire); triggered = true; }
        }

        // Teletransporte
        if (!triggered && g_cvEnableTP.BoolValue && GetRandomFloat(0.0, 100.0) < g_fChanceTP) {
            if (CountAliveTanks() >= 2 || t == TANK_KING || g_cvChaosMode.BoolValue) {
                TeleportOtherTanks(client); triggered = true;
            }
        }

        if (triggered) {
            g_bInCooldown[client] = true;
            CreateTimer(g_fCooldown, Timer_ResetCooldown, GetClientUserId(client));
        }
    }
    return Plugin_Continue;
}

void TriggerRockRainCast(int client, int rocks, bool isFire) {
    g_fLastRockRain[client] = GetGameTime();
    SetEntityMoveType(client, MOVETYPE_NONE);
    PrintCenterMsgToAll("⚠ EL TANK ESTÁ INVOCANDO METEORITOS ⚠\n¡Lánzale una Pipe Bomb para cancelarlo!");
    
    Handle pack = CreateDataPack();
    WritePackCell(pack, GetClientUserId(client));
    WritePackCell(pack, rocks);
    WritePackCell(pack, isFire ? 1 : 0);
    WritePackCell(pack, 15); // 1.5s casting
    CreateTimer(0.1, Timer_CastingRockRain, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CastingRockRain(Handle timer, Handle pack) {
    ResetPack(pack);
    int client = GetClientOfUserId(ReadPackCell(pack));
    int rocks = ReadPackCell(pack);
    bool isFire = ReadPackCell(pack) == 1;
    int ticks = ReadPackCell(pack);

    if (!IsTank(client) || !IsPlayerAlive(client)) { CloseHandle(pack); return Plugin_Stop; }

    int pipe = -1; float tankPos[3]; GetClientAbsOrigin(client, tankPos);
    while ((pipe = FindEntityByClassname(pipe, "pipe_bomb_projectile")) != -1) {
        float pipePos[3]; GetEntPropVector(pipe, Prop_Send, "m_vecOrigin", pipePos);
        if (GetVectorDistance(tankPos, pipePos) < 400.0) {
            SetEntityMoveType(client, MOVETYPE_WALK);
            SetEntProp(client, Prop_Send, "m_nSequence", 63); 
            SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 4.0); 
            PrintCenterMsgToAll("✔ ¡LLUVIA CANCELADA POR PIPE BOMB! ✔");
            EmitSoundToAll("player/tank/voice/pain/tank_fire_08.wav", client);
            CloseHandle(pack); return Plugin_Stop;
        }
    }

    if (ticks <= 0) {
        SetEntityMoveType(client, MOVETYPE_WALK);
        ExecuteMultiRock(client, rocks, isFire);
        CloseHandle(pack); return Plugin_Stop;
    }

    SetPackPosition(pack, 24); WritePackCell(pack, ticks - 1);
    return Plugin_Continue;
}

// ============================================================================
// MATEMÁTICAS ORIGINALES DE LA LLUVIA DE ROCAS
// ============================================================================
void ExecuteMultiRock(int client, int count, bool isFire) {
    g_bTankImmune[client] = true;
    SDKHook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage_Core);
    
    SetEntProp(client, Prop_Send, "m_iGlowType", 3);
    SetEntProp(client, Prop_Send, "m_glowColorOverride", isFire ? 16711680 : 25600);

    if (count > 5) {
        g_bTankFrozen[client] = true; g_bTankRockImmune[client] = true;
        SetEntityMoveType(client, MOVETYPE_NONE);
    }

    float eyePos[3]; GetClientEyePosition(client, eyePos);
    LaunchMultipleRocks(client, eyePos, count);

    float duration = count > 5 ? (2.5 + ((count - 5) * 0.3)) : 2.5;
    CreateTimer(duration + 0.5, Timer_RemoveGlow, GetClientUserId(client));
    g_hImmunityTimer[client] = CreateTimer(duration, Timer_RemoveImmunity, GetClientUserId(client));

    if (count > 5) {
        g_hFreezeTimer[client] = CreateTimer(duration, Timer_UnfreezeTank, GetClientUserId(client));
        g_hRockImmuneTimer[client] = CreateTimer(duration + 1.0, Timer_RemoveRockImmunity, GetClientUserId(client));
    }
}

void LaunchMultipleRocks(int client, float eyePos[3], int rockCount) {
    int survivors[MAXPLAYERS + 1]; int survivorCount = 0;
    float tankPos[3]; GetClientAbsOrigin(client, tankPos);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            float survivorPos[3]; GetClientAbsOrigin(i, survivorPos);
            if (GetVectorDistance(tankPos, survivorPos) > 2500.0) continue;
            if (IsInsideSaferoom(survivorPos)) continue;
            survivors[survivorCount++] = i;
        }
    }
    
    if (survivorCount == 0) return;
    char damageStr[32]; IntToString(RoundToNearest(g_fDamage), damageStr, sizeof(damageStr));
    float tankAngles[3]; GetClientEyeAngles(client, tankAngles);
    
    for (int rock = 0; rock < rockCount; rock++) {
        float delay = rock < 5 ? (0.1 * rock) : (0.5 + (0.15 * (rock - 5)));
        int ent = CreateEntityByName("env_rock_launcher");
        if (!IsValidEntity(ent)) continue;
        DispatchKeyValue(ent, "rockdamageoverride", damageStr);

        float launchPos[3]; int targetEntity; int dummyRef = 0;

        if (rock < 5) {
            DispatchSpawn(ent);
            int target = survivors[GetRandomInt(0, survivorCount - 1)]; targetEntity = target;
            float direction[3]; GetDirectionalVector(rock, tankAngles, direction);
            launchPos[0] = eyePos[0] + (direction[0] * 300.0); launchPos[1] = eyePos[1] + (direction[1] * 300.0); launchPos[2] = eyePos[2] + (direction[2] * 300.0);
            TeleportEntity(ent, launchPos, NULL_VECTOR, NULL_VECTOR);
        } else {
            int targetSurvivor = survivors[GetRandomInt(0, survivorCount - 1)];
            float survivorPosTarget[3]; GetClientAbsOrigin(targetSurvivor, survivorPosTarget);
            float progressRatio = float(rock - 5) / float(rockCount - 5 > 0 ? rockCount - 5 : 1);
            float maxRadius = 250.0 * (1.0 - (progressRatio * 0.6)); float radius = GetRandomFloat(20.0, maxRadius); float angle = GetRandomFloat(0.0, 360.0);
            float targetX = survivorPosTarget[0] + (Cosine(DegToRad(angle)) * radius); float targetY = survivorPosTarget[1] + (Sine(DegToRad(angle)) * radius); float targetZ = survivorPosTarget[2];

            float traceStart[3], traceEnd[3];
            traceStart[0] = targetX; traceStart[1] = targetY; traceStart[2] = targetZ + 10.0;
            traceEnd[0] = targetX; traceEnd[1] = targetY; traceEnd[2] = targetZ + 1200.0;
            Handle trace = TR_TraceRayFilterEx(traceStart, traceEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_WorldOnly);
            float spawnHeightZ = TR_DidHit(trace) ? (TR_GetEndPosition(traceEnd, trace), traceEnd[2] - 80.0) : (targetZ + 800.0 + (float(rock - 5) * 40.0));
            delete trace;

            launchPos[0] = targetX; launchPos[1] = targetY; launchPos[2] = spawnHeightZ;
            int dummyTarget = CreateEntityByName("info_target");
            float groundPos[3]; groundPos[0] = targetX; groundPos[1] = targetY; groundPos[2] = targetZ;
            TeleportEntity(dummyTarget, groundPos, NULL_VECTOR, NULL_VECTOR); DispatchSpawn(dummyTarget);
            targetEntity = dummyTarget; dummyRef = EntIndexToEntRef(dummyTarget);

            float vectorDir[3], aimAngles[3]; SubtractVectors(groundPos, launchPos, vectorDir); GetVectorAngles(vectorDir, aimAngles);
            DispatchSpawn(ent); TeleportEntity(ent, launchPos, aimAngles, NULL_VECTOR);
        }

        SetVariantEntity(targetEntity); AcceptEntityInput(ent, "SetTarget");
        DataPack p; CreateDataTimer(delay, Timer_LaunchRock, p);
        p.WriteCell(EntIndexToEntRef(ent)); p.WriteCell(rock < 5 ? GetClientUserId(targetEntity) : 0); p.WriteCell(dummyRef);
    }
}

public Action Timer_LaunchRock(Handle timer, DataPack pack) {
    pack.Reset(); int entRef = pack.ReadCell(); int userid = pack.ReadCell(); int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
        if (userid != 0) {
            int target = GetClientOfUserId(userid);
            if (IsValidClient(target) && IsPlayerAlive(target)) { SetVariantEntity(target); AcceptEntityInput(ent, "SetTarget"); }
        }
        AcceptEntityInput(ent, "LaunchRock");
        DataPack packRemove; CreateDataTimer(0.1, Timer_RemoveLauncher, packRemove);
        packRemove.WriteCell(entRef); packRemove.WriteCell(dummyRef);
    }
    return Plugin_Stop;
}

public Action Timer_RemoveLauncher(Handle timer, DataPack pack) {
    pack.Reset(); int entRef = pack.ReadCell(); int dummyRef = pack.ReadCell();
    int ent = EntRefToEntIndex(entRef); if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) AcceptEntityInput(ent, "Kill");
    if (dummyRef != 0) { int dummy = EntRefToEntIndex(dummyRef); if (dummy != INVALID_ENT_REFERENCE && IsValidEntity(dummy)) AcceptEntityInput(dummy, "Kill"); }
    return Plugin_Stop;
}

void GetDirectionalVector(int rockIndex, float tankAngles[3], float direction[3]) {
    float yaw = tankAngles[1]; float pitch = tankAngles[0];
    switch (rockIndex) {
        case 0: { direction[0]=Cosine(DegToRad(yaw)); direction[1]=Sine(DegToRad(yaw)); direction[2]=-Sine(DegToRad(pitch)); }
        case 1: { direction[0]=Cosine(DegToRad(yaw+90.0)); direction[1]=Sine(DegToRad(yaw+90.0)); direction[2]=0.0; }
        case 2: { direction[0]=Cosine(DegToRad(yaw-90.0)); direction[1]=Sine(DegToRad(yaw-90.0)); direction[2]=0.0; }
        case 3: { direction[0]=Cosine(DegToRad(yaw+180.0)); direction[1]=Sine(DegToRad(yaw+180.0)); direction[2]=0.0; }
        case 4: { direction[0]=Cosine(DegToRad(yaw)); direction[1]=Sine(DegToRad(yaw)); direction[2]=1.0; }
    }
    NormalizeVector(direction, direction);
}

// ============================================================================
// LÓGICAS ORIGINALES DE TELETRANSPORTE
// ============================================================================
void TeleportOtherTanks(int client) {
    PrintMsgToAll("\x04[Tank] \x03¡GRITO! \x05¡La manada se reúne!");
    float targetPos[3]; int teleported = 0;
    float callerPos[3]; GetClientAbsOrigin(client, callerPos); ShowLightningEffect(callerPos);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (i == client || !IsTank(i)) continue;
        if (FindSafeTeleportSpot(client, targetPos)) {
            float originPos[3]; GetClientAbsOrigin(i, originPos); ShowLightningEffect(originPos);
            TeleportEntity(i, targetPos, NULL_VECTOR, NULL_VECTOR); ShowLightningEffect(targetPos);
            PrintMsgToClient(i, "\x04[Tank] \x05¡Has sido llamado!"); teleported++;
        }
    }
}

void ShowLightningEffect(float pos[3]) {
    float topPos[3]; topPos[0] = pos[0]; topPos[1] = pos[1]; topPos[2] = pos[2] + 800.0; 
    TE_SetupBeamPoints(topPos, pos, g_iLightningModel, g_iHaloModel, 0, 0, 0.5, 10.0, 10.0, 0, 10.0, {150, 200, 255, 255}, 10);
    TE_SendToAll(); TE_SetupSparks(pos, NULL_VECTOR, 100, 50); TE_SendToAll();
    EmitSoundToAll("ambient/energy/zap9.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
}

bool FindSafeTeleportSpot(int client, float targetPos[3]) {
    float tankPos[3]; GetClientAbsOrigin(client, tankPos);
    for (int attempt = 0; attempt < 20; attempt++) {
        float angle = GetRandomFloat(0.0, 360.0); float radius = GetRandomFloat(200.0, 500.0);
        float testPos[3]; testPos[0] = tankPos[0] + (Cosine(DegToRad(angle)) * radius); testPos[1] = tankPos[1] + (Sine(DegToRad(angle)) * radius); testPos[2] = tankPos[2];
        float traceStart[3], traceEnd[3]; traceStart[0] = testPos[0]; traceStart[1] = testPos[1]; traceStart[2] = testPos[2] + 300.0; traceEnd[0] = testPos[0]; traceEnd[1] = testPos[1]; traceEnd[2] = testPos[2] - 500.0;
        Handle trace = TR_TraceHullFilterEx(traceStart, traceEnd, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 72.0}), MASK_PLAYERSOLID, TraceFilter_IgnoreTank, client);
        if (TR_DidHit(trace)) {
            TR_GetEndPosition(targetPos, trace); targetPos[2] += 10.0; delete trace;
            if (!IsPositionValid(targetPos, tankPos)) continue;
            if (IsInsideSaferoom(targetPos)) continue;
            if (IsInsideWall(targetPos)) continue;
            return true;
        }
        delete trace;
    }
    return false;
}

bool IsPositionValid(float pos[3], float originPos[3]) {
    float distance = GetVectorDistance(pos, originPos); if (distance < 150.0 || distance > 600.0) return false;
    float heightDiff = FloatAbs(pos[2] - originPos[2]); if (heightDiff > 300.0) return false; return true;
}

bool IsInsideSaferoom(float pos[3]) {
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1) {
        char targetname[64]; GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrContains(targetname, "checkpoint", false) != -1 || StrContains(targetname, "saferoom", false) != -1) {
            float entPos[3]; GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
            if (GetVectorDistance(pos, entPos) < 300.0) return true;
        }
    }
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1) {
        float entPos[3]; GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
        if (GetVectorDistance(pos, entPos) < 400.0) return true;
    }
    return false;
}

bool IsInsideWall(float pos[3]) {
    float mins[3] = {-16.0, -16.0, 0.0}; float maxs[3] = {16.0, 16.0, 72.0};
    Handle trace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilter_WorldOnly);
    bool stuck = TR_DidHit(trace); delete trace; return stuck;
}

// ============================================================================
// EVENTOS AL RECIBIR DAÑO Y EFECTOS CUERPO A CUERPO
// ============================================================================
public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
    if (victim > 0 && victim <= MaxClients && g_iTankType[victim] == TANK_FIRE) {
        if (damagetype & DMG_BURN || damagetype & DMG_SLOWBURN) { damage = 0.0; return Plugin_Handled; }
    }

    if (attacker > 0 && attacker <= MaxClients && g_iTankType[attacker] != TANK_NONE) {
        if (victim > 0 && victim <= MaxClients && GetClientTeam(victim) == 2) {
            char classname[32]; GetEdictClassname(inflictor, classname, sizeof(classname));
            if (StrEqual(classname, "weapon_tank_claw") || StrEqual(classname, "weapon_tank_rock")) {
                int t = g_iTankType[attacker];

                if (g_cvPowerFire.BoolValue && t == TANK_FIRE) { IgniteEntity(victim, 4.0); ScreenFade(victim, 100, 50, 0, 150, 1.5); } 
                else if (g_cvPowerIce.BoolValue && t == TANK_ICE && GetRandomInt(1, 3) == 1) {
                    SetEntityRenderMode(victim, RENDER_TRANSCOLOR); SetEntityRenderColor(victim, 0, 100, 170, 180); SetEntityMoveType(victim, MOVETYPE_VPHYSICS); 
                    CreateTimer(3.0, Timer_UnFreeze, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE); ScreenFade(victim, 0, 50, 100, 150, 1.5);
                }
                else if (g_cvPowerSpawn.BoolValue && t == TANK_SPAWN && g_hVomit != null) { SDKCall(g_hVomit, victim, attacker, true); }
                else if (g_cvEnableThiefPower.BoolValue && (t == TANK_THIEF || t == TANK_ROGUE)) {
                    DropItemsPhysically(victim);
                    if (g_hFling != null) {
                        float vAng[3], vVel[3]; GetClientEyeAngles(attacker, vAng); GetAngleVectors(vAng, vVel, NULL_VECTOR, NULL_VECTOR);
                        ScaleVector(vVel, 450.0); vVel[2] = 350.0; SDKCall(g_hFling, victim, vVel, 76, attacker, 2.0);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    if (!g_cvEnableThiefPower.BoolValue) return;
    int victim = GetClientOfUserId(event.GetInt("userid")); int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (IsValidClient(attacker) && IsValidClient(victim) && (g_iTankType[attacker] == TANK_THIEF || g_iTankType[attacker] == TANK_ROGUE)) {
        if (GetClientTeam(victim) == 2 && IsPlayerAlive(victim)) {
            char weapon[64]; event.GetString("weapon", weapon, sizeof(weapon));
            if (StrEqual(weapon, "tank_rock")) { IgniteEntity(victim, 5.0); }
        }
    }
}

public Action Hook_TankRockDamage_Core(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
    if (g_bTankRockImmune[victim] && IsValidEntity(inflictor)) { char cls[64]; GetEdictClassname(inflictor, cls, sizeof(cls)); if (StrEqual(cls, "tank_rock")) return Plugin_Handled; }
    
    // Tope daño Experto para el Thief
    if (IsExpertDifficulty() && IsValidClient(attacker) && (g_iTankType[attacker] == TANK_THIEF || g_iTankType[attacker] == TANK_ROGUE) && (damagetype & DMG_CLUB)) {
        if (GetClientTeam(victim) == 2 && IsPlayerAlive(victim)) {
            int currentHP = GetClientHealth(victim);
            if (damage >= float(currentHP)) {
                float cappedDamage = float(currentHP) - 1.0;
                if (cappedDamage > EXPERT_THIEF_MAX_DAMAGE) cappedDamage = EXPERT_THIEF_MAX_DAMAGE;
                if (cappedDamage < 1.0) cappedDamage = 1.0;
                damage = cappedDamage; return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_UnFreeze(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntityRenderMode(client, RENDER_NORMAL); SetEntityRenderColor(client, 255, 255, 255, 255); SetEntityMoveType(client, MOVETYPE_WALK);
    }
    return Plugin_Stop;
}

void DropItemsPhysically(int client) {
    float vPos[3], vForce[3], vAngVel[3]; GetClientAbsOrigin(client, vPos); vPos[2] += 35.0;
    for (int i = 0; i < 5; i++) {
        int weapon = GetPlayerWeaponSlot(client, i);
        if (weapon != -1 && IsValidEntity(weapon)) {
            SDKHooks_DropWeapon(client, weapon);
            vForce[0] = GetRandomFloat(-200.0, 200.0); vForce[1] = GetRandomFloat(-200.0, 200.0); vForce[2] = GetRandomFloat(300.0, 450.0);
            TeleportEntity(weapon, vPos, NULL_VECTOR, vForce);
            vAngVel[0] = GetRandomFloat(-400.0, 400.0); vAngVel[1] = GetRandomFloat(-400.0, 400.0); vAngVel[2] = GetRandomFloat(-400.0, 400.0);
            SetEntPropVector(weapon, Prop_Data, "m_vecAngularVelocity", vAngVel);
        }
    }
}

// ================= GESTIÓN REAL DEL ÁCIDO SIN REBOTE (GAMEDATA SPITTER) =================
public void OnEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "tank_rock")) { CreateTimer(0.1, Timer_ModifyRock, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE); }
}

public Action Timer_ModifyRock(Handle timer, any ref) {
    int entity = EntRefToEntIndex(ref);
    if (entity != INVALID_ENT_REFERENCE) {
        int thrower = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
        if (thrower > 0 && thrower <= MaxClients && g_iTankType[thrower] != TANK_NONE) {
            g_iRockType[entity] = g_iTankType[thrower]; 
            int t = g_iTankType[thrower];
            if (t == TANK_FIRE || t == TANK_KING || t == TANK_THIEF || t == TANK_ROGUE) { SetEntityRenderColor(entity, 128, 0, 0, 255); IgniteEntity(entity, 100.0); } 
            else if (t == TANK_ICE) { SetEntityRenderMode(entity, RENDER_TRANSCOLOR); SetEntityRenderColor(entity, 0, 100, 255, 180); } 
            else if (t == TANK_SPITTER) { SetEntityRenderColor(entity, 50, 255, 50, 255); }
        }
    }
    return Plugin_Stop;
}

public void OnEntityDestroyed(int entity) {
    if (!IsServerProcessing() || entity <= 32 || !IsValidEntity(entity)) return;
    char classname[32]; GetEdictClassname(entity, classname, sizeof(classname));
    if (StrEqual(classname, "tank_rock", true)) {
        if (g_cvPowerSpit.BoolValue && g_iRockType[entity] == TANK_SPITTER) {
            int bot = CreateFakeClient("Spitter");
            if (bot > 0) {
                float pos[3]; GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
                TeleportEntity(bot, pos, NULL_VECTOR, NULL_VECTOR);
                if (g_hSpitBurst != null) SDKCall(g_hSpitBurst, bot, true);
                KickClient(bot);
            }
            g_iRockType[entity] = TANK_NONE;
        }
    }
}

// ================= TIMERS EXTRA Y MENÚS DE ADMINISTRADOR =================
public Action Timer_ResetCooldown(Handle timer, any userid) { int c = GetClientOfUserId(userid); if (c > 0 && c <= MaxClients) g_bInCooldown[c] = false; return Plugin_Stop; }
public Action Timer_RemoveGlow(Handle timer, any userid) { int client = GetClientOfUserId(userid); if (client > 0 && IsClientInGame(client)) { SetEntProp(client, Prop_Send, "m_iGlowType", 0); SetEntProp(client, Prop_Send, "m_glowColorOverride", 0); } return Plugin_Stop; }
public Action Timer_RemoveImmunity(Handle timer, any userid) { int client = GetClientOfUserId(userid); if (client > 0 && IsClientInGame(client)) { g_bTankImmune[client] = false; SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage_Core); } return Plugin_Stop; }
public Action Timer_UnfreezeTank(Handle timer, any userid) { int client = GetClientOfUserId(userid); if (client > 0 && IsClientInGame(client)) { g_bTankFrozen[client] = false; SetEntityMoveType(client, MOVETYPE_WALK); } return Plugin_Stop; }
public Action Timer_RemoveRockImmunity(Handle timer, any userid) { int client = GetClientOfUserId(userid); if (client > 0 && IsClientInGame(client)) { g_bTankRockImmune[client] = false; SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage_Core); } return Plugin_Stop; }
public Action Timer_ResetVisuals(Handle timer, any userid) { int client = GetClientOfUserId(userid); g_hDeathVisualTimer[client] = null; ResetTankVisuals(client); return Plugin_Stop; }
public Action Hook_TankTakeDamage_Core(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) { if (g_bTankImmune[victim]) return Plugin_Handled; return Plugin_Continue; }
public bool TraceFilter_IgnoreTank(int entity, int contentsMask, any data) { return (entity != data); }
public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data) { return entity == 0; }

void CleanUpTankLogic(int client) {
    if (client < 1 || client > MaxClients) return;
    g_bInCooldown[client] = false; g_bTankImmune[client] = false; g_bTankFrozen[client] = false; g_bTankRockImmune[client] = false;
    g_fLastRockRain[client] = 0.0; g_fLastTP[client] = 0.0;
    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TankTakeDamage_Core); SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_TankRockDamage_Core);
    if (g_hImmunityTimer[client] != null) { delete g_hImmunityTimer[client]; g_hImmunityTimer[client] = null; }
    if (g_hFreezeTimer[client] != null) { delete g_hFreezeTimer[client]; g_hFreezeTimer[client] = null; }
    if (g_hRockImmuneTimer[client] != null) { delete g_hRockImmuneTimer[client]; g_hRockImmuneTimer[client] = null; }
}

void ResetTankVisuals(int client) {
    if (g_hDeathVisualTimer[client] != null) { delete g_hDeathVisualTimer[client]; g_hDeathVisualTimer[client] = null; }
    if (IsValidClient(client)) { SetEntityMoveType(client, MOVETYPE_WALK); SetEntProp(client, Prop_Send, "m_iGlowType", 0); SetEntityRenderColor(client, 255, 255, 255, 255); }
}

// ================= MENÚS =================
public Action Command_AdminTankMenu(int client, int args) {
    if (client == 0) return Plugin_Handled;
    Menu menu = new Menu(MenuHandler_AdminTank);
    menu.SetTitle("Menu Mutaciones de Tank");
    menu.AddItem("1", "FIRE Tank"); menu.AddItem("2", "ICE Tank"); menu.AddItem("3", "SPITTER Tank");
    menu.AddItem("4", "WARP Tank"); menu.AddItem("5", "COBALT Tank"); menu.AddItem("6", "SPAWN Tank");
    menu.AddItem("7", "KING Tank (Jefe Final)"); menu.AddItem("8", "THIEF Tank (Ladrón)"); menu.AddItem("9", "ROGUE Tank (Veloz+Ladrón)");
    menu.Display(client, MENU_TIME_FOREVER); return Plugin_Handled;
}
public int MenuHandler_AdminTank(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32]; menu.GetItem(param2, info, sizeof(info));
        g_bForceSpawn = true; g_iForcedType = StringToInt(info); 
        int flags = GetCommandFlags("z_spawn_old"); SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);
        FakeClientCommand(param1, "z_spawn_old tank auto"); SetCommandFlags("z_spawn_old", flags);
    } else if (action == MenuAction_End) delete menu;
    return 0;
}
void ScreenFade(int client, int r, int g, int b, int alpha, float duration) {
    Handle msg = StartMessageOne("Fade", client);
    if (msg != INVALID_HANDLE) {
        BfWriteShort(msg, RoundFloat(duration * 400.0)); BfWriteShort(msg, RoundFloat(duration * 400.0));
        BfWriteShort(msg, 0x0001); BfWriteByte(msg, r); BfWriteByte(msg, g); BfWriteByte(msg, b); BfWriteByte(msg, alpha);
        EndMessage();
    }
}