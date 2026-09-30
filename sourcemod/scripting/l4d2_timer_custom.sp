#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "3.2"

ConVar g_hEnable;
ConVar g_hCustomTime;

bool   g_bFinaleActive  = false;
bool   g_bRescueCalled  = false;
Handle g_hTimerRescue   = null;
Handle g_hTimerCountdown = null;
int    g_iCountdown     = 0;

public Plugin myinfo =
{
    name        = "TankRun Finale Controller",
    author      = "[T-T]Moy",
    description = "Controla finale de TankRun sin bugs",
    version     = PLUGIN_VERSION,
    url         = ""
};

public void OnPluginStart()
{
    g_hEnable     = CreateConVar("sm_tr_finale_enable", "1",    "Activar plugin");
    g_hCustomTime = CreateConVar("sm_tr_finale_time",   "60.0", "Tiempo hasta rescate (segundos)");

    HookEvent("finale_start",           Event_FinaleStart);
    HookEvent("finale_vehicle_leaving", Event_FinaleEnd);
    HookEvent("round_end",              Event_RoundEnd);
}

bool IsTankRun()
{
    char mode[32];
    FindConVar("mp_gamemode").GetString(mode, sizeof(mode));
    return (StrContains(mode, "tank", false) != -1);
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue) return;
    if (!IsTankRun())         return;
    if (g_bFinaleActive)      return;

    g_bFinaleActive = true;
    g_bRescueCalled = false;

    int time     = RoundToFloor(g_hCustomTime.FloatValue);
    g_iCountdown = time;

    PrintToChatAll("\x04[TankRun]\x01 Finale iniciado. Rescate en \x03%d segundos", time);

    // Avanzar el stage DELAY del juego para "consumirlo" inmediatamente.
    // Esto saca al Director del timer interno de ese mapa.
    // Usamos un pequeño delay para que el evento finale_start termine de procesarse.
    CreateTimer(0.5, Timer_SkipInitialStage);

    // Timer principal de rescate
    g_hTimerRescue = CreateTimer(float(time), Timer_CallRescue, _, TIMER_FLAG_NO_MAPCHANGE);

    // HUD countdown — guardamos el handle para poder matarlo
    g_hTimerCountdown = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SkipInitialStage(Handle timer)
{
    // Solo avanzamos si el finale sigue activo y no se llamó el rescue aún.
    // Esto "consume" el DELAY stage del mapa y queda esperando el siguiente ForceNextStage
    // que llamaremos nosotros cuando expire nuestro timer custom.
    if (g_bFinaleActive && !g_bRescueCalled)
        L4D2_ForceNextStage();

    return Plugin_Stop;
}

public Action Timer_Countdown(Handle timer)
{
    if (!g_bFinaleActive || g_bRescueCalled)
    {
        g_hTimerCountdown = null;
        return Plugin_Stop;
    }

    if (g_iCountdown <= 0)
    {
        g_hTimerCountdown = null;
        return Plugin_Stop;
    }

    PrintHintTextToAll("☁ Rescate en: %d", g_iCountdown);
    g_iCountdown--;

    return Plugin_Continue;
}

public Action Timer_CallRescue(Handle timer)
{
    g_hTimerRescue = null;

    if (!g_bFinaleActive || g_bRescueCalled)
        return Plugin_Stop;

    g_bRescueCalled = true;
    g_iCountdown    = 0;

    PrintToChatAll("\x04[TankRun]\x01 ¡El rescate está en camino!");
    PrintHintTextToAll("¡Rescate en camino!");

    // Avanzar al stage del vehículo de rescate.
    // Si el mapa tiene más de un stage intermedio, puede necesitar
    // múltiples calls. Para la mayoría de finales holdout es uno solo.
    L4D2_ForceNextStage();

    return Plugin_Stop;
}

public void Event_FinaleEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetPlugin();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetPlugin();
}

public void OnMapStart()
{
    ResetPlugin();
}

void ResetPlugin()
{
    g_bFinaleActive = false;
    g_bRescueCalled = false;
    g_iCountdown    = 0;

    if (g_hTimerRescue != null)
    {
        KillTimer(g_hTimerRescue);
        g_hTimerRescue = null;
    }

    if (g_hTimerCountdown != null)
    {
        KillTimer(g_hTimerCountdown);
        g_hTimerCountdown = null;
    }
}