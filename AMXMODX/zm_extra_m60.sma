#include <amxconst>
#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <xs> 
#include <zombieplague>

//Male Version Zombie M60 Machine Gun

#define CSW_M60 CSW_M249
#define weapon_m60 "weapon_m249"

#define DAMAGE 75
#define CLIP 100
#define BPAMMO 200
#define SPEED 1.00
#define RECOIL 0.8
#define RELOAD_TIME 4.75

#define BODY_NUM 0
#define SHOOT_ANIM random_num(1, 2)
#define RELOAD_ANIM 3
#define DRAW_ANIM 4

#define UP_SCALE -5.5
#define FORWARD_SCALE 8.0
#define RIGHT_SCALE 5.5
#define LEFT_SCALE -5.5
#define TE_BOUNCE_SHELL	1

#define write_coord_f(%1) engfunc(EngFunc_WriteCoord,%1)

#define WEAPON_SECRETCODE 210797

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_ShellId, g_HamBot, g_weapon_event
new Float:g_Recoil[33][3], g_Clip[33]

// Item ID
new g_M60, g_had_m60, g_is_alive

//M60 models
new const P_MODEL[] = "models/zombie_plague/p_m60.mdl"
new const V_MODEL[] = "models/zombie_plague/v_m60.mdl"
new const W_MODEL[] = "models/zombie_plague/w_m60.mdl"
new const DEFAULT_W_MODEL [] = "models/w_m249.mdl"

//M60 sounds
new const FIRE_SOUND[] = "zombie_plague/m60-1.wav"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_sound(FIRE_SOUND)
	g_ShellId = precache_model("models/rshell.mdl")
}

public plugin_init()
{
	register_plugin("M60 Machine Gun", "1.0", "IDF GALIL DEFENDER")
	g_M60 = zp_register_extra_item("M60 Machine Gun", 150, ZP_TEAM_HUMAN)

	//Forwards
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	//Hams
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_m60, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_m60, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_m60, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_m60, "fw_Weapon_Reload")
	RegisterHam(Ham_Item_Deploy, weapon_m60, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_m60, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_m60, "fw_Item_PostFrame")	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	//Events
	register_event("TextMsg", "fw_Game_Will_Restart_In", "a", "2=#Game_will_restart_in")

	//Client Commands
	register_clcmd("weapon_m60", "Hook_Weapon")
	
	//Messages
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
}

public Hook_Weapon(player)
{
	engclient_cmd(player, weapon_m60)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m249.sc", name))
	{
		g_weapon_event = get_orig_retval()
	}
}

public client_putinserver(player)
{
	if(!g_HamBot && is_user_bot(player))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", player)
	}
}

public Register_HamBot(player) 
{
	RegisterHamFromEntity(Ham_TraceAttack, player, "fw_TraceAttack_Player")
	Register_SafetyFuncBot(player)
}

public Register_SafetyFuncBot(player)
{
	RegisterHamFromEntity(Ham_Spawn, player, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, player, "fw_PlayerKilled", 1)
}

public fw_Safety_Spawn_Post(player)
{
	if(!is_user_alive(player))
	{
		return
	}
	Set_BitVar(g_had_m60, player)
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_M60)
	{
		if (Get_BitVar(g_had_m60, player))
		{
			//Warning!
			client_print(player, print_center, "You already have the M60 machine gun!")
			return ZP_PLUGIN_HANDLED
		}
		else
		{
			//Drop any primary weapon the player has
			drop_weapons(player, 1)
			
			//Give M60 to player
			Set_BitVar(g_had_m60, player)
			fm_give_item(player, weapon_m60)
				
			//Set Ammo
			static Ent; Ent = fm_get_user_weapon_entity(player, CSW_M60)
			if(pev_valid(Ent))
			{
				cs_set_weapon_ammo(Ent, CLIP)
			}
			engfunc(EngFunc_MessageBegin, MSG_ONE, get_user_msgid("CurWeapon"), {0, 0, 0}, player) 
			write_byte(1)
			write_byte(CSW_M60)
			write_byte(CLIP)
			message_end()
			cs_set_user_bpammo(player, CSW_M60, BPAMMO)
		}
	}
	return PLUGIN_CONTINUE
}

