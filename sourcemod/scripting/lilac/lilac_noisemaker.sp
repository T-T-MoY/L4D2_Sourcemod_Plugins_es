/* lilac/lilac_noisemaker.sp */

#if defined _lilac_noisemaker_included
 #endinput
#endif
#define _lilac_noisemaker_included

/* TF2 Noisemaker Detection (Updated for SM 1.12) 
   NOTE: This module does absolutely nothing in L4D2/CSGO.
*/

static int noisemaker_type[MAXPLAYERS + 1];
static int noisemaker_entity[MAXPLAYERS + 1];
static int noisemaker_entity_prev[MAXPLAYERS + 1];
static int noisemaker_detection[MAXPLAYERS + 1];

void lilac_noisemaker_reset_client(int client)
{
    noisemaker_type[client] = 0;
    noisemaker_entity[client] = 0;
    noisemaker_entity_prev[client] = 0;
    noisemaker_detection[client] = 0;
}

public Action event_inventoryupdate(Event event, const char[] name, bool dontBroadcast)
{
    // Optimización: Si no es TF2, ignorar evento completamente
    if (ggame != GAME_TF2) return Plugin_Continue;

    int client = GetClientOfUserId(event.GetInt("userid"));
    check_inventory_for_noisemaker(client);

    return Plugin_Continue;
}

void check_inventory_for_noisemaker(int client)
{
    if (ggame != GAME_TF2) return; // Doble seguridad

    char classname[32];
    int type;

    if (!is_player_valid(client))
        return;

    noisemaker_type[client] = NOISEMAKER_TYPE_NONE;
    noisemaker_entity_prev[client] = noisemaker_entity[client];
    noisemaker_entity[client] = 0;

    int max_entities = GetEntityCount();
    for (int i = MaxClients + 1; i < max_entities; i++) 
    {
        if (!IsValidEdict(i)) continue;
        if (GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") != client) continue;

        GetEntityClassname(i, classname, sizeof(classname));

        if (!StrEqual(classname, "tf_wearable", false)) continue;

        type = get_entity_noisemaker_type(GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex"));

        if (type) {
            noisemaker_type[client] = type;
            noisemaker_entity[client] = i;
            return;
        }
    }
}

static int get_entity_noisemaker_type(int itemindex)
{
    switch (itemindex) {
        case 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 493, 542: 
            return NOISEMAKER_TYPE_LIMITED;
        
        case 536, 673: 
            return NOISEMAKER_TYPE_UNLIMITED;
    }
    return NOISEMAKER_TYPE_NONE;
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
    if (ggame != GAME_TF2) return Plugin_Continue;

    if (!icvar[CVAR_ENABLE] || !icvar[CVAR_NOISEMAKER_SPAM])
        return Plugin_Continue;

    char command[64];
    kv.GetSectionName(command, sizeof(command));

    if (noisemaker_type[client] != NOISEMAKER_TYPE_LIMITED)
        return Plugin_Continue;

    if (noisemaker_entity_prev[client] != noisemaker_entity[client]) {
        noisemaker_entity_prev[client] = noisemaker_entity[client];
        noisemaker_detection[client] = 0;
    }

    if (StrEqual(command, "+use_action_slot_item_server", false)
        || StrEqual(command, "-use_action_slot_item_server", false)) 
    {
        /* Detectar spam: Limite 60 usos rápidos */
        if (++noisemaker_detection[client] > 60)
            lilac_detected_noisemaker(client);
    }

    return Plugin_Continue;
}

static void lilac_detected_noisemaker(int client)
{
    if (playerinfo_banned_flags[client][CHEAT_NOISEMAKER_SPAM])
        return;

    if (!lilac_forward_allow_cheat_detection(client, CHEAT_NOISEMAKER_SPAM))
        return;

    playerinfo_banned_flags[client][CHEAT_NOISEMAKER_SPAM] = true;
    lilac_forward_client_cheat(client, CHEAT_NOISEMAKER_SPAM);

    if (icvar[CVAR_LOG]) {
        lilac_log_setup_client(client);
        Format(line_buffer, sizeof(line_buffer), "%s suspected of unlimited noisemaker spam.", line_buffer);
        lilac_log(true);
        if (icvar[CVAR_LOG_EXTRA]) lilac_log_extra(client);
    }
    
    database_log(client, "noisemaker", DATABASE_LOG_ONLY);
    
    // Solo logueamos por ahora, no baneamos en esta versión
}