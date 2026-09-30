#pragma semicolon 1
#pragma newdecls required;
#include <sourcemod>
#include <multicolors>
#include <sdktools> // Librería para el glow y manipulación de entidades

public Plugin myinfo =
{
    name = "Mathack Block",
    author = "Sir, Visor, NightTime & extrav3rt, Harry Potter (Mod by [T-TMoY])",
    description = "Kicks or Marks clients who are potentially attempting to enable mathack",
    version = "1.3-VisualPunishment",
    url = "http://steamcommunity.com/profiles/76561198026784913"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MaterialHack_CheckClients", Native_CheckClients);
    return APLRes_Success;
}

static const float CLIENT_CHECK_INTERVAL = 3.5;
#define SPAM_MESSAGE_INTERVAL 20.0 // <-- Tiempo en segundos de espera para repetir el mensaje de advertencia

#define CONFIG_FILE             "configs/smd_texture_manager_block.cfg"
#define LOG_FILE                "logs/smd_texture_manager_block.log"
#define CLS_CVAR_MAXLEN         128

char g_sPath[256], g_sList[256];

enum /*CLSAction*/
{
    CLSA_Kick = 0,
    CLSA_Log  = 1,
};

enum struct CLSEntry
{
    char CLSE_cvar[CLS_CVAR_MAXLEN];
    bool CLSE_hasMin;
    float CLSE_min;
    bool CLSE_hasMax;
    float CLSE_max;
    int CLSE_action;
    char CLSE_Note[CLS_CVAR_MAXLEN];
}

ArrayList ClientSettingsArray;
Handle ClientSettingsCheckTimer;
bool g_bParseList;

// --- VARIABLES PARA EL CASTIGO VISUAL ---
ConVar g_cvKickMode;
bool g_bIsMarked[MAXPLAYERS + 1];
int g_iHintEntity[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

// --- VARIABLES PARA EL MENSAJE REPETITIVO ---
Handle g_hSpamTimer[MAXPLAYERS + 1];
char g_sViolatedCvar[MAXPLAYERS + 1][CLS_CVAR_MAXLEN];
float g_fViolatedValue[MAXPLAYERS + 1];


public void OnPluginStart()
{
    BuildPath(Path_SM, g_sPath, sizeof(g_sPath), LOG_FILE);
    BuildPath(Path_SM, g_sList, sizeof(g_sList), CONFIG_FILE);

    RegServerCmd("list_clientsettings",     ServerCMD_ClientSettings_Cmd,   "List Client settings enforced by smd_texture_manager_block");
    RegServerCmd("add_trackclientcvar",     ServerCMD_TrackClientCvar_Cmd,  "Add a Client CVar to be tracked and enforced by smd_texture_manager_block");
    RegServerCmd("reload_trackclientcvar",  ServerCMD_reloadWhiteList,      "Reload the 'trackclientcvar' list");

    g_cvKickMode = CreateConVar("sm_mathack_kick_mode", "0", "1 = Kicks/Bans, 0 = Solo castigo visual (Aura + Texto permanente)", FCVAR_NOTIFY);

    ClientSettingsArray = new ArrayList(sizeof(CLSEntry));

    HookEvent("player_death", Event_PlayerStateChange);
    HookEvent("player_spawn", Event_PlayerStateChange);
}

public void OnClientDisconnect(int client)
{
    ClearVisualPunishment(client);
}

public void Event_PlayerStateChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients)
    {
        ClearVisualPunishment(client);
    }
}

// Función segura para borrar la entidad 3D y los temporizadores
void ClearVisualPunishment(int client)
{
    g_bIsMarked[client] = false;

    // Destruimos el letrero
    int ent = EntRefToEntIndex(g_iHintEntity[client]);
    if (ent > 0 && IsValidEntity(ent))
    {
        AcceptEntityInput(ent, "Kill");
    }
    g_iHintEntity[client] = INVALID_ENT_REFERENCE;

    // Apagamos el mensaje repetitivo del chat
    if (g_hSpamTimer[client] != null)
    {
        KillTimer(g_hSpamTimer[client]);
        g_hSpamTimer[client] = null;
    }
}

