// ============================================================
// l4d2_tankrun_finale_skip.sp
// Autor: MoY
// Descripción:
//   En la mutación "tankrun", reemplaza el timer de espera
//   del finale por un evento de latas (scavenge).
//   Al completar las latas, se llama al vehículo de rescate
//   y termina la ronda normalmente.
//
// Mapas soportados:
//   c2m5_concert      (Feria Siniestra)
//   c3m4_plantation   (La Plantación)
//   c4m5_milltown_escape (Diluvio)
//   c5m5_bridge       (La Parroquia)
//   c8m5_rooftop      (No Mercy)
//   c11m5_runway      (Último Vuelo)
// ============================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

// ============================================================
// CVARS
// ============================================================
ConVar g_cvEnabled;
ConVar g_cvCansRequired;
ConVar g_cvCansFilled;

// ============================================================
// GLOBALS
// ============================================================
bool g_bFinaleStarted    = false;
bool g_bRescueCalled     = false;
int  g_iCansFilled       = 0;
int  g_iCansRequired     = 3;
char g_sCurrentMap[64];

// ============================================================
// PLUGIN INFO
// ============================================================
public Plugin myinfo =
{
    name        = "[L4D2] TankRun Finale Skip",
    author      = "MoY",
    description = "Reemplaza el timer del finale de Tank Run con evento de latas",
    version     = "1.0",
    url         = ""
};

// ============================================================
// ON PLUGIN START
// ============================================================
public void OnPluginStart()
{
    g_cvEnabled      = CreateConVar("tr_finale_skip_enabled",   "1", "Activar el finale skip de Tank Run [0=Off 1=On]");
    g_cvCansRequired = CreateConVar("tr_finale_cans_required",  "3", "Latas necesarias para llamar al rescate [1-10]", _, true, 1.0, true, 10.0);

    HookEvent("round_start",           Event_RoundStart,    EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,      EventHookMode_PostNoCopy);
    HookEvent("finale_start",          Event_FinaleStart,   EventHookMode_Post);
    HookEvent("scavenge_item_rescued", Event_CanFilled,     EventHookMode_Post);

    AutoExecConfig(true, "l4d2_tankrun_finale_skip");
}

// ============================================================
// ON MAP START
// ============================================================
public void OnMapStart()
{
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    g_bFinaleStarted = false;
    g_bRescueCalled  = false;
    g_iCansFilled    = 0;
}

// ============================================================
// EVENTS
// ============================================================
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleStarted = false;
    g_bRescueCalled  = false;
    g_iCansFilled    = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleStarted = false;
    g_bRescueCalled  = false;
    g_iCansFilled    = 0;
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    if (!IsTankRun())
        return;

    g_bFinaleStarted = true;
    g_iCansRequired  = g_cvCansRequired.IntValue;
    g_iCansFilled    = 0;

    // Matar el timer de espera del finale si existe
    KillFinaleTimer();

    // Anunciar el evento a los jugadores
    PrintToChatAll("\x04[Tank Run]\x01 ¡Llena \x05%d latas\x01 para llamar al rescate!", g_iCansRequired);
    PrintToChatAll("\x04[Tank Run]\x01 ¡El timer de espera ha sido eliminado!");
}

