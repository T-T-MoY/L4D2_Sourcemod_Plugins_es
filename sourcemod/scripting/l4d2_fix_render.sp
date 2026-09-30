#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name = "Areaportal/Render Fixer",
    author = "Moises",
    description = "Fuerza la apertura de areaportals para evitar ver el vacio/inframundo en mapas bugueados.",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    // Comando manual para administradores por si acaso se necesita en medio del juego
    RegAdminCmd("sm_fixvoid", Command_FixVoid, ADMFLAG_ROOT, "Fuerza la apertura de todos los areaportals para corregir bugs visuales de render.");
    
    // Ejecutar la corrección automáticamente cuando el mapa carga
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Damos un pequeño retraso para asegurar que todas las entidades del mapa hayan cargado
    CreateTimer(2.0, Timer_FixRender);
}

public Action Timer_FixRender(Handle timer)
{
    int arreglados = AbrirAreaportals();
    PrintToServer("[Render Fix] Se forzo la apertura de %d areaportals para evitar bugs visuales.", arreglados);
    return Plugin_Stop;
}

public Action Command_FixVoid(int client, int args)
{
    int arreglados = AbrirAreaportals();
    
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "\x04[Render Fix]\x01 Se abrieron \x03%d\x01 areaportals forzosamente.", arreglados);
    }
    else
    {
        PrintToServer("[Render Fix] Se abrieron %d areaportals forzosamente.", arreglados);
    }
    
    return Plugin_Handled;
}

int AbrirAreaportals()
{
    int count = 0;
    int entity = -1;

    // Buscar y abrir todos los func_areaportal normales
    while ((entity = FindEntityByClassname(entity, "func_areaportal")) != -1)
    {
        if (IsValidEntity(entity))
        {
            AcceptEntityInput(entity, "Open");
            count++;
        }
    }

    // Buscar func_areaportalwindow (ventanas que se desvanecen con la distancia)
    // Las forzamos a mostrarse siempre poniendo su distancia de desvanecimiento muy alta
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "func_areaportalwindow")) != -1)
    {
        if (IsValidEntity(entity))
        {
            // Cambiado "PropData" por el enumerador correcto Prop_Data sin comillas
            SetEntPropFloat(entity, Prop_Data, "m_flFadeStartDist", 99999.0);
            SetEntPropFloat(entity, Prop_Data, "m_flFadeDist", 99999.0);
            count++;
        }
    }

    return count;
}