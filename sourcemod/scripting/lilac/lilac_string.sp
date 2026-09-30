/* lilac/lilac_string.sp */

#if defined _lilac_string_included
 #endinput
#endif
#define _lilac_string_included

/* String Validation Module (Updated for SM 1.12) */

/* -------------------------------------------------------------------------- */
/* CHAT HOOKS                                  */
/* -------------------------------------------------------------------------- */

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    int flags;

    if (!icvar[CVAR_ENABLE])
        return Plugin_Continue;

    /* Si el jugador está baneado por Chat-Clear, no dejarle hablar para que no spamee */
    if (playerinfo_banned_flags[client][CHEAT_CHATCLEAR])
        return Plugin_Stop;

    if (!icvar[CVAR_FILTER_CHAT])
        return Plugin_Continue;

    /* Validar la cadena de texto */
    /* STRFLAG_NEWLINE se maneja aparte porque el Post-Hook lo necesita para detectar el exploit */
    bool valid = is_string_valid(sArgs, flags);

    if (!valid && !(flags & STRFLAG_NEWLINE)) 
    {
        PrintToChat(client, "[Lilac] Invalid characters detected in your message.");
        return Plugin_Stop;
    }
    else if (flags & STRFLAG_WIDE_CHAR_SPAM) 
    {
        /* Exploit de caracteres anchos (Wide Char) que lagean el chat */
        PrintToChat(client, "[Lilac] Anti-Spam: Wide characters are not allowed.");
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    // CS:GO maneja el chat diferente, el chat-clear no funciona igual ahí.
    // Para L4D2/TF2/CSS sí es necesario.
    if (ggame == GAME_CSGO) return;

    if (!icvar[CVAR_ENABLE] || !icvar[CVAR_CHAT])
        return;

    if (playerinfo_banned_flags[client][CHEAT_CHATCLEAR])
        return;

    /* Detectar Chat-Clear (Spam de líneas vacías) */
    if (does_string_contain_newline(sArgs)) 
    {
        if (!lilac_forward_allow_cheat_detection(client, CHEAT_CHATCLEAR))
            return;

        playerinfo_banned_flags[client][CHEAT_CHATCLEAR] = true;
        lilac_forward_client_cheat(client, CHEAT_CHATCLEAR);

        if (icvar[CVAR_LOG]) {
            lilac_log_setup_client(client);
            Format(line_buffer, sizeof(line_buffer), "%s detected/banned for Chat-Clear.", line_buffer);
            lilac_log(true);
            if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
        }
        
        database_log(client, "chat_clear", DATABASE_BAN);
        lilac_ban_client(client, CHEAT_CHATCLEAR);
    }
}

static bool does_string_contain_newline(const char[] string)
{
    for (int i = 0; string[i]; i++) {
        if (string[i] == '\n' || string[i] == '\r')
            return true;
    }
    return false;
}

/* -------------------------------------------------------------------------- */
/* NAME VALIDATION                             */
/* -------------------------------------------------------------------------- */

public Action event_namechange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (skip_name_check(client)) return Plugin_Continue;

    char client_name[MAX_NAME_LENGTH];
    event.GetString("newname", client_name, sizeof(client_name));
    
    check_name(client, client_name);
    return Plugin_Continue;
}

void lilac_string_check_name(int client)
{
    if (skip_name_check(client)) return;

    char name[MAX_NAME_LENGTH];
    if (GetClientName(client, name, sizeof(name)))
        check_name(client, name);
}

static bool skip_name_check(int client)
{
    if (!icvar[CVAR_ENABLE] || !icvar[CVAR_FILTER_NAME] || !is_player_valid(client) || IsFakeClient(client))
        return true;
    return false;
}

