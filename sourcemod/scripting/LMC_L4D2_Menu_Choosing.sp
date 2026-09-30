/*  
*    LMC_L4D2_Menu_Choosing - Allows humans to choose LMC model with cookiesaving
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    Modified: Added first-person arms model support for infected disguises
*    Version 2.0.0
*/


#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define REQUIRE_EXTENSIONS
#include <clientprefs>
#undef REQUIRE_EXTENSIONS

#define REQUIRE_PLUGIN
#include <LMCCore>
#include <LMCL4D2CDeathHandler>
#include <LMCL4D2SetTransmit>
#undef REQUIRE_PLUGIN

#pragma newdecls required


#define PLUGIN_NAME "LMC_L4D2_Menu_Choosing"
#define PLUGIN_VERSION "2.0.0"

//change me to whatever flag you want
#define COMMAND_ACCESS ADMFLAG_CHAT

#define HUMAN_MODEL_PATH_SIZE 11
#define SPECIAL_MODEL_PATH_SIZE 8
#define UNCOMMON_MODEL_PATH_SIZE 6
#define COMMON_MODEL_PATH_SIZE 34


enum /*ZOMBIECLASS*/
{
	ZOMBIECLASS_SMOKER = 1,
	ZOMBIECLASS_BOOMER,
	ZOMBIECLASS_HUNTER,
	ZOMBIECLASS_SPITTER,
	ZOMBIECLASS_JOCKEY,
	ZOMBIECLASS_CHARGER,
	ZOMBIECLASS_UNKNOWN,
	ZOMBIECLASS_TANK,
}

enum LMCModelSectionType
{
	LMCModelSectionType_Human = 0,
	LMCModelSectionType_Special,
	LMCModelSectionType_UnCommon,
	LMCModelSectionType_Common
};

static const char sHumanPaths[HUMAN_MODEL_PATH_SIZE][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_teenangst_light.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_biker_light.mdl",
	"models/survivors/survivor_manager.mdl",
	"models/npcs/rescue_pilot_01.mdl"
};

enum LMCHumanModelType
{
	LMCHumanModelType_Nick = 0,
	LMCHumanModelType_Rochelle,
	LMCHumanModelType_Coach,
	LMCHumanModelType_Ellis,
	LMCHumanModelType_Bill,
	LMCHumanModelType_Zoey,
	LMCHumanModelType_ZoeyLight,
	LMCHumanModelType_Francis,
	LMCHumanModelType_FrancisLight,
	LMCHumanModelType_Louis,
	LMCHumanModelType_Pilot
};

static const char sSpecialPaths[SPECIAL_MODEL_PATH_SIZE][] =
{
	"models/infected/witch.mdl",
	"models/infected/witch_bride.mdl",
	"models/infected/boomer.mdl",
	"models/infected/boomette.mdl",
	"models/infected/hunter.mdl",
	"models/infected/smoker.mdl",
	"models/infected/hulk.mdl",
	"models/infected/hulk_dlc3.mdl"
};

enum LMCSpecialModelType
{
	LMCSpecialModelType_Witch = 0,
	LMCSpecialModelType_WitchBride,
	LMCSpecialModelType_Boomer,
	LMCSpecialModelType_Boomette,
	LMCSpecialModelType_Hunter,
	LMCSpecialModelType_Smoker,
	LMCSpecialModelType_Tank,
	LMCSpecialModelType_TankDLC3
};

static const char sUnCommonPaths[UNCOMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_riot.mdl",
	"models/infected/common_male_mud.mdl",
	"models/infected/common_male_ceda.mdl",
	"models/infected/common_male_clown.mdl",
	"models/infected/common_male_jimmy.mdl",
	"models/infected/common_male_fallen_survivor.mdl"
};

enum LMCUnCommonModelType
{
	LMCUnCommonModelType_RiotCop = 0,
	LMCUnCommonModelType_MudMan,
	LMCUnCommonModelType_Ceda,
	LMCUnCommonModelType_Clown,
	LMCUnCommonModelType_Jimmy,
	LMCUnCommonModelType_Fallen
};

static const char sCommonPaths[COMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_tshirt_cargos.mdl",
	"models/infected/common_male_tankTop_jeans.mdl",
	"models/infected/common_male_dressShirt_jeans.mdl",
	"models/infected/common_female_tankTop_jeans.mdl",
	"models/infected/common_female_tshirt_skirt.mdl",
	"models/infected/common_male_roadcrew.mdl",
	"models/infected/common_male_tankTop_overalls.mdl",
	"models/infected/common_male_tankTop_jeans_rain.mdl",
	"models/infected/common_female_tankTop_jeans_rain.mdl",
	"models/infected/common_male_roadcrew_rain.mdl",
	"models/infected/common_male_tshirt_cargos_swamp.mdl",
	"models/infected/common_male_tankTop_overalls_swamp.mdl",
	"models/infected/common_female_tshirt_skirt_swamp.mdl",
	"models/infected/common_male_formal.mdl",
	"models/infected/common_female_formal.mdl",
	"models/infected/common_military_male01.mdl",
	"models/infected/common_police_male01.mdl",
	"models/infected/common_male_baggagehandler_01.mdl",
	"models/infected/common_tsaagent_male01.mdl",
	"models/infected/common_shadertest.mdl",
	"models/infected/common_female_nurse01.mdl",
	"models/infected/common_surgeon_male01.mdl",
	"models/infected/common_worker_male01.mdl",
	"models/infected/common_morph_test.mdl",
	"models/infected/common_male_biker.mdl",
	"models/infected/common_female01.mdl",
	"models/infected/common_male01.mdl",
	"models/infected/common_male_suit.mdl",
	"models/infected/common_patient_male01_l4d2.mdl",
	"models/infected/common_male_polo_jeans.mdl",
	"models/infected/common_female_rural01.mdl",
	"models/infected/common_male_rural01.mdl",
	"models/infected/common_male_pilot.mdl",
	"models/infected/common_test.mdl"
};

