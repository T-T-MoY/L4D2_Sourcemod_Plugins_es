#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required


#define EF_BONEMERGE          0x001
#define EF_NOSHADOW           0x010
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_NORECEIVESHADOW    0x040
#define EF_PARENT_ANIMATES    0x200
#define HIDEHUD_ALL        (1 << 2)
#define HIDEHUD_CROSSHAIR  (1 << 8)
#define CVAR_FLAGS     FCVAR_NOTIFY



ConVar g_cvHidePlayers;

TopMenu hTopMenu;

ConVar g_cvFlagDancesMenu;
ConVar g_cvCooldown;
ConVar g_cvHideWeapons;
ConVar g_cvTeleportBack;
ConVar g_cvSpeed;

ConVar g_cvCamDistance;
ConVar g_cvCamHeight;
ConVar g_cvCamAngle;

int g_iEmoteEnt[MAXPLAYERS + 1];

int g_EmotesTarget[MAXPLAYERS + 1];

bool g_bClientDancing[MAXPLAYERS + 1];


Handle CooldownTimers[MAXPLAYERS + 1];
bool g_bEmoteCooldown[MAXPLAYERS + 1];

int g_iWeaponHandEnt[MAXPLAYERS + 1];

Handle g_EmoteForward;
Handle g_EmoteForward_Pre;
bool g_bHooked[MAXPLAYERS + 1];

float g_fLastAngles[MAXPLAYERS + 1][3];
float g_fLastPosition[MAXPLAYERS + 1][3];

int playerModels[MAXPLAYERS + 1];
int playerModelsIndex[MAXPLAYERS + 1];

EngineVersion _Game;
bool L4D;


public Plugin myinfo = {
    name = "SM Fortnite Emotes Extended - L4D Version",
    author = "Kodua, Franc1sco franug, TheBO$$, Foxhound",
    description = "This plugin is for demonstration of some animations from Fortnite in L4D",
    version = "1.4.3",
    url = "https://forums.alliedmods.net/showthread.php?t=318981"
};

public void OnPluginStart() {

    _Game = GetEngineVersion();
    L4D = (_Game == Engine_Left4Dead);

    LoadTranslations("common.phrases");
    LoadTranslations("fnemotes.phrases");

    RegConsoleCmd("sm_dances", Command_Menu, "");
    RegConsoleCmd("sm_dance", Command_Menu, "");
    RegAdminCmd("sm_setdances", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setdances <#userid|name> [Emote ID]", "");
    RegAdminCmd("sm_setdance", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setdance <#userid|name> [Emote ID]", "");

    HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
    if(L4D){
    HookEvent("player_afk", Event_PAfkQ);
    HookEvent("player_bot_replace", Event_PAfk);
    HookEvent("player_team", Event_PAfkQ);
    HookEvent("bot_player_replace", Event_PAfk);
    }
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);

    HookEvent("round_start", Event_Start);

    /**
    	Convars
    **/

    g_cvCooldown = CreateConVar("sm_emotes_cooldown", "2.0", "Cooldown for emotes in seconds. -1 or 0 = no cooldown.", CVAR_FLAGS);
    g_cvFlagDancesMenu = CreateConVar("sm_dances_admin_flag_menu", "", "admin flag for dances (empty for all players)", CVAR_FLAGS);
    g_cvHideWeapons = CreateConVar("sm_emotes_hide_weapons", "1", "Hide weapons when dancing", CVAR_FLAGS);
    g_cvHidePlayers = CreateConVar("sm_emotes_hide_enemies", "0", "Hide enemy players when dancing", CVAR_FLAGS);
    g_cvTeleportBack = CreateConVar("sm_emotes_teleportonend", "0", "Teleport back to the exact position when he started to dance. (Some maps need this for teleport triggers)", CVAR_FLAGS);
    g_cvSpeed = CreateConVar("sm_emotes_speed", "0.80", "Sets the playback speed of the animation. default (1.0)", CVAR_FLAGS);

    
    // Convars para ajustar la cámara
    g_cvCamDistance = CreateConVar("sm_emotes_cam_distance", "30.0", "Distancia de la cámara en tercera persona (valores más bajos = más cerca).", CVAR_FLAGS);
    g_cvCamHeight = CreateConVar("sm_emotes_cam_height", "0.0", "Altura de la cámara (positivo = arriba, negativo = abajo).", CVAR_FLAGS);
    g_cvCamAngle = CreateConVar("sm_emotes_cam_angle", "0.0", "Ángulo lateral de la cámara (rotación izquierda/derecha).", CVAR_FLAGS);

    

    AutoExecConfig(true, "fortnite_solo_dance_l4d");

    /**
    	End Convars
    **/

    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
        OnAdminMenuReady(topmenu);
    }

    g_EmoteForward = CreateGlobalForward("fnemotes_OnEmote", ET_Ignore, Param_Cell);
    g_EmoteForward_Pre = CreateGlobalForward("fnemotes_OnEmote_Pre", ET_Event, Param_Cell);
}
public void OnPluginEnd() {
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && g_bClientDancing[i]) {
            StopEmote(i);
        }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    RegPluginLibrary("fnemotes");
    CreateNative("fnemotes_IsClientEmoting", Native_IsClientEmoting);
    return APLRes_Success;
}

