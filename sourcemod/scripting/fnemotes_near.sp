#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define EF_BONEMERGE            (1 << 0)
#define EF_NOSHADOW             (1 << 4)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_NORECEIVESHADOW      (1 << 6)
#define EF_PARENT_ANIMATES      (1 << 9)
#define HIDEHUD_ALL             (1 << 2)
#define HIDEHUD_CROSSHAIR       (1 << 8)

int g_iEmoteEnt[MAXPLAYERS+1];   // El Esqueleto Animado
int g_iCloneEnt[MAXPLAYERS+1];   // El Clon (El muñeco que verás)
int g_iWeaponHandEnt[MAXPLAYERS+1];
bool g_bClientDancing[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "[L4D2] Smooth Sliding Dance V3",
    author = "Optimizacion",
    description = "0% Ghosting, 100% Sliding. Loop engine nativo.",
    version = "3.0"
};

public void OnPluginStart()
{ 
    RegConsoleCmd("sm_dance", Command_Dance);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    HookEvent("round_start", Event_Start);
}

public void OnMapStart()
{
    AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.mdl");
    AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.vvd");
    AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.dx90.vtx");
    PrecacheModel("models/player/kodua/fnemotes_nearlycivilized.mdl", true);
}

public Action Command_Dance(int client, int args)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || !(GetEntityFlags(client) & FL_ONGROUND))
        return Plugin_Handled;

    if (g_bClientDancing[client]) StopEmote(client);

    // 1. Ocultamos armas
    WeaponBlock(client);

    // 2. Extraemos tu modelo actual (Nick, Ellis, etc.)
    char playerModel[256];
    GetEntPropString(client, Prop_Data, "m_ModelName", playerModel, sizeof(playerModel));

    float vec[3], ang[3];
    GetClientAbsOrigin(client, vec);
    GetClientAbsAngles(client, ang);
    ang[0] = 0.0; ang[2] = 0.0; // Evita que el clon se incline si miras al cielo

    // 3. Magia de invisibilidad en tu jugador real (Mantenemos tus físicas intactas)
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, 0); // 0 opacidad
    SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") | EF_NOSHADOW);

    // Damos un nombre temporal a tu jugador para poder emparentar los objetos
    char clientName[32];
    Format(clientName, sizeof(clientName), "client_dance_%d", client);
    DispatchKeyValue(client, "targetname", clientName);

    // 4. Creamos el Esqueleto Animado de Fortnite (Ahora te seguirá a TI)
    int EmoteEnt = CreateEntityByName("prop_dynamic");
    char emoteEntName[32];
    Format(emoteEntName, sizeof(emoteEntName), "emote_%d", EmoteEnt);
    DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
    DispatchKeyValue(EmoteEnt, "model", "models/player/kodua/fnemotes_nearlycivilized.mdl");
    DispatchKeyValue(EmoteEnt, "solid", "0");
    // ¡IMPORTANTE! Eliminado el rendermode 10 que congelaba la animacion.
    DispatchSpawn(EmoteEnt);
    TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);

    // Pegamos el esqueleto al jugador invisible
    SetVariantString(clientName);
    AcceptEntityInput(EmoteEnt, "SetParent", EmoteEnt, EmoteEnt, 0);

    // 5. Creamos el Clon visual
    int SkinEnt = CreateEntityByName("prop_dynamic");
    DispatchKeyValue(SkinEnt, "model", playerModel);
    DispatchKeyValue(SkinEnt, "solid", "0");
    DispatchSpawn(SkinEnt);
    TeleportEntity(SkinEnt, vec, ang, NULL_VECTOR);

    // Pegamos el clon al esqueleto (BoneMerge para que copie los movimientos de Fortnite)
    SetVariantString(emoteEntName);
    AcceptEntityInput(SkinEnt, "SetParent", SkinEnt, SkinEnt, 0);
    SetEntProp(SkinEnt, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);

    // Guardamos los datos
    g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);
    g_iCloneEnt[client] = EntIndexToEntRef(SkinEnt);
    g_bClientDancing[client] = true;

    // 6. Loop Perfecto Nativo
    SetVariantString("Emote_Gangnam_Style");
    AcceptEntityInput(EmoteEnt, "SetDefaultAnimation", -1, -1, 0);
    SetVariantString("Emote_Gangnam_Style");
    AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);

    SetCam(client);
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
    if (!g_bClientDancing[client]) return Plugin_Continue;

    // Calculo de velocidad real
    float currentVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVel);
    float speed = SquareRoot(currentVel[0]*currentVel[0] + currentVel[1]*currentVel[1]);
    
    // Panel central
    PrintCenterText(client, "=== MODO DESLIZANTE ===\nVelocidad: %.1f\nPulsa Clic Izquierdo o 'E' para salir", speed);

    // Cancelar si dispara o interactúa
    if (iButtons & IN_ATTACK || iButtons & IN_USE || iButtons & IN_ATTACK2)
    {
        StopEmote(client);
    }

    return Plugin_Continue;
}