public void OnConfigsExecuted()
{
    g_bParseList = true;
    ParseList();
    RequestFrame(NextFrame_ParseList);

    delete ClientSettingsCheckTimer;
    ClientSettingsCheckTimer = CreateTimer(CLIENT_CHECK_INTERVAL, Timer_CheckClients, _, TIMER_REPEAT);
}

Action ServerCMD_ClientSettings_Cmd(int args)
{
    if (ClientSettingsArray == null) return Plugin_Handled;

    int iSize = ClientSettingsArray.Length;
    PrintToServer("Tracked Client CVars (Total %d)", iSize);

    CLSEntry clsetting;
    char message[256], shortbuf[64];
    for (int i = 0; i < iSize; i++) 
    {
        ClientSettingsArray.GetArray(i, clsetting, sizeof(clsetting));
        Format(message, sizeof(message), "Client CVar: %s ", clsetting.CLSE_cvar);

        if (clsetting.CLSE_hasMin) {
            Format(shortbuf, sizeof(shortbuf), "Min: %f ", clsetting.CLSE_min);
            StrCat(message, sizeof(message), shortbuf);
        }
        if (clsetting.CLSE_hasMax) {
            Format(shortbuf, sizeof(shortbuf), "Max: %f ", clsetting.CLSE_max);
            StrCat(message, sizeof(message), shortbuf);
        }

        switch (clsetting.CLSE_action) {
            case CLSA_Kick: StrCat(message, sizeof(message), "Action: Kick");
            case CLSA_Log: StrCat(message, sizeof(message), "Action: Log");
            default: {
                Format(shortbuf, sizeof(shortbuf), "Action: Ban (%d min)", clsetting.CLSE_action);
                StrCat(message, sizeof(message), shortbuf);
            }
        }
        PrintToServer(message);
    }
    return Plugin_Handled;
}

Action ServerCMD_TrackClientCvar_Cmd(int args)
{
    if (args < 3 || args == 4) 
    {
        static char cmdbuf[128];
        GetCmdArgString(cmdbuf, sizeof(cmdbuf));
        if (g_bParseList) LogError("Invalid track client cvar: %s | Usage: <cvar> <hasMin> <min> <hasMax> <max> <action> [note]", cmdbuf);
        else PrintToServer("Invalid track client cvar: %s | Usage: add_trackclientcvar <cvar> <hasMin> <min> <hasMax> <max> <action> [note]", cmdbuf);
        return Plugin_Handled;
    }

    char sBuffer[CLS_CVAR_MAXLEN], cvar[CLS_CVAR_MAXLEN], sNote[CLS_CVAR_MAXLEN];
    bool hasMax;
    float max;
    int action = CLSA_Kick;

    GetCmdArg(1, cvar, sizeof(cvar));
    if (strlen(cvar) == 0) return Plugin_Handled;

    GetCmdArg(2, sBuffer, sizeof(sBuffer));
    bool hasMin = view_as<bool>(StringToInt(sBuffer));

    GetCmdArg(3, sBuffer, sizeof(sBuffer));
    float min = StringToFloat(sBuffer);

    if (args >= 5) {
        GetCmdArg(4, sBuffer, sizeof(sBuffer));
        hasMax = view_as<bool>(StringToInt(sBuffer));
        GetCmdArg(5, sBuffer, sizeof(sBuffer));
        max = StringToFloat(sBuffer);
    }

    if (args >= 6) {
        GetCmdArg(6, sBuffer, sizeof(sBuffer));
        action = StringToInt(sBuffer);
    }

    sNote[0] = '\0';
    if (args >= 7) GetCmdArg(7, sNote, sizeof(sNote));

    _AddClientCvar(cvar, hasMin, min, hasMax, max, action, sNote);
    return Plugin_Handled;
}

Action ServerCMD_reloadWhiteList(int args)
{
    g_bParseList = true;
    ParseList();
    RequestFrame(NextFrame_ParseList);
    delete ClientSettingsCheckTimer;
    ClientSettingsCheckTimer = CreateTimer(CLIENT_CHECK_INTERVAL, Timer_CheckClients, _, TIMER_REPEAT);
    return Plugin_Handled;
}

