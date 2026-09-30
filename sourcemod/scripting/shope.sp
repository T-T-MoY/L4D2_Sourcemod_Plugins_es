#define PLUGIN_VERSION "1.19"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <clientprefs>
#include <geoip>

#undef REQUIRE_PLUGIN
#tryinclude <special_ammo>
#tryinclude <autorespawn>
#tryinclude <hx_stats>

#define CVAR_FLAGS FCVAR_NONE
#define SURVIVORTEAM 2
#define INFECTEDTEAM 3

#define DEBUG 0

/*
	name = "[L4D] Points and Gift System",
	author = "(-DR-)GrammerNatzi",
	description = "This plug-in allows clients to gain points through various accomplishments and use them to buy items and health/ammo refills. It also allows admins to gift the same things to players and grant them god mode. Both use menus, no less.",

	VERSION HISTORY:

	1.19 (fork)
	- Disabled witch points when witch begin to hunt

	1.18 (fork)
	- Fixed possible zeroing of Points - added bool flag whether points is loaded. Zero points is now converted to -1 when saved.
	- Added logging of saved points to "logs/shop_points.log"
	- "logs/shop.log" is renamed to "logs/shop_transfer.log"
	- Removed "pointsconfirm" command.
	- Made most command access by ADMIN_ROOT only.
	- sm_savepoints is now accessible to admin only.
	- Added save points on plugin unload.
	
	1.17 (fork)
	- Added Witcher Shove upgrade
	- Added Shield upgrade

	1.16 (fork)
	- Added integration with hx_stats

	1.15 (fork)
	- Added "Hot butt", "Crash butt"

	1.14 (fork)
	- Added Resurrection.
	
	1.13 (fork)
	- Added native of earned money (for statistics plugin)

	1.12 (fork)
	- special ammo are replaced by 3 special ammo from AtomicStryker's plugin
	- logging of money transfer operations
	- disabled some hooks in non-versus mode.

	1.11 (fork)
	- added donation info in "bank operations"

	1.10 (fork)
	- removed points for tank kill and tank burning
	- added points for deal damage to tank and 1-3 places bonus for damage dealers.
	- added "back" button that redirects to sm_menu

	1.9 (fork)
	- Some fixes on client's cookie loading/saving (some clients expirienced random reset of coins).
	- Added new events for points
	- Added logging the count of coins on client disconnect to logs/shop.log file
	
	1.8 (fork)
	- Converted to a new syntax and methodmaps
	
	1.7 (fork)
	- Menu is now not closed when you bye something
	
	1.6 (fork)
	- PLAYERS replaced by MAXPLAYERS.
	- for loops max indeces replaced by MaxClients.
	- fixed cache saving/loading

	1.5 (fork)
	- Added coins cache (saving) on client restart

	1.4 (fork)
	- added "Bank operations" menu
	- added "transfer coins"

 	1.3 (fork)
	- menu has been reorganized into 4 branches
	- added propane tank, oxygen tank and gascan
	- added simple opportunity to change position of menu items
	
*/

public Plugin myinfo = 
{
	name = "[L4D] Shop",
	author = "(-DR-) & Dragokas",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
}

#define 	TEAM_SURVIVORS 		2
#define 	TEAM_INFECTED 		3

int TransferTo[MAXPLAYERS + 1];
int godon[MAXPLAYERS + 1];
int points[MAXPLAYERS + 1];
int pointskillcount[MAXPLAYERS + 1];
int pointsteam[MAXPLAYERS + 1];
int g_iShoveCount[MAXPLAYERS+1];
int numtanks;
int numwitches;
//int tankonfire[MAXPLAYERS + 1];
int buyitem[MAXPLAYERS + 1];
int pointsremindtimer;
int pointstimer;
bool pointson;
bool g_bVersus;
bool g_bPointsLoaded[MAXPLAYERS+1];
int numrounds;
int g_iMoneyEarned[MAXPLAYERS+1]; // in this round
float g_fBlackFridayPrice = 0.2; // 80 %

ConVar pointsoncvar;
ConVar pointsminplayers;
ConVar pointsinfected;
ConVar pointsspecial;
ConVar pointsheal;
ConVar pointsrevive;
ConVar pointsrescue;
ConVar pointsrescuecpr;
ConVar pointsrescuemedkitcpr;
ConVar pointsadvertising;
ConVar pointswitchinsta;
ConVar pointswitch;
//ConVar pointstankburn;
//ConVar pointstankkill;
ConVar pointshurt;
ConVar pointsminigun;
ConVar pointsheadshot;
ConVar pointsinfectednum;
ConVar pointsgrab;
ConVar pointspounce;
ConVar pointsincapacitate;
ConVar pointsvomit;
int pointshurtcount[MAXPLAYERS + 1];
ConVar pointsadvertisingticks;
ConVar pointsresetround;
ConVar pointsresetrounds;

/*Item-Related Convars*/
ConVar tanklimit;
ConVar witchlimit;

/*Price Convars*/
ConVar shotpoints;
ConVar smgpoints;
ConVar riflepoints;
ConVar autopoints;
ConVar huntingpoints;
ConVar pipepoints;
ConVar molopoints;
ConVar oxygentankpoints;
ConVar gascanpoints;
ConVar propanetankpoints;
ConVar pillspoints;
ConVar medpoints;
ConVar pistolpoints;
ConVar refillpoints;
ConVar healpoints;
ConVar tankhppoints;
ConVar tankhpfirstpoints;
ConVar tankhpsecondpoints;
ConVar tankhpthirdpoints;
ConVar respawnpoints;
ConVar witchershovepoints;
ConVar shieldpoints;

/*Price for hx_stat*/
ConVar ptstat_rescuemedkitcpr;
ConVar ptstat_rescuecpr;
ConVar ptstat_rescue;

/*Infected Price Convars*/
ConVar suicidepoints;
ConVar ihealpoints;
ConVar boomerpoints;
ConVar hunterpoints;
ConVar smokerpoints;
ConVar tankpoints;
ConVar wwitchpoints;
ConVar panicpoints;
ConVar mobpoints;

/*Special Price Convars*/
ConVar incendpoints;
ConVar burstpoints;
ConVar piersingpoints;

ConVar g_CvarGameMode;
ConVar g_ConVarDifficulty;

Handle hCookie_Shop = INVALID_HANDLE;

bool g_bLate;
bool g_bMinPlayers;
bool g_bSpecialAmmoLib;
bool g_bAutorespawnLib;
bool g_bHxstatsLib;

bool g_bLeft4Dead2;
bool g_bBlackFriday;
bool g_bMapTransition;
bool g_bInDisconnect[MAXPLAYERS+1];

char g_sLogTransfer[PLATFORM_MAX_PATH];
char g_sLogPoints[PLATFORM_MAX_PATH];
char g_sLogShop[PLATFORM_MAX_PATH];

char g_sSteamId[MAXPLAYERS+1][32];
char g_sQuery1[512];
char g_sQuery2[512];

Database g_hDB;

float g_fLastTime[MAXPLAYERS+1];
int g_iBuyPerMinute[MAXPLAYERS+1];

float fOxygenLastTime[MAXPLAYERS+1];
int g_iOxygenPerMinute[MAXPLAYERS+1];

float fPropaneLastTime[MAXPLAYERS+1];
int g_iPropanePerMinute[MAXPLAYERS+1];

int g_iPistolPerMap[MAXPLAYERS+1];
int g_iAutoshotgunPerMap[MAXPLAYERS+1];
int g_iM16PerMap[MAXPLAYERS+1];
int g_iSniperPerMap[MAXPLAYERS+1];
int g_iShotgunPerMap[MAXPLAYERS+1];
int g_iUziPerMap[MAXPLAYERS+1];
int g_iPillsPerMap[MAXPLAYERS+1];
int g_iMedkitPerMap[MAXPLAYERS+1];
int g_iPipePerMap[MAXPLAYERS+1];
int g_iMolotovPerMap[MAXPLAYERS+1];
int g_iPropanePerMap[MAXPLAYERS+1];
int g_iOxygenPerMap[MAXPLAYERS+1];
int g_iPetrolPerMap[MAXPLAYERS+1];

const int MAX_PISTOL_PER_MAP = 10;
const int MAX_AUTOSHOTGUN_PER_MAP = 10;
const int MAX_M16_PER_MAP = 10;
const int MAX_SNIPER_PER_MAP = 10;
const int MAX_SHOTGUN_PER_MAP = 10;
const int MAX_UZI_PER_MAP = 10;
const int MAX_PILLS_PER_MAP = 10;
const int MAX_MEDKIT_PER_MAP = 10;
const int MAX_PIPE_PER_MAP = 30;
const int MAX_MOLOTOV_PER_MAP = 30;
const int MAX_PROPANE_PER_MAP = 5;
const int MAX_OXYGEN_PER_MAP = 7;
const int MAX_PETROL_PER_MAP = 10;

const int MAX_ITEMS_PER_MINUTE = 10;

const int MAX_PROPANE_PER_MINUTE = 2;
const int MAX_OXYGEN_PER_MINUTE = 2;

#define SHOP_TABLE "l4d_shop"
#define SHOP_DATABASE_CFG "l4d_shop"

#define SHOP_CREATE_TABLE "\
CREATE TABLE IF NOT EXISTS `"...SHOP_TABLE..."` (\
 `Steamid` varchar(32) NOT NULL DEFAULT '',\
 `Coins` int(11) NOT NULL DEFAULT '0',\
 `Name` tinyblob NOT NULL,\
 `Time` int(11) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`Steamid`)\
) ENGINE=InnoDB DEFAULT CHARSET=utf8;\
"

// ALTER TABLE `l4d_shop` ENGINE = InnoDB;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead) {
		//g_bLeft4Dead1 = true;
	}
	else if (test == Engine_Left4Dead2) {
		g_bLeft4Dead2 = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("GetMoneyEarned", NATIVE_GetMoneyEarned);
	RegPluginLibrary("shope");
	
	g_bLate = late;
	return APLRes_Success;
}

public int NATIVE_GetMoneyEarned(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	
	return g_iMoneyEarned[iClient];
}

