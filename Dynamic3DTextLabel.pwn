#include <a_samp>
#include <a_mysql>
#include <foreach>
#include <streamer>
#include <sscanf2>
#include <zcmd>


#define    	MYSQL_HOST        "localhost"
#define   	MYSQL_USER        "root"
#define    	MYSQL_DATABASE    "labelsys"
#define    	MYSQL_PASSWORD    ""


#define 	red 	0xFF0000FF
#define 	green 	0x00FF00FF
#define 	SCM 	SendClientMessage

#define 	MAX_LABELS 1000
#define 	LABEL_DISTANCE	20.00

#define 	DIALOG_CREATE_LABEL	30
#define 	DIALOG_EDIT_LABEL	40

enum LabelData
{
	ID,
	Text3D:Label,
	Text[74],
	Color,
	Interior,
	VirtualWorld,
	Float:PosX,
	Float:PosY,
	Float:PosZ
};
new xInfo[MAX_LABELS][LabelData],
	Iterator:Labels<MAX_LABELS>,
	MySQL:mysql;

new SelectedLabel[MAX_PLAYERS];

public OnFilterScriptInit() 
{

	mysql_log(ALL);
    mysql = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE);
    if(mysql_errno() != 0)
        print("[MySQL] Failed Connection");
    else
        print("[MySQL] Successfully Connected");

    mysql_tquery(mysql, "CREATE TABLE IF NOT EXISTS `DynamicLabels` (\
    `ID` int(5) NOT NULL AUTO_INCREMENT UNIQUE KEY,\
    `Text` varchar(74) NOT NULL,\
    `Color` int(8) NOT NULL,\
    `Interior` int(5) NOT NULL,\
    `VirtualWorld` int(5) NOT NULL,\
    `PosX` float NOT NULL,\
    `PosY` float NOT NULL,\
    `PosZ` float NOT NULL)");

    mysql_tquery(mysql, "SELECT * FROM `DynamicLabels`", "LoadDynamicLabels" "");
	return 1;
}

public OnFilterScriptInit() 
{

	DestroyAllDynamic3DTextLabels();
	return 1;
}

public OnPlayerConnect(playerid) 
{

	SelectedLabel[playerid] = -1;
	return 1;
}

