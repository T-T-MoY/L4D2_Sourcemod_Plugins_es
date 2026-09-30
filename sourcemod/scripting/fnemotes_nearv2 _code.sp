#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors> // Compatible con multicolors
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma semicolon 1
#pragma newdecls required

#define EF_BONEMERGE            (1 << 0)
#define EF_NOSHADOW             (1 << 4)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_NORECEIVESHADOW      (1 << 6)
#define EF_PARENT_ANIMATES      (1 << 9)
#define HIDEHUD_ALL             (1 << 2)
#define HIDEHUD_CROSSHAIR       (1 << 8)
#define CVAR_FLAGS              FCVAR_PROTECTED

ConVar g_cvHidePlayers;

TopMenu hTopMenu;

ConVar g_cvCooldown;
ConVar g_cvSpeed;
ConVar g_cvEmotesSounds;
ConVar g_cvHideWeapons;
ConVar g_cvTeleportBack;

int g_iEmoteEnt[MAXPLAYERS+1];
int g_iEmoteSoundEnt[MAXPLAYERS+1];

int g_EmotesTarget[MAXPLAYERS+1];

char g_sEmoteSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];

bool g_bClientDancing[MAXPLAYERS+1];


Handle CooldownTimers[MAXPLAYERS+1];
bool g_bEmoteCooldown[MAXPLAYERS+1];

int g_iWeaponHandEnt[MAXPLAYERS+1];

Handle g_EmoteForward;
Handle g_EmoteForward_Pre;
bool g_bHooked[MAXPLAYERS + 1];

float g_fLastAngles[MAXPLAYERS+1][3];
float g_fLastPosition[MAXPLAYERS+1][3];


public Plugin myinfo =
{
  name = "[L4D2] Fortnite Emotes & Dances",
  author = "Kodua, Franc1sco franug, TheBO$$, Aleexxx, Foxhound, nearly civilized",
  description = "Animations from Fortnite in CS:GO/L4D2. New emotes ported by nearly civilized",
  version = "1.8.1",
  url = "https://forums.alliedmods.net/showthread.php?t=318981"
};

public void OnPluginStart()
{ 
  //LoadTranslations("common.phrases");
  //LoadTranslations("fnemotes_near.phrases");
  
  RegConsoleCmd("sm_emotes", Command_Menu);
  RegConsoleCmd("sm_emote", Command_Menu);
  RegConsoleCmd("sm_dances", Command_Menu); 
  RegConsoleCmd("sm_dance", Command_Menu);
  RegAdminCmd("sm_setemotes", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
  RegAdminCmd("sm_setemote", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
  RegAdminCmd("sm_setdances", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
  RegAdminCmd("sm_setdance", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");

  RegConsoleCmd("sm_doemote", Command_Do_Emotes, "[SM] Usage: sm_doemote [Emote ID]");
  RegConsoleCmd("sm_dodance", Command_Do_Emotes, "[SM] Usage: sm_dodance [Emote ID]");

  HookEvent("player_death",   Event_PlayerDeath,  EventHookMode_Pre);
  HookEvent("player_hurt",  Event_PlayerHurt,   EventHookMode_Pre);
  HookEvent("player_team",  Event_PlayerTeam,   EventHookMode_Pre);
  HookEvent("round_start",  Event_Start);
  
  /**
    Convars
  **/
  
  AutoExecConfig_SetFile("fortnite_emotes_nearlycivilized");

  g_cvEmotesSounds = AutoExecConfig_CreateConVar("sm_emotes_sounds", "1", "Enable/Disable sounds for emotes.", _, true, 0.0, true, 1.0);
  g_cvCooldown = AutoExecConfig_CreateConVar("sm_emotes_cooldown", "1.0", "Cooldown for emotes in seconds. -1 or 0 = no cooldown.");
  g_cvHideWeapons = AutoExecConfig_CreateConVar("sm_emotes_hide_weapons", "1", "Hide weapons when dancing", _, true, 0.0, true, 1.0);
  g_cvHidePlayers = AutoExecConfig_CreateConVar("sm_emotes_hide_enemies", "0", "Hide enemy players when dancing", _, true, 0.0, true, 1.0);
  g_cvTeleportBack = AutoExecConfig_CreateConVar("sm_emotes_teleportonend", "1", "Teleport back to the exact position when he started to dance. (Some maps need this for teleport triggers)", _, true, 0.0, true, 1.0);
  g_cvSpeed = CreateConVar("sm_emotes_speed", "0.84", "Sets the playback speed of the animation. default (1.0)", CVAR_FLAGS);
  
  AutoExecConfig_ExecuteFile();
  
  AutoExecConfig_CleanFile();
  
  /**
    End Convars
  **/

  TopMenu topmenu;
  if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
  {
    OnAdminMenuReady(topmenu);
  } 
  
  g_EmoteForward = CreateGlobalForward("fnemotes_OnEmote", ET_Ignore, Param_Cell);
  g_EmoteForward_Pre = CreateGlobalForward("fnemotes_OnEmote_Pre", ET_Event, Param_Cell);
}

public void OnPluginEnd()
{
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && g_bClientDancing[i]) {
      StopEmote(i);
    }
  }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  RegPluginLibrary("fnemotes");
  CreateNative("fnemotes_IsClientEmoting", Native_IsClientEmoting);
  return APLRes_Success;
}

public int Native_IsClientEmoting(Handle plugin, int numParams)
{
  return g_bClientDancing[GetNativeCell(1)];
}

public void OnMapStart()
{
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.mdl");
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.vvd");
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.dx90.vtx");

  // edit
  // add the sound file routes here
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/ninja_dance_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/dance_soldier_03.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/hip_hop_good_vibes_mix_01_loop.mp3");
  /*se añadira mas*/
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_zippy_A.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_electroshuffle_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_aerobics_01.mp3"); 
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_music_emotes_bendy.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_bandofthefort_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_boogiedown.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_capoeira.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_flapper_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_chicken_foley_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/bananacry.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_music_boneless.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emotes_music_shoot_v7.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emotes_music_swipeit.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_disco.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_worm_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_music_emotes_takethel.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_breakdance_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_dance_pump.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_ridethepony_music_01.mp3"); 
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_facepalm_foley_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emotes_onthehook_02.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_floss_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_flippnsexy.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_fresh_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_groove_jam_a.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/br_emote_shred_guitar_mix_03_loop.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_heelclick.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/s5_hiphop_breakin_132bmp_loop.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_hotstuff.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_hula_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_infinidab.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_intensity.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_irish_jig_foley_music_loop.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_music_emotes_koreaneagle.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_kpop_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_laugh_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_livinglarge_A.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_luchador.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_hillbilly_shuffle.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_samba_new_B.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_makeitrain_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_poplock.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_poprock_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_robot_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_salute_foley_01.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_snap1.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_stagebow.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_dino_complete.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_founders_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emotes_music_twist.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_warehouse.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/wiggle_music_loop.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_yeet.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/youre_awesome_emote_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emotes_lankylegs_loop_02.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/eastern_bloc_musc_setup_d.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_bandofthefort_music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_hot_music.mp3");

  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/smooth_moves.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/california_girls.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/thanos_twerk.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Psychic.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Vivid.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Deflated_Emote_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Art_Giant.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Autumn_Tea.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Comrade.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Downward.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Griddles_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_HotPink.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_JumpingJoy.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Just_Home_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Macaroon_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_NeverGonna.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Tour_Bus.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/pumpkin_dance.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Air_Guitar_Emote.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/distraction.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Emote_Blaster.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Headbanger_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Hitchhiker_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/ItsGoTime_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/KneeSlapper_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Showstopper_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Sprinkler_Music.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/gmod_select.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/pollo_dance.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/toastbust.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/lebronjame.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/cant_c_me.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/rollie_rollie.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/leave_the_door.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/unforgettable.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/scenariooo.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/dropit.mp3");

  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/bananacry.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/blowkiss.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/clapping.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/fishing.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/flexing.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/gogogo.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/iheartyou.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/jubilation.mp3");
  
    

  // this dont touch
  PrecacheModel("models/player/kodua/fnemotes_nearlycivilized.mdl", true);

  // edit
  // add mp3 files without sound/
  // add wav files with */
  PrecacheSound("kodua/fortnite_emotes/ninja_dance_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/dance_soldier_03.mp3");
  PrecacheSound("kodua/fortnite_emotes/hip_hop_good_vibes_mix_01_loop.mp3");
  /*se añadira mas*/
   PrecacheSound("kodua/fortnite_emotes/emote_zippy_A.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_electroshuffle_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_aerobics_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_music_emotes_bendy.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_bandofthefort_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_boogiedown.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_capoeira.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_flapper_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_chicken_foley_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/bananacry.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_music_boneless.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emotes_music_shoot_v7.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emotes_music_swipeit.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_disco.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_worm_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_music_emotes_takethel.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_breakdance_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_dance_pump.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_ridethepony_music_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_facepalm_foley_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emotes_onthehook_02.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_floss_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_flippnsexy.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_fresh_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_groove_jam_a.mp3");
  PrecacheSound("kodua/fortnite_emotes/br_emote_shred_guitar_mix_03_loop.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_heelclick.mp3");
  PrecacheSound("kodua/fortnite_emotes/s5_hiphop_breakin_132bmp_loop.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_hotstuff.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_hula_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_infinidab.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_intensity.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_irish_jig_foley_music_loop.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_music_emotes_koreaneagle.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_kpop_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_laugh_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_livinglarge_A.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_luchador.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_hillbilly_shuffle.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_samba_new_B.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_makeitrain_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_poplock.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_poprock_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_robot_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_salute_foley_01.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_snap1.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_stagebow.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_dino_complete.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_founders_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emotes_music_twist.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_warehouse.mp3");
  PrecacheSound("kodua/fortnite_emotes/wiggle_music_loop.mp3");
  PrecacheSound("kodua/fortnite_emotes/emote_yeet.mp3");
  PrecacheSound("kodua/fortnite_emotes/youre_awesome_emote_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emotes_lankylegs_loop_02.mp3");
  PrecacheSound("kodua/fortnite_emotes/eastern_bloc_musc_setup_d.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_bandofthefort_music.mp3");
  PrecacheSound("kodua/fortnite_emotes/athena_emote_hot_music.mp3");
  
  PrecacheSound("kodua/fortnite_emotes/smooth_moves.mp3");
  PrecacheSound("kodua/fortnite_emotes/california_girls.mp3");
  PrecacheSound("kodua/fortnite_emotes/thanos_twerk.mp3");
  PrecacheSound("kodua/fortnite_emotes/Psychic.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Vivid.mp3");
  PrecacheSound("kodua/fortnite_emotes/Deflated_Emote_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Art_Giant.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Autumn_Tea.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Comrade.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Downward.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Griddles_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_HotPink.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_JumpingJoy.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Just_Home_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Macaroon_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_NeverGonna.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Tour_Bus.mp3");
  PrecacheSound("kodua/fortnite_emotes/pumpkin_dance.mp3");
  PrecacheSound("kodua/fortnite_emotes/Air_Guitar_Emote.mp3");
  PrecacheSound("kodua/fortnite_emotes/distraction.mp3");
  PrecacheSound("kodua/fortnite_emotes/Emote_Blaster.mp3");
  PrecacheSound("kodua/fortnite_emotes/Headbanger_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Hitchhiker_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/ItsGoTime_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/KneeSlapper_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Showstopper_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/Sprinkler_Music.mp3");
  PrecacheSound("kodua/fortnite_emotes/gmod_select.mp3");
  PrecacheSound("kodua/fortnite_emotes/pollo_dance.mp3");
  PrecacheSound("kodua/fortnite_emotes/toastbust.mp3");
  PrecacheSound("kodua/fortnite_emotes/lebronjame.mp3");
  PrecacheSound("kodua/fortnite_emotes/cant_c_me.mp3");
  PrecacheSound("kodua/fortnite_emotes/rollie_rollie.mp3");
  PrecacheSound("kodua/fortnite_emotes/leave_the_door.mp3");
  PrecacheSound("kodua/fortnite_emotes/unforgettable.mp3");
  PrecacheSound("kodua/fortnite_emotes/scenariooo.mp3");
  PrecacheSound("kodua/fortnite_emotes/dropit.mp3");

  PrecacheSound("kodua/fortnite_emotes/bananacry.mp3");
  PrecacheSound("kodua/fortnite_emotes/blowkiss.mp3");
  PrecacheSound("kodua/fortnite_emotes/clapping.mp3");
  PrecacheSound("kodua/fortnite_emotes/fishing.mp3");
  PrecacheSound("kodua/fortnite_emotes/flexing.mp3");
  PrecacheSound("kodua/fortnite_emotes/gogogo.mp3");
  PrecacheSound("kodua/fortnite_emotes/iheartyou.mp3");
  PrecacheSound("kodua/fortnite_emotes/jubilation.mp3");
  
}


public void OnClientPutInServer(int client)
{
  if (IsValidClient(client))
  { 
    ResetCam(client);
    TerminateEmote(client);
    g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;

    if (CooldownTimers[client] != null)
    {
      KillTimer(CooldownTimers[client]);
    }
  }
}

public void OnClientDisconnect(int client)
{
  if (IsValidClient(client))
  {
    ResetCam(client);
    TerminateEmote(client);

    if (CooldownTimers[client] != null)
    {
      KillTimer(CooldownTimers[client]);
      CooldownTimers[client] = null;
      g_bEmoteCooldown[client] = false;
    }
  }
  g_bHooked[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (IsValidClient(client))
  {
    ResetCam(client);
    StopEmote(client);
  }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int client = GetClientOfUserId(event.GetInt("userid"));
  if(GetPlayerTeam(attacker) != GetPlayerTeam(client)) {
    StopEmote(client);
  }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  StopEmote(client);
}

public int GetPlayerTeam(int player) {
  return IsValidClient(player) ? GetClientTeam(player) : 0;
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i, false) && g_bClientDancing[i]) {
      ResetCam(i);
      StopEmote(i);
      WeaponUnblock(i);
      g_bClientDancing[i] = false;
    }
  }
}

