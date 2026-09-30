/* lilac/lilac_aimbot.sp */

#if defined _lilac_aimbot_included
 #endinput
#endif
#define _lilac_aimbot_included

/* Aimbot Detection Module (Updated for SM 1.12 + L4D2 Safety) */

static int aimbot_detection[MAXPLAYERS + 1];
static int aimbot_autoshoot[MAXPLAYERS + 1];
static int aimbot_timertick[MAXPLAYERS + 1];

void lilac_aimbot_reset_client(int client)
{
    aimbot_detection[client] = 0;
    aimbot_autoshoot[client] = 0;
    aimbot_timertick[client] = 0;
}

int lilac_aimbot_get_client_detections(int client)
{
    return aimbot_detection[client];
}

/* --- EVENTO DE MUERTE (Genérico + L4D2) --- */
public Action event_player_death(Event event, const char[] name, bool dontBroadcast)
{
    if (!icvar[CVAR_ENABLE]) return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));

    // Validaciones básicas
    if (!is_player_valid(attacker) || !is_player_valid(victim))
        return Plugin_Continue;

    // LÓGICA ESPECÍFICA DE L4D2
    if (ggame == GAME_L4D2)
    {
        // 1. Solo analizar Supervivientes (Team 2). 
        // Los infectados (Team 3) tienen mecánicas de giro brusco (Hunter/Jockey) que parecen aimbot.
        if (GetClientTeam(attacker) != 2) return Plugin_Continue;

        // 2. Filtrar armas no balísticas
        char weapon[32];
        event.GetString("weapon", weapon, sizeof(weapon));
        
        // Si mata con melee, motosierra, fuego o explosivos, ignorar.
        if (StrContains(weapon, "melee") != -1 || 
            StrContains(weapon, "chainsaw") != -1 || 
            StrContains(weapon, "pipe") != -1 || 
            StrContains(weapon, "molotov") != -1 ||
            StrEqual(weapon, "inferno") ||
            StrEqual(weapon, "entityflame"))
        {
            return Plugin_Continue;
        }
    }

    // Evitar chequear dos veces en el mismo tick (ej: escopeta disparando múltiples perdigones)
    if (aimbot_timertick[victim] == GetGameTickCount())
        return Plugin_Continue;

    // Pasar a la lógica compartida
    event_death_shared(GetClientUserId(attacker), attacker, victim, false);

    return Plugin_Continue;
}

/* --- EVENTO DE MUERTE (TF2 Específico) --- */
public Action event_player_death_tf2(Event event, const char[] name, bool dontBroadcast)
{
    if (!icvar[CVAR_ENABLE]) return Plugin_Continue;

    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!is_player_valid(victim)) return Plugin_Continue;

    if (aimbot_timertick[victim] == GetGameTickCount()) return Plugin_Continue;

    char wep[64];
    event.GetString("weapon_logclassname", wep, sizeof(wep));

    // Ignorar sentries y muertes por mundo
    if (strncmp(wep, "obj_", 4, false) == 0 || strncmp(wep, "world", 5, false) == 0)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int killtype = event.GetInt("customkill");

    // killtype 3 es lanzallamas, ignorar snaps (los pyros giran mucho)
    event_death_shared(GetClientUserId(attacker), attacker, victim, (killtype == 3));

    return Plugin_Continue;
}

/* --- LÓGICA COMPARTIDA DE ANÁLISIS --- */
void event_death_shared(int userid, int client, int victim, bool skip_delta)
{
    if (client == victim || IsFakeClient(client) || !IsPlayerAlive(client))
        return;

    // Si ya está detectado y baneado internamente, no seguir procesando
    if (playerinfo_banned_flags[client][CHEAT_AIMBOT]) return;

    // Un jugador recién conectado (<10s) puede tener lag spikes, ignorar.
    if (GetClientTime(client) < 10.1) return;

    if (icvar[CVAR_AIMLOCK_LIGHT])
        lilac_aimlock_light_test(client);

    if (!icvar[CVAR_AIMBOT]) return;

    aimbot_timertick[client] = GetGameTickCount();

    float killpos[3], deathpos[3];
    GetClientEyePosition(client, killpos);
    GetClientEyePosition(victim, deathpos);

    // Preparar DataPack para el Timer de análisis diferido
    bool skip_snap = false;
    
    // Si están muy cerca (< 350 unidades), los ángulos cambian muy rápido legítimamente. Ignorar snaps.
    if (GetVectorDistance(killpos, deathpos) < 350.0 || skip_delta)
        skip_snap = true;

    DataPack pack;
    CreateDataTimer(0.5, timer_check_aimbot, pack); // Analizamos 0.5s después para asegurar tener historial
    pack.WriteCell(userid);
    pack.WriteCell(skip_snap);
    pack.WriteCell(playerinfo_index[client]); // Guardamos el índice actual como fallback
    pack.WriteFloat(killpos[0]);
    pack.WriteFloat(killpos[1]);
    pack.WriteFloat(killpos[2]);
    pack.WriteFloat(deathpos[0]);
    pack.WriteFloat(deathpos[1]);
    pack.WriteFloat(deathpos[2]);
}