public OnPlayerDisconnect(playerid, reason) 
{
	SelectedLabel[playerid] = -1;
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) 
{
	switch(dialogid) 
	{
		case DIALOG_CREATE_LABEL: 
		{
			if(response) 
			{
				switch(listitem) 
				{
					case 0: 
					{
						ShowPlayerDialog(playerid, DIALOG_CREATE_LABEL+1, DIALOG_STYLE_INPUT, "Label Text", "Enter the label text below", "Next", "Close");
					}
					case 1: 
					{
						ShowPlayerDialog(playerid, DIALOG_CREATE_LABEL+2, DIALOG_STYLE_INPUT, "Label Color", "Enter the label color below", "Next", "Close");
					}
					case 2: 
					{
						ShowPlayerDialog(playerid, DIALOG_CREATE_LABEL+3, DIALOG_STYLE_INPUT, "Label Interior", "Enter the label interior below", "Next", "Close");
					}
					case 3: 
					{
						ShowPlayerDialog(playerid, DIALOG_CREATE_LABEL+4, DIALOG_STYLE_INPUT, "Label Virtual World", "Enter the label virtual world below", "Next", "Close");
					}
					case 4: 
					{
						new id = Iter_Free(Labels);
						if(id == -1) return SCM(playerid, red, "You can't create more labels");
						if(strlen(xInfo[id][Text]) < 1) return SCM(playerid, red, "Please enter a valid text");
						if(IsPlayerInAnyVehicle(playerid)) return SCM(playerid, red, "You must be on foot to create the label");

						GetPlayerPos(playerid, xInfo[id][PosX], xInfo[id][PosY], xInfo[id][PosZ]);

						xInfo[id][Label] = CreateDynamic3DTextLabel(xInfo[id][Text], xInfo[id][Color], xInfo[id][PosX], xInfo[id][PosY],
						xInfo[id][PosZ], LABEL_DISTANCE, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, xInfo[id][VirtualWorld], xInfo[id][Interior]);

						new query[200];
						format(query, sizeof(query), "You have created a new label with ID: %i", id);
						SCM(playerid, green, query);

						mysql_format(mysql, query, sizeof(query), "INSERT INTO `DynamicLabels` (Text, Color, VirtualWorld, Interior, PosX, PosY, PosZ) \
						VALUES ('%e', %i, %i, %i, %f, %f, %f)", xInfo[id][Text], xInfo[id][Color], xInfo[id][VirtualWorld], xInfo[id][Interior], xInfo[id][PosX], 
						xInfo[id][PosY], xInfo[id][PosZ]);
						mysql_tquery(mysql, query, "OnLabelCreated", "i", id);
					}
				}
			}
		}
		case DIALOG_CREATE_LABEL+1: 
		{
			if(response) 
			{
				new id = Iter_Free(Labels);
				if(isnull(inputtext)) return SCM(playerid, red, "Please enter a valid text");
				
				format(xInfo[id][Text], 74, inputtext);
				NewLines(inputtext, strlen(inputtext));
				UpdateDynamic3DTextLabelText(xInfo[id][Label], xInfo[id][Color], inputtext);

				cmd_createlabel(playerid, "");
			}
		}
		case DIALOG_CREATE_LABEL+2: 
		{
			if(response) 
			{
				new id = Iter_Free(Labels);
				if(strlen(inputtext) != 6) return SCM(playerid, red, "Invalid hex color");

				new color;
				if (sscanf(inputtext, "x", color)) return SCM(playerid, red, "Please enter a valid color (RRGGBB)");

				color = (color << 8) | 0xFF;

				xInfo[id][Color] = color;
				cmd_createlabel(playerid, "");
			}
		}
		case DIALOG_CREATE_LABEL+3: 
		{
			if(response) 
			{
				new id = Iter_Free(Labels);
				if(!IsNumeric(inputtext)) return SCM(playerid, red, "You have entered an invalid interior ID");

				xInfo[id][Interior] = strval(inputtext);
				cmd_createlabel(playerid, "");
			}
		}
		case DIALOG_CREATE_LABEL+4: 
		{
			if(response) 
			{
				new id = Iter_Free(Labels);
				if(!IsNumeric(inputtext)) return SCM(playerid, red, "You have entered an invalid virtual world ID");
				if(strval(inputtext) == -1) return SCM(playerid, red, "You have entered an invalid virtual world ID");

				xInfo[id][VirtualWorld] = strval(inputtext);
				cmd_createlabel(playerid, "");
			}
		}
		case DIALOG_EDIT_LABEL: 
		{

			if(response) 
			{
				switch(listitem) 
				{
					case 0: 
					{

						ShowPlayerDialog(playerid, DIALOG_EDIT_LABEL+1, DIALOG_STYLE_INPUT, "Label Text", "Enter the label text below", "Next", "Close");
					}
					case 1: 
					{

						ShowPlayerDialog(playerid, DIALOG_EDIT_LABEL+2, DIALOG_STYLE_INPUT, "Label Color", "Enter the label color below", "Next", "Close");
					}
					case 2: 
					{

						ShowPlayerDialog(playerid, DIALOG_EDIT_LABEL+3, DIALOG_STYLE_INPUT, "Label Interior", "Enter the label interior below", "Next", "Close");
					}
					case 3: 
					{

						ShowPlayerDialog(playerid, DIALOG_EDIT_LABEL+4, DIALOG_STYLE_INPUT, "Label Virtual World", "Enter the label virtual world below", "Next", "Close");
					}
					case 4: 
					{

						new id = SelectedLabel[playerid];
						SetPlayerPos(playerid, xInfo[id][PosX], xInfo[id][PosY], xInfo[id][PosZ]);
						SetPlayerInterior(playerid, xInfo[id][Interior]);
						SetPlayerVirtualWorld(playerid, xInfo[id][VirtualWorld]);
					}
					case 5:
					{

						new id = SelectedLabel[playerid];
						DestroyDynamic3DTextLabel(xInfo[id][Label]);

						GetPlayerPos(playerid, xInfo[id][PosX], xInfo[id][PosY], xInfo[id][PosZ]);

						xInfo[id][Label] = CreateDynamic3DTextLabel(xInfo[id][Text], xInfo[id][Color], xInfo[id][PosX], xInfo[id][PosY],
						xInfo[id][PosZ], LABEL_DISTANCE, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, xInfo[id][VirtualWorld], xInfo[id][Interior]);
					}
					case 6: 
					{

						new id = SelectedLabel[playerid];
						DestroyDynamic3DTextLabel(xInfo[id][Label]);
						Iter_Remove(Labels, id);

						new query[60];
						mysql_format(mysql, query, sizeof(query), "DELETE FROM `DynamicLabels` WHERE `ID` = %i", xInfo[id][ID]);
						mysql_tquery(mysql, query);
					}
				}
			}
		}
		case DIALOG_EDIT_LABEL+1: 
		{
			if(response) 
			{
				new id = SelectedLabel[playerid];
				if(isnull(inputtext)) return SCM(playerid, red, "Please enter a valid text");

				format(xInfo[id][Text], 74, inputtext);
				NewLines(inputtext, strlen(inputtext));
				UpdateDynamic3DTextLabelText(xInfo[id][Label], xInfo[id][Color], inputtext);
				
				new strcmd[5];
				format(strcmd, sizeof(strcmd), "%i", id);
				cmd_editlabel(playerid, strcmd);
			}
		}
		case DIALOG_EDIT_LABEL+2: 
		{
			if(response) 
			{
				new id = SelectedLabel[playerid];

				if(strlen(inputtext) != 6) return SCM(playerid, red, "Invalid hex color");

				new color;
				if (sscanf(inputtext, "x", color)) return SCM(playerid, red, "Please enter a valid color (RRGGBB)");

				color = (color << 8) | 0xFF;
				
				xInfo[id][Color] = color;
				UpdateDynamic3DTextLabelText(xInfo[id][Label], color, xInfo[id][Text]);
				
				new strcmd[5];
				format(strcmd, sizeof(strcmd), "%i", id);
				cmd_editlabel(playerid, strcmd);
			}
		}
		case DIALOG_EDIT_LABEL+3: 
		{
			if(response) 
			{
				if(!IsNumeric(inputtext)) return SCM(playerid, red, "You have entered an invalid interior ID");

				new id = SelectedLabel[playerid];
				DestroyDynamic3DTextLabel(xInfo[id][Label]);

				GetPlayerPos(playerid, xInfo[id][PosX], xInfo[id][PosY], xInfo[id][PosZ]);

				xInfo[id][Label] = CreateDynamic3DTextLabel(xInfo[id][Text], xInfo[id][Color], xInfo[id][PosX], xInfo[id][PosY],
				xInfo[id][PosZ], LABEL_DISTANCE, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, xInfo[id][VirtualWorld], strval(inputtext));
				
				new strcmd[5];
				format(strcmd, sizeof(strcmd), "%i", id);
				cmd_editlabel(playerid, strcmd);
			}
		}
		case DIALOG_EDIT_LABEL+4: 
		{
			if(response) 
			{
				if(!IsNumeric(inputtext)) return SCM(playerid, red, "You have entered an invalid virtual world ID");
				if(strval(inputtext) == -1) return SCM(playerid, red, "You have entered an invalid virtual world ID");

				new id = SelectedLabel[playerid];
				DestroyDynamic3DTextLabel(xInfo[id][Label]);

				GetPlayerPos(playerid, xInfo[id][PosX], xInfo[id][PosY], xInfo[id][PosZ]);

				xInfo[id][Label] = CreateDynamic3DTextLabel(xInfo[id][Text], xInfo[id][Color], xInfo[id][PosX], xInfo[id][PosY],
				xInfo[id][PosZ], LABEL_DISTANCE, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, strval(inputtext), xInfo[id][Interior]);

				new strcmd[5];
				format(strcmd, sizeof(strcmd), "%i", id);
				cmd_editlabel(playerid, strcmd);
			}
		}
	}
	return 0;
}