public Action Command_Menu(int client, int args)
{
  if (!IsValidClient(client))
    return Plugin_Handled;
  
  Menu_Dance(client);

  return Plugin_Handled;
}

public Action CreateEmote(int client, const char[] anim1, const char[] anim2, const char[] soundName, bool isLooped)
{
  if (!IsValidClient(client))
    return Plugin_Handled;
  
  if(g_EmoteForward_Pre != null)
  {
    Action res = Plugin_Continue;
    Call_StartForward(g_EmoteForward_Pre);
    Call_PushCell(client);
    Call_Finish(res);

    if (res != Plugin_Continue)
    {
      return Plugin_Handled;
    }
  }
  
  if (!IsPlayerAlive(client) || bIsPlayerIncapped(client))
  {
    CReplyToCommand(client, "Debes estar vivo para usar emotes");
    return Plugin_Handled;
  }

  if (!(GetEntityFlags(client) & FL_ONGROUND))
  {
    CReplyToCommand(client,"Debes estar en el suelo");
    return Plugin_Handled;
  }
  
  if (CooldownTimers[client] != null)
  {
    CReplyToCommand(client,"Espera antes de usar otro emote");
    return Plugin_Handled;
  }

  if (StrEqual(anim1, ""))
  {
    CReplyToCommand(client, "Animación inválida");
    return Plugin_Handled;
  }

  if (g_iEmoteEnt[client] != 0)
    StopEmote(client);

  if (GetEntityMoveType(client) == MOVETYPE_NONE)
  {
    CReplyToCommand(client, "No puedes usar emotes ahora");
    return Plugin_Handled;
  }

  int EmoteEnt = CreateEntityByName("prop_dynamic");
  if (IsValidEntity(EmoteEnt))
  {
    SetEntityMoveType(client, MOVETYPE_NONE);
    WeaponBlock(client);

    float vec[3], ang[3];
    GetClientAbsOrigin(client, vec);
    GetClientAbsAngles(client, ang);
    
    g_fLastPosition[client] = vec;
    g_fLastAngles[client] = ang;

    char emoteEntName[16];
    FormatEx(emoteEntName, sizeof(emoteEntName), "emoteEnt%i", GetRandomInt(1000000, 9999999));
    
    DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
    DispatchKeyValue(EmoteEnt, "model", "models/player/kodua/fnemotes_nearlycivilized.mdl");
    DispatchKeyValue(EmoteEnt, "solid", "0");
    DispatchKeyValue(EmoteEnt, "rendermode", "10");

    ActivateEntity(EmoteEnt);
    DispatchSpawn(EmoteEnt);

    TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);
    
    SetVariantString(emoteEntName);
    AcceptEntityInput(client, "SetParent", client, client, 0);

    g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);

    SetEntProp(client, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);

    //Sound

    if (g_cvEmotesSounds.BoolValue && !StrEqual(soundName, ""))
    {
      int EmoteSoundEnt = CreateEntityByName("info_target");
      if (IsValidEntity(EmoteSoundEnt))
      {
        char soundEntName[16];
        FormatEx(soundEntName, sizeof(soundEntName), "soundEnt%i", GetRandomInt(1000000, 9999999));

        DispatchKeyValue(EmoteSoundEnt, "targetname", soundEntName);

        DispatchSpawn(EmoteSoundEnt);

        vec[2] += 72.0;
        TeleportEntity(EmoteSoundEnt, vec, NULL_VECTOR, NULL_VECTOR);

        SetVariantString(emoteEntName);
        AcceptEntityInput(EmoteSoundEnt, "SetParent");

        g_iEmoteSoundEnt[client] = EntIndexToEntRef(EmoteSoundEnt);

        //Formatting sound path

        char soundNameBuffer[64];

        if (StrEqual(soundName, "ninja_dance_01") || StrEqual(soundName, "dance_soldier_03"))
        {
          int randomSound = GetRandomInt(0, 1);
          if(randomSound)
          {
            strcopy(soundNameBuffer, sizeof(soundNameBuffer), "ninja_dance_01");
          } else
          {
            strcopy(soundNameBuffer, sizeof(soundNameBuffer), "dance_soldier_03");
          }
        } else
        {
          FormatEx(soundNameBuffer, sizeof(soundNameBuffer), "%s", soundName);
        }

        FormatEx(g_sEmoteSound[client], PLATFORM_MAX_PATH, "kodua/fortnite_emotes/%s.mp3", soundNameBuffer);

        EmitSoundToAll(g_sEmoteSound[client], client, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
      }
    }
    else
    {
      g_sEmoteSound[client][0] = '\0';
    }

    if (StrEqual(anim2, "none", false))
    {
      HookSingleEntityOutput(EmoteEnt, "OnAnimationDone", EndAnimation, true);
    }
    else
    {
      SetVariantString(anim2);
      AcceptEntityInput(EmoteEnt, "SetDefaultAnimation", -1, -1, 0);
    }

    SetVariantString(anim1);
    AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);

    SetCam(client);

    if(g_cvSpeed.FloatValue!=1.0) SetEntPropFloat(EmoteEnt, Prop_Send, "m_flPlaybackRate", g_cvSpeed.FloatValue);

    g_bClientDancing[client] = true;
    
    if(g_cvHidePlayers.BoolValue)
    {
      for(int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && !g_bHooked[i])
        {
          SDKHook(i, SDKHook_SetTransmit, SetTransmit);
          g_bHooked[i] = true;
        }
    }

    if (g_cvCooldown.FloatValue > 0.0)
    {
      CooldownTimers[client] = CreateTimer(g_cvCooldown.FloatValue, ResetCooldown, client);
    }
    
    if(g_EmoteForward != null)
    {
      Call_StartForward(g_EmoteForward);
      Call_PushCell(client);
      Call_Finish();
    }
  }
  
  return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
  if (IsNonElevatorMap())
  {
    if (g_bClientDancing[client] && !(GetEntityFlags(client) & FL_ONGROUND))
    {
      StopEmote(client);
    }
  }
  else
  {
    {
    if (g_bClientDancing[client] && !(GetEntityFlags(client) & FL_ONGROUND))
    {
      StopEmote(client);
    }
  }
  }

  static int iAllowedButtons = IN_BACK | IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT | IN_WALK | IN_SPEED | IN_SCORE;

  if (iButtons == 0)
    return Plugin_Continue;

  if (g_iEmoteEnt[client] == 0)
    return Plugin_Continue;

  if ((iButtons & iAllowedButtons) && !(iButtons &~ iAllowedButtons)) 
    return Plugin_Continue;

  StopEmote(client);

  return Plugin_Continue;
}

public void EndAnimation(const char[] output, int caller, int activator, float delay) 
{
  if (caller > 0)
  {
    activator = GetEmoteActivator(EntIndexToEntRef(caller));
    StopEmote(activator);
  }
}

public int GetEmoteActivator(int iEntRefDancer)
{
  if (iEntRefDancer == INVALID_ENT_REFERENCE)
    return 0;
  
  for (int i = 1; i <= MaxClients; i++) 
  {
    if (g_iEmoteEnt[i] == iEntRefDancer) 
    {
      return i;
    }
  }
  return 0;
}

public void StopEmote(int client)
{
  if (g_iEmoteEnt[client] == 0)
    return;

  int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
  if (iEmoteEnt != 0 && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt))
  {
    char emoteEntName[50];
    GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
    SetVariantString(emoteEntName);
    AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
    DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
    AcceptEntityInput(iEmoteEnt, "FireUser1");
    
    if(g_cvTeleportBack.BoolValue)
      TeleportEntity(client, g_fLastPosition[client], g_fLastAngles[client], NULL_VECTOR);
    
    ResetCam(client);
    WeaponUnblock(client);
    SetEntityMoveType(client, MOVETYPE_WALK);

    g_iEmoteEnt[client] = 0;
    g_bClientDancing[client] = false;
  } else
  {
    g_iEmoteEnt[client] = 0;
    g_bClientDancing[client] = false;
  }

  if (g_iEmoteSoundEnt[client] != 0)
  {
    int iEmoteSoundEnt = EntRefToEntIndex(g_iEmoteSoundEnt[client]);

    if (!StrEqual(g_sEmoteSound[client], "") && iEmoteSoundEnt != 0 && iEmoteSoundEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteSoundEnt))
    {
      StopSound(client, SNDCHAN_AUTO, g_sEmoteSound[client]);
      AcceptEntityInput(iEmoteSoundEnt, "Kill");
      g_iEmoteSoundEnt[client] = 0;
    }
    else
    {
      g_iEmoteSoundEnt[client] = 0;
    }
  }
}

public void TerminateEmote(int client)
{
  if (g_iEmoteEnt[client] == 0)
    return;

  int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
  if (iEmoteEnt != 0 && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt))
  {
    char emoteEntName[50];
    GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
    SetVariantString(emoteEntName);
    AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
    DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
    AcceptEntityInput(iEmoteEnt, "FireUser1");

    g_iEmoteEnt[client] = 0;
    g_bClientDancing[client] = false;
  } else
  {
    g_iEmoteEnt[client] = 0;
    g_bClientDancing[client] = false;
  }

  if (g_iEmoteSoundEnt[client] != 0)
  {
    int iEmoteSoundEnt = EntRefToEntIndex(g_iEmoteSoundEnt[client]);

    if (!StrEqual(g_sEmoteSound[client], "") && iEmoteSoundEnt != 0 && iEmoteSoundEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteSoundEnt))
    {
      StopSound(client, SNDCHAN_AUTO, g_sEmoteSound[client]);
      AcceptEntityInput(iEmoteSoundEnt, "Kill");
      g_iEmoteSoundEnt[client] = 0;
    }
    else
    {
      g_iEmoteSoundEnt[client] = 0;
    }
  }
}

public void WeaponBlock(int client)
{
  SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
  SDKHook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
  
  if(g_cvHideWeapons.BoolValue)
    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
    
  int iEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(iEnt != -1)
  {
    g_iWeaponHandEnt[client] = EntIndexToEntRef(iEnt);
    
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
  }
}

public void WeaponUnblock(int client)
{
  SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
  SDKUnhook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
  
  //Even if are not activated, there will be no errors
  SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
  
  if(GetEmotePeople() == 0)
  {
    for(int i = 1; i <= MaxClients; i++)
      if (IsClientInGame(i) && g_bHooked[i])
      {
        SDKUnhook(i, SDKHook_SetTransmit, SetTransmit);
        g_bHooked[i] = false;
      }
  }
  
  if(IsPlayerAlive(client) && g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE)
  {
    int iEnt = EntRefToEntIndex(g_iWeaponHandEnt[client]);
    if(iEnt != INVALID_ENT_REFERENCE)
    {
      SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
    }
  }
  
  g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;
}

public Action WeaponCanUseSwitch(int client, int weapon)
{
  return Plugin_Stop;
}

public void OnPostThinkPost(int client)
{
  SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action SetTransmit(int entity, int client) 
{ 
  if(g_bClientDancing[client] && IsPlayerAlive(client) && GetClientTeam(client) != GetClientTeam(entity)) return Plugin_Handled;
  
  return Plugin_Continue; 
} 

public void SetCam(int client)
{
  SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
  SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_CROSSHAIR);
}

public void ResetCam(int client)
{
  SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);
  SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_CROSSHAIR);
}

public Action ResetCooldown(Handle timer, any client)
{
  CooldownTimers[client] = null;
  return Plugin_Stop;
}

