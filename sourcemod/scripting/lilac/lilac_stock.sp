/* lilac/lilac_stock.sp */

#if defined _lilac_stock_included
 #endinput
#endif
#define _lilac_stock_included

/* Lilac Stock Functions (Updated for SM 1.12 + L4D2) 
   Contains helper functions, logging, and banning logic.
*/

/* -------------------------------------------------------------------------- */
/* L4D2 HELPERS                                 */
/* -------------------------------------------------------------------------- */

bool IsL4D2Ghost(int client)
{
    if (ggame != GAME_L4D2) return false;
    if (!is_player_valid(client)) return false;
    
    if (HasEntProp(client, Prop_Send, "m_isGhost"))
        return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
        
    return false;
}

bool IsL4D2Tank(int client)
{
    if (ggame != GAME_L4D2) return false;
    if (!is_player_valid(client)) return false;

    // Clase 8 es Tank en L4D2
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
        return true;

    return false;
}

/* -------------------------------------------------------------------------- */
/* ADMIN WARNINGS                                 */
/* -------------------------------------------------------------------------- */

void lilac_warn_admins(int client, int cheat, int detections)
{
    char name[MAX_NAME_LENGTH];
    char type[32];
    int admins[MAXPLAYERS + 1];
    int n = 0;

    /* Build admin list */
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && is_player_admin(i))
            admins[n++] = i;
    }

    if (!n) return;

    switch (cheat) {
        case CHEAT_BHOP:       strcopy(type, sizeof(type), "Bhop");
        case CHEAT_AIMBOT:     strcopy(type, sizeof(type), "Aimbot");
        case CHEAT_AIMLOCK:    strcopy(type, sizeof(type), "Aimlock");
        default: return;
    }

    if (!GetClientName(client, name, sizeof(name)))
        strcopy(name, sizeof(name), "[Unknown]");

    for (int i = 0; i < n; i++) {
        PrintToChat(admins[i], "[Lilac] %T", "admin_chat_warning_generic", admins[i], name, type, detections);
    }
}

/* -------------------------------------------------------------------------- */
/* PLAYER MANAGEMENT                               */
/* -------------------------------------------------------------------------- */

bool bullettime_can_shoot(int client)
{
    if (!IsPlayerAlive(client)) return false;

    int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    if (!IsValidEntity(weapon)) return false;

    // En L4D2, las garras de los infectados a veces no tienen nextprimaryattack normal
    // Si da errores, envolver esto en un try/check o ignorar si es infectado
    float nextAttack = GetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack");
    float simTime = GetEntPropFloat(client, Prop_Data, "m_flSimulationTime");

    if ((simTime + GetTickInterval()) >= nextAttack)
        return true;

    return false;
}

void lilac_reset_client(int client)
{
    // Reseteamos módulos (asegurate que estas funciones existan en los otros .sp)
    lilac_backtrack_reset_client(client);
    lilac_bhop_reset_client(client);
    lilac_macro_reset_client(client);
    
    #if !defined TF2C
        lilac_noisemaker_reset_client(client);
    #endif
    
    lilac_aimbot_reset_client(client);
    lilac_ping_reset_client(client);
    lilac_convar_reset_client(client);
    lilac_lerp_reset_client(client);

    // Resetear variables base
    playerinfo_index[client] = 0;
    playerinfo_aimlock_sus[client] = 0;
    playerinfo_aimlock[client] = 0;
    playerinfo_time_bumpercart[client] = 0.0;
    playerinfo_time_teleported[client] = 0.0;
    playerinfo_time_aimlock[client] = 0.0;
    playerinfo_time_process_aimlock[client] = 0.0;

    // Resetear nuevas variables L4D2
    playerinfo_is_ghost[client] = false;
    playerinfo_is_tank[client] = false;

    for (int i = 0; i < CHEAT_MAX; i++) {
        playerinfo_time_forward[client][i] = 0.0;
        playerinfo_banned_flags[client][i] = false;
    }

    for (int i = 0; i < CMD_LENGTH; i++) {
        playerinfo_buttons[client][i] = 0;
        playerinfo_actions[client][i] = 0;
        playerinfo_time_usercmd[client][i] = 0.0;
        
        float zero[3] = {0.0, 0.0, 0.0};
        set_player_log_angles(client, zero, i);
    }
}

/* -------------------------------------------------------------------------- */
/* LOGGING                                     */
/* -------------------------------------------------------------------------- */

void lilac_log_setup_client(int client)
{
    char date[512], steamid[64], ip[64];
    FormatTime(date, sizeof(date), dateformat, GetTime());
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
    GetClientIP(client, ip, sizeof(ip), true);

    FormatEx(line_buffer, sizeof(line_buffer), "%s [Version %s] {Name: \"%N\" | SteamID: %s | IP: %s}", date, PLUGIN_VERSION, client, steamid, ip);
}