forward OnLabelCreated(labelid);
public OnLabelCreated(labelid) 
{
	xInfo[labelid][ID] = cache_insert_id();
	Iter_Add(Labels, labelid);
	return 1;
}

forward LoadDynamicLabels();
public LoadDynamicLabels() 
{
	new rows = cache_num_rows();

	if(rows) 
	{
		for(new i; i < rows; i++) 
		{
			new id = Iter_Free(Labels);

			cache_get_value_name_int(i, "ID", xInfo[id][ID]);
			cache_get_value_name(i, "Text", xInfo[id][Text]);
			cache_get_value_name_int(i, "Color", xInfo[id][Color]);
			cache_get_value_name_int(i, "Interior", xInfo[id][Interior]);
			cache_get_value_name_int(i, "VirtualWorld", xInfo[id][VirtualWorld]);
			cache_get_value_name_float(i, "PosX", xInfo[id][PosX]);
			cache_get_value_name_float(i, "PosY", xInfo[id][PosY]);
			cache_get_value_name_float(i, "PosZ", xInfo[id][PosZ]);

			NewLines(xInfo[id][Text], strlen(xInfo[id][Text]));

			xInfo[id][Label] = CreateDynamic3DTextLabel(xInfo[id][Text], xInfo[id][Color], xInfo[id][PosX], xInfo[id][PosY],
			xInfo[id][PosZ], LABEL_DISTANCE, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, xInfo[id][VirtualWorld], xInfo[id][Interior]);

			Iter_Add(Labels, id);
		}
		printf("Loaded %i dynamic labels", rows);
	}
}

