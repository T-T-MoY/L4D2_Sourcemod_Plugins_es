/* lilac/lilac_backtrack.sp */

#if defined _lilac_backtrack_included
 #endinput
#endif
#define _lilac_backtrack_included

/* Backtrack Detection & Patching (Updated for SM 1.12 + L4D2 Logic) */

// Variables globales del módulo
static int prev_tickcount[MAXPLAYERS + 1];
static int diff_tickcount[MAXPLAYERS + 1];
static float time_timeout[MAXPLAYERS + 1];

void lilac_backtrack_reset_client(int client)
{
    prev_tickcount[client] = 0;
    diff_tickcount[client] = 0;
    time_timeout[client] = 0.0;
}

void lilac_backtrack_store_tickcount(int client, int tickcount)
{
    // Guardamos el tick actual para compararlo en el siguiente frame
    // Nota: Usamos una variable temporal estática para el swap
    prev_tickcount[client] = tickcount; 
    // En la lógica original había un swap raro con 'tmp', simplificado aquí:
    // Realmente necesitamos el tickcount DEL FRAME ANTERIOR.
    // En OnPlayerRunCmd, guardamos el tick al FINAL de la función para la próxima vez.
}

/* Función principal llamada desde OnPlayerRunCmd */
int lilac_backtrack_patch(int client, int tickcount)
{
    // 1. Si se acaba de teletransportar, el tickcount salta. Ignorar.
    if (playerinfo_time_teleported[client] + 2.0 > GetGameTime())
        return tickcount;

    // 2. Optimización L4D2: Si está siendo atacado por especiales (Jockey/Hunter/Smoker/Charger)
    // El motor a veces desincroniza los ticks. No intervenir para evitar lag visual.
    if (ggame == GAME_L4D2) {
        if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) return tickcount;
        if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) return tickcount;
        if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) return tickcount;
        if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) return tickcount;
    }

    // 3. Detección: Si el tickcount no es válido y NO está ya en castigo...
    if (!lilac_valid_tickcount(client, tickcount) && !lilac_is_player_in_backtrack_timeout(client))
    {
        // ... ponerlo en castigo (Timeout)
        lilac_set_client_in_backtrack_timeout(client);
    }

    // 4. Parcheo: Si está en timeout y la opción de parchear está activa
    if (lilac_is_player_in_backtrack_timeout(client) && icvar[CVAR_BACKTRACK_PATCH])
    {
        return lilac_lock_tickcount(client); // Devolvemos un tickcount corregido
    }

    // Actualizamos el tickcount previo para la siguiente comparación
    // IMPORTANTE: Esto debe hacerse después de usar prev_tickcount en lilac_valid_tickcount
    prev_tickcount[client] = tickcount;

    return tickcount;
}

static int lilac_lock_tickcount(int client)
{
    /* Calcula un Tickcount "Fake" pero seguro basado en el ping */
    float latency = GetClientAvgLatency(client, NetFlow_Outgoing);
    int ping_ticks = RoundToNearest(latency / GetTickInterval());
    
    // Calculamos el tick ideal basado en la diferencia congelada
    int tick = diff_tickcount[client] + (GetGameTickCount() - ping_ticks);

    /* Seguridad: Nunca devolver un tick mayor al del servidor */
    if (tick > GetGameTickCount()) 
        return GetGameTickCount();
        
    return tick;
}

static bool lilac_valid_tickcount(int client, int tickcount)
{
    /* Lógica: El tickcount del cliente debería aumentar de 1 en 1 (aprox).
       Si la diferencia entre (Anterior + 1) y (Actual) es muy grande, 
       están manipulando el tiempo (Backtrack). */
    
    int delta = intabs((prev_tickcount[client] + 1) - tickcount);
    return (delta <= icvar[CVAR_BACKTRACK_TOLERANCE]);
}

static void lilac_set_client_in_backtrack_timeout(int client)
{
    /* Castigo: Ignorar sus tickcounts manipulados por 1.1 segundos */
    time_timeout[client] = GetGameTime() + 1.1;

    /* Calcular la diferencia "legal" actual para forzarla durante el castigo */
    float latency = GetClientAvgLatency(client, NetFlow_Outgoing);
    int ping_ticks = RoundToNearest(latency / GetTickInterval());
    
    // Guardamos la diferencia base para el lock
    diff_tickcount[client] = (prev_tickcount[client] - (GetGameTickCount() - ping_ticks)) + 1;

    /* Clamp: Limitar la diferencia para evitar errores extremos de punto flotante */
    int limit = time_to_ticks(0.2) - 3; // ~200ms de margen
    if (diff_tickcount[client] > limit)
        diff_tickcount[client] = limit;
    else if (diff_tickcount[client] < (limit * -1))
        diff_tickcount[client] = (limit * -1);
}

static bool lilac_is_player_in_backtrack_timeout(int client)
{
    return (GetGameTime() < time_timeout[client]);
}