public void OnAllPluginsLoaded()
{
	g_bSpecialAmmoLib = LibraryExists("special_ammo");
	g_bAutorespawnLib = LibraryExists("autorespawn");
	g_bHxstatsLib = LibraryExists("hx_stats");
	#if !defined _hxstats_included
		#pragma unused g_bHxstatsLib
	#endif
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("shope.phrases");
	LoadTranslations("special_ammo.phrases");

	/*Commands*/
	//RegAdminCmd("refill", Refill, ADMFLAG_KICK);
	//RegAdminCmd("heal", Heal, ADMFLAG_KICK);
	//RegConsoleCmd("debugteamid",TeamID);
	//RegConsoleCmd("repeatbuy",RepeatBuy);
	//RegAdminCmd("sm_fakegod",FakeGod, ADMFLAG_KICK);
	
	RegConsoleCmd("points", ShowPoints);
	
	RegConsoleCmd("usepoints", PointsChooseMenu);
	RegConsoleCmd("shop", PointsChooseMenu);
	RegConsoleCmd("sm_bank", PointsChooseMenu);
	RegConsoleCmd("sm_coins", PointsChooseMenu);
	RegConsoleCmd("sm_shop", PointsChooseMenu);
	RegConsoleCmd("sm_buy", PointsChooseMenu);
	RegConsoleCmd("sm_store", PointsChooseMenu);
	
	//RegConsoleCmd("usepointsspecial", PointsSpecialMenu);
	//RegConsoleCmd("pointsmenu",PointsMenu);
	//RegConsoleCmd("pointsmenu2", PointsMenu2);
	//RegConsoleCmd("pointsconfirm", PointsConfirm);
	
	RegAdminCmd("sm_savepoints", SaveAllPoints, ADMFLAG_ROOT);
	
	RegAdminCmd("sm_clientgivepoints",Command_GivePoints,ADMFLAG_ROOT,"sm_clientgivepoints <#userid|name> [number of points]");
	RegAdminCmd("sm_clientsetpoints",Command_SetPoints,ADMFLAG_ROOT,"sm_clientsetpoints <#userid|name> [number of points]");
	
	RegAdminCmd("sm_clientgive", Command_ClientCmd, ADMFLAG_ROOT, "sm_clientgive <#userid|name> [item number] Numbers: 0 - Shotgun, 1 - SMG, 2 - Rifle, 3 - Hunting Rifle, 4 - Auto-shotty, 5 - Pipe Bomb, 6 - Molotov, 7 - Pistol, 8 - Pills, 9 - Medkit, 10 - Ammo, 11 - Health");
	
	// RegAdminCmd("sm_clientgivemenu", GiveItemMenu, ADMFLAG_KICK, "Blah");
	
	//this signals that the plugin is on on this server
	CreateConVar("points_gift_on", PLUGIN_VERSION, "Points_Gift_On", FCVAR_DONTRECORD);
	
	/* Values for Convars*/
	pointsoncvar = CreateConVar("points_on","1","Point system on or off?",CVAR_FLAGS, true, 0.0);
	
	/* Survivor points */
	pointsminplayers = CreateConVar("points_min_players","3","Minimum players to allow earn points.",CVAR_FLAGS, true, 0.0);
	pointsinfected = CreateConVar("points_amount_infected","2","How many points for killing a certain number of infected.",CVAR_FLAGS, true, 0.0);
	pointsinfectednum = CreateConVar("points_amount_infectednum","25","How many killed infected does it take to earn points? Headshot and minigun kills can be used to rank up extra kills.",CVAR_FLAGS,true,0.0);
	pointsspecial = CreateConVar("points_amount_specialinfected","1","How many points for killing a special infected.",CVAR_FLAGS, true, 0.0);
	pointsheal = CreateConVar("points_amount_heal","5","How many points for healing someone.",CVAR_FLAGS, true, 0.0);
	pointsrevive = CreateConVar("points_amount_revive","3","How many points for reviving someone.",CVAR_FLAGS, true, 0.0);
	pointsrescue = CreateConVar("points_amount_rescue","2","How many points for rescuing someone from a closet.",CVAR_FLAGS, true, 0.0);
	pointsrescuecpr = CreateConVar("points_amount_cpr","10","How many points for rescuing someone with cpr.",CVAR_FLAGS, true, 0.0);
	pointsrescuemedkitcpr = CreateConVar("points_amount_cpr_medkit","25","How many points for rescuing someone with cpr + medkit.",CVAR_FLAGS, true, 0.0);
	//pointsonversus = CreateConVar("points_on_versus","0","Point system on or off in versus mode? (DOES NOT WORK YET)",CVAR_FLAGS, true, 0.0);
	pointsadvertising = CreateConVar("points_advertising","1","Do we want the plugin to advertise itself? 1 for short version, 2 for long, 0 for none.",CVAR_FLAGS, true, 0.0);
	pointswitch = CreateConVar("points_amount_witch","5","How many points you get for killing a witch.",CVAR_FLAGS,true,0.0);
	pointswitchinsta = CreateConVar("points_amount_witch_instakill","3","How many extra points you get for killing a witch in one shot.",CVAR_FLAGS,true,0.0);
	//pointstankburn = CreateConVar("points_amount_tank_burn","2","How many points you get for burning a tank.",CVAR_FLAGS,true,0.0);
	//pointstankkill = CreateConVar("points_amount_tank","2","How many additional points you get for killing a tank.",CVAR_FLAGS,true,0.0);
	
	ptstat_rescuemedkitcpr = CreateConVar("ptstat_amount_cpr_medkit","5","How many stat points for rescuing someone with cpr + medkit.",CVAR_FLAGS, true, 0.0);
	ptstat_rescuecpr = CreateConVar("ptstat_amount_cpr","5","How many stat points for rescuing someone with cpr.",CVAR_FLAGS, true, 0.0);
	ptstat_rescue = CreateConVar("ptstat_rescue","1","How many stat points for rescuing someone from a closet.",CVAR_FLAGS, true, 0.0);
	
	/* Minigun */
	pointsheadshot = CreateConVar("points_amount_extra_headshotkills","1","How many extra kills are survivors awarded for scoring headshots? 0 = None.",CVAR_FLAGS,true, 0.0);
	pointsminigun = CreateConVar("points_amount_extra_minigunkills","1","How many extra kills are survivors awarded for scoring minigun kills? 0 = None.",CVAR_FLAGS,true, 0.0);
	
	/* Infected points */
	pointshurt = CreateConVar("points_amount_infected_hurt","2","How many points infected get for hurting survivors a number of times.",CVAR_FLAGS,true,0.0);
	pointsincapacitate = CreateConVar("points_amount_infected_incapacitation","5","How many points you get for incapacitating a survivor",CVAR_FLAGS,true,0.0);
	//pointsvson = CreateConVar("points_on_infected","1","Do infected in versus get points or not?",CVAR_FLAGS,true,0.0);
	pointsgrab = CreateConVar("points_amount_infected_pull","1","How many points you get [as a smoker] when you pull a survivor.",CVAR_FLAGS,true,0.0);
	pointspounce = CreateConVar("points_amount_infected_pounce","1","How many points you get [as a hunter] when you pounce a survivor.",CVAR_FLAGS,true,0.0);
	pointsvomit = CreateConVar("points_amount_infected_vomit","1","How many points you get [as a boomer] when you vomit/explode on a survivor.",CVAR_FLAGS,true,0.0);
	
	pointsadvertisingticks = CreateConVar("points_advertising_ticks","80","How many seconds before the optional advertisement is displayed again.",CVAR_FLAGS,true,0.0);
	
	//pointsreset = CreateConVar("points_reset","0","Reset points on map load?",CVAR_FLAGS, true, 0.0);
	pointsresetround = CreateConVar("points_reset_round","0","Reset points when a certain amount of rounds end? Resets at end of campaign in coop, a defined amount rounds in versus, and every round in survival.",CVAR_FLAGS, true, 0.0);
	pointsresetrounds = CreateConVar("points_reset_round_amount","2","How many rounds until reset in versus?",CVAR_FLAGS, true, 0.0);
	
	tankhppoints = CreateConVar("points_price_tank_hp","1","How many points each 1000 hp of killed tank costs.",CVAR_FLAGS, true, -1.0);
	tankhpfirstpoints = CreateConVar("points_price_tank_hp_first","10","How many points take first tank damage dealer.",CVAR_FLAGS, true, -1.0);
	tankhpsecondpoints = CreateConVar("points_price_tank_hp_second","5","How many points take second tank damage dealer.",CVAR_FLAGS, true, -1.0);
	tankhpthirdpoints = CreateConVar("points_price_tank_hp_third","3","How many points take third tank damage dealer.",CVAR_FLAGS, true, -1.0);
	
	/*Price Convars*/
	shotpoints = CreateConVar("points_price_shotgun","20","How many points a shotgun costs.",CVAR_FLAGS, true, -1.0);
	smgpoints = CreateConVar("points_price_smg","15","How many points a sub-machine gun costs.",CVAR_FLAGS, true, -1.0);
	riflepoints = CreateConVar("points_price_rifle","30","How many points a rifle costs.",CVAR_FLAGS, true, -1.0);
	huntingpoints = CreateConVar("points_price_huntingrifle","30","How many points a hunting rifle costs.",CVAR_FLAGS, true, -1.0);
	autopoints = CreateConVar("points_price_autoshotgun","25","How many points an auto-shotgun costs.",CVAR_FLAGS, true, -1.0);
	pipepoints = CreateConVar("points_price_pipebomb","25","How many points a pipe-bomb costs.",CVAR_FLAGS, true, -1.0);
	molopoints = CreateConVar("points_price_molotov","25","How many points a molotov costs.",CVAR_FLAGS, true, -1.0);
	pistolpoints = CreateConVar("points_price_pistol","5","How many points an extra pistol costs.",CVAR_FLAGS, true, -1.0);
	pillspoints = CreateConVar("points_price_painpills","50","How many points a bottle of pills costs.",CVAR_FLAGS, true, -1.0);
	medpoints = CreateConVar("points_price_medkit","50","How many points a medkit costs.",CVAR_FLAGS, true, -1.0);
	refillpoints = CreateConVar("points_price_refill","20","How many points an ammo refill costs.",CVAR_FLAGS, true, -1.0);
	healpoints = CreateConVar("points_price_heal","60","How many points a heal costs.",CVAR_FLAGS, true, -1.0);
	respawnpoints = CreateConVar("points_price_respawn","200","How many points a resurrection costs.",CVAR_FLAGS, true, -1.0);
	witchershovepoints = CreateConVar("points_price_witchershove","50","How many points a witcher shove costs.",CVAR_FLAGS, true, -1.0);
	shieldpoints = CreateConVar("points_price_shield","50","How many points a shield costs.",CVAR_FLAGS, true, -1.0);

	oxygentankpoints = CreateConVar("points_price_oxygentank","5","How many points an oxygentank costs.",CVAR_FLAGS, true, -1.0);
	gascanpoints = CreateConVar("points_price_gascan","10","How many points a gascan costs.",CVAR_FLAGS, true, -1.0);
	propanetankpoints = CreateConVar("points_price_propanetank","15","How many points a propanetank costs.",CVAR_FLAGS, true, -1.0);
	
	/*Special Price Convars*/
	incendpoints = CreateConVar("points_price_incendiary_ammo","40","How many points does incendiary ammo cost?",CVAR_FLAGS,true,-1.0);
	burstpoints = CreateConVar("points_price_bursting_ammo","60","How many points does bursting ammo cost?",CVAR_FLAGS,true,-1.0);
	piersingpoints = CreateConVar("points_price_piercing_ammo","50","How many points does armor piersing ammo cost?",CVAR_FLAGS,true,-1.0);
	
	/*Infected Price Convars*/
	suicidepoints = CreateConVar("points_price_infected_suicide","4","How many points it takes to end it all.",CVAR_FLAGS, true, -1.0);
	ihealpoints = CreateConVar("points_price_infected_heal","5","How many points a heal costs (for infected).",CVAR_FLAGS, true, -1.0);
	boomerpoints = CreateConVar("points_price_infected_boomer","10","How many points a boomer costs.",CVAR_FLAGS, true, -1.0);
	hunterpoints = CreateConVar("points_price_infected_hunter","5","How many points a hunter costs.",CVAR_FLAGS, true, -1.0);
	smokerpoints = CreateConVar("points_price_infected_smoker","7","How many points a smoker costs.",CVAR_FLAGS, true, -1.0);
	tankpoints = CreateConVar("points_price_infected_tank","35","How many points a tank costs.",CVAR_FLAGS, true, -1.0);
	wwitchpoints = CreateConVar("points_price_infected_witch","25","How many points a witch costs.",CVAR_FLAGS, true, -1.0);
	mobpoints = CreateConVar("points_price_infected_mob","18","How many points a mini-event/mob costs.",CVAR_FLAGS, true, -1.0);
	panicpoints = CreateConVar("points_price_infected_mob_mega","23","How many points a mega mob costs.",CVAR_FLAGS, true, -1.0);
	
	/*Item-Related Convars*/
	tanklimit = CreateConVar("points_limit_tanks","1","How many tanks can be spawned in a round.",CVAR_FLAGS,true,0.0);
	witchlimit = CreateConVar("points_limit_witches","2","How many witches can be spawned in a round.",CVAR_FLAGS,true,0.0);
	
	g_ConVarDifficulty = FindConVar("z_difficulty");
	g_CvarGameMode = FindConVar("mp_gamemode");
	
	char gamemode[25];
	g_CvarGameMode.GetString(gamemode,sizeof(gamemode));
	g_bVersus = (strcmp(gamemode, "versus", false) == 0);
	
	/*Bug Prevention*/
	pointsremindtimer = 1;
	
	if (hCookie_Shop == INVALID_HANDLE)
		hCookie_Shop = RegClientCookie("hspro_shop_coins", "0", CookieAccess_Private);
	
	/*Event Hooks*/
	HookEvent("player_death", InfectedKill);
	
	HookEvent("round_end", 	RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", 		Event_MapTransition, 	EventHookMode_PostNoCopy);
	HookEvent("finale_win", 			Event_MapTransition, 	EventHookMode_PostNoCopy);
	
	//HookEvent("game_newmap", MapLoad);
	HookEvent("rescue_door_open", RescuePoints);
	HookEvent("heal_success", HealPointsEvent);
	//HookEvent("revive_success", RevivePoints);
	HookEvent("infected_death", KillPoints);
	HookEvent("player_team", RefreshTeamPoints);
	HookEvent("witch_killed", WitchPoints);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("entity_shoved", 	  entity_shoved, 	EventHookMode_Post);
	HookEvent("player_shoved", 	  player_shoved, 	EventHookMode_Post);

	//HookEvent("zombie_ignited", TankBurnPoints);
	//HookEvent("tank_killed", TankKill);
	
	if (g_bVersus) {
		HookEvent("player_hurt",HurtPoints);
		HookEvent("player_incapacitated",IncapacitatePoints);
		HookEvent("tongue_grab",GrabPoints);
		HookEvent("lunge_pounce",PouncePoints);
		HookEvent("player_now_it",VomitPoints);
	}
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);	
	
	
	//HookEvent("tank_spawn",TankCheck);
	//CreateTimer(80.0, PointsReminder, _, TIMER_REPEAT);
	
	/* Config Creation*/
	AutoExecConfig(true, "L4DPoints");
	
	BuildPath(Path_SM, g_sLogTransfer, sizeof(g_sLogTransfer), "logs/shop_transfer.log");
	BuildPath(Path_SM, g_sLogPoints, sizeof(g_sLogPoints), "logs/shop_points.log");
	BuildPath(Path_SM, g_sLogShop, sizeof(g_sLogPoints), "logs/shop.log");
		
	/*
	// replaced by database
	if (g_bLate)
		LoadAllPoints(0, 0);
	*/
	
	AddCommandListener(ListenSay, "say");
	AddCommandListener(ListenSay, "say_team");
	
	if (g_bLate)
	{
		g_bMinPlayers = GetSurvivorCount() > pointsminplayers.IntValue;
		
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				pointsteam[i] = GetClientTeam(i);
			}
		}
	}
}

