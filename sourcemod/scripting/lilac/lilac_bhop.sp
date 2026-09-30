/* lilac/lilac_bhop.sp */

#if defined _lilac_bhop_included
 #endinput
#endif
#define _lilac_bhop_included

/* Bhop Detection Module (Updated for SM 1.12 + L4D2 Fixes) */

static int jump_ticks[MAXPLAYERS + 1];
static int perfect_bhops[MAXPLAYERS + 1];
static int next_bhop[MAXPLAYERS + 1];
static int detections[MAXPLAYERS + 1];

/* Helper interno para reiniciar contadores de un salto específico */
static void bhop_reset(int client)
{
    /* -1 porque el primer salto es legítimo y no cuenta como "bhop" */
    jump_ticks[client] = -1;
    perfect_bhops[client] = -1;
    next_bhop[client] = GetGameTickCount();
}

/* Función pública para reiniciar todo el cliente (al conectar) */
void lilac_bhop_reset_client(int client)
{
    bhop_reset(client);
    detections[client] = 0;
}

/* Función principal llamada frame a frame */
void lilac_bhop_check(int client, int buttons, int last_buttons)
{
    // 1. Si ya está baneado, no hacer nada
    if (playerinfo_banned_flags[client][CHEAT_BHOP])
        return;

    // 2. L4D2 FIXES:
    if (ggame == GAME_L4D2)
    {
        // Ignorar fantasmas (spamean salto para volar)
        if (playerinfo_is_ghost[client]) 
        {
            bhop_reset(client);
            return;
        }

        // Ignorar si está colgado de un borde o incapacitado
        if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0 || 
            GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0)
        {
            bhop_reset(client);
            return;
        }
        
        // Ignorar si está siendo atacado (Jockey/Charger/Hunter)
        // Esto evita falsos positivos cuando el infectado salta contigo
        if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
            GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
            GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
        {
            bhop_reset(client);
            return;
        }
    }

    // 3. Contar ticks sosteniendo la barra espaciadora
    if ((buttons & IN_JUMP))
        jump_ticks[client]++;

    int flags = GetEntityFlags(client);

    // 4. DETECCIÓN: Salto justo al tocar el suelo
    // (Botón presionado AHORA y NO estaba presionado ANTES = Nuevo click)
    if ((buttons & IN_JUMP) && !(last_buttons & IN_JUMP)) 
    {
        if ((flags & FL_ONGROUND)) 
        {
            // Verificar si ha pasado el tiempo mínimo de "suelo" (Cooldown)
            if (GetGameTickCount() > next_bhop[client]) 
            {
                // Salto perfecto detectado
                next_bhop[client] = GetGameTickCount() + bhop_settings[BHOP_INDEX_AIR];
                perfect_bhops[client]++;
                
                // Verificar si superó el límite Máximo
                check_bhop_max(client);
            }
            else 
            {
                // Saltó muy rápido (error humano o script fallando), reiniciar racha
                bhop_reset(client);
            }
        }
    }
    // 5. Si está en el suelo pero NO salta (rompió la cadena de bhop)
    else if ((flags & FL_ONGROUND)) 
    {
        // Verificar si tenía una racha acumulada suficiente para banear
        check_bhop_min(client);
        bhop_reset(client);
    }
}

static void check_bhop_max(int client)
{
    /* Si la config de MAX es inválida, salir */
    if (bhop_settings[BHOP_INDEX_MAX] < bhop_settings_min[BHOP_INDEX_MAX])
        return;

    /* Si no ha llegado al límite, salir */
    if (perfect_bhops[client] < bhop_settings[BHOP_INDEX_MAX])
        return;

    /* Permitir bloqueo externo */
    if (!lilac_forward_allow_cheat_detection(client, CHEAT_BHOP))
        return;

    /* BANEO DIRECTO (Racha inhumana instantánea) */
    lilac_detected_bhop(client, true, true);
    lilac_ban_bhop(client);
}

static void check_bhop_min(int client)
{
    /* Config inválida */
    if (bhop_settings[BHOP_INDEX_MIN] < bhop_settings_min[BHOP_INDEX_MIN])
        return;

    /* No llegó al mínimo de sospecha */
    if (perfect_bhops[client] < bhop_settings[BHOP_INDEX_MIN])
        return;

    /* LÓGICA DE HYPER-SCROLL / MACRO:
       Si hizo muchos saltos perfectos, pero mantuvo la tecla pulsada demasiados ticks
       (jump_ticks alto), probablemente sea un humano spameando la rueda del ratón o espacio.
       Ignorar si jump_ticks es muy alto. */
    if (bhop_settings[BHOP_INDEX_JUMP] > -1
        && jump_ticks[client] > bhop_settings[BHOP_INDEX_JUMP] + bhop_settings[BHOP_INDEX_MIN])
    {
        return;
    }

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_BHOP))
        return;

    /* Detección Acumulativa */
    lilac_detected_bhop(client, false, false);
}

static void lilac_detected_bhop(int client, bool force_log, bool banning)
{
    lilac_forward_client_cheat(client, CHEAT_BHOP);

    /* La detección expira en 10 minutos */
    CreateTimer(600.0, timer_decrement_bhop, GetClientUserId(client));

    /* No loguear la primera vez a menos que sea forzado (MAX bhop) */
    if (++detections[client] < 2 && !force_log)
        return;

    /* Avisar a admins (si no es ban directo todavía) */
    if (icvar[CVAR_CHEAT_WARN] && !banning && detections[client] < bhop_settings[BHOP_INDEX_TOTAL])
        lilac_warn_admins(client, CHEAT_BHOP, detections[client]);

    /* Logging */
    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer),
            "%s Suspected Bhop (Detection: %d | Bhops: %d | JumpTicks: %d).",
            line_buffer, detections[client], perfect_bhops[client], jump_ticks[client]);
        
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(client);
    }
    
    database_log(client, "bhop", detections[client], float(perfect_bhops[client]), float(jump_ticks[client]));

    /* Si alcanzó el total de detecciones necesarias -> BAN */
    if (detections[client] >= bhop_settings[BHOP_INDEX_TOTAL])
        lilac_ban_bhop(client);
}

static void lilac_ban_bhop(int client)
{
    if (playerinfo_banned_flags[client][CHEAT_BHOP]) return;

    playerinfo_banned_flags[client][CHEAT_BHOP] = true;

    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s Banned for Bhop.", line_buffer);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }
    
    database_log(client, "bhop", DATABASE_BAN);
    lilac_ban_client(client, CHEAT_BHOP);
}

public Action timer_decrement_bhop(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (is_player_valid(client) && detections[client] > 0)
        detections[client]--;
    return Plugin_Continue;
}