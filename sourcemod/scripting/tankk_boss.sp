#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define TANK_NONE 0
#define TANK_FIRE 1
#define TANK_ICE 2
#define TANK_SPITTER 3
#define TANK_WARP 4
#define TANK_COBALT 5
#define TANK_SPAWN 6

int g_iTankType[MAXPLAYERS + 1];
float g_fNextWarp[MAXPLAYERS + 1];
int g_iRockType[2048]; 

bool g_bForceSpawn = false;
int g_iForcedType = 0;

ConVar g_cvEnableFire;
ConVar g_cvEnableIce;
ConVar g_cvEnableSpitter;
ConVar g_cvEnableWarp;
ConVar g_cvEnableCobalt;
ConVar g_cvEnableSpawn;

// Manejadores de Memoria (SDKCalls)[cite: 1]
Handle g_hSDKSpitBurst = null;
Handle g_hSDKVomitOnPlayer = null;

public Plugin myinfo = {
    name = "Elemental Mutant Tanks - GameData",
    author = "Moises",
    description = "Mutaciones utilizando SDKCalls directos del motor del juego.",
    version = "12.0"
};

public void OnPluginStart() {
    g_cvEnableFire = CreateConVar("sm_tank_fire_enable", "1", "Permitir Tanks de Fuego");
    g_cvEnableIce = CreateConVar("sm_tank_ice_enable", "1", "Permitir Tanks de Hielo");
    g_cvEnableSpitter = CreateConVar("sm_tank_spit_enable", "1", "Permitir Tanks de Acido");
    g_cvEnableWarp = CreateConVar("sm_tank_warp_enable", "1", "Permitir Tanks Warp");
    g_cvEnableCobalt = CreateConVar("sm_tank_cobalt_enable", "1", "Permitir Tanks Cobaltos");
    g_cvEnableSpawn = CreateConVar("sm_tank_spawn_enable", "1", "Permitir Tanks Infecciosos");
    
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    
    RegAdminCmd("sm_tankmenu", Command_TankMenu, ADMFLAG_ROOT, "Abre el menu para spawnear Tanks Elementales");
    
    CreateTimer(0.2, Timer_TankEngine, _, TIMER_REPEAT);
    
    InitSDKCalls();
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) OnClientPutInServer(i);
    }
}

// ================= INICIALIZACIÓN DE GAMEDATA =================
void InitSDKCalls() {
    Handle hGameData = LoadGameConfigFile("supertanks");
    if (hGameData == null) {
        SetFailState("No se pudo cargar addons/sourcemod/gamedata/supertanks.txt");
    }

    StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CSpitterProjectile_Detonate")) {
        SetFailState("No se encontro la firma CSpitterProjectile_Detonate en supertanks.txt");
    }
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKSpitBurst = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon")) {
        SetFailState("No se encontro la firma CTerrorPlayer_OnVomitedUpon en supertanks.txt");
    }
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKVomitOnPlayer = EndPrepSDKCall();

    CloseHandle(hGameData);
}

public void OnMapStart() {
    PrecacheModel("models/infected/hulk.mdl", true); 
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
    g_iTankType[client] = TANK_NONE;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) g_iTankType[i] = TANK_NONE;
    for (int i = 0; i < 2048; i++) g_iRockType[i] = TANK_NONE;
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients) {
        if (g_iTankType[client] == TANK_FIRE) ExtinguishEntity(client);
        g_iTankType[client] = TANK_NONE;
    }
    return Plugin_Continue;
}

