#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <csgo_colors>
#include <sdkhooks>

#define MONEYBAG_COUNT 5

#define MONEYBAG_MODEL "models/props/cs_militia/footlocker01_closed.mdl"
#define BACKPOINT_MODEL "models/props_vehicles/pickup_truck_2004.mdl"

new String:g_cfg_file[PLATFORM_MAX_PATH];
new String:g_cMap[34];
new Handle:h_kv_cfg;
new Float:g_MoneyPoint[3];
new Float:g_BackPoint[3];

new Handle:t_PlayerTake[MAXPLAYERS+1];
new g_MoneyBags[MONEYBAG_COUNT];

new bool:p_BugTake[MAXPLAYERS+1];
new bool:p_haveBug[MAXPLAYERS+1];
new p_OwnedBag[MAXPLAYERS+1];

new Handle:t_RoundEnd;

new g_BagCount;

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
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	
	RegAdminCmd("sm_bpos_reload", cmd_Reload, ADMFLAG_ROOT, "Reload cfgs");
	RegAdminCmd("sm_mpoint_set", cmd_SetMoneyPoint, ADMFLAG_ROOT, "Set money position");
	RegAdminCmd("sm_bpoint_set", cmd_SetBackPoint, ADMFLAG_ROOT, "Set backpoint position");
}

public OnMapStart()
{
	LoadCfg();
	PrecacheModel(MONEYBAG_MODEL, true);
	PrecacheModel(BACKPOINT_MODEL, true)
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

public RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) 
{
	KillTimer(t_RoundEnd);
	t_RoundEnd = INVALID_HANDLE;
}

public RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	func_SpawnBackPoint();
	func_SpawnMoneyPack(MONEYBAG_COUNT);
	g_BagCount = 0;
	t_RoundEnd = CreateTimer((GetConVarFloat(FindConVar("mp_roundtime")) * 60.0) - GetConVarFloat(FindConVar("mp_freezetime")) - 1.0, tm_OnTimerEndRound);
}

public Action:tm_OnTimerEndRound(Handle:timer)
{
	CS_TerminateRound(10.0, CSRoundEnd_CTWin);
	KillTimer(timer);
	t_RoundEnd = INVALID_HANDLE;
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	p_BugTake[client] = false;
	p_haveBug[client] = false;
	p_OwnedBag[client] = 0;
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && IsClientInGame(client))
	{
		AcceptEntityInput(p_OwnedBag[client], "TurnOff");
		
		SetEntProp(p_OwnedBag[client], Prop_Send, "m_usSolidFlags",  152);
		SetEntProp(p_OwnedBag[client], Prop_Send, "m_CollisionGroup", 8);
		
		p_OwnedBag[client] = 0;
		p_haveBug[client] = false;
		//new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	}
	
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

public Action:OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsClientInGame(client)) return;
	
	if(buttons & IN_USE)
	{
		if(IsPlayerAlive(client))
		{ 
			new Ent;
			new String:Classname[32];
		   
			Ent = GetClientAimTarget(client, false);
		   
			if (Ent != -1 && IsValidEntity(Ent) && p_BugTake[client] == false && p_haveBug[client] == false)
			{
				new Float:origin[3], Float:clientent[3];
			   
				GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", origin);
				GetClientAbsOrigin(client, clientent);
			   
				new Float:distance = GetVectorDistance(origin, clientent);
				if (distance < 60)
				{
					GetEdictClassname(Ent, Classname, sizeof(Classname));
				   
					decl String:modelname[128];
					GetEntPropString(Ent, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
				   
					if (StrEqual(modelname, MONEYBAG_MODEL))
					{
						p_BugTake[client] = true;
						SetEntityMoveType(client, MOVETYPE_NONE);
						SetEntityRenderColor(client, 255, 0, 0, 255);
						
						new Handle:datapack = INVALID_HANDLE;
						t_PlayerTake[client] = CreateDataTimer(3.0, tm_PlayerTake, datapack, TIMER_FLAG_NO_MAPCHANGE);
						WritePackCell(datapack, client);
						WritePackCell(datapack, Ent);
						ResetPack(datapack);
						SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime()); 
						SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 3);
						CGOPrintToChat(client, "{LIGHTOLIVE}Взятие ящика");
					}
				}
			}
		}
	}
	else if(p_BugTake[client] == true)
	{	
		func_UnTakeBag(client);
	}
} 

public func_UnTakeBag(client)
{
	p_BugTake[client] = false;
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime()); 
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	CGOPrintToChat(client, "{LIGHTOLIVE}Взятие отменено");
	if(t_PlayerTake[client]) KillTimer(t_PlayerTake[client]);
	t_PlayerTake[client] = INVALID_HANDLE;
}

