/* lilac/lilac_config.sp */

#if defined _lilac_config_included
 #endinput
#endif
#define _lilac_config_included

/* Configuration Module (Updated for SM 1.12 Native ConVars) */

void lilac_config_setup()
{
    // Crear ConVars Nativas (Standard SourceMod)
    
    hcvar[CVAR_ENABLE] = CreateConVar("lilac_enable", "1", "Enable Little Anti-Cheat.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_WELCOME] = CreateConVar("lilac_welcome", "0", "Welcome connecting players saying that the server is protected.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_SB] = CreateConVar("lilac_sourcebans", "1", "Ban players via sourcebans++ (If it isn't installed, it will default to basebans).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_MA] = CreateConVar("lilac_materialadmin", "1", "Ban players via Material-Admin (Fork of Sourcebans++).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_SOURCEIRC] = CreateConVar("lilac_sourceirc", "1", "Enable reflecting log messages to SourceIRC channels flagged with 'lilac'.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_LOG] = CreateConVar("lilac_log", "1", "Enable cheat logging.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_LOG_EXTRA] = CreateConVar("lilac_log_extra", "1", "0 = Disabled.\n1 = Log extra info on ban.\n2 = Log extra info always.", FCVAR_PROTECTED, true, 0.0, true, 2.0);
    
    hcvar[CVAR_LOG_MISC] = CreateConVar("lilac_log_misc", "0", "Log misc kicks (ping, interp, convar failure).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_LOG_DATE] = CreateConVar("lilac_log_date", "{year}/{month}/{day} {hour}:{minute}:{second}", "Date format for logs.", FCVAR_PROTECTED);
    
    hcvar[CVAR_BAN] = CreateConVar("lilac_ban", "1", "Enable banning. Set to 0 to test detection without banning.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_BAN_LENGTH] = CreateConVar("lilac_ban_length", "0", "Ban length in minutes (0 = permanent).", FCVAR_PROTECTED, true, 0.0);
    
    hcvar[CVAR_BAN_LANGUAGE] = CreateConVar("lilac_ban_language", "1", "Ban reason language (0=Server, 1=Cheater).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_CHEAT_WARN] = CreateConVar("lilac_cheat_warning", "1", "Alert admins in chat about detections.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_ANGLES] = CreateConVar("lilac_angles", "1", "Detect Angle-Cheats (Spinbot).\n-1 = Log only.\n0 = Disabled.\n1 = Enabled.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_PATCH_ANGLES] = CreateConVar("lilac_angles_patch", "1", "Patch Angle-Cheats (Fix illegal angles).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_CHAT] = CreateConVar("lilac_chatclear", "1", "Detect Chat-Clear exploits.\n-1 = Log only.\n0 = Disabled.\n1 = Enabled.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_CONVAR] = CreateConVar("lilac_convar", "1", "Detect invalid ConVars.\n-1 = Log only.\n0 = Disabled.\n1 = Enabled.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_NOLERP] = CreateConVar("lilac_nolerp", "1", "Detect NoLerp.\n-1 = Log only.\n0 = Disabled.\n1 = Enabled.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_BHOP] = CreateConVar("lilac_bhop", "5", "Bhop mode.\n3=Custom\n4=Low\n5=Medium\n6=High", FCVAR_PROTECTED, true, -6.0, true, 6.0);
    
    hcvar[CVAR_AIMBOT] = CreateConVar("lilac_aimbot", "5", "Detect Aimbot.\n0=Disabled\n1=Log Only\n5+=Ban on Nth detection.", FCVAR_PROTECTED, true, 0.0);
    
    hcvar[CVAR_AIMBOT_AUTOSHOOT] = CreateConVar("lilac_aimbot_autoshoot", "1", "Detect Autoshoot.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_AIMLOCK] = CreateConVar("lilac_aimlock", "10", "Detect Aimlock.\n0=Disabled\n1=Log Only\n5+=Ban on Nth detection.", FCVAR_PROTECTED, true, 0.0);
    
    hcvar[CVAR_AIMLOCK_LIGHT] = CreateConVar("lilac_aimlock_light", "1", "Aimlock CPU Optimization (Do not disable unless robust server).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_ANTI_DUCK_DELAY] = CreateConVar("lilac_anti_duck_delay", "0", "CS:GO Only (FastDuck). Disabled by default for L4D2.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_NOISEMAKER_SPAM] = CreateConVar("lilac_noisemaker", "0", "TF2 Only. Disabled by default.", FCVAR_PROTECTED, true, -1.0, true, 1.0);
    
    hcvar[CVAR_BACKTRACK_PATCH] = CreateConVar("lilac_backtrack_patch", "0", "Patch Backtrack (Visual Fix).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_BACKTRACK_TOLERANCE] = CreateConVar("lilac_backtrack_tolerance", "0", "Backtrack tolerance ticks.", FCVAR_PROTECTED, true, 0.0, true, 3.0);
    
    hcvar[CVAR_MAX_PING] = CreateConVar("lilac_max_ping", "0", "Ping limit (0 = disabled).", FCVAR_PROTECTED, true, 0.0, true, 1000.0);
    
    hcvar[CVAR_MAX_PING_SPEC] = CreateConVar("lilac_max_ping_spec", "0", "Move high ping players to spectator.", FCVAR_PROTECTED, true, 0.0, true, 90.0);
    
    hcvar[CVAR_MAX_LERP] = CreateConVar("lilac_max_lerp", "105", "Max allowed Lerp (ms).", FCVAR_PROTECTED, true, 0.0, true, 510.0);
    
    hcvar[CVAR_MACRO] = CreateConVar("lilac_macro", "0", "Detect Macros.", FCVAR_PROTECTED, true, -1.0, true, 2.0);
    
    hcvar[CVAR_MACRO_WARNING] = CreateConVar("lilac_macro_warning", "1", "Macro warning mode.", FCVAR_PROTECTED, true, 0.0, true, 3.0);
    
    hcvar[CVAR_MACRO_DEAL_METHOD] = CreateConVar("lilac_macro_method", "0", "Macro punishment (0=Kick, 1=Ban).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_MACRO_MODE] = CreateConVar("lilac_macro_mode", "0", "Macro detection mode.", FCVAR_PROTECTED, true, 0.0, true, 3.0);
    
    hcvar[CVAR_FILTER_NAME] = CreateConVar("lilac_filter_name", "2", "Filter invalid names (newlines).", FCVAR_PROTECTED, true, -1.0, true, 2.0);
    
    hcvar[CVAR_FILTER_CHAT] = CreateConVar("lilac_filter_chat", "1", "Filter invalid chat characters.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_LOSS_FIX] = CreateConVar("lilac_loss_fix", "1", "Ignore detections during packet loss.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_AUTO_UPDATE] = CreateConVar("lilac_auto_update", "0", "Auto-Update (Requires Updater).", FCVAR_PROTECTED, true, 0.0, true, 1.0);
    
    hcvar[CVAR_DATABASE] = CreateConVar("lilac_database", "", "Database configuration name (empty = disabled).", FCVAR_PROTECTED);

    /* Hookear cambios y establecer valores iniciales */
    for (int i = 0; i < CVAR_MAX; i++) {
        if (i != CVAR_LOG_DATE)
            icvar[i] = hcvar[i].IntValue;

        hcvar[i].AddChangeHook(cvar_change);
    }

    /* Generación automática de Config en cfg/sourcemod/lilac.cfg */
    AutoExecConfig(true, "lilac");

    /* Comandos de Consola */
    RegServerCmd("lilac_date_list", lilac_date_list, "Lists date formatting options");
    RegServerCmd("lilac_set_ban_length", lilac_set_ban_length, "Sets custom ban lengths");
    RegServerCmd("lilac_ban_status", lilac_ban_status, "Prints ban status");
    RegServerCmd("lilac_bhop_set", lilac_bhop_set, "Sets Custom Bhop settings");
    
    /* Detectar ConVars del Motor */
    ConVar tcvar;
    if ((tcvar = FindConVar("sv_maxupdaterate")) != null) {
        tcvar.AddChangeHook(cvar_change);
        lilac_lerp_maxupdaterate_changed(tcvar.IntValue);
    } else {
        lilac_lerp_maxupdaterate_changed(0);
    }

    if ((tcvar = FindConVar("sv_client_min_interp_ratio")) != null) {
        tcvar.AddChangeHook(cvar_change);
        lilac_lerp_ratio_changed(tcvar.IntValue);
    } else {
        lilac_lerp_ratio_changed(0);
    }
    
    if ((tcvar = FindConVar("sv_client_max_interp_ratio")) != null) {
        tcvar.AddChangeHook(cvar_change);
        // Si tienes la función para max ratio, la llamas, si no, usa la genérica
        lilac_lerp_ratio_changed(tcvar.IntValue);
    }

    if ((tcvar = FindConVar("sv_cheats")) != null) {
        tcvar.AddChangeHook(cvar_change);
        sv_cheats = tcvar.IntValue;
    } else {
        sv_cheats = 0; // Por defecto asumimos 0 por seguridad
    }
}

public void OnConfigsExecuted()
{
    static bool run_status_ban = true;

    if (run_status_ban)
        lilac_ban_status(0);

    /* We need to call this here, in case of a plugin reload. */
    lilac_bhop_set_preset();

    run_status_ban = false;

    // Asegurarse que la base de datos se inicia si está configurada
    Database_OnConfigExecuted(); // Comentado si el modulo DB no está listo
}

/* Callback para cambios de Cvars */
public void cvar_change(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // Actualizar cache de enteros (icvar)
    if (convar == hcvar[CVAR_ENABLE]) icvar[CVAR_ENABLE] = StringToInt(newValue);
    else if (convar == hcvar[CVAR_LOG]) icvar[CVAR_LOG] = StringToInt(newValue);
    else if (convar == hcvar[CVAR_BAN]) icvar[CVAR_BAN] = StringToInt(newValue);
    // ... Mapear el resto de cvars críticas aquí ...
    // Para ahorrar espacio, SourceMod actualiza el IntValue del objeto ConVar automáticamente.
    // Pero si usas el array icvar[] para optimización, debes actualizarlo.
    
    // Método optimizado: Buscar índice
    for(int i=0; i<CVAR_MAX; i++) {
        if(convar == hcvar[i]) {
            if (i == CVAR_LOG_DATE) {
                 lilac_setup_date_format(newValue);
            } else {
                 icvar[i] = StringToInt(newValue);
            }
            
            // Logic Hooks específicos
            if (i == CVAR_BHOP) lilac_bhop_set_preset();
            if (i == CVAR_MACRO) {
                for (int k = 1; k <= MaxClients; k++) lilac_macro_reset_client(k);
            }
            break;
        }
    }
    
    // Chequeos de Motor
    char cvarName[64];
    convar.GetName(cvarName, sizeof(cvarName));
    
    if (StrEqual(cvarName, "sv_cheats")) {
        sv_cheats = StringToInt(newValue);
        time_sv_cheats = GetTime() + QUERY_TIMEOUT;
    }
    else if (StrEqual(cvarName, "sv_autobunnyhopping")) {
        force_disable_bhop = StringToInt(newValue);
    }
}

/* --- COMANDOS DE CONFIGURACIÓN --- */

public Action lilac_bhop_set(int args)
{
    if (intabs(icvar[CVAR_BHOP]) != BHOP_MODE_CUSTOM) {
        PrintToServer("[Lilac] Error: Set 'lilac_bhop' to 3 (Custom) to use this.");
        return Plugin_Handled;
    }
    if (args < 2) {
        PrintToServer("Usage: lilac_bhop_set <type> <value>\nTypes: min, max, air, total");
        return Plugin_Handled;
    }

    char type[16], valStr[16];
    GetCmdArg(1, type, sizeof(type));
    GetCmdArg(2, valStr, sizeof(valStr));
    
    int index = -1;
    float val = StringToFloat(valStr);
    
    if (StrContains(type, "min") != -1) index = BHOP_INDEX_MIN;
    else if (StrContains(type, "max") != -1) index = BHOP_INDEX_MAX;
    else if (StrContains(type, "air") != -1) index = BHOP_INDEX_AIR;
    else if (StrContains(type, "tot") != -1) index = BHOP_INDEX_TOTAL;
    else if (StrContains(type, "jump") != -1) index = BHOP_INDEX_JUMP;

    if (index == -1) {
        PrintToServer("Unknown type.");
        return Plugin_Handled;
    }

    int finalVal;
    if (index == BHOP_INDEX_AIR) finalVal = RoundToCeil(tick_rate * ((val > 1.0) ? 1.0 : val));
    else finalVal = RoundToNearest(val);

    if (finalVal < bhop_settings_min[index] && index == BHOP_INDEX_TOTAL)
        finalVal = bhop_settings_min[index];

    bhop_settings[index] = finalVal;
    print_current_bhop_settings();
    return Plugin_Handled;
}

static void print_current_bhop_settings()
{
    PrintToServer("--- Bhop Settings ---");
    PrintToServer("Min: %d", bhop_settings[BHOP_INDEX_MIN]);
    PrintToServer("Max: %d", bhop_settings[BHOP_INDEX_MAX]);
    PrintToServer("Air: %d", bhop_settings[BHOP_INDEX_AIR]);
    PrintToServer("Total: %d", bhop_settings[BHOP_INDEX_TOTAL]);
}

public Action lilac_ban_status(int args)
{
    PrintToServer("[Lilac] Ban System Status:");
    PrintToServer("SourceBans++: %s", sourcebanspp_exist ? "Yes" : "No");
    PrintToServer("MaterialAdmin: %s", materialadmin_exist ? "Yes" : "No");
    PrintToServer("BaseBans: Active");
    return Plugin_Handled;
}

public Action lilac_set_ban_length(int args)
{
    if (args < 2) {
        PrintToServer("Usage: lilac_set_ban_length <cheat> <minutes>");
        return Plugin_Handled;
    }
    
    char cheat[32], timeStr[32];
    GetCmdArg(1, cheat, sizeof(cheat));
    GetCmdArg(2, timeStr, sizeof(timeStr));
    
    int idx = -1;
    if (StrContains(cheat, "bhop") != -1) idx = CHEAT_BHOP;
    else if (StrContains(cheat, "aim") != -1) idx = CHEAT_AIMBOT;
    else if (StrContains(cheat, "ang") != -1) idx = CHEAT_ANGLES;
    // ... mapear el resto ...
    
    if (idx != -1) ban_length_overwrite[idx] = StringToInt(timeStr);
    
    return Plugin_Handled;
}

public Action lilac_date_list(int args)
{
    PrintToServer("Lilac Date Formats: {year} {month} {day} {hour} {minute} {second}");
    return Plugin_Handled;
}

static int bclamp(int n, int idx) {
    return ((n < bhop_settings_min[idx]) ? bhop_settings_min[idx] : n);
}

static void lilac_bhop_set_preset()
{
    int mode = intabs(icvar[CVAR_BHOP]);
    
    // Preset Defaults
    bhop_settings[BHOP_INDEX_MIN] = 7;
    bhop_settings[BHOP_INDEX_JUMP] = -1;
    bhop_settings[BHOP_INDEX_MAX] = 20;
    bhop_settings[BHOP_INDEX_AIR] = RoundToCeil(tick_rate * 0.3);
    bhop_settings[BHOP_INDEX_TOTAL] = 5;

    switch (mode) {
        case BHOP_MODE_LOW: { /* Default values above apply */ }
        case BHOP_MODE_MEDIUM: { bhop_settings[BHOP_INDEX_TOTAL] = 3; }
        case BHOP_MODE_HIGH: { 
            bhop_settings[BHOP_INDEX_MIN] = 5;
            bhop_settings[BHOP_INDEX_JUMP] = 8;
            bhop_settings[BHOP_INDEX_TOTAL] = 1;
        }
    }
}

static void lilac_setup_date_format(const char []format)
{
    strcopy(dateformat, sizeof(dateformat), format);
    ReplaceString(dateformat, sizeof(dateformat), "{year}", "%Y");
    ReplaceString(dateformat, sizeof(dateformat), "{month}", "%m");
    ReplaceString(dateformat, sizeof(dateformat), "{day}", "%d");
    ReplaceString(dateformat, sizeof(dateformat), "{hour}", "%H");
    ReplaceString(dateformat, sizeof(dateformat), "{minute}", "%M");
    ReplaceString(dateformat, sizeof(dateformat), "{second}", "%S");
}

void lilac_update_url()
{
    if (icvar[CVAR_AUTO_UPDATE]) 
    {
        if (NATIVE_EXISTS("Updater_AddPlugin")) {
            Updater_AddPlugin(UPDATE_URL);
        } else {
            PrintToServer("[Lilac] Error: Updater_AddPlugin not found! Check if Updater is installed.");
        }
    }
    else 
    {
        if (NATIVE_EXISTS("Updater_RemovePlugin")) {
            Updater_RemovePlugin();
        }
    }
}