public Action Event_PAfk(Handle event,
    const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "player"));
    int target = GetClientOfUserId(GetEventInt(event, "bot"));
    if (IsClientInGame(client)) {
        ResetCam(client);
        TerminateEmote(client);
        RemoveSkin(client);
        WeaponUnblock(client);
        g_bClientDancing[client] = false;
    }

    SetEntityMoveType(target, MOVETYPE_WALK);
}

public Action Event_PAfkQ(Handle event,
    const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(0 < client <= MaxClients && g_bClientDancing[client]){
    ResetCam(client);
    TerminateEmote(client);
    RemoveSkin(client);
    WeaponUnblock(client);
    g_bClientDancing[client] = false;
   }
}

int Native_IsClientEmoting(Handle plugin, int numParams) {
    return g_bClientDancing[GetNativeCell(1)];
}

public void OnMapStart() {

    if(L4D){
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_l4d.mdl");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_l4d.vvd");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_l4d.dx90.vtx");
    }else{
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.vvd");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.dx90.vtx");
    }

    // this dont touch
    if(L4D){
    PrecacheModel("models/player/custom_player/foxhound/fortnite_dances_emotes_l4d.mdl", true);
    }else{
    PrecacheModel("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl", true);    
    }


}

public void OnClientPutInServer(int client) {
    if (IsValidClient(client)) {
        ResetCam(client);
        TerminateEmote(client);
        g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;

        if (CooldownTimers[client] != null) {
            KillTimer(CooldownTimers[client]);
        }
    }
}

public void OnClientDisconnect(int client) {
    if (IsValidClient(client)) {
        ResetCam(client);
        TerminateEmote(client);
    }
    if (CooldownTimers[client] != null) {
        KillTimer(CooldownTimers[client]);
        CooldownTimers[client] = null;
        g_bEmoteCooldown[client] = false;
    }

    g_bHooked[client] = false;
}

public Action OnPlayerDeath(Handle event,
    const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidClient(client)) {
        ResetCam(client);
        StopEmote(client);
    }
}

public Action Event_PlayerHurt(Event event,
    const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsSurvivor(client)) {
        return Plugin_Continue;
    }

    if (attacker != client) {

        StopEmote(client);
    }

    return Plugin_Continue;
}

public Action Event_Start(Event event,const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++)
        if (IsValidClient(i, false) && g_bClientDancing[i]) {
            ResetCam(i);
            StopEmote(i);
            WeaponUnblock(i);

            g_bClientDancing[i] = false;

        }

    return Plugin_Continue;
}

public Action Command_Menu(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;


    char sBuffer[32];

    if (CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        Menu_Dance(client);
    } else CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");

    return Plugin_Handled;
}

