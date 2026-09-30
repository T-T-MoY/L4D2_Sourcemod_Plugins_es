#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

// ConVars
ConVar cvarGlowFlash, cvarTimeExplode, cvarDamage, cvarRadius, cvarPropHealth, cvarDebugHP;
ConVar cvarPluginEnabled;

// Variables
int GlowFlash, PropHealth;
float TimeExplode, iRadius, ExplosionDamage;
bool g_bPluginEnabled = true;
bool g_bDebugHP = false;

// Entity's And Sound's
#define SOUND_SPAWN        "plats/churchbell_end.wav"
#define EXPLOSION_SOUND    "animation/bombing_run_01.wav"
#define EXPLOSION          "weapon_grenade_explosion"
#define SPAWN_EFFECT       "electrical_arc_01_system"
#define EXPLOSION_HUGE     "gas_explosion_main"

public Plugin myinfo = 
{
    name        = "[L4D2] Tank Destructible Props (Final)",
    author      = "King_OXO, [T-T]MOY(edit)",
    description = "Tank throws props that can be destroyed. Includes debug mode.",
    version     = "4.2.0",
    url         = "www.sourcemod.com"
};

public void OnPluginStart()
{
    // --- CONFIGURACIÓN DE CONVARS ---
    
    cvarPluginEnabled     = CreateConVar("l4d2_tank_props_enabled", "1", "Activa/desactiva el plugin: 1=ON, 0=OFF", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // Visuales
    cvarGlowFlash         = CreateConVar("l4d2_prop_glow_flash", "1", "El borde parpadea? 1=Si, 0=No", FCVAR_NOTIFY);
    
    // Debug
    cvarDebugHP           = CreateConVar("l4d2_prop_debug_hp", "0", "MODO TEST: Muestra la vida del prop al dispararle. 1=ON, 0=OFF", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // Mecánicas
    cvarTimeExplode       = CreateConVar("l4d2_prop_timer_explode", "30.0", "Tiempo en segundos para que explote solo", FCVAR_NOTIFY);
    cvarDamage            = CreateConVar("l4d2_prop_explosion_damage", "2.0", "Daño que hace al explotar", FCVAR_NOTIFY);    
    cvarRadius            = CreateConVar("l4d2_prop_explosion_radius", "1.0", "Radio de la explosion", FCVAR_NOTIFY);    
    cvarPropHealth        = CreateConVar("l4d2_prop_health", "1500", "Vida del objeto (HP)", FCVAR_NOTIFY);

    UpdateConVarValues();
    
    // Hooks
    cvarGlowFlash.AddChangeHook(OnTPRCVarsChanged);
    cvarTimeExplode.AddChangeHook(OnTPRCVarsChanged);
    cvarPluginEnabled.AddChangeHook(OnTogglePlugin);
    cvarDamage.AddChangeHook(OnTPRCVarsChanged);
    cvarRadius.AddChangeHook(OnTPRCVarsChanged);
    cvarPropHealth.AddChangeHook(OnTPRCVarsChanged);
    cvarDebugHP.AddChangeHook(OnTPRCVarsChanged);
    
    // Comandos
    RegAdminCmd("sm_tankprops", Command_TankProps, ADMFLAG_GENERIC, "Uso: sm_tankprops [0/1]");
    RegAdminCmd("sm_prophp", Command_DebugHP, ADMFLAG_GENERIC, "Activa/Desactiva el visualizador de vida del prop");
    
    HookEvent("player_hurt", Player_Hurt);
    
    AutoExecConfig(true, "l4d_tank_props_destructible");
}

public void UpdateConVarValues()
{
    GlowFlash         = cvarGlowFlash.IntValue;
    ExplosionDamage   = cvarDamage.FloatValue;
    TimeExplode       = cvarTimeExplode.FloatValue;
    iRadius           = cvarRadius.FloatValue;
    g_bPluginEnabled  = cvarPluginEnabled.BoolValue;
    PropHealth        = cvarPropHealth.IntValue;
    g_bDebugHP        = cvarDebugHP.BoolValue;
}

public void OnTPRCVarsChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    UpdateConVarValues();
}

public void OnTogglePlugin(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_bPluginEnabled = convar.BoolValue;
}

// --- MODIFICACIÓN SOLICITADA: SOPORTE PARA 0 y 1 ---
public Action Command_TankProps(int client, int args)
{
    if (!client) return Plugin_Handled;

    // Si el usuario escribe un argumento (ej: sm_tankprops 1)
    if (args >= 1)
    {
        char arg[8];
        GetCmdArg(1, arg, sizeof(arg));
        int value = StringToInt(arg);

        if (value == 1)
        {
             g_bPluginEnabled = true;
             cvarPluginEnabled.SetBool(true);
             PrintToChatAll("[SM] Tank Destructible Props: \x04Activado");
             return Plugin_Handled;
        }
        else if (value == 0)
        {
             g_bPluginEnabled = false;
             cvarPluginEnabled.SetBool(false);
             PrintToChatAll("[SM] Tank Destructible Props: \x02Desactivado");
             return Plugin_Handled;
        }
    }

    // Si no escribe nada, simplemente alterna (Toggle)
    g_bPluginEnabled = !g_bPluginEnabled;
    cvarPluginEnabled.SetBool(g_bPluginEnabled);
    PrintToChatAll("[SM] Tank Destructible Props: %s", g_bPluginEnabled ? "\x04Activado" : "\x02Desactivado");

    return Plugin_Handled;
}
// ---------------------------------------------------

public Action Command_DebugHP(int client, int args)
{
    g_bDebugHP = !g_bDebugHP;
    cvarDebugHP.SetBool(g_bDebugHP);
    PrintToChatAll("[SM] Debug de Vida Prop: %s", g_bDebugHP ? "\x04ENCENDIDO" : "\x02APAGADO");
    return Plugin_Handled;
}

public void OnMapStart()
{
    CheckModelPreCache("models/props_foliage/tree_trunk_fallen.mdl");
    CheckModelPreCache("models/props/cs_militia/militiarock01.mdl");
    CheckModelPreCache("models/props_vehicles/airport_baggage_cart2.mdl");
    
    PrecacheSound(SOUND_SPAWN, true);
    PrecacheSound(EXPLOSION_SOUND, true);
    PrecacheParticle(EXPLOSION_HUGE);
    PrecacheParticle(SPAWN_EFFECT);
    PrecacheParticle(EXPLOSION);
}

stock void CheckModelPreCache(const char[] Modelfile)
{
    if (!IsModelPrecached(Modelfile)) PrecacheModel(Modelfile, true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bPluginEnabled) return;
    if (StrEqual(classname, "tank_rock", false))
        RequestFrame(OnTankRockNextFrame, EntIndexToEntRef(entity));
}

void OnTankRockNextFrame(int iEntRef)
{
    if (!g_bPluginEnabled || !IsValidEntRef(iEntRef)) return;
    
    int entity = EntRefToEntIndex(iEntRef);
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if (!IsValidClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 3) return;
    
    CreateTimer(0.1, Throw, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action Throw(Handle timer, int entity)
{
    if (!g_bPluginEnabled || !IsValidEntity(entity)) return Plugin_Stop;
    
    float velocity[3];
    int g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");    
    GetEntDataVector(entity, g_iVelocity, velocity);
    float v = GetVectorLength(velocity);
    
    if (v > 0.1)
    {
        int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        float Pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Pos);  
        
        int physics = CreateEntityByName("prop_physics_multiplayer");
        if (IsValidEntity(physics))
        {
            int Model = GetRandomInt(0, 2);
            switch(Model)
            {
                case 0: SetEntityModel(physics, "models/props_foliage/tree_trunk_fallen.mdl");
                case 1: SetEntityModel(physics, "models/props/cs_militia/militiarock01.mdl");
                case 2: SetEntityModel(physics, "models/props_vehicles/airport_baggage_cart2.mdl");
            }
            
            RemoveEntity(entity);
            ShowParticle(Pos, SPAWN_EFFECT);
            EmitSoundToAll(SOUND_SPAWN, client);
            DispatchSpawn(physics);
            
            float speed = GetConVarFloat(FindConVar("z_tank_throw_force"));
            ScaleVector(velocity, speed * 2.0);
            TeleportEntity(physics, Pos, NULL_VECTOR, velocity);
            
            CreateTimer(TimeExplode, Explosion, physics);
            
            // Vida y Hook
            SetEntityHealth(physics, PropHealth);
            SDKHook(physics, SDKHook_OnTakeDamage, OnPropTakeDamage);
            
            // Glow Rojo Fijo
            SetGlowColor(physics, 255, 0, 0);
            SetEntProp(physics, Prop_Send, "m_bFlashing", GlowFlash);
        }
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action OnPropTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidEntity(victim)) return Plugin_Continue;

    int currentHealth = GetEntProp(victim, Prop_Data, "m_iHealth");
    int newHealth = currentHealth - RoundToFloor(damage);
    
    if (g_bDebugHP)
    {
        if (newHealth > 0)
            PrintCenterTextAll(">>> PROP HP: %d / %d <<<", newHealth, PropHealth);
        else
            PrintCenterTextAll(">>> PROP DESTRUIDO <<<");
    }

    if (newHealth <= 0)
    {
        Explosion(INVALID_HANDLE, victim);
        return Plugin_Handled; 
    }

    // Glow Rojo Siempre
    SetGlowColor(victim, 255, 0, 0);
    
    return Plugin_Continue;
}

void SetGlowColor(int entity, int r, int g, int b)
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", r + (g * 256) + (b * 65536));
    SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
}

public Action Explosion(Handle timer, int physics)
{
    if(IsValidEntity(physics))
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
        if (IsSurvivor(i))
        {
            float SurvivorPoS[3];
            GetClientAbsOrigin(i, SurvivorPoS);
            float distance = GetVectorDistance(Pos, SurvivorPoS);
            if (distance <= iRadius)
            {
                SurvivorReaction(i, ExplosionDamage);
            }
        }
    }
    ShowParticle(Pos, EXPLOSION_HUGE);
}