// Arms models for first person view (infected disguises)
static const char sArmsBoomer[]  = "models/v_models/weapons/v_claw_boomer.mdl";
static const char sArmsHunter[]  = "models/v_models/weapons/v_claw_hunter.mdl";
static const char sArmsSmoker[]  = "models/v_models/weapons/v_claw_smoker.mdl";
static const char sArmsTank[]    = "models/v_models/weapons/v_claw_hulk.mdl";

#define CvarIndexes 7
static const char sSharedCvarNames[CvarIndexes][] =
{
	"lmc_allowtank",
	"lmc_allowhunter",
	"lmc_allowsmoker",
	"lmc_allowboomer",
	"lmc_allowSurvivors",
	"lmc_allow_tank_model_use",
	"lmc_precache_prevent"
};

static const char sJoinSound[] = "ui/menu_countdown.wav";

static Handle hCvar_ArrayIndex[CvarIndexes] = {INVALID_HANDLE, ...};

static bool g_bAllowTank = false;
static bool g_bAllowHunter = true;
static bool g_bAllowSmoker = true;
static bool g_bAllowBoomer = true;
static bool g_bAllowSurvivors = true;
static bool g_bTankModel = false;

static Handle hCookie_LmcCookie = INVALID_HANDLE;

static Handle hCvar_AdminOnlyModel = INVALID_HANDLE;
static Handle hCvar_AnnounceDelay = INVALID_HANDLE;
static Handle hCvar_AnnounceMode = INVALID_HANDLE;
static Handle hCvar_ThirdPersonTime = INVALID_HANDLE;

static float g_fAnnounceDelay = 15.0;
static int g_iAnnounceMode = 1;
static bool g_bAdminOnly = false;
static float g_fThirdPersonTime = 2.0;

static int iSavedModel[MAXPLAYERS+1] = {0, ...};
static bool bAutoApplyMsg[MAXPLAYERS+1];
static bool bAutoBlockedMsg[MAXPLAYERS+1][9];

static int iCurrentPage[MAXPLAYERS+1];

// Arms model tracking per client
static char sClientArmsModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
static Handle hArmsTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Lux",
	description = "Allows humans to choose LMC model with cookiesaving",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};

