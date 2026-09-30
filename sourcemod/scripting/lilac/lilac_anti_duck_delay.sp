/* lilac/lilac_anti_duck_delay.sp */

#if defined _lilac_anti_duck_delay_included
 #endinput
#endif
#define _lilac_anti_duck_delay_included

/* Anti-Duck Delay Detection 
   Updated for SM 1.12
   
   NOTA: Este exploit es exclusivo de CS:GO (Infinite Duck / Fast Duck).
   En L4D2/TF2/CSS esta mecánica de "fatiga por agacharse" no existe o funciona diferente,
   por lo que detectar esta flag es innecesario y peligroso.
*/

void lilac_anti_duck_delay_check(int client, int buttons)
{
    // SEGURIDAD: Solo ejecutar en CS:GO
    if (ggame != GAME_CSGO)
        return;

    // Chequeo de la flag mágica (1 << 22)
    if (!(buttons & IN_BULLRUSH))
        return;

    if (playerinfo_banned_flags[client][CHEAT_ANTI_DUCK_DELAY])
        return;

    /* Anti-Spam de la forward */
    if (playerinfo_time_forward[client][CHEAT_ANTI_DUCK_DELAY] > GetGameTime())
        return;

    // Permitir a otros plugins bloquear la detección
    if (!lilac_forward_allow_cheat_detection(client, CHEAT_ANTI_DUCK_DELAY)) {
        playerinfo_time_forward[client][CHEAT_ANTI_DUCK_DELAY] = GetGameTime() + 10.0;
        return;
    }

    playerinfo_banned_flags[client][CHEAT_ANTI_DUCK_DELAY] = true;
    lilac_forward_client_cheat(client, CHEAT_ANTI_DUCK_DELAY);

    // LOG
    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s detected/banned for Anti-Duck-Delay (Fast Duck Exploit).", line_buffer);

        lilac_log(true);

        if (icvar[CVAR_LOG_EXTRA])
            lilac_log_extra(client);
    }
    
    database_log(client, "anti_duck_delay", DATABASE_BAN);

    // BAN
    lilac_ban_client(client, CHEAT_ANTI_DUCK_DELAY);
}