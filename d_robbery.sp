#include <sourcemod>
#include <sdktools>
#include <csgo_colors>
#include <sdkhooks>

#define MONEYBAG_COUNT 5

new String:g_cfg_file[PLATFORM_MAX_PATH];
new String:g_cMap[34];
new Handle:h_kv_cfg;
new Float:g_MoneyPoint[3];
new Float:g_BackPoint[3];

new Handle:t_PlayerTake[MAXPLAYERS+1];
new g_MoneyBags[MONEYBAG_COUNT];

public Plugin:myinfo = 
{ 
    name = "Robbery Mod", 
    author = "Primo & Hejter", 
    description = "Robbery Mod to CSGO.", 
    version = "1.1", 
} 

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	BuildPath(Path_SM, g_cfg_file, sizeof(g_cfg_file), "configs/robbery/point.txt");
	
	if (!FileExists(g_cfg_file) && !FileExists(g_cfg_file, true))
	{
		FormatEx(error, err_max, "%s not exists", g_cfg_file);
		return APLRes_Failure;
	}
	
	return APLRes_Success;
}

public OnPluginStart() 
{
	HookEvent("round_start", RoundStart);
	
	RegAdminCmd("sm_bpos_reload", cmd_Reload, ADMFLAG_ROOT, "Reload cfgs");
	RegAdminCmd("sm_mpoint_set", cmd_SetMoneyPoint, ADMFLAG_ROOT, "Set money position");
	RegAdminCmd("sm_bpoint_set", cmd_SetBackPoint, ADMFLAG_ROOT, "Set backpoint position");
}

public OnMapStart()
{
	LoadCfg();
	PrecacheModel("models/props/cs_italy/bin03.mdl", true);
	PrecacheModel("models/props/cs_militia/footlocker01_closed.mdl", true);
}

LoadCfg()
{
	if (h_kv_cfg == INVALID_HANDLE)
	{
		h_kv_cfg = CreateKeyValues("Points");
		if (!FileToKeyValues(h_kv_cfg, g_cfg_file)) 
		{
			CloseHandle(h_kv_cfg);
			h_kv_cfg = INVALID_HANDLE;
			ThrowError("Could not parse %s", g_cfg_file);
		}
	}
	
	if (KvJumpToKey(h_kv_cfg, g_cMap, false))
	{
		KvGetVector(h_kv_cfg, "money", g_MoneyPoint);
		KvGetVector(h_kv_cfg, "backpoint", g_BackPoint);
	}
	else
	{
	}
	KvRewind(h_kv_cfg);
}

public Action:cmd_SetMoneyPoint(client, argc)
{
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}
	
	decl Float:pos[3];
	if (h_kv_cfg != INVALID_HANDLE && GetPlayerEye(client, pos))
	{
		KvJumpToKey(h_kv_cfg, g_cMap, true);
		pos[2] += 30.0;
		KvSetVector(h_kv_cfg, "money", pos);
		KvRewind(h_kv_cfg);
		KeyValuesToFile(h_kv_cfg, g_cfg_file);
		PrintToChat(client, "%s: %d:%d:%d", "Точка денег установлена", pos[0], pos[1], pos[2]);
	}
	else
	{
		PrintToChat(client, "%s", "Произошла ошибка. Точка не установлена");
	}
	
	return Plugin_Handled;
}

stock bool:GetPlayerEye(client, Float:pos[3])
{
	decl Float:vAngles[3], Float:vOrigin[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayers);

	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return true;
	}

	CloseHandle(trace);
	return false;
}

public bool:TraceEntityFilterPlayers(entity, contentsMask)
{
	return (!(0 < entity <= MaxClients));
}