public Action ListenSay(int client, char[] command, int args)
{
	static char message[128];
	GetCmdArgString(message, sizeof(message));
	int pos;
	pos = StrContains(message, "магазин");
	if( pos != -1 && pos <= 2 && strlen(message) < 18 )
	{
		PointsChooseMenu(client, 0);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			OnUserDisconnect(i);
		}
	}
}

public void OnConfigsExecuted()
{
	#if DEBUG
	StringToLog("OnConfigsExecuted. Database: %i", g_hDB);
	#endif

	if (!g_hDB)
	{
		if (SQL_CheckConfig(SHOP_DATABASE_CFG))
		{
			Database.Connect(SQL_Callback_Connect, SHOP_DATABASE_CFG);
		}
	}
}

public Action Timer_SQL_ReConnect(Handle timer)
{
	OnConfigsExecuted();
	return Plugin_Continue;
}

public void SQL_Callback_Connect (Database db, const char[] error, any data)
{
	#if DEBUG
	StringToLog("SQL_Callback_Connect");
	#endif

	//const int MAX_ATTEMPT = 20;
	//static int iAttempt;
	g_hDB = db;
	if (!db)
	{
		/*
		++iAttempt;
		LogError("Attempt #%i. %s", iAttempt, error);
		
		if (iAttempt < MAX_ATTEMPT)
		{
			CreateTimer(3.0, Timer_SQL_ReConnect, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else {
			iAttempt = 0;
		}
		*/
		return;
	}
	SQL_OnConnected();
}

void SQL_OnConnected()
{
	#if DEBUG
	StringToLog("SQL_OnConnected. Late? %b", g_bLate);
	#endif

	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				SQL_RegisterClient(i);
			}
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		g_bInDisconnect[client] = false;
		CreateTimer(0.5, Timer_ClientPost, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ClientPost(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	
	if (client && IsClientInGame(client))
	{
		SQL_RegisterClient(client);
	}
	return Plugin_Continue;
}

void SQL_CreateTable()
{
	if (g_hDB)
	{
		g_hDB.Query(SQL_Callback, SHOP_CREATE_TABLE);
		
		PrintToChatAll("\x01[HXStats] Database table is created. \x04Please, restart the map.");
	}
}

public void SQL_RegisterClient(int client)
{
	#if DEBUG
	StringToLog("SQL_RegisterClient: %i (%N)", client, client);
	#endif

	if (!g_hDB)
		return;
	
	if ( !CacheSteamID(client) )
		return;
	
	FormatEx(g_sQuery1, sizeof(g_sQuery1)
	 , "SELECT \
		Coins \
		FROM `"...SHOP_TABLE..."` WHERE `Steamid` = '%s'", g_sSteamId[client]);
	
	#if DEBUG
	StringToLog("SELECT Coins FROM l4d_shop WHERE `Steamid` = '%s'", g_sSteamId[client]);
	#endif
	
	g_hDB.Query(SQL_Callback_RegisterClient, g_sQuery1, GetClientUserId(client));
}

public void NameProtect(char[] sBuf, int size)
{
	char result[64];
	g_hDB.Escape(sBuf, result, sizeof(result));
	strcopy(sBuf, size, result);
}

public void SQL_Callback_RegisterClient (Database db, DBResultSet hQuery, const char[] error, any data)
{
	if (!hQuery)
	{
		if (StrContains(error, "Table") != -1 && StrContains(error, "doesn't exist") != -1)
		{
			PrintToChatAll(error);
			SQL_CreateTable();
			return;
		}
	}
	if (!db || !hQuery) { LogError(error); return; }
	int client = GetClientOfUserId(data);
	if (!client || !IsClientInGame(client)) return;
	
	if (!hQuery.FetchRow())
	{
		#if DEBUG
		StringToLog("[NEW] Client is not found in db: %i (%N)", client, client);
		#endif
	
		if (LoadPointsCookie(client))
		{
			#if DEBUG
			StringToLog("Cookied loaded for %i (%N). Coins: %i", client, client, points[client]);
			#endif
			
			points[client] = 3000;
		
			FormatEx(g_sQuery1, sizeof(g_sQuery1), "INSERT IGNORE INTO `"...SHOP_TABLE..."` SET `Steamid` = '%s'", g_sSteamId[client]);
			
			static char sName[32];
			GetClientName(client, sName, sizeof(sName));
			NameProtect(sName, sizeof(sName));
			
			FormatEx(g_sQuery2, sizeof(g_sQuery2),
				"UPDATE `"...SHOP_TABLE..."` SET \
				Name = '%s', \
				Coins = %d, \
				Time = %d \
				WHERE `Steamid` = '%s'"
				, sName
				, points[client]
				, GetTime()
				, g_sSteamId[client]);
			
			Transaction tx = new Transaction();
			tx.AddQuery(g_sQuery1);
			tx.AddQuery(g_sQuery2);
			db.Execute(tx, SQL_Tx_SuccessRegister, SQL_Tx_Failure, GetClientUserId(client));
			
			g_bPointsLoaded[client] = true;
		}
		else {
			#if DEBUG
			StringToLog("[FAILED] Cannot load cookies for %i (%N)", client, client);
			#endif
		}
	}
	else
	{
		  points[client] = hQuery.FetchInt(0);
		  g_bPointsLoaded[client] = true;
		  
		  #if DEBUG
		  StringToLog("Client %i (%N) is found. Coins: %i", client, client, points[client]);
		  #endif
	}
}

public void SQL_Tx_SuccessRegister (Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientOfUserId(data);
	if (client && IsClientInGame(client))
	{
		// Remove old version of points save system
		SetClientCookie(client, hCookie_Shop, "-1");
		
		#if DEBUG
		StringToLog("Update db record for %i (%N) is success. Cookies are removed.", client, client);
		#endif
	}
}
public void SQL_Tx_Failure (Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError(error);
}

public Action SaveAllPoints(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SQL_SavePoints(i);
		}
	}
	return Plugin_Handled;
}

void SQL_SavePoints(int client)
{
	if (!g_hDB)
		return;
	
	if (!g_bPointsLoaded[client])
		return;
	
	if ( !CacheSteamID(client) )
		return;
	
	static char sName[32];
	GetClientName(client, sName, sizeof(sName));
	NameProtect(sName, sizeof(sName));
	
	FormatEx(g_sQuery1, sizeof(g_sQuery1),
		"UPDATE `"...SHOP_TABLE..."` SET \
		Name = '%s', \
		Coins = %d, \
		Time = %d \
		WHERE `Steamid` = '%s'"
		, sName
		, points[client]
		, GetTime()
		, g_sSteamId[client]);
	
	g_hDB.Query(SQL_Callback, g_sQuery1);
	
	#if DEBUG
	StringToLog("Saving points for %i (%N)", client, client);
	#endif
}

public void SQL_Callback (Database db, DBResultSet hQuery, const char[] error, any data)
{
	if (!db || !hQuery) { LogError(error); return; }
}

bool LoadPointsCookie(int client)
{
	char sCookie[16];
	if(AreClientCookiesCached(client))
	{
		static char sSteam[64];
		if (GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam)))
		{
			GetClientCookie(client, hCookie_Shop, sCookie, sizeof(sCookie));
			points[client] = StringToInt(sCookie);
			return true;
		}
		else {
			#if DEBUG
			StringToLog("[FAILED] GetClientAuthId for %i (%N)", client, client);
			#endif
		}
	}
	else {
		#if DEBUG
		StringToLog("[FAILED] AreClientCookiesCached for %i (%N)", client, client);
		#endif
	}
	return false;
}

public void Event_RoundStart(Event event, char[] event_name, bool dontBroadcast)
{
	g_bMapTransition = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		g_iMoneyEarned[i] = 0;
	}
}

void AddPoints(int client, int iPoints)
{
	g_iMoneyEarned[client] += iPoints;
	points[client] += iPoints;
}

void AddStatPoints(int client, int iPoints)
{
	#if defined _hxstats_included
	if (g_bHxstatsLib)
	{
		HX_AddPoints(client, iPoints);
		//PrintToChat(client, "\x04hxstats +%i", iPoints);
	}
	#else
		#pragma unused client, iPoints
	#endif
}

public void OnTankKilledHP(int attacker, int target, int hp, int place)
{
	//PrintToChatAll("t - %N, %i, %i", attacker, target, hp);
	static int p, bonus;
	bonus = 0;
	if (pointson) {
		if (hp >= 1000 && IsClientInGame(attacker)) {
			p = hp / 1000 * tankhppoints.IntValue;
			switch(place){
				case 1: bonus = tankhpfirstpoints.IntValue;
				case 2: bonus = tankhpsecondpoints.IntValue;
				case 3: bonus = tankhpthirdpoints.IntValue;
			}
			CPrintToChat(attacker, "\x03%t", "Cutting hp of tank: Coin(s)", hp, p, bonus); // Снятие % жизней у танка: %d Coin(s)
			AddPoints(attacker, p + bonus);
			AddStatPoints(attacker, p + bonus);
		}
	}
}

public void OnClientCPR(int client, int subject, int medkit)
{
	if (medkit) {
		if (pointson && g_bMinPlayers) {
			AddPoints(client, pointsrescuemedkitcpr.IntValue);
			AddStatPoints(client, ptstat_rescuemedkitcpr.IntValue);
			CPrintToChat(client, "\x03%t", "Back to life of teammate with medkit: Coin(s)", pointsrescuemedkitcpr.IntValue); // Возвращение к жизни союзника с помощью аптеки: %d Coin(s)
		}
	}
	else {
		if (pointson && g_bMinPlayers) {
			AddPoints(client, pointsrescuecpr.IntValue);
			AddStatPoints(client, ptstat_rescuecpr.IntValue);
			CPrintToChat(client, "\x03%t", "Back to life of teammate: Coin(s)", pointsrescuecpr.IntValue); // Возвращение к жизни союзника: %d Coin(s)
		}
	}
}