void StopEmote(int client)
{
    if (!g_bClientDancing[client]) return;

    // Destruimos las entidades clonadas
    int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (iEmoteEnt > 0 && IsValidEntity(iEmoteEnt)) AcceptEntityInput(iEmoteEnt, "Kill");
    
    int iCloneEnt = EntRefToEntIndex(g_iCloneEnt[client]);
    if (iCloneEnt > 0 && IsValidEntity(iCloneEnt)) AcceptEntityInput(iCloneEnt, "Kill");
    
    g_iEmoteEnt[client] = 0;
    g_iCloneEnt[client] = 0;
    g_bClientDancing[client] = false;
    
    // Devolvemos tu cuerpo real a la normalidad
    SetEntityRenderMode(client, RENDER_NORMAL);
    SetEntityRenderColor(client, 255, 255, 255, 255);
    SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") & ~EF_NOSHADOW);
            
    ResetCam(client);
    WeaponUnblock(client);
    PrintCenterText(client, ""); 
}

// -------------------------------------------------------------
// CAMARA RE4 Y UTILIDADES
// -------------------------------------------------------------
void SetCam(int client)
{
    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_CROSSHAIR);
    ClientCommand(client, "thirdpersonshoulder");
    ClientCommand(client, "c_thirdpersonshoulderoffset 30"); 
    ClientCommand(client, "c_thirdpersonshoulderheight 10"); 
    ClientCommand(client, "c_thirdpersonshoulderaimdist 120");
}

void ResetCam(int client)
{
    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_CROSSHAIR);
    ClientCommand(client, "thirdperson");
    ClientCommand(client, "firstperson");
}

public void OnClientPutInServer(int client) { if (IsValidClient(client)) { ResetCam(client); StopEmote(client); g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE; } }
public void OnClientDisconnect(int client) { if (IsValidClient(client)) { ResetCam(client); StopEmote(client); } }
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) { StopEmote(GetClientOfUserId(event.GetInt("userid"))); }
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(GetPlayerTeam(attacker) != GetPlayerTeam(client)) StopEmote(client);
}
void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) { StopEmote(GetClientOfUserId(event.GetInt("userid"))); }
int GetPlayerTeam(int player) { return IsValidClient(player) ? GetClientTeam(player) : 0; }
void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i, false) && g_bClientDancing[i]) { StopEmote(i); }
    }
}

void WeaponBlock(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKHook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
    int iEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(iEnt != -1) { g_iWeaponHandEnt[client] = EntIndexToEntRef(iEnt); SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1); }
}

void WeaponUnblock(int client)
{
    SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKUnhook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
    SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
    if(IsPlayerAlive(client) && g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE)
    {
        int iEnt = EntRefToEntIndex(g_iWeaponHandEnt[client]);
        if(iEnt != INVALID_ENT_REFERENCE) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
    }
    g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;
}
Action WeaponCanUseSwitch(int client, int weapon) { return Plugin_Stop; }
void OnPostThinkPost(int client) { SetEntProp(client, Prop_Send, "m_iAddonBits", 0); }
stock bool IsValidClient(int client, bool nobots = true)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client))) return false;
    return IsClientInGame(client);
}