static void check_name(int client, const char[] name)
{
    int flags;
    if (is_string_valid(name, flags)) return;

    // Detectar Newlines en el nombre (Exploit de scoreboard)
    if (icvar[CVAR_FILTER_NAME] == 2 && (flags & STRFLAG_NEWLINE)) 
    {
        if (playerinfo_banned_flags[client][CHEAT_NEWLINE_NAME]) return;
        if (!lilac_forward_allow_cheat_detection(client, CHEAT_NEWLINE_NAME)) return;

        playerinfo_banned_flags[client][CHEAT_NEWLINE_NAME] = true;
        lilac_forward_client_cheat(client, CHEAT_NEWLINE_NAME);

        if (icvar[CVAR_LOG]) {
            lilac_log_setup_client(client);
            Format(line_buffer, sizeof(line_buffer), "%s banned for newline characters in name (%s).", line_buffer, name);
            lilac_log(true);
            if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
        }
        database_log(client, "name_newline", DATABASE_BAN);
        lilac_ban_client(client, CHEAT_NEWLINE_NAME);
    }
    else 
    {
        /* Nombre inválido genérico (Kick) */
        if (icvar[CVAR_LOG_MISC]) {
            lilac_log_setup_client(client);
            Format(line_buffer, sizeof(line_buffer), "%s kicked for invalid name characters (%s).", line_buffer, name);
            lilac_log(true);
            if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
        }
        database_log(client, "name_invalid", DATABASE_KICK);

        if (icvar[CVAR_FILTER_NAME] > 0)
            KickClient(client, "[Lilac] Please change your name (Invalid characters).");
    }
}

/* -------------------------------------------------------------------------- */
/* UTF-8 PARSING ENGINE                        */
/* -------------------------------------------------------------------------- */

static bool is_string_valid(const char[] string, int &flags)
{
    int widechars = 0;
    int i = 0;
    flags = 0;

    while (string[i]) 
    {
        int codepoint = 0;
        int len = utf8_decode(string[i], codepoint);

        if (len == 0) return false; // Codificación rota

        switch (codepoint) {
            case '\n', '\r': {
                flags = STRFLAG_NEWLINE;
                return false;
            }
            case 0xfdfd: { // Bismillah symbol exploit
                if (++widechars > 3)
                    flags |= STRFLAG_WIDE_CHAR_SPAM;
            }
        }

        // Filtros de rango Unicode
        if (codepoint >= 0xd800 && codepoint <= 0xdfff) return false; // Surrogates
        else if (codepoint > 0x10ffff) return false; // Max Unicode
        else if (codepoint < 0x20 && codepoint != '\t') return false; // Control Chars
        else if (codepoint == 0x7f) return false; // DEL
        else if (codepoint >= 0x80 && codepoint <= 0x9f) return false; // C1 Control
        
        // Private Use Areas (Iconos personalizados que a veces crashean)
        else if (codepoint >= 0xe000 && codepoint <= 0xf8ff) return false;
        else if (codepoint >= 0xf0000 && codepoint <= 0xfffff) return false;
        else if (codepoint >= 0x100000 && codepoint <= 0x10fffd) return false;

        i += len;
    }
    return true;
}

static int utf8_decode(const char[] ptr, int &codepoint)
{
    // Manejo manual de UTF-8 bitwise
    int c = ptr[0] & 0xFF; // Cast a unsigned para seguridad
    int len = utf8_header_length(c);

    if (len == 0) return 0;
    if (len == 1) {
        codepoint = c;
        return 1;
    }

    static int mask[] = {0, 0, 0x1f, 0x0f, 0x07};
    codepoint = c & mask[len];

    for (int i = 1; i < len; i++) {
        int next_c = ptr[i] & 0xFF;
        if ((next_c & 0xc0) != 0x80) return 0;
        codepoint = (codepoint << 6) | (next_c & 0x3f);
    }

    if (len != codepoint_to_utf8_length(codepoint)) return 0; // Overlong encoding check

    return len;
}

static int utf8_header_length(int c)
{
    if (c >= 0xf5) return 0;
    if (c == 0xc0 || c == 0xc1) return 0;

    int v = c & 0xf0;
    if (v == 0xc0 || v == 0xd0) return 2;
    if (v == 0xe0) return 3;
    if (v == 0xf0) return 4;
    return ((c & 0x80) == 0) ? 1 : 0; // 1 byte (ASCII)
}

static int codepoint_to_utf8_length(int codepoint)
{
    if (codepoint < 0x80) return 1;
    if (codepoint < 0x800) return 2;
    if (codepoint < 0x10000) return 3;
    if (codepoint < 0x110000) return 4;
    return 0;
}