Action CreateEmote(int client,const char[] anim1,const char[] anim2, bool isLooped) {
    if (!IsValidClient(client)) return Plugin_Handled;

    if (g_EmoteForward_Pre != null) {
        Action res = Plugin_Continue;
        Call_StartForward(g_EmoteForward_Pre);
        Call_PushCell(client);
        Call_Finish(res);

        if (res != Plugin_Continue) {
            return Plugin_Handled;
        }
    }

    if (!IsPlayerAlive(client)) {
        CPrintToChat(client, "%t", "MUST_BE_ALIVE");
        return Plugin_Handled;
    }

    if (!(GetEntityFlags(client) & FL_ONGROUND)) {
        CPrintToChat(client, "%t", "STAY_ON_GROUND");
        return Plugin_Handled;
    }

    if (CooldownTimers[client]) {
        CPrintToChat(client, "%t", "COOLDOWN_EMOTES");
        return Plugin_Handled;
    }

    if (StrEqual(anim1, "")) {
        CPrintToChat(client, "%t", "AMIN_1_INVALID");
        return Plugin_Handled;
    }

    if (g_iEmoteEnt[client]) StopEmote(client);

    if (GetEntityMoveType(client) == MOVETYPE_NONE) {
        CPrintToChat(client, "%t", "CANNOT_USE_NOW");
        return Plugin_Handled;
    }

    int EmoteEnt = CreateEntityByName("prop_dynamic");
    if (IsValidEntity(EmoteEnt)) {
        SetEntityMoveType(client, MOVETYPE_NONE);
        if (L4D){ SetEntityRenderMode(client, RENDER_TRANSALPHA);
        }
        WeaponBlock(client);

        float vec[3],
            ang[3];
        GetClientAbsOrigin(client, vec);
        GetClientAbsAngles(client, ang);

        g_fLastPosition[client] = vec;
        g_fLastAngles[client] = ang;
        int skin = -1;
        char emoteEntName[16];
        FormatEx(emoteEntName, sizeof(emoteEntName), "emoteEnt%i", GetRandomInt(1000000, 9999999));
        char model[PLATFORM_MAX_PATH];
        GetClientModel(client, model, sizeof(model));
        skin = CreatePlayerModelProp(client, model);
        DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
        if(L4D){
        DispatchKeyValue(EmoteEnt, "model", "models/player/custom_player/foxhound/fortnite_dances_emotes_l4d.mdl");
        }else{
        DispatchKeyValue(EmoteEnt, "model", "models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl");
        }
        DispatchKeyValue(EmoteEnt, "solid", "0");
        DispatchKeyValue(EmoteEnt, "rendermode", "0");

        ActivateEntity(EmoteEnt);
        DispatchSpawn(EmoteEnt);

        TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);

        SetVariantString(emoteEntName);
        AcceptEntityInput(client, "SetParent", client, client, skin);

        g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);

        SetEntProp(client, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);



        if (StrEqual(anim2, "none", false)) {
            HookSingleEntityOutput(EmoteEnt, "OnAnimationDone", EndAnimation, true);
        } else {
            SetVariantString(anim2);
            AcceptEntityInput(EmoteEnt, "SetDefaultAnimation", -1, -1, 0);
        }

        SetVariantString(anim1);
        AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);

        if (g_cvSpeed.FloatValue != 1.0) SetEntPropFloat(EmoteEnt, Prop_Send, "m_flPlaybackRate", g_cvSpeed.FloatValue);

        SetCam(client);

        g_bClientDancing[client] = true;

        if (g_cvHidePlayers.BoolValue) {
            for (int i = 1; i <= MaxClients; i++)
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && !g_bHooked[i]) {
                    SDKHook(i, SDKHook_SetTransmit, SetTransmit);
                    g_bHooked[i] = true;
                }
        }

        if (g_cvCooldown.FloatValue > 0.0) {
            CooldownTimers[client] = CreateTimer(g_cvCooldown.FloatValue, ResetCooldown, client);
        }

        if (g_EmoteForward != null) {
            Call_StartForward(g_EmoteForward);
            Call_PushCell(client);
            Call_Finish();
        }

        if (isLooped) {}
    }

    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVelocity[3], float fAngles[3], int & iWeapon) {
    if (g_bClientDancing[client] && !(GetEntityFlags(client) & FL_ONGROUND))
        StopEmote(client);

    static int iAllowedButtons = IN_BACK | IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT | IN_WALK | IN_SPEED | IN_SCORE;

    if (iButtons == 0)
        return Plugin_Continue;

    if (g_iEmoteEnt[client] == 0)
        return Plugin_Continue;

    if ((iButtons & iAllowedButtons) && !(iButtons & ~iAllowedButtons))
        return Plugin_Continue;

    StopEmote(client);

    return Plugin_Continue;
}

void EndAnimation(const char[] output, int caller, int activator, float delay) {
    if (caller > 0) {
        activator = GetEmoteActivator(EntIndexToEntRef(caller));
        StopEmote(activator);
    }
}

int GetEmoteActivator(int iEntRefDancer) {
    if (iEntRefDancer == INVALID_ENT_REFERENCE)
        return 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (g_iEmoteEnt[i] == iEntRefDancer) {
            return i;
        }
    }
    return 0;
}

void StopEmote(int client) {
    if (!g_iEmoteEnt[client])
        return;

    int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt)) {
        char emoteEntName[50];
        GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
        SetVariantString(emoteEntName);
        AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
        DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(iEmoteEnt, "FireUser1");

        if (g_cvTeleportBack.BoolValue)
            TeleportEntity(client, g_fLastPosition[client], g_fLastAngles[client], NULL_VECTOR);

        RemoveSkin(client);
        ResetCam(client);
        WeaponUnblock(client);
        SetEntityMoveType(client, MOVETYPE_WALK);
        if (L4D){ SetEntityRenderMode(client, RENDER_NORMAL);}

        g_iEmoteEnt[client] = 0;
        g_bClientDancing[client] = false;
    } else {
        g_iEmoteEnt[client] = 0;
        g_bClientDancing[client] = false;
    }
}