public Action:tm_PlayerTake(Handle:timer, Handle:pack)
{
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
		
	/*	p_pos1[2] -= 20.0;	
		p_pos1[1] += 25.0;
		p_angle1[1] += 70.0;
		p_angle1[2] += 90.0;*/
		
		decl Float:p_bagOr[3];
		decl Float:p_bagAng[3];
		decl Float:p_bagForward[3];
		decl Float:p_bagRight[3];
		decl Float:p_bagUp[3];
		GetClientAbsOrigin(client,p_bagOr);
		GetClientAbsAngles(client,p_bagAng);
		
		p_bagAng[0] += 0.0;
		p_bagAng[1] += 70.0; 
		p_bagAng[2] -= 90.0;
		
		new Float:p_bagOffset[3];
		p_bagOffset[0] = 0.0;
		p_bagOffset[1] = 0.0;
		p_bagOffset[2] = 20.0;
		
		GetAngleVectors(p_bagAng, p_bagForward, p_bagRight, p_bagUp);
		
		p_bagOr[0] += p_bagRight[0]*p_bagOffset[0]+p_bagForward[0]*p_bagOffset[1]+p_bagUp[0]*p_bagOffset[2];
		p_bagOr[1] += p_bagRight[1]*p_bagOffset[0]+p_bagForward[1]*p_bagOffset[1]+p_bagUp[1]*p_bagOffset[2];
		p_bagOr[2] += p_bagRight[2]*p_bagOffset[0]+p_bagForward[2]*p_bagOffset[1]+p_bagUp[2]*p_bagOffset[2];
		
		AcceptEntityInput(ent, "TurnOn", ent, ent, 0);

		// Teleport the hat to the right position and attach it
		TeleportEntity(ent, p_bagOr, p_bagAng, NULL_VECTOR); 
			
		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", client, ent, 0);
		
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
		SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
		
		SetVariantString("facemask");
		AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
		
		CGOPrintToChat(client, "{LIGHTOLIVE}Вы взяли мешок с деньгами");
		p_haveBug[client] = true;
		p_OwnedBag[client] = ent;
		
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

		DispatchKeyValue(ent, "model", MONEYBAG_MODEL);
		DispatchKeyValue(ent, "physicsmode", "2");
		DispatchKeyValue(ent, "massScale", "100.0");
		DispatchKeyValue(ent, "targetname", targetname);
		DispatchKeyValue(ent, "spawnflags", "0");	
		DispatchSpawn(ent);
		
		SetEntProp(ent, Prop_Send, "m_usSolidFlags",  152);
		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 8);
		
		float angles[3];
		angles[0] = GetRandomFloat(-360.0, 360.0);
		angles[1] = GetRandomFloat(-360.0, 360.0);
		angles[2] = GetRandomFloat(300.0, 360.0);
		TeleportEntity(ent, g_MoneyPoint, NULL_VECTOR, NULL_VECTOR);		
		TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, angles);
	}
}

func_SpawnBackPoint()
{
	new ent = CreateEntityByName("prop_physics_override");
	decl String:targetname[64];

	FormatEx(targetname, sizeof(targetname), "back_%i", ent);

	DispatchKeyValue(ent, "model", BACKPOINT_MODEL);
	DispatchKeyValue(ent, "physicsmode", "2");
	DispatchKeyValue(ent, "massScale", "1000.0");
	DispatchKeyValue(ent, "targetname", targetname);
	DispatchKeyValue(ent, "spawnflags", "0");	
	DispatchSpawn(ent);
	
	SetEntProp(ent, Prop_Send, "m_usSolidFlags",  152);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 8);
	
	TeleportEntity(ent, g_BackPoint, NULL_VECTOR, NULL_VECTOR);	
	SDKHook(ent, SDKHook_StartTouch, ve_spawn_OnStartTouch);		
}

public ve_spawn_OnStartTouch(ent, client)
{
	if (client > 0 && client <= MAXPLAYERS)
	{
		if(p_haveBug[client] == true)
		{
			AcceptEntityInput(p_OwnedBag[client], "Kill");
			CGOPrintToChatAll("{LIGHTRED}%N {LIGHTOLIVE}доставил мешок с деньгами к точке сбора. {OLIVE}Осталось %d", client, MONEYBAG_COUNT-g_BagCount);
			p_BugTake[client] = false;
			p_haveBug[client] = false;
			p_OwnedBag[client] = 0;
			g_BagCount++;
			if(g_BagCount == MONEYBAG_COUNT) CS_TerminateRound(10.0, CSRoundEnd_TerroristWin);
		}
	}
}