public void RescuePoints(Event event, char[] event_name, bool dontBroadcast)
{
	if (pointson && g_bMinPlayers) {
		int client = GetClientOfUserId(event.GetInt("userid"));
		AddPoints(client, pointsrescue.IntValue);
		AddStatPoints(client, ptstat_rescue.IntValue);
		CPrintToChat(client, "\x03%t", "Allies rescued: Coin(s)", pointsrescue.IntValue); // Спасение из убеги: %d Coin(s)
	}
}

stock float GetShieldProtectionLevel()
{
	static char sDif[32];
	g_ConVarDifficulty.GetString(sDif, sizeof(sDif));
	
	if (StrEqual(sDif, "Easy", false)) {
		return 0.3;
	}
	else if (StrEqual(sDif, "Normal", false)) {
		return 0.4;
	}
	else if (StrEqual(sDif, "Hard", false)) {
		return 0.5;
	}
	else if (StrEqual(sDif, "Impossible", false)) {
		return 0.75;
	}
	return 0.75;
}

public void OnMapStart()
{
	pointson = pointsoncvar.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		g_iPistolPerMap[i] = 0;
		g_iAutoshotgunPerMap[i] = 0;
		g_iM16PerMap[i] = 0;
		g_iSniperPerMap[i] = 0;
		g_iShotgunPerMap[i] = 0;
		g_iUziPerMap[i] = 0;
		g_iPillsPerMap[i] = 0;
		g_iMedkitPerMap[i] = 0;
		g_iPipePerMap[i] = 0;
		g_iMolotovPerMap[i] = 0;
		g_iPropanePerMap[i] = 0;
		g_iOxygenPerMap[i] = 0;
		g_iPetrolPerMap[i] = 0;
	}

	if( pointsadvertising.BoolValue )
	{
		CreateTimer(3.0, TimerUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	
	static char buf[4];
	
	/*
	char sH[8], sM[8];
	
	FormatTime(sH, 8, "%H", GetTime());
	FormatTime(sM, 8, "%M", GetTime());
	
	PrintToChatAll("shop time: %s:%s", sH, sM);
	*/
	
	FormatTime(buf, sizeof(buf), "%w", GetTime()); // + 7 * 60 * 60
	
	int wd = StringToInt(buf);
	if (wd == 5)
	{
		if( !g_bBlackFriday )
		{
			g_bBlackFriday = true;
			CreateTimer(2.0, Timer_BlackFriday, 1, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else {
		if( g_bBlackFriday )
		{
			g_bBlackFriday = false;
			CreateTimer(2.0, Timer_BlackFriday, 0, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_BlackFriday(Handle timer, int isFriday)
{
	ArrayList al;
	al = new ArrayList(ByteCountToCells(4));
	al.Push(shotpoints);
	al.Push(smgpoints);
	al.Push(riflepoints);
	al.Push(huntingpoints);
	al.Push(autopoints);
	al.Push(pipepoints);
	al.Push(molopoints);
	al.Push(pistolpoints);
	al.Push(pillspoints);
	al.Push(medpoints);
	al.Push(refillpoints);
	al.Push(healpoints);
	al.Push(respawnpoints);
	al.Push(witchershovepoints);
	al.Push(shieldpoints);
	al.Push(oxygentankpoints);
	al.Push(gascanpoints);
	al.Push(propanetankpoints);
	al.Push(incendpoints);
	al.Push(burstpoints);
	al.Push(piersingpoints);
	
	ConVar cv;
	int iFlags;
	for (int i = 0; i < al.Length; i++)
	{
		cv = al.Get(i);
	
		if( isFriday )
		{
			iFlags = cv.Flags;
			cv.Flags &= ~FCVAR_NOTIFY;
			cv.SetInt(RoundToCeil(cv.IntValue * g_fBlackFridayPrice));
			cv.Flags = iFlags;
		}
		else {
			cv.RestoreDefault(false, false);
		}
	}
	delete al;
	return Plugin_Continue;
}

/*
public void OnClientPostAdminCheck(int client)
{
	LoadPoints(client);
}*/

/*
// replaced by database
public void OnClientCookiesCached(int client)
{
	LoadPoints(client);
}
*/

int GetSurvivorCount(int iExcludeClient = 0)
{
	int cnt = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != iExcludeClient && IsClientInGame(i) && GetClientTeam(i) != 3 && !IsFakeClient(i))
			cnt++;
	}
	return cnt;
}

public Action TimerUpdate(Handle timer)
{
	int advertising;
	pointstimer += 1;

	if(pointson)
	{
		if (pointstimer >= pointsadvertisingticks.IntValue * pointsremindtimer)
		{
			advertising = pointsadvertising.IntValue;
			pointsremindtimer += 1;
			if(advertising == 2)
			{
				CPrintToChatAll("\x03%t", "Shop_Advertise_1"); // Вы можете получить HS-коины для покупок. !shop - чтобы использовать.
			}
			else if(advertising == 1)
			{
				CPrintToChatAll("\x03%t", "Shop_Advertise_2"); // !shop - использовать магазин.
			}
		}
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if( !IsFakeClient(client) )
	{
		g_bMinPlayers = GetSurvivorCount() > pointsminplayers.IntValue;
	}
}

public Action ShowPoints(int client, int args)
{
	if(pointson)
	{
		ShowPointsFunc(client);
	}
	return Plugin_Handled;
}

public Action TeamID(int client, int args)
{
	if(pointson)
	{
		TeamIDFunc(client);
	}
	return Plugin_Handled;
}

public Action TeamIDFunc(int client)
{
	CPrintToChat(client, "\x03%t", "You are in team", pointsteam[client]); // Вы в команде %d.
	
	return Plugin_Handled;
}

public Action ShowPointsFunc(int client)
{
	CPrintToChat(client, "\x03%t", "You have coins", points[client]); // У вас есть %d HS-коинов.
	
	return Plugin_Handled;
}

stock bool IsTank(int client)
{
	static int class;
	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( class == (g_bLeft4Dead2 ? 8 : 5 ))
			return true;
	}
	return false;
}

void AddWitcherShove(int client)
{
	g_iShoveCount[client] += 100;
}

public void entity_shoved(Event event, const char [] name, bool dontBroadcast)
{
	static char sTemp[16];
	static int client, victim;
	client = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_iShoveCount[client] > 0)
	{
		victim = event.GetInt("entityid");
		GetEdictClassname(victim, sTemp, sizeof sTemp);
		if( strcmp(sTemp, "infected") == 0 || strcmp(sTemp, "witch") == 0)
		{
			BlastInfected(client, victim);
			//IgniteInfected(client, victim);
			g_iShoveCount[client]--;
		}
	}
}

public void player_shoved(Event event, const char [] name, bool dontBroadcast)
{
	static int client, victim;
	client = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_iShoveCount[client] > 0)
	{
		victim = GetClientOfUserId(event.GetInt("userid"));
		
		if (victim && IsClientInGame(victim) && GetClientTeam(victim) == 3)
		{
			if (!IsTank(victim))
			{
				//BlastInfected(client, victim);
				IgniteInfected(client, victim);
				g_iShoveCount[client]--;
			}
		}
	}
}

void BlastInfected(int client, int target)
{
	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	int entity = CreateEntityByName("point_hurt");
	if (entity != -1) {
		char sTarget[16];
		IntToString(target, sTarget, sizeof(sTarget));
		DispatchKeyValue(target, "targetname", sTarget);
		DispatchKeyValue(entity, "DamageTarget", sTarget);
		DispatchKeyValue(entity, "Damage", "50");
		DispatchKeyValue(entity, "DamageType", "64");
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Hurt", client, client);
		RemoveEdict(entity);
	}
}

void IgniteInfected(int client, int target)
{
	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	int entity = CreateEntityByName("point_hurt");
	if (entity != -1) {
		char sTarget[16];
		IntToString(target, sTarget, sizeof(sTarget));
		DispatchKeyValue(target, "targetname", sTarget);
		DispatchKeyValue(entity, "DamageTarget", sTarget);
		DispatchKeyValue(entity, "Damage", "100");
		DispatchKeyValue(entity, "DamageType", "8"); // DMG_BURN
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Hurt", client, client);
		RemoveEdict(entity);
	}
}

public void InfectedKill(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker && attacker <= MaxClients)
	{
		if (client && client <= MaxClients)
		{
			if (pointsteam[attacker] == SURVIVORTEAM)
			{
				if (pointsteam[client] != SURVIVORTEAM)
				{
					if(pointson && g_bMinPlayers)
					{
						CPrintToChat(attacker,"\x03%t", "Killing the infected: Coin(s)", pointsspecial.IntValue); // Убийства зараженных: %i Coin(s)
						AddPoints(attacker, pointsspecial.IntValue);
					}
				}
			}
		}
	}
	
	//PrintToChat(attacker, "team att: %i, team vict: %i. On? %b. Min? %b", pointsteam[attacker], pointsteam[client], pointson, g_bMinPlayers);
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapTransition = true;
	OnRoundEnd();
}

public void OnClientDisconnect(int client)
{
	if ( !g_bMapTransition && !g_bInDisconnect[client])
	{
		g_bInDisconnect[client] = true;
		
		if (client && IsClientInGame(client) && !IsFakeClient(client))
		{
			SQL_SavePoints(client);
		}
	}
}

public void RoundEnd(Event event, char[] event_name, bool dontBroadcast)
{
	OnRoundEnd();
}

void OnRoundEnd()
{
	char gamemode[16];
	g_CvarGameMode.GetString(gamemode,sizeof(gamemode));
	numtanks = 0;
	numwitches = 0;
	numrounds += 1;
	if (pointsresetround.BoolValue)
	{
		if (StrEqual(gamemode,"versus",false))
		{
			if (numrounds >= pointsresetrounds.IntValue)
			{
				for (int i; i <= MaxClients; i++)
				{
					points[i] = 0;
				}
				numrounds = 0;
			}
		}
		else
		{
			for (int i; i <= MaxClients; i++)
			{
				points[i] = 0;
			}
			numrounds = 0;
		}
	}

	SaveAllPoints(0, 0);
}

public void IncapacitatePoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker > 0 && attacker <= MaxClients)
	{
		if (pointsteam[attacker] == INFECTEDTEAM)
		{
			if (client > 0 && client <= MaxClients)
			{
				if(pointson && g_bMinPlayers)
				{
					CPrintToChat(attacker, "\x03%t", "Survivor is Injured: Coin(s)", pointsincapacitate.IntValue); // Ранен выживший: %d Coin(s)
					AddPoints(attacker, pointsincapacitate.IntValue);
				}
			}
		}
	}
}

public void GrabPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients)
	{
		if (pointsteam[client] != SURVIVORTEAM)
		{
			if(pointson && g_bMinPlayers)
			{
				CPrintToChat(client, "\x03%t", "Survivor was captured: Coin(s)", pointsgrab.IntValue); // Схвачен Выживший: %d Coin(s)
				AddPoints(client, pointsgrab.IntValue);
			}
		}
	}
	
}

public void PouncePoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients)
	{
		if (pointsteam[client] != SURVIVORTEAM)
		{
			if(pointson && g_bMinPlayers)
			{
				CPrintToChat(client, "\x03%t", "Survivor was captured: Coin(s)", pointspounce.IntValue); // Схвачен Выживший: %d Coin(s)
				AddPoints(client, pointspounce.IntValue);
			}
		}
	}
	
}

public void VomitPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if (client > 0 && client <= MaxClients)
	{
		if (pointsteam[client] != SURVIVORTEAM)
		{
			if(pointson && g_bMinPlayers)
			{
				CPrintToChat(client, "\x03%t", "Survivor is in vomit: Coin(s)", pointsvomit.IntValue); // 'Облёван' Выживший: %d Coin(s)
				AddPoints(client, pointsvomit.IntValue);
			}
		}
	}
	
}

