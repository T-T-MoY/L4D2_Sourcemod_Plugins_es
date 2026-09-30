#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0"

// Variables para votación de restart
bool g_bRestartVoteInProgress = false;
int g_iRestartVotesYes = 0;
int g_iRestartVotesNo = 0;
ArrayList g_alRestartVoters;

// Variables para votación de voz global
bool g_bVoiceVoteInProgress = false;
int g_iVoiceVotesYes = 0;
int g_iVoiceVotesNo = 0;
ArrayList g_alVoiceVoters;
bool g_bGlobalVoiceEnabled = false;

public Plugin myinfo = 
{
    name = "Block Votes & Admin Difficulty + Extras",
    author = "[T-T]Moy",
    description = "Bloquea votos, permite a admins cambiar dificultad, restart y voz global",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    AddCommandListener(Command_CallVote, "callvote");
    RegAdminCmd("sm_difficulty", Command_Difficulty, ADMFLAG_CHANGEMAP, "Abrir menú de dificultad");
    RegAdminCmd("sm_dificultad", Command_Difficulty, ADMFLAG_CHANGEMAP, "Abrir menú de dificultad");
    
    // ========== NUEVAS FUNCIONALIDADES ==========
    
    // Comandos de Restart Chapter (solo admin)
    RegAdminCmd("sm_restart", Command_RestartChapter, ADMFLAG_CHANGEMAP, "Reinicia el capitulo actual");
    RegAdminCmd("sm_restartchapter", Command_RestartChapter, ADMFLAG_CHANGEMAP, "Reinicia el capitulo actual");
    RegAdminCmd("sm_restartmap", Command_RestartChapter, ADMFLAG_CHANGEMAP, "Reinicia el capitulo actual");
    
    // Comandos de votación para restart (solo admin inicia)
    RegAdminCmd("sm_voterestart", Command_VoteRestart, ADMFLAG_CHANGEMAP, "Iniciar votacion para reiniciar capitulo");
    RegAdminCmd("sm_voterestartchapter", Command_VoteRestart, ADMFLAG_CHANGEMAP, "Iniciar votacion para reiniciar capitulo");
    
    // Comandos de voz global para Versus (solo admin)
    RegAdminCmd("sm_globalvoice", Command_GlobalVoice, ADMFLAG_CHANGEMAP, "Activar/Desactivar voz global en Versus");
    RegAdminCmd("sm_allvoice", Command_GlobalVoice, ADMFLAG_CHANGEMAP, "Activar/Desactivar voz global en Versus");
    RegAdminCmd("sm_vozglobal", Command_GlobalVoice, ADMFLAG_CHANGEMAP, "Activar/Desactivar voz global en Versus");
    
    // Comandos de votación para voz global (solo admin inicia)
    RegAdminCmd("sm_votevoice", Command_VoteVoice, ADMFLAG_CHANGEMAP, "Iniciar votacion para voz global");
    RegAdminCmd("sm_voteglobalvoice", Command_VoteVoice, ADMFLAG_CHANGEMAP, "Iniciar votacion para voz global");
    RegAdminCmd("sm_votevoz", Command_VoteVoice, ADMFLAG_CHANGEMAP, "Iniciar votacion para voz global");
    
    // Comandos de votación para TODOS los jugadores
    RegConsoleCmd("sm_yes", Command_VoteYes, "Votar SI en votacion activa");
    RegConsoleCmd("sm_no", Command_VoteNo, "Votar NO en votacion activa");
    RegConsoleCmd("sm_si", Command_VoteYes, "Votar SI en votacion activa");
    
    // Inicializar arrays
    g_alRestartVoters = new ArrayList();
    g_alVoiceVoters = new ArrayList();
    
    // Hook para eventos
    HookEvent("round_start", Event_RoundStart);
}

// ==================== CÓDIGO ORIGINAL - BLOQUEO DE VOTOS ====================

