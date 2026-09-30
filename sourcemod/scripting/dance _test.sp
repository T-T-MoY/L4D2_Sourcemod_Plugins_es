#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <autoexecconfig>

#pragma semicolon 1
#pragma newdecls required

#define EF_BONEMERGE            (1 << 0)
#define EF_NOSHADOW             (1 << 4)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_NORECEIVESHADOW      (1 << 6)
#define EF_PARENT_ANIMATES      (1 << 9)

ConVar g_cvSpeed;
ConVar g_cvEmotesSounds;
ConVar g_cvCooldown;
ConVar g_cvMoveSpeed;

int g_iEmoteEnt[MAXPLAYERS+1];
int g_iPlatformEnt[MAXPLAYERS+1]; // La "caja" invisible
int g_iEmoteSoundEnt[MAXPLAYERS+1];
char g_sEmoteSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];
bool g_bClientDancing[MAXPLAYERS+1];
Handle g_CooldownTimer[MAXPLAYERS+1];
Handle g_MoveTimer[MAXPLAYERS+1];

public Plugin myinfo =
{
  name = "[L4D2] Dancing Movement Platform",
  author = "Kodua, Modified",
  description = "Baila en una plataforma móvil",
  version = "3.0.0",
  url = ""
};

public void OnPluginStart()
{ 
  RegConsoleCmd("sm_dance", Command_Dance);
  RegConsoleCmd("sm_stopdance", Command_StopDance);
  
  HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
  HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
  HookEvent("round_start", Event_RoundStart);
  
  AutoExecConfig_SetFile("l4d2_dance_movement");
  g_cvEmotesSounds = AutoExecConfig_CreateConVar("sm_dance_sounds", "1", "Activar sonidos", _, true, 0.0, true, 1.0);
  g_cvCooldown = AutoExecConfig_CreateConVar("sm_dance_cooldown", "2.0", "Cooldown en segundos");
  g_cvSpeed = AutoExecConfig_CreateConVar("sm_dance_speed", "1.0", "Velocidad de animación");
  g_cvMoveSpeed = AutoExecConfig_CreateConVar("sm_dance_movespeed", "200.0", "Velocidad de movimiento de plataforma");
  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();
}

public void OnPluginEnd()
{
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && g_bClientDancing[i]) {
      StopDance(i);
    }
  }
}

public void OnMapStart()
{
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.mdl");
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.vvd");
  AddFileToDownloadsTable("models/player/kodua/fnemotes_nearlycivilized.dx90.vtx");
  
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/california_girls.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/thanos_twerk.mp3");
  AddFileToDownloadsTable("sound/kodua/fortnite_emotes/Psychic.mp3");

  PrecacheModel("models/player/kodua/fnemotes_nearlycivilized.mdl", true);
  PrecacheModel("models/props/cs_office/vending_machine.mdl", true); // Modelo para la plataforma
  
  PrecacheSound("kodua/fortnite_emotes/california_girls.mp3");
  PrecacheSound("kodua/fortnite_emotes/thanos_twerk.mp3");
  PrecacheSound("kodua/fortnite_emotes/Psychic.mp3");
}

public void OnClientPutInServer(int client)
{
  if (IsValidClient(client)) { 
    g_bClientDancing[client] = false;
    g_iEmoteEnt[client] = 0;
    g_iPlatformEnt[client] = 0;
    g_iEmoteSoundEnt[client] = 0;
    
    if (g_CooldownTimer[client] != null) {
      KillTimer(g_CooldownTimer[client]);
      g_CooldownTimer[client] = null;
    }
    if (g_MoveTimer[client] != null) {
      KillTimer(g_MoveTimer[client]);
      g_MoveTimer[client] = null;
    }
  }
}

public void OnClientDisconnect(int client)
{
  if (IsValidClient(client)) {
    StopDance(client);
    if (g_CooldownTimer[client] != null) {
      KillTimer(g_CooldownTimer[client]);
      g_CooldownTimer[client] = null;
    }
    if (g_MoveTimer[client] != null) {
      KillTimer(g_MoveTimer[client]);
      g_MoveTimer[client] = null;
    }
  }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client) && g_bClientDancing[client]) {
    StopDance(client);
  }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(attacker) && IsValidClient(client)) {
    if (GetClientTeam(attacker) != GetClientTeam(client) && g_bClientDancing[client]) {
      StopDance(client);
    }
  }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && g_bClientDancing[i]) {
      StopDance(i);
    }
  }
}

