#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

// ConVars
ConVar cvarGlowColorRed, cvarGlowColorGreen, cvarGlowColorBlue, cvarGlowFlash;
ConVar cvarTimeExplode, cvarChanceProp, cvarDamage, cvarRadius;
ConVar cvarPropHealth, cvarDebugHP, cvarPluginEnabled, cvarShootDestroy;

// Variables cache
int   GlowColorRed, GlowColorGreen, GlowColorBlue, GlowFlash, PropHealth;
float TimeExplode, ModelChance, iRadius, ExplosionDamage;
bool  g_bPluginEnabled, g_bDebugHP, g_bShootDestroy;

// Sonidos / Particulas
#define SOUND_SPAWN      "plats/churchbell_end.wav"
#define EXPLOSION_SOUND  "animation/bombing_run_01.wav"
#define EXPLOSION        "weapon_grenade_explosion"
#define SPAWN_EFFECT     "electrical_arc_01_system"
#define EXPLOSION_HUGE   "gas_explosion_main"

// Modelos — tomados de TankUltraPropsRocks (16 modelos)
static const char g_sModels[][PLATFORM_MAX_PATH] =
{
    "models/props_vehicles/cara_69sedan.mdl",                       // 0  – auto sedan
    "models/props_vehicles/police_car_city.mdl",                    // 1  – patrulla ciudad
    "models/props_vehicles/police_car_rural.mdl",                   // 2  – patrulla rural
    "models/props_vehicles/airport_baggage_cart2.mdl",              // 3  – carrito aeropuerto
    "models/props_vehicles/floodlight_generator_pose01_static.mdl", // 4  – generador
    "models/props_fairgrounds/swan_boat.mdl",                       // 7  – bote cisne
    "models/props_foliage/tree_trunk_fallen.mdl",                   // 10 – tronco caido
    "models/props/cs_militia/militiarock01.mdl",                    // 11 – roca
    "models/props_debris/concrete_chunk01a.mdl",                    // 12 – bloque hormigon
    "models/props_interiors/couch.mdl",                             // 13 – sofa
    "models/props_unique/airport/atlas_break_ball.mdl",              // 15 – bola gigante
    "models/props_foliage/tree_trunk.mdl"
};
#define MODEL_COUNT 16

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name        = "[L4D2] Tank Props Throw v3",
    author      = "King_OXO, [T-T]MOY (edit)",
    description = "Tank lanza props en lugar de roca. 16 modelos, sistema de disparo opcional.",
    version     = "3.0.0",
    url         = "www.sourcemod.com"
};