public void OnPluginStart()
{
	LoadTranslations("lmc.phrases");

	CreateConVar("lmc_l4d2_menu_choosing", PLUGIN_VERSION, "LMC_L4D2_Menu_Choosing_Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);

	hCvar_AdminOnlyModel = CreateConVar("lmc_adminonly", "0", "Allow admins to only change models? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AnnounceDelay = CreateConVar("lmc_announcedelay", "15.0", "Delay On which a message is displayed for !lmc command", FCVAR_NOTIFY, true, 1.0, true, 360.0);
	hCvar_AnnounceMode = CreateConVar("lmc_announcemode", "1", "Display Mode for !lmc command (0 = off, 1 = Print to chat, 2 = Hint text, 3 = Director Hint)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	hCvar_ThirdPersonTime = CreateConVar("lmc_thirdpersontime", "0.0", "How long (in seconds) the client will be in thirdperson view after selecting a model from !lmc command. (0.5 < = off)", FCVAR_NOTIFY, true, 0.0, true, 360.0);
	HookConVarChange(hCvar_AdminOnlyModel, eConvarChanged);
	HookConVarChange(hCvar_AnnounceDelay, eConvarChanged);
	HookConVarChange(hCvar_AnnounceMode, eConvarChanged);
	HookConVarChange(hCvar_ThirdPersonTime, eConvarChanged);
	AutoExecConfig(true, "LMC_L4D2_Menu_Choosing");
	CvarsChanged();

	hCookie_LmcCookie = RegClientCookie("lmc_cookie", "", CookieAccess_Protected);
	RegConsoleCmd("sm_lmc", ShowMenuCmd, "Brings up a menu to select a client's model");

	HookEvent("player_spawn", ePlayerSpawn);
	HookEvent("player_bot_replace", ePlayerBotReplace);
	HookEvent("player_death", ePlayerDeath);
}

void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	if(hCvar_ArrayIndex[0] != INVALID_HANDLE)
		g_bAllowTank = GetConVarInt(hCvar_ArrayIndex[0]) > 0;
	if(hCvar_ArrayIndex[1] != INVALID_HANDLE)
		g_bAllowHunter = GetConVarInt(hCvar_ArrayIndex[1]) > 0;
	if(hCvar_ArrayIndex[2] != INVALID_HANDLE)
		g_bAllowSmoker = GetConVarInt(hCvar_ArrayIndex[2]) > 0;
	if(hCvar_ArrayIndex[3] != INVALID_HANDLE)
		g_bAllowBoomer = GetConVarInt(hCvar_ArrayIndex[3]) > 0;
	if(hCvar_ArrayIndex[4] != INVALID_HANDLE)
		g_bAllowSurvivors = GetConVarInt(hCvar_ArrayIndex[4]) > 0;
	if(hCvar_ArrayIndex[5] != INVALID_HANDLE)
		g_bTankModel = GetConVarInt(hCvar_ArrayIndex[5]) > 0;

	g_bAdminOnly = GetConVarInt(hCvar_AdminOnlyModel) > 0;
	g_fAnnounceDelay = GetConVarFloat(hCvar_AnnounceDelay);
	g_iAnnounceMode = GetConVarInt(hCvar_AnnounceMode);
	g_fThirdPersonTime = GetConVarFloat(hCvar_ThirdPersonTime);
}

void HookCvars()
{
	for(int i = 0; i < CvarIndexes; i++)
	{
		if(hCvar_ArrayIndex[i] != INVALID_HANDLE)
			continue;

		if((hCvar_ArrayIndex[i] = FindConVar(sSharedCvarNames[i])) == INVALID_HANDLE)
		{
			PrintToServer("[LMC]Unable to find shared cvar \"%s\" using fallback value plugin:(%s)", sSharedCvarNames[i], PLUGIN_NAME);
			continue;
		}
		HookConVarChange(hCvar_ArrayIndex[i], eConvarChanged);
	}
}


public void OnMapStart()
{
	bool bPrecacheModels = true;
	if(FindConVar(sSharedCvarNames[6]) != INVALID_HANDLE)
	{
		char sCvarString[4096];
		char sMap[67];
		GetConVarString(FindConVar(sSharedCvarNames[6]), sCvarString, sizeof(sCvarString));
		GetCurrentMap(sMap, sizeof(sMap));

		Format(sMap, sizeof(sMap), ",%s,", sMap);
		Format(sCvarString, sizeof(sCvarString), ",%s,", sCvarString);

		if(StrContains(sCvarString, sMap, false) != -1)
			bPrecacheModels = false;

		if(!bPrecacheModels)
		{
			ReplaceString(sMap, sizeof(sMap), ",", "", false);
			PrintToServer("[%s] \"%s\" Model Precaching Disabled.", PLUGIN_NAME, sMap);
		}
	}

	if(bPrecacheModels)
	{
		int i;
		for(i = 0; i < HUMAN_MODEL_PATH_SIZE; i++)
			PrecacheModel(sHumanPaths[i], true);

		for(i = 0; i < SPECIAL_MODEL_PATH_SIZE; i++)
			PrecacheModel(sSpecialPaths[i], true);

		for(i = 0; i < UNCOMMON_MODEL_PATH_SIZE; i++)
			PrecacheModel(sUnCommonPaths[i], true);

		for(i = 0; i < COMMON_MODEL_PATH_SIZE; i++)
			PrecacheModel(sCommonPaths[i], true);

		// Precache arms models
		PrecacheModel(sArmsBoomer, true);
		PrecacheModel(sArmsHunter, true);
		PrecacheModel(sArmsSmoker, true);
		PrecacheModel(sArmsTank, true);
	}

	PrecacheSound(sJoinSound, true);

	HookCvars();
	CvarsChanged();
}

//=============================================================================
// ARMS MODEL FUNCTIONS
//=============================================================================

// Returns the arms model path for a given menu case number
// Returns empty string if no custom arms model needed
void GetArmsModelForCase(int iCaseNum, char[] sOut, int iMaxLen)
{
	sOut[0] = '\0';
	switch(iCaseNum)
	{
		case 5, 6:   // Boomer, Boomette
			strcopy(sOut, iMaxLen, sArmsBoomer);
		case 7:      // Hunter
			strcopy(sOut, iMaxLen, sArmsHunter);
		case 8:      // Smoker
			strcopy(sOut, iMaxLen, sArmsSmoker);
		case 24, 25: // Tank, Tank DLC
			strcopy(sOut, iMaxLen, sArmsTank);
	}
}

// Applies the arms model to client and starts the maintenance timer
void ApplyArmsModel(int iClient, int iCaseNum)
{
    if(GetClientTeam(iClient) != 2)
        return;

    char sArms[PLATFORM_MAX_PATH];
    GetArmsModelForCase(iCaseNum, sArms, sizeof(sArms));

    strcopy(sClientArmsModel[iClient], PLATFORM_MAX_PATH, sArms);

    if(sArms[0] != '\0')
    {
        SetArmsViewModel(iClient, sArms);
        StartArmsTimer(iClient);
    }
    else
    {
        StopArmsTimer(iClient);
    }
}

void SetArmsViewModel(int iClient, const char[] sArmsModel)
{
    int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
    if(iViewModel < 1 || !IsValidEntity(iViewModel))
        return;

    PrintToConsole(iClient, "[LMC Arms] ViewModel entity: %d", iViewModel);
    PrintToConsole(iClient, "[LMC Arms] Applying arms: %s", sArmsModel);
    PrintToConsole(iClient, "[LMC Arms] Is precached: %d", IsModelPrecached(sArmsModel));

    SetEntityModel(iViewModel, sArmsModel);
}

// Starts a repeating timer to maintain the arms model (game overwrites it)
void StartArmsTimer(int iClient)
{
	StopArmsTimer(iClient);
	hArmsTimer[iClient] = CreateTimer(0.1, Timer_MaintainArms, GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void StopArmsTimer(int iClient)
{
	if(hArmsTimer[iClient] != INVALID_HANDLE)
	{
		KillTimer(hArmsTimer[iClient]);
		hArmsTimer[iClient] = INVALID_HANDLE;
	}
}

Action Timer_MaintainArms(Handle hTimer, any iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if(iClient < 1 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2)
	{
		// Client gone or not a survivor anymore - stop timer
		int iIdx = -1;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(hArmsTimer[i] == hTimer)
			{
				iIdx = i;
				break;
			}
		}
		if(iIdx != -1)
			hArmsTimer[iIdx] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	if(sClientArmsModel[iClient][0] != '\0')
    {
        PrintToConsole(iClient, "[LMC Arms] Applying: %s", sClientArmsModel[iClient]);
        //SetEntPropString(iClient, Prop_Send, "m_szArmsModel", sClientArmsModel[iClient]);
		SetArmsViewModel(iClient, sClientArmsModel[iClient]);
        
        // Verificar si realmente se aplicó
        char sCheck[PLATFORM_MAX_PATH];
        GetEntPropString(iClient, Prop_Send, "m_szArmsModel", sCheck, sizeof(sCheck));
        PrintToConsole(iClient, "[LMC Arms] Current after set: %s", sCheck);
    }



	//if(sClientArmsModel[iClient][0] != '\0')
	//	SetEntPropString(iClient, Prop_Send, "m_szArmsModel", sClientArmsModel[iClient]);

	return Plugin_Continue;
}

// Resets arms model to default and stops timer
void ResetArmsModel(int iClient)
{
    StopArmsTimer(iClient);
    sClientArmsModel[iClient][0] = '\0';

    // Restaurar el viewmodel original del jugador
    int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
    if(iViewModel > 0 && IsValidEntity(iViewModel))
    {
        char sModel[PLATFORM_MAX_PATH];
        GetClientModel(iClient, sModel, sizeof(sModel));
        SetEntityModel(iViewModel, sModel);
    }
}

//=============================================================================
// EVENTS
//=============================================================================

void ePlayerSpawn(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || iClient > MaxClients)
		return;

	if(!IsClientInGame(iClient) || IsFakeClient(iClient) || !IsPlayerAlive(iClient))
		return;

	LMC_ResetRenderMode(iClient);

	// Reset arms on spawn, will be re-applied by ModelIndex if needed
	ResetArmsModel(iClient);

	if(g_bAdminOnly && !CheckCommandAccess(iClient, "sm_lmc", COMMAND_ACCESS))
		return;

	switch(GetClientTeam(iClient))
	{
		case 3:
		{
			switch(GetEntProp(iClient, Prop_Send, "m_zombieClass"))
			{
				case ZOMBIECLASS_SMOKER:
				{
					if(!g_bAllowSmoker)
						return;
				}
				case ZOMBIECLASS_BOOMER:
				{
					if(!g_bAllowBoomer)
						return;
				}
				case ZOMBIECLASS_HUNTER:
				{
					if(!g_bAllowHunter)
						return;
				}
				case ZOMBIECLASS_CHARGER, ZOMBIECLASS_JOCKEY, ZOMBIECLASS_SPITTER, ZOMBIECLASS_UNKNOWN:
				{
					return;
				}
				case ZOMBIECLASS_TANK:
				{
					if(!g_bAllowTank)
						return;
				}
				default:
				{
					return;
				}
			}
		}
		case 2:
		{
			if(!g_bAllowSurvivors)
				return;
		}
		default:
		{
			return;
		}
	}

	if(iSavedModel[iClient] < 2)
		return;

	RequestFrame(NextFrame, GetClientUserId(iClient));
}

void ePlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || iClient > MaxClients)
		return;

	// Stop arms timer on death - will restart on next spawn if needed
	ResetArmsModel(iClient);
}

void ePlayerBotReplace(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "player"));
	int iBot = GetClientOfUserId(GetEventInt(hEvent, "bot"));

	if(iBot < 1 || iBot > MaxClients)
		return;

	if(!IsFakeClient(iBot))
		return;

	LMC_ResetRenderMode(iBot);

	if(g_bAdminOnly && !CheckCommandAccess(iBot, "sm_lmc", COMMAND_ACCESS))
		return;

	switch(GetClientTeam(iBot))
	{
		case 3:
		{
			switch(GetEntProp(iBot, Prop_Send, "m_zombieClass"))
			{
				case ZOMBIECLASS_SMOKER:
				{
					if(!g_bAllowSmoker)
						return;
				}
				case ZOMBIECLASS_BOOMER:
				{
					if(!g_bAllowBoomer)
						return;
				}
				case ZOMBIECLASS_HUNTER:
				{
					if(!g_bAllowHunter)
						return;
				}
				case ZOMBIECLASS_CHARGER, ZOMBIECLASS_JOCKEY, ZOMBIECLASS_SPITTER, ZOMBIECLASS_UNKNOWN:
				{
					return;
				}
				case ZOMBIECLASS_TANK:
				{
					if(!g_bAllowTank)
						return;
				}
				default:
				{
					return;
				}
			}
		}
		case 2:
		{
			if(!g_bAllowSurvivors)
				return;
		}
		default:
		{
			return;
		}
	}

	iSavedModel[iBot] = iSavedModel[iClient];

	if(iSavedModel[iBot] < 2)
		return;

	RequestFrame(NextFrame, GetClientUserId(iBot));
}

