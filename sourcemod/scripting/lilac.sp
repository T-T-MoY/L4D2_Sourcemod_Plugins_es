/* lilac.sp - FINAL VERSION (L4D2 Optimized) */

/*
    Little Anti-Cheat (Gemini L4D2 Edition)
    Based on J_Tanzanite's work.
    Updated for SourceMod 1.12 with specific L4D2 protections.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks> // Vital para el detector de daño

#pragma semicolon 1
#pragma newdecls required

/* --- INCLUDES --- */
// Base
#include "lilac/lilac_globals.sp"
#include "lilac/lilac_stock.sp"
#include "lilac/lilac_config.sp"
#include "lilac/lilac_string.sp"
#include "lilac/lilac_convar.sp"
#include "lilac/lilac_database.sp"

// Módulos Estándar (Optimizados)
#include "lilac/lilac_aimbot.sp"
#include "lilac/lilac_aimlock.sp"
#include "lilac/lilac_angles.sp"
#include "lilac/lilac_bhop.sp"
#include "lilac/lilac_lerp.sp"
#include "lilac/lilac_macro.sp"
#include "lilac/lilac_ping.sp"
#include "lilac/lilac_backtrack.sp"

// Módulos Exclusivos L4D2 (NUEVOS)
#include "lilac/lilac_l4d2_exploits.sp"
#include "lilac/lilac_l4d2_damage.sp"
#include "lilac/lilac_l4d2_movement.sp"

// Módulos desactivados/Legacy (Se incluyen solo para que no falten referencias si se activan en otro juego)
#include "lilac/lilac_anti_duck_delay.sp"
#include "lilac/lilac_noisemaker.sp"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};

public void OnPluginStart()
{
    LoadTranslations("lilac.phrases.txt");

    // Detectar Juego
    char gamefolder[32];
    GetGameFolderName(gamefolder, sizeof(gamefolder));

    if (StrEqual(gamefolder, "left4dead2", false)) {
        ggame = GAME_L4D2;
        PrintToServer("[Lilac] L4D2 Mode Active: Exploits, Damage & Movement checks enabled.");
    }
    else if (StrEqual(gamefolder, "csgo", false)) {
        ggame = GAME_CSGO;
    }
    else if (StrEqual(gamefolder, "tf", false)) {
        ggame = GAME_TF2;
    }
    else {
        // Fallback genérico
        ggame = GAME_UNKNOWN;
        if (StrEqual(gamefolder, "cstrike", false)) ggame = GAME_CSS;
        else if (StrEqual(gamefolder, "left4dead", false)) ggame = GAME_L4D;
    }

    // Hooks de Eventos
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam); // Para resetear estados al cambiar de equipo
    HookEvent("player_changename", event_namechange);
    
    // Eventos específicos por juego
    if (ggame == GAME_TF2) {
        HookEvent("player_death", event_player_death_tf2);
        HookEvent("player_teleported", event_teleported);
        HookEvent("post_inventory_application", event_inventoryupdate);
    } else {
        HookEvent("player_death", event_player_death);
        // En L4D2 'player_spawn' cubre la mayoría de teleports lógicos de reinicio
    }

    // Configuración Inicial
    lilac_config_setup();

    if (icvar[CVAR_LOG])
        lilac_log_first_time_setup();

    // Timers Globales
    CreateTimer(QUERY_TIMER, timer_query, _, TIMER_REPEAT); // ConVar check
    CreateTimer(5.0, timer_check_ping, _, TIMER_REPEAT);    // Ping check
    CreateTimer(5.0, timer_check_lerp, _, TIMER_REPEAT);    // Lerp check
    CreateTimer(0.5, timer_check_aimlock, _, TIMER_REPEAT); // Aimlock check
    CreateTimer(300.0, timer_decrement_macro, _, TIMER_REPEAT); // Limpiar macros viejos

    // Inicializar Tickrate
    tick_rate = RoundToNearest(1.0 / GetTickInterval());
    macro_max = (tick_rate >= 60) ? 20 : 0; // Ajuste para macros

    // Auto Update
    if (LibraryExists("updater")) lilac_update_url();
    
    // Forwards Globales
    forwardhandle = CreateGlobalForward("lilac_cheater_detected", ET_Ignore, Param_Cell, Param_Cell);
    forwardhandleban = CreateGlobalForward("lilac_cheater_banned", ET_Ignore, Param_Cell, Param_Cell);
    forwardhandleallow = CreateGlobalForward("lilac_allow_cheat_detection", ET_Event, Param_Cell, Param_Cell);
}

public void OnAllPluginsLoaded()
{
    sourcebanspp_exist = LibraryExists("sourcebans++");
    sourcebans_exist = LibraryExists("sourcebans");
    materialadmin_exist = LibraryExists("materialadmin");
}

public void OnClientPutInServer(int client)
{
    lilac_reset_client(client);
    lilac_string_check_name(client);
    
    // Inicializar submódulos L4D2
    if (ggame == GAME_L4D2) {
        lilac_movement_reset(client);
        lilac_l4d2_damage_hook(client); // SDKHooks para daño
    }

    CreateTimer(30.0, timer_welcome, GetClientUserId(client));
}

