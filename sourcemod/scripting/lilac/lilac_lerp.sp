/* lilac/lilac_lerp.sp */

#if defined _lilac_lerp_included
 #endinput
#endif
#define _lilac_lerp_included

/* Lerp Detection Module (Updated for SM 1.12) */

static float min_lerp_possible = 0.0;
static bool ignore_nolerp[MAXPLAYERS + 1];
static bool ignore_nolerp_all = false;

void lilac_lerp_reset_client(int client)
{
    ignore_nolerp[client] = false;
}

void lilac_lerp_ignore_nolerp_client(int client)
{
    ignore_nolerp[client] = true;
}

void lilac_lerp_ratio_changed(int value)
{
    /* Si el servidor permite ratio < 1 (o -1 en L4D2 competitivo),
       desactivamos la detección de NoLerp porque es legal tener 0. */
    if (value < 1)
        ignore_nolerp_all = true;
    else
        ignore_nolerp_all = false;
}

void lilac_lerp_maxupdaterate_changed(int value)
{
    // Calcular el lerp mínimo matemáticamente posible para este server
    if (value > 0)
        min_lerp_possible = 1.0 / float(value);
    else
        min_lerp_possible = 0.0;
}

public Action timer_check_lerp(Handle timer)
{
    if (!icvar[CVAR_ENABLE])
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!is_player_valid(i) || IsFakeClient(i))
            continue;

        // Obtener el Lerp actual del cliente
        float lerp = GetEntPropFloat(i, Prop_Data, "m_fLerpTime");
        float lerp_ms = lerp * 1000.0;

        /* --- DETECCION 1: HIGH LERP EXPLOIT --- */
        // Si el lerp es mayor al permitido (default 105ms).
        // En L4D2, esto evita el exploit de "hitbox desync".
        if (lerp_ms > float(icvar[CVAR_MAX_LERP]) && icvar[CVAR_MAX_LERP] >= 105) 
        {
            detected_lerp_exploit(i, lerp);
            continue;
        }

        /* --- DETECCION 2: NOLERP (HACK) --- */
        if (!icvar[CVAR_NOLERP]
            || ignore_nolerp_all
            || ignore_nolerp[i]
            || playerinfo_banned_flags[i][CHEAT_NOLERP]
            || min_lerp_possible < 0.005) // Si el server está mal configurado, ignorar
        {
            continue;
        }

        // Buffer de seguridad del 95% para evitar falsos positivos por redondeo
        if (lerp > (min_lerp_possible * 0.95))
            continue;

        // Si su lerp es MENOR que lo matemáticamente posible según el updaterate, es hack
        detected_nolerp(i, lerp);
    }

    return Plugin_Continue;
}

static void detected_lerp_exploit(int client, float lerp)
{
    // Esto suele ser KICK, no BAN, porque puede ser mala configuración del usuario
    if (icvar[CVAR_LOG_MISC]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), 
            "%s Kicked for Interpolation Exploit (%.1fms / Max allowed: %dms).", 
            line_buffer, lerp * 1000.0, icvar[CVAR_MAX_LERP]);
        
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA] == 2) lilac_log_extra(client);
    }
    
    database_log(client, "lerp_exploit", DATABASE_KICK, lerp * 1000.0, float(icvar[CVAR_MAX_LERP]));
    
    KickClient(client, "[Lilac] Fix your cl_interp (Max allowed: %d ms)", icvar[CVAR_MAX_LERP]);
}

static void detected_nolerp(int client, float lerp)
{
    if (!lilac_forward_allow_cheat_detection(client, CHEAT_NOLERP))
        return;

    playerinfo_banned_flags[client][CHEAT_NOLERP] = true;
    lilac_forward_client_cheat(client, CHEAT_NOLERP);

    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s detected/banned for NoLerp (%.3f ms).", line_buffer, lerp * 1000.0);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }
    
    database_log(client, "nolerp", DATABASE_BAN, lerp * 1000.0);
    lilac_ban_client(client, CHEAT_NOLERP);
}