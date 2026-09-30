#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Block Votes & Admin Difficulty",
    author = "[T-T]Moy",
    description = "Bloquea votos y permite a admins cambiar dificultad",
    version = "1.1",
    url = ""
};

public void OnPluginStart()
{
    AddCommandListener(Command_CallVote, "callvote");
    RegAdminCmd("sm_difficulty", Command_Difficulty, ADMFLAG_CHANGEMAP, "Abrir menú de dificultad");
    RegAdminCmd("sm_dificultad", Command_Difficulty, ADMFLAG_CHANGEMAP, "Abrir menú de dificultad");
}

public Action Command_CallVote(int client, const char[] command, int argc)
{
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "\x04[Servidor]\x01 Los votos están desactivados. Solo admins pueden cambiar configuraciones.");
    }
    return Plugin_Handled;
}

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