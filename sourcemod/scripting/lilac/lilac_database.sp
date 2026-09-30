/* lilac/lilac_database.sp */

#if defined _lilac_database_included
 #endinput
#endif
#define _lilac_database_included

/* Database Module (Updated for SM 1.12) */

void Database_OnConfigExecuted()
{
    // Si ya estamos conectados, no hacer nada
    if (lil_db != null)
        return;
    
    static bool first_load = true;
    
    /* Obtener nombre de la config de base de datos */
    if (first_load) {
        hcvar[CVAR_DATABASE].GetString(db_name, sizeof(db_name));
        first_load = false;
    }
    
    // Si la cvar está vacía, no usamos DB
    if (db_name[0] == '\0' || IsCharSpace(db_name[0]))
        return;
    
    if (!SQL_CheckConfig(db_name)) {
        LogError("[Lilac] Database config '%s' doesn't exist in databases.cfg", db_name);
        return;
    }

    // Conexión asíncrona moderna
    Database.Connect(OnDatabaseConnected, db_name);
}

public void OnDatabaseConnected(Database db, const char[] error, any data)
{
    if (db == null) {
        LogError("[Lilac] Could not connect to database: %s", error);
        return;
    }
    
    lil_db = db;
    InitDatabase();
}

void InitDatabase()
{
    /* Crear tabla si no existe (Compatible MySQL y SQLite) */
    char query[] = "CREATE TABLE IF NOT EXISTS lilac_detections (" ...
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " ... // SQLite prefiere esto, MySQL lo acepta
        "name varchar(128) NOT NULL, " ...
        "steamid varchar(32) NOT NULL, " ...
        "ip varchar(32) NOT NULL, " ...
        "cheat varchar(50) NOT NULL, " ...
        "timestamp INTEGER NOT NULL, " ...
        "detection INTEGER NOT NULL, " ...
        "pos1 FLOAT NOT NULL, pos2 FLOAT NOT NULL, pos3 FLOAT NOT NULL, " ...
        "ang1 FLOAT NOT NULL, ang2 FLOAT NOT NULL, ang3 FLOAT NOT NULL, " ...
        "map varchar(128) NOT NULL, " ...
        "team INTEGER NOT NULL, " ...
        "weapon varchar(64) NOT NULL, " ...
        "data1 FLOAT NOT NULL, data2 FLOAT NOT NULL, " ...
        "latency_inc FLOAT NOT NULL, latency_out FLOAT NOT NULL, " ...
        "loss_inc FLOAT NOT NULL, loss_out FLOAT NOT NULL, " ...
        "choke_inc FLOAT NOT NULL, choke_out FLOAT NOT NULL, " ...
        "connection_ticktime FLOAT NOT NULL, " ...
        "game_ticktime FLOAT NOT NULL, " ...
        "lilac_version varchar(20) NOT NULL);";

    lil_db.Query(OnDatabaseInit, query);
    
    // Intentar establecer UTF-8 para nombres con caracteres especiales
    lil_db.SetCharset("utf8mb4");
}

public void OnDatabaseInit(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null) {
        LogError("[Lilac] Database init failed: %s", error);
        delete lil_db;
        lil_db = null;
    }
}

/* Función principal para loguear en la DB */
void database_log(int client, char[] cheat, int detection=DATABASE_BAN, float data1=0.0, float data2=0.0)
{
    if (lil_db == null)
        return;

    char steamid[32], ip[32], map[128], weapon[64];
    float pos[3], ang[3];

    // Obtener y limpiar nombre
    char name[MAX_NAME_LENGTH];
    char safe_name[(MAX_NAME_LENGTH * 2) + 1]; // Buffer doble para escape
    
    if (!GetClientName(client, name, sizeof(name))) {
        strcopy(safe_name, sizeof(safe_name), "<unknown>");
    } else {
        TrimString(name);
        lil_db.Escape(name, safe_name, sizeof(safe_name));
    }

    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
    GetClientIP(client, ip, sizeof(ip), true);
    GetClientAbsOrigin(client, pos);
    GetCurrentMap(map, sizeof(map));
    GetClientWeapon(client, weapon, sizeof(weapon));
    get_player_log_angles(client, 0, true, ang);

    // Construcción de Query
    // Usamos FormatEx y un buffer grande (definido en globals)
    FormatEx(sql_buffer, sizeof(sql_buffer), 
        "INSERT INTO lilac_detections (" ...
        "name, steamid, ip, cheat, timestamp, detection, " ...
        "pos1, pos2, pos3, ang1, ang2, ang3, " ...
        "map, team, weapon, data1, data2, " ...
        "latency_inc, latency_out, loss_inc, loss_out, " ...
        "choke_inc, choke_out, connection_ticktime, game_ticktime, lilac_version) " ...
        "VALUES ('%s', '%s', '%s', '%s', %d, %d, " ...
        "%.1f, %.1f, %.1f, %.5f, %.5f, %.5f, " ...
        "'%s', %d, '%s', %.4f, %.4f, " ...
        "%.4f, %.4f, %.4f, %.4f, " ...
        "%.4f, %.4f, %.4f, %.4f, '%s');",
        safe_name, steamid, ip, cheat, GetTime(), detection,
        pos[0], pos[1], pos[2], ang[0], ang[1], ang[2],
        map, GetClientTeam(client), weapon, data1, data2,
        GetClientAvgLatency(client, NetFlow_Incoming), GetClientAvgLatency(client, NetFlow_Outgoing),
        GetClientAvgLoss(client, NetFlow_Incoming), GetClientAvgLoss(client, NetFlow_Outgoing),
        GetClientAvgChoke(client, NetFlow_Incoming), GetClientAvgChoke(client, NetFlow_Outgoing),
        GetClientTime(client), GetGameTime(), PLUGIN_VERSION);

    lil_db.Query(OnDetectionInserted, sql_buffer);
}

public void OnDetectionInserted(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null) {
        LogError("[Lilac] Failed to insert detection: %s", error);
    }
}