void NextFrame_ParseList()
{
    g_bParseList = false;
}

Action Timer_CheckClients(Handle timer)
{
    if (ClientSettingsArray == null) return Plugin_Continue;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            EnforceCliSettings(client);
        }
    }   
    return Plugin_Continue;
}

void ParseList()
{
    delete ClientSettingsArray;
    ClientSettingsArray = new ArrayList(sizeof(CLSEntry));

    File hFile = OpenFile(g_sList, "r");
    if(hFile == null) return;

    bool bDataStart = false;
    char sBuffer[256];
    while(!hFile.EndOfFile() && hFile.ReadLine(sBuffer, sizeof(sBuffer)))
    {
        if(StrContains(sBuffer, "Do not delete this line", false) != -1)
        {
            bDataStart = true;
            continue;
        }

        if(strncmp(sBuffer, "//", 2, false) == 0) continue;

        if(bDataStart)
        {
            TrimString(sBuffer);
            StripQuotes(sBuffer);
            if(strlen(sBuffer) <= 0) continue;
            ServerCommand("add_trackclientcvar %s", sBuffer);
        }
    }
    delete hFile;
}

void _AddClientCvar(const char[] cvar, bool hasMin, float min, bool hasMax, float max, int action, const char[] sNote)
{
    if (!(hasMin || hasMax) || (hasMin && hasMax && max < min) || strlen(cvar) >= CLS_CVAR_MAXLEN) return;

    int iSize = ClientSettingsArray.Length;
    CLSEntry newEntry;
    for (int i = 0; i < iSize; i++) 
    {
        ClientSettingsArray.GetArray(i, newEntry, sizeof(newEntry));
        if (strcmp(newEntry.CLSE_cvar, cvar, false) == 0) return;
    }

    strcopy(newEntry.CLSE_cvar, CLS_CVAR_MAXLEN, cvar);
    newEntry.CLSE_hasMin = hasMin;
    newEntry.CLSE_min = min;
    newEntry.CLSE_hasMax = hasMax;
    newEntry.CLSE_max = max;
    newEntry.CLSE_action = action;
    strcopy(newEntry.CLSE_Note, CLS_CVAR_MAXLEN, sNote);

    ClientSettingsArray.PushArray(newEntry, sizeof(newEntry));
}

void EnforceCliSettings(int client)
{
    int iSize = ClientSettingsArray.Length;
    CLSEntry clsetting;
    for (int i = 0; i < iSize; i++) 
    {
        ClientSettingsArray.GetArray(i, clsetting, sizeof(clsetting));
        QueryClientConVar(client, clsetting.CLSE_cvar, _EnforceCliSettings_QueryReply, i);
    }
}