// Eventos de Teletransporte (Mapas o Plugins)
public Action event_teleported(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (is_player_valid(client))
        playerinfo_time_teleported[client] = GetGameTime();
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (is_player_valid(client)) {
        playerinfo_time_teleported[client] = GetGameTime();
        lilac_reset_client(client); // Limpiar historial al respawnear
        
        if (ggame == GAME_L4D2) {
            lilac_movement_reset(client);
            playerinfo_is_ghost[client] = IsL4D2Ghost(client);
        }
    }
    return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (is_player_valid(client)) {
        lilac_reset_client(client);
    }
    return Plugin_Continue;
}

public Action timer_welcome(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (is_player_valid(client) && icvar[CVAR_WELCOME] && icvar[CVAR_ENABLE])
        PrintToChat(client, "[Lilac] This server is protected by Little Anti-Cheat (Gemini Ed).");
    return Plugin_Continue;
}

/* --- EL NÚCLEO DEL ANTICHEAT (OnPlayerRunCmd) --- */
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3],
                float angles[3], int& weapon, int& subtype, int& cmdnum,
                int& tickcount, int& seed, int mouse[2])
{
    // Validaciones básicas
    if (!is_player_valid(client) || IsFakeClient(client))
        return Plugin_Continue;

    /* Gestión de índice circular para logs */
    static int lbuttons[MAXPLAYERS + 1]; // Botones anteriores
    if (++playerinfo_index[client] >= CMD_LENGTH) playerinfo_index[client] = 0;

    // Guardar tiempo del comando
    playerinfo_time_usercmd[client][playerinfo_index[client]] = GetGameTime();

    // Actualizar estado Ghost (L4D2) para evitar falsos positivos
    if (ggame == GAME_L4D2) {
        playerinfo_is_ghost[client] = IsL4D2Ghost(client);
    }

    /* --- EJECUCIÓN DE MÓDULOS DE DETECCIÓN --- */
    if (icvar[CVAR_ENABLE]) 
    {
        // 1. CHEQUEOS EXCLUSIVOS L4D2 (Alta Prioridad)
        if (ggame == GAME_L4D2) {
            lilac_l4d2_movement_check(client); // Speedhack & Teleport
        }

        // 2. BACKTRACK (Parchear Tickcount antes de guardar)
        if (icvar[CVAR_BACKTRACK_PATCH]) {
            tickcount = lilac_backtrack_patch(client, tickcount);
        } else {
            // Si el parche está apagado, solo guardamos el tick para referencia
            lilac_backtrack_store_tickcount(client, tickcount);
        }

        // 3. ANGLES (Spinbot / Anti-Aim)
        if (icvar[CVAR_ANGLES])
            lilac_angles_check(client, angles);

        // 4. MACROS (Auto-Jump / Auto-Shoot)
        if (macro_max && icvar[CVAR_MACRO])
            lilac_macro_check(client, buttons, lbuttons[client]);

        // 5. BUNNYHOP (Scripts de salto perfecto)
        if (!force_disable_bhop && icvar[CVAR_BHOP])
            lilac_bhop_check(client, buttons, lbuttons[client]);

        // 6. ANTI-DUCK (Solo CS:GO, se ignora en L4D2)
        if (ggame == GAME_CSGO && icvar[CVAR_ANTI_DUCK_DELAY])
            lilac_anti_duck_delay_check(client, buttons);

        // 7. PARCHES ACTIVOS
        if (icvar[CVAR_PATCH_ANGLES])
            lilac_angles_patch(angles);
    }

    /* --- GUARDADO DE DATOS --- */
    // Guardar ángulos y botones para uso futuro (Aimbot/Aimlock analysis)
    set_player_log_angles(client, angles, playerinfo_index[client]);
    playerinfo_buttons[client][playerinfo_index[client]] = buttons;
    playerinfo_actions[client][playerinfo_index[client]] = 0; // Reset acciones

    // Detectar si disparó en este tick (Para Aimbot)
    if ((buttons & IN_ATTACK) && bullettime_can_shoot(client))
        playerinfo_actions[client][playerinfo_index[client]] |= ACTION_SHOT;

    lbuttons[client] = buttons; // Actualizar botones "anteriores"

    return Plugin_Continue;
}

// Hook de comandos de cliente para Anti-Exploit
public Action OnClientCommand(int client, int args)
{
    // Pasar al módulo de exploits de L4D2 (Anti-Crasher/Flood)
    if (ggame == GAME_L4D2) {
        return lilac_l4d2_exploits_check_command(client, args);
        // Nota: Asegúrate de que la función en lilac_l4d2_exploits.sp se llame así
        // o ajusta el nombre aquí según como lo hayas guardado.
        // Si usaste el nombre del ejemplo anterior (OnClientCommand dentro del módulo),
        // SourceMod automáticamente une los hooks, así que no necesitas llamarlo explícitamente aquí
        // a menos que quieras controlar el orden.
        // Si lilac_l4d2_exploits.sp tiene "public Action OnClientCommand", ¡BÓRRALO de aquí!
        // SourceMod ejecutará ambos.
    }
    return Plugin_Continue;
}