public Action Command_CallVote(int client, const char[] command, int argc)
{
    if (client > 0 && IsClientInGame(client))
    {
        // Si es admin → permitir voto
        if (CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
        {
            return Plugin_Continue;
        }

        // Si NO es admin → bloquear
        PrintToChat(client, "\x04[Servidor]\x01 Los votos están desactivados. Solo admins pueden usar votaciones.");
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// ==================== CÓDIGO ORIGINAL - DIFICULTAD ====================

public Action Command_Difficulty(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[SM] Este comando solo puede usarse en el juego.");
        return Plugin_Handled;
    }
    
    ShowDifficultyMenu(client);
    return Plugin_Handled;
}

void ShowDifficultyMenu(int client)
{
    Menu menu = new Menu(DifficultyMenuHandler);
    menu.SetTitle("Seleccionar Dificultad:");
    
    menu.AddItem("easy", "Fácil (Easy)");
    menu.AddItem("normal", "Normal");
    menu.AddItem("hard", "Avanzado (Hard)");
    menu.AddItem("impossible", "Experto (Expert)");
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int DifficultyMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(selection, info, sizeof(info));
        
        char difficulty[32];
        switch (selection)
        {
            case 0: difficulty = "Easy";
            case 1: difficulty = "Normal";
            case 2: difficulty = "Hard";
            case 3: difficulty = "Expert";
        }
        
        ServerCommand("z_difficulty %s", info);
        
        char adminName[64];
        GetClientName(client, adminName, sizeof(adminName));
        
        PrintToChatAll("\x04[Admin]\x01 %s ha cambiado la dificultad a \x03%s", adminName, difficulty);
        LogAction(client, -1, "\"%L\" cambió la dificultad a %s", client, info);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

// ==================== NUEVO: RESTART CHAPTER DIRECTO ====================

public Action Command_RestartChapter(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    PrintToChatAll("\x04[Admin] \x03%N \x01ha reiniciado el capitulo!", client);
    LogAction(client, -1, "\"%L\" reinició el capítulo", client);
    
    CreateTimer(2.0, Timer_RestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Handled;
}

public Action Timer_RestartMap(Handle timer)
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ServerCommand("changelevel %s", mapName);
    return Plugin_Stop;
}

// ==================== NUEVO: VOTACION RESTART ====================

public Action Command_VoteRestart(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (g_bRestartVoteInProgress)
    {
        PrintToChat(client, "\x04[Votacion] \x01Ya hay una votacion de restart en progreso!");
        return Plugin_Handled;
    }
    
    if (g_bVoiceVoteInProgress)
    {
        PrintToChat(client, "\x04[Votacion] \x01Ya hay una votacion de voz en progreso!");
        return Plugin_Handled;
    }
    
    StartRestartVote(client);
    return Plugin_Handled;
}

void StartRestartVote(int client)
{
    g_bRestartVoteInProgress = true;
    g_iRestartVotesYes = 0;
    g_iRestartVotesNo = 0;
    g_alRestartVoters.Clear();
    
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x05        VOTACION: Reiniciar Capitulo");
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x03Admin %N \x01inició votación para \x05reiniciar el capitulo", client);
    PrintToChatAll("\x01Escribe \x04!yes \x01(o \x04!si\x01) / \x03!no \x01para votar");
    PrintToChatAll("\x01Tiempo: \x0530 segundos");
    PrintToChatAll("\x04═══════════════════════════════════════");
    
    LogAction(client, -1, "\"%L\" inició votación de restart", client);
    
    CreateTimer(30.0, Timer_EndRestartVote, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(20.0, Timer_RestartVoteWarning, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RestartVoteWarning(Handle timer)
{
    if (g_bRestartVoteInProgress)
    {
        PrintToChatAll("\x04[Votacion] \x01¡Quedan \x0510 segundos \x01para votar!");
    }
    return Plugin_Stop;
}

public Action Timer_EndRestartVote(Handle timer)
{
    if (!g_bRestartVoteInProgress)
        return Plugin_Stop;
    
    g_bRestartVoteInProgress = false;
    
    int totalVotes = g_iRestartVotesYes + g_iRestartVotesNo;
    
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x05        RESULTADO DE LA VOTACION");
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x04Votos SI: \x05%d \x01| \x04Votos NO: \x03%d", g_iRestartVotesYes, g_iRestartVotesNo);
    
    if (totalVotes == 0)
    {
        PrintToChatAll("\x04[Votacion] \x03¡Nadie votó! \x01Votación cancelada.");
        PrintToChatAll("\x04═══════════════════════════════════════");
        return Plugin_Stop;
    }
    
    float yesPercentage = (float(g_iRestartVotesYes) / float(totalVotes)) * 100.0;
    
    if (yesPercentage >= 60.0)
    {
        PrintToChatAll("\x04[Votacion] \x05¡APROBADA! \x01(%.0f%%) Reiniciando en 3 segundos...", yesPercentage);
        PrintToChatAll("\x04═══════════════════════════════════════");
        CreateTimer(3.0, Timer_RestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        PrintToChatAll("\x04[Votacion] \x03¡RECHAZADA! \x01(%.0f%%) Se necesita 60%% o más.", yesPercentage);
        PrintToChatAll("\x04═══════════════════════════════════════");
    }
    
    return Plugin_Stop;
}

// ==================== NUEVO: VOZ GLOBAL DIRECTO ====================

public Action Command_GlobalVoice(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (!IsVersusMode())
    {
        PrintToChat(client, "\x04[Voice] \x01Este comando solo funciona en modo \x05Versus\x01!");
        return Plugin_Handled;
    }
    
    g_bGlobalVoiceEnabled = !g_bGlobalVoiceEnabled;
    
    if (g_bGlobalVoiceEnabled)
    {
        EnableGlobalVoice();
        PrintToChatAll("\x04[Admin] \x03%N \x01ha \x05ACTIVADO \x01la voz global en Versus!", client);
        LogAction(client, -1, "\"%L\" activó voz global", client);
    }
    else
    {
        DisableGlobalVoice();
        PrintToChatAll("\x04[Admin] \x03%N \x01ha \x03DESACTIVADO \x01la voz global en Versus!", client);
        LogAction(client, -1, "\"%L\" desactivó voz global", client);
    }
    
    return Plugin_Handled;
}

// ==================== NUEVO: VOTACION VOZ GLOBAL ====================

public Action Command_VoteVoice(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (!IsVersusMode())
    {
        PrintToChat(client, "\x04[Voice] \x01Este comando solo funciona en modo \x05Versus\x01!");
        return Plugin_Handled;
    }
    
    if (g_bVoiceVoteInProgress)
    {
        PrintToChat(client, "\x04[Votacion] \x01Ya hay una votacion de voz en progreso!");
        return Plugin_Handled;
    }
    
    if (g_bRestartVoteInProgress)
    {
        PrintToChat(client, "\x04[Votacion] \x01Ya hay una votacion de restart en progreso!");
        return Plugin_Handled;
    }
    
    StartVoiceVote(client);
    return Plugin_Handled;
}

void StartVoiceVote(int client)
{
    g_bVoiceVoteInProgress = true;
    g_iVoiceVotesYes = 0;
    g_iVoiceVotesNo = 0;
    g_alVoiceVoters.Clear();
    
    char voteAction[32];
    Format(voteAction, sizeof(voteAction), g_bGlobalVoiceEnabled ? "Desactivar" : "Activar");
    
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x05        VOTACION: %s Voz Global", voteAction);
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x03Admin %N \x01inició votación para \x05%s voz global", client, voteAction);
    PrintToChatAll("\x01Escribe \x04!yes \x01(o \x04!si\x01) / \x03!no \x01para votar");
    PrintToChatAll("\x01Tiempo: \x0530 segundos");
    PrintToChatAll("\x04═══════════════════════════════════════");
    
    LogAction(client, -1, "\"%L\" inició votación de voz global", client);
    
    CreateTimer(30.0, Timer_EndVoiceVote, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(20.0, Timer_VoiceVoteWarning, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_VoiceVoteWarning(Handle timer)
{
    if (g_bVoiceVoteInProgress)
    {
        PrintToChatAll("\x04[Votacion] \x01¡Quedan \x0510 segundos \x01para votar!");
    }
    return Plugin_Stop;
}

public Action Timer_EndVoiceVote(Handle timer)
{
    if (!g_bVoiceVoteInProgress)
        return Plugin_Stop;
    
    g_bVoiceVoteInProgress = false;
    
    int totalVotes = g_iVoiceVotesYes + g_iVoiceVotesNo;
    
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x05        RESULTADO DE LA VOTACION");
    PrintToChatAll("\x04═══════════════════════════════════════");
    PrintToChatAll("\x04Votos SI: \x05%d \x01| \x04Votos NO: \x03%d", g_iVoiceVotesYes, g_iVoiceVotesNo);
    
    if (totalVotes == 0)
    {
        PrintToChatAll("\x04[Votacion] \x03¡Nadie votó! \x01Votación cancelada.");
        PrintToChatAll("\x04═══════════════════════════════════════");
        return Plugin_Stop;
    }
    
    float yesPercentage = (float(g_iVoiceVotesYes) / float(totalVotes)) * 100.0;
    
    if (yesPercentage >= 60.0)
    {
        PrintToChatAll("\x04[Votacion] \x05¡APROBADA! \x01(%.0f%%)", yesPercentage);
        
        if (g_bGlobalVoiceEnabled)
        {
            DisableGlobalVoice();
            PrintToChatAll("\x04[Voice] \x03¡Voz global DESACTIVADA!");
            g_bGlobalVoiceEnabled = false;
        }
        else
        {
            EnableGlobalVoice();
            PrintToChatAll("\x04[Voice] \x05¡Voz global ACTIVADA!");
            g_bGlobalVoiceEnabled = true;
        }
        PrintToChatAll("\x04═══════════════════════════════════════");
    }
    else
    {
        PrintToChatAll("\x04[Votacion] \x03¡RECHAZADA! \x01(%.0f%%) Se necesita 60%% o más.", yesPercentage);
        PrintToChatAll("\x04═══════════════════════════════════════");
    }
    
    return Plugin_Stop;
}

// ==================== COMANDOS DE VOTACION PARA TODOS ====================

public Action Command_VoteYes(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (g_bRestartVoteInProgress)
    {
        if (g_alRestartVoters.FindValue(client) != -1)
        {
            PrintToChat(client, "\x04[Votacion] \x01¡Ya has votado!");
            return Plugin_Handled;
        }
        
        g_alRestartVoters.Push(client);
        g_iRestartVotesYes++;
        PrintToChatAll("\x05%N \x01votó \x04SI \x01para restart (\x04%d SI \x01| \x03%d NO\x01)", 
            client, g_iRestartVotesYes, g_iRestartVotesNo);
    }
    else if (g_bVoiceVoteInProgress)
    {
        if (g_alVoiceVoters.FindValue(client) != -1)
        {
            PrintToChat(client, "\x04[Votacion] \x01¡Ya has votado!");
            return Plugin_Handled;
        }
        
        g_alVoiceVoters.Push(client);
        g_iVoiceVotesYes++;
        PrintToChatAll("\x05%N \x01votó \x04SI \x01para voz global (\x04%d SI \x01| \x03%d NO\x01)", 
            client, g_iVoiceVotesYes, g_iVoiceVotesNo);
    }
    else
    {
        PrintToChat(client, "\x04[Votacion] \x01No hay ninguna votación activa!");
    }
    
    return Plugin_Handled;
}

public Action Command_VoteNo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (g_bRestartVoteInProgress)
    {
        if (g_alRestartVoters.FindValue(client) != -1)
        {
            PrintToChat(client, "\x04[Votacion] \x01¡Ya has votado!");
            return Plugin_Handled;
        }
        
        g_alRestartVoters.Push(client);
        g_iRestartVotesNo++;
        PrintToChatAll("\x05%N \x01votó \x03NO \x01para restart (\x04%d SI \x01| \x03%d NO\x01)", 
            client, g_iRestartVotesYes, g_iRestartVotesNo);
    }
    else if (g_bVoiceVoteInProgress)
    {
        if (g_alVoiceVoters.FindValue(client) != -1)
        {
            PrintToChat(client, "\x04[Votacion] \x01¡Ya has votado!");
            return Plugin_Handled;
        }
        
        g_alVoiceVoters.Push(client);
        g_iVoiceVotesNo++;
        PrintToChatAll("\x05%N \x01votó \x03NO \x01para voz global (\x04%d SI \x01| \x03%d NO\x01)", 
            client, g_iVoiceVotesYes, g_iVoiceVotesNo);
    }
    else
    {
        PrintToChat(client, "\x04[Votacion] \x01No hay ninguna votación activa!");
    }
    
    return Plugin_Handled;
}

// ==================== FUNCIONES DE VOZ ====================

void EnableGlobalVoice()
{
    ServerCommand("sv_alltalk 1");
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            SetClientListeningFlags(i, VOICE_NORMAL);
        }
    }
}

void DisableGlobalVoice()
{
    ServerCommand("sv_alltalk 0");
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            SetClientListeningFlags(i, VOICE_TEAM);
        }
    }
}

// ==================== EVENTOS ====================

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Resetear votaciones al inicio de ronda
    g_bRestartVoteInProgress = false;
    g_bVoiceVoteInProgress = false;
}

// ==================== FUNCIONES AUXILIARES ====================

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

bool IsVersusMode()
{
    char gameMode[32];
    FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
    return (StrEqual(gameMode, "versus", false) || StrEqual(gameMode, "teamversus", false));
}