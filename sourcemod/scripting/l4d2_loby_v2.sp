#pragma semicolon 1
#pragma newdecls required // Obliga a usar la sintaxis moderna de SourceMod 1.12

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_ENTITIES 4096 // Aumentado el límite de 2048 a 4096 para mapas pesados

float g_fEntPos[MAX_ENTITIES][3];
bool g_bPosChange[MAX_ENTITIES];

public Plugin myinfo =
{
	name = "LagFixer (Listen Server Buff)",
	author = "tRololo312312 & Actualizado por MoY",
	description = "Solución optimizada para el lag de phys_bone_follower.",
	version = "2.0",
	url = "https://steamcommunity.com/profiles/76561198039186809/"
};

public void OnPluginStart()
{
	// Se mantiene el timer cada 7 segundos para no sobrecargar el servidor
	CreateTimer(7.0, Timer_CheckPos, _, TIMER_REPEAT);
}

public Action Timer_CheckPos(Handle timer)
{
	float currentPos[3];
	int i = -1;
	
	while ((i = FindEntityByClassname(i, "phys_bone_follower")) != INVALID_ENT_REFERENCE)
	{
		// Protección contra índices fuera de límite (Index out of bounds)
		if (i < 0 || i >= MAX_ENTITIES) 
			continue;

		if (IsValidEntity(i))
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", currentPos);
			
			// Si la entidad no está en su posición por defecto {0.0, 0.0, 0.0}
			if (g_fEntPos[i][0] != 0.0 || g_fEntPos[i][1] != 0.0 || g_fEntPos[i][2] != 0.0)
			{
				bool moved = false;
				for (int index = 0; index < 3; index++)
				{
					if (currentPos[index] != g_fEntPos[i][index])
					{
						moved = true;
						break;
					}
				}
				
				if (moved)
				{
					g_bPosChange[i] = true;
				}
				else if (g_bPosChange[i])
				{
					g_bPosChange[i] = false;
				}
			}

			// Actualizar la posición guardada
			for (int index = 0; index < 3; index++)
			{
				g_fEntPos[i][index] = currentPos[index];
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "phys_bone_follower"))
	{
		// Verificamos que el índice de la entidad sea válido para nuestros arrays
		if (entity >= 0 && entity < MAX_ENTITIES && IsValidEntity(entity))
		{
			SDKHook(entity, SDKHook_SetTransmit, Hook_HideIt);
			
			g_fEntPos[entity][0] = 0.0;
			g_fEntPos[entity][1] = 0.0;
			g_fEntPos[entity][2] = 0.0;
			g_bPosChange[entity] = false;
		}
	}
}

public Action Hook_HideIt(int iEntity, int iClient)
{
	// Seguridad adicional: Asegurarse de que el índice es válido y el cliente está en el juego
	if (iEntity < 0 || iEntity >= MAX_ENTITIES)
		return Plugin_Continue;
		
	if (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient))
	{
		if (!IsFakeClient(iClient) && g_bPosChange[iEntity])
		{
			return Plugin_Handled; // Oculta la entidad al cliente
		}
	}
	
	return Plugin_Continue;
}