public void Event_CanFilled(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    if (!g_bFinaleStarted)
        return;

    if (g_bRescueCalled)
        return;

    if (!IsTankRun())
        return;

    g_iCansFilled++;

    int iRemaining = g_iCansRequired - g_iCansFilled;

    if (iRemaining > 0)
    {
        PrintToChatAll("\x04[Tank Run]\x01 Lata entregada! Faltan \x05%d\x01.", iRemaining);
    }
    else
    {
        g_bRescueCalled = true;
        PrintToChatAll("\x04[Tank Run]\x01 ¡Latas completas! ¡El rescate está en camino!");
        CreateTimer(2.0, Timer_CallRescue, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

// ============================================================
// TIMER - LLAMAR RESCATE
// ============================================================
public Action Timer_CallRescue(Handle timer)
{
    CallRescueVehicle();
    return Plugin_Stop;
}

// ============================================================
// FUNCIONES
// ============================================================

// Verifica si el gamemode actual es tankrun
bool IsTankRun()
{
    char sGameMode[32];
    ConVar cvGameMode = FindConVar("mp_gamemode");
    if (cvGameMode == null)
        return false;

    cvGameMode.GetString(sGameMode, sizeof(sGameMode));
    return StrEqual(sGameMode, "tankrun", false);
}

// Mata el timer del finale para eliminar el countdown de espera
void KillFinaleTimer()
{
    // Buscar y matar entidades de timer del finale
    // Nombres comunes usados por los mapas oficiales
    int ent = -1;

    // Intentar matar timers genéricos del finale
    ent = FindEntityByClassname(ent, "logic_timer");
    while (ent != -1)
    {
        char sName[64];
        GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));

        // Matar timers relacionados al finale
        if (StrContains(sName, "finale", false) != -1 ||
            StrContains(sName, "timer",  false) != -1 ||
            StrContains(sName, "rescue", false) != -1)
        {
            AcceptEntityInput(ent, "Disable");
        }

        ent = FindEntityByClassname(ent, "logic_timer");
    }

    // Matar el director script del finale para evitar el countdown
    int director = FindEntityByClassname(-1, "info_director");
    if (director != -1)
    {
        // Pausar el director brevemente para interrumpir la secuencia del finale
        AcceptEntityInput(director, "PauseThreatLevel");
    }
}

// Llama al vehículo de rescate según el mapa actual
void CallRescueVehicle()
{
    if (StrEqual(g_sCurrentMap, "c2m5_concert", false))
    {
        // Feria Siniestra - Helicóptero
        SetVariantString("exit2");
        AcceptEntityInput(FindEntityByName("stadium_exit_left_chopper_prop"), "SetAnimation");
        AcceptEntityInput(FindEntityByName("stadium_exit_left_outro_camera"), "Enable");
        EndRound();
    }
    else if (StrEqual(g_sCurrentMap, "c3m4_plantation", false))
    {
        // La Plantación - Bote
        AcceptEntityInput(FindEntityByName("camera_outro"), "SetParentAttachment");
        SetVariantString("c3m4_outro_boat");
        AcceptEntityInput(FindEntityByName("escape_boat_prop"), "SetAnimation");
        AcceptEntityInput(FindEntityByName("camera_outro"), "Enable");
        EndRound();
    }
    else if (StrEqual(g_sCurrentMap, "c4m5_milltown_escape", false))
    {
        // Diluvio - Bote
        SetVariantString("c4m5_outro_boat");
        AcceptEntityInput(FindEntityByName("model_boat"), "SetAnimation");
        AcceptEntityInput(FindEntityByName("camera_outro"), "Enable");
        EndRound();
    }
    else if (StrEqual(g_sCurrentMap, "c5m5_bridge", false))
    {
        // La Parroquia - Helicóptero
        SetVariantString("4lift");
        AcceptEntityInput(FindEntityByName("heli_rescue"), "SetAnimation");
        AcceptEntityInput(FindEntityByName("camera_outro"), "Enable");
        EndRound();
    }
    else if (StrEqual(g_sCurrentMap, "c8m5_rooftop", false))
    {
        // No Mercy - Helicóptero
        // Trigger del relay de rescate genérico
        int relay = FindEntityByName("rescue_vehicle_relay");
        if (relay != -1)
            AcceptEntityInput(relay, "Trigger");
        else
        {
            // Fallback: usar ent_fire via cheat
            int director = FindEntityByClassname(-1, "info_director");
            if (director != -1)
                AcceptEntityInput(director, "FinishCustomScriptedSequence");
        }
        EndRound();
    }
    else if (StrEqual(g_sCurrentMap, "c11m5_runway", false))
    {
        // Último Vuelo - Avión
        int relay = FindEntityByName("rescue_vehicle_relay");
        if (relay != -1)
            AcceptEntityInput(relay, "Trigger");
        else
        {
            int director = FindEntityByClassname(-1, "info_director");
            if (director != -1)
                AcceptEntityInput(director, "FinishCustomScriptedSequence");
        }
        EndRound();
    }
    else
    {
        // Mapa no soportado - fallback genérico
        PrintToChatAll("\x04[Tank Run]\x01 Mapa no soportado para rescate automático.");
        PrintToChatAll("\x04[Tank Run]\x01 Intentando rescate genérico...");

        int director = FindEntityByClassname(-1, "info_director");
        if (director != -1)
            AcceptEntityInput(director, "FinishCustomScriptedSequence");
    }
}

// Termina la ronda (survivors escapan)
void EndRound()
{
    // Dar un pequeño delay antes de terminar para que se vea la animación
    CreateTimer(5.0, Timer_EndRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_EndRound(Handle timer)
{
    // Forzar fin de ronda con survivors ganando
    int director = FindEntityByClassname(-1, "info_director");
    if (director != -1)
    {
        AcceptEntityInput(director, "FinishCustomScriptedSequence");
    }
    return Plugin_Stop;
}

// Helper - Busca entidad por targetname
int FindEntityByName(const char[] sName)
{
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "*")) != -1)
    {
        char sEntName[64];
        GetEntPropString(ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
        if (StrEqual(sEntName, sName, false))
            return ent;
    }
    return -1;
}
