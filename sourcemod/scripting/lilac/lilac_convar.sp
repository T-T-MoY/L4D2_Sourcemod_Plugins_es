/* lilac/lilac_convar.sp */

#if defined _lilac_convar_included
 #endinput
#endif
#define _lilac_convar_included

/* ConVar Query Module (Updated for SM 1.12 + L4D2) */

/* Lista de CVars críticas a escanear */
static char query_list[][] = {
    "sv_cheats",
    "r_drawothermodels",
    "mat_wireframe",
    "snd_show",
    "snd_visualize",
    "mat_proxy",
    "r_drawmodelstatsoverlay",
    "r_shadowwireframe",
    "r_showenvcubemap",
    "r_drawrenderboxes",
    "r_modelwireframedecal"
};

// Variables para control de queries
static int query_index[MAXPLAYERS + 1];
static int query_failed[MAXPLAYERS + 1];

void lilac_convar_reset_client(int client)
{
    query_index[client] = 0;
    query_failed[client] = 0;
}

public Action timer_query(Handle timer)
{
    if (!icvar[CVAR_ENABLE] || !icvar[CVAR_CONVAR])
        return Plugin_Continue;

    /* Si sv_cheats cambió recientemente o está en 1, abortar escaneo */
    if (GetTime() < time_sv_cheats || sv_cheats)
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!is_player_valid(i) || IsFakeClient(i))
            continue;

        /* Jugadores recién conectados (esperar 60s) */
        if (GetClientTime(i) < 60.0)
            continue;

        /* Ignorar baneados */
        if (playerinfo_banned_flags[i][CHEAT_CONVAR])
            continue;

        /* Incrementar índice solo si respondió al anterior */
        if (!query_failed[i]) {
            if (++query_index[i] >= sizeof(query_list))
                query_index[i] = 0;
        }

        /* Enviar Query */
        QueryClientConVar(i, query_list[query_index[i]], query_reply, 0);

        /* Control de Fallos (Kick por Timeout) */
        if (++query_failed[i] > QUERY_MAX_FAILURES) 
        {
            if (icvar[CVAR_LOG_MISC]) {
                lilac_log_setup_client(i);
                Format(line_buffer, sizeof(line_buffer), 
                    "%s Kicked for query failure (Attempts: %d | Time: %.0f sec).", 
                    line_buffer, QUERY_MAX_FAILURES, QUERY_TIMER * QUERY_MAX_FAILURES);
                
                lilac_log(true);
                if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(i);
            }
            database_log(i, "cvar_query_failure", DATABASE_KICK, float(QUERY_MAX_FAILURES), QUERY_TIMER * QUERY_MAX_FAILURES);
            
            KickClient(i, "[Lilac] Query Timeout (Lag or Cheat)");
        }
    }
    return Plugin_Continue;
}

public void query_reply(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
    /* El cliente respondió, reseteamos fallos */
    if (is_player_valid(client))
        query_failed[client] = 0;
    else
        return; // Cliente desconectado

    if (result != ConVarQuery_Okay) return; // Error de transmisión, ignorar

    /* Si el servidor tiene cheats activados, ignorar respuestas */
    if (GetTime() < time_sv_cheats || sv_cheats) return;

    if (playerinfo_banned_flags[client][CHEAT_CONVAR]) return;

    int val = StringToInt(cvarValue);

    /* --- ANÁLISIS DE RESPUESTA --- */
    
    // Regla 1: r_drawothermodels debe ser 1
    if (StrEqual("r_drawothermodels", cvarName, false)) {
        if (val == 1) return; // OK
    }
    // Regla 2: El resto deben ser 0
    else {
        if (val == 0) return; // OK
    }

    // SI LLEGAMOS AQUÍ, DETECTAMOS UN VALOR ILEGAL

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_CONVAR)) return;

    lilac_forward_client_cheat(client, CHEAT_CONVAR);

    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s Illegal ConVar Detected (%s = %s).", line_buffer, cvarName, cvarValue);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }
    database_log(client, "cvar_invalid", DATABASE_BAN);

    playerinfo_banned_flags[client][CHEAT_CONVAR] = true;
    lilac_ban_client(client, CHEAT_CONVAR);
}