public Action Menu_Dance(int client)
{
  Menu menu = new Menu(MenuHandler1);

  char title[65];
  Format(title, sizeof(title),  "Menú de Emotes y Bailes");
  menu.SetTitle(title); 

  menu.AddItem("", "Emote aleatorio");
  menu.AddItem("", "Baile alatorio");
  menu.AddItem("", "Lista de emotes");
  menu.AddItem("", "Lista de bailes");
  
  menu.ExitButton = true;
  menu.ExitBackButton = false;
  menu.Display(client, MENU_TIME_FOREVER);
 
  return Plugin_Handled;
}

public int MenuHandler1(Menu menu, MenuAction action, int param1, int param2)
{
  switch (action)
  {   
    case MenuAction_Select:
    {
      int client = param1;
      
      switch (param2)
      {
        case 0: 
        {
          RandomEmote(client);
          Menu_Dance(client);
        }
        case 1: 
        {
          RandomDance(client);
          Menu_Dance(client);
        }   
        case 2:
        {
          EmotesMenu(client);
        }
        case 3:
        {
          DancesMenu(client);
        }
      }
    }
    case MenuAction_End:
    {
      delete menu;
    }
  }
  return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////
//Emotes Menu
////////////////////////////////////////////////////////////////////////////////////////////

public Action EmotesMenu(int client)
{
  Menu menu = new Menu(MenuHandlerEmotes);
  
  char title[65];
  Format(title, sizeof(title), "Menu de Emotes");
  menu.SetTitle(title); 

  menu.AddItem("1", "Emote_Fonzie_Pistol");
  menu.AddItem("2", "Emote_Bring_It_On");
  menu.AddItem("3", "Emote_ThumbsDown");
  menu.AddItem("4", "Emote_ThumbsUp");
  menu.AddItem("5", "Emote_Celebration_Loop");
  menu.AddItem("6", "Emote_BlowKiss");
  menu.AddItem("7", "Emote_Calculated");
  menu.AddItem("8", "Emote_Confused");
  menu.AddItem("9", "Emote_Chug");
  menu.AddItem("10", "Emote_Cry");
  menu.AddItem("11", "Emote_DustingOffHands");
  menu.AddItem("12", "Emote_DustOffShoulders");
  menu.AddItem("13", "Emote_Facepalm");
  menu.AddItem("14", "Emote_Fishing");
  menu.AddItem("15", "Emote_Flex");
  menu.AddItem("16", "Emote_golfclap");
  menu.AddItem("17", "Emote_HandSignals");
  menu.AddItem("18", "Emote_HeelClick");
  menu.AddItem("19", "Emote_Hotstuff");
  menu.AddItem("20", "Emote_IBreakYou");
  menu.AddItem("21", "Emote_IHeartYou");
  menu.AddItem("22", "Emote_Kung-Fu_Salute");
  menu.AddItem("23", "Emote_Laugh");
  menu.AddItem("24", "Emote_Luchador");
  menu.AddItem("25", "Emote_Make_It_Rain");
  menu.AddItem("26", "Emote_NotToday");
  menu.AddItem("27", "Emote_RockPaperScissor_Paper");
  menu.AddItem("28", "Emote_RockPaperScissor_Rock");
  menu.AddItem("29", "Emote_RockPaperScissor_Scissor");
  menu.AddItem("30", "Emote_Salt");
  menu.AddItem("31", "Emote_Salute");
  menu.AddItem("32", "Emote_Snap");
  menu.AddItem("33", "Emote_StageBow");
  menu.AddItem("34", "Emote_Wave2");
  menu.AddItem("35", "Emote_Yeet");
  menu.AddItem("36", "Emote_Cena");
  menu.AddItem("37", "Emote_Lebron");


  

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
 
  return Plugin_Handled;
}

public Menu CreateEmotesMenuAtPosition()
{
  Menu menu = new Menu(MenuHandlerEmotes);
  
  char title[65];
  Format(title, sizeof(title), "Menu de Emotes");
  menu.SetTitle(title); 

  menu.AddItem("1", "Emote_Fonzie_Pistol");
  menu.AddItem("2", "Emote_Bring_It_On");
  menu.AddItem("3", "Emote_ThumbsDown");
  menu.AddItem("4", "Emote_ThumbsUp");
  menu.AddItem("5", "Emote_Celebration_Loop");
  menu.AddItem("6", "Emote_BlowKiss");
  menu.AddItem("7", "Emote_Calculated");
  menu.AddItem("8", "Emote_Confused");
  menu.AddItem("9", "Emote_Chug");
  menu.AddItem("10", "Emote_Cry");
  menu.AddItem("11", "Emote_DustingOffHands");
  menu.AddItem("12", "Emote_DustOffShoulders");
  menu.AddItem("13", "Emote_Facepalm");
  menu.AddItem("14", "Emote_Fishing");
  menu.AddItem("15", "Emote_Flex");
  menu.AddItem("16", "Emote_golfclap");
  menu.AddItem("17", "Emote_HandSignals");
  menu.AddItem("18", "Emote_HeelClick");
  menu.AddItem("19", "Emote_Hotstuff");
  menu.AddItem("20", "Emote_IBreakYou");
  menu.AddItem("21", "Emote_IHeartYou");
  menu.AddItem("22", "Emote_Kung-Fu_Salute");
  menu.AddItem("23", "Emote_Laugh");
  menu.AddItem("24", "Emote_Luchador");
  menu.AddItem("25", "Emote_Make_It_Rain");
  menu.AddItem("26", "Emote_NotToday");
  menu.AddItem("27", "Emote_RockPaperScissor_Paper");
  menu.AddItem("28", "Emote_RockPaperScissor_Rock");
  menu.AddItem("29", "Emote_RockPaperScissor_Scissor");
  menu.AddItem("30", "Emote_Salt");
  menu.AddItem("31", "Emote_Salute");
  menu.AddItem("32", "Emote_Snap");
  menu.AddItem("33", "Emote_StageBow");
  menu.AddItem("34", "Emote_Wave2");
  menu.AddItem("35", "Emote_Yeet");
  menu.AddItem("36", "Emote_Cena");
  menu.AddItem("37", "Emote_Lebron");

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  
  return menu;
}

public int MenuHandlerEmotes(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    int currentPosition = GetMenuSelectionPosition();
    char info[16];
    if (menu.GetItem(param2, info, sizeof(info)))
    {
        int iParam2 = StringToInt(info);
        


        if (iParam2 == 1)
        {
            CreateEmote(client, "Emote_Fonzie_Pistol", "none", "", false);
        }
        else if (iParam2 == 2)
        {
            CreateEmote(client, "Emote_Bring_It_On", "none", "", false);
        }
        else if (iParam2 == 3)
        {
            CreateEmote(client, "Emote_ThumbsDown", "none", "", false);
        }
        else if (iParam2 == 4)
        {
            CreateEmote(client, "Emote_ThumbsUp", "none", "", false);
        }
        else if (iParam2 == 5)
        {
            CreateEmote(client, "Emote_Celebration_Loop", "", "jubilation", false);
        }
        else if (iParam2 == 6)
        {
            CreateEmote(client, "Emote_BlowKiss", "none", "blowkiss", false);
        }
        else if (iParam2 == 7)
        {
            CreateEmote(client, "Emote_Calculated", "none", "", false);
        }
        else if (iParam2 == 8)
        {
            CreateEmote(client, "Emote_Confused", "none", "", false);
        }
        else if (iParam2 == 9)
        {
            CreateEmote(client, "Emote_Chug", "none", "gogogo", false);
        }
        else if (iParam2 == 10)
        {
            CreateEmote(client, "Emote_Cry", "none", "bananacry", false);
        }
        else if (iParam2 == 11)
        {
            CreateEmote(client, "Emote_DustingOffHands", "none", "", true);
        }
        else if (iParam2 == 12)
        {
            CreateEmote(client, "Emote_DustOffShoulders", "none", "athena_emote_hot_music", true);
        }
        else if (iParam2 == 13)
        {
            CreateEmote(client, "Emote_Facepalm", "none", "athena_emote_facepalm_foley_01", false);
        }
        else if (iParam2 == 14)
        {
            CreateEmote(client, "Emote_Fishing", "none", "fishing", false);
        }
        else if (iParam2 == 15)
        {
            CreateEmote(client, "Emote_Flex", "none", "flexing", false);
        }
        else if (iParam2 == 16)
        {
            CreateEmote(client, "Emote_golfclap", "none", "clapping", false);
        }
        else if (iParam2 == 17)
        {
            CreateEmote(client, "Emote_HandSignals", "none", "", false);
        }
        else if (iParam2 == 18)
        {
            CreateEmote(client, "Emote_HeelClick", "none", "emote_heelclick", false);
        }
        else if (iParam2 == 19)
        {
            CreateEmote(client, "Emote_Hotstuff", "none", "emote_hotstuff", false);
        }
        else if (iParam2 == 20)
        {
            CreateEmote(client, "Emote_IBreakYou", "none", "", false);
        }
        else if (iParam2 == 21)
        {
            CreateEmote(client, "Emote_IHeartYou", "none", "iheartyou", false);
        }
        else if (iParam2 == 22)
        {
            CreateEmote(client, "Emote_Kung-Fu_Salute", "none", "", false);
        }
        else if (iParam2 == 23)
        {
            CreateEmote(client, "Emote_Laugh", "Emote_Laugh_CT", "emote_laugh_01", false);
        }
        else if (iParam2 == 24)
        {
            CreateEmote(client, "Emote_Luchador", "none", "emote_luchador", false);
        }
        else if (iParam2 == 25)
        {
            CreateEmote(client, "Emote_Make_It_Rain", "none", "athena_emote_makeitrain_music", false);
        }
        else if (iParam2 == 26)
        {
            CreateEmote(client, "Emote_NotToday", "none", "", false);
        }
        else if (iParam2 == 27)
        {
            CreateEmote(client, "Emote_RockPaperScissor_Paper", "none", "", false);
        }
        else if (iParam2 == 28)
        {
            CreateEmote(client, "Emote_RockPaperScissor_Rock", "none", "", false);
        }
        else if (iParam2 == 29)
        {
            CreateEmote(client, "Emote_RockPaperScissor_Scissor", "none", "", false);
        }
        else if (iParam2 == 30)
        {
            CreateEmote(client, "Emote_Salt", "none", "", false);
        }
        else if (iParam2 == 31)
        {
            CreateEmote(client, "Emote_Salute", "none", "athena_emote_salute_foley_01", false);
        }
        else if (iParam2 == 32)
        {
            CreateEmote(client, "Emote_Snap", "none", "emote_snap1", false);
        }
        else if (iParam2 == 33)
        {
            CreateEmote(client, "Emote_StageBow", "none", "emote_stagebow", false);
        }
        else if (iParam2 == 34)
        {
            CreateEmote(client, "Emote_Wave2", "none", "", false);
        }
        else if (iParam2 == 35)
        {
            CreateEmote(client, "Emote_Yeet", "none", "emote_yeet", false);
        }
        else if (iParam2 == 36)
        {
            CreateEmote(client, "Emote_Cena", "none", "cant_c_me", false);
        }
        else if (iParam2 == 37)
        {
            CreateEmote(client, "Emote_Lebron", "none", "lebronjame", false);
        }
    }
    Menu newMenu = CreateEmotesMenuAtPosition();
    newMenu.DisplayAt(client, currentPosition, MENU_TIME_FOREVER);
    //EmotesMenu(client);
    return 0;
  }
  else if(action == MenuAction_Cancel)
  {
    if(param2 == MenuCancel_ExitBack)
    {
      Menu_Dance(client);
    }
  }
  else if(action == MenuAction_End){
    delete menu;
  }
  return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////
//Dances Menu
////////////////////////////////////////////////////////////////////////////////////////////

public Action DancesMenu(int client)
{
  Menu menu = new Menu(MenuHandlerDances);
  
  char title[65];
  Format(title, sizeof(title), "Menu de Bailes");
  menu.SetTitle(title); 
  
  menu.AddItem("1", "Movimientos de Baile");
  menu.AddItem("2", "Justicia Naranja");
  menu.AddItem("3", "Bullicioso");
  menu.AddItem("4", "Shuffle Electrónico");
  menu.AddItem("5", "Aeróbico");
  menu.AddItem("6", "Flexible");
  menu.AddItem("7", "Mejores Amigos");
  menu.AddItem("8", "Boogie");
  menu.AddItem("9", "Capoeira");
  menu.AddItem("10", "A la Moda");
  menu.AddItem("11", "Pollo");
  menu.AddItem("12", "Sin Huesos");
  menu.AddItem("13", "Bombo");
  menu.AddItem("14", "Muévelo");
  menu.AddItem("15", "Disco para Siempre");
  menu.AddItem("16", "Disco para Siempre 2");
  menu.AddItem("17", "El Gusano");
  menu.AddItem("18", "Toma La L");
  menu.AddItem("19", "BreakDance");
  menu.AddItem("20", "Bomba");
  menu.AddItem("21", "Monta Al Pony");
  menu.AddItem("22", "Dab");
  menu.AddItem("23", "Bloque Oriental");
  menu.AddItem("24", "Pies de Suelo");
  menu.AddItem("25", "Hilo Dental");
  menu.AddItem("26", "Flippin Sexy");
  menu.AddItem("27", "Fresco");
  menu.AddItem("28", "Grefg");
  menu.AddItem("29", "Guitarra");
  menu.AddItem("30", "Shuffle");
  menu.AddItem("31", "Hip Hop");
  menu.AddItem("32", "Hula Hop");
  menu.AddItem("33", "Dab Infinito");
  menu.AddItem("34", "Intensidad");
  menu.AddItem("35", "Dabke Turco");
  menu.AddItem("36", "Águila");
  menu.AddItem("37", "Corazón Verdadero");
  menu.AddItem("38", "Viviendo a lo Grande");
  menu.AddItem("39", "Maracas");
  menu.AddItem("40", "Pop Lock");
  menu.AddItem("41", "Poder Estelar");
  menu.AddItem("42", "Robot");
  menu.AddItem("43", "T-Rex");
  menu.AddItem("44", "Reanimado");
  menu.AddItem("45", "Twist");
  menu.AddItem("46", "Almacén");
  menu.AddItem("47", "Meneo");
  menu.AddItem("48", "Eres Increíble");
  menu.AddItem("49", "Smooth Moves");
  menu.AddItem("50", "California Girls");
  menu.AddItem("51", "Thanos Twerk");
  menu.AddItem("52", "Gangnam Style");
  menu.AddItem("53", "In Da Ghetto");
  menu.AddItem("54", "Blinding Lights");
  menu.AddItem("55", "Griddy");
  menu.AddItem("56", "I Like To Move It");
  menu.AddItem("57", "Macarena");
  menu.AddItem("58", "Never Gonna");
  menu.AddItem("59", "Ninja Style");
  menu.AddItem("60", "Pumpkin Dance");
  menu.AddItem("61", "Pump Up The Jam");
  menu.AddItem("62", "Renegade");
  menu.AddItem("63", "Rushin Around");
  menu.AddItem("64", "Say So");
  menu.AddItem("65", "Stuck");
  menu.AddItem("66", "Toosie Slide");
  menu.AddItem("67", "Air Shredder");
  menu.AddItem("68", "Crossbounce");
  menu.AddItem("69", "Distraction Dance");
  menu.AddItem("70", "Headbanger");
  menu.AddItem("71", "Hitchhiker");
  menu.AddItem("72", "It's Go Time");
  menu.AddItem("73", "Knee Slapper");
  menu.AddItem("74", "Showstopper");
  menu.AddItem("75", "Sprinkler");
  menu.AddItem("76", "Garry's Mod");
  menu.AddItem("77", "Chicken Dance");
  menu.AddItem("78", "I Ain't Afraid");
  menu.AddItem("79", "Leave The Door Open");
  menu.AddItem("80", "Forget Me Not");
  menu.AddItem("81", "Rollie");
  menu.AddItem("82", "Scenario");
  menu.AddItem("83", "T Pose");
  menu.AddItem("84", "Conducir Coche");


  
  
  

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
 
  return Plugin_Handled;
}

public Menu CreateDancesMenuAtPosition()
{
  Menu menu = new Menu(MenuHandlerDances);
  
  char title[65];
  Format(title, sizeof(title), "Menu de Bailes");
  menu.SetTitle(title); 
  
  menu.AddItem("1", "Movimientos de Baile");
  menu.AddItem("2", "Justicia Naranja");
  menu.AddItem("3", "Bullicioso");
  menu.AddItem("4", "Shuffle Electrónico");
  menu.AddItem("5", "Aeróbico");
  menu.AddItem("6", "Flexible");
  menu.AddItem("7", "Mejores Amigos");
  menu.AddItem("8", "Boogie");
  menu.AddItem("9", "Capoeira");
  menu.AddItem("10", "A la Moda");
  menu.AddItem("11", "Pollo");
  menu.AddItem("12", "Sin Huesos");
  menu.AddItem("13", "Bombo");
  menu.AddItem("14", "Muévelo");
  menu.AddItem("15", "Disco para Siempre");
  menu.AddItem("16", "Disco para Siempre 2");
  menu.AddItem("17", "El Gusano");
  menu.AddItem("18", "Toma La L");
  menu.AddItem("19", "BreakDance");
  menu.AddItem("20", "Bomba");
  menu.AddItem("21", "Monta Al Pony");
  menu.AddItem("22", "Dab");
  menu.AddItem("23", "Bloque Oriental");
  menu.AddItem("24", "Pies de Suelo");
  menu.AddItem("25", "Hilo Dental");
  menu.AddItem("26", "Flippin Sexy");
  menu.AddItem("27", "Fresco");
  menu.AddItem("28", "Grefg");
  menu.AddItem("29", "Guitarra");
  menu.AddItem("30", "Shuffle");
  menu.AddItem("31", "Hip Hop");
  menu.AddItem("32", "Hula Hop");
  menu.AddItem("33", "Dab Infinito");
  menu.AddItem("34", "Intensidad");
  menu.AddItem("35", "Dabke Turco");
  menu.AddItem("36", "Águila");
  menu.AddItem("37", "Corazón Verdadero");
  menu.AddItem("38", "Viviendo a lo Grande");
  menu.AddItem("39", "Maracas");
  menu.AddItem("40", "Pop Lock");
  menu.AddItem("41", "Poder Estelar");
  menu.AddItem("42", "Robot");
  menu.AddItem("43", "T-Rex");
  menu.AddItem("44", "Reanimado");
  menu.AddItem("45", "Twist");
  menu.AddItem("46", "Almacén");
  menu.AddItem("47", "Meneo");
  menu.AddItem("48", "Eres Increíble");
  menu.AddItem("49", "Smooth Moves");
  menu.AddItem("50", "California Girls");
  menu.AddItem("51", "Thanos Twerk");
  menu.AddItem("52", "Gangnam Style");
  menu.AddItem("53", "In Da Ghetto");
  menu.AddItem("54", "Blinding Lights");
  menu.AddItem("55", "Griddy");
  menu.AddItem("56", "I Like To Move It");
  menu.AddItem("57", "Macarena");
  menu.AddItem("58", "Never Gonna");
  menu.AddItem("59", "Ninja Style");
  menu.AddItem("60", "Pumpkin Dance");
  menu.AddItem("61", "Pump Up The Jam");
  menu.AddItem("62", "Renegade");
  menu.AddItem("63", "Rushin Around");
  menu.AddItem("64", "Say So");
  menu.AddItem("65", "Stuck");
  menu.AddItem("66", "Toosie Slide");
  menu.AddItem("67", "Air Shredder");
  menu.AddItem("68", "Crossbounce");
  menu.AddItem("69", "Distraction Dance");
  menu.AddItem("70", "Headbanger");
  menu.AddItem("71", "Hitchhiker");
  menu.AddItem("72", "It's Go Time");
  menu.AddItem("73", "Knee Slapper");
  menu.AddItem("74", "Showstopper");
  menu.AddItem("75", "Sprinkler");
  menu.AddItem("76", "Garry's Mod");
  menu.AddItem("77", "Chicken Dance");
  menu.AddItem("78", "I Ain't Afraid");
  menu.AddItem("79", "Leave The Door Open");
  menu.AddItem("80", "Forget Me Not");
  menu.AddItem("81", "Rollie");
  menu.AddItem("82", "Scenario");
  menu.AddItem("83", "T Pose");
  menu.AddItem("84", "Conducir Coche");


  menu.ExitButton = true;
  menu.ExitBackButton = true;
  
  return menu;
}

public int MenuHandlerDances(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    int currentPosition = GetMenuSelectionPosition();
    char info[16];
    if(menu.GetItem(param2, info, sizeof(info)))
    {
      int iParam2 = StringToInt(info);
      

      if (iParam2 == 1)
      {
          CreateEmote(client, "DanceMoves", "none", "ninja_dance_01", false);
      }
      else if (iParam2 == 2)
      {
          CreateEmote(client, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", "hip_hop_good_vibes_mix_01_loop", true);
      }
      else if (iParam2 == 3)
      {
          CreateEmote(client, "Emote_Zippy_Dance", "none", "emote_zippy_A", true);
      }
      else if (iParam2 == 4)
      {
          CreateEmote(client, "ElectroShuffle", "none", "athena_emote_electroshuffle_music", true);
      }
      else if (iParam2 == 5)
      {
          CreateEmote(client, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
      }
      else if (iParam2 == 6)
      {
          CreateEmote(client, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);
      }
      else if (iParam2 == 7)
      {
          CreateEmote(client, "Emote_BandOfTheFort", "none", "athena_emote_bandofthefort_music", true);
      }
      else if (iParam2 == 8)
      {
          CreateEmote(client, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true);
      }
      else if (iParam2 == 9)
      {
          CreateEmote(client, "Emote_Capoeira", "none", "emote_capoeira", false);
      }
      else if (iParam2 == 10)
      {
          CreateEmote(client, "Emote_Charleston", "none", "athena_emote_flapper_music", true);
      }
      else if (iParam2 == 11)
      {
          CreateEmote(client, "Emote_Chicken", "none", "athena_emote_chicken_foley_01", true);
      }
      else if (iParam2 == 12)
      {
          CreateEmote(client, "Emote_Dance_NoBones", "none", "athena_emote_music_boneless", true);
      }
      else if (iParam2 == 13)
      {
          CreateEmote(client, "Emote_Dance_Shoot", "none", "athena_emotes_music_shoot_v7", true);
      }
      else if (iParam2 == 14)
      {
          CreateEmote(client, "Emote_Dance_SwipeIt", "none", "athena_emotes_music_swipeit", true);
      }
      else if (iParam2 == 15)
      {
          CreateEmote(client, "Emote_Dance_Disco_T3", "none", "athena_emote_disco", true);
      }
      else if (iParam2 == 16)
      {
          CreateEmote(client, "Emote_DG_Disco", "none", "athena_emote_disco", true);
      }
      else if (iParam2 == 17)
      {
          CreateEmote(client, "Emote_Dance_Worm", "none", "athena_emote_worm_music", false);
      }
      else if (iParam2 == 18)
      {
          CreateEmote(client, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", "athena_music_emotes_takethel", true);
      }
      else if (iParam2 == 19)
      {
          CreateEmote(client, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
      }
      else if (iParam2 == 20)
      {
          CreateEmote(client, "Emote_Dance_Pump", "none", "emote_groove_jam_a", true);
      }
      else if (iParam2 == 21)
      {
          CreateEmote(client, "Emote_Dance_RideThePony", "none", "athena_emote_ridethepony_music_01", false);
      }
      else if (iParam2 == 22)
      {
          CreateEmote(client, "Emote_Dab", "none", "", false);
      }
      else if (iParam2 == 23)
      {
          CreateEmote(client, "Emote_EasternBloc_Start", "Emote_EasternBloc", "eastern_bloc_musc_setup_d", true);
      }
      else if (iParam2 == 24)
      {
          CreateEmote(client, "Emote_FancyFeet", "Emote_FancyFeet_CT", "athena_emotes_lankylegs_loop_02", true);
      }
      else if (iParam2 == 25)
      {
          CreateEmote(client, "Emote_FlossDance", "none", "athena_emote_floss_music", true);
      }
      else if (iParam2 == 26)
      {
          CreateEmote(client, "Emote_FlippnSexy", "none", "emote_flippnSexy", false);
      }
      else if (iParam2 == 27)
      {
          CreateEmote(client, "Emote_Fresh", "none", "athena_emote_fresh_music", true);
      }
      else if (iParam2 == 28)
      {
          CreateEmote(client, "Emote_GrooveJam", "none", "emote_groove_jam_a", true);
      }
      else if (iParam2 == 29)
      {
          CreateEmote(client, "Emote_guitar", "none", "br_emote_shred_guitar_mix_03_loop", true);
      }
      else if (iParam2 == 30)
      {
          CreateEmote(client, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", "emote_hillbilly_shuffle", true);
      }
      else if (iParam2 == 31)
      {
          CreateEmote(client, "Emote_Hiphop_01", "Emote_Hip_Hop", "s5_hiphop_breakin_132bmp_loop", true);
      }
      else if (iParam2 == 32)
      {
          CreateEmote(client, "Emote_Hula_Start", "Emote_Hula", "emote_hula_01", true);
      }
      else if (iParam2 == 33)
      {
          CreateEmote(client, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", "athena_emote_infinidab", true);
      }
      else if (iParam2 == 34)
      {
          CreateEmote(client, "Emote_Intensity_Start", "Emote_Intensity_Loop", "emote_intensity", true);
      }
      else if (iParam2 == 35)
      {
          CreateEmote(client, "Emote_IrishJig_Start", "Emote_IrishJig", "emote_irish_jig_foley_music_loop", true);
      }
      else if (iParam2 == 36)
      {
          CreateEmote(client, "Emote_KoreanEagle", "none", "athena_music_emotes_koreaneagle", true);
      }
      else if (iParam2 == 37)
      {
          CreateEmote(client, "Emote_Kpop_02", "none", "emote_kpop_01", true);
      }
      else if (iParam2 == 38)
      {
          CreateEmote(client, "Emote_LivingLarge", "none", "emote_livinglarge_A", true);
      }
      else if (iParam2 == 39)
      {
          CreateEmote(client, "Emote_Maracas", "none", "emote_samba_new_b", true);
      }
      else if (iParam2 == 40)
      {
          CreateEmote(client, "Emote_PopLock", "none", "athena_emote_poplock", true);
      }
      else if (iParam2 == 41)
      {
          CreateEmote(client, "Emote_PopRock", "none", "emote_poprock_01", true);
      }
      else if (iParam2 == 42)
      {
          CreateEmote(client, "Emote_RobotDance", "none", "athena_emote_robot_music", true);
      }
      else if (iParam2 == 43)
      {
          CreateEmote(client, "Emote_T-Rex", "none", "emote_dino_complete", false);
      }
      else if (iParam2 == 44)
      {
          CreateEmote(client, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);
      }
      else if (iParam2 == 45)
      {
          CreateEmote(client, "Emote_Twist", "none", "athena_emotes_music_twist", true);
      }
      else if (iParam2 == 46)
      {
          CreateEmote(client, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", "emote_warehouse", true);
      }
      else if (iParam2 == 47)
      {
          CreateEmote(client, "Emote_Wiggle", "none", "wiggle_music_loop", true);
      }
      else if (iParam2 == 48)
      {
          CreateEmote(client, "Emote_Youre_Awesome", "none", "youre_awesome_emote_music", false);
      }
      else if (iParam2 == 49)
      {
          CreateEmote(client, "Emote_Smooth_Moves", "none", "smooth_moves", true);
      }
      else if (iParam2 == 50)
      {
          CreateEmote(client, "Emote_Friday13", "none", "california_girls", true);
      }
      else if (iParam2 == 51)
      {
          CreateEmote(client, "Emote_Thanos_Twerk", "none", "thanos_twerk", true);
      }
      else if (iParam2 == 52)
      {
          CreateEmote(client, "Emote_Gangnam_Style", "none", "Psychic", false);
      }
      else if (iParam2 == 53)
      {
          CreateEmote(client, "Emote_InDaGhetto", "none", "Emote_Vivid", true);
      }
      else if (iParam2 == 54)
      {
          CreateEmote(client, "Emote_BlindingLights", "none", "Emote_Autumn_Tea", false);
      }
      else if (iParam2 == 55)
      {
          CreateEmote(client, "Emote_Griddy", "none", "Emote_Griddles_Music", true);
      }
      else if (iParam2 == 56)
      {
          CreateEmote(client, "Emote_ILikeToMoveIt", "none", "Emote_JumpingJoy", true);
      }
      else if (iParam2 == 57)
      {
          CreateEmote(client, "Emote_Macarena", "none", "Emote_Macaroon_Music", true);
      }
      else if (iParam2 == 58)
      {
          CreateEmote(client, "Emote_NeverGonna", "none", "Emote_NeverGonna", false);
      }
      else if (iParam2 == 59)
      {
          CreateEmote(client, "Emote_NinjaStyle", "none", "Emote_Tour_Bus", true);
      }
      else if (iParam2 == 60)
      {
          CreateEmote(client, "Emote_PumpkinDance", "none", "pumpkin_dance", false);
      }
      else if (iParam2 == 61)
      {
          CreateEmote(client, "Emote_PumpUpTheJam", "none", "Deflated_Emote_Music", true);
      }
      else if (iParam2 == 62)
      {
          CreateEmote(client, "Emote_Renegade", "none", "Emote_Just_Home_Music", true);
      }
      else if (iParam2 == 63)
      {
          CreateEmote(client, "Emote_RushinAround", "none", "Emote_Comrade", true);
      }
      else if (iParam2 == 64)
      {
          CreateEmote(client, "Emote_SaySo", "none", "Emote_HotPink", true);
      }
      else if (iParam2 == 65)
      {
          CreateEmote(client, "Emote_Stuck", "none", "Emote_Downward", true);
      }
      else if (iParam2 == 66)
      {
          CreateEmote(client, "Emote_ToosieSlide", "none", "Emote_Art_Giant", true);
      }
      else if (iParam2 == 67)
      {
          CreateEmote(client, "Emote_AirShredder", "none", "Air_Guitar_Emote", true);
      }
      else if (iParam2 == 68)
      {
          CreateEmote(client, "Emote_Crossbounce", "none", "Emote_Blaster", true);
      }
      else if (iParam2 == 69)
      {
          CreateEmote(client, "Emote_DistractionDance", "none", "distraction", true);
      }
      else if (iParam2 == 70)
      {
          CreateEmote(client, "Emote_Headbanger", "none", "Headbanger_Music", true);
      }
      else if (iParam2 == 71)
      {
          CreateEmote(client, "Emote_HitchHiker", "none", "Hitchhiker_Music", true);
      }
      else if (iParam2 == 72)
      {
          CreateEmote(client, "Emote_ItsGoTime", "none", "ItsGoTime_Music", true);
      }
      else if (iParam2 == 73)
      {
          CreateEmote(client, "Emote_KneeSlapper", "none", "KneeSlapper_Music", true);
      }
      else if (iParam2 == 74)
      {
          CreateEmote(client, "Emote_Showstopper", "none", "Showstopper_Music", true);
      }
      else if (iParam2 == 75)
      {
          CreateEmote(client, "Emote_Sprinkler", "none", "Sprinkler_Music", true);
      }
      else if (iParam2 == 76)
      {
          CreateEmote(client, "Emote_Gmod", "none", "gmod_select", true);
      }
      else if (iParam2 == 77)
      {
          CreateEmote(client, "Emote_ChickenDance", "none", "pollo_dance", true);
      }
      else if (iParam2 == 78)
      {
          CreateEmote(client, "Emote_Ghostbusters", "none", "toastbust", true);
      }
      else if (iParam2 == 79)
      {
          CreateEmote(client, "Emote_Martian", "none", "leave_the_door", true);
      }
      else if (iParam2 == 80)
      {
          CreateEmote(client, "Emote_RememberMe_Intro", "Emote_RememberMe_Loop", "unforgettable", true);
      }
      else if (iParam2 == 81)
      {
          CreateEmote(client, "Emote_Rollie", "none", "rollie_rollie", true);
      }
      else if (iParam2 == 82)
      {
          CreateEmote(client, "Emote_Scenario", "none", "scenariooo", true);
      }
      else if (iParam2 == 83)
      {
          CreateEmote(client, "Emote_Tpose", "none", "", true);
      }
      else if (iParam2 == 84)
      {
          CreateEmote(client, "Emote_SmoothDrive", "none", "dropit", true);
      }

    }
    Menu newMenu = CreateDancesMenuAtPosition();
    newMenu.DisplayAt(client, currentPosition, MENU_TIME_FOREVER);
    //DancesMenu(client);
    return 0;
  }
  else if (action == MenuAction_Cancel)
  {
    if(param2 == MenuCancel_ExitBack)
      {
        Menu_Dance(client);
      }
  }
  else if (action == MenuAction_End)
  {
    delete menu;
  }
  return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////
//Random
////////////////////////////////////////////////////////////////////////////////////////////

public Action RandomEmote(int i)
{
  
  int number = GetRandomInt(1, 37);
  
  switch (number)
  {
    case 1:
    {
      CreateEmote(i, "Emote_Fonzie_Pistol", "none", "", false);
    }
    case 2:
    {
      CreateEmote(i, "Emote_Bring_It_On", "none", "", false);
    }
    case 3:
    {
      CreateEmote(i, "Emote_ThumbsDown", "none", "", false);
    }
    /*se añadira ams casos*/
    case 4:
    CreateEmote(i, "Emote_ThumbsUp", "none", "", false);
    case 5:
    CreateEmote(i, "Emote_Celebration_Loop", "", "jubilation", false);
    case 6:
    CreateEmote(i, "Emote_BlowKiss", "none", "blowkiss", false);
    case 7:
    CreateEmote(i, "Emote_Calculated", "none", "", false);
    case 8:
    CreateEmote(i, "Emote_Confused", "none", "", false);
    case 9:
    CreateEmote(i, "Emote_Chug", "none", "gogogo", false);
    case 10:
    CreateEmote(i, "Emote_Cry", "none", "bananacry", false);
    case 11:
    CreateEmote(i, "Emote_DustingOffHands", "none", "", true);
    case 12:
    CreateEmote(i, "Emote_DustOffShoulders", "none", "athena_emote_hot_music", true);
    case 13:
    CreateEmote(i, "Emote_Facepalm", "none", "athena_emote_facepalm_foley_01", false);
    case 14:
    CreateEmote(i, "Emote_Fishing", "none", "fishing", false);
    case 15:
    CreateEmote(i, "Emote_Flex", "none", "flexing", false);
    case 16:
    CreateEmote(i, "Emote_golfclap", "none", "clapping", false);
    case 17:
    CreateEmote(i, "Emote_HandSignals", "none", "", false);
    case 18:
    CreateEmote(i, "Emote_HeelClick", "none", "emote_heelclick", false);
    case 19:
    CreateEmote(i, "Emote_Hotstuff", "none", "emote_hotstuff", false);  
    case 20:
    CreateEmote(i, "Emote_IBreakYou", "none", "", false); 
    case 21:
    CreateEmote(i, "Emote_IHeartYou", "none", "iheartyou", false);
    case 22:
    CreateEmote(i, "Emote_Kung-Fu_Salute", "none", "", false);
    case 23:
    CreateEmote(i, "Emote_Laugh", "Emote_Laugh_CT", "emote_laugh_01", false);   
    case 24:
    CreateEmote(i, "Emote_Luchador", "none", "emote_luchador", false);
    case 25:
    CreateEmote(i, "Emote_Make_It_Rain", "none", "athena_emote_makeitrain_music", false);
    case 26:
    CreateEmote(i, "Emote_NotToday", "none", "", false);  
    case 27:
    CreateEmote(i, "Emote_RockPaperScissor_Paper", "none", "", false);
    case 28:
    CreateEmote(i, "Emote_RockPaperScissor_Rock", "none", "", false);
    case 29:
    CreateEmote(i, "Emote_RockPaperScissor_Scissor", "none", "", false);
    case 30:
    CreateEmote(i, "Emote_Salt", "none", "", false);
    case 31:
    CreateEmote(i, "Emote_Salute", "none", "athena_emote_salute_foley_01", false);
    case 32:
    CreateEmote(i, "Emote_Snap", "none", "emote_snap1", false);
    case 33:
    CreateEmote(i, "Emote_StageBow", "none", "emote_stagebow", false);    
    case 34:
    CreateEmote(i, "Emote_Wave2", "none", "", false);
    case 35:
    CreateEmote(i, "Emote_Yeet", "none", "emote_yeet", false);
    case 36:
    CreateEmote(i, "Emote_Cena", "none", "cant_c_me", false);
    case 37:
    CreateEmote(i, "Emote_Lebron", "none", "lebronjame", false);
    
  }
  return Plugin_Continue;
}

public Action RandomDance(int i)
{
  int number = GetRandomInt(1, 84);
  
  switch (number)
  {
    case 1:
    {
      CreateEmote(i, "DanceMoves", "none", "ninja_dance_01", false);
    }
    case 2:
    {
      CreateEmote(i, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", "hip_hop_good_vibes_mix_01_loop", true);   
    }
    /*se añadira mas casos*/
    case 3:
    CreateEmote(i, "Emote_Zippy_Dance", "none", "emote_zippy_A", true);
    case 4:
    CreateEmote(i, "ElectroShuffle", "none", "athena_emote_electroshuffle_music", true);
    case 5:
    CreateEmote(i, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
    case 6:
    CreateEmote(i, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);
    case 7:
    CreateEmote(i, "Emote_BandOfTheFort", "none", "athena_emote_bandofthefort_music", true);  
    case 8:
    CreateEmote(i, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true); 
    case 9:
    CreateEmote(i, "Emote_Capoeira", "none", "emote_capoeira", false);
    case 10:
    CreateEmote(i, "Emote_Charleston", "none", "athena_emote_flapper_music", true);
    case 11:
    CreateEmote(i, "Emote_Chicken", "none", "athena_emote_chicken_foley_01", true);
    case 12:
    CreateEmote(i, "Emote_Dance_NoBones", "none", "athena_emote_music_boneless", true);
    case 13:
    CreateEmote(i, "Emote_Dance_Shoot", "none", "athena_emotes_music_shoot_v7", true);
    case 14:
    CreateEmote(i, "Emote_Dance_SwipeIt", "none", "athena_emotes_music_swipeit", true);
    case 15:
    CreateEmote(i, "Emote_Dance_Disco_T3", "none", "athena_emote_disco", true);
    case 16:
    CreateEmote(i, "Emote_DG_Disco", "none", "athena_emote_disco", true);           
    case 17:
    CreateEmote(i, "Emote_Dance_Worm", "none", "athena_emote_worm_music", false);
    case 18:
    CreateEmote(i, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", "athena_music_emotes_takethel", true);
    case 19:
    CreateEmote(i, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
    case 20:
    CreateEmote(i, "Emote_Dance_Pump", "none", "emote_groove_jam_a", true);
    case 21:
    CreateEmote(i, "Emote_Dance_RideThePony", "none", "athena_emote_ridethepony_music_01", false);
    case 22:
    CreateEmote(i, "Emote_Dab", "none", "", false);
    case 23:
    CreateEmote(i, "Emote_EasternBloc_Start", "Emote_EasternBloc", "eastern_bloc_musc_setup_d", true);
    case 24:
    CreateEmote(i, "Emote_FancyFeet", "Emote_FancyFeet_CT", "athena_emotes_lankylegs_loop_02", true); 
    case 25:
    CreateEmote(i, "Emote_FlossDance", "none", "athena_emote_floss_music", true);
    case 26:
    CreateEmote(i, "Emote_FlippnSexy", "none", "emote_flippnsexy", false);
    case 27:
    CreateEmote(i, "Emote_Fresh", "none", "athena_emote_fresh_music", true);
    case 28:
    CreateEmote(i, "Emote_GrooveJam", "none", "emote_groove_jam_a", true);  
    case 29:
    CreateEmote(i, "Emote_guitar", "none", "br_emote_shred_guitar_mix_03_loop", true);  
    case 30:
    CreateEmote(i, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", "emote_hillbilly_shuffle", true); 
    case 31:
    CreateEmote(i, "Emote_Hiphop_01", "Emote_Hip_Hop", "s5_hiphop_breakin_132bmp_loop", true);  
    case 32:
    CreateEmote(i, "Emote_Hula_Start", "Emote_Hula", "emote_hula_01", true);
    case 33:
    CreateEmote(i, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", "athena_emote_infinidab", true);  
    case 34:
    CreateEmote(i, "Emote_Intensity_Start", "Emote_Intensity_Loop", "emote_intensity", true);
    case 35:
    CreateEmote(i, "Emote_IrishJig_Start", "Emote_IrishJig", "emote_irish_jig_foley_music_loop", true);
    case 36:
    CreateEmote(i, "Emote_KoreanEagle", "none", "athena_music_emotes_koreaneagle", true);
    case 37:
    CreateEmote(i, "Emote_Kpop_02", "none", "emote_kpop_01", true); 
    case 38:
    CreateEmote(i, "Emote_LivingLarge", "none", "emote_livinglarge_A", true); 
    case 39:
    CreateEmote(i, "Emote_Maracas", "none", "emote_samba_new_b", true);
    case 40:
    CreateEmote(i, "Emote_PopLock", "none", "athena_emote_poplock", true);
    case 41:
    CreateEmote(i, "Emote_PopRock", "none", "emote_poprock_01", true);    
    case 42:
    CreateEmote(i, "Emote_RobotDance", "none", "athena_emote_robot_music", true); 
    case 43:
    CreateEmote(i, "Emote_T-Rex", "none", "emote_dino_complete", false);
    case 44:
    CreateEmote(i, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);    
    case 45:
    CreateEmote(i, "Emote_Twist", "none", "athena_emotes_music_twist", true);
    case 46:
    CreateEmote(i, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", "emote_warehouse", true);
    case 47:
    CreateEmote(i, "Emote_Wiggle", "none", "wiggle_music_loop", true);
    case 48:
    CreateEmote(i, "Emote_Youre_Awesome", "none", "youre_awesome_emote_music", false);
    case 49:
    CreateEmote(i, "Emote_Smooth_Moves", "none", "smooth_moves", true);
    case 50:
    CreateEmote(i, "Emote_Friday13", "none", "california_girls", true);
    case 51:
    CreateEmote(i, "Emote_Thanos_Twerk", "none", "thanos_twerk", true);   
    case 52:
    CreateEmote(i, "Emote_Gangnam_Style", "none", "Psychic", false);   
    case 53:
    CreateEmote(i, "Emote_InDaGhetto", "none", "Emote_Vivid", true);
    case 54:
    CreateEmote(i, "Emote_BlindingLights", "none", "Emote_Autumn_Tea", false);
    case 55:
    CreateEmote(i, "Emote_Griddy", "none", "Emote_Griddles_Music", true);
    case 56:
    CreateEmote(i, "Emote_ILikeToMoveIt", "none", "Emote_JumpingJoy", true);
    case 57:
    CreateEmote(i, "Emote_Macarena", "none", "Emote_Macaroon_Music", true);
    case 58:
    CreateEmote(i, "Emote_NeverGonna", "none", "Emote_NeverGonna", false);
    case 59:
    CreateEmote(i, "Emote_NinjaStyle", "none", "Emote_Tour_Bus", true);
    case 60:
    CreateEmote(i, "Emote_PumpkinDance", "none", "pumpkin_dance", false);
    case 61:
    CreateEmote(i, "Emote_PumpUpTheJam", "none", "Deflated_Emote_Music", true);
    case 62:
    CreateEmote(i, "Emote_Renegade", "none", "Emote_Just_Home_Music", true);
    case 63:
    CreateEmote(i, "Emote_RushinAround", "none", "Emote_Comrade", true);
    case 64:
    CreateEmote(i, "Emote_SaySo", "none", "Emote_HotPink", true);
    case 65:
    CreateEmote(i, "Emote_Stuck", "none", "Emote_Downward", true);
    case 66:
    CreateEmote(i, "Emote_ToosieSlide", "none", "Emote_Art_Giant", true);
    case 67:
    CreateEmote(i, "Emote_AirShredder", "none", "Air_Guitar_Emote", true);
    case 68:
    CreateEmote(i, "Emote_Crossbounce", "none", "Emote_Blaster", true);
    case 69:
    CreateEmote(i, "Emote_DistractionDance", "none", "distraction", true);
    case 70:
    CreateEmote(i, "Emote_Headbanger", "none", "Headbanger_Music", true);
    case 71:
    CreateEmote(i, "Emote_HitchHiker", "none", "Hitchhiker_Music", true);
    case 72:
    CreateEmote(i, "Emote_ItsGoTime", "none", "ItsGoTime_Music", true);
    case 73:
    CreateEmote(i, "Emote_KneeSlapper", "none", "KneeSlapper_Music", true);
    case 74:
    CreateEmote(i, "Emote_Showstopper", "none", "Showstopper_Music", true);
    case 75:
    CreateEmote(i, "Emote_Sprinkler", "none", "Sprinkler_Music", true);
    case 76:
    CreateEmote(i, "Emote_Gmod", "none", "gmod_select", true);
    case 77:
    CreateEmote(i, "Emote_ChickenDance", "none", "pollo_dance", true);
    case 78:
    CreateEmote(i, "Emote_Ghostbusters", "none", "toastbust", true);
    case 79:
    CreateEmote(i, "Emote_Martian", "none", "leave_the_door", true);
    case 80:
    CreateEmote(i, "Emote_RememberMe_Intro", "Emote_RememberMe_Loop", "unforgettable", true);
    case 81:
    CreateEmote(i, "Emote_Rollie", "none", "rollie_rollie", true);
    case 82:
    CreateEmote(i, "Emote_Scenario", "none", "scenariooo", true);
    case 83:
    CreateEmote(i, "Emote_Tpose", "none", "", true);
    case 84:
    CreateEmote(i, "Emote_SmoothDrive", "none", "dropit", true);
    
            
  }
  return Plugin_Continue;
}

////////////////////////////////////////////////////////////////////////////////////////////
//Admin Command sm_setemote and sm_doemote/sm_dodance
////////////////////////////////////////////////////////////////////////////////////////////

public Action Command_Admin_Emotes(int client, int args)
{
  if (args < 1)
  {
    CReplyToCommand(client, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
    return Plugin_Handled;
  }
  
  char arg[65];
  GetCmdArg(1, arg, sizeof(arg));
  
  int amount=1;
  if (args > 1)
  {
    char arg2[3];
    GetCmdArg(2, arg2, sizeof(arg2));
    if (StringToIntEx(arg2, amount) < 1 || StringToIntEx(arg2, amount) > 86)
    {
      CReplyToCommand(client, "Id de emote invalido");
      return Plugin_Handled;
    }
  }
  
  char target_name[MAX_TARGET_LENGTH];
  int target_list[MAXPLAYERS], target_count;
  bool tn_is_ml;
  
  if ((target_count = ProcessTargetString(
      arg,
      client,
      target_list,
      MAXPLAYERS,
      COMMAND_FILTER_ALIVE,
      target_name,
      sizeof(target_name),
      tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, target_count);
    return Plugin_Handled;
  }
  
  
  for (int i = 0; i < target_count; i++)
  {
    PerformEmote(client, target_list[i], amount);
  } 
  
  return Plugin_Handled;
}

public Action Command_Do_Emotes(int client, int args) //sm_doemote/sm_dodance
{
  if (args < 1)
  {
    CReplyToCommand(client, "[SM] Usage: sm_dodance [Emote ID]");
    CReplyToCommand(client, "[SM] Usage: sm_doemote [Emote ID]");
    return Plugin_Handled;
  }
  
  int amount=1;
  if (args > 0)
  {
    char arg1[4];
    GetCmdArg(1, arg1, sizeof(arg1));
    if (StringToIntEx(arg1, amount) < 1 || StringToIntEx(arg1, amount) > 133)
    {
      CReplyToCommand(client, "Id de emote invalido");
      return Plugin_Handled;
    }
  }
  
  PerformEmote(client, client, amount);
  
  return Plugin_Handled;
}

public void PerformEmote(int client, int target, int amount)
{
  switch (amount)
  {
    case 1:
    {
      CreateEmote(target, "Emote_Fonzie_Pistol", "none", "", false);
    }
    case 2:
    {
      CreateEmote(target, "Emote_Bring_It_On", "none", "", false);
    }
    case 3:
    {
      CreateEmote(target, "Emote_ThumbsDown", "none", "", false);
    }
    case 4:
    {
      CreateEmote(target, "Emote_ThumbsUp", "none", "", false);
    }
    /*se añadira mas casos*/
    case 5:
    CreateEmote(target, "Emote_Celebration_Loop", "", "jubilation", false);
    case 6:
    CreateEmote(target, "Emote_BlowKiss", "none", "blowkiss", false);
    case 7:
    CreateEmote(target, "Emote_Calculated", "none", "", false);
    case 8:
    CreateEmote(target, "Emote_Confused", "none", "", false);
    case 9:
    CreateEmote(target, "Emote_Chug", "none", "gogogo", false);
    case 10:
    CreateEmote(target, "Emote_Cry", "none", "bananacry", false);
    case 11:
    CreateEmote(target, "Emote_DustingOffHands", "none", "", true);
    case 12:
    CreateEmote(target, "Emote_DustOffShoulders", "none", "athena_emote_hot_music", true);
    case 13:
    CreateEmote(target, "Emote_Facepalm", "none", "athena_emote_facepalm_foley_01", false);
    case 14:
    CreateEmote(target, "Emote_Fishing", "none", "fishing", false);
    case 15:
    CreateEmote(target, "Emote_Flex", "none", "flexing", false);
    case 16:
    CreateEmote(target, "Emote_golfclap", "none", "clapping", false);
    case 17:
    CreateEmote(target, "Emote_HandSignals", "none", "", false);
    case 18:
    CreateEmote(target, "Emote_HeelClick", "none", "emote_heelclick", false);
    case 19:
    CreateEmote(target, "Emote_Hotstuff", "none", "emote_hotstuff", false); 
    case 20:
    CreateEmote(target, "Emote_IBreakYou", "none", "", false);  
    case 21:
    CreateEmote(target, "Emote_IHeartYou", "none", "iheartyou", false);
    case 22:
    CreateEmote(target, "Emote_Kung-Fu_Salute", "none", "", false);
    case 23:
    CreateEmote(target, "Emote_Laugh", "Emote_Laugh_CT", "emote_laugh_01", false);    
    case 24:
    CreateEmote(target, "Emote_Luchador", "none", "emote_luchador", false);
    case 25:
    CreateEmote(target, "Emote_Make_It_Rain", "none", "athena_emote_makeitrain_music", false);
    case 26:
    CreateEmote(target, "Emote_NotToday", "none", "", false); 
    case 27:
    CreateEmote(target, "Emote_RockPaperScissor_Paper", "none", "", false);
    case 28:
    CreateEmote(target, "Emote_RockPaperScissor_Rock", "none", "", false);
    case 29:
    CreateEmote(target, "Emote_RockPaperScissor_Scissor", "none", "", false);
    case 30:
    CreateEmote(target, "Emote_Salt", "none", "", false);
    case 31:
    CreateEmote(target, "Emote_Salute", "none", "athena_emote_salute_foley_01", false);
    case 32:
    CreateEmote(target, "Emote_SmoothDrive", "none", "dropit", false); //
    case 33:
    CreateEmote(target, "Emote_Snap", "none", "emote_snap1", false);
    case 34:
    CreateEmote(target, "Emote_StageBow", "none", "emote_stagebow", false);     
    case 35:
    CreateEmote(target, "Emote_Wave2", "none", "", false);
    case 36:
    CreateEmote(target, "Emote_Yeet", "none", "emote_yeet", false); 
    case 37:
    CreateEmote(target, "DanceMoves", "none", "ninja_dance_01", false);
    case 38:
    CreateEmote(target, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", "hip_hop_good_vibes_mix_01_loop", true);           
    case 39:
    CreateEmote(target, "Emote_Zippy_Dance", "none", "emote_zippy_A", true);
    case 40:
    CreateEmote(target, "ElectroShuffle", "none", "athena_emote_electroshuffle_music", true);
    case 41:
    CreateEmote(target, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
    case 42:
    CreateEmote(target, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);
    case 43:
    CreateEmote(target, "Emote_BandOfTheFort", "none", "athena_emote_bandofthefort_music", true); 
    case 44:
    CreateEmote(target, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true);  
    case 45:
    CreateEmote(target, "Emote_Capoeira", "none", "emote_capoeira", false);
    case 46:
    CreateEmote(target, "Emote_Charleston", "none", "athena_emote_flapper_music", true);
    case 47:
    CreateEmote(target, "Emote_Chicken", "none", "athena_emote_chicken_foley_01", true);
    case 48:
    CreateEmote(target, "Emote_Dance_NoBones", "none", "athena_emote_music_boneless", true);
    case 49:
    CreateEmote(target, "Emote_Dance_Shoot", "none", "athena_emotes_music_shoot_v7", true);
    case 50:
    CreateEmote(target, "Emote_Dance_SwipeIt", "none", "athena_emotes_music_swipeit", true);
    case 51:
    CreateEmote(target, "Emote_Dance_Disco_T3", "none", "athena_emote_disco", true);
    case 52:
    CreateEmote(target, "Emote_DG_Disco", "none", "athena_emote_disco", true);          
    case 53:
    CreateEmote(target, "Emote_Dance_Worm", "none", "athena_emote_worm_music", false);
    case 54:
    CreateEmote(target, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", "athena_music_emotes_takethel", true);
    case 55:
    CreateEmote(target, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
    case 56:
    CreateEmote(target, "Emote_Dance_Pump", "none", "emote_groove_jam_a", true);
    case 57:
    CreateEmote(target, "Emote_Dance_RideThePony", "none", "athena_emote_ridethepony_music_01", false);
    case 58:
    CreateEmote(target, "Emote_Dab", "none", "", false);
    case 59:
    CreateEmote(target, "Emote_EasternBloc_Start", "Emote_EasternBloc", "eastern_bloc_musc_setup_d", true);
    case 60:
    CreateEmote(target, "Emote_FancyFeet", "Emote_FancyFeet_CT", "athena_emotes_lankylegs_loop_02", true); 
    case 61:
    CreateEmote(target, "Emote_FlossDance", "none", "athena_emote_floss_music", true);
    case 62:
    CreateEmote(target, "Emote_FlippnSexy", "none", "emote_flippnsexy", false);
    case 63:
    CreateEmote(target, "Emote_Fresh", "none", "athena_emote_fresh_music", true);
    case 64:
    CreateEmote(target, "Emote_GrooveJam", "none", "emote_groove_jam_a", true); 
    case 65:
    CreateEmote(target, "Emote_guitar", "none", "br_emote_shred_guitar_mix_03_loop", true); 
    case 66:
    CreateEmote(target, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", "emote_hillbilly_shuffle", true); 
    case 67:
    CreateEmote(target, "Emote_Hiphop_01", "Emote_Hip_Hop", "s5_hiphop_breakin_132bmp_loop", true); 
    case 68:
    CreateEmote(target, "Emote_Hula_Start", "Emote_Hula", "emote_hula_01", true);
    case 69:
    CreateEmote(target, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", "athena_emote_infinidab", true); 
    case 70:
    CreateEmote(target, "Emote_Intensity_Start", "Emote_Intensity_Loop", "emote_intensity", true);
    case 71:
    CreateEmote(target, "Emote_IrishJig_Start", "Emote_IrishJig", "emote_irish_jig_foley_music_loop", true);
    case 72:
    CreateEmote(target, "Emote_KoreanEagle", "none", "athena_music_emotes_koreaneagle", true);
    case 73:
    CreateEmote(target, "Emote_Kpop_02", "none", "emote_kpop_01", true);  
    case 74:
    CreateEmote(target, "Emote_LivingLarge", "none", "emote_LivingLarge_A", true);  
    case 75:
    CreateEmote(target, "Emote_Maracas", "none", "emote_samba_new_b", true);
    case 76:
    CreateEmote(target, "Emote_PopLock", "none", "athena_emote_poplock", true);
    case 77:
    CreateEmote(target, "Emote_PopRock", "none", "emote_poprock_01", true);   
    case 78:
    CreateEmote(target, "Emote_RobotDance", "none", "athena_emote_robot_music", true);  
    case 79:
    CreateEmote(target, "Emote_T-Rex", "none", "emote_dino_complete", false);
    case 80:
    CreateEmote(target, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);   
    case 81:
    CreateEmote(target, "Emote_Twist", "none", "athena_emotes_music_twist", true);
    case 82:
    CreateEmote(target, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", "emote_warehouse", true);
    case 83:
    CreateEmote(target, "Emote_Wiggle", "none", "wiggle_music_loop", true);
    case 84:
    CreateEmote(target, "Emote_Youre_Awesome", "none", "youre_awesome_emote_music", false);
    case 85:
    CreateEmote(target, "Emote_Smooth_Moves", "none", "smooth_moves", false);
    case 86:
    CreateEmote(target, "Emote_Friday13", "none", "california_girls", true);
    case 87:
    CreateEmote(target, "Emote_Thanos_Twerk", "none", "thanos_twerk", true);   
    case 88:
    CreateEmote(target, "Emote_Gangnam_Style", "none", "Psychic", false);   
    case 89:
    CreateEmote(target, "Emote_InDaGhetto", "none", "Emote_Vivid", true);
    case 90:
    CreateEmote(target, "Emote_BlindingLights", "none", "Emote_Autumn_Tea", false);
    case 91:
    CreateEmote(target, "Emote_Griddy", "none", "Emote_Griddles_Music", true);
    case 92:
    CreateEmote(target, "Emote_ILikeToMoveIt", "none", "Emote_JumpingJoy", true);
    case 93:
    CreateEmote(target, "Emote_Macarena", "none", "Emote_Macaroon_Music", true);
    case 94:
    CreateEmote(target, "Emote_NeverGonna", "none", "Emote_NeverGonna", false);
    case 95:
    CreateEmote(target, "Emote_NinjaStyle", "none", "Emote_Tour_Bus", true);
    case 96:
    CreateEmote(target, "Emote_PumpkinDance", "none", "pumpkin_dance", false);
    case 97:
    CreateEmote(target, "Emote_PumpUpTheJam", "none", "Deflated_Emote_Music", true);
    case 98:
    CreateEmote(target, "Emote_Renegade", "none", "Emote_Just_Home_Music", true);
    case 99:
    CreateEmote(target, "Emote_RushinAround", "none", "Emote_Comrade", true);
    case 100:
    CreateEmote(target, "Emote_SaySo", "none", "Emote_HotPink", true);
    case 101:
    CreateEmote(target, "Emote_Stuck", "none", "Emote_Downward", true);
    case 102:
    CreateEmote(target, "Emote_ToosieSlide", "none", "Emote_Art_Giant", true);
    case 103:
    CreateEmote(target, "Emote_AirShredder", "none", "Air_Guitar_Emote", true);
    case 104:
    CreateEmote(target, "Emote_Crossbounce", "none", "Emote_Blaster", true);
    case 105:
    CreateEmote(target, "Emote_DistractionDance", "none", "distraction", true);
    case 106:
    CreateEmote(target, "Emote_Headbanger", "none", "Headbanger_Music", true);
    case 107:
    CreateEmote(target, "Emote_HitchHiker", "none", "Hitchhiker_Music", true);
    case 108:
    CreateEmote(target, "Emote_ItsGoTime", "none", "ItsGoTime_Music", true);
    case 109:
    CreateEmote(target, "Emote_KneeSlapper", "none", "KneeSlapper_Music", true);
    case 110:
    CreateEmote(target, "Emote_Showstopper", "none", "Showstopper_Music", true);
    case 111:
    CreateEmote(target, "Emote_Sprinkler", "none", "Sprinkler_Music", true);
    case 112:
    CreateEmote(target, "Emote_Gmod", "none", "gmod_select", true);
    case 113:
    CreateEmote(target, "Emote_Cena", "none", "cant_c_me", false);
    case 114:
    CreateEmote(target, "Emote_Lebron", "none", "lebronjame", false);
    case 115:
    CreateEmote(target, "Emote_ChickenDance", "none", "pollo_dance", true);
    case 116:
    CreateEmote(target, "Emote_Ghostbusters", "none", "toastbust", true);
    case 117:
    CreateEmote(target, "Emote_Martian", "none", "leave_the_door", true);
    case 118:
    CreateEmote(target, "Emote_RememberMe_Intro", "Emote_RememberMe_Loop", "unforgettable", true);
    case 119:
    CreateEmote(target, "Emote_Rollie", "none", "rollie_rollie", true);
    case 120:
    CreateEmote(target, "Emote_Scenario", "none", "scenariooo", true);
    case 121:
    CreateEmote(target, "Emote_Tpose", "none", "", true);
    
    default:
    {
      CPrintToChat(client, "ID de emote inválido");
    }
  }
}

public void OnAdminMenuReady(Handle aTopMenu)
{
  TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

  /* Block us from being called twice */
  if (topmenu == hTopMenu)
  {
    return;
  }
  
  /* Save the Handle */
  hTopMenu = topmenu;
  
  /* Find the "Player Commands" category */
  TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

  if (player_commands != INVALID_TOPMENUOBJECT)
  {
    hTopMenu.AddItem("sm_setemotes", AdminMenu_Emotes, player_commands, "sm_setemotes", ADMFLAG_SLAY);
  }
}

public void AdminMenu_Emotes(TopMenu topmenu, 
          TopMenuAction action,
          TopMenuObject object_id,
          int param,
          char[] buffer,
          int maxlength)
{
  if (action == TopMenuAction_DisplayOption)
  {
    Format(buffer, maxlength, "Reproductor de emote", param);
  }
  else if (action == TopMenuAction_SelectOption)
  {
    DisplayEmotePlayersMenu(param);
  }
}

public void DisplayEmotePlayersMenu(int client)
{
  Menu menu = new Menu(MenuHandler_EmotePlayers);
  
  char title[65];
  Format(title, sizeof(title), "Reproductor de Emotes");
  menu.SetTitle(title);
  menu.ExitBackButton = true;
  
  AddTargetsToMenu(menu, client, true, true);
  
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EmotePlayers(Menu menu, MenuAction action, int param1, int param2)
{
  if (action == MenuAction_End)
  {
    delete menu;
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack && hTopMenu != null)
    {
      hTopMenu.Display(param1, TopMenuPosition_LastCategory);
    }
  }
  else if (action == MenuAction_Select)
  {
    char info[32];
    int userid, target;
    
    menu.GetItem(param2, info, sizeof(info));
    userid = StringToInt(info);

    if ((target = GetClientOfUserId(userid)) == 0)
    {
      CPrintToChat(param1, "[SM] El jugador ya no está disponible");
    }
    else if (!CanUserTarget(param1, target))
    {
      CPrintToChat(param1, "[SM] No se puede apuntar a ese jugador");
    }
    else
    {
      g_EmotesTarget[param1] = userid;
      DisplayEmotesAmountMenu(param1);
      return 0; // Return, because we went to a new menu and don't want the re-draw to occur.
    }
    
    /* Re-draw the menu if they're still valid */
    if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
    {
      DisplayEmotePlayersMenu(param1);
    }
  }
  
  return 0;
}

public void DisplayEmotesAmountMenu(int client)
{
  Menu menu = new Menu(MenuHandler_EmotesAmount);
  
  char title[65];
  Format(title, sizeof(title), "Seleccionar Emote para: %N", GetClientOfUserId(g_EmotesTarget[client]));
  menu.SetTitle(title);
  menu.ExitBackButton = true;

  menu.AddItem("1", "Emote_Fonzie_Pistol");
  menu.AddItem("2", "Emote_Bring_It_On");
  menu.AddItem("3", "Emote_ThumbsDown");
  /* se añadira mas*/
  menu.AddItem("4", "Emote_ThumbsUp");
  menu.AddItem("5", "Emote_Celebration_Loop");
  menu.AddItem("6", "Emote_BlowKiss");
  menu.AddItem("7", "Emote_Calculated");
  menu.AddItem("8", "Emote_Confused");
  menu.AddItem("9", "Emote_Chug");
  menu.AddItem("10", "Emote_Cry");
  menu.AddItem("11", "Emote_DustingOffHands");
  menu.AddItem("12", "Emote_DustOffShoulders");
  menu.AddItem("13", "Emote_Facepalm");
  menu.AddItem("14", "Emote_Fishing");
  menu.AddItem("15", "Emote_Flex");
  menu.AddItem("16", "Emote_golfclap");
  menu.AddItem("17", "Emote_HandSignals");
  menu.AddItem("18", "Emote_HeelClick");
  menu.AddItem("19", "Emote_Hotstuff");
  menu.AddItem("20", "Emote_IBreakYou");
  menu.AddItem("21", "Emote_IHeartYou");
  menu.AddItem("22", "Emote_Kung-Fu_Salute");
  menu.AddItem("23", "Emote_Laugh");
  menu.AddItem("24", "Emote_Luchador");
  menu.AddItem("25", "Emote_Make_It_Rain");
  menu.AddItem("26", "Emote_NotToday");
  menu.AddItem("27", "Emote_RockPaperScissor_Paper");
  menu.AddItem("28", "Emote_RockPaperScissor_Rock");
  menu.AddItem("29", "Emote_RockPaperScissor_Scissor");
  menu.AddItem("30", "Emote_Salt");
  menu.AddItem("31", "Emote_Salute");
  menu.AddItem("32", "Emote_SmoothDrive");
  menu.AddItem("33", "Emote_Snap");
  menu.AddItem("34", "Emote_StageBow");
  menu.AddItem("35", "Emote_Wave2");
  menu.AddItem("36", "Emote_Yeet");
  menu.AddItem("37", "DanceMoves");
  menu.AddItem("38", "Emote_Mask_Off_Intro");
  menu.AddItem("39", "Emote_Zippy_Dance");
  menu.AddItem("40", "ElectroShuffle");
  menu.AddItem("41", "Emote_AerobicChamp");
  menu.AddItem("42", "Emote_Bendy");
  menu.AddItem("43", "Emote_BandOfTheFort");
  menu.AddItem("44", "Emote_Boogie_Down_Intro");
  menu.AddItem("45", "Emote_Capoeira");
  menu.AddItem("46", "Emote_Charleston");
  menu.AddItem("47", "Emote_Chicken");
  menu.AddItem("48", "Emote_Dance_NoBones");
  menu.AddItem("49", "Emote_Dance_Shoot");
  menu.AddItem("50", "Emote_Dance_SwipeIt");
  menu.AddItem("51", "Emote_Dance_Disco_T3");
  menu.AddItem("52", "Emote_DG_Disco");
  menu.AddItem("53", "Emote_Dance_Worm");
  menu.AddItem("54", "Emote_Dance_Loser");
  menu.AddItem("55", "Emote_Dance_Breakdance");
  menu.AddItem("56", "Emote_Dance_Pump");
  menu.AddItem("57", "Emote_Dance_RideThePony");
  menu.AddItem("58", "Emote_Dab");
  menu.AddItem("59", "Emote_EasternBloc_Start");
  menu.AddItem("60", "Emote_FancyFeet");
  menu.AddItem("61", "Emote_FlossDance");
  menu.AddItem("62", "Emote_FlippnSexy");
  menu.AddItem("63", "Emote_Fresh");
  menu.AddItem("64", "Emote_GrooveJam");
  menu.AddItem("65", "Emote_guitar");
  menu.AddItem("66", "Emote_Hillbilly_Shuffle_Intro");
  menu.AddItem("67", "Emote_Hiphop_01");
  menu.AddItem("68", "Emote_Hula_Start");
  menu.AddItem("69", "Emote_InfiniDab_Intro");
  menu.AddItem("70", "Emote_Intensity_Start");
  menu.AddItem("71", "Emote_IrishJig_Start");
  menu.AddItem("72", "Emote_KoreanEagle");
  menu.AddItem("73", "Emote_Kpop_02");
  menu.AddItem("74", "Emote_LivingLarge");
  menu.AddItem("75", "Emote_Maracas");
  menu.AddItem("76", "Emote_PopLock");
  menu.AddItem("77", "Emote_PopRock");
  menu.AddItem("78", "Emote_RobotDance");
  menu.AddItem("79", "Emote_T-Rex");
  menu.AddItem("80", "Emote_TechnoZombie");
  menu.AddItem("81", "Emote_Twist");
  menu.AddItem("82", "Emote_WarehouseDance_Start");
  menu.AddItem("83", "Emote_Wiggle");
  menu.AddItem("84", "Emote_Youre_Awesome");
  menu.AddItem("85", "Emote_Smooth_Moves");
  menu.AddItem("86", "Emote_Friday13");
  menu.AddItem("87", "Emote_Thanos_Twerk");
  menu.AddItem("88", "Emote_Gangnam_Style");
  menu.AddItem("89", "Emote_InDaGhetto");
  menu.AddItem("90", "Emote_BlindingLights");
  menu.AddItem("91", "Emote_Griddy");
  menu.AddItem("92", "Emote_ILikeToMoveIt");
  menu.AddItem("93", "Emote_Macarena");
  menu.AddItem("94", "Emote_NeverGonna");
  menu.AddItem("95", "Emote_NinjaStyle");
  menu.AddItem("96", "Emote_PumpkinDance");
  menu.AddItem("97", "Emote_PumpUpTheJam");
  menu.AddItem("98", "Emote_Renegade");
  menu.AddItem("99", "Emote_RushinAround");
  menu.AddItem("100", "Emote_SaySo");
  menu.AddItem("101", "Emote_Stuck");
  menu.AddItem("102", "Emote_ToosieSlide");
  menu.AddItem("103", "Emote_AirShredder");
  menu.AddItem("104", "Emote_Crossbounce");
  menu.AddItem("105", "Emote_DistractionDance");
  menu.AddItem("106", "Emote_Headbanger");
  menu.AddItem("107", "Emote_HitchHiker");
  menu.AddItem("108", "Emote_ItsGoTime");
  menu.AddItem("109", "Emote_KneeSlapper");
  menu.AddItem("110", "Emote_Showstopper");
  menu.AddItem("111", "Emote_Sprinkler");
  menu.AddItem("112", "Emote_Gmod");
  menu.AddItem("113", "Emote_Cena");
  menu.AddItem("114", "Emote_Lebron");
  menu.AddItem("115", "Emote_ChickenDance");
  menu.AddItem("116", "Emote_Ghostbusters");
  menu.AddItem("117", "Emote_Martian");
  menu.AddItem("118", "Emote_RememberMe_Intro");
  menu.AddItem("119", "Emote_Rollie");
  menu.AddItem("120", "Emote_Scenario");
  menu.AddItem("121", "Emote_Tpose");
	
  
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EmotesAmount(Menu menu, MenuAction action, int param1, int param2)
{
  if (action == MenuAction_End)
  {
    delete menu;
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack && hTopMenu != null)
    {
      hTopMenu.Display(param1, TopMenuPosition_LastCategory);
    }
  }
  else if (action == MenuAction_Select)
  {
    char info[32];
    int amount;
    int target;
    
    menu.GetItem(param2, info, sizeof(info));
    amount = StringToInt(info);

    if ((target = GetClientOfUserId(g_EmotesTarget[param1])) == 0)
    {
      CPrintToChat(param1, "[SM] Player no longer available");
    }
    else if (!CanUserTarget(param1, target))
    {
      CPrintToChat(param1, "[SM] Unable to target");
    }
    else
    {
      char name[MAX_NAME_LENGTH];
      GetClientName(target, name, sizeof(name));
      
      PerformEmote(param1, target, amount);
    }
    
    /* Re-draw the menu if they're still valid */
    if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
    {
      DisplayEmotePlayersMenu(param1);
    }
  }
  return 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
  if(StrEqual(classname, "trigger_multiple"))
  {
      SDKHook(entity, SDKHook_StartTouch, OnTrigger);
      SDKHook(entity, SDKHook_EndTouch, OnTrigger);
      SDKHook(entity, SDKHook_Touch, OnTrigger);
  }
  else if(StrEqual(classname, "trigger_hurt"))
  {
      SDKHook(entity, SDKHook_StartTouch, OnTrigger);
      SDKHook(entity, SDKHook_EndTouch, OnTrigger);
      SDKHook(entity, SDKHook_Touch, OnTrigger);
  }
  else if(StrEqual(classname, "trigger_push"))
  {
      SDKHook(entity, SDKHook_StartTouch, OnTrigger);
      SDKHook(entity, SDKHook_EndTouch, OnTrigger);
      SDKHook(entity, SDKHook_Touch, OnTrigger);
  }
}

public Action OnTrigger(int entity, int other)
{
  if (0 < other <= MaxClients)
  {
    StopEmote(other);
  }

  return Plugin_Continue;
}

public bool IsNonElevatorMap()
{
  char MapName[128];
  GetCurrentMap(MapName, sizeof(MapName));
  if (StrContains(MapName, "c1m2", true) > -1 || 
    StrContains(MapName, "c1m3", true) > -1 || 
    StrContains(MapName, "c2m1", true) > -1 || 
    StrContains(MapName, "c2m2", true) > -1 || 
    StrContains(MapName, "c2m3", true) > -1 || 
    StrContains(MapName, "c2m4", true) > -1 || 
    StrContains(MapName, "c2m5", true) > -1 || 
    StrContains(MapName, "c3m2", true) > -1 || 
    StrContains(MapName, "c3m3", true) > -1 || 
    StrContains(MapName, "c3m4", true) > -1 || 
    StrContains(MapName, "c4m1", true) > -1 || 
    StrContains(MapName, "c4m4", true) > -1 || 
    StrContains(MapName, "c4m5", true) > -1 || 
    StrContains(MapName, "c5m1", true) > -1 || 
    StrContains(MapName, "c5m2", true) > -1 || 
    StrContains(MapName, "c5m3", true) > -1 || 
    StrContains(MapName, "c5m4", true) > -1 || 
    StrContains(MapName, "c5m5", true) > -1 || 
    StrContains(MapName, "c6m1", true) > -1 || 
    StrContains(MapName, "c6m2", true) > -1 || 
    StrContains(MapName, "c7m1", true) > -1 || 
    StrContains(MapName, "c7m2", true) > -1 || 
    StrContains(MapName, "c7m3", true) > -1 || 
    StrContains(MapName, "c8m1", true) > -1 || 
    StrContains(MapName, "c8m2", true) > -1 || 
    StrContains(MapName, "c8m3", true) > -1 || 
    StrContains(MapName, "c8m5", true) > -1 || 
    StrContains(MapName, "c9m1", true) > -1 || 
    StrContains(MapName, "c9m2", true) > -1 || 
    StrContains(MapName, "c10m1", true) > -1 || 
    StrContains(MapName, "c10m2", true) > -1 || 
    StrContains(MapName, "c10m3", true) > -1 || 
    StrContains(MapName, "c10m4", true) > -1 || 
    StrContains(MapName, "c10m5", true) > -1 || 
    StrContains(MapName, "c11m1", true) > -1 || 
    StrContains(MapName, "c11m2", true) > -1 || 
    StrContains(MapName, "c11m3", true) > -1 || 
    StrContains(MapName, "c11m4", true) > -1 || 
    StrContains(MapName, "c11m5", true) > -1 || 
    StrContains(MapName, "c12m1", true) > -1 || 
    StrContains(MapName, "c12m2", true) > -1 || 
    StrContains(MapName, "c12m3", true) > -1 || 
    StrContains(MapName, "c12m4", true) > -1 || 
    StrContains(MapName, "c12m5", true) > -1 || 
    StrContains(MapName, "c13m1", true) > -1 || 
    StrContains(MapName, "c13m2", true) > -1 || 
    StrContains(MapName, "c13m3", true) > -1 || 
    StrContains(MapName, "c13m4", true) > -1 || 
    StrContains(MapName, "c14m1", true) > -1 || 
    StrContains(MapName, "c14m2", true) > -1) return true;
  return false;
}

stock bool IsValidClient(int client, bool nobots = true)
{
  if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
  {
    return false;
  }
  return IsClientInGame(client);
}


public int GetEmotePeople()
{
  int count;
  for(int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && g_bClientDancing[i]) {
      count++;
    }
  }
  return count;
}

/**
* Metodo para verificar si el jugador esta vivo
* @param int client
* @return bool
*/
public bool bIsPlayerIncapped(int client) {
  return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}