public void OnPluginStart()
{
    cvarPluginEnabled  = CreateConVar("l4d2_tank_props_enabled",        "1",      "Activa/desactiva el plugin: 1=ON, 0=OFF",                        FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarGlowColorRed   = CreateConVar("l4d2_prop_glow_red",             "255",    "Color Rojo del glow (0-255)",                                    FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvarGlowColorGreen = CreateConVar("l4d2_prop_glow_green",           "0",      "Color Verde del glow (0-255)",                                   FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvarGlowColorBlue  = CreateConVar("l4d2_prop_glow_blue",            "0",      "Color Azul del glow (0-255)",                                    FCVAR_NOTIFY, true, 0.0, true, 255.0);
    cvarGlowFlash      = CreateConVar("l4d2_prop_glow_flash",           "1",      "El borde del prop parpadea: 1=Si, 0=No",                         FCVAR_NOTIFY);
    cvarChanceProp     = CreateConVar("l4d2_prop_chance",               "100",    "Probabilidad de que aparezca un prop (0-100)",                   FCVAR_NOTIFY, true, 0.0, true, 100.0);
    cvarTimeExplode    = CreateConVar("l4d2_prop_timer_explode",        "50",     "Segundos antes de que el prop explote solo",                     FCVAR_NOTIFY);
    cvarDamage         = CreateConVar("l4d2_prop_explosion_damage",     "1",      "Dano al explotar el prop",                                       FCVAR_NOTIFY);
    cvarRadius         = CreateConVar("l4d2_prop_explosion_radius",     "1",      "Radio de explosion del prop",                                    FCVAR_NOTIFY);
    cvarShootDestroy   = CreateConVar("l4d2_prop_shoot_destroy",        "1",      "Sobrevivientes pueden destruir el prop a tiros: 1=Si, 0=No",     FCVAR_NOTIFY, true, 0.0, true, 1.0);
    cvarPropHealth     = CreateConVar("l4d2_prop_health",               "1800",   "Vida del prop (solo si l4d2_prop_shoot_destroy=1)",              FCVAR_NOTIFY);
    cvarDebugHP        = CreateConVar("l4d2_prop_debug_hp",             "1",      "MODO TEST: muestra HP del prop al dispararle. 1=ON, 0=OFF",      FCVAR_NOTIFY, true, 0.0, true, 1.0);

    UpdateConVarValues();

    cvarPluginEnabled .AddChangeHook(OnTPRCVarsChanged);
    cvarGlowColorRed  .AddChangeHook(OnTPRCVarsChanged);
    cvarGlowColorGreen.AddChangeHook(OnTPRCVarsChanged);
    cvarGlowColorBlue .AddChangeHook(OnTPRCVarsChanged);
    cvarGlowFlash     .AddChangeHook(OnTPRCVarsChanged);
    cvarChanceProp    .AddChangeHook(OnTPRCVarsChanged);
    cvarTimeExplode   .AddChangeHook(OnTPRCVarsChanged);
    cvarDamage        .AddChangeHook(OnTPRCVarsChanged);
    cvarRadius        .AddChangeHook(OnTPRCVarsChanged);
    cvarShootDestroy  .AddChangeHook(OnTPRCVarsChanged);
    cvarPropHealth    .AddChangeHook(OnTPRCVarsChanged);
    cvarDebugHP       .AddChangeHook(OnTPRCVarsChanged);

    RegAdminCmd("sm_tankprops", Command_TankProps, ADMFLAG_GENERIC, "Uso: sm_tankprops [0/1]");
    RegAdminCmd("sm_prophp",    Command_DebugHP,   ADMFLAG_GENERIC, "Activa/Desactiva debug HP del prop");

    HookEvent("player_hurt", Player_Hurt);

    AutoExecConfig(true, "l4d2_tank_props");
}

void UpdateConVarValues()
{
    g_bPluginEnabled = cvarPluginEnabled .BoolValue;
    GlowColorRed     = cvarGlowColorRed  .IntValue;
    GlowColorGreen   = cvarGlowColorGreen.IntValue;
    GlowColorBlue    = cvarGlowColorBlue .IntValue;
    GlowFlash        = cvarGlowFlash     .IntValue;
    ModelChance      = cvarChanceProp    .FloatValue;
    TimeExplode      = cvarTimeExplode   .FloatValue;
    ExplosionDamage  = cvarDamage        .FloatValue;
    iRadius          = cvarRadius        .FloatValue;
    g_bShootDestroy  = cvarShootDestroy  .BoolValue;
    PropHealth       = cvarPropHealth    .IntValue;
    g_bDebugHP       = cvarDebugHP       .BoolValue;
}

public void OnTPRCVarsChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    UpdateConVarValues();
}

// ---- Comandos admin ----

public Action Command_TankProps(int client, int args)
{
    if (!client) return Plugin_Handled;
    if (args >= 1)
    {
        char arg[8];
        GetCmdArg(1, arg, sizeof(arg));
        int value = StringToInt(arg);
        if (value == 1)      { cvarPluginEnabled.SetBool(true);  PrintToChatAll("[SM] Tank Props: \x04Activado"); }
        else if (value == 0) { cvarPluginEnabled.SetBool(false); PrintToChatAll("[SM] Tank Props: \x02Desactivado"); }
        return Plugin_Handled;
    }
    cvarPluginEnabled.SetBool(!g_bPluginEnabled);
    PrintToChatAll("[SM] Tank Props: %s", g_bPluginEnabled ? "\x04Activado" : "\x02Desactivado");
    return Plugin_Handled;
}

public Action Command_DebugHP(int client, int args)
{
    cvarDebugHP.SetBool(!g_bDebugHP);
    PrintToChatAll("[SM] Debug HP Prop: %s", g_bDebugHP ? "\x04ENCENDIDO" : "\x02APAGADO");
    return Plugin_Handled;
}

// ---- Precache ----

public void OnMapStart()
{
    for (int i = 0; i < MODEL_COUNT; i++)
        CheckModelPreCache(g_sModels[i]);

    PrecacheSound(SOUND_SPAWN,     true);
    PrecacheSound(EXPLOSION_SOUND, true);
    PrecacheParticle(EXPLOSION_HUGE);
    PrecacheParticle(SPAWN_EFFECT);
    PrecacheParticle(EXPLOSION);
}

stock void CheckModelPreCache(const char[] Modelfile)
{
    if (!IsModelPrecached(Modelfile))
    {
        PrecacheModel(Modelfile, true);
        PrintToServer("Model: %s precacheado", Modelfile);
    }
}

// ---- Deteccion de roca ----

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "tank_rock", false))
        RequestFrame(OnTankRockNextFrame, EntIndexToEntRef(entity));
}