public void HurtPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker > 0 && attacker <= MaxClients)
	{
		if (client > 0 && client <= MaxClients)
		{
			if (pointsteam[attacker] != SURVIVORTEAM)
			{
				if (pointsteam[client] == SURVIVORTEAM)
				{
					if(pointson && g_bMinPlayers)
					{
						pointshurtcount[attacker] += 1;
						if(pointshurtcount[attacker] >= 5)
						{
							CPrintToChat(attacker, "\x05 %t", "Loss of survivors five times: Coin(s)", pointshurt.IntValue); // Потеря выживших пять раз: %d Coin(s)
							AddPoints(attacker, pointshurt.IntValue);
							pointshurtcount[attacker] -= 5;
						}
					}
				}
			}
		}
	}
}

/*
public Action TankKill(Event event, char[] event_name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker > 0 && attacker <= MaxClients)
	{
		if(pointson && g_bMinPlayers)
		{
			CPrintToChat(attacker, "\x03%t", "Tank is killed: Coin(s)", pointstankkill.IntValue); // Танк убит: %d Coin(s)
			AddPoints(attacker, pointstankkill.IntValue);
			for (int i = 0;i <= MaxClients;i++)
			{
				tankonfire[i] = 0;
			}
		}
	}
}
*/

public void WitchPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int instakill = event.GetBool("oneshot");
	if (client > 0 && client <= MaxClients)
	{
		if(pointsteam[client] == SURVIVORTEAM)
		{
			if(pointson && g_bMinPlayers)
			{
				CPrintToChat(client, "\x03%t", "Witch is killed: Coin(s)", pointswitch.IntValue); // Ведьма убита: %d Coin(s)
				AddPoints(client, pointswitch.IntValue);
				if (instakill)
				{
					CPrintToChat(client, "\x03%t", "Witch is crowned: Coin(s)", pointswitchinsta.IntValue); // Ведьма коронована: %d Coin(s)
					AddPoints(client, pointswitchinsta.IntValue);
				}
			}
		}
	}
}

/*
public Action TankBurnPoints(Event event, char[] event_name, bool dontBroadcast)
{
	char victim[64];
	int client = GetClientOfUserId(event.GetInt("userid"));
	event.GetString("victimname", victim, sizeof(victim));
//	new target = event.GetInt("clientid");
	if (client > 0 && client <= MaxClients)
	{
		if (StrEqual(victim,"Tank",false))
		{
			if(tankonfire[client] != 1)
			{
				if(pointson && g_bMinPlayers)
				{
					CPrintToChat(client, "\x03%t", "Tank is on fire", pointstankburn.IntValue); // Танк горит: %d Coin(s)
					AddPoints(client, pointstankburn.IntValue);
					tankonfire[client] = 1;
				}
			}
		}
	}
}
*/

public void RefreshTeamPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients) return;

	int teamid = event.GetInt("team");
	pointsteam[client] = teamid;
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	OnUserDisconnect(client);
	
	g_bMinPlayers = GetSurvivorCount(client) > pointsminplayers.IntValue;
}

public void OnClientDisconnect_Post(int client)
{
	g_sSteamId[client][0] = '\0';
}

void OnUserDisconnect(int client)
{
	if (client != 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (!g_bInDisconnect[client])
		{
			g_bInDisconnect[client] = true;
			
			SQL_SavePoints(client);
		}
		
		if (g_bPointsLoaded[client])
		{
			LogShopPoints(client, points[client]);
		}
	}
	points[client] = 0;
	g_iShoveCount[client] = 0;
	g_bPointsLoaded[client] = false;
}

public void HealPointsEvent(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("subject"));
	if (client > 0 && client <= MaxClients)
	{
		if (client != target)
		{
			if(pointson && g_bMinPlayers)
			{
				AddPoints(client, pointsheal.IntValue);
				CPrintToChat(client, "\x03%t", "Ally treatment: Coin(s)", pointsheal.IntValue); // Лечение союзника: %d Coin(s).
			}	
		}
	}
}

public void KillPoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	int headshot = event.GetBool("headshot");
	int minigun = event.GetBool("minigun");
	if (client > 0 && client <= MaxClients)
	{
		pointskillcount[client] += 1;
		if (headshot)
		{
			pointskillcount[client] += pointsheadshot.IntValue;
		}
		if (minigun)
		{
			pointskillcount[client] += pointsminigun.IntValue;
		}
		if (pointskillcount[client] >= pointsinfectednum.IntValue)
		{
			if(pointson && g_bMinPlayers)
			{
				AddPoints(client, pointsinfected.IntValue);
				CPrintToChat(client,"\x03%t", "Killing of infected: Coin(s)", pointsinfected.IntValue); // Убийства зараженных: %d Coin(s)
			}
			pointskillcount[client] -= pointsinfectednum.IntValue;
		}
	}
}

public void RevivePoints(Event event, char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("subject"));
	if (client > 0 && client <= MaxClients)
	{
		if (client != target)
		{
			if(pointson && g_bMinPlayers)
			{
				AddPoints(client, pointsrevive.IntValue);
				CPrintToChat(client, "\x03%t", "Allies revitalizing: Coin(s)", pointsrevive.IntValue); // Оживление союзников: %d Coin(s)
			}
		}
	}
}