// ================= ASIGNACIÓN EN SPAWN =================
public Action Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) return Plugin_Continue;

    if (g_bForceSpawn) {
        g_iTankType[client] = g_iForcedType;
        g_bForceSpawn = false;
        ApplyTankTraits(client, g_iTankType[client]);
    } else {
        int activeTanks[6];
        int count = 0;
        
        if (g_cvEnableFire.BoolValue) activeTanks[count++] = TANK_FIRE;
        if (g_cvEnableIce.BoolValue) activeTanks[count++] = TANK_ICE;
        if (g_cvEnableSpitter.BoolValue) activeTanks[count++] = TANK_SPITTER;
        if (g_cvEnableWarp.BoolValue) activeTanks[count++] = TANK_WARP;
        if (g_cvEnableCobalt.BoolValue) activeTanks[count++] = TANK_COBALT;
        if (g_cvEnableSpawn.BoolValue) activeTanks[count++] = TANK_SPAWN;
        
        if (count > 0) {
            g_iTankType[client] = activeTanks[GetRandomInt(0, count - 1)];
            ApplyTankTraits(client, g_iTankType[client]);
        } else {
            g_iTankType[client] = TANK_NONE; 
        }
    }
    return Plugin_Continue;
}

void ApplyTankTraits(int client, int type) {
    SetEntityRenderFx(client, RENDERFX_PULSE_FAST);
    switch (type) {
        case TANK_FIRE: {
            SetEntityRenderColor(client, 255, 30, 0, 255);
            IgniteEntity(client, 99999.0);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank de \x07FUEGO\x01!");
        }
        case TANK_ICE: {
            SetEntityRenderMode(client, RENDER_TRANSCOLOR);
            SetEntityRenderColor(client, 0, 100, 255, 180);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank de \x07HIELO\x01!");
        }
        case TANK_SPITTER: {
            SetEntityRenderColor(client, 50, 255, 50, 255);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank de \x07ACIDO\x01!");
        }
        case TANK_WARP: {
            SetEntityRenderColor(client, 150, 0, 255, 255);
            g_fNextWarp[client] = GetGameTime() + GetRandomFloat(10.0, 15.0);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank \x07WARP\x01!");
        }
        case TANK_COBALT: {
            SetEntityRenderColor(client, 0, 105, 255, 255);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank \x07COBALTO\x01!");
        }
        case TANK_SPAWN: {
            SetEntityRenderColor(client, 75, 95, 105, 255);
            PrintToChatAll("\x04[T-T]\x01 Ha aparecido un Tank \x07INFECCIOSO\x01!");
        }
    }
}

// ================= MOTOR DE TRAYECTORIAS Y HABILIDADES =================
public Action Timer_TankEngine(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && g_iTankType[i] != TANK_NONE) {
            float vel[3], pos[3];
            GetEntPropVector(i, Prop_Data, "m_vecVelocity", vel);
            GetClientAbsOrigin(i, pos);
            
            float speed = GetVectorLength(vel);

            if (g_iTankType[i] == TANK_FIRE && speed > 50.0) {
                int fire = CreateEntityByName("env_fire");
                if (fire != -1) {
                    DispatchKeyValue(fire, "firesize", "50");
                    DispatchKeyValue(fire, "health", "2"); 
                    DispatchKeyValue(fire, "fireattack", "2");
                    DispatchSpawn(fire);
                    TeleportEntity(fire, pos, NULL_VECTOR, NULL_VECTOR);
                    AcceptEntityInput(fire, "StartFire");
                    
                    char addoutput[64];
                    Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::2.0:1");
                    SetVariantString(addoutput);
                    AcceptEntityInput(fire, "AddOutput");
                    AcceptEntityInput(fire, "FireUser1");
                }
            }
            
            if (g_iTankType[i] == TANK_COBALT) {
                SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.5); 
                if (speed > 50.0) CreateBlurEffect(i, pos);
            }
            
            if (g_iTankType[i] == TANK_WARP) {
                if (GetGameTime() >= g_fNextWarp[i]) {
                    WarpToSurvivor(i);
                    g_fNextWarp[i] = GetGameTime() + GetRandomFloat(10.0, 15.0);
                }
            }
        }
    }
    return Plugin_Continue;
}