void OnTankRockNextFrame(int iEntRef)
{
    if (!IsValidEntRef(iEntRef))
        return;

    int entity = EntRefToEntIndex(iEntRef);
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

    if (!IsValidClient(client))
        return;
    if (!IsPlayerAlive(client))
        return;
    if (GetClientTeam(client) != 3)
        return;

    CreateTimer(0.1, Throw, entity, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

// ---- Sistema de lanzamiento ----

Action Throw(Handle timer, int entity)
{
    float velocity[3];
    if (IsValidEntity(entity))
    {
        int g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
        GetEntDataVector(entity, g_iVelocity, velocity);
        float v = GetVectorLength(velocity);

        if (v > 0.1)
        {
            if (!g_bPluginEnabled)
                return Plugin_Stop;

            int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
            float Pos[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Pos);

            if (GetRandomFloat(0.0, 100.0) < ModelChance)
            {
                if (IsValidClient(client))
                {
                    Handle msg = StartMessageOne("Shake", client);
                    BfWriteByte(msg, 0);
                    BfWriteFloat(msg, 20.0);
                    BfWriteFloat(msg, 8.0);
                    BfWriteFloat(msg, 5.0);
                    EndMessage();
                }

                int physics = CreateEntityByName("prop_physics_multiplayer");
                if (IsValidEntity(physics))
                {
                    int Model = GetRandomInt(0, MODEL_COUNT - 1);
                    SetEntityModel(physics, g_sModels[Model]);

                    RemoveEntity(entity);

                    ShowParticle(Pos, SPAWN_EFFECT);
                    EmitSoundToAll(SOUND_SPAWN, client);

                    // FIX COLISIONES: physdamagescale 0 antes del spawn
                    // evita knockback/camara-ruleta cuando el prop golpea a un jugador
                    DispatchKeyValue(physics, "physdamagescale", "0");

                    DispatchSpawn(physics);

                    // COLLISION_GROUP_DEBRIS_TRIGGER (6) despues del spawn:
                    // - el prop colisiona con el mundo normalmente
                    // - NO lanza al jugador cuando lo toca o cae encima
                    SetEntProp(physics, Prop_Data, "m_CollisionGroup", 6);

                    float speed = GetConVarFloat(FindConVar("z_tank_throw_force"));
                    ScaleVector(velocity, speed * 2.0);
                    TeleportEntity(physics, Pos, NULL_VECTOR, velocity);

                    CreateTimer(TimeExplode, Explosion, physics);

                    SetEntProp(physics, Prop_Send, "m_glowColorOverride", GlowColorRed + (GlowColorGreen * 256) + (GlowColorBlue * 65536));
                    SetEntProp(physics, Prop_Send, "m_iGlowType", 3);
                    SetEntProp(physics, Prop_Send, "m_bFlashing", GlowFlash);

                    if (g_bShootDestroy)
                    {
                        SetEntityHealth(physics, PropHealth);
                        SDKHook(physics, SDKHook_OnTakeDamage, OnPropTakeDamage);
                    }
                }
            }
            return Plugin_Stop;
        }
    }
    else
    {
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

// ---- Sistema de disparo al prop ----

public Action OnPropTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidEntity(victim)) return Plugin_Continue;

    int currentHP = GetEntProp(victim, Prop_Data, "m_iHealth");
    int newHP     = currentHP - RoundToFloor(damage);

    SetEntProp(victim, Prop_Data, "m_iHealth", newHP);

    if (g_bDebugHP)
    {
        if (newHP > 0)
            PrintCenterTextAll(">>> PROP HP: %d / %d <<<", newHP, PropHealth);
        else
            PrintCenterTextAll(">>> PROP DESTRUIDO <<<");
    }

    if (newHP <= 0)
    {
        float Pos[3];
        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", Pos);
        RemoveEntity(victim);
        ExplodeMain(Pos);
        return Plugin_Handled;
    }

    SetEntProp(victim, Prop_Send, "m_glowColorOverride", GlowColorRed + (GlowColorGreen * 256) + (GlowColorBlue * 65536));
    SetEntProp(victim, Prop_Send, "m_iGlowType", 3);

    damage = 0.0;
    return Plugin_Changed;
}

// ---- Explosion por timer ----

public Action Explosion(Handle timer, int physics)
{
    if (IsValidEntity(physics))
    {
        float Pos[3];
        GetEntPropVector(physics, Prop_Send, "m_vecOrigin", Pos);
        RemoveEntity(physics);
        ExplodeMain(Pos);
    }
    return Plugin_Stop;
}

void ExplodeMain(float Pos[3])
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsSurvivor(i)) continue;
        float sPos[3];
        GetClientAbsOrigin(i, sPos);
        if (GetVectorDistance(Pos, sPos) <= iRadius)
            SurvivorReaction(i, Pos, ExplosionDamage);
    }
    ShowParticle(Pos, EXPLOSION_HUGE);
    EmitSoundToAll(EXPLOSION_SOUND);
}