void TerminateEmote(int client) {
    if (!g_iEmoteEnt[client])
        return;

    int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt)) {
        char emoteEntName[50];
        GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
        SetVariantString(emoteEntName);
        AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
        DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(iEmoteEnt, "FireUser1");

        g_iEmoteEnt[client] = 0;
        g_bClientDancing[client] = false;
    } else {
        g_iEmoteEnt[client] = 0;
        g_bClientDancing[client] = false;
    }
}

void WeaponBlock(int client) {
    SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKHook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);

    if (g_cvHideWeapons.BoolValue)
        SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

    int iEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (iEnt != -1) {
        g_iWeaponHandEnt[client] = EntIndexToEntRef(iEnt);

        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    }
}

void WeaponUnblock(int client) {
    SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKUnhook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);

    //Even if are not activated, there will be no errors
    SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);

    if (GetEmotePeople() == 0) {
        for (int i = 1; i <= MaxClients; i++)
            if (IsClientInGame(i) && g_bHooked[i]) {
                SDKUnhook(i, SDKHook_SetTransmit, SetTransmit);
                g_bHooked[i] = false;
            }
    }

    if (IsPlayerAlive(client) && g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE) {
        int iEnt = EntRefToEntIndex(g_iWeaponHandEnt[client]);
        if (iEnt != INVALID_ENT_REFERENCE) {
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
        }
    }

    g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;
}

Action WeaponCanUseSwitch(int client, int weapon) {
    return Plugin_Stop;
}

void OnPostThinkPost(int client) {
    SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action SetTransmit(int entity, int client) {
    if (g_bClientDancing[client] && IsPlayerAlive(client) && GetClientTeam(client) != GetClientTeam(entity)) return Plugin_Handled;

    return Plugin_Continue;
}

void SetCam(int client) {
    if (L4D) {
        // 1. Forzar vista en tercera persona (esto ya funciona)
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);

        // 2. Ajustar distancia de la cámara (propiedad real en L4D2)
        float distance = g_cvCamDistance.FloatValue;
        SetEntPropFloat(client, Prop_Send, "m_flTauntCameraDistance", distance); // Usar esta propiedad

        // 3. Ajustar altura (puede no funcionar en L4D2, pero lo intentamos)
        float height = g_cvCamHeight.FloatValue;
        SetEntPropFloat(client, Prop_Send, "m_flTauntCameraOffsetZ", height);

        // 4. Ajustar ángulo lateral (experimental)
        float angle = g_cvCamAngle.FloatValue;
        SetEntPropFloat(client, Prop_Send, "m_flTauntCameraYaw", angle);

        // 5. Forzar tercera persona (esto ya funciona)
        SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
    } else {
        // Para otros juegos (no L4D2)
        SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
    }

    // Ocultar el crosshair
    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_CROSSHAIR);
}

void ResetCam(int client) {
    if (L4D) {

        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);

    } else {
        SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);
    }

    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_CROSSHAIR);
}

Action ResetCooldown(Handle timer, any client) {
    CooldownTimers[client] = null;
}