void CreateBlurEffect(int client, float pos[3]) {
    float ang[3];
    GetClientAbsAngles(client, ang);
    int anim = GetEntProp(client, Prop_Send, "m_nSequence");
    int entity = CreateEntityByName("prop_dynamic");
    if (entity != -1) {
        DispatchKeyValue(entity, "model", "models/infected/hulk.mdl");
        DispatchSpawn(entity);
        AcceptEntityInput(entity, "DisableCollision");
        SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
        SetEntityRenderColor(entity, 0, 105, 255, 100);
        SetEntProp(entity, Prop_Send, "m_nSequence", anim);
        SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 0.0);
        TeleportEntity(entity, pos, ang, NULL_VECTOR);
        
        char addoutput[64];
        Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::0.25:1");
        SetVariantString(addoutput);
        AcceptEntityInput(entity, "AddOutput");
        AcceptEntityInput(entity, "FireUser1");
    }
}

void WarpToSurvivor(int tank) {
    int validSurvivors[MAXPLAYERS];
    int count = 0;
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
            validSurvivors[count++] = i;
        }
    }
    
    if (count > 0) {
        int target = validSurvivors[GetRandomInt(0, count - 1)];
        float survPos[3], warpPos[3];
        GetClientAbsOrigin(target, survPos);
        
        float angle = GetRandomFloat(0.0, 360.0) * 3.14159 / 180.0;
        float distance = GetRandomFloat(300.0, 450.0);
        
        warpPos[0] = survPos[0] + (distance * Cosine(angle));
        warpPos[1] = survPos[1] + (distance * Sine(angle));
        warpPos[2] = survPos[2] + 20.0;
        
        Handle trace = TR_TraceRayFilterEx(survPos, warpPos, MASK_SOLID, RayType_EndPoint, TraceFilter_NoPlayers);
        if (TR_DidHit(trace)) {
            TR_GetEndPosition(warpPos, trace);
            float dir[3];
            MakeVectorFromPoints(warpPos, survPos, dir);
            NormalizeVector(dir, dir);
            ScaleVector(dir, 60.0);
            AddVectors(warpPos, dir, warpPos);
        }
        CloseHandle(trace);
        
        TeleportEntity(tank, warpPos, NULL_VECTOR, NULL_VECTOR);
        EmitSoundToAll("ambient/energy/zap1.wav", tank);
        ScreenFade(target, 150, 0, 255, 100, 1.0); 
    }
}

public bool TraceFilter_NoPlayers(int entity, int contentsMask) {
    return entity > MaxClients;
}