// ---- Player_Hurt ----

public void Player_Hurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPluginEnabled) return;

    int client   = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    if (StrEqual(weapon, "tank_rock", true) && IsTank(attacker))
    {
        float Pos[3];
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", Pos);
        MiniExplosion(Pos, client);
    }
}

void MiniExplosion(float Pos[3], int victim)
{
    SurvivorReaction(victim, Pos, 15.0);
    ShowParticle(Pos, EXPLOSION);
    EmitSoundToAll(EXPLOSION_SOUND, victim);
}

// ---- Helpers ----

void PrecacheParticle(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    if (table == INVALID_STRING_TABLE)
        table = FindStringTable("ParticleEffectNames");

    if (FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX)
    {
        bool save = LockStringTables(false);
        AddToStringTable(table, sEffectName);
        LockStringTables(save);
    }
}

void ShowParticle(float Pos[3], char[] particlename)
{
    int particle = CreateEntityByName("info_particle_system");
    if (particle == -1) return;

    DispatchKeyValue(particle, "effect_name", particlename);
    DispatchSpawn(particle);
    ActivateEntity(particle);
    AcceptEntityInput(particle, "start");
    TeleportEntity(particle, Pos, NULL_VECTOR, NULL_VECTOR);
    SetVariantString("OnUser1 !self:Kill::1.0:1");
    AcceptEntityInput(particle, "AddOutput");
    AcceptEntityInput(particle, "FireUser1");
}

public bool bTraceEntityFilterPlayer(int entity, int contentsMask)
{
    return (entity > MaxClients || !entity);
}

bool IsValidEntRef(int iEntRef)
{
    return iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE;
}

bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
}

bool IsTank(int client)
{
    if (!IsValidClient(client) || GetClientTeam(client) != 3) return false;
    return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

stock bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock void SurvivorReaction(int target, float vPos[3], float damage)
{
    if (target < 1 || target > MaxClients) return;
    if (!IsClientInGame(target) || !IsPlayerAlive(target)) return;

    SDKHooks_TakeDamage(target, 0, 0, damage, DMG_BLAST);

    Handle msg = StartMessageOne("Shake", target);
    BfWriteByte(msg, 0);
    BfWriteFloat(msg, 20.0);
    BfWriteFloat(msg, 8.0);
    BfWriteFloat(msg, 5.0);
    EndMessage();

    StaggerClient(GetClientUserId(target), vPos);
}

void StaggerClient(int iUserID, const float fPos[3])
{
    static int iScriptLogic = INVALID_ENT_REFERENCE;
    if (iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
    {
        iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
        if (iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
        {
            LogError("[TankProps] No se pudo crear logic_script");
            return;
        }
        DispatchSpawn(iScriptLogic);
    }

    char sBuffer[96];
    Format(sBuffer, sizeof(sBuffer),
        "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))",
        iUserID, RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));
    SetVariantString(sBuffer);
    AcceptEntityInput(iScriptLogic, "RunScriptCode");
    RemoveEntity(iScriptLogic);
    iScriptLogic = INVALID_ENT_REFERENCE;
}