public Action:cmd_SetBackPoint(client, argc) 
{
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}
	
	decl Float:pos[3];
	if (h_kv_cfg != INVALID_HANDLE && GetPlayerEye(client, pos))
	{
		KvJumpToKey(h_kv_cfg, g_cMap, true);
		pos[2] += 30.0;
		KvSetVector(h_kv_cfg, "backpoint", pos);
		KvRewind(h_kv_cfg);
		KeyValuesToFile(h_kv_cfg, g_cfg_file);
		PrintToChat(client, "%s: %d:%d:%d", "Точка backpoint установлена", pos[0], pos[1], pos[2]);
	}
	else
	{
		PrintToChat(client, "%s", "Произошла ошибка. Точка не установлена");
	}
	
	return Plugin_Handled;
}

public Action:cmd_Reload(client, argc)
{
	if (h_kv_cfg != INVALID_HANDLE)
	{
		CloseHandle(h_kv_cfg);
		h_kv_cfg = INVALID_HANDLE;
	}
	LoadCfg();
	ReplyToCommand(client, "Настройки перезагружены!");
}


public RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	func_SpawnMoneyPack(MONEYBAG_COUNT);
}

public Action:OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsClientInGame(client)) return;
	
	if(buttons & IN_USE)
	{
		if(IsPlayerAlive(client))
		{ 
			for(new i; i < MONEYBAG_COUNT; i++)
			{
				if(GetClientAimTarget(client) == g_MoneyBags[i]) 
				{
					SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime()); 
					SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 3);
					SetEntityRenderColor(client, 255, 0, 0, 0);
					SetEntityMoveType(client, MOVETYPE_NONE);
					//AcceptEntityInpit(g_MoneyBags, "Kill");
					
					new Handle:pack;
					WritePackCell(pack, client);
					WritePackCell(pack, i);

					t_PlayerTake[client] = CreateDataTimer(3.0, tm_PlayerTake, pack);
				}
			}
		}
	}
	else if(t_PlayerTake[client]) 
	{	
		func_UnTakeBag(client);
	}
}

public func_UnTakeBag(client)
{
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime()); 
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
}

public Action:tm_PlayerTake(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new ent = ReadPackCell(pack);
    
	if (IsPlayerAlive(client))
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime()); 
		SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
		
		decl Float:p_pos1[3];		
		decl Float:p_angle1[3];
		
		GetClientAbsOrigin(client,p_pos1);
		GetClientAbsAngles(client,p_angle1);
		
		p_pos1[2] += 30.0;	
		p_angle1[1] += 70.0;
		
		AcceptEntityInput(ent, "TurnOn", ent, ent, 0);

		// Teleport the hat to the right position and attach it
		TeleportEntity(ent, p_pos1, p_angle1, NULL_VECTOR); 
			
		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", client, ent, 0);
			
		SetVariantString("facemask");
		AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
		
		CGOPrintToChat(client, "{LIGHTOLIVE}Вы взяли мешок с деньгами");
		
		
	}
	KillTimer(t_PlayerTake[client]);
	CloseHandle(pack);
}

func_SpawnMoneyPack(count)
{
	for(new t_i; t_i < count; t_i++)
	{
		new ent = CreateEntityByName("prop_physics_override");
		g_MoneyBags[t_i] = ent;
		decl String:targetname[64];

		FormatEx(targetname, sizeof(targetname), "money_%i", ent);

		DispatchKeyValue(ent, "model", "models/props/cs_militia/footlocker01_closed.mdl");
		DispatchKeyValue(ent, "physicsmode", "2");
		DispatchKeyValue(ent, "massScale", "1.0");
		DispatchKeyValue(ent, "targetname", targetname);
		DispatchKeyValue(ent, "spawnflags", "0");	
		DispatchSpawn(ent);
		
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
		
		float angles[3];
		angles[0] = GetRandomFloat(-360.0, 360.0);
		angles[1] = GetRandomFloat(-360.0, 360.0);
		angles[2] = GetRandomFloat(300.0, 360.0);
		TeleportEntity(ent, g_MoneyPoint, NULL_VECTOR, NULL_VECTOR);		
		TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, angles);
	}
}
