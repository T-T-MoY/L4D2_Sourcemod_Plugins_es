/* lilac/lilac_aimlock.sp */

#if defined _lilac_aimlock_included
 #endinput
#endif
#define _lilac_aimlock_included

/* Aimlock Detection Module (Updated for SM 1.12 + L4D2) */

/* Helper: ¿Debemos ignorar a este atacante? */
static bool aimlock_skip_player(int client)
{
    // Validaciones básicas
    if (!is_player_valid(client) || IsFakeClient(client) || !IsPlayerAlive(client))
        return true;

    // L4D2 Específico:
    if (ggame == GAME_L4D2)
    {
        // Solo escanear Supervivientes (Team 2).
        // Los infectados (Team 3) tienen mecánicas de "lock" naturales (Smoker, Jockey).
        if (GetClientTeam(client) != 2) return true;
        
        // Si es fantasma (por seguridad, aunque el team check ya lo cubriría a veces)
        if (playerinfo_is_ghost[client]) return true;
    }
    else
    {
        // Juegos genéricos (CSGO, CSS, TF2)
        if (GetClientTeam(client) < 2) return true;
    }

    // Si se acaba de teletransportar, esperar 2 segundos
    if (GetGameTime() - playerinfo_time_teleported[client] < 2.0)
        return true;

    // Si tiene pérdida de paquetes, el aim se ve robótico
    if (skip_due_to_loss(client))
        return true;

    // Si ya está baneado por aimlock, no gastar CPU
    if (playerinfo_banned_flags[client][CHEAT_AIMLOCK])
        return true;

    /* Modo Ligero: Solo procesar jugadores en la "cola" de sospechosos */
    if (icvar[CVAR_AIMLOCK_LIGHT] == 1 && !lilac_is_player_in_aimlock_que(client))
        return true;

    return false;
}

/* Helper: ¿Es este objetivo válido para ser escaneado? */
static bool aimlock_skip_target(int client, int target)
{
    // Validaciones básicas de objetivo
    if (client == target || !is_player_valid(target) || !IsPlayerAlive(target))
        return true;

    // No escanear compañeros de equipo
    if (GetClientTeam(client) == GetClientTeam(target))
        return true;

    // L4D2: Ignorar objetivos fantasmas (Infectados spawneando)
    if (ggame == GAME_L4D2 && playerinfo_is_ghost[target])
        return true;

    // Objetivo recién teletransportado (o spawneado)
    if (GetGameTime() - playerinfo_time_teleported[target] < 2.0)
        return true;

    return false;
}

/* --- TIMER PRINCIPAL DE ESCANEO --- */
public Action timer_check_aimlock(Handle timer)
{
    if (!icvar[CVAR_ENABLE] || !icvar[CVAR_AIMLOCK])
        return Plugin_Continue;

    float pos[3], pos2[3];
    int players_processed = 0;
    bool detected_aimlock[MAXPLAYERS + 1];

    // Limpieza inicial
    for (int i = 1; i <= MaxClients; i++) detected_aimlock[i] = false;

    for (int client = 1; client <= MaxClients; client++) 
    {
        /* Optimización de CPU: No procesar más de 5 jugadores por tick del timer */
        if (icvar[CVAR_AIMLOCK_LIGHT] == 1 && players_processed >= 5)
            continue;

        if (aimlock_skip_player(client))
            continue;

        GetClientEyePosition(client, pos);
        players_processed++;

        bool process = true;

        // Loop contra todos los posibles objetivos
        for (int target = 1; process && target <= MaxClients; target++) 
        {
            if (aimlock_skip_target(client, target))
                continue;

            GetClientEyePosition(target, pos2);

            /* Si está muy cerca (< 300 unidades), el aimlock es difícil de distinguir del aim natural */
            if (GetVectorDistance(pos, pos2) < 300.0) {
                detected_aimlock[client] = false;
                process = false; // Dejar de escanear a este cliente por este tick
                continue;
            }

            /* Si ya detectamos aimlock en este tick contra un objetivo, no hace falta chequear los demás */
            if (detected_aimlock[client])
                continue;

            // Análisis matemático
            if (is_aimlocking(client, pos, pos2))
                detected_aimlock[client] = true;
        }
    }

    // Procesar detecciones
    for (int i = 1; i <= MaxClients; i++) {
        if (detected_aimlock[i])
            lilac_detected_aimlock(i);
    }

    return Plugin_Continue;
}