public Remove_M60(player)
{
	UnSet_BitVar(g_had_m60, player)
}

//Drop primary weapons
stock drop_weapons(player, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(player, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(player, "drop", wname)
		}
	}
}

public fw_UpdateClientData_Post(player, sendweapons, cd_handle)
{
	if(!is_user_alive(player))
	{
		return FMRES_IGNORED	
	}
	if(get_user_weapon(player) == CSW_M60 && Get_BitVar(g_had_m60, player))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	}
	
	return FMRES_HANDLED
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
	{
		return FMRES_IGNORED
	}
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, DEFAULT_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_m60, entity)
		
		if(!pev_valid(weapon))
		{
			return FMRES_IGNORED
		}
		
		if(Get_BitVar(g_had_m60, iOwner))
		{
			Remove_M60(iOwner)
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			set_pev(entity, pev_body, BODY_NUM)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
	{
		return FMRES_IGNORED
	}
	
	if(get_user_weapon(invoker) != CSW_M60 || !Get_BitVar(g_had_m60, invoker))
	{
		return FMRES_IGNORED
	}
	
	if(eventid != g_weapon_event)
	{
		return FMRES_IGNORED
	}
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	set_weapon_anim(invoker, SHOOT_ANIM)
	emit_sound(invoker, CHAN_WEAPON, FIRE_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	return FMRES_SUPERCEDE
}

public fw_CmdStart(player, uc_handle, seed)
{
	if(!is_user_alive(player))
	{
		return FMRES_IGNORED
	}
	
	if(!Get_BitVar(g_had_m60, player) || get_user_weapon(player) != CSW_M60)
	{
		return FMRES_IGNORED
	}
	
	
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	
	if(!(NewButton & IN_ATTACK))
	{
		if((pev(player, pev_oldbuttons) & IN_ATTACK) && pev(player, pev_weaponanim) == SHOOT_ANIM)
		{
			static weapon; weapon = fm_get_user_weapon_entity(player, CSW_M60)
			if(pev_valid(weapon)) 
			{
				set_pdata_float(weapon, 48, 2.0, 4)
			}
		}
	}
	return FMRES_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
	{
		return HAM_IGNORED
	}
	
	if(get_user_weapon(Attacker) != CSW_M60 || !Get_BitVar(g_had_m60, Attacker))
	{
		return HAM_IGNORED
	}
		
	SetHamParamFloat(3, float(DAMAGE))

	return HAM_IGNORED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
	{
		return HAM_IGNORED	
	}
	
	if(get_user_weapon(Attacker) != CSW_M60 || !Get_BitVar(g_had_m60, Attacker))
	{
		return HAM_IGNORED
	}
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
		
	Make_BulletHole(Attacker, flEnd, Damage)

	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static player; player = pev(Ent, pev_owner)
	pev(player, pev_punchangle, g_Recoil[player])
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static player; player = pev(Ent, pev_owner)
	new clip2,ammo2
	get_user_ammo(player,CSW_M60,clip2,ammo2)
	if(Get_BitVar(g_had_m60, player))
	{
		static Float:Push[3]
		pev(player, pev_punchangle, Push)
		xs_vec_sub(Push, g_Recoil[player], Push)
		
		xs_vec_mul_scalar(Push, RECOIL, Push)
		xs_vec_add(Push, g_Recoil[player], Push)
		set_pev(player, pev_punchangle, Push)

		static Float:vVel[3], Float:vAngle[3], Float:vOrigin[3], Float:vViewOfs[3], 
		i, Float:vShellOrigin[3], Float:vShellVelocity[3], Float:vRight[3],
		Float:vUp[3], Float:vForward[3]
		pev(player, pev_velocity, vVel)
		pev(player, pev_view_ofs, vViewOfs)
		pev(player, pev_angles, vAngle)
		pev(player, pev_origin, vOrigin)
		global_get(glb_v_right, vRight)
		global_get(glb_v_up, vUp)
		global_get(glb_v_forward, vForward)
		
		//Check if player use left or right hand
		if(get_cvar_num("cl_righthand") == 1)
		{
			for(i = 0; i<3; i++)
			{
				vShellOrigin[i] = vOrigin[i] + vViewOfs[i] + vUp[i] * UP_SCALE + vForward[i] * FORWARD_SCALE + vRight[i] * RIGHT_SCALE
				vShellVelocity[i] = vVel[i] + vRight[i] * random_float(-50.0, -70.0) + vUp[i] * random_float(100.0, 150.0) + vForward[i] * 25.0
			}
		}
		else
		{
			for(i = 0; i<3; i++)
			{
				vShellOrigin[i] = vOrigin[i] + vViewOfs[i] + vUp[i] * UP_SCALE + vForward[i] * FORWARD_SCALE + vRight[i] * LEFT_SCALE
				vShellVelocity[i] = vVel[i] + vRight[i] * random_float(-50.0, -70.0) + vUp[i] * random_float(100.0, 150.0) + vForward[i] * 25.0
			}
		}

		//check if m60 has ammo in its box, if not it will stop ejecting shells
		if(clip2 == 0)
		{
			return;	
		}
		else
		{
			CBaseWeapon__EjectBrass(vShellOrigin, vShellVelocity, -vAngle[1], g_ShellId, TE_BOUNCE_SHELL)
		}
	}
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
	{
		return
	}

	static player; player = get_pdata_cbase(Ent, 41, 4)

	if(get_pdata_cbase(player, 373) != Ent)
	{
		return
	}

	if(!Get_BitVar(g_had_m60, player))
	{
		return
	}
	
	set_pev(player, pev_viewmodel2, V_MODEL)
	set_pev(player, pev_weaponmodel2, P_MODEL)
	
	set_weapon_anim(player, DRAW_ANIM)
}

public fw_Item_AddToPlayer_Post(ent, player)
{
	if(!pev_valid(ent))
	{
		return HAM_IGNORED
	}
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_had_m60, player)
		set_pev(ent, pev_impulse, 0)
	}		
	
	if(Get_BitVar(g_had_m60, player))
	{
		message_begin(MSG_ONE, get_user_msgid("WeaponList"), {0, 0, 0}, player)
		write_string("weapon_m60")
		write_byte(3)
		write_byte(BPAMMO)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_M60)
		write_byte(0)
		message_end()
	}		
	else
	{
		message_begin(MSG_ONE, get_user_msgid("WeaponList"), {0, 0, 0}, player)
		write_string("weapon_m249")
		write_byte(3)
		write_byte(200)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_M249)
		write_byte(0)
		message_end()
	}		
	return HAM_IGNORED	
}

