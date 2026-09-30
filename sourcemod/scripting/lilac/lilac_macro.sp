/* lilac/lilac_macro.sp */

#if defined _lilac_macro_included
 #endinput
#endif
#define _lilac_macro_included

/* Macro Detection Module (Auto-Jump / Auto-Shoot) */
/* Updated for SM 1.12 + L4D2 Tweaks */

static int macro_history[MAXPLAYERS + 1][MACRO_ARRAY][MACRO_LOG_LENGTH];
static int macro_detected[MAXPLAYERS + 1][MACRO_ARRAY];

/* Helper para reiniciar historial de un tipo específico */
static void lilac_macro_reset_client_history(int client, int type)
{
    if (type < 0 || type >= MACRO_ARRAY)
        return;

    for (int i = 0; i < MACRO_LOG_LENGTH; i++)
        macro_history[client][type][i] = 0;
}

void lilac_macro_reset_client(int client)
{
    for (int i = 0; i < MACRO_ARRAY; i++) {
        macro_detected[client][i] = 0;
        lilac_macro_reset_client_history(client, i);
    }
}

/* Función principal llamada desde OnPlayerRunCmd */
void lilac_macro_check(int client, int buttons, int last_buttons)
{
    static int index[MAXPLAYERS + 1];

    // Buffer circular basado en tickrate
    if (++index[client] >= tick_rate)
        index[client] = 0;

    for (int i = 0; i < MACRO_ARRAY; i++) 
    {
        /* Si no estamos escaneando este tipo de macro, saltar */
        if (!process_macro_type(i))
            continue;

        int input = get_macro_input(i);
        
        // Detectar pulsación NUEVA (Key Down)
        bool key_pressed = (!(last_buttons & input) && (buttons & input));
        
        // Guardar en historial
        macro_history[client][i][index[client]] = key_pressed ? 1 : 0;

        /* Solo analizar si acaba de pulsar la tecla */
        if (!key_pressed)
            continue;

        // Contar cuántos clicks ha hecho en el último segundo (tick_rate frames)
        int clicks_per_second = 0;
        for (int k = 0; k < tick_rate; k++) {
            if (macro_history[client][i][k])
                clicks_per_second++;
        }

        /* L4D2 TWEAK: Si es Auto-Shoot y tiene pistolas, ser más tolerante */
        int threshold = macro_max;
        
        if (i == MACRO_AUTOSHOOT && ggame == GAME_L4D2) {
            // En L4D2 con duales se puede clickear muy rapido. Aumentamos margen.
            // Si el default es ~15, lo subimos a 18 para pistolas.
            threshold += 3; 
        }

        /* Si supera el límite humano de clicks por segundo */
        if (clicks_per_second >= threshold)
            lilac_detected_macro(client, i);
    }
}

static bool process_macro_type(int macro_type)
{
    if (macro_type >= MACRO_ARRAY || macro_type < 0) return false;

    // 0 = Detectar todo
    if (!icvar[CVAR_MACRO_MODE]) return true;

    // Chequeo de bits (1 = Jump, 2 = Shoot)
    return (icvar[CVAR_MACRO_MODE] & (1 << macro_type)) ? true : false;
}

static int get_macro_input(int macro_type)
{
    switch (macro_type) {
        case MACRO_AUTOJUMP: return IN_JUMP;
        case MACRO_AUTOSHOOT: return IN_ATTACK;
        default: return 0;
    }
}

static void lilac_detected_macro(int client, int type)
{
    char string[32];

    /* Limpiar historial para evitar detecciones en cadena en el mismo segundo */
    lilac_macro_reset_client_history(client, type);

    if (playerinfo_banned_flags[client][CHEAT_MACRO]) return;

    /* Anti-Spam */
    if (playerinfo_time_forward[client][CHEAT_MACRO] > GetGameTime()) return;

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_MACRO)) {
        playerinfo_time_forward[client][CHEAT_MACRO] = GetGameTime() + 5.0;
        return;
    }

    switch (type) {
        case MACRO_AUTOJUMP:  strcopy(string, sizeof(string), "Auto-Jump");
        case MACRO_AUTOSHOOT: strcopy(string, sizeof(string), "Auto-Shoot");
        default: return;
    }

    lilac_forward_client_cheat(client, CHEAT_MACRO);

    /* Ignorar primera detección (falsos positivos humanos) */
    if (++macro_detected[client][type] < 2) return;

    /* LOGGING */
    if (icvar[CVAR_LOG] && icvar[CVAR_MACRO] < 2) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), 
            "%s detected using Macro %s (Count: %d | CPS: %d).", 
            line_buffer, string, macro_detected[client][type], macro_max);
        
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }

    // Nombre para base de datos (macro_autojump, macro_autoshoot)
    char db_cheat[32];
    Format(db_cheat, sizeof(db_cheat), "macro_%s", (type == MACRO_AUTOJUMP) ? "autojump" : "autoshoot");
    database_log(client, db_cheat, macro_detected[client][type], float(macro_max));

    /* WARNING SYSTEM */
    if (icvar[CVAR_MACRO] > -1) {
        switch (icvar[CVAR_MACRO_WARNING]) {
            case 1: { // Warn Player
                PrintCenterText(client, "[Lilac] Warning: Macro usage is forbidden!");
                PrintToChat(client, "\x04[Lilac]\x01 Warning: Macro usage is forbidden!");
            }
            case 2: { // Warn Admins
                 // (Simplificado) lilac_warn_admins ya hace esto mejor, pero mantenemos lógica original
                 if (macro_detected[client][type] == 2)
                    lilac_warn_admins(client, CHEAT_MACRO, macro_detected[client][type]);
            }
            case 3: { // Warn All
                if (macro_detected[client][type] == 2)
                    PrintToChatAll("\x04[Lilac]\x01 %N detected using %s macro.", client, string);
            }
        }
    }

    /* PUNISHMENT (Require 5+ detections) */
    if (macro_detected[client][type] < 5) return;

    playerinfo_banned_flags[client][CHEAT_MACRO] = true;

    if (icvar[CVAR_MACRO] == -1) return; // Log only mode

    if (icvar[CVAR_MACRO_DEAL_METHOD] == 0)
        KickClient(client, "[Lilac] Kicked for Macro Usage (%s)", string);
    else
        lilac_ban_client(client, CHEAT_MACRO);
}

public Action timer_decrement_macro(Handle timer)
{
    // Reducir nivel de detección cada 5 minutos
    for (int i = 1; i <= MaxClients; i++) {
        for (int k = 0; k < MACRO_ARRAY; k++) {
            if (macro_detected[i][k] > 0)
                macro_detected[i][k]--;
        }
    }
    return Plugin_Continue;
}