void NextFrame(int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if(iClient < 1 || !IsClientInGame(iClient))
		return;

	ModelIndex(iClient, iSavedModel[iClient], false);
}

//=============================================================================
// MENU
//=============================================================================

Action ShowMenuCmd(int iClient, int iArgs)
{
	iCurrentPage[iClient] = 0;
	ShowMenu(iClient);

	return Plugin_Handled;
}

void ShowMenu(int iClient)
{
	if(iClient == 0 || !IsClientInGame(iClient))
	{
		ReplyToCommand(iClient, LMC_Translate(iClient, "%t", "In-game only"));
		return;
	}
	if(g_bAdminOnly && !CheckCommandAccess(iClient, "sm_lmc", COMMAND_ACCESS))
	{
		LMC_CPrintToChat(iClient, "%t", "Admin only");
		return;
	}
	if(!IsPlayerAlive(iClient) && bAutoBlockedMsg[iClient][8])
	{
		LMC_CPrintToChat(iClient, "%t", "Alive only");
		bAutoBlockedMsg[iClient][8] = false;
	}
	Handle hMenu = CreateMenu(CharMenu);
	SetMenuTitle(hMenu, LMC_Translate(iClient, "%t", "Lux's Model Changer"));

	AddMenuItem(hMenu, "1", LMC_Translate(iClient, "%t", "Normal Models"), iSavedModel[iClient] == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(hMenu, "2", LMC_Translate(iClient, "%t", "Random Common"));
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Witch]))
		AddMenuItem(hMenu, "3", LMC_Translate(iClient, "%t", "Witch"), iSavedModel[iClient] == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_WitchBride]))
		AddMenuItem(hMenu, "4", LMC_Translate(iClient, "%t", "Witch Bride"), iSavedModel[iClient] == 4 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Boomer]))
		AddMenuItem(hMenu, "5", LMC_Translate(iClient, "%t", "Boomer"), iSavedModel[iClient] == 5 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Boomette]))
		AddMenuItem(hMenu, "6", LMC_Translate(iClient, "%t", "Boomette"), iSavedModel[iClient] == 6 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Hunter]))
		AddMenuItem(hMenu, "7", LMC_Translate(iClient, "%t", "Hunter"), iSavedModel[iClient] == 7 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Smoker]))
		AddMenuItem(hMenu, "8", LMC_Translate(iClient, "%t", "Smoker"), iSavedModel[iClient] == 8 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_RiotCop]))
		AddMenuItem(hMenu, "9", LMC_Translate(iClient, "%t", "Riot Cop"), iSavedModel[iClient] == 9 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_MudMan]))
		AddMenuItem(hMenu, "10", LMC_Translate(iClient, "%t", "MudMan"), iSavedModel[iClient] == 10 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Pilot]))
		AddMenuItem(hMenu, "11", LMC_Translate(iClient, "%t", "Chopper Pilot"), iSavedModel[iClient] == 11 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_Ceda]))
		AddMenuItem(hMenu, "12", LMC_Translate(iClient, "%t", "CEDA"), iSavedModel[iClient] == 12 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_Clown]))
		AddMenuItem(hMenu, "13", LMC_Translate(iClient, "%t", "Clown"), iSavedModel[iClient] == 13 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_Jimmy]))
		AddMenuItem(hMenu, "14", LMC_Translate(iClient, "%t", "Jimmy Gibs"), iSavedModel[iClient] == 14 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sUnCommonPaths[LMCUnCommonModelType_Fallen]))
		AddMenuItem(hMenu, "15", LMC_Translate(iClient, "%t", "Fallen Survivor"), iSavedModel[iClient] == 15 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Nick]))
		AddMenuItem(hMenu, "16", LMC_Translate(iClient, "%t", "Nick"), iSavedModel[iClient] == 16 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Rochelle]))
		AddMenuItem(hMenu, "17", LMC_Translate(iClient, "%t", "Rochelle"), iSavedModel[iClient] == 17 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Coach]))
		AddMenuItem(hMenu, "18", LMC_Translate(iClient, "%t", "Coach"), iSavedModel[iClient] == 18 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Ellis]))
		AddMenuItem(hMenu, "19", LMC_Translate(iClient, "%t", "Ellis"), iSavedModel[iClient] == 19 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Bill]))
		AddMenuItem(hMenu, "20", LMC_Translate(iClient, "%t", "Bill"), iSavedModel[iClient] == 20 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Zoey]))
		AddMenuItem(hMenu, "21", LMC_Translate(iClient, "%t", "Zoey"), iSavedModel[iClient] == 21 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Francis]))
		AddMenuItem(hMenu, "22", LMC_Translate(iClient, "%t", "Francis"), iSavedModel[iClient] == 22 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if(IsModelPrecached(sHumanPaths[LMCHumanModelType_Louis]))
		AddMenuItem(hMenu, "23", LMC_Translate(iClient, "%t", "Louis"), iSavedModel[iClient] == 23 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	if(g_bTankModel)
	{
		if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_Tank]))
			AddMenuItem(hMenu, "24", LMC_Translate(iClient, "%t", "Tank"), iSavedModel[iClient] == 24 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		if(IsModelPrecached(sSpecialPaths[LMCSpecialModelType_TankDLC3]))
			AddMenuItem(hMenu, "25", LMC_Translate(iClient, "%t", "Tank DLC"), iSavedModel[iClient] == 25 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	SetMenuExitButton(hMenu, true);

	DisplayMenuAtItem(hMenu, iClient, iCurrentPage[iClient], 15);
}

int CharMenu(Handle hMenu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[4];
			GetMenuItem(hMenu, param2, sItem, sizeof(sItem));
			ModelIndex(param1, StringToInt(sItem), true);
			iCurrentPage[param1] = GetMenuSelectionPosition();
			ShowMenu(param1);
		}
		case MenuAction_Cancel:
		{
			iCurrentPage[param1] = 0;
		}
		case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}

	return 0;
}

