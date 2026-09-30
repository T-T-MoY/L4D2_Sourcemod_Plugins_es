/* lilac/lilac_ping.sp */

#if defined _lilac_ping_included
 #endinput
#endif
#define _lilac_ping_included

/* Ping Limiter Module (Updated for SM 1.12) */

static int ping_high[MAXPLAYERS + 1];
static int ping_warn[MAXPLAYERS + 1];

void lilac_ping_reset_client(int client)
{
    ping_high[client] = 0;
    ping_warn[client] = 0;
}

public Action timer_check_ping(Handle timer)
{
    static bool toggle = true;
    char reason[128];
    float ping;

    // Si está desactivado o el límite es muy bajo (<100), no hacer nada
    if (!icvar[CVAR_ENABLE] || icvar[CVAR_MAX_PING] < 100)
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!is_player_valid(i) || IsFakeClient(i))
            continue;

        /* Jugadores recién conectados: Esperar 120s para que su conexión se estabilice */
        if (GetClientTime(i) < 120.0)
            continue;

        // Obtener Ping real (Latency * 1000)
        ping = GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0;

        // --- CASO 1: PING NORMAL ---
        if (ping < float(icvar[CVAR_MAX_PING])) 
        {
            // Reducir el contador de "ping alto" gradualmente si la conexión mejora
            if (toggle && ping_high[i] > 0)
                ping_high[i]--;

            // Si el jugador estaba advertido y ya bajó su nivel de alerta
            if (ping_high[i] < ping_warn[i] - 2 && ping_warn[i] > 0) {
                ping_warn[i] = 0;
                PrintToChat(i, "\x04[Lilac]\x01 Your ping has stabilized. You can play safely now.");
            }
            continue;
        }

        // --- CASO 2: PING ALTO DETECTADO ---
        
        // Fase de Espectador (Advertencia)
        // Si superó el umbral para espectador (ej. 30s con lag)
        if (++ping_high[i] >= icvar[CVAR_MAX_PING_SPEC] / 5 && icvar[CVAR_MAX_PING_SPEC] >= 30) 
        {
            // En L4D2, mover a spec funciona bien (Team 1)
            if (GetClientTeam(i) != 1) {
                ChangeClientTeam(i, 1); // Mover a Spectator
                PrintToChat(i, "\x04[Lilac]\x01 Moved to Spectator due to High Ping.");
            }

            ping_warn[i] = ping_high[i];

            // Mensajes de advertencia periódicos
            int time_left = 100 - (ping_high[i] * 5); // Segundos restantes aprox antes del kick
            if (time_left > 0 && time_left % 10 == 0) {
                PrintToChat(i, "\x04[Lilac]\x01 WARNING: High Ping Kick in %d seconds! (%.0f / %d max)", 
                    time_left, ping, icvar[CVAR_MAX_PING]);
            }
        }

        // Fase de Kick/Ban (Tras ~100 segundos de lag sostenido)
        if (ping_high[i] < 20)
            continue;

        // LOGGING
        if (icvar[CVAR_LOG_MISC]) {
            lilac_log_setup_client(i);
            Format(line_buffer, sizeof(line_buffer), 
                "%s Kicked for High Ping (%.0fms / %dms max).", 
                line_buffer, ping, icvar[CVAR_MAX_PING]);
            
            lilac_log(true);
            if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(i);
        }
        database_log(i, "high_ping", DATABASE_KICK);

        // BANEO TEMPORAL (3 MINUTOS)
        // Esto evita que intenten reconectarse inmediatamente y sigan lageando
        Format(reason, sizeof(reason), "[Lilac] High Ping (%.0fms > %dms)", ping, icvar[CVAR_MAX_PING]);
        BanClient(i, 3, BANFLAG_AUTO, reason, reason, "lilac");
    }

    toggle = !toggle;
    return Plugin_Continue;
}