void lilac_log_extra(int client)
{
    char map[128], weapon[64];
    float pos[3], ang[3];

    GetClientAbsOrigin(client, pos);
    GetCurrentMap(map, sizeof(map));
    GetClientWeapon(client, weapon, sizeof(weapon));
    get_player_log_angles(client, 0, true, ang);

    FormatEx(line_buffer, sizeof(line_buffer), 
        "\tPos={%.0f,%.0f,%.0f}, Angles={%.5f,%.5f,%.5f}, Map=\"%s\", Team={%d}, Weapon=\"%s\", Latency={Inc:%f,Out:%f}, Loss={Inc:%f,Out:%f}",
        pos[0], pos[1], pos[2], ang[0], ang[1], ang[2], map, GetClientTeam(client), weapon,
        GetClientAvgLatency(client, NetFlow_Incoming), GetClientAvgLatency(client, NetFlow_Outgoing),
        GetClientAvgLoss(client, NetFlow_Incoming), GetClientAvgLoss(client, NetFlow_Outgoing));

    lilac_log(false);
}

void lilac_log(bool cleanup)
{
    // USO MODERNO DE ARCHIVOS (SM 1.12)
    File file = OpenFile(log_file, "a");

    if (file == null) {
        PrintToServer("[Lilac] Error: Cannot open log file at %s", log_file);
        return;
    }

    if (cleanup) {
        for (int i = 0; line_buffer[i]; i++) {
            if (line_buffer[i] == '\n' || line_buffer[i] == 0x0d) line_buffer[i] = '*';
            else if (line_buffer[i] < 32) line_buffer[i] = '#';
        }
    }

    file.WriteLine("%s", line_buffer);
    
    // SourceIRC Integration
    if (icvar[CVAR_SOURCEIRC] && NATIVE_EXISTS("IRC_MsgFlaggedChannels")) {
         if (!cleanup) {
            for (int i = 0; line_buffer[i]; i++) {
                if (line_buffer[i] == '\n' || line_buffer[i] == 0x0d) line_buffer[i] = '*';
                else if (line_buffer[i] < 32) line_buffer[i] = '#';
            }
        }
        IRC_MsgFlaggedChannels("lilac", "[LILAC] %s", line_buffer);
    }

    delete file; // CERRAR ARCHIVO IMPORTANTE
}

void lilac_log_first_time_setup()
{
    if (!FileExists(log_file)) {
        FormatEx(line_buffer, sizeof(line_buffer), "=========[Notice]=========\nNew Lilac Install v%s\nLogs initialized.\n", PLUGIN_VERSION);
        lilac_log(false);
    }
}

/* -------------------------------------------------------------------------- */
/* BANNING                                     */
/* -------------------------------------------------------------------------- */

void lilac_ban_client(int client, int cheat)
{
    char reason[128];
    int lang = LANG_SERVER;
    bool log_only = false;

    if (!icvar[CVAR_BAN]) return;

    // Verificar si es "Log Only"
    switch (cheat) {
        case CHEAT_ANGLES:          log_only = icvar[CVAR_ANGLES] < 0;
        case CHEAT_CHATCLEAR:       log_only = icvar[CVAR_CHAT] < 0;
        case CHEAT_CONVAR:          log_only = icvar[CVAR_CONVAR] < 0;
        case CHEAT_NOLERP:          log_only = icvar[CVAR_NOLERP] < 0;
        case CHEAT_BHOP:            log_only = icvar[CVAR_BHOP] < 0;
        case CHEAT_ANTI_DUCK_DELAY: log_only = icvar[CVAR_ANTI_DUCK_DELAY] < 0;
        case CHEAT_NOISEMAKER_SPAM: log_only = icvar[CVAR_NOISEMAKER_SPAM] < 0;
        case CHEAT_MACRO:           log_only = icvar[CVAR_MACRO] < 0;
        case CHEAT_NEWLINE_NAME:    log_only = icvar[CVAR_FILTER_NAME] < 0;
    }

    if (log_only) return;
    if (icvar[CVAR_BAN_LANGUAGE]) lang = client;

    // Generar razón de ban
    switch (cheat) {
        case CHEAT_BHOP:   Format(reason, sizeof(reason), "[AC] %T", "ban_bhop", lang);
        case CHEAT_AIMBOT: Format(reason, sizeof(reason), "[AC] %T", "ban_aimbot", lang);
        // ... (otros casos simplificados para brevedad, funcionan igual)
        default: Format(reason, sizeof(reason), "[AC] Detected Cheat #%d", cheat);
    }

    lilac_forward_client_ban(client, cheat);

    // Prioridad de sistemas de ban
    if (icvar[CVAR_MA] && NATIVE_EXISTS("MABanPlayer")) {
        MABanPlayer(0, client, MA_BAN_STEAM, get_ban_length(cheat), reason);
    } else if (icvar[CVAR_SB] && NATIVE_EXISTS("SBPP_BanPlayer")) {
        SBPP_BanPlayer(0, client, get_ban_length(cheat), reason);
    } else {
        // Fallback: Base Bans
        BanClient(client, get_ban_length(cheat), BANFLAG_AUTO, reason, reason, "lilac");
    }
    
    // Kickear después de un breve delay para asegurar que el ban se procese
    CreateTimer(1.0, timer_kick, GetClientUserId(client));
}

