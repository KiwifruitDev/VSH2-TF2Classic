#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2c>
#include <vsh2>

public void RemoveWepFromSlot(const int client, const int wepslot) {
	TF2_RemoveWeaponSlot(client, wepslot);
}


public Plugin myinfo = {
	name        = "VSH2 Buff Civilian Subplugin",
	author      = "KiwifruitDev",
	description = "",
	version     = "1.0",
	url         = "https://github.com/VSH2-Devs/Vs-Saxton-Hale-2"
};

enum struct BuffCivilian {
	VSH2GameMode gm;
	ConfigMap    cfg;
	int          id;
	ConVar       scout_rage_gen;
	ConVar       airblast_rage;
	ConVar       jarate_rage;
	
	/// Boss custom cvars.
	ConVar       run_speed;
	ConVar       glow_iota;
	ConVar       charge_amnt;
	ConVar       max_jmp_charge;
	ConVar       jmp_reset;
	ConVar       wghdwn_time;
	ConVar       wghdwn_iota;
	ConVar       minion_uber_time;
	ConVar       minion_climb_vel;
	ConVar       minion_spawn;
	ConVar       rage_time;
}

BuffCivilian buff_civilian;


public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "VSH2") ) {
		buff_civilian.scout_rage_gen = FindConVar("vsh2_scout_rage_gen");
		buff_civilian.airblast_rage  = FindConVar("vsh2_airblast_rage");
		buff_civilian.jarate_rage    = FindConVar("vsh2_jarate_rage");
		buff_civilian.cfg            = new ConfigMap("configs/saxton_hale/boss_cfgs/buff_civilian.cfg");
		
		buff_civilian.run_speed = CreateConVar("vsh2_buffcivilian_speed", "340.0", "How fast, based on health, Buff Civilian can move.", FCVAR_NOTIFY, true, 1.0, true, 99999.0);
		buff_civilian.glow_iota = CreateConVar("vsh2_buffcivilian_glow_iota", "0.1", "How fast Buff Civilian's glow time decreases.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.charge_amnt = CreateConVar("vsh2_buffcivilian_jmp_charge", "2.5", "How much superjump charge should increase when holding jump buttons.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.max_jmp_charge = CreateConVar("vsh2_buffcivilian_max_jmp_charge", "25.0", "maximum charge that superjump can charge to.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.jmp_reset = CreateConVar("vsh2_buffcivilian_jmp_reset", "-100.0", "amount to reset the superjump charge after superjumping.", FCVAR_NOTIFY, false, _, true, 99999.0);
		buff_civilian.wghdwn_time = CreateConVar("vsh2_buffcivilian_weighdown_time", "3.0", "how much time the buff civilian has to be in the air for weighdown to work.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.wghdwn_iota = CreateConVar("vsh2_buffcivilian_weighdown_iota", "0.1", "How fast Buff Civilian's weighdown time decreases.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.minion_uber_time = CreateConVar("vsh2_buffcivilian_minion_uber_time", "3.0", "How long buff civilian minion spawn ubers last.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.minion_climb_vel = CreateConVar("vsh2_buffcivilian_minion_climb_vel", "400.0", "buff civilian minion upward climbing velocity (in hammer units).", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.rage_time = CreateConVar("vsh2_buffcivilian_rage_time", "10.0", "how long in seconds does the buff civilian rage boost (applies to minions as well) work for.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		buff_civilian.minion_spawn = CreateConVar("vsh2_buffcivilian_minion_spawn_time", "1.5", "amount, multiplied by the minion count, for minions to spawn.", FCVAR_NOTIFY, true, 0.0, true, 99999.0);
		
		/// If config is null, do not register boss.
		if( buff_civilian.cfg==null ) {
			LogError("[VSH 2] ERROR :: **** couldn't find 'configs/saxton_hale/boss_cfgs/buff_civilian.cfg'. Failed to register Buff Civilian boss module. ****");
			return;
		}
		char plugin_name_str[MAX_BOSS_NAME_SIZE];
		buff_civilian.cfg.Get("boss.plugin name", plugin_name_str, sizeof(plugin_name_str));
		buff_civilian.id = VSH2_RegisterPlugin(plugin_name_str);
		LoadVSH2Hooks();
	}
}


public void LoadVSH2Hooks()
{
	if( !VSH2_HookEx(OnCallDownloads, BuffCivilian_OnCallDownloads) )
		LogError("Error loading OnCallDownloads forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossMenu, BuffCivilian_OnBossMenu) )
		LogError("Error loading OnBossMenu forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossSelected, BuffCivilian_OnBossSelected) )
		LogError("Error loading OnBossSelected forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossThink, BuffCivilian_OnBossThink) )
		LogError("Error loading OnBossThink forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossModelTimer, BuffCivilian_OnBossModelTimer) )
		LogError("Error loading OnBossModelTimer forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossEquipped, BuffCivilian_OnBossEquipped) )
		LogError("Error loading OnBossEquipped forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossInitialized, BuffCivilian_OnBossInitialized) )
		LogError("Error loading OnBossInitialized forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnMinionInitialized, BuffCivilian_OnMinionInitialized) )
		LogError("Error loading OnMinionInitialized forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossPlayIntro, BuffCivilian_OnBossPlayIntro) )
		LogError("Error loading OnBossPlayIntro forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnPlayerKilled, BuffCivilian_OnPlayerKilled) )
		LogError("Error loading OnPlayerKilled forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnPlayerHurt, BuffCivilian_OnPlayerHurt) )
		LogError("Error loading OnPlayerHurt forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnPlayerAirblasted, BuffCivilian_OnPlayerAirblasted) )
		LogError("Error loading OnPlayerAirblasted forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossMedicCall, BuffCivilian_OnBossMedicCall) )
		LogError("Error loading OnBossMedicCall forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossTaunt, BuffCivilian_OnBossMedicCall) )
		LogError("Error loading OnBossTaunt forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnBossJarated, BuffCivilian_OnBossJarated) )
		LogError("Error loading OnBossJarated forwards for Buff Civilian subplugin.");
	
	if( !VSH2_HookEx(OnRoundEndInfo, BuffCivilian_OnRoundEndInfo) )
		LogError("Error loading OnRoundEndInfo forwards for Buff Civilian subplugin.");
}


stock bool IsBuffCivilian(const VSH2Player player) {
	return player.GetPropInt("iBossType") == buff_civilian.id;
}

public void BuffCivilian_OnCallDownloads() {
	{
		int boss_mdl_len = buff_civilian.cfg.GetSize("boss.model");
		char[] boss_mdl_str = new char[boss_mdl_len];
		if( buff_civilian.cfg.Get("boss.model", boss_mdl_str, boss_mdl_len) > 0 ) {
			PrepareModel(boss_mdl_str);
		}
		ConfigMap skins = buff_civilian.cfg.GetSection("boss.skins");
		PrepareAssetsFromCfgMap(skins, ResourceMaterial);
	}
	{
		int zomb_mdl_len = buff_civilian.cfg.GetSize("boss.minion model");
		char[] zomb_mdl_str = new char[zomb_mdl_len];
		if( buff_civilian.cfg.Get("boss.minion model", zomb_mdl_str, zomb_mdl_len) > 0 ) {
			PrepareModel(zomb_mdl_str);
		}
		ConfigMap skins = buff_civilian.cfg.GetSection("boss.minion skins");
		PrepareAssetsFromCfgMap(skins, ResourceMaterial);
	}
	{
		ConfigMap sounds_sect = buff_civilian.cfg.GetSection("boss.sounds");
		if( sounds_sect != null ) {
			PrepareAssetsFromCfgMap(sounds_sect.GetSection("intro"),     ResourceSound);
			PrepareAssetsFromCfgMap(sounds_sect.GetSection("rage"),      ResourceSound);
			PrepareAssetsFromCfgMap(sounds_sect.GetSection("superjump"), ResourceSound);
		}
	}
}

public void BuffCivilian_OnBossMenu(Menu &menu) {
	char tostr[10]; IntToString(buff_civilian.id, tostr, sizeof(tostr));
	menu.AddItem(tostr, "Buff Civilian (Custom Boss)");
}

public void BuffCivilian_OnBossSelected(const VSH2Player player) {
	if( !IsBuffCivilian(player) || IsVoteInProgress() ) {
		return;
	}
	
	int help_len = buff_civilian.cfg.GetSize("boss.help panel");
	char[] help_str = new char[help_len];
	buff_civilian.cfg.Get("boss.help panel", help_str, help_len);
	
	Panel panel = new Panel();
	panel.SetTitle(help_str);
	panel.DrawItem("Exit");
	panel.Send(player.index, HintPanel, 10);
	delete panel;
}

public void BuffCivilian_OnBossThink(const VSH2Player player)
{
	int client = player.index;
	if( !IsPlayerAlive(client) || !IsBuffCivilian(player) ) {
		return;
	}
	
	player.SpeedThink(buff_civilian.run_speed.FloatValue);
	player.GlowThink(buff_civilian.glow_iota.FloatValue);
	if( player.SuperJumpThink(buff_civilian.charge_amnt.FloatValue, buff_civilian.max_jmp_charge.FloatValue) ) {
		player.SuperJump(player.GetPropFloat("flCharge"), buff_civilian.jmp_reset.FloatValue);
		ConfigMap superjump_sect = buff_civilian.cfg.GetSection("boss.sounds.superjump");
		player.PlayRandVoiceClipCfgMap(superjump_sect, VSH2_VOICE_ABILITY);
	}
	
	if( OnlyScoutsLeft() ) {
		player.SetPropFloat("flRAGE", player.GetPropFloat("flRAGE") + buff_civilian.scout_rage_gen.FloatValue);
	}
	player.WeighDownThink(buff_civilian.wghdwn_time.FloatValue, buff_civilian.wghdwn_iota.FloatValue);
	
	/// hud code
	SetHudTextParams(-1.0, 0.77, 0.35, 255, 255, 255, 255);
	Handle hud = buff_civilian.gm.hHUD;
	float jmp = player.GetPropFloat("flCharge");
	float rage = player.GetPropFloat("flRAGE");
	if( rage >= 100.0 ) {
		ShowSyncHudText(client, hud, "Jump: %i%% | Rage: FULL - Call Medic (default: E) to activate", player.GetPropInt("bSuperCharge") ? 1000 : RoundFloat(jmp) * 4);
	} else {
		ShowSyncHudText(client, hud, "Jump: %i%% | Rage: %0.1f", player.GetPropInt("bSuperCharge") ? 1000 : RoundFloat(jmp) * 4, rage);
	}
}

public void BuffCivilian_OnBossModelTimer(const VSH2Player player) {
	if( !IsBuffCivilian(player) ) {
		return;
	}
	int client = player.index;
	int boss_mdl_len = buff_civilian.cfg.GetSize("boss.model");
	char[] boss_mdl = new char[boss_mdl_len];
	buff_civilian.cfg.Get("boss.model", boss_mdl, boss_mdl_len);
	SetVariantString(boss_mdl);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

public void BuffCivilian_OnBossEquipped(const VSH2Player player) {
	if( !IsBuffCivilian(player) ) {
		return;
	}
	char boss_name_str[MAX_BOSS_NAME_SIZE];
	buff_civilian.cfg.Get("boss.name", boss_name_str, sizeof(boss_name_str));
	player.SetName(boss_name_str);
	player.RemoveAllItems();
	
	int index;
	buff_civilian.cfg.GetInt("boss.melee", index);
	
	player.SpawnWeapon(index);
}

public void BuffCivilian_OnBossInitialized(const VSH2Player player) {
	if( !IsBuffCivilian(player) )
		return;
	
	SetEntProp(player.index, Prop_Send, "m_iClass", view_as< int >(TFClass_Civilian));
}

public void BuffCivilian_OnMinionInitialized(const VSH2Player player, const VSH2Player master) {
	if( !IsBuffCivilian(master) )
		return;
	
	int client = player.index;
	TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	player.RemoveAllItems();
	
	int index;
	buff_civilian.cfg.GetInt("boss.minion melee", index);
	player.SpawnWeapon(index);
	
	TF2_AddCondition(client, TFCond_Ubercharged, buff_civilian.minion_uber_time.FloatValue);
	SetEntityHealth(client, 200);
	
	int zomb_mdl_len = buff_civilian.cfg.GetSize("boss.minion model");
	char[] zomb_mdl = new char[zomb_mdl_len];
	buff_civilian.cfg.Get("boss.minion model", zomb_mdl, zomb_mdl_len);
	SetVariantString(zomb_mdl);
	
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	SetEntProp(client, Prop_Send, "m_nBody", 0);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 30, 160, 255, 255);
}

public void BuffCivilian_OnBossPlayIntro(const VSH2Player player) {
	if( !IsBuffCivilian(player) )
		return;
	
	ConfigMap intro_sect = buff_civilian.cfg.GetSection("boss.sounds.intro");
	player.PlayRandVoiceClipCfgMap(intro_sect, VSH2_VOICE_INTRO);
}

public void KilledPlayer(const VSH2Player attacker, const VSH2Player victim, Event event) {
	/// GLITCH: suiciding allows boss to become own minion.
	if( attacker.userid==victim.userid ) {
		return;
	} else if( event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER ) {
		/// PATCH: Hitting spy with active deadringer turns them into Minion...
		return;
	} else if( TF2_IsPlayerInCondition(victim.index, TFCond_Disguised) ) {
		/// PATCH: killing spy with teammate disguise kills both spy and the teammate he disguised as...
		TF2_RemovePlayerDisguise(victim.index); //event.SetInt("userid", victim.userid);
	}
	victim.hOwnerBoss = attacker;
	victim.ConvertToMinion(0.4);
}

public void BuffCivilian_OnPlayerKilled(const VSH2Player attacker, const VSH2Player victim, Event event)
{
	//int deathflags = event.GetInt("death_flags");
	/// attacker is buff civilian!
	if( attacker.bIsBoss && IsBuffCivilian(attacker) ) {
		KilledPlayer(attacker, victim, event);
	} else if( attacker.GetPropInt("bIsMinion") ) {
		/// attacker is a buff civilian minion!
		VSH2Player owner = attacker.hOwnerBoss;
		if( IsBuffCivilian(owner) ) {
			KilledPlayer(owner, victim, event);
		}
	}
	
	if( victim.GetPropInt("bIsMinion") ) {
		/// Cap respawning minions by the amount of minions there are * 1.5.
		/// If 10 minions, then respawn them in 15 seconds.
		VSH2Player owner = victim.hOwnerBoss;
		if( IsBuffCivilian(owner) && IsPlayerAlive(owner.index) ) {
			int minions = VSH2GameMode.CountMinions(false, owner);
			victim.ConvertToMinion(minions * buff_civilian.minion_spawn.FloatValue);
		}
	}
}

public void BuffCivilian_OnPlayerHurt(const VSH2Player attacker, const VSH2Player victim, Event event) {
	int damage = event.GetInt("damageamount");
	if( !victim.bIsBoss && victim.GetPropInt("bIsMinion") && !attacker.GetPropInt("bIsMinion") ) {
		/// Have boss take damage if minions are hurt by players,
		/// this prevents bosses from hiding just because they gained minions.
		VSH2Player ownerBoss = victim.hOwnerBoss;
		if( IsBuffCivilian(ownerBoss) ) {
			//ownerBoss.SetPropInt("iHealth", GetClientHealth(ownerBoss.index)-damage);
			SDKHooks_TakeDamage(ownerBoss.index, attacker.index, attacker.index, damage+0.0, DMG_DIRECT, 0);
			//ownerBoss.GiveRage(damage);
		}
		return;
	}
	
	if( IsBuffCivilian(victim) && victim.bIsBoss ) {
		victim.GiveRage(damage);
	}
}

public void BuffCivilian_OnPlayerAirblasted(const VSH2Player airblaster, const VSH2Player airblasted, Event event)
{
	if( !IsBuffCivilian(airblasted) )
		return;
	
	float rage = airblasted.GetPropFloat("flRAGE");
	airblasted.SetPropFloat("flRAGE", rage + buff_civilian.airblast_rage.FloatValue);
}

public void BuffCivilian_OnBossMedicCall(const VSH2Player rager) {
	if( !IsBuffCivilian(rager) )
		return;
	
	float rage = rager.GetPropFloat("flRAGE");
	if( rage < 100.0 )
		return;
	
	float rage_time = buff_civilian.rage_time.FloatValue;
	int attribute = 0;
	float value = 0.0;
	TF2_AddCondition(rager.index, TFCond_MegaHeal, rage_time);
	switch( GetRandomInt(0, 2) ) {
		case 0: { attribute = 2;   value = 2.0;   } /// Extra damage
		case 1: { attribute = 26;  value = 100.0; } /// Extra health
		case 2: { attribute = 107; value = 2.0;   } /// Extra speed
	}
	rager.SetPropFloat("flRAGE", 0.0);
	ConfigMap rage_sect = buff_civilian.cfg.GetSection("boss.sounds.rage");
	rager.PlayRandVoiceClipCfgMap(rage_sect, VSH2_VOICE_RAGE);
}

public void BuffCivilian_OnBossJarated(const VSH2Player victim, const VSH2Player thrower) {
	if( !IsBuffCivilian(victim) )
		return;
	
	float rage = victim.GetPropFloat("flRAGE");
	victim.SetPropFloat("flRAGE", rage - buff_civilian.jarate_rage.FloatValue);
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	VSH2Player player = VSH2Player(client);
	if( player.GetPropInt("bIsMinion") ) {
		if( IsBuffCivilian(player.hOwnerBoss) ) {
			player.ClimbWall(weapon, buff_civilian.minion_climb_vel.FloatValue, 0.0, false);
		}
		result = false;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void BuffCivilian_OnRoundEndInfo(const VSH2Player player, bool boss_won, char message[MAXMESSAGE])
{
	if( !IsBuffCivilian(player) ) {
		return;
	}
	
	if( boss_won ) {
		/// play Boss Wins sounds here!
	}
}


stock bool IsValidClient(const int client, bool nobots=false) {
	if( client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)) )
		return false;
	
	return IsClientInGame(client);
}

stock int GetSlotFromWeapon(const int iClient, const int iWeapon) {
	for( int i; i<5; i++ ) {
		if( iWeapon==GetPlayerWeaponSlot(iClient, i) ) {
			return i;
		}
	}
	return -1;
}

stock bool OnlyScoutsLeft() {
	VSH2Player[] players = new VSH2Player[MaxClients];
	int len = VSH2GameMode.GetFighters(players);
	for( int i; i<len; i++ ) {
		if( players[i].iTFClass != TFClass_Scout ) {
			return false;
		}
	}
	return true;
}

stock void SetPawnTimer(Function func, float thinktime = 0.1, any param1 = -999, any param2 = -999) {
	DataPack thinkpack = new DataPack();
	thinkpack.WriteFunction(func);
	thinkpack.WriteCell(param1);
	thinkpack.WriteCell(param2);
	CreateTimer(thinktime, DoThink, thinkpack, TIMER_DATA_HNDL_CLOSE);
}

public Action DoThink(Handle hTimer, DataPack hndl) {
	hndl.Reset();
	
	Function pFunc = hndl.ReadFunction();
	Call_StartFunction( null, pFunc );
	
	any param1 = hndl.ReadCell();
	if( param1 != -999 )
		Call_PushCell(param1);
	
	any param2 = hndl.ReadCell();
	if( param2 != -999 )
		Call_PushCell(param2);
	
	Call_Finish();
	return Plugin_Continue;
}

public int HintPanel(Menu menu, MenuAction action, int param1, int param2) {
	return;
}