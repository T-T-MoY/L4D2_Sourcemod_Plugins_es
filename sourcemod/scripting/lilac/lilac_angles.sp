/* lilac/lilac_angles.sp */

#if defined _lilac_angles_included
 #endinput
#endif
#define _lilac_angles_included

/* Angles Detection Module (Updated for SM 1.12 + L4D2 Safe Mode) */

void lilac_angles_check(int client, float angles[3])
{
    // Validaciones básicas de entidad
    if (!IsPlayerAlive(client) || playerinfo_time_teleported[client] + 5.0 > GetGameTime())
        return;

    /* --- LÓGICA L4D2 (SAFE MODE) --- */
    if (ggame == GAME_L4D2)
    {
        // 1. Solo escanear Supervivientes
        if (GetClientTeam(client) != 2) return;

        // 2. Si está Incapacitado o Atrapado, ignorar ángulos (la cámara se rompe)
        if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) return;

        // Verificar si está siendo "Dominado"
        if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) return;
        if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) return;
        if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) return;
        if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) return; // Charger
        
        // 3. SOLO chequear PITCH (X).
        if (FloatAbs(angles[0]) > 90.0) 
        {
             lilac_detected_angles(client, angles);
        }
        return;
    }

    /* --- LÓGICA ESTÁNDAR (CSGO, CSS) --- */
    // Solo ejecutamos esto si NO es L4D2 ni TF2
    if (ggame != GAME_TF2) 
    {
        if ((FloatAbs(angles[0]) > max_angles[0] && max_angles[0] != 0.0)
            || (FloatAbs(angles[2]) > max_angles[2] && max_angles[2] != 0.0))
        {
            lilac_detected_angles(client, angles);
        }
    }
}

void lilac_angles_patch(float angles[3])
{
    /* Patch Pitch (Arriba/Abajo) */
    if (max_angles[0] != 0.0) {
        if (angles[0] > max_angles[0])
            angles[0] = max_angles[0];
        else if (angles[0] < (max_angles[0] * -1.0))
            angles[0] = (max_angles[0] * -1.0);
    }

    /* Patch Roll (Inclinación) */
    if (ggame != GAME_L4D2)
    {
        angles[2] = 0.0;
    }
}

static void lilac_detected_angles(int client, float ang[3])
{
    if (playerinfo_banned_flags[client][CHEAT_ANGLES]) return;
    if (playerinfo_time_forward[client][CHEAT_ANGLES] > GetGameTime()) return;

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_ANGLES)) {
        playerinfo_time_forward[client][CHEAT_ANGLES] = GetGameTime() + 20.0;
        return;
    }

    playerinfo_banned_flags[client][CHEAT_ANGLES] = true;
    lilac_forward_client_cheat(client, CHEAT_ANGLES);

    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s detected for Angle-Cheats (Pitch: %.2f, Yaw: %.2f).", line_buffer, ang[0], ang[1]);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }

    database_log(client, "angles", DATABASE_BAN);
    lilac_ban_client(client, CHEAT_ANGLES);
}