CMD:createlabel(playerid, params[]) 
{
	if(!IsPlayerAdmin(playerid)) return SCM(playerid, red, "You must be an administrator to use this command");

	new id = Iter_Free(Labels);

	xInfo[id][Interior] = 0;
	xInfo[id][VirtualWorld] = 0;

	new string[300];
	format(string, sizeof(string), "{FFFFFF}Text: {00FF00}%s\n{FFFFFF}Color: {00FF00}%x\n{FFFFFF}Interior: {00FF00}%i\n{FFFFFF}Virtual World: {00FF00}%i\n{00FF00}Create Label",
	xInfo[id][Text], xInfo[id][Color], xInfo[id][Interior], xInfo[id][VirtualWorld]);

	ShowPlayerDialog(playerid, DIALOG_CREATE_LABEL, DIALOG_STYLE_LIST, "Create 3D Label", string, "Select", "Cancel");
	return 1;
}

CMD:editlabel(playerid, params[]) 
{
	if(!IsPlayerAdmin(playerid)) return SCM(playerid, red, "You must be an administrator to use this command");

	new id;
	if(sscanf(params, "i", id)) return SCM(playerid, red, "Edit label: /editlabel <ID>");
	if(!Iter_Contains(Labels, id)) return SCM(playerid, red, "Invalid label ID");

	SelectedLabel[playerid] = id;

	new string[300];
	format(string, sizeof(string), "{FFFFFF}Text: {00FF00}%s\n{FFFFFF}Color: {00FF00}%x\n{FFFFFF}Interior: {00FF00}%i\n{FFFFFF}Virtual World: {00FF00}%i\n\
	{00FF00}Teleport to Label\nMove Label\n{FF0000}Destroy Label", xInfo[id][Text], xInfo[id][Color], xInfo[id][Interior], xInfo[id][VirtualWorld]);

	ShowPlayerDialog(playerid, DIALOG_EDIT_LABEL, DIALOG_STYLE_LIST, "Edit 3D Label", string, "Select", "Cancel");
	return 1;
}

CMD:labels(playerid, params[]) 
{
	if(!IsPlayerAdmin(playerid)) return SCM(playerid, red, "You must be an administrator to use this command");
	if(Iter_Count(Labels) == 0) return SCM(playerid, red, "There are no labels currently");

	new string[128], s[300];
	foreach(new i : Labels) 
	{
		format(string, sizeof(string), "{FFFFFF}ID: {00FF00}%i {FFFFFF}Text: {00FF00}%s\n", i, xInfo[i][Text]);
		strcat(s, string);
	}

	ShowPlayerDialog(playerid, 1, DIALOG_STYLE_LIST, "3D Labels", s, "Close", "");
	return 1;
}

IsNumeric(string[])
{
    for (new i = 0, j = strlen(string); i < j; i++)
    {
    	if (string[i] > '9' || string[i] < '0') return 0;
    }
    return 1;
}

NewLines(text[], length) // Credits to Konstantinos
{
    for (new i; i != length; i++)
    {
        if (text[i] == '\\' && i != length - 1 && text[i + 1] == 'n')
        {
            text[i] = ' ';
            text[i + 1] = '\n';
            i++;
        }
    }
}