public Action Command_Dance(int client, int args)
{
  if (!IsValidClient(client)) {
    return Plugin_Handled;
  }
  
  ShowDanceMenu(client);
  return Plugin_Handled;
}

public Action Command_StopDance(int client, int args)
{
  if (!IsValidClient(client)) {
    return Plugin_Handled;
  }
  
  if (g_bClientDancing[client]) {
    StopDance(client);
    CPrintToChat(client, "{green}[Baile]{default} Has dejado de bailar");
    ShowDanceMenu(client);
  } else {
    CPrintToChat(client, "{green}[Baile]{default} No estás bailando");
  }
  
  return Plugin_Handled;
}

public void ShowDanceMenu(int client)
{
  Menu menu = new Menu(MenuHandler_Dance);
  menu.SetTitle("=== MENU DE BAILES ===");
  
  if (g_bClientDancing[client]) {
    menu.AddItem("stop", ">>> DETENER BAILE <<<");
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }
  
  menu.AddItem("1", "California Girls");
  menu.AddItem("2", "Thanos Twerk");
  menu.AddItem("3", "Gangnam Style");
  
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Dance(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select) {
    char info[16];
    menu.GetItem(param2, info, sizeof(info));
    
    if (StrEqual(info, "stop")) {
      StopDance(client);
      CPrintToChat(client, "{green}[Baile]{default} Has dejado de bailar");
      ShowDanceMenu(client);
    } else {
      int choice = StringToInt(info);
      StartDance(client, choice);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  
  return 0;
}

public void StartDance(int client, int danceID)
{
  if (!IsValidClient(client)) {
    return;
  }
  
  if (!IsPlayerAlive(client) || IsPlayerIncapped(client)) {
    CPrintToChat(client, "{green}[Baile]{default} Debes estar vivo para bailar");
    return;
  }
  
  if (g_CooldownTimer[client] != null) {
    CPrintToChat(client, "{green}[Baile]{default} Espera antes de bailar otra vez");
    return;
  }
  
  if (g_bClientDancing[client]) {
    StopDance(client);
  }
  
  char anim[64], soundName[64];
  
  switch (danceID) {
    case 1: {
      strcopy(anim, sizeof(anim), "Emote_Friday13");
      strcopy(soundName, sizeof(soundName), "california_girls");
    }
    case 2: {
      strcopy(anim, sizeof(anim), "Emote_Thanos_Twerk");
      strcopy(soundName, sizeof(soundName), "thanos_twerk");
    }
    case 3: {
      strcopy(anim, sizeof(anim), "Emote_Gangnam_Style");
      strcopy(soundName, sizeof(soundName), "Psychic");
    }
    default: return;
  }
  
  CreateDancePlatform(client, anim, soundName);
  
  CreateTimer(0.5, Timer_ShowStopMenu, GetClientUserId(client));
}

public Action Timer_ShowStopMenu(Handle timer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (client > 0 && g_bClientDancing[client]) {
    ShowDanceMenu(client);
  }
  return Plugin_Stop;
}

public void CreateDancePlatform(int client, const char[] anim, const char[] soundName)
{
  float vec[3], ang[3];
  GetClientAbsOrigin(client, vec);
  GetClientAbsAngles(client, ang);
  
  // Crear la plataforma invisible (la "caja")
  int platform = CreateEntityByName("prop_dynamic_override");
  if (!IsValidEntity(platform)) {
    return;
  }
  
  char platformName[32];
  FormatEx(platformName, sizeof(platformName), "platform_%i", GetRandomInt(100000, 999999));
  
  DispatchKeyValue(platform, "targetname", platformName);
  DispatchKeyValue(platform, "model", "models/props/cs_office/vending_machine.mdl");
  DispatchKeyValue(platform, "solid", "6"); // VPHYSICS
  DispatchKeyValue(platform, "rendermode", "10");
  DispatchKeyValue(platform, "renderamt", "0"); // Invisible
  
  DispatchSpawn(platform);
  ActivateEntity(platform);
  
  vec[2] += 10.0; // Elevar un poco la plataforma
  TeleportEntity(platform, vec, ang, NULL_VECTOR);
  
  g_iPlatformEnt[client] = EntIndexToEntRef(platform);
  
  // Crear la entidad del baile
  int emoteEnt = CreateEntityByName("prop_dynamic");
  if (!IsValidEntity(emoteEnt)) {
    AcceptEntityInput(platform, "Kill");
    return;
  }
  
  char emoteEntName[32];
  FormatEx(emoteEntName, sizeof(emoteEntName), "dance_%i", GetRandomInt(100000, 999999));
  
  DispatchKeyValue(emoteEnt, "targetname", emoteEntName);
  DispatchKeyValue(emoteEnt, "model", "models/player/kodua/fnemotes_nearlycivilized.mdl");
  DispatchKeyValue(emoteEnt, "solid", "0");
  DispatchKeyValue(emoteEnt, "rendermode", "10");
  
  ActivateEntity(emoteEnt);
  DispatchSpawn(emoteEnt);
  
  vec[2] -= 10.0; // Volver a la posición original
  TeleportEntity(emoteEnt, vec, ang, NULL_VECTOR);
  
  // Parent el baile a la plataforma
  SetVariantString(platformName);
  AcceptEntityInput(emoteEnt, "SetParent", platform, platform, 0);
  
  g_iEmoteEnt[client] = EntIndexToEntRef(emoteEnt);
  
  // Configurar animación en loop
  SetVariantString(anim);
  AcceptEntityInput(emoteEnt, "SetDefaultAnimation");
  
  SetVariantString(anim);
  AcceptEntityInput(emoteEnt, "SetAnimation");
  
  if (g_cvSpeed.FloatValue != 1.0) {
    SetEntPropFloat(emoteEnt, Prop_Send, "m_flPlaybackRate", g_cvSpeed.FloatValue);
  }
  
  // Teleportar jugador a la plataforma
  vec[2] += 65.0; // Posicionar encima de la plataforma
  TeleportEntity(client, vec, NULL_VECTOR, NULL_VECTOR);
  
  // Parent el jugador a la plataforma
  SetVariantString(platformName);
  AcceptEntityInput(client, "SetParent", platform, platform, 0);
  
  // Ocultar el jugador
  SetEntityRenderMode(client, RENDER_NONE);
  
  // Forzar cámara en tercera persona
  SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.0);
  
  // Sonido
  if (g_cvEmotesSounds.BoolValue && !StrEqual(soundName, "")) {
    int soundEnt = CreateEntityByName("info_target");
    if (IsValidEntity(soundEnt)) {
      char soundEntName[32];
      FormatEx(soundEntName, sizeof(soundEntName), "sound_%i", GetRandomInt(100000, 999999));
      
      DispatchKeyValue(soundEnt, "targetname", soundEntName);
      DispatchSpawn(soundEnt);
      
      vec[2] += 72.0;
      TeleportEntity(soundEnt, vec, NULL_VECTOR, NULL_VECTOR);
      
      SetVariantString(platformName);
      AcceptEntityInput(soundEnt, "SetParent", platform, platform, 0);
      
      g_iEmoteSoundEnt[client] = EntIndexToEntRef(soundEnt);
      
      FormatEx(g_sEmoteSound[client], PLATFORM_MAX_PATH, "kodua/fortnite_emotes/%s.mp3", soundName);
      EmitSoundToAll(g_sEmoteSound[client], client, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
    }
  }
  
  g_bClientDancing[client] = true;
  
  // Iniciar timer de movimiento
  g_MoveTimer[client] = CreateTimer(0.1, Timer_MovePlatform, GetClientUserId(client), TIMER_REPEAT);
  
  // Cooldown
  if (g_cvCooldown.FloatValue > 0.0) {
    g_CooldownTimer[client] = CreateTimer(g_cvCooldown.FloatValue, Timer_ResetCooldown, GetClientUserId(client));
  }
  
  CPrintToChat(client, "{green}[Baile]{default} ¡Bailando! Usa {olive}WASD{default} para moverte y {olive}ESPACIO{default} para saltar");
}

public Action Timer_MovePlatform(Handle timer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (client <= 0 || !g_bClientDancing[client]) {
    if (client > 0) {
      g_MoveTimer[client] = null;
    }
    return Plugin_Stop;
  }
  
  int platform = EntRefToEntIndex(g_iPlatformEnt[client]);
  if (platform == INVALID_ENT_REFERENCE || !IsValidEntity(platform)) {
    StopDance(client);
    return Plugin_Stop;
  }
  
  // Obtener input del jugador
  int buttons = GetClientButtons(client);
  float ang[3], vel[3];
  GetClientEyeAngles(client, ang);
  
  float speed = g_cvMoveSpeed.FloatValue;
  
  // Calcular movimiento basado en input
  if (buttons & IN_FORWARD) {
    vel[0] += Cosine(DegToRad(ang[1])) * speed;
    vel[1] += Sine(DegToRad(ang[1])) * speed;
  }
  if (buttons & IN_BACK) {
    vel[0] -= Cosine(DegToRad(ang[1])) * speed;
    vel[1] -= Sine(DegToRad(ang[1])) * speed;
  }
  if (buttons & IN_MOVELEFT) {
    vel[0] += Cosine(DegToRad(ang[1] + 90.0)) * speed;
    vel[1] += Sine(DegToRad(ang[1] + 90.0)) * speed;
  }
  if (buttons & IN_MOVERIGHT) {
    vel[0] += Cosine(DegToRad(ang[1] - 90.0)) * speed;
    vel[1] += Sine(DegToRad(ang[1] - 90.0)) * speed;
  }
  
  // Salto
  if (buttons & IN_JUMP) {
    vel[2] = 300.0;
  } else {
    vel[2] = -100.0; // Gravedad
  }
  
  // Aplicar velocidad a la plataforma
  if (vel[0] != 0.0 || vel[1] != 0.0 || vel[2] != 0.0) {
    float pos[3];
    GetEntPropVector(platform, Prop_Send, "m_vecOrigin", pos);
    
    pos[0] += vel[0] * 0.1;
    pos[1] += vel[1] * 0.1;
    pos[2] += vel[2] * 0.1;
    
    TeleportEntity(platform, pos, NULL_VECTOR, NULL_VECTOR);
  }
  
  return Plugin_Continue;
}

public Action Timer_ResetCooldown(Handle timer, int userid)
{
  int client = GetClientOfUserId(userid);
  if (client > 0) {
    g_CooldownTimer[client] = null;
  }
  return Plugin_Stop;
}

public void StopDance(int client)
{
  if (!g_bClientDancing[client]) {
    return;
  }
  
  // Detener timer de movimiento
  if (g_MoveTimer[client] != null) {
    KillTimer(g_MoveTimer[client]);
    g_MoveTimer[client] = null;
  }
  
  // Restaurar jugador
  if (IsValidClient(client) && IsPlayerAlive(client)) {
    AcceptEntityInput(client, "ClearParent");
    SetEntityRenderMode(client, RENDER_NORMAL);
    SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);
    
    // Bajar al jugador al suelo
    float pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] -= 65.0;
    TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
  }
  
  // Eliminar plataforma
  if (g_iPlatformEnt[client] != 0) {
    int platform = EntRefToEntIndex(g_iPlatformEnt[client]);
    if (platform != INVALID_ENT_REFERENCE && IsValidEntity(platform)) {
      AcceptEntityInput(platform, "Kill");
    }
    g_iPlatformEnt[client] = 0;
  }
  
  // Eliminar baile
  if (g_iEmoteEnt[client] != 0) {
    int emoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (emoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(emoteEnt)) {
      AcceptEntityInput(emoteEnt, "Kill");
    }
    g_iEmoteEnt[client] = 0;
  }
  
  // Detener sonido
  if (g_iEmoteSoundEnt[client] != 0) {
    int soundEnt = EntRefToEntIndex(g_iEmoteSoundEnt[client]);
    if (!StrEqual(g_sEmoteSound[client], "")) {
      StopSound(client, SNDCHAN_AUTO, g_sEmoteSound[client]);
    }
    if (soundEnt != INVALID_ENT_REFERENCE && IsValidEntity(soundEnt)) {
      AcceptEntityInput(soundEnt, "Kill");
    }
    g_iEmoteSoundEnt[client] = 0;
    g_sEmoteSound[client][0] = '\0';
  }
  
  g_bClientDancing[client] = false;
}

stock bool IsValidClient(int client, bool nobots = true)
{
  if (client <= 0 || client > MaxClients || !IsClientConnected(client)) {
    return false;
  }
  if (nobots && IsFakeClient(client)) {
    return false;
  }
  return IsClientInGame(client);
}

stock bool IsPlayerIncapped(int client)
{
  return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}