void _EnforceCliSettings_QueryReply(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
    if (!IsClientInGame(client) || IsClientInKickQueue(client)) return;
    if (ClientSettingsArray == null) return; 

    int clsetting_index = value;
    if (clsetting_index < 0 || clsetting_index >= ClientSettingsArray.Length) return;
    if (result) return;

    float fCvarVal = StringToFloat(cvarValue);
    CLSEntry clsetting;
    ClientSettingsArray.GetArray(clsetting_index, clsetting, sizeof(clsetting));

    if ((clsetting.CLSE_hasMin && fCvarVal < clsetting.CLSE_min) || (clsetting.CLSE_hasMax && fCvarVal > clsetting.CLSE_max)) 
    {
        static char sSteamID64[32];
        GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

        if (clsetting.CLSE_action == CLSA_Log) 
        {
            LogToFileEx(g_sPath, "[Name: %N | STEAMID: %s | %s: %f]: Has bad cvar value.", client, sSteamID64, cvarName, fCvarVal);
            return;
        }

        if (g_cvKickMode.BoolValue) 
        {
            if (clsetting.CLSE_action <= CLSA_Kick) 
            {
                CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} was kicked for having an illegal value for '{green}%s{default}' ({green}%.2f{default})", client, cvarName, fCvarVal);
                KickClient(client, "Illegal Client Value for %s (%.2f)", cvarName, fCvarVal);
            }
            else if (clsetting.CLSE_action > 1) 
            {
                CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} was banned for having an illegal value for '{green}%s{default}' ({green}%.2f{default})", client, cvarName, fCvarVal);
                char banMessage[CLS_CVAR_MAXLEN];
                Format(banMessage, sizeof(banMessage), "Illegal Client Value for %s (%.2f)", cvarName, fCvarVal);
                BanClient(client, clsetting.CLSE_action, BANFLAG_AUTHID, banMessage, banMessage);
                ServerCommand("sm_exbanid %d \"%s\"", clsetting.CLSE_action, sSteamID64);
            }
        }
        else 
        {
            if (!g_bIsMarked[client] && IsPlayerAlive(client))
            {
                g_bIsMarked[client] = true;
                ApplyCheaterPunishment(client, cvarName, fCvarVal);
                LogToFileEx(g_sPath, "[Name: %N | STEAMID: %s]: MARKED with Aura for illegal cvar: %s (%f)", client, sSteamID64, cvarName, fCvarVal);
                
                // Guardamos los datos para poder repetirlos
                strcopy(g_sViolatedCvar[client], CLS_CVAR_MAXLEN, cvarName);
                g_fViolatedValue[client] = fCvarVal;

                // Enviamos el mensaje la primera vez y arrancamos el timer repetitivo
                SendTechnicalWarning(client);
                g_hSpamTimer[client] = CreateTimer(SPAM_MESSAGE_INTERVAL, Timer_SpamWarning, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
}

// --- FUNCIÓN PARA ENVIAR EL MENSAJE FILTRADO ---
void SendTechnicalWarning(int cheater)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            // Condición: Que NO sea el tramposo actual, y que el jugador que lee NO esté marcado tampoco
            if (i != cheater && !g_bIsMarked[i])
            {
                CPrintToChat(i, "[{red}T-T{default}] Jugador: {lightgreen}%N{default} || motivo: usa {green}%s{default} ({green}%.2f{default})", cheater, g_sViolatedCvar[cheater], g_fViolatedValue[cheater]);
            }
        }
    }
}

// --- TIMER QUE REPITE EL MENSAJE EN EL CHAT ---
Action Timer_SpamWarning(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    // Si el jugador se desconectó o ya no está marcado, detenemos este timer
    if (client == 0 || !g_bIsMarked[client])
    {
        g_hSpamTimer[client] = null;
        return Plugin_Stop;
    }

    SendTechnicalWarning(client);
    return Plugin_Continue;
}

void ApplyCheaterPunishment(int client, const char[] cvarName, float fCvarVal)
{
    SetEntProp(client, Prop_Send, "m_iGlowType", 3); 
    SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
    SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);

    char sHintText[128];
    Format(sHintText, sizeof(sHintText), "TRAMPA: %s (%.2f)", cvarName, fCvarVal);
    
    int entity = CreateEntityByName("env_instructor_hint");
    if (entity != -1)
    {
        char sTargetName[32];
        Format(sTargetName, sizeof(sTargetName), "cheater_target_%d", client);
        DispatchKeyValue(client, "targetname", sTargetName);
        
        DispatchKeyValue(entity, "hint_target", sTargetName);
        DispatchKeyValue(entity, "hint_timeout", "0"); 
        DispatchKeyValue(entity, "hint_static", "0");  
        DispatchKeyValue(entity, "hint_caption", sHintText);
        DispatchKeyValue(entity, "hint_color", "255 0 0"); 
        DispatchKeyValue(entity, "hint_icon_onscreen", "icon_alert_red"); 
        DispatchKeyValue(entity, "hint_instance_type", "2"); 
        
        DispatchSpawn(entity);
        AcceptEntityInput(entity, "ShowHint");
        
        SetVariantString("!activator");
        AcceptEntityInput(entity, "SetParent", client, entity);

        g_iHintEntity[client] = EntIndexToEntRef(entity);
    }
}

int Native_CheckClients(Handle plugin, int numParams)
{
    CreateTimer(0.1, Timer_CheckClients);
    return 0;
}