/* --- MATEMÁTICAS DEL AIMLOCK --- */
static bool is_aimlocking(int client, float pos[3], float pos2[3])
{
    float ideal[3], lang[3], ang[3];
    float laimdist, aimdist;
    int lock = 0;
    int ind = playerinfo_index[client];

    // Calcular ángulo ideal hacia el objetivo
    aim_at_point(pos, pos2, ideal);

    // Revisar historial de 0.6 segundos
    for (int i = 0; i < time_to_ticks(0.6); i++) 
    {
        if (ind < 0) ind += CMD_LENGTH;

        // Solo procesar comandos recientes
        if (GetGameTime() - playerinfo_time_usercmd[client][ind] < 0.6) 
        {
            get_player_log_angles(client, ind, false, ang);
            laimdist = angle_delta(ang, ideal);

            if (i > 0) 
            {
                // Si la mira está pegada al objetivo (menos de 5 grados de error)
                if (aimdist < 5.0)
                    lock++;
                else
                    lock = 0;

                /* CRITERIO DE DETECCIÓN:
                   1. La mira está MUY cerca del objetivo (aimdist < 10% del movimiento anterior)
                   2. El jugador movió la mira rápido (angle_delta > 20 grados)
                   3. Mantuvo el lock por más de 0.1 segundos (lock > ticks)
                */
                if (aimdist < laimdist * 0.1 
                    && angle_delta(ang, lang) > 20.0 
                    && lock > time_to_ticks(0.1))
                {
                    return true;
                }
            }

            lang = ang;
            aimdist = laimdist;
        }
        ind--;
    }
    return false;
}

/* --- REPORTE Y BANEO --- */
static void lilac_detected_aimlock(int client)
{
    if (playerinfo_banned_flags[client][CHEAT_AIMLOCK]) return;

    // Sistema de "Sospechas" (Suspicion)
    // Se necesitan 2 detecciones en un lapso de 3 minutos para confirmar
    if (GetGameTime() - playerinfo_time_aimlock[client] < 180.0)
        playerinfo_aimlock_sus[client]++;
    else
        playerinfo_aimlock_sus[client] = 1;

    playerinfo_time_aimlock[client] = GetGameTime();

    // Si aún no alcanza el umbral de sospecha
    if (playerinfo_aimlock_sus[client] < 2) return;

    playerinfo_aimlock_sus[client] = 0; // Reset sospechas, pasamos a Detección Real

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_AIMLOCK)) return;

    // Timer de expiración (10 mins)
    CreateTimer(600.0, timer_decrement_aimlock, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    lilac_forward_client_cheat(client, CHEAT_AIMLOCK);

    // No loguear la primera detección real (dar margen de duda)
    if (++playerinfo_aimlock[client] < 2) return;

    // AVISAR ADMINS
    if (icvar[CVAR_CHEAT_WARN])
        lilac_warn_admins(client, CHEAT_AIMLOCK, playerinfo_aimlock[client]);

    // LOG
    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s Suspected Aimlock (Detection: %d).", line_buffer, playerinfo_aimlock[client]);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(client);
    }
    database_log(client, "aimlock", playerinfo_aimlock[client]);

    // BANEO
    if (playerinfo_aimlock[client] >= icvar[CVAR_AIMLOCK] && icvar[CVAR_AIMLOCK] >= AIMLOCK_BAN_MIN) {
        playerinfo_banned_flags[client][CHEAT_AIMLOCK] = true;
        
        if (icvar[CVAR_LOG]) {
            lilac_log_setup_client(client);
            Format(line_buffer, sizeof(line_buffer), "%s Banned for Aimlock.", line_buffer);
            lilac_log(true);
        }
        database_log(client, "aimlock", DATABASE_BAN);
        
        lilac_ban_client(client, CHEAT_AIMLOCK);
    }
}

/* --- LÓGICA DE COLA DE PROCESAMIENTO (LIGHT MODE) --- */
void lilac_aimlock_light_test(int client)
{
    // Si el jugador hace movimientos bruscos, lo añadimos a la cola de "Aimlock Test"
    // Esto ahorra CPU al no analizar jugadores que mueven la mira suavemente.
    
    if (GetGameTime() - playerinfo_time_teleported[client] < 3.0) return;

    int ind = playerinfo_index[client];
    float lastang[3], ang[3];
    
    // Check rápido de 0.5s
    for (int i = 0; i < time_to_ticks(0.5); i++) {
        if (ind < 0) ind += CMD_LENGTH;
        get_player_log_angles(client, ind, false, ang);

        if (i > 0) {
            // Si mueve la mira más de 20 grados en 1 tick, es sospechoso, a la cola.
            if (angle_delta(lastang, ang) > 20.0) {
                playerinfo_time_process_aimlock[client] = GetGameTime() + 200.0; // Analizar por 200s
                return;
            }
        }
        lastang = ang;
        ind--;
    }
}

static bool lilac_is_player_in_aimlock_que(int client)
{
    /* Devuelve true si el jugador merece ser analizado por Aimlock */
    return (GetGameTime() < playerinfo_time_process_aimlock[client] // Está en la cola
        || playerinfo_aimlock[client] > 0 // Ya ha sido detectado antes
        || lilac_aimbot_get_client_detections(client) > 1 // Sospechoso de Aimbot
        || GetClientTime(client) < 240.0 // Acaba de entrar (siempre analizar nuevos)
        || (GetGameTime() - playerinfo_time_aimlock[client] < 180.0 && playerinfo_time_aimlock[client] > 1.0));
}

public Action timer_decrement_aimlock(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (is_player_valid(client) && playerinfo_aimlock[client] > 0)
        playerinfo_aimlock[client]--;
    return Plugin_Continue;
}