//=============================================================================
// MODEL INDEX - core model assignment logic
//=============================================================================

void ModelIndex(int iClient, int iCaseNum, bool bUsingMenu=false)
{
	if(AreClientCookiesCached(iClient) && bUsingMenu)
	{
		char sCookie[3];
		IntToString(iCaseNum, sCookie, sizeof(sCookie));
		SetClientCookie(iClient, hCookie_LmcCookie, sCookie);
	}
	iSavedModel[iClient] = iCaseNum;

	if(!IsPlayerAlive(iClient))
		return;

	switch(GetClientTeam(iClient))
	{
		case 3:
		{
			switch(GetEntProp(iClient, Prop_Send, "m_zombieClass"))
			{
				case ZOMBIECLASS_SMOKER:
				{
					if(!g_bAllowSmoker)
					{
						if(!bUsingMenu && !bAutoBlockedMsg[iClient][0])
							return;
						LMC_CPrintToChat(iClient, "%t", "Disabled_Models_Smoker");
						bAutoBlockedMsg[iClient][0] = false;
						return;
					}
				}
				case ZOMBIECLASS_BOOMER:
				{
					if(!g_bAllowBoomer)
					{
						if(!bUsingMenu && !bAutoBlockedMsg[iClient][1])
							return;
						LMC_CPrintToChat(iClient, "%t", "Disabled_Models_Boomer");
						bAutoBlockedMsg[iClient][1] = false;
						return;
					}
				}
				case ZOMBIECLASS_HUNTER:
				{
					if(!g_bAllowHunter)
					{
						if(!bUsingMenu && !bAutoBlockedMsg[iClient][2])
							return;
						LMC_CPrintToChat(iClient, "%t", "Disabled_Models_Hunter");
						bAutoBlockedMsg[iClient][2] = false;
						return;
					}
				}
				case ZOMBIECLASS_SPITTER:
				{
					if(!bUsingMenu && !bAutoBlockedMsg[iClient][3])
						return;
					LMC_CPrintToChat(iClient, "%t", "Unsupported_Spitter");
					bAutoBlockedMsg[iClient][3] = false;
					return;
				}
				case ZOMBIECLASS_JOCKEY:
				{
					if(!bUsingMenu && !bAutoBlockedMsg[iClient][4])
						return;
					LMC_CPrintToChat(iClient, "%t", "Unsupported_Jockey");
					bAutoBlockedMsg[iClient][4] = false;
					return;
				}
				case ZOMBIECLASS_CHARGER:
				{
					if(IsFakeClient(iClient))
						return;
					if(!bUsingMenu && !bAutoBlockedMsg[iClient][5])
						return;
					LMC_CPrintToChat(iClient, "%t", "Unsupported_Charger");
					bAutoBlockedMsg[iClient][5] = false;
					return;
				}
				case ZOMBIECLASS_TANK:
				{
					if(!g_bAllowTank)
					{
						if(!bUsingMenu && !bAutoBlockedMsg[iClient][6])
							return;
						LMC_CPrintToChat(iClient, "%t", "Disabled_Models_Tank");
						bAutoBlockedMsg[iClient][6] = false;
						return;
					}
				}
			}
		}
		case 2:
		{
			if(!g_bAllowSurvivors)
			{
				if(!bUsingMenu && !bAutoBlockedMsg[iClient][7])
					return;
				LMC_CPrintToChat(iClient, "%t", "Disabled_Models_Survivors");
				bAutoBlockedMsg[iClient][7] = false;
				return;
			}
		}
		default:
			return;
	}

	//model selection
	switch(iCaseNum)
	{
		case 1:
		{
			ResetDefaultModel(iClient);
			ResetArmsModel(iClient); // Restore default arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Default_Models");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
			return;
		}
		case 2:
		{
			static int iChoice = 0;
			static int iLastValidModel = 0;
			if(!IsModelValid(iClient, LMCModelSectionType_Common, iChoice))
			{
				if(IsModelValid(iClient, LMCModelSectionType_Common, iLastValidModel))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sCommonPaths[iLastValidModel]));
			}
			else
			{
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sCommonPaths[iChoice]));
				iLastValidModel = iChoice;
			}
			if(++iChoice >= COMMON_MODEL_PATH_SIZE)
				iChoice = 0;

			ResetArmsModel(iClient); // Commons have no arms model
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Common");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 3:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Witch)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Witch]));
			ResetArmsModel(iClient); // Witch has no arms model
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Witch");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 4:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_WitchBride)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_WitchBride]));
			ResetArmsModel(iClient); // Witch Bride has no arms model
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Witch_Bride");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 5:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Boomer)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Boomer]));
			ApplyArmsModel(iClient, iCaseNum); // Boomer arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Boomer");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 6:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Boomette)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Boomette]));
			ApplyArmsModel(iClient, iCaseNum); // Boomette uses Boomer arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Boomette");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 7:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Hunter)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Hunter]));
			ApplyArmsModel(iClient, iCaseNum); // Hunter arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Hunter");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 8:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Smoker)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Smoker]));
			ApplyArmsModel(iClient, iCaseNum); // Smoker arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Smoker");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 9:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_RiotCop)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_RiotCop]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_RiotCop");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 10:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_MudMan)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_MudMan]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_MudMen");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 11:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Pilot)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Pilot]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Chopper_Pilot");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 12:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_Ceda)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_Ceda]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_CEDA");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 13:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_Clown)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_Clown]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Clown");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 14:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_Jimmy)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_Jimmy]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Jimmy_Gibs");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 15:
		{
			if(IsModelValid(iClient, LMCModelSectionType_UnCommon, view_as<int>(LMCUnCommonModelType_Fallen)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sUnCommonPaths[LMCUnCommonModelType_Fallen]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Fallen_Survivor");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 16:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Nick)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Nick]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Nick");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 17:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Rochelle)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Rochelle]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Rochelle");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 18:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Coach)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Coach]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Coach");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 19:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Ellis)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Ellis]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Ellis");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 20:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Bill)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Bill]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Bill");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 21:
		{
			if(GetRandomInt(1, 100) >= 50)
			{
				if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Zoey)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Zoey]));
			}
			else
			{
				if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_ZoeyLight)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_ZoeyLight]));
				else if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Zoey)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Zoey]));
			}
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Zoey");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 22:
		{
			if(GetRandomInt(1, 100) >= 50)
			{
				if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Francis)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Francis]));
			}
			else
			{
				if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_FrancisLight)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_FrancisLight]));
				else if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Francis)))
					LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Francis]));
			}
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Francis");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 23:
		{
			if(IsModelValid(iClient, LMCModelSectionType_Human, view_as<int>(LMCHumanModelType_Louis)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sHumanPaths[LMCHumanModelType_Louis]));
			ResetArmsModel(iClient);
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Louis");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 24:
		{
			if(!g_bTankModel)
				return;
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_Tank)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_Tank]));
			ApplyArmsModel(iClient, iCaseNum); // Tank arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Tank");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
		case 25:
		{
			if(!g_bTankModel)
				return;
			if(IsModelValid(iClient, LMCModelSectionType_Special, view_as<int>(LMCSpecialModelType_TankDLC3)))
				LMC_L4D2_SetTransmit(iClient, LMC_SetClientOverlayModel(iClient, sSpecialPaths[LMCSpecialModelType_TankDLC3]));
			ApplyArmsModel(iClient, iCaseNum); // Tank DLC arms
			if(!bUsingMenu && !bAutoApplyMsg[iClient])
				return;
			LMC_CPrintToChat(iClient, "%t", "Model_Tank_DLC");
			SetExternalView(iClient);
			bAutoApplyMsg[iClient] = false;
		}
	}
	bAutoApplyMsg[iClient] = false;
}