public Action Command_GivePoints(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_clientgivepoints <#userid|name> [number of points]");
		return Plugin_Handled;
	}

	bool tn_is_ml;
	char arg[MAX_NAME_LENGTH], arg2[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	
	int targetclient;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		for (int i = 0; i < target_count; i++)
		{
			targetclient = target_list[i];
			points[targetclient] += StringToInt(arg2);
			SQL_SavePoints(targetclient);
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	return Plugin_Handled;
}

public Action Command_SetPoints(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_clientsetpoints <#userid|name> [number of points]");
		return Plugin_Handled;
	}

	bool tn_is_ml;
	char arg[MAX_NAME_LENGTH], arg2[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	
	int targetclient;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		for (int i = 0; i < target_count; i++)
		{
			targetclient = target_list[i];
			points[targetclient] = StringToInt(arg2);
			SQL_SavePoints(targetclient);
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	return Plugin_Handled;
}

public Action Command_ClientCmd(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_clientgive <#userid|name> [item number] Numbers: 0 - Shotgun, 1 - SMG, 2 - Rifle, 3 - Hunting Rifle, 4 - Auto-shotty, 5 - Pipe Bomb, 6 - Molotov, 7 - Pistol, 8 - Pills, 9 - Medkit, 10 - Ammo, 11 - Health");
		return Plugin_Handled;
	}

	bool tn_is_ml;
	char arg[MAX_NAME_LENGTH], arg2[4];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	
	int flags4;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		for (int i = 0; i < target_count; i++)
		{
			flags4 = GetCommandFlags("give");
			SetCommandFlags("give", flags4 & ~FCVAR_CHEAT);
			switch (StringToInt(arg2))
			{
				case 0: //shotgun
				{
					//Give the player a shotgun
					FakeClientCommand(target_list[i], "give pumpshotgun");
				}
				case 1: //smg
				{
					//Give the player an smg
					FakeClientCommand(target_list[i], "give smg");
				}
				case 2: //rifle
				{
					//Give the player a rifle
					FakeClientCommand(target_list[i], "give rifle");
				}
				case 3: //hunting rifle
				{
					//Give the player a hunting rifle
					FakeClientCommand(target_list[i], "give hunting_rifle");
				}
				case 4: //auto shotgun
				{
					//Give the player a autoshotgun
					FakeClientCommand(target_list[i], "give autoshotgun");
				}
				case 5: //pipe_bomb
				{
					//Give the player a pipe_bomb
					FakeClientCommand(target_list[i], "give pipe_bomb");
				}
				case 6: //hunting molotov
				{
					//Give the player a molotov
					FakeClientCommand(target_list[i], "give molotov");
				}
				case 7: //pistol
				{
					//Give the player a pistol
					FakeClientCommand(target_list[i], "give pistol");
				}
				case 8: //pills
				{
					//Give the player pain pills
					FakeClientCommand(target_list[i], "give pain_pills");
				}
				case 9: //medkit
				{
					//Give the player a first aid kit
					FakeClientCommand(target_list[i], "give first_aid_kit");
				}
				case 10: //refill
				{
					//Refill ammo
					FakeClientCommand(target_list[i], "give ammo");
				}
				case 11: //heal
				{
					//Heal player
					FakeClientCommand(target_list[i], "give health");
				}	
			}
			SetCommandFlags("give", flags4|FCVAR_CHEAT);
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	return Plugin_Handled;
}

public Action PointsChooseMenu(int client, int args)
{
	if (!g_bPointsLoaded[client] && IsClientInGame(client))
	{
		PrintToChat(client, "Error in loading points. Re-join the game.");
		return Plugin_Handled;
	}
	
	if(pointson)
	{
		PointsChooseMenuFunc(client);
	}
	return Plugin_Handled;
}

public Action PointsMenu(int client, int args)
{
	if(pointson)
	{
		if(pointsteam[client] != SURVIVORTEAM)
		{
			InfectedPointsMenuFunc(client);
		}
		else
		{
			PointsMenuFunc(client);
		}
	}
	return Plugin_Handled;
}

public Action PointsSpecialMenu(int client, int args)
{
	if(pointson)
	{
		if(pointsteam[client] != SURVIVORTEAM)
		{
			CPrintToChat(client, "\x05 %t", "Not yet accessible for survivors!"); // Пока недоступно для оставшихся в живых!
		}
		else
		{
			PointsSpecialMenuFunc(client);
		}
	}
	return Plugin_Handled;
}

public Action PointsMenu2(int client, int args)
{
	if(pointson)
	{
		if(pointsteam[client] != SURVIVORTEAM)
		{
			InfectedPointsMenu2Func(client);
		}
		else
		{
			PointsMenu2Func(client);
		}
	}
	return Plugin_Handled;
}

public Action PointsConfirm(int client, int args)
{
	PointsUse(client);
	//SavePoints(client);
	return Plugin_Handled;
}

public Action PointsChooseMenuFunc(int clientId) {
	static char Value[128];
	Menu menu = new Menu(PointsChooseMenuHandler, MENU_ACTIONS_DEFAULT);
	Format (Value, sizeof(Value), "%T", "Available bitcoins:", clientId, points[clientId]); // {HSCoins} Доступно монет: %d
	if (g_bBlackFriday)
	{
		//StrCat(Value, sizeof(Value), "\n>>> Black Friday <<<");
		Format(Value, sizeof(Value), "%s\n%T", Value, "Black_Friday", clientId, RoundToCeil(100 - g_fBlackFridayPrice*100) );
	}
	
	menu.SetTitle(Value);
	Format (Value, sizeof(Value), "%T", "Weapon", clientId); // Оружие
	menu.AddItem("weapon",    		Value);
	Format (Value, sizeof(Value), "%T", "Medicine", clientId); // Медикаменты
	menu.AddItem("medic",     		Value);
	
	Format (Value, sizeof(Value), "%T", "Improvement", clientId); // Улучшения
	menu.AddItem("improve",   		Value);
	
	Format (Value, sizeof(Value), "%T", "Grenades and balloons", clientId); // Гранаты и баллоны
	menu.AddItem("explosive", 		Value);
	Format (Value, sizeof(Value), "%T", "Bank operations", clientId); // Банковские операции
	menu.AddItem("bank", 		    Value);
	Format (Value, sizeof(Value), "%T", "Donate", clientId); // Донат
	menu.AddItem("donate", 		    Value);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

char[] strcatEx(char[] str1, ConVar hConVar)
{
	char str2[16];
	char strret[128];
	hConVar.GetString(str2, sizeof(str2));
	Format(strret, sizeof(strret), "%s%s", str1, str2);
	return strret;
}

// Оружие
public Action PointsMenuFunc(int clientId) {
	char Value[60];
	Menu menu = new Menu(PointsMenuHandler);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Cartridge", clientId); // Патроны          -
	menu.AddItem("ammo", 			strcatEx(Value, refillpoints));
	Format(Value, sizeof(Value), "%T", "Pistol", clientId); // Пистолет         -
	menu.AddItem("pistol", 		strcatEx(Value, pistolpoints));
	Format(Value, sizeof(Value), "%T", "AutoShotgun", clientId); // Автодробовик -
	menu.AddItem("autoshotgun", 	strcatEx(Value, autopoints));
	Format(Value, sizeof(Value), "%T", "M-16", clientId); // М-16               -
	menu.AddItem("m16", 			strcatEx(Value, riflepoints));
	Format(Value, sizeof(Value), "%T", "Sniper", clientId); // Снайперка      -
	menu.AddItem("sniper", 		strcatEx(Value, huntingpoints));
	Format(Value, sizeof(Value), "%T", "Shotgun", clientId); // Дробовик        -
	menu.AddItem("shotgun", 		strcatEx(Value, shotpoints));
	Format(Value, sizeof(Value), "%T", "Uzi", clientId); // Узи                  -
	menu.AddItem("uzi", 			strcatEx(Value, smgpoints));
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Медикаменты
public Action PointsMenu2Func(int clientId) {
	char Value[64];
	Menu menu = new Menu(PointsMenuHandler2);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Health", clientId); // Здоровье   -
	menu.AddItem("heal", 			strcatEx(Value, healpoints));
	Format(Value, sizeof(Value), "%T", "Pills", clientId); // Таблетки   -
	menu.AddItem("pills", 			strcatEx(Value, pillspoints));
	Format(Value, sizeof(Value), "%T", "Medkit", clientId); // Аптечка     -
	menu.AddItem("aidkit", 		strcatEx(Value, medpoints));
	if (g_bAutorespawnLib)
	{
		//Format(Value, sizeof(Value), "%T", "Resurrect", clientId); // Воскрешение     -
		//menu.AddItem("Resurrect", 		strcatEx(Value, respawnpoints));
	}
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Улучшения
public Action PointsSpecialMenuFunc(int clientId) {
	char Value[80];
	Menu menu = new Menu(PointsSpecialMenuHandler);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T  - ", "Incendiary", clientId); // 
	menu.AddItem("Incendiary", 			strcatEx(Value, incendpoints));
	Format(Value, sizeof(Value), "%T  - ", "Bursting", clientId); // 
	menu.AddItem("Bursting", 	strcatEx(Value, burstpoints));
	Format(Value, sizeof(Value), "%T  - ", "Armor piercing", clientId); // 
	menu.AddItem("Armor piercing", 	strcatEx(Value, piersingpoints));
	Format(Value, sizeof(Value), "%T  - ", "Witcher Shove", clientId); // 
	menu.AddItem("Witcher Shove", 	strcatEx(Value, piersingpoints));
	Format(Value, sizeof(Value), "%T  - ", "Shield", clientId); // 
	menu.AddItem("Shield", 	strcatEx(Value, piersingpoints));
	/*
	Format(Value, sizeof(Value), "%T  - ", "Bulldozer", clientId); // 
	menu.AddItem("Bulldozer", 	strcatEx(Value, bulldozerpoints));
	*/
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Гранаты и баллоны
public Action PointsMenu3Func(int clientId) {
	char Value[60];
	Menu menu = new Menu(PointsMenuHandler3);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Pipe bomb", clientId); // Пайпа       -
	menu.AddItem("pipe", 			strcatEx(Value, pipepoints));
	Format(Value, sizeof(Value), "%T", "Molotov", clientId); // Молотов   -
	menu.AddItem("molotov", 		strcatEx(Value, molopoints));
	Format(Value, sizeof(Value), "%T", "Propane balloon", clientId); // Баллон пропана           -
	menu.AddItem("propane", 		strcatEx(Value, propanetankpoints));
	Format(Value, sizeof(Value), "%T", "Oxygen balloon", clientId); // Баллон кислорода        -
	menu.AddItem("oxigen", 		strcatEx(Value, oxygentankpoints));
	Format(Value, sizeof(Value), "%T", "Gas canister", clientId); // Канистра с бензином -
	menu.AddItem("gascan", 		strcatEx(Value, gascanpoints));
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Банковские операции
public Action PointsMenu4Func(int clientId) {
	char Value[128];
	Menu menu = new Menu(Transfer1MenuHandler);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Transfer coins to another player", clientId); // Перевести монеты другому игроку
	menu.AddItem("transfer_player", Value);
	Format(Value, sizeof(Value), "%T", "BuyCoins", clientId); // Купить монеты за донат
	menu.AddItem("BuyCoins", Value);
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Transfer1MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsChooseMenuFunc(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));

			if ( StrEqual("transfer_player", info, false) )
			{
				if (points[client] <= 0)
				{
					PrintNoCoins(client);
					PointsMenu4Func(client);
					return 0;
				}
				Transfer2Menu(client);
			}
			else if ( StrEqual("BuyCoins", info, false) )
			{
				ShowDonateInfo(client);
			}
		}
	}
	return 0;
}
public int BuyPanelHandler(Menu UpgradePanel, MenuAction action, int client, int param2)
{
	return 0;
}

void ShowDonateInfo(int client)
{
	char Value[60];
	Panel p = new Panel();
	//Format(Value, sizeof(Value), "%T", "BuyCoins");
	//p.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Donate1", client);
	p.DrawText(Value);
	Format(Value, sizeof(Value), "%T", "Donate2", client);
	p.DrawText(Value);
	Format(Value, sizeof(Value), "%T", "Donate3", client);
	p.DrawText(Value);
	p.Send( client, BuyPanelHandler, 20);
	delete p;
	PrintToChat(client, "\x05[INFO] %s\n%s\n%s", "\x04 You can buy \x03 1000 coins for 1$", "\x04Ask: admin \x03☣ Drakoshka ☣", "\x04Steam: \x03https://steamcommunity.com/id/drago-kas/");
}

stock bool IsClientRootAdmin(int client)
{
	return ((GetUserFlagBits(client) & ADMFLAG_ROOT) != 0);
}

public Action Transfer2Menu(int client) 
{
	char Value[80];
	Menu menu = new Menu(Transfer2MenuHandler);
	Format(Value, sizeof(Value), "%T", "Who would you like to transfer coins to?", client); // Кому вы желаете перевести монеты?
	menu.SetTitle(Value);
	char name[128];
	char number[10];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (IsFakeClient(i)) continue;
		//if (GetClientTeam(i) != TEAM_SURVIVORS) continue;
		if (i == client) continue;
		
		//if (IsClientRootAdmin(client))
		{
			Format(name, sizeof(name), "%N - %i Coin(s)", i, points[i]);
		}
		//else {
		//	Format(name, sizeof(name), "%N", i);
		//}
		Format(number, sizeof(number), "%i", i);

		menu.AddItem(number, name);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Transfer2MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsMenu4Func(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[10];
			char name[128];
			menu.GetItem(ItemIndex, info, sizeof(info), _, name, sizeof(name));
			int target = StringToInt(info);

			if (!IsClientInGame(target))
			{
				CPrintToChat(client, "%t", "is no longer in game!", name);
				Transfer2Menu(client);
				return 0;
			}
			TransferTo[client] = target;
			Transfer3Menu(param1);
		}
	}
	return 0;
}

public Action Transfer3Menu(int client)
{
	char Value[80];
	Menu menu = new Menu(Transfer3MenuHandler);
	Format(Value, sizeof(Value), "%T", "How many coins would you like to transfer?", client); // Сколько монет вы желаете перевести?
	menu.SetTitle(Value);
	
	//Format(Value, sizeof(Value), "%T", "All coins ()", client, points[client]); // Все монеты (%d)
	//menu.AddItem("0", Value);
	if (points[client] >= 10)
		menu.AddItem("10", "10 coins");
	if (points[client] >= 20)
		menu.AddItem("20", "20 coins");
	if (points[client] >= 30)
		menu.AddItem("30", "30 coins");
	if (points[client] >= 50)
		menu.AddItem("50", "50 coins");
	if (points[client] >= 60)
		menu.AddItem("60", "60 coins");
	if (points[client] >= 100)
		menu.AddItem("100", "100 coins");
	if (points[client] >= 1000)
		menu.AddItem("1000", "1000 coins");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Transfer3MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				Transfer2Menu(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;
			int coins;

			char info[16];
			menu.GetItem(ItemIndex, info, sizeof(info));

			if ( StrEqual("0", info, false) )
				coins = points[client];
			else
				coins = StringToInt(info);
			
			int target = TransferTo[client];

			if (!IsClientInGame(target))
			{
				CPrintToChat(client, "%t", "Client is no longer in game!");
				return 0;
			}
			points[client] -= coins;
			points[target] += coins;

			CPrintToChat(client, "%t", "coins is transferred to", coins, target); // %d монет переведено игроку %N
			CPrintToChat(target, "%t", "has transfered coins to you :)", client, coins); // %N перевёл вам %d монет :)
			
			LogToFileEx(g_sLogTransfer, "%i coins are transferred %L -> %L", coins, client, target );
			
			Transfer2Menu(client);
		}
	}
	return 0;
}

public Action PointsConfirmFunc(int clientId)
{
	int cost;
	switch (buyitem[clientId])
	{
		case 0: //shotgun
		{
			cost = shotpoints.IntValue;
		}
		case 1: //smg
		{
			cost = smgpoints.IntValue;
		}
		case 2: //rifle
		{
			cost = riflepoints.IntValue;
		}
		case 3: //hunting rifle
		{
			cost = huntingpoints.IntValue;
		}
		case 4: //auto shotgun
		{
			cost = autopoints.IntValue;
		}
		case 5: //pipe bomb
		{
			cost = pipepoints.IntValue;
		}
		case 6: //molotov
		{
			cost = molopoints.IntValue;
		}
		case 7: //extra pistol
		{
			cost = pistolpoints.IntValue;
		}
		case 8: //pills
		{
			cost = pillspoints.IntValue;
		}
		case 9: //medkit
		{
			cost = medpoints.IntValue;
		}
		case 10: //refill
		{
			cost = refillpoints.IntValue;
		}
		case 11: //heal
		{
			cost = healpoints.IntValue;
		}
		case 12: //suicide
		{
			cost = suicidepoints.IntValue;
		}
		case 13: //iheal
		{
			cost = ihealpoints.IntValue;
		}
		case 14: //boomer
		{
			cost = boomerpoints.IntValue;
		}
		case 15: //hunter
		{
			cost = hunterpoints.IntValue;
		}
		case 16: //smoker
		{
			cost = smokerpoints.IntValue;
		}
		case 17: //tank
		{
			cost = tankpoints.IntValue;
		}
		case 18: //witch
		{
			cost = wwitchpoints.IntValue;
		}
		case 19: //mob
		{
			cost = mobpoints.IntValue;
		}
		case 20: //panic
		{
			cost = panicpoints.IntValue;
		}
		case 23: //propane tank
		{
			cost = propanetankpoints.IntValue;
		}
		case 24: //oxygen tank
		{
			cost = oxygentankpoints.IntValue;
		}
		case 25: //gascan
		{
			cost = gascanpoints.IntValue;
		}
		case 31: // Incendiary ammo
		{
			cost = incendpoints.IntValue;
		}
		case 32: // Bursting ammo
		{
			cost = burstpoints.IntValue;
		}
		case 33: // Armor piercing ammo
		{
			cost = piersingpoints.IntValue;
		}
		case 34: // Witcher Shove
		{
			cost = witchershovepoints.IntValue;
		}
		case 35: // Shield
		{
			cost = shieldpoints.IntValue;
		}
		case 40: // Resurrection
		{
			cost = respawnpoints.IntValue;
		}
	}
	char Value[64];
	Menu menu = new Menu(PointsConfirmHandler);
	Format(Value, sizeof(Value), "%T", "Cost:", clientId, cost); // Стоимость: %d
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Yes", clientId); // Да
	menu.AddItem("option1", Value);
	Format(Value, sizeof(Value), "%T", "No", clientId); // Нет
	menu.AddItem("option2", Value);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action InfectedPointsMenuFunc(int clientId) {
	char Value[64];
	Menu menu = new Menu(InfectedPointsMenuHandler);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);

	Format(Value, sizeof(Value), "%T", "Suicide", clientId); // Суицид
	menu.AddItem("option1", Value);
	Format(Value, sizeof(Value), "%T", "Health", clientId); // Здоровье
	menu.AddItem("option2", Value);
	Format(Value, sizeof(Value), "%T", "Spawn boomer", clientId); // Спаун толстяка
	menu.AddItem("option3", Value);
	Format(Value, sizeof(Value), "%T", "Spawn hunter", clientId); // Спаун ханта
	menu.AddItem("option4", Value);
	Format(Value, sizeof(Value), "%T", "Spawn smoker", clientId); // Спаун куры
	menu.AddItem("option5", Value);
	Format(Value, sizeof(Value), "%T", "Spawn tank", clientId); // Спаун танка
	menu.AddItem("option6", Value);
	Format(Value, sizeof(Value), "%T", "Next", clientId); // Далее
	menu.AddItem("option7", Value);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action InfectedPointsMenu2Func(int clientId) {
	char Value[64];
	Menu menu = new Menu(InfectedPointsMenu2Handler);
	Format(Value, sizeof(Value), "%T", "coins:", clientId, points[clientId]); // HS монет:
	menu.SetTitle(Value);
	Format(Value, sizeof(Value), "%T", "Spawn witch", clientId); // Спаун ведьмы
	menu.AddItem("option1", Value);
	Format(Value, sizeof(Value), "%T", "Spawn zombie", clientId); // Спаун зомби
	menu.AddItem("option2", Value);
	Format(Value, sizeof(Value), "%T", "Panic wave", clientId); // Волна зомби
	menu.AddItem("option3", Value);
	menu.ExitBackButton = true;
	menu.Display(clientId, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action Refill(int client, int args)
{
	RefillFunc(client);
	
	return Plugin_Handled;
}

public Action RefillFunc(int clientId)
{
	int flags3 = GetCommandFlags("give");
	SetCommandFlags("give", flags3 & ~FCVAR_CHEAT);
	
	//Give player ammo
	FakeClientCommand(clientId, "give ammo");
	
	SetCommandFlags("give", flags3|FCVAR_CHEAT);
	
	return Plugin_Handled;
}

public Action Heal(int client, int args)
{
	HealFunc(client);
	
	return Plugin_Handled;
}

public Action HealFunc(int clientId)
{
	int flags2 = GetCommandFlags("give");
	SetCommandFlags("give", flags2 & ~FCVAR_CHEAT);
	
	//Give player health
	FakeClientCommand(clientId, "give health");
	
	SetCommandFlags("give", flags2|FCVAR_CHEAT);
	
	return Plugin_Handled;
}

public Action FakeGod(int client, int args)
{
	FakeGodFunc(client);
	
	return Plugin_Handled;
}

public Action FakeGodFunc(int client)
{
	if (godon[client] <= 0)
	{
		godon[client] = 1;
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
	else
	{
		godon[client] = 0;
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);  
	}
	
	return Plugin_Handled;
}

void PrintNoCoins(int client)
{
	CPrintToChat(client, "\x03%t", "Not enough bitcoins.", client); // Недостаточно HS-монет.
}

bool IsPlayerIncapped(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}

bool IsHealAllowed(int client)
{
	int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
	if (iHealth >= 80 && !IsPlayerIncapped(client)) {
		PrintToChat(client, "\x04Can't bye. You are already healed!");
		//bFailed = true;
	}
	else {
		return true;
	}
	return false;
}

public int PointsConfirmHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select ) {
		
		if(itemNum == 0)
		{
			PointsUse(client);
		}
	}
	return 0;
}

bool PointsUse(int client)
{
	static float fNowTime;
	fNowTime = GetEngineTime();
	if (g_fLastTime[client] != 0.0 && FloatAbs(fNowTime - g_fLastTime[client]) < 60.0) {
		g_iBuyPerMinute[client]++;
		if (g_iBuyPerMinute[client] > MAX_ITEMS_PER_MINUTE)
		{
			PrintToChat(client, "\x05[SHOP] \x04You can't buy too often. Wait a minute!");
			return false;
		}
	}
	else {
		g_fLastTime[client] = fNowTime;
		g_iBuyPerMinute[client] = 1;
	}
	
	bool bFailed;
	int flags = GetCommandFlags("give");
	int flags2 = GetCommandFlags("kill");
	int flags3 = GetCommandFlags("z_spawn");
	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	SetCommandFlags("kill", flags2 & ~FCVAR_CHEAT);
	SetCommandFlags("z_spawn", flags3 & ~FCVAR_CHEAT);


	{
		{
			switch(buyitem[client])
			{
				case 0: //shotgun
				{
					if (points[client] >= shotpoints.IntValue)
					{
						if (g_iShotgunPerMap[client] >= MAX_SHOTGUN_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a shotgun
							g_iShotgunPerMap[client]++;
							FakeClientCommand(client, "give pumpshotgun");
							points[client] -= shotpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 1: //smg
				{
					if (points[client] >= smgpoints.IntValue)
					{
						if (g_iUziPerMap[client] >= MAX_UZI_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player an SMG
							g_iUziPerMap[client]++;
							FakeClientCommand(client, "give smg");
							points[client] -= smgpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 2: //rifle
				{
					if (points[client] >= riflepoints.IntValue)
					{
						if (g_iM16PerMap[client] >= MAX_M16_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a rifle
							g_iM16PerMap[client]++;
							FakeClientCommand(client, "give rifle");
							points[client] -= riflepoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 3: //hunting rifle
				{
					if (points[client] >= huntingpoints.IntValue)
					{
						if (g_iSniperPerMap[client] >= MAX_SNIPER_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a hunting rifle
							g_iSniperPerMap[client]++;
							FakeClientCommand(client, "give hunting_rifle");
							points[client] -= huntingpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 4: //auto shotgun
				{
					if (points[client] >= autopoints.IntValue)
					{
						if (g_iAutoshotgunPerMap[client] > MAX_AUTOSHOTGUN_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player an auto shotgun
							g_iAutoshotgunPerMap[client]++;
							FakeClientCommand(client, "give autoshotgun");
							points[client] -= autopoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 5: //pipe bomb
				{
					if (points[client] >= pipepoints.IntValue)
					{
						if (g_iPipePerMap[client] > MAX_PIPE_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a pipebomb
							g_iPipePerMap[client]++;
							FakeClientCommand(client, "give pipe_bomb");
							points[client] -= pipepoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 6: //molotov
				{
					if (points[client] >= molopoints.IntValue)
					{
						if (g_iMolotovPerMap[client] > MAX_MOLOTOV_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a molotov
							g_iMolotovPerMap[client]++;
							FakeClientCommand(client, "give molotov");
							points[client] -= molopoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 7: //pistol
				{
					if (points[client] >= pistolpoints.IntValue)
					{
						if (g_iPistolPerMap[client] > MAX_PISTOL_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a pistol
							g_iPistolPerMap[client]++;
							FakeClientCommand(client, "give pistol");
							points[client] -= pistolpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 8: //pills
				{
				   if (points[client] >= pillspoints.IntValue)
					{
						if (g_iPillsPerMap[client] > MAX_PILLS_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player pain pills
							g_iPillsPerMap[client]++;
							FakeClientCommand(client, "give pain_pills");
							points[client] -= pillspoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 9: //medkit
				{
					if (points[client] >= medpoints.IntValue)
					{
						if (g_iMedkitPerMap[client] > MAX_MEDKIT_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a medkit
							g_iMedkitPerMap[client]++;
							FakeClientCommand(client, "give first_aid_kit");
							points[client] -= medpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 10: //refill
				{
					if (points[client] >= refillpoints.IntValue)
					{
						//Refill ammo
						FakeClientCommand(client, "give ammo");
						points[client] -= refillpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 11: //heal
				{
					if (points[client] >= healpoints.IntValue)
					{
						//Heal player
						if (IsHealAllowed(client)) {
							FakeClientCommand(client, "give health");
							points[client] -= healpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 12: //suicide
				{
					if (points[client] >= suicidepoints.IntValue)
					{
						//Kill yourself (for boomers)
						FakeClientCommand(client, "kill");
						points[client] -= suicidepoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 13: //heal
				{
					if (points[client] >= ihealpoints.IntValue)
					{
						//Give the player health
						if (IsHealAllowed(client)) {
							FakeClientCommand(client, "give health");
							points[client] -= ihealpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 14: //boomer
				{
					if (points[client] >= boomerpoints.IntValue)
					{
						//Make the player a boomer
						FakeClientCommand(client, "z_spawn boomer auto");
						points[client] -= boomerpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 15: //hunter
				{
					if (points[client] >= hunterpoints.IntValue)
					{
						//Make the player a hunter
						FakeClientCommand(client, "z_spawn hunter auto");
						points[client] -= hunterpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 16: //smoker
				{
					if (points[client] >= smokerpoints.IntValue)
					{
						//Make the player a smoker
						FakeClientCommand(client, "z_spawn smoker auto");
						points[client] -= smokerpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 17: //tank
				{
					if (points[client] >= tankpoints.IntValue)
					{
						numtanks += 1;
						if (numtanks < tanklimit.IntValue + 1)
						{
							//Make the player a tank
							FakeClientCommand(client, "z_spawn tank auto");
							points[client] -= tankpoints.IntValue;
						}
						else
						{
							CPrintToChat(client,"\x03%t", "Tank limit is exceeded on map!", client); // Лимит танка на карту!
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 18: //spawn witch
				{
					if (points[client] >= wwitchpoints.IntValue)
					{
						numwitches += 1;
						if (numwitches < witchlimit.IntValue + 1)
						{
							//Spawn a witch
							FakeClientCommand(client, "z_spawn witch auto");
							points[client] -= wwitchpoints.IntValue;
						}
						else
						{
							CPrintToChat(client,"\x03%t", "Witch limit is exceeded on map!", client); // Лимит ведьмы на карту!
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 19: //spawn mob
				{
					if (points[client] >= mobpoints.IntValue)
					{
						//Spawn a mob
						FakeClientCommand(client, "z_spawn mob");
						points[client] -= mobpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 20: //spawn mega mob
				{
					if (points[client] >= panicpoints.IntValue)
					{
						//Spawn a mob
						int flags4 = GetCommandFlags("director_force_panic_event");
						SetCommandFlags("director_force_panic_event", flags4 & ~FCVAR_CHEAT);
						FakeClientCommand(client, "director_force_panic_event");
						SetCommandFlags("director_force_panic_event", flags4|FCVAR_CHEAT);
						//FakeClientCommand(client, "z_spawn mob;z_spawn mob;z_spawn mob;z_spawn mob;z_spawn mob");
						points[client] -= panicpoints.IntValue;
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 23: //propane tank
				{
					if (points[client] >= propanetankpoints.IntValue)
					{
						if (g_iPropanePerMap[client] >= MAX_PROPANE_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							if (fPropaneLastTime[client] != 0.0 && FloatAbs(fNowTime - fPropaneLastTime[client]) < 60.0) {
								g_iPropanePerMinute[client]++;
							}
							else {
								g_iPropanePerMinute[client] = 1;
								fPropaneLastTime[client] = fNowTime;
							}
								
							if (g_iPropanePerMinute[client] > MAX_PROPANE_PER_MINUTE)
							{
								PrintToChat(client, "\x05[SHOP] \x04You can't buy too often. Wait a minute!");
							}
							else {
								//Give the player a propane tank
								g_iPropanePerMap[client]++;
								FakeClientCommand(client, "give propanetank");
								points[client] -= propanetankpoints.IntValue;
							}
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 24: //oxygen tank
				{
					if (points[client] >= oxygentankpoints.IntValue)
					{
						if (g_iOxygenPerMap[client] >= MAX_OXYGEN_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							if (fOxygenLastTime[client] != 0.0 && FloatAbs(fNowTime - fOxygenLastTime[client]) < 60.0) {
								g_iOxygenPerMinute[client]++;
							}
							else {
								g_iOxygenPerMinute[client] = 1;
								fOxygenLastTime[client] = fNowTime;
							}
							
							if (g_iOxygenPerMinute[client] > MAX_OXYGEN_PER_MINUTE)
							{
								PrintToChat(client, "\x05[SHOP] \x04You can't buy too often. Wait a minute!");
							}
							else {
								//Give the player a oxygentank
								g_iOxygenPerMap[client]++;
								FakeClientCommand(client, "give oxygentank");
								points[client] -= oxygentankpoints.IntValue;
							}
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 25: //gascan
				{
					if (points[client] >= gascanpoints.IntValue)
					{
						if (g_iPetrolPerMap[client] >= MAX_PETROL_PER_MAP)
						{
							PrintToChat(client, "\x05[SHOP] \x04This type of goods is over. Wait a next map!");
						}
						else {
							//Give the player a medkit
							g_iPetrolPerMap[client]++;
							FakeClientCommand(client, "give gascan");
							points[client] -= gascanpoints.IntValue;
						}
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				
				case 31: // Incendiary ammo
				{
					if (points[client] >= incendpoints.IntValue)
					{
						#if defined _spacial_ammo_included_
						if (g_bSpecialAmmoLib) {
							// Give Incendiary ammo
							AddSpecialAmmo(client, 1);
							points[client] -= incendpoints.IntValue;
							PrintToChat(client, "\x04+ \x03%t", "Incendiary");
						}
						#endif
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 32: // Bursting ammo
				{
					if (points[client] >= burstpoints.IntValue)
					{
						#if defined _spacial_ammo_included_
						if (g_bSpecialAmmoLib) {
							// Give Bursting ammo
							AddSpecialAmmo(client, 2);
							points[client] -= burstpoints.IntValue;
							PrintToChat(client, "\x04+ \x03%t", "Bursting");
						}
						#endif
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				case 33: // Armor piercing ammo
				{
					if (points[client] >= piersingpoints.IntValue)
					{
						#if defined _spacial_ammo_included_
						if (g_bSpecialAmmoLib) {
							// Give Armor piercing ammo
							AddSpecialAmmo(client, 3);
							points[client] -= piersingpoints.IntValue;
							PrintToChat(client, "\x04+ \x03%t", "Armor piercing");
						}
						#endif
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				
				case 34: // Witcher Shove
				{
					if (points[client] >= witchershovepoints.IntValue)
					{
						// Give Witcher Shove weapon upgrade
						AddWitcherShove(client);
						points[client] -= witchershovepoints.IntValue;
						PrintToChat(client, "\x04+100 \x03%t", "Witcher Shove");
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				
				case 35: // Shield
				{
					if (points[client] >= shieldpoints.IntValue)
					{
						#if defined _autorespawn_included_
						if (g_bAutorespawnLib)
						{
							if (AR_CreateShield(client, 600.0, GetShieldProtectionLevel()) != -1)
							{
								points[client] -= shieldpoints.IntValue;
								PrintToChat(client, "\x04+ \x03%t", "Shield");
							}
							else {
								PrintToChat(client, "\x04%t", "Already Upgraded");
							}
						}
						#endif
					}
					else
					{
						PrintNoCoins(client);
					}
				}
				
				case 40: //resurrection
				{
					if (points[client] >= respawnpoints.IntValue && !IsPlayerAlive(client))
					{
						#if defined _autorespawn_included_
						if (g_bAutorespawnLib)
						{
							if (AR_RespawnPlayer(client))
							{
								points[client] -= respawnpoints.IntValue;
							}
						}
						#endif
					}
					else
					{
						PrintNoCoins(client);
					}
				}
			}
		}
	}

	SetCommandFlags("give", flags|FCVAR_CHEAT);
	SetCommandFlags("kill", flags2|FCVAR_CHEAT);
	SetCommandFlags("z_spawn", flags3|FCVAR_CHEAT);

	return !bFailed;
}

void PrintDisabled(int client)
{
	CPrintToChat(client, "\x03%t", "Disabled."); // Отключено.
}

public int PointsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsChooseMenuFunc(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));
			
			if ( StrEqual("ammo", info, false) )
			{
				if (refillpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 10;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("pistol", info, false) )
			{
				if (pistolpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 7;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("autoshotgun", info, false) )
			{
				if (autopoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 4;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("m16", info, false) )
			{
				if (riflepoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 2;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("sniper", info, false) )
			{
				if (huntingpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 3;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("shotgun", info, false) )
			{
				if (shotpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					//Give the player a shotgun
					buyitem[client] = 0;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("uzi", info, false) )
			{
				if (smgpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 1;
					PointsConfirm(client, 0);
				}
			}
			PointsMenuFunc(client);
		}
	}
	return 0;
}

public int PointsMenuHandler2(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsChooseMenuFunc(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));

			if ( StrEqual("heal", info, false) )
			{
				if (healpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 11;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("pills", info, false) )
			{
				if (pillspoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 8;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("aidkit", info, false) )
			{
				if (medpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 9;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("Resurrect", info, false) )
			{
				if (!IsPlayerAlive(client))
				{
					if (respawnpoints.IntValue < 0)
					{
						PrintDisabled(client);
					}
					else
					{
						buyitem[client] = 40;
						PointsConfirm(client, 0);
					}
				}
			}
			PointsMenu2Func(client);
		}
	}
	return 0;
}


public int PointsMenuHandler3(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsChooseMenuFunc(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));

			if ( StrEqual("pipe", info, false) )
			{
				if (pipepoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 5;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("molotov", info, false) )
			{
				if (molopoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 6;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("propane", info, false) )
			{
				if (propanetankpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 23;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("oxigen", info, false) )
			{
				if (oxygentankpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 24;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("gascan", info, false) )
			{
				if (gascanpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 25;
					PointsConfirm(client, 0);
				}
			}
			PointsMenu3Func(client);
		}
	}
	return 0;
}

public int InfectedPointsMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select ) {
		
		switch (itemNum)
		{
			case 0: //suicide
			{
				if (suicidepoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 12;
					PointsConfirm(client, 0);
				}
			}
			case 1: //heal
			{
				if (ihealpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 13;
					PointsConfirm(client, 0);
				}
			}
			case 2: //boomer
			{
				if (boomerpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 14;
					PointsConfirm(client, 0);
				}
			}
			case 3: //hunter
			{
				if (hunterpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 15;
					PointsConfirm(client, 0);
				}
			}
			case 4: //smoker
			{
				if (smokerpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 16;
					PointsConfirm(client, 0);
				}
			}
			case 5: //tank
			{
				if (tankpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 17;
					PointsConfirm(client, 0);
				}
			}
			case 6: //next page
			{
				PointsMenu2(client, 0);
			}
		}
		InfectedPointsMenuFunc(client);
	}
	return 0;
}

public int InfectedPointsMenu2Handler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		switch (itemNum)
		{
			case 0: //witch
			{
				if (wwitchpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 18;
					PointsConfirm(client, 0);
				}
			}
			case 1: //mob
			{
				if (mobpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 19;
					PointsConfirm(client, 0);
				}
			}
			case 2: //mega mob
			{
				if (panicpoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 20;
					PointsConfirm(client, 0);
				}
			}
		}
		InfectedPointsMenu2Func(client);
	}
	else if (action == MenuAction_Cancel)
	{
		PointsMenu(client, 0);
	}
	return 0;
}

public int PointsSpecialMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				PointsChooseMenuFunc(param1);

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));

			if ( StrEqual("Incendiary", info, false) )
			{
				if (incendpoints.IntValue < 0 || !g_bSpecialAmmoLib)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 31;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("Bursting", info, false) )
			{
				if (burstpoints.IntValue < 0 || !g_bSpecialAmmoLib)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 32;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("Armor piercing", info, false) )
			{
				if (piersingpoints.IntValue < 0 || !g_bSpecialAmmoLib)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 33;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("Witcher Shove", info, false) )
			{
				if (witchershovepoints.IntValue < 0)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 34;
					PointsConfirm(client, 0);
				}
			}
			else if ( StrEqual("Shield", info, false) )
			{
				if (shieldpoints.IntValue < 0 || !g_bAutorespawnLib)
				{
					PrintDisabled(client);
				}
				else
				{
					buyitem[client] = 35;
					PointsConfirm(client, 0);
				}
			}
			PointsSpecialMenuFunc(client);
		}
	}
	return 0;
}

public int PointsChooseMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				FakeClientCommand(param1, "sm_menu");

		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;

			char info[64];
			menu.GetItem(ItemIndex, info, sizeof(info));
			
			if ( StrEqual("weapon", info, false) )
			{
				PointsMenuFunc(client);
			}
			else if ( StrEqual("medic", info, false) )
			{
				PointsMenu2Func(client);
			}
			else if ( StrEqual("improve", info, false) )
			{
				PointsSpecialMenuFunc(client);
			}
			else if ( StrEqual("explosive", info, false) )
			{
				PointsMenu3Func(client);
			}
			else if ( StrEqual("bank", info, false) )
			{
				PointsMenu4Func(client);
			}
			else if ( StrEqual("donate", info, false) )
			{
				ShowDonateInfo(client);
			}
		}
	}
	return 0;
}

stock void ReplaceColor(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{white}", "\x01", false);
    ReplaceString(message, maxLen, "{cyan}", "\x03", false);
    ReplaceString(message, maxLen, "{orange}", "\x04", false);
    ReplaceString(message, maxLen, "{green}", "\x05", false);
}

stock void CPrintToChatAll(const char[] format, any ...)
{
    char buffer[192];
    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            ReplaceColor(buffer, sizeof(buffer));
            PrintToChat(i, "\x01%s", buffer);
        }
    }
}

stock void CPrintToChat(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    ReplaceColor(buffer, sizeof(buffer));
    PrintToChat(iClient, "\x01%s", buffer);
}

void LogShopPoints(int client, int iPoints)
{
	static char sSteam[64];
	static char sIP[32];
	static char sCountry[4];
	static char sName[MAX_NAME_LENGTH];
	
	if (client != 0 && IsClientInGame(client)) {
		GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam));
		GetClientName(client, sName, sizeof(sName));
		GetClientIP(client, sIP, sizeof(sIP));
		GeoipCode3(sIP, sCountry);
		LogToFile(g_sLogPoints, "%s %i (%s | [%s] %s)", sSteam, iPoints, sName, sCountry, sIP);
	}
}

bool CacheSteamID(int client)
{
	if (g_sSteamId[client][0] == '\0')
	{
		if ( !GetClientAuthId(client, AuthId_Steam2, g_sSteamId[client], sizeof(g_sSteamId[])) )
		{
			return false;
		}
	}
	return true;
}

File g_hLog;

stock void OpenLog(char[] access)
{
	g_hLog = OpenFile(g_sLogShop, access);
	if( g_hLog == null )
	{
		LogError("[Shop] Failed to open or create log file: %s (access: %s)", g_sLogShop, access);
		return;
	}
}
stock void CloseLog()
{
	if (g_hLog) {
		g_hLog.Close();
		g_hLog = null;
	}
}
stock void StringToLog(const char[] format, any ...)
{
	static char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	if (g_hLog == null) {
		OpenLog("a+");
	}
	if (g_hLog) {
		g_hLog.WriteLine(buffer);
		FlushFile(g_hLog);
	}
}

stock void SetCvarSilent( ConVar cv, int value )
{
	if( !cv )
	{
		return;
	}
	int flags = cv.Flags;
	cv.Flags &= ~FCVAR_NOTIFY;
	cv.SetInt(value, true, false);
	cv.Flags = flags;
}


// =========================================================
//					SPECIAL EVENTS
// =========================================================

public void DAS_OnWitchHunting(int iStarted )
{
	static int iOldValue1;
	static int iOldValue2;
	
	if( iStarted )
	{
		iOldValue1 = pointswitch.IntValue;
		SetCvarSilent(pointswitch, 0);
		
		iOldValue2 = pointswitchinsta.IntValue;
		SetCvarSilent(pointswitchinsta, 0);
	}
	else {
		SetCvarSilent(pointswitch, iOldValue1);
		SetCvarSilent(pointswitchinsta, iOldValue2);
	}
}