public fw_Item_PostFrame(ent)
{
	if(!pev_valid(ent))
	{
		return HAM_IGNORED
	}
	
	static player
	player = pev(ent, pev_owner)
	
	if(is_user_alive(player) && Get_BitVar(g_had_m60, player))
	{	
		static Float:flNextAttack; flNextAttack = get_pdata_float(player, 83, 5)
		static bpammo; bpammo = cs_get_user_bpammo(player, CSW_M60)
		static iClip; iClip = get_pdata_int(ent, 51, 4)
		static fInReload; fInReload = get_pdata_int(ent, 54, 4)
		
		if(fInReload && flNextAttack <= 0.0)
		{
			static temp1; temp1 = min(CLIP - iClip, bpammo)

			set_pdata_int(ent, 51, iClip + temp1, 4)
			//cs_set_user_bpammo(player, CSW_M60, bpammo - temp1)		
			cs_set_user_bpammo(player, CSW_M60, BPAMMO)
			set_pdata_int(ent, 54, 0, 4)
		
			fInReload = 0
		}		
	}
	
	return HAM_IGNORED	
}

public fw_Weapon_Reload(ent)
{
	static player; player = pev(ent, pev_owner)
	if(!is_user_alive(player))
	{
		return HAM_IGNORED
	}
	if(!Get_BitVar(g_had_m60, player))
	{
		return HAM_IGNORED
	}
	
	g_Clip[player] = -1
	
	static bpammo; bpammo = cs_get_user_bpammo(player, CSW_M60)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	
	if(bpammo <= 0) return HAM_SUPERCEDE
	
	if(iClip >= CLIP) return HAM_SUPERCEDE		
		
	g_Clip[player] = iClip

	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static player; player = pev(ent, pev_owner)
	
	if(!is_user_alive(player))
	{
		return HAM_IGNORED
	}
	
	if(!Get_BitVar(g_had_m60, player))
	{
		return HAM_IGNORED
	}

	if (g_Clip[player] == -1)
	{
		return HAM_IGNORED
	}
	
	set_pdata_int(ent, 51, g_Clip[player], 4)
	set_pdata_int(ent, 54, 1, 4)
	
	set_weapon_anim(player, RELOAD_ANIM)
	set_pdata_float(player, 83, RELOAD_TIME, 5)

	return HAM_HANDLED
}

