/* lilac/lilac_l4d2_movement.sp */

#if defined _lilac_l4d2_movement_included
 #endinput
#endif
#define _lilac_l4d2_movement_included

/* L4D2 Movement Validator
   Prevents: Speedhack, Teleport hacks.
*/

static float g_vLastOrigin[MAXPLAYERS + 1][3];
static int g_iSpeedWarnings[MAXPLAYERS + 1];

void lilac_movement_reset(int client)
{
    g_vLastOrigin[client][0] = 0.0;
    g_iSpeedWarnings[client] = 0;
}

void lilac_l4d2_movement_check(int client)
{
    // Validaciones básicas
    if (!IsPlayerAlive(client) || IsFakeClient(client) || GetClientTeam(client) < 2)
        return;

    // Ignorar si está en noclip o movetype observador
    if (GetEntityMoveType(client) == MOVETYPE_NOCLIP || GetEntityMoveType(client) == MOVETYPE_OBSERVER)
        return;

    // Ignorar si está dentro de un vehículo o montado
    if (GetEntPropEnt(client, Prop_Send, "m_hVehicle") != -1) return;

    // --- FILTROS DE L4D2 (EVITAR FALSOS POSITIVOS) ---
    // 1. Ignorar si acaba de respawnear/teletransportarse
    if (GetGameTime() - playerinfo_time_teleported[client] < 1.0) {
        GetClientAbsOrigin(client, g_vLastOrigin[client]);
        return;
    }

    // 2. Si es Infectado, ignorar Charger (Charge), Hunter (Pounce), Jockey (Ride)
    if (GetClientTeam(client) == 3) {
        int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if (zombieClass == 3 || zombieClass == 5 || zombieClass == 6) { 
             GetClientAbsOrigin(client, g_vLastOrigin[client]);
             return; // Hunter, Jockey, Charger se mueven muy rápido legalmente
        }
        if (playerinfo_is_ghost[client]) return;
    }

    // 3. Si es Superviviente, ignorar si está siendo atacado (Velocity boost por golpe de Tank)
    if (GetClientTeam(client) == 2) {
        if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
            GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) {
            GetClientAbsOrigin(client, g_vLastOrigin[client]);
            return;
        }
    }

    // --- CÁLCULO DE VELOCIDAD ---
    float currentPos[3];
    GetClientAbsOrigin(client, currentPos);

    // Si no teníamos posición previa, guardarla y salir
    if (GetVectorLength(g_vLastOrigin[client]) == 0.0) {
        g_vLastOrigin[client] = currentPos;
        return;
    }

    float distance = GetVectorDistance(currentPos, g_vLastOrigin[client]);
    
    // Velocidad máxima teórica en 1 tick (~450 unidades es correr + adrenalina + slope boost)
    // Speedhacks suelen hacer > 800 unidades por tick (teleport) o velocidad constante alta.
    // Usamos un umbral alto para seguridad (700 unidades en 1 tick es ~21000 u/s velocity, imposible legalmente).
    
    if (distance > 600.0)
    {
        g_iSpeedWarnings[client]++;

        if (g_iSpeedWarnings[client] >= 3) // 3 ticks seguidos moviéndose imposiblemente rápido
        {
            if (icvar[CVAR_LOG]) {
                lilac_log_setup_client(client);
                Format(line_buffer, sizeof(line_buffer), "%s detected Speedhack/Teleport (Dist: %.1f).", line_buffer, distance);
                lilac_log(true);
            }
            
            // Teletransportar al jugador atrás (Rubberbanding) para anular el hack
            TeleportEntity(client, g_vLastOrigin[client], NULL_VECTOR, NULL_VECTOR);
            
            // Banear
            lilac_ban_client(client, CHEAT_BHOP); // Usamos flag de movimiento
        }
    }
    else
    {
        // Enfriar advertencias si se mueve normal
        if (g_iSpeedWarnings[client] > 0) g_iSpeedWarnings[client]--;
    }

    g_vLastOrigin[client] = currentPos;
}