Action Menu_Dance(int client) {
    Menu menu = new Menu(MenuHandler1);

    char title[65];
    Format(title, sizeof(title), "%T:", "TITLE_MAIM_MENU", client);
    menu.SetTitle(title);

    AddTranslatedMenuItem(menu, "1", "RANDOM_DANCE", client);
    AddTranslatedMenuItem(menu, "2", "DANCES_LIST", client);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int MenuHandler1(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Select: {
            int client = param1;

            switch (param2) {
                case 0: {
                    RandomDance(client);
                    Menu_Dance(client);
                }
                case 1: {
                    DancesMenu(client);
                }
            }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
}


Action DancesMenu(int client) {
    char sBuffer[32];
    g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");
        return Plugin_Handled;
    }
    Menu menu = new Menu(MenuHandlerDances);

    char title[65];
    Format(title, sizeof(title), "%T:", "TITLE_DANCES_MENU", client);
    menu.SetTitle(title);

    AddTranslatedMenuItem(menu, "1", "DanceMoves", client);
    AddTranslatedMenuItem(menu, "2", "Emote_Mask_Off_Intro", client);
    AddTranslatedMenuItem(menu, "3", "Emote_Zippy_Dance", client);
    AddTranslatedMenuItem(menu, "4", "ElectroShuffle", client);
    AddTranslatedMenuItem(menu, "5", "Emote_AerobicChamp", client);
    AddTranslatedMenuItem(menu, "6", "Emote_Bendy", client);
    AddTranslatedMenuItem(menu, "7", "Emote_BandOfTheFort", client);
    AddTranslatedMenuItem(menu, "8", "Emote_Boogie_Down_Intro", client);
    AddTranslatedMenuItem(menu, "9", "Emote_Capoeira", client);
    AddTranslatedMenuItem(menu, "10", "Emote_Charleston", client);
    AddTranslatedMenuItem(menu, "11", "Emote_Chicken", client);
    AddTranslatedMenuItem(menu, "12", "Emote_Dance_NoBones", client);
    AddTranslatedMenuItem(menu, "13", "Emote_Dance_Shoot", client);
    AddTranslatedMenuItem(menu, "14", "Emote_Dance_SwipeIt", client);
    AddTranslatedMenuItem(menu, "15", "Emote_Dance_Disco_T3", client);
    AddTranslatedMenuItem(menu, "16", "Emote_DG_Disco", client);
    AddTranslatedMenuItem(menu, "17", "Emote_Dance_Worm", client);
    AddTranslatedMenuItem(menu, "18", "Emote_Dance_Loser", client);
    AddTranslatedMenuItem(menu, "19", "Emote_Dance_Breakdance", client);
    AddTranslatedMenuItem(menu, "20", "Emote_Dance_Pump", client);
    AddTranslatedMenuItem(menu, "21", "Emote_Dance_RideThePony", client);
    AddTranslatedMenuItem(menu, "22", "Emote_Dab", client);
    AddTranslatedMenuItem(menu, "23", "Emote_EasternBloc_Start", client);
    AddTranslatedMenuItem(menu, "24", "Emote_FancyFeet", client);
    AddTranslatedMenuItem(menu, "25", "Emote_FlossDance", client);
    AddTranslatedMenuItem(menu, "26", "Emote_FlippnSexy", client);
    AddTranslatedMenuItem(menu, "27", "Emote_Fresh", client);
    AddTranslatedMenuItem(menu, "28", "Emote_GrooveJam", client);
    AddTranslatedMenuItem(menu, "29", "Emote_guitar", client);
    AddTranslatedMenuItem(menu, "30", "Emote_Hillbilly_Shuffle_Intro", client);
    AddTranslatedMenuItem(menu, "31", "Emote_Hiphop_01", client);
    AddTranslatedMenuItem(menu, "32", "Emote_Hula_Start", client);
    AddTranslatedMenuItem(menu, "33", "Emote_InfiniDab_Intro", client);
    AddTranslatedMenuItem(menu, "34", "Emote_Intensity_Start", client);
    AddTranslatedMenuItem(menu, "35", "Emote_IrishJig_Start", client);
    AddTranslatedMenuItem(menu, "36", "Emote_KoreanEagle", client);
    AddTranslatedMenuItem(menu, "37", "Emote_Kpop_02", client);
    AddTranslatedMenuItem(menu, "38", "Emote_LivingLarge", client);
    AddTranslatedMenuItem(menu, "39", "Emote_Maracas", client);
    AddTranslatedMenuItem(menu, "40", "Emote_PopLock", client);
    AddTranslatedMenuItem(menu, "41", "Emote_PopRock", client);
    AddTranslatedMenuItem(menu, "42", "Emote_RobotDance", client);
    AddTranslatedMenuItem(menu, "43", "Emote_T-Rex", client);
    AddTranslatedMenuItem(menu, "44", "Emote_TechnoZombie", client);
    AddTranslatedMenuItem(menu, "45", "Emote_Twist", client);
    AddTranslatedMenuItem(menu, "46", "Emote_WarehouseDance_Start", client);
    AddTranslatedMenuItem(menu, "47", "Emote_Wiggle", client);
    AddTranslatedMenuItem(menu, "48", "Emote_Youre_Awesome", client);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int MenuHandlerDances(Menu menu, MenuAction action, int client, int param2) {
    switch (action) {
        case MenuAction_Select: {
            char info[16];
            if (menu.GetItem(param2, info, sizeof(info))) {
                int iParam2 = StringToInt(info);

                switch (iParam2) {
                    case 1:
                        CreateEmote(client, "DanceMoves", "none", false);
                    case 2:
                        CreateEmote(client, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", true);
                    case 3:
                        CreateEmote(client, "Emote_Zippy_Dance", "none", true);
                    case 4:
                        CreateEmote(client, "ElectroShuffle", "none", true);
                    case 5:
                        CreateEmote(client, "Emote_AerobicChamp", "none", true);
                    case 6:
                        CreateEmote(client, "Emote_Bendy", "none", true);
                    case 7:
                        CreateEmote(client, "Emote_BandOfTheFort", "none", true);
                    case 8:
                        CreateEmote(client, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", true);
                    case 9:
                        CreateEmote(client, "Emote_Capoeira", "none", false);
                    case 10:
                        CreateEmote(client, "Emote_Charleston", "none", true);
                    case 11:
                        CreateEmote(client, "Emote_Chicken", "none", true);
                    case 12:
                        CreateEmote(client, "Emote_Dance_NoBones", "none", true);
                    case 13:
                        CreateEmote(client, "Emote_Dance_Shoot", "none", true);
                    case 14:
                        CreateEmote(client, "Emote_Dance_SwipeIt", "none", true);
                    case 15:
                        CreateEmote(client, "Emote_Dance_Disco_T3", "none", true);
                    case 16:
                        CreateEmote(client, "Emote_DG_Disco", "none", true);
                    case 17:
                        CreateEmote(client, "Emote_Dance_Worm", "none", false);
                    case 18:
                        CreateEmote(client, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", true);
                    case 19:
                        CreateEmote(client, "Emote_Dance_Breakdance", "none", false);
                    case 20:
                        CreateEmote(client, "Emote_Dance_Pump", "none", true);
                    case 21:
                        CreateEmote(client, "Emote_Dance_RideThePony", "none", false);
                    case 22:
                        CreateEmote(client, "Emote_Dab", "none", false);
                    case 23:
                        CreateEmote(client, "Emote_EasternBloc_Start", "Emote_EasternBloc", true);
                    case 24:
                        CreateEmote(client, "Emote_FancyFeet", "Emote_FancyFeet_CT", true);
                    case 25:
                        CreateEmote(client, "Emote_FlossDance", "none", true);
                    case 26:
                        CreateEmote(client, "Emote_FlippnSexy", "none", false);
                    case 27:
                        CreateEmote(client, "Emote_Fresh", "none", true);
                    case 28:
                        CreateEmote(client, "Emote_GrooveJam", "none", true);
                    case 29:
                        CreateEmote(client, "Emote_guitar", "none", true);
                    case 30:
                        CreateEmote(client, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", true);
                    case 31:
                        CreateEmote(client, "Emote_Hiphop_01", "Emote_Hip_Hop", true);
                    case 32:
                        CreateEmote(client, "Emote_Hula_Start", "Emote_Hula", true);
                    case 33:
                        CreateEmote(client, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", true);
                    case 34:
                        CreateEmote(client, "Emote_Intensity_Start", "Emote_Intensity_Loop", true);
                    case 35:
                        CreateEmote(client, "Emote_IrishJig_Start", "Emote_IrishJig", true);
                    case 36:
                        CreateEmote(client, "Emote_KoreanEagle", "none", true);
                    case 37:
                        CreateEmote(client, "Emote_Kpop_02", "none", true);
                    case 38:
                        CreateEmote(client, "Emote_LivingLarge", "none", true);
                    case 39:
                        CreateEmote(client, "Emote_Maracas", "none", true);
                    case 40:
                        CreateEmote(client, "Emote_PopLock", "none", true);
                    case 41:
                        CreateEmote(client, "Emote_PopRock", "none", true);
                    case 42:
                        CreateEmote(client, "Emote_RobotDance", "none", true);
                    case 43:
                        CreateEmote(client, "Emote_T-Rex", "none", false);
                    case 44:
                        CreateEmote(client, "Emote_TechnoZombie", "none", true);
                    case 45:
                        CreateEmote(client, "Emote_Twist", "none", true);
                    case 46:
                        CreateEmote(client, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", true);
                    case 47:
                        CreateEmote(client, "Emote_Wiggle", "none", true);
                    case 48:
                        CreateEmote(client, "Emote_Youre_Awesome", "none", false);
                }
            }
            menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_Dance(client);
            }
        }
    }
}

Action RandomDance(int client) {
    char sBuffer[32];
    g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");
        return;
    }
    int number = GetRandomInt(1, 48);

    switch (number) {
        case 1:
            CreateEmote(client, "DanceMoves", "none", false);
        case 2:
            CreateEmote(client, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", true);
        case 3:
            CreateEmote(client, "Emote_Zippy_Dance", "none", true);
        case 4:
            CreateEmote(client, "ElectroShuffle", "none", true);
        case 5:
            CreateEmote(client, "Emote_AerobicChamp", "none", true);
        case 6:
            CreateEmote(client, "Emote_Bendy", "none", true);
        case 7:
            CreateEmote(client, "Emote_BandOfTheFort", "none", true);
        case 8:
            CreateEmote(client, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", true);
        case 9:
            CreateEmote(client, "Emote_Capoeira", "none", false);
        case 10:
            CreateEmote(client, "Emote_Charleston", "none", true);
        case 11:
            CreateEmote(client, "Emote_Chicken", "none", true);
        case 12:
            CreateEmote(client, "Emote_Dance_NoBones", "none", true);
        case 13:
            CreateEmote(client, "Emote_Dance_Shoot", "none", true);
        case 14:
            CreateEmote(client, "Emote_Dance_SwipeIt", "none", true);
        case 15:
            CreateEmote(client, "Emote_Dance_Disco_T3", "none", true);
        case 16:
            CreateEmote(client, "Emote_DG_Disco", "none", true);
        case 17:
            CreateEmote(client, "Emote_Dance_Worm", "none", false);
        case 18:
            CreateEmote(client, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", true);
        case 19:
            CreateEmote(client, "Emote_Dance_Breakdance", "none", false);
        case 20:
            CreateEmote(client, "Emote_Dance_Pump", "none", true);
        case 21:
            CreateEmote(client, "Emote_Dance_RideThePony", "none", false);
        case 22:
            CreateEmote(client, "Emote_Dab", "none", false);
        case 23:
            CreateEmote(client, "Emote_EasternBloc_Start", "Emote_EasternBloc", true);
        case 24:
            CreateEmote(client, "Emote_FancyFeet", "Emote_FancyFeet_CT", true);
        case 25:
            CreateEmote(client, "Emote_FlossDance", "none", true);
        case 26:
            CreateEmote(client, "Emote_FlippnSexy", "none", false);
        case 27:
            CreateEmote(client, "Emote_Fresh", "none", true);
        case 28:
            CreateEmote(client, "Emote_GrooveJam", "none", true);
        case 29:
            CreateEmote(client, "Emote_guitar", "none", true);
        case 30:
            CreateEmote(client, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", true);
        case 31:
            CreateEmote(client, "Emote_Hiphop_01", "Emote_Hip_Hop", true);
        case 32:
            CreateEmote(client, "Emote_Hula_Start", "Emote_Hula", true);
        case 33:
            CreateEmote(client, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", true);
        case 34:
            CreateEmote(client, "Emote_Intensity_Start", "Emote_Intensity_Loop", true);
        case 35:
            CreateEmote(client, "Emote_IrishJig_Start", "Emote_IrishJig", true);
        case 36:
            CreateEmote(client, "Emote_KoreanEagle", "none", true);
        case 37:
            CreateEmote(client, "Emote_Kpop_02", "none", true);
        case 38:
            CreateEmote(client, "Emote_LivingLarge", "none", true);
        case 39:
            CreateEmote(client, "Emote_Maracas", "none", true);
        case 40:
            CreateEmote(client, "Emote_PopLock", "none", true);
        case 41:
            CreateEmote(client, "Emote_PopRock", "none", true);
        case 42:
            CreateEmote(client, "Emote_RobotDance", "none", true);
        case 43:
            CreateEmote(client, "Emote_T-Rex", "none", false);
        case 44:
            CreateEmote(client, "Emote_TechnoZombie", "none", true);
        case 45:
            CreateEmote(client, "Emote_Twist", "none", true);
        case 46:
            CreateEmote(client, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", true);
        case 47:
            CreateEmote(client, "Emote_Wiggle", "none", true);
        case 48:
            CreateEmote(client, "Emote_Youre_Awesome", "none", false);
    }
}


Action Command_Admin_Emotes(int client, int args) {
    if (args < 1) {
        CPrintToChat(client, "[T-T] Usage: sm_setdances <#userid|name> [Dance ID]");
        return Plugin_Handled;
    }

    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));

    int amount = 1;
    if (args > 1) {
        char arg2[3];
        GetCmdArg(2, arg2, sizeof(arg2));
        if (StringToIntEx(arg2, amount) < 1 || StringToIntEx(arg2, amount) > 86) {
            CPrintToChat(client, "%t", "INVALID_EMOTE_ID");
            return Plugin_Handled;
        }
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
            arg,
            client,
            target_list,
            MAXPLAYERS,
            COMMAND_FILTER_ALIVE,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }


    return Plugin_Handled;
}


public void OnAdminMenuReady(Handle aTopMenu) {
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    /* Block us from being called twice */
    if (topmenu == hTopMenu) {
        return;
    }

    /* Save the Handle */
    hTopMenu = topmenu;

    /* Find the "Player Commands" category */
    TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if (player_commands != INVALID_TOPMENUOBJECT) {
        hTopMenu.AddItem("sm_setemotes", AdminMenu_Emotes, player_commands, "sm_setemotes", ADMFLAG_SLAY);
    }
}

void AdminMenu_Emotes(TopMenu topmenu,
    TopMenuAction action,
    TopMenuObject object_id,
    int param,
    char[] buffer,
    int maxlength) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "%T", "EMOTE_PLAYER", param);
    } else if (action == TopMenuAction_SelectOption) {
        DisplayEmotePlayersMenu(param);
    }
}

void DisplayEmotePlayersMenu(int client) {
    Menu menu = new Menu(MenuHandler_EmotePlayers);

    char title[65];
    Format(title, sizeof(title), "%T:", "EMOTE_PLAYER", client);
    menu.SetTitle(title);
    menu.ExitBackButton = true;

    AddTargetsToMenu(menu, client, true, true);

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_EmotePlayers(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack && hTopMenu) {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_Select) {
        char info[32];
        int userid, target;

        menu.GetItem(param2, info, sizeof(info));
        userid = StringToInt(info);

        if ((target = GetClientOfUserId(userid)) == 0) {
            CPrintToChat(param1, "[SM] %t", "Player no longer available");
        } else if (!CanUserTarget(param1, target)) {
            CPrintToChat(param1, "[SM] %t", "Unable to target");
        } else {
            g_EmotesTarget[param1] = userid;
            return; // Return, because we went to a new menu and don't want the re-draw to occur.
        }

        /* Re-draw the menu if they're still valid */
        if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
            DisplayEmotePlayersMenu(param1);
        }
    }

    return;
}

int MenuHandler_EmotesAmount(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack && hTopMenu) {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_Select) {
        char info[32];
        int amount;
        int target;

        menu.GetItem(param2, info, sizeof(info));
        amount = StringToInt(info);

        if ((target = GetClientOfUserId(g_EmotesTarget[param1])) == 0) {
            CPrintToChat(param1, "[SM] %t", "Player no longer available");
        } else if (!CanUserTarget(param1, target)) {
            CPrintToChat(param1, "[SM] %t", "Unable to target");
        } else {
            char name[MAX_NAME_LENGTH];
            GetClientName(target, name, sizeof(name));
        }

        /* Re-draw the menu if they're still valid */
        if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
            DisplayEmotePlayersMenu(param1);
        }
    }
}

void AddTranslatedMenuItem(Menu menu,
    const char[] opt,
        const char[] phrase, int client) {
    char buffer[128];
    Format(buffer, sizeof(buffer), "%T", phrase, client);
    menu.AddItem(opt, buffer);
}

stock bool IsValidClient(int client, bool nobots = true) {
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client))) {
        return false;
    }
    return IsClientInGame(client);
}

bool CheckAdminFlags(int client, int iFlag) {
    int iUserFlags = GetUserFlagBits(client);
    return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}

int GetEmotePeople() {
    int count;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && g_bClientDancing[i])
            count++;

    return count;
}