//=============================================================================
// CLIENT CONNECT / DISCONNECT
//=============================================================================

public void OnClientPostAdminCheck(int iClient)
{
	if(IsFakeClient(iClient))
		return;

	if(g_iAnnounceMode != 0 && !g_bAdminOnly)
		CreateTimer(g_fAnnounceDelay, iClientInfo, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action iClientInfo(Handle hTimer, any iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return Plugin_Stop;

	switch(g_iAnnounceMode)
	{
		case 1:
		{
			LMC_CPrintToChat(iClient, "%t", "Change_Model_Help_Chat");
			EmitSoundToClient(iClient, sJoinSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
		}
		case 2: PrintHintText(iClient, "%s", LMC_TranslateNoColor(iClient, "%t", "Change_Model_Help_Chat"));
		case 3:
		{
			int iEntity = CreateEntityByName("env_instructor_hint");
			if(iEntity < 1)
				return Plugin_Stop;

			char sValues[64];
			FormatEx(sValues, sizeof(sValues), "hint%d", iClient);
			DispatchKeyValue(iClient, "targetname", sValues);
			DispatchKeyValue(iEntity, "hint_target", sValues);
			Format(sValues, sizeof(sValues), "10");
			DispatchKeyValue(iEntity, "hint_timeout", sValues);
			DispatchKeyValue(iEntity, "hint_range", "100");
			DispatchKeyValue(iEntity, "hint_icon_onscreen", "icon_tip");
			DispatchKeyValue(iEntity, "hint_caption", LMC_TranslateNoColor(iClient, "%t", "Change_Model_Help_Chat"));
			Format(sValues, sizeof(sValues), "%i %i %i", GetRandomInt(1, 255), GetRandomInt(100, 255), GetRandomInt(1, 255));
			DispatchKeyValue(iEntity, "hint_color", sValues);
			DispatchSpawn(iEntity);
			AcceptEntityInput(iEntity, "ShowHint", iClient);
			SetVariantString("OnUser1 !self:Kill::6:1");
			AcceptEntityInput(iEntity, "AddOutput");
			AcceptEntityInput(iEntity, "FireUser1");
		}
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sCookie[3];
		IntToString(iSavedModel[iClient], sCookie, sizeof(sCookie));
		SetClientCookie(iClient, hCookie_LmcCookie, sCookie);
	}

	// Cleanup arms timer
	StopArmsTimer(iClient);
	sClientArmsModel[iClient][0] = '\0';

	iCurrentPage[iClient] = 0;
	bAutoApplyMsg[iClient] = true;
	for(int i = 0; i < sizeof(bAutoBlockedMsg[]); i++)
		bAutoBlockedMsg[iClient][i] = true;

	iSavedModel[iClient] = 0;
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[3];
	GetClientCookie(iClient, hCookie_LmcCookie, sCookie, sizeof(sCookie));
	if(StrEqual(sCookie, "\0", false))
		return;

	iSavedModel[iClient] = StringToInt(sCookie);

	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;

	if(g_bAdminOnly && !CheckCommandAccess(iClient, "sm_lmc", COMMAND_ACCESS))
		return;

	ModelIndex(iClient, iSavedModel[iClient], false);
}

public void LMC_OnClientModelApplied(int iClient, int iEntity, const char sModel[PLATFORM_MAX_PATH], bool bBaseReattach)
{
	if(bBaseReattach)
		LMC_L4D2_SetTransmit(iClient, iEntity);
}

//=============================================================================
// THIRD PERSON VIEW
//=============================================================================

void SetExternalView(int iClient)
{
	if(g_fThirdPersonTime < 0.5)
		return;

	float fCurrentTPtime = GetForcedThirdPerson(iClient);
	float fTime = GetGameTime();
	if(fCurrentTPtime > (fTime + g_fThirdPersonTime))
		return;

	if(fCurrentTPtime < fTime + 0.5)
		if(fCurrentTPtime > fTime - 1.0)
			return;

	SetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView", fTime + g_fThirdPersonTime);
}

float GetForcedThirdPerson(int iClient)
{
	return GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView");
}

//=============================================================================
// MODEL VALIDATION
//=============================================================================

bool IsModelValid(int iClient, LMCModelSectionType iModelSectionType, int iModelIndex)
{
	char sCurrentModel[PLATFORM_MAX_PATH];
	GetClientModel(iClient, sCurrentModel, sizeof(sCurrentModel));

	switch(iModelSectionType)
	{
		case LMCModelSectionType_Human:
		{
			bool bSameModel = StrEqual(sCurrentModel, sHumanPaths[iModelIndex], false);
			if(!bSameModel && IsModelPrecached(sHumanPaths[iModelIndex]))
				return true;
			if(bSameModel)
				ResetDefaultModel(iClient);
			return false;
		}
		case LMCModelSectionType_Special:
		{
			bool bSameModel = StrEqual(sCurrentModel, sSpecialPaths[iModelIndex], false);
			if(!bSameModel && IsModelPrecached(sSpecialPaths[iModelIndex]))
				return true;
			if(bSameModel)
				ResetDefaultModel(iClient);
			return false;
		}
		case LMCModelSectionType_UnCommon:
		{
			bool bSameModel = StrEqual(sCurrentModel, sUnCommonPaths[iModelIndex], false);
			if(!bSameModel && IsModelPrecached(sUnCommonPaths[iModelIndex]))
				return true;
			if(bSameModel)
				ResetDefaultModel(iClient);
			return false;
		}
		case LMCModelSectionType_Common:
		{
			bool bSameModel = StrEqual(sCurrentModel, sCommonPaths[iModelIndex], false);
			if(!bSameModel && IsModelPrecached(sCommonPaths[iModelIndex]))
				return true;
			if(bSameModel)
				ResetDefaultModel(iClient);
			return false;
		}
	}
	ResetDefaultModel(iClient);
	return false;
}

void ResetDefaultModel(int iClient)
{
	int iOverlayModel = LMC_GetClientOverlayModel(iClient);
	if(iOverlayModel > -1)
		AcceptEntityInput(iOverlayModel, "kill");

	LMC_ResetRenderMode(iClient);
}