// ================= EFECTOS AL GOLPEAR CON LAS GARRAS =================
public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
    
    if (victim > 0 && victim <= MaxClients && g_iTankType[victim] == TANK_FIRE) {
        if (damagetype & DMG_BURN || damagetype & DMG_SLOWBURN) {
            damage = 0.0;
            return Plugin_Handled; 
        }
    }

    if (attacker > 0 && attacker <= MaxClients && g_iTankType[attacker] != TANK_NONE) {
        if (victim > 0 && victim <= MaxClients && GetClientTeam(victim) == 2) {
            char classname[32];
            GetEdictClassname(inflictor, classname, sizeof(classname));
            
            if (StrEqual(classname, "weapon_tank_claw") || StrEqual(classname, "weapon_tank_rock")) {
                
                if (g_iTankType[attacker] == TANK_FIRE) {
                    IgniteEntity(victim, 4.0);
                    ScreenFade(victim, 100, 50, 0, 150, 1.5);
                } 
                else if (g_iTankType[attacker] == TANK_ICE) {
                    if (GetRandomInt(1, 3) == 1) {
                        SetEntityRenderMode(victim, RENDER_TRANSCOLOR);
                        SetEntityRenderColor(victim, 0, 100, 170, 180);
                        SetEntityMoveType(victim, MOVETYPE_VPHYSICS);
                        CreateTimer(3.0, Timer_UnFreeze, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
                        ScreenFade(victim, 0, 50, 100, 150, 1.5);
                    }
                }
                else if (g_iTankType[attacker] == TANK_SPAWN) {
                    // SDKCall Directo desde gamedata[cite: 1]
                    if (g_hSDKVomitOnPlayer != null) {
                        SDKCall(g_hSDKVomitOnPlayer, victim, attacker, true);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_UnFreeze(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
        SetEntityMoveType(client, MOVETYPE_WALK);
    }
    return Plugin_Stop;
}

// ================= GESTIÓN DE ROCAS Y COLISIONES =================
public void OnEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "tank_rock")) {
        SDKHook(entity, SDKHook_Touch, Hook_RockTouch);
        CreateTimer(0.1, Timer_ModifyRock, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_ModifyRock(Handle timer, any ref) {
    int entity = EntRefToEntIndex(ref);
    if (entity != INVALID_ENT_REFERENCE) {
        int thrower = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
        if (thrower > 0 && thrower <= MaxClients && g_iTankType[thrower] != TANK_NONE) {
            
            g_iRockType[entity] = g_iTankType[thrower]; 
            
            if (g_iTankType[thrower] == TANK_FIRE) {
                SetEntityRenderColor(entity, 128, 0, 0, 255);
                IgniteEntity(entity, 100.0);
            } 
            else if (g_iTankType[thrower] == TANK_ICE) {
                SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
                SetEntityRenderColor(entity, 0, 100, 255, 180);
            } 
            else if (g_iTankType[thrower] == TANK_SPITTER) {
                SetEntityRenderColor(entity, 50, 255, 50, 255);
            }
        }
    }
    return Plugin_Stop;
}

public Action Hook_RockTouch(int entity, int other) {
    if (g_iRockType[entity] == TANK_SPITTER) {
        float pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        
        // Evitar multiples activaciones
        g_iRockType[entity] = TANK_NONE; 
        
        // Crear un bot falso temporal[cite: 1]
        int bot = CreateFakeClient("Spitter");
        if (bot > 0) {
            TeleportEntity(bot, pos, NULL_VECTOR, NULL_VECTOR);
            if (g_hSDKSpitBurst != null) {
                SDKCall(g_hSDKSpitBurst, bot, true);
            }
            KickClient(bot);
        }
        
        // Destruir roca de inmediato para evitar efecto rana
        AcceptEntityInput(entity, "Kill"); 
    }
    return Plugin_Continue;
}

// ================= MENU DE DEPURACION =================
public Action Command_TankMenu(int client, int args) {
    if (client == 0) return Plugin_Handled;
    
    Menu menu = new Menu(MenuHandler_TankMenu);
    menu.SetTitle("Menu Mutaciones de Tank");
    menu.AddItem("1", "Spawn FIRE Tank");
    menu.AddItem("2", "Spawn ICE Tank");
    menu.AddItem("3", "Spawn SPITTER Tank");
    menu.AddItem("4", "Spawn WARP Tank");
    menu.AddItem("5", "Spawn COBALT Tank");
    menu.AddItem("6", "Spawn INFECTION Tank");
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int MenuHandler_TankMenu(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        g_bForceSpawn = true;
        g_iForcedType = StringToInt(info); 
        
        int flags = GetCommandFlags("z_spawn");
        SetCommandFlags("z_spawn", flags & ~FCVAR_CHEAT);
        FakeClientCommand(param1, "z_spawn tank auto"); 
        SetCommandFlags("z_spawn", flags);
        
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ScreenFade(int client, int r, int g, int b, int alpha, float duration) {
    Handle msg = StartMessageOne("Fade", client);
    if (msg != INVALID_HANDLE) {
        BfWriteShort(msg, RoundFloat(duration * 400.0));
        BfWriteShort(msg, RoundFloat(duration * 400.0));
        BfWriteShort(msg, 0x0001);
        BfWriteByte(msg, r);
        BfWriteByte(msg, g);
        BfWriteByte(msg, b);
        BfWriteByte(msg, alpha);
        EndMessage();
    }
}