void MiniExplosion(float Pos[3], int victim)
{
    SurvivorReaction(victim, 15.0);
    ShowParticle(Pos, EXPLOSION);
}

void PrecacheParticle(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    if( table == INVALID_STRING_TABLE ) table = FindStringTable("ParticleEffectNames");
    if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
    {
        bool save = LockStringTables(false);
        AddToStringTable(table, sEffectName);
        LockStringTables(save);
    }
}

void ShowParticle( float Pos[3], char[] particlename )
{
    int particle = CreateEntityByName("info_particle_system");
    if( particle != -1 )
    {
        DispatchKeyValue(particle, "effect_name", particlename);
        DispatchSpawn(particle);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        TeleportEntity(particle, Pos, NULL_VECTOR, NULL_VECTOR);
        SetVariantString("OnUser1 !self:Kill::1.0:1");
        AcceptEntityInput(particle, "AddOutput");
        AcceptEntityInput(particle, "FireUser1"); 
    }
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
    if (IsValidClient(client) && GetClientTeam(client) == 3)
    {
        int class = GetEntProp(client, Prop_Send, "m_zombieClass");
        if (class == 8) return true;
    }
    return false;
}

stock bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock void SurvivorReaction(int target, float damage)
{
    if (target > 0 && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target))
    {
        SDKHooks_TakeDamage(target, 0, 0, damage, DMG_BLAST);
        Handle msg = StartMessageOne("Shake", target);
        BfWriteByte(msg, 0);
        BfWriteFloat(msg, 20.0);
        BfWriteFloat(msg, 8.0);
        BfWriteFloat(msg, 5.0);
        EndMessage();
    }
}

public void Player_Hurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPluginEnabled) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
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