stock Make_BulletHole(player, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(player)
		write_byte(Decal)
		message_end()
	}
}

stock get_weapon_attachment(player, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(player, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(player, pev_origin, fOrigin) 
	pev(player, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	static Float:EntVelocity[3]
	
	pev(ent, pev_velocity, EntVelocity)
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	static Float:fl_Time2; fl_Time2 = distance_f / (speed * multi)
	
	if(type == 1)
	{
		fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time		
	} 
	else if(type == 2)
	{
		fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
	}

	xs_vec_add(EntVelocity, fl_Velocity, fl_Velocity)
	set_pev(ent, pev_velocity, fl_Velocity)
}

stock set_weapon_anim(player, anim)
{
	if(!is_user_alive(player))
	{
		return
	}
	
	set_pev(player, pev_weaponanim, anim)
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, {0, 0, 0}, player)
	write_byte(anim)
	write_byte(pev(player, pev_body))
	message_end()
}

public fw_Game_Will_Restart_In()
{ 
	static iPlayers[32], iPlayersNum, i
	get_players(iPlayers, iPlayersNum, "a") 

	for (i = 0; i <= iPlayersNum; ++i) 
	{
		UnSet_BitVar(g_had_m60, i)
	}
}

// Player killed
public fw_PlayerKilled(victim, attacker, shouldgib)
{
	UnSet_BitVar(g_is_alive, victim)
}

//Death Message for the console and kill hud for the upper right corner
public message_DeathMsg(msg_id, msg_dest, player)
{
	static TruncatedWeapon[33], Attacker, Victim
	
	get_msg_arg_string(4, TruncatedWeapon, charsmax(TruncatedWeapon))
	
	Attacker = get_msg_arg_int(1)
	Victim = get_msg_arg_int(2)
	
	if(!is_user_connected(Attacker) || Attacker == Victim)
	{
		return PLUGIN_CONTINUE
	}
	if(equal(TruncatedWeapon, "m249") && get_user_weapon(Attacker) == CSW_M60)
	{
		if(Get_BitVar(g_had_m60, Attacker))
		{
			set_msg_arg_string(4, "m60")
		}
	}
	return PLUGIN_CONTINUE
}

//Ejecting shells when firing
CBaseWeapon__EjectBrass(Float:vecOrigin[3], Float:vecVelocity[3], Float:rotation, model, soundtype)
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0)
	write_byte(TE_MODEL)
	engfunc(EngFunc_WriteCoord, vecOrigin[0])
	engfunc(EngFunc_WriteCoord, vecOrigin[1])
	engfunc(EngFunc_WriteCoord, vecOrigin[2])
	engfunc(EngFunc_WriteCoord, vecVelocity[0])
	engfunc(EngFunc_WriteCoord, vecVelocity[1])
	engfunc(EngFunc_WriteCoord, vecVelocity[2])
	engfunc(EngFunc_WriteAngle, rotation)
	write_short(model)
	write_byte(soundtype)
	write_byte(25) // 2.5 seconds
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