public void OnClientPostAdminCheck(int client) {
    playerModelsIndex[client] = -1;
    playerModels[client] = INVALID_ENT_REFERENCE;
}

bool IsSurvivor(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

public int CreatePlayerModelProp(int client, char[] sModel) {
    if (L4D) {
        RemoveSkin(client);
        int skin = CreateEntityByName("commentary_dummy");
        DispatchKeyValue(skin, "model", sModel);
        DispatchSpawn(skin);
        SetEntProp(skin, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);
        SetVariantString("!activator");
        AcceptEntityInput(skin, "SetParent", client, skin);
        SetVariantString("primary");
        AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0);
        playerModels[client] = EntIndexToEntRef(skin);
        playerModelsIndex[client] = skin;
        return skin;
    }

    return 0;
}

public void RemoveSkin(int client) {
    if (IsValidEntity(playerModels[client])) {
        AcceptEntityInput(playerModels[client], "Kill");
    }
    playerModels[client] = INVALID_ENT_REFERENCE;
    playerModelsIndex[client] = -1;
}

stock void ReplaceColor(char[] message, int maxLen) {
    ReplaceString(message, maxLen, "{default}", "\x01");
    ReplaceString(message, maxLen, "{darkred}", "\x04");
    ReplaceString(message, maxLen, "{olive}", "\x05");
}

stock void CPrintToChat(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    ReplaceColor(buffer, sizeof(buffer));
    PrintToChat(iClient, "\x01%s", buffer);
}