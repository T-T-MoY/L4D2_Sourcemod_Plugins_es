#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION  "1.1"
#define GAMEDATA_FILE   "survivor_shoving"

// ------------------------------------------------------------
// Globals
// ------------------------------------------------------------

Handle  g_hSDKStagger;      // CTerrorPlayer::OnStaggered
ConVar  g_hCvarEnable;      // sm_survivorshoving_enable

// ------------------------------------------------------------
// Plugin info
// ------------------------------------------------------------

public Plugin myinfo =
{
    name        = "Survivor Shoving",
    author      = "[T-T]MoY",
    description = "Survivors that shove each other receive a real engine stagger + friendly fire vocalize",
    version     = PLUGIN_VERSION,
    url         = ""
};

// ------------------------------------------------------------
// OnPluginStart
// ------------------------------------------------------------

public void OnPluginStart()
{
    // --- ConVar ---
    g_hCvarEnable = CreateConVar(
        "sm_survivorshoving_enable",
        "1",
        "0 = Plugin desactivado | 1 = Plugin activado",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    AutoExecConfig(true, "survivor_shoving");

    // --- Gamedata / SDKCall ---
    GameData hGameData = new GameData(GAMEDATA_FILE);
    if (hGameData == null)
        SetFailState("No se pudo cargar el gamedata '%s.txt'.", GAMEDATA_FILE);

    StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer_OnStaggered"))
        SetFailState("No se encontró la firma 'CTerrorPlayer_OnStaggered' en el gamedata.");

    // Parámetros: (CBaseEntity* source, Vector const* staggerDir)
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_Vector,      SDKPass_ByRef);

    g_hSDKStagger = EndPrepSDKCall();
    if (g_hSDKStagger == null)
        SetFailState("EndPrepSDKCall falló para 'CTerrorPlayer_OnStaggered'.");

    delete hGameData;

    // --- Evento ---
    HookEvent("player_shoved", Event_PlayerShoved);
}

// ------------------------------------------------------------
// player_shoved
// ------------------------------------------------------------

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
    // Checar si el plugin está habilitado
    if (!g_hCvarEnable.BoolValue)
        return;

    int victimUserId   = event.GetInt("userid");
    int attackerUserId = event.GetInt("attacker");

    if (victimUserId == 0 || attackerUserId == 0)
        return;

    int victim   = GetClientOfUserId(victimUserId);
    int attacker = GetClientOfUserId(attackerUserId);

    // Víctima: survivor vivo y válido
    if (victim == 0 || !IsClientInGame(victim) || !IsPlayerAlive(victim))
        return;

    if (GetClientTeam(victim) != 2)
        return;

    // Atacante: no debe ser bot  (≡ !IsPlayerABot en VScript)
    if (attacker == 0 || !IsClientInGame(attacker) || IsFakeClient(attacker))
        return;

    // --- Stagger real del engine ---
    // OnStaggered recibe la POSICIÓN DE ORIGEN del golpe (no una dirección).
    // El engine calcula internamente: pushDir = victimPos - sourcePos
    // → pasamos la posición del atacante para que la víctima salga disparada HACIA ADELANTE (lejos del atacante).
    float attackerPos[3];
    GetClientAbsOrigin(attacker, attackerPos);

    // CTerrorPlayer::OnStaggered(victim, source_entity, source_position)
    SDKCall(g_hSDKStagger, victim, attacker, attackerPos);

    // --- SpeakResponseConcept: PlayerFriendlyFire ---
    SetVariantString("PlayerFriendlyFire");
    AcceptEntityInput(victim, "SpeakResponseConcept");
}