/* --- TIMER DE ANÁLISIS MATEMÁTICO --- */
public Action timer_check_aimbot(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    bool skip_snap = pack.ReadCell();
    int fallback = pack.ReadCell();
    
    float killpos[3], deathpos[3];
    killpos[0] = pack.ReadFloat(); killpos[1] = pack.ReadFloat(); killpos[2] = pack.ReadFloat();
    deathpos[0] = pack.ReadFloat(); deathpos[1] = pack.ReadFloat(); deathpos[2] = pack.ReadFloat();

    if (!is_player_valid(client)) return Plugin_Continue;

    /* --- FASE 1: BUSCAR EL DISPARO --- */
    int ind = playerinfo_index[client];
    int shotindex = -1;
    
    // Buscamos hacia atrás en el historial de comandos cuándo ocurrió el disparo
    // Buffer = 0.5 (timer) + 0.5 (max lag) + 0.1 (seguridad)
    int ticks_to_check = CMD_LENGTH - time_to_ticks(1.1); 

    for (int i = 0; i < ticks_to_check; i++) {
        if (--ind < 0) ind += CMD_LENGTH;

        // Si el comando es muy viejo (> 0.3s antes de que se llamara al timer original), ignorar
        if (GetGameTime() - playerinfo_time_usercmd[client][ind] < 0.3)
            continue;

        if ((playerinfo_actions[client][ind] & ACTION_SHOT)) {
            shotindex = ind;
            break;
        }
    }

    bool skip_autoshoot = false;
    bool skip_repeat = false;

    if (shotindex == -1) {
        // No encontramos el disparo exacto (posible lag o paquete perdido)
        shotindex = fallback;
        if (playerinfo_index[client] == fallback) {
            // No hemos recibido nuevos comandos desde la muerte, datos inestables.
            skip_autoshoot = true;
            skip_repeat = true;
        }
    } else {
        // Marcamos el disparo como analizado para no contarlo doble
        playerinfo_actions[client][shotindex] = 0;
    }

    if (skip_snap) skip_repeat = true;

    // Si el jugador hizo taunt/burla cerca del disparo, ignorar snaps (la cámara se mueve sola)
    if (playerinfo_time_usercmd[client][shotindex] - playerinfo_time_teleported[client] < 0.6)
        skip_snap = true;

    /* --- FASE 2: CÁLCULOS DE ÁNGULOS (SNAP) --- */
    int detected = 0;
    float delta = 0.0;
    float total_delta = 0.0;
    float ideal[3], ang[3], lang[3]; // lang = last angle

    if (!skip_snap) {
        aim_at_point(killpos, deathpos, ideal);
        ind = shotindex;
        
        // Analizar historial de 0.5 segundos ANTES del disparo
        for (int i = 0; i < time_to_ticks(0.5); i++) {
            if (ind < 0) ind += CMD_LENGTH;

            // Limite de tiempo
            if (playerinfo_time_usercmd[client][shotindex] - playerinfo_time_usercmd[client][ind] > 0.5)
                break;

            float aimdist = angle_delta(playerinfo_angles[client][ind], ideal);
            get_player_log_angles(client, ind, false, ang);

            if (i > 0) { // Necesitamos al menos 2 puntos para calcular velocidad (delta)
                float tdelta = angle_delta(lang, ang);
                if (tdelta > delta) delta = tdelta;
                total_delta += tdelta;

                // CRITERIO DE SNAP:
                // Si la mira se movió RAPIDISIMO (tdelta > 10) y terminó MUY CERCA del objetivo (aimdist pequeño)
                // Es sospechoso. Aimbot ajusta instantáneamente.
                
                // Snap fuerte
                if (aimdist < (angle_delta(lang, ideal) * 0.2) && tdelta > 10.0)
                    detected |= AIMBOT_FLAG_SNAP;

                // Snap suave
                if (aimdist < (angle_delta(lang, ideal) * 0.1) && tdelta > 5.0)
                    detected |= AIMBOT_FLAG_SNAP2;
            }

            lang = ang;
            ind--;
        }
    }

    /* --- FASE 3: VALIDACIONES FINALES --- */
    if (skip_due_to_loss(client)) {
        skip_autoshoot = true;
        skip_repeat = true;
        detected = 0; // Si hay packet loss, no baneamos por aimbot (falsos positivos)
    }

    // Angle Repeat: ¿La mira tiembla de forma robótica?
    if (!skip_repeat) {
        get_player_log_angles(client, shotindex - 1, false, ang);
        get_player_log_angles(client, shotindex + 1, false, lang);
        float tdelta = angle_delta(ang, lang);
        
        get_player_log_angles(client, shotindex, false, lang);
        
        // Matemáticas complejas simplificadas: Si el movimiento es errático pero preciso
        if (tdelta < 10.0 && angle_delta(ang, lang) > 0.5 && angle_delta(ang, lang) > tdelta * 5.0)
            detected |= AIMBOT_FLAG_REPEAT;
    }

    // Autoshoot: ¿Disparó EXACTAMENTE en el tick que la mira cruzó al enemigo?
    if (!skip_autoshoot && icvar[CVAR_AIMBOT_AUTOSHOOT]) {
        int attacks = 0;
        ind = shotindex + 1;
        // Revisar 3 ticks alrededor del disparo
        for (int i = 0; i < 3; i++) {
            if (ind < 0) ind += CMD_LENGTH;
            else if (ind >= CMD_LENGTH) ind -= CMD_LENGTH;
            
            if ((playerinfo_buttons[client][ind] & IN_ATTACK)) attacks++;
            ind--;
        }

        if (attacks == 1) { // Disparo de 1 solo tick (humano casi imposible consistentemente)
            if (detected || ++aimbot_autoshoot[client] > 1)
                detected |= AIMBOT_FLAG_AUTOSHOOT;
        } else {
            aimbot_autoshoot[client] = 0;
        }
    }

    /* --- REPORTE --- */
    if (detected || total_delta > AIMBOT_MAX_TOTAL_DELTA)
        lilac_detected_aimbot(client, delta, total_delta, detected);

    return Plugin_Continue;
}

