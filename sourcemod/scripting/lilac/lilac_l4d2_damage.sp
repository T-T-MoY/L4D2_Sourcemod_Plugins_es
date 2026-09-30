/* lilac/lilac_l4d2_damage.sp */

#if defined _lilac_l4d2_damage_included
 #endinput
#endif
#define _lilac_l4d2_damage_included

/* L4D2 Damage Validator 
   Prevents: Insta-kill hacks, Magic Bullets.
*/

#define MAX_DMG_SINGLE_HIT 600.0 // Una escopeta hace ~250. Un AWP ~150 (en L4D2). 600 es margen seguro.

// Esta función debe ser llamada desde OnClientPutInServer en lilac.sp
void lilac_l4d2_damage_hook(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_Check);
}

public Action OnTakeDamage_Check(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    // Solo validar si el atacante es un jugador humano
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker))
    {
        // Ignorar daño por fuego o explosiones (pueden ser altos legítimamente)
        if ((damagetype & DMG_BURN) || (damagetype & DMG_BLAST))
            return Plugin_Continue;

        // DETECCIÓN: Daño excesivo en un solo tick
        if (damage > MAX_DMG_SINGLE_HIT)
        {
            // Validar arma: Solo las armas de fuego normales.
            // Ignorar Motosierra o Melee (su lógica de daño es distinta)
            char weapon[32];
            GetClientWeapon(attacker, weapon, sizeof(weapon));

            if (StrContains(weapon, "pistol") != -1 || 
                StrContains(weapon, "rifle") != -1 || 
                StrContains(weapon, "smg") != -1 || 
                StrContains(weapon, "shotgun") != -1 || 
                StrContains(weapon, "sniper") != -1)
            {
                // Es un hack de daño
                if (icvar[CVAR_LOG]) {
                    lilac_log_setup_client(attacker);
                    Format(line_buffer, sizeof(line_buffer), "%s blocked for Massive Damage Exploit (%.1f dmg with %s).", line_buffer, damage, weapon);
                    lilac_log(true);
                }
                
                // Anular el daño
                damage = 0.0; 
                
                // Banear
                lilac_ban_client(attacker, CHEAT_AIMBOT); // Usamos flag de Aimbot como genérico
                return Plugin_Handled;
            }
        }
    }
    return Plugin_Continue;
}