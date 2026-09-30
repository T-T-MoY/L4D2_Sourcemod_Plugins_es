#if defined _tank_abilities_included
 #endinput
#endif
#define _tank_abilities_included

/**
 * Se dispara cuando un Tank usa ability_throw.
 * Los listeners pueden retornar Plugin_Handled para indicar que "consumieron" el evento
 * (ejemplo: el módulo multirock retorna Handled cuando activa las rocas).
 * El core verifica este retorno.
 */
forward Action L4D2_OnTankAbility(int client, const char[] ability);

/**
 * Se dispara SOLO si ningún listener de L4D2_OnTankAbility retornó Plugin_Handled.
 * Es decir: se dispara solo cuando las rocas NO se activaron ese throw.
 * El módulo TP escucha ESTE forward para simular el "else" del OLD.
 */
forward void L4D2_OnTankAbilityElse(int client, const char[] ability);

/**
 * Helper para verificar si un cliente es un Tank válido.
 */
stock bool IsValidTank(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
            GetClientTeam(client) == 3 && IsPlayerAlive(client) && 
            GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}