static void lilac_detected_aimbot(int client, float delta, float td, int flags)
{
    // Si otro plugin dice que no banear, respetar.
    if (!lilac_forward_allow_cheat_detection(client, CHEAT_AIMBOT)) return;

    // Timer de enfriamiento (detecciones expiran en 10 min)
    CreateTimer(600.0, timer_decrement_aimbot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    lilac_forward_client_cheat(client, CHEAT_AIMBOT);

    // Necesitamos al menos 2 detecciones para loguear (evitar suerte)
    if (++aimbot_detection[client] < 2) return;

    // Aviso a admins
    if (icvar[CVAR_CHEAT_WARN])
        lilac_warn_admins(client, CHEAT_AIMBOT, aimbot_detection[client]);

    // Logging detallado
    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        
        char flagStr[128];
        if (flags & AIMBOT_FLAG_SNAP) StrCat(flagStr, sizeof(flagStr), " Snap");
        if (flags & AIMBOT_FLAG_SNAP2) StrCat(flagStr, sizeof(flagStr), " Snap2");
        if (flags & AIMBOT_FLAG_AUTOSHOOT) StrCat(flagStr, sizeof(flagStr), " Autoshoot");
        if (flags & AIMBOT_FLAG_REPEAT) StrCat(flagStr, sizeof(flagStr), " Jitter");
        
        Format(line_buffer, sizeof(line_buffer), 
            "%s Suspected Aimbot (Count: %d | Delta: %.0f | Flags:%s)", 
            line_buffer, aimbot_detection[client], delta, flagStr);
            
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(client);
    }

    // BANEO
    if (aimbot_detection[client] >= icvar[CVAR_AIMBOT] && icvar[CVAR_AIMBOT] >= AIMBOT_BAN_MIN) {
        playerinfo_banned_flags[client][CHEAT_AIMBOT] = true;
        lilac_ban_client(client, CHEAT_AIMBOT);
    }
}

public Action timer_decrement_aimbot(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (is_player_valid(client) && aimbot_detection[client] > 0)
        aimbot_detection[client]--;
    return Plugin_Continue;
}