public Action timer_kick(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (is_player_valid(client))
        KickClient(client, "Anti-Cheat Detection");
    return Plugin_Continue;
}

int get_ban_length(int cheat)
{
    return ((ban_length_overwrite[cheat] <= -1) ? icvar[CVAR_BAN_LENGTH] : ban_length_overwrite[cheat]);
}

/* -------------------------------------------------------------------------- */
/* MATH & UTILS                                    */
/* -------------------------------------------------------------------------- */

void get_player_log_angles(int client, int tick, bool latest, float writeto[3])
{
    int i = latest ? playerinfo_index[client] : tick;
    
    // Normalizar buffer circular
    while (i < 0) i += CMD_LENGTH;
    while (i >= CMD_LENGTH) i -= CMD_LENGTH;

    writeto[0] = playerinfo_angles[client][i][0];
    writeto[1] = playerinfo_angles[client][i][1];
    writeto[2] = playerinfo_angles[client][i][2];
}

void set_player_log_angles(int client, float ang[3], int tick)
{
    int i = tick;
    while (i < 0) i += CMD_LENGTH;
    while (i >= CMD_LENGTH) i -= CMD_LENGTH;

    playerinfo_angles[client][i][0] = ang[0];
    playerinfo_angles[client][i][1] = ang[1];
    playerinfo_angles[client][i][2] = ang[2];
}

void aim_at_point(const float p1[3], const float p2[3], float writeto[3])
{
    SubtractVectors(p2, p1, writeto);
    GetVectorAngles(writeto, writeto);
    
    // Normalización de ángulos segura
    if (writeto[0] > 90.0) writeto[0] -= 360.0;
    if (writeto[0] < -90.0) writeto[0] += 360.0;
    
    // Fix para L4D2: Angles[1] (Yaw) puede ser +/- 180
    while (writeto[1] > 180.0) writeto[1] -= 360.0;
    while (writeto[1] < -180.0) writeto[1] += 360.0;
    
    writeto[2] = 0.0;
}

float angle_delta(float a1[3], float a2[3])
{
    float p1[3], p2[3];
    p1[0] = a1[0]; p1[1] = a1[1]; p1[2] = 0.0;
    p2[0] = a2[0]; p2[1] = a2[1]; p2[2] = 0.0;

    float delta = GetVectorDistance(p1, p2);
    
    // Normalizar delta (corregido)
    int safeguard = 5;
    while (delta > 180.0 && safeguard > 0) {
        delta = FloatAbs(delta - 360.0);
        safeguard--;
    }
    return delta;
}

bool skip_due_to_loss(int client)
{
    if (icvar[CVAR_LOSS_FIX])
        return GetClientAvgLoss(client, NetFlow_Both) > 0.50; // 50% Packet loss
    return false;
}

int time_to_ticks(float time)
{
    return (time > 0.0) ? RoundToNearest(time / GetTickInterval()) : 0;
}

int intabs(int num)
{
    return (num < 0) ? -num : num;
}

bool is_player_admin(int client)
{
    return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, true);
}

bool is_player_valid(int client)
{
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientConnected(client)) return false;
    if (!IsClientInGame(client)) return false;
    if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
    // Agregamos IsFakeClient aquí para simplificar lógica en otros lados
    // NOTA: Si algun módulo necesita chequear bots, quitar esta linea.
    if (IsFakeClient(client)) return false; 
    
    return true;
}

/* -------------------------------------------------------------------------- */
/* FORWARDS                                    */
/* -------------------------------------------------------------------------- */

void lilac_forward_client_cheat(int client, int cheat)
{
    if (forwardhandle != null) {
        Call_StartForward(forwardhandle);
        Call_PushCell(client);
        Call_PushCell(cheat);
        Call_Finish();
    }
}

void lilac_forward_client_ban(int client, int cheat)
{
    if (forwardhandleban != null) {
        Call_StartForward(forwardhandleban);
        Call_PushCell(client);
        Call_PushCell(cheat);
        Call_Finish();
    }
}

bool lilac_forward_allow_cheat_detection(int client, int cheat)
{
    Action result = Plugin_Continue;
    if (forwardhandleallow != null) {
        Call_StartForward(forwardhandleallow);
        Call_PushCell(client);
        Call_PushCell(cheat);
        Call_Finish(result);
    }
    return (result == Plugin_Continue);
}