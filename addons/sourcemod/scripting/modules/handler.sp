/**
 * ALL NON-BOSS AND NON-MINION RELATED CODE IS AT THE BOTTOM. HAVE FUN CODING!
 */

#define MAXBOSS    (MaxDefaultVSH2Bosses + (g_modsys.m_hBossesRegistered.Length - 1))

#include "modules/bosses.sp"

/**
	PLEASE REMEMBER THAT PLAYERS THAT DON'T HAVE THEIR BOSS ID'S SET ARE NOT ACTUAL BOSSES.
	THIS PLUGIN HAS BEEN SETUP SO THAT IF YOU BECOME A BOSS, YOU MUST HAVE A VALID BOSS ID.

	FOR MANAGEMENT FUNCTIONS, DO NOT HAVE THEM DISCRIMINATE WHO IS A BOSS OR NOT, SIMPLY CHECK 'iBossType' TO SEE IF IT REALLY WAS A BOSS PLAYER.
*/


public void ManageDownloads()
{
	Action act = Call_OnCallDownloads();    /// in forwards.sp
	if( act==Plugin_Stop )
		return;

	static char download_keys[][] = {
		"downloads.sounds",
		"downloads.models",
		"downloads.materials"
	};

	for( int i; i<sizeof(download_keys); i++ ) {
		ConfigMap download_map = g_vsh2.m_hCfg.GetSection(download_keys[i]);
		PrepareAssetsFromCfgMap(download_map, i);
	}

	char basic_sounds[][] = {
		"ui/item_store_add_to_cart.wav",
		"player/doubledonk.wav",
		"vo/announcer_am_capincite01.wav",
		"vo/announcer_am_capincite03.wav",
		"vo/announcer_am_capenabled02.wav",
		"vo/announcer_ends_60sec.wav",
		"vo/announcer_ends_30sec.wav",
		"vo/announcer_ends_10sec.wav",
		"vo/announcer_ends_1sec.wav",
		"vo/announcer_ends_2sec.wav",
		"vo/announcer_ends_3sec.wav",
		"vo/announcer_ends_4sec.wav",
		"vo/announcer_ends_5sec.wav",
		"items/pumpkin_pickup.wav"
	};
	PrecacheSoundList(basic_sounds, sizeof(basic_sounds));
	//PrepareSound("saxton_hale/9000.wav");

	AddHaleToDownloads   ();
	AddVagToDownloads    ();
	AddCBSToDownloads    ();
	AddHHHToDownloads    ();
	AddBunnyToDownloads  ();
}

public void ManageMenu(Menu& menu, const int client)
{
	AddHaleToMenu(menu);
	AddVagToMenu(menu);
	AddCBSToMenu(menu);
	AddHHHToMenu(menu);
	AddBunnyToMenu(menu);
	Call_OnBossMenu(menu, BaseBoss(client));
}

public void ManageDisconnect(const int client)
{
	BaseBoss leaver = BaseBoss(client);
	if( leaver.index && leaver.bIsBoss ) {
		if( g_vshgm.iRoundState >= StateRunning ) {
			/// Arena mode flips out when no one is on the other team
			BaseBoss[] bosses = new BaseBoss[MaxClients];
			int numbosses = VSHGameMode.GetBosses(bosses, false);
			if( numbosses-1 > 0 ) { /// Exclude leaver, this is why CountBosses() can't be used
				for( int i=0; i<numbosses; i++ ) {
					if( bosses[i]==leaver || (IsClientValid(bosses[i].index) && IsPlayerAlive(bosses[i].index)) ) {
						continue;
					}
					BaseBoss next = VSHGameMode.FindNextBoss();
					if( g_vshgm.hNextBoss ) {
						next = g_vshgm.hNextBoss;
						g_vshgm.hNextBoss = view_as< BaseBoss >(0);
					}
					if( IsValidClient(next.index) ) {
						next.bIsMinion = true; /// Dumb hack, prevents spawn hook from forcing them back to red
						next.ForceTeamChange(VSH2Team_Boss);
					}

					if( g_vshgm.iRoundState==StateRunning ) {
						ForceTeamWin(VSH2Team_Red);
					}
					break;
				}
			} else { /// No bosses left
				BaseBoss next = VSHGameMode.FindNextBoss();
				if( g_vshgm.hNextBoss ) {
					next = g_vshgm.hNextBoss;
					g_vshgm.hNextBoss = view_as< BaseBoss >(0);
				}
				if( IsValidClient(next.index) ) {
					next.bIsMinion = true;
					next.ForceTeamChange(VSH2Team_Boss);
				}
				if( g_vshgm.iRoundState==StateRunning ) {
					ForceTeamWin(VSH2Team_Red);
				}
			}
		} else if( g_vshgm.iRoundState==StateStarting ) {
			BaseBoss replace = VSHGameMode.FindNextBoss();
			if( g_vshgm.hNextBoss ) {
				replace = g_vshgm.hNextBoss;
				g_vshgm.hNextBoss = view_as< BaseBoss >(0);
			}
			if( IsValidClient(replace.index) ) {
				replace.MakeBossAndSwitch(replace.iPresetType == -1 ? leaver.iBossType : replace.iPresetType, true);
				int len = g_vsh2.m_hCfg.GetSize("messages.boss replacer");
				char[] boss_replacer = new char[len];
				if( g_vsh2.m_hCfg.Get("messages.boss replacer", boss_replacer, len) ) {
					CPrintToChat(replace.index, "{olive}[VSH 2]{green} %s", boss_replacer);
				} else {
					CPrintToChat(replace.index, "{olive}[VSH 2]{green} Surprise! You're on NOW!");
				}
			}
		}
		int len = g_vsh2.m_hCfg.GetSize("messages.quitter");
		char[] quitter = new char[len];
		if( g_vsh2.m_hCfg.Get("messages.quitter", quitter, len) ) {
			CPrintToChatAll("{olive}[VSH 2]{red} %s", quitter);
		} else {
			CPrintToChatAll("{olive}[VSH 2]{red} A Boss Just Disconnected!");
		}
	} else {
		RequestFrame(CheckAlivePlayers, 0);
		if( client == VSHGameMode.FindNextBoss().index )
			SetPawnTimer(_SkipBossPanel, 1.0);

		if( leaver.userid == g_vshgm.hNextBoss.userid )
			g_vshgm.hNextBoss = view_as< BaseBoss >(0);
	}
}

public void ManageOnBossSelected(const BaseBoss base)
{
	SetPawnTimer(_SkipBossPanel, 4.0);
	Action act = Call_OnBossSelected(base);
	if( act > Plugin_Changed )
		return;

	ManageBossHelp(base);

	/// random multibosses code.
	int playing = GetLivingPlayers(VSH2Team_Red);
	int max_random_bosses = g_vsh2.m_hCvars.MaxRandomMultiBosses.IntValue;
	if( !g_vsh2.m_hCvars.AllowRandomMultiBosses.BoolValue || playing < 10 || GetRandomInt(0, 3) > 0 || VSHGameMode.CountBosses(false) >= max_random_bosses ) {
		return;
	}

	int extra_bosses = GetRandomInt(1, playing / 12);
	if( extra_bosses > max_random_bosses ) {
		extra_bosses = max_random_bosses;
	}
	for( int i; i<extra_bosses; i++ ) {
		BaseBoss partner = VSHGameMode.FindNextBoss();
		int preset_boss_type = partner.iPresetType;
		if( preset_boss_type == -1 ) {
			preset_boss_type = GetRandomInt(VSH2Boss_Hale, MAXBOSS);
		}
		partner.MakeBossAndSwitch(preset_boss_type, false);
	}
}

public Action ManageOnTouchPlayer(const BaseBoss base, const BaseBoss victim)
{
	return Call_OnTouchPlayer(base, victim);
}

public Action ManageOnTouchBuilding(const BaseBoss base, const int building)
{
	return Call_OnTouchBuilding(base, EntIndexToEntRef(building));
}

public void ManageBossHelp(const BaseBoss base)
{
	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).Help();
		case VSH2Boss_Vagineer: ToCVagineer(base).Help();
		case VSH2Boss_CBS:      ToCChristian(base).Help();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).Help();
		case VSH2Boss_Bunny:    ToCBunny(base).Help();
	}
}

public void ManageBossThink(const BaseBoss base)
{
	/** Adding this so bosses can take minicrits if airborne */
	TF2_AddCondition(base.index, TFCond_GrapplingHookSafeFall, 0.2);

	Action act = Call_OnBossThink(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).Think();
		case VSH2Boss_Vagineer: ToCVagineer(base).Think();
		case VSH2Boss_CBS:      ToCChristian(base).Think();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).Think();
		case VSH2Boss_Bunny:    ToCBunny(base).Think();
	}

	Call_OnBossThinkPost(base);
}

public void ManageBossModels(const BaseBoss base)
{
	Action act = Call_OnBossModelTimer(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).SetModel();
		case VSH2Boss_Vagineer: ToCVagineer(base).SetModel();
		case VSH2Boss_CBS:      ToCChristian(base).SetModel();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).SetModel();
		case VSH2Boss_Bunny:    ToCBunny(base).SetModel();
	}
}

public void ManageBossDeath(const BaseBoss base)
{
	Action act = Call_OnBossDeath(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).Death();
		case VSH2Boss_Vagineer: ToCVagineer(base).Death();
		case VSH2Boss_CBS:      ToCChristian(base).Death();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).Death();
		case VSH2Boss_Bunny:    ToCBunny(base).Death();
	}
}

public void ManageBossEquipment(const BaseBoss base)
{
	Action act = Call_OnBossEquipped(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).Equip();
		case VSH2Boss_Vagineer: ToCVagineer(base).Equip();
		case VSH2Boss_CBS:      ToCChristian(base).Equip();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).Equip();
		case VSH2Boss_Bunny:    ToCBunny(base).Equip();
	}
	Call_OnBossEquippedPost(base);
}

/** whatever stuff needs initializing should be done here */
public void ManageBossTransition(const BaseBoss base)
{
	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:
			TF2_SetPlayerClass(base.index, TFClass_Soldier, _, false);
		case VSH2Boss_Vagineer:
			TF2_SetPlayerClass(base.index, TFClass_Engineer, _, false);
		case VSH2Boss_CBS:
			TF2_SetPlayerClass(base.index, TFClass_Sniper, _, false);
		case VSH2Boss_HHHjr, VSH2Boss_Bunny:
			TF2_SetPlayerClass(base.index, TFClass_DemoMan, _, false);
	}
	ManageBossModels(base);
	/// Patch: Aug 18, 2018 - patching bad first person animations on custom boss models.
	Call_OnBossInitialized(base);
	ManageBossEquipment(base);
}

public void ManageMinionTransition(const BaseBoss base)
{
	if( !base.bIsMinion )
		return;

	base.ForceTeamChange(VSH2Team_Boss); /// Force our guy to the dark side lmao
	base.RemoveAllItems(false);

	BaseBoss master = BaseBoss(base.iOwnerBoss, true);
	Call_OnMinionInitialized(base, master);
}

public void ManagePlayBossIntro(const BaseBoss base)
{
	Action act = Call_OnBossPlayIntro(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).PlaySpawnClip();
		case VSH2Boss_Vagineer: ToCVagineer(base).PlaySpawnClip();
		case VSH2Boss_CBS:      ToCChristian(base).PlaySpawnClip();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).PlaySpawnClip();
		case VSH2Boss_Bunny:    ToCBunny(base).PlaySpawnClip();
	}
}

public Action ManageOnBossTakeDamage(const BaseBoss victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	switch( victim.iBossType ) {
		case -1: {}
		default: {
			int bFallDamage = (damagetype & DMG_FALL);
			char trigger[32];
			if( attacker > MaxClients && GetEdictClassname(attacker, trigger, sizeof(trigger)) && !strcmp(trigger, "trigger_hurt", false) ) {
				Action act = Call_OnBossTakeDamage_OnTriggerHurt(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
				if( act > Plugin_Changed ) {
					return Plugin_Continue;
				}

				if( g_vshgm.bTeleToSpawn || damage >= victim.iHealth ) {
					victim.TeleToSpawn(VSH2Team_Boss);
				} else if( damage >= g_vsh2.m_hCvars.TriggerHurtThreshold.FloatValue ) {
					if( victim.iBossType==VSH2Boss_HHHjr ) {
						victim.flCharge = HALEHHH_TELEPORTCHARGE;
					} else {
						victim.bSuperCharge = true;
					}
				}

				if( damage > g_vsh2.m_hCvars.MaxTriggerHurtDmg.FloatValue ) {
					if( act != Plugin_Changed ) {
						damage = g_vsh2.m_hCvars.MaxTriggerHurtDmg.FloatValue;
					}
					return Plugin_Changed;
				}
			} else if( attacker <= 0 && bFallDamage ) {
				if( Call_OnBossTakeFallDamage(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					damage = (victim.iHealth > 100) ? 1.0 : 30.0;
				}
				return Plugin_Changed;
			}

			if( attacker <= 0 || attacker > MaxClients ) {
				return Plugin_Continue;
			}

			BaseBoss hitter = BaseBoss(attacker);
			victim.iHits++;
			victim.flLastHit = GetGameTime();
			char classname[64], inflictor_name[32];
			if( IsValidEntity(inflictor) ) {
				GetEntityClassname(inflictor, inflictor_name, sizeof(inflictor_name));
			}
			if( IsValidEntity(weapon) ) {
				GetEdictClassname(weapon, classname, sizeof(classname));
			}

			/// Bosses shouldn't die from a single backstab
			if( damagecustom == TF_CUSTOM_BACKSTAB || (!strcmp(classname, "tf_weapon_knife", false) && damage > victim.iHealth) ) {
				float changedamage = ( (Pow(float(victim.iMaxHealth)*0.0014, 2.0) + 899.0) - (float(victim.iMaxHealth)*(float(victim.iStabbed)/100)) );
				if( victim.iStabbed < 4 ) {
					victim.iStabbed++;
				}
				/// You can level "damage dealt" with backstabs
				damage = changedamage / 3;
				damagetype |= DMG_CRIT;
				EmitSoundToAll("player/spy_shield_break.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
				EmitSoundToAll("player/crit_received3.wav", victim.index, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);

				float curtime = GetGameTime();
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", curtime+2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", curtime+2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", curtime+2.0);

				char boss_name[MAX_BOSS_NAME_SIZE]; victim.GetName(boss_name);
				{
					int len = g_vsh2.m_hCfg.GetSize("messages.stabber");
					char[] stabber = new char[len];
					if( g_vsh2.m_hCfg.Get("messages.stabber", stabber, len) ) {
						PrintCenterText(attacker, stabber, boss_name);
					} else {
						PrintCenterText(attacker, "You Tickled %s!", boss_name);
					}
				}
				{
					int len = g_vsh2.m_hCfg.GetSize("messages.stabbed");
					char[] stabbed = new char[len];
					if( g_vsh2.m_hCfg.Get("messages.stabbed", stabbed, len) ) {
						PrintCenterText(victim.index, "%s", stabbed);
					} else {
						PrintCenterText(victim.index, "You Were Just Tickled!");
					}
				}

				if( Call_OnBossTakeDamage_OnStabbed(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					switch( victim.iBossType ) {
						case VSH2Boss_Hale:     ToCHale(victim).Stabbed();
						case VSH2Boss_Vagineer: ToCVagineer(victim).Stabbed();
						case VSH2Boss_HHHjr:    ToCHHHJr(victim).Stabbed();
						case VSH2Boss_Bunny:    ToCBunny(victim).Stabbed();
					}
					return Plugin_Changed;
				}
				return Plugin_Changed;
			}

			if( damagecustom==TF_CUSTOM_BOOTS_STOMP ) {
				if( Call_OnBossTakeDamage_OnMantreadsStomp(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					int flag = g_vsh2.m_hCvars.BootStompLogic.IntValue;
					float boot_dmg = g_vsh2.m_hCvars.BootStompDamage.FloatValue;
					switch( flag ) {
						case 0: damage =  boot_dmg;
						case 1: damage *= boot_dmg;
						case 2: damage += boot_dmg;
					}
				}
				return Plugin_Changed;
			}

			if( damagecustom==TF_CUSTOM_TELEFRAG ) {
				if( Call_OnBossTakeDamage_OnTelefragged(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					damage = victim.iHealth+0.2;
					int flag = g_vsh2.m_hCvars.TeleFragLogic.IntValue;
					float telefrag_dmg = g_vsh2.m_hCvars.TeleFragDamage.FloatValue;
					switch( flag ) {
						case 0: damage =  telefrag_dmg;
						case 1: damage *= telefrag_dmg;
						case 2: damage += telefrag_dmg;
						case 3: damage =  victim.iHealth + 0.2;
						case 4: damage =  victim.iHealth * telefrag_dmg;
						case 5: damage =  victim.iHealth + telefrag_dmg;
					}
				}
				int teleowner = FindTeleOwner(attacker);
				if( teleowner != -1 && teleowner != attacker ) {
					BaseBoss builder = BaseBoss(teleowner);
					builder.iDamage += RoundFloat(damage) / 2;
				}
				return Plugin_Changed;
			}

			if( g_vsh2.m_hCvars.Anchoring.BoolValue ) {
				int iFlags = GetEntityFlags(victim.index);
				if( (iFlags & (FL_ONGROUND|FL_DUCKING)) == (FL_ONGROUND|FL_DUCKING) ) {
					damagetype |= DMG_PREVENT_PHYSICS_FORCE;
				}
			}

			/// Heavy Shotguns heal for damage dealt
			if( StrContains(classname, "tf_weapon_shotgun", false) > -1 && hitter.iTFClass==TFClass_Heavy ) {
				return Call_OnBossTakeDamage_OnHeavyShotgun(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
			} else if( StrContains(classname, "tf_weapon_sniperrifle", false) > -1 && g_vshgm.iRoundState != StateEnding ) {
				float bossGlow = victim.flGlowtime;
				float chargelevel = (IsValidEntity(weapon) && weapon > MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
				float time = (bossGlow > 10 ? 1.0 : 2.0);
				time += (bossGlow > 10 ? (bossGlow > 20 ? 1 : 2) : 4) * (chargelevel / 100);
				bossGlow += RoundToCeil(time);
				float max_time_cap = g_vsh2.m_hCvars.MaxBossGlowTime.FloatValue;
				if( bossGlow > max_time_cap ) {
					bossGlow = max_time_cap;
				}
				victim.flGlowtime = bossGlow;

				if( !(damagetype & DMG_CRIT) ) {
					bool ministatus = (TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed) || TF2_IsPlayerInCondition(attacker, TFCond_CritHype));
					if( Call_OnBossTakeDamage_OnSniped(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
						damage *= (ministatus) ? 2.222222 : 3.0;
						return Plugin_Changed;
					}
					return Plugin_Changed;
				}
			}

			/// Patch Nov 1, 2019: being in water fires air shot hook.
			int boss_flags = GetEntityFlags(victim.index);
			int grounded = boss_flags & FL_ONGROUND;
			int swimming = boss_flags & FL_INWATER;
			if( !grounded && !swimming && !StrContains(inflictor_name, "tf_projectile_", false) ) {
				float ray_angle[] = { 90.0, 0.0, 0.0 };
				TR_TraceRayFilter(damagePosition, ray_angle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayIgnoreEnts);
				if( TR_DidHit() ) {
					float end_pos[3]; TR_GetEndPosition(end_pos);
					if( GetVectorDistance(damagePosition, end_pos) >= g_vsh2.m_hCvars.AirShotDist.FloatValue ) {
						if( Call_OnBossAirShotProj(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) ) {
							return Plugin_Changed;
						}
					}
				}
			}

			/// everything else covered here.
			return Call_OnBossTakeDamage(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
		}
	}
	return Plugin_Continue;
}

public Action ManageOnBossDealDamage(const BaseBoss victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	BaseBoss fighter = BaseBoss(attacker);
	switch( fighter.iBossType ) {
		case -1: {}
		default: {
			victim.iHits++;
			victim.flLastHit = GetGameTime();

			int client = victim.index;
			if( damagecustom == TF_CUSTOM_BOOTS_STOMP ) {
				if( Call_OnBossDealDamage_OnStomp(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					float flFallVelocity = GetEntPropFloat(inflictor, Prop_Send, "m_flFallVelocity");
					/// TF2 Fall Damage formula, modified for VSH2
					damage = 10.0 * (GetRandomFloat(0.8, 1.2) * (5.0 * (flFallVelocity / 300.0)));
				}
				return Plugin_Changed;
			}
			if( TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed) ) {
				if( Call_OnBossDealDamage_OnHitDefBuff(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					ScaleVector(damageForce, 9.0);
					damage *= g_vsh2.m_hCvars.OnHitBattalions.FloatValue;
				}
				return Plugin_Changed;
			}
			/*
			if( TF2_IsPlayerInCondition(client, TFCond_DefenseBuffMmmph) ) {
				damage *= 9;
				/// Patch: Nov 14, 2017 - removing post-bonk slowdown.
				TF2_AddCondition(client, TFCond_UberchargedOnTakeDamage, 0.1);
				return Plugin_Changed;
			}
			*/
			if( TF2_IsPlayerInCondition(client, TFCond_CritMmmph) ) {
				if( Call_OnBossDealDamage_OnHitCritMmmph(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					damage *= g_vsh2.m_hCvars.OnHitPhlogTaunt.FloatValue;
					return Plugin_Changed;
				}
				return Plugin_Changed;
			}

			int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			char mediclassname[32];
			if( IsValidEntity(medigun)
				&& GetEdictClassname(medigun, mediclassname, sizeof(mediclassname))
				&& !strcmp(mediclassname, "tf_weapon_medigun", false)
				&& !TF2_IsPlayerInCondition(client, TFCond_Ubercharged)
				&& weapon == GetPlayerWeaponSlot(attacker, 2)) {
				/**
				 * If medic has (nearly) full uber, use it as a single-hit shield to prevent medics from dying early.
				 * Entire team is pretty much screwed if all the medics just die.
				 */
				if( Call_OnBossDealDamage_OnHitMedic(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
					if( g_vsh2.m_hCvars.MedicUberShield.BoolValue && GetMediCharge(medigun) >= 0.90 ) {
						SetMediCharge(medigun, 0.1);
						ScaleVector(damageForce, 9.0);
						damage *= 0.1;
						/// Patch: Nov 14, 2017 - removing post-bonk slowdown.
						//TF2_AddCondition(client, TFCond_UberchargedOnTakeDamage, 0.1);
						EmitSoundToAll("player/spy_shield_break.wav", client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, 1.0, 100, _, _, NULL_VECTOR, true, 0.0);
						TF2_AddCondition(client, TFCond_SpeedBuffAlly, 5.0);
						return Plugin_Changed;
					}
				}
				return Plugin_Changed;
			}

			/// eggs probably do melee damage to spies, then? That's not ideal, but eh.
			if( victim.iTFClass == TFClass_Spy ) {
				if( TF2_IsPlayerInCondition(client, TFCond_Cloaked) ) {
					if( Call_OnBossDealDamage_OnHitCloakedSpy(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom) != Plugin_Changed ) {
						if( damagetype & DMG_CRIT )
							damagetype &= ~DMG_CRIT;
						if( damagetype & (DMG_CLUB|DMG_SLASH) )
							damage = g_vsh2.m_hCvars.CloakDamage.FloatValue / FindConVar("tf_stealth_damage_reduction").FloatValue;
						return Plugin_Changed;
					}
					return Plugin_Changed;
				}
			}

			return Call_OnBossDealDamage(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
		}
	}
	return Plugin_Continue;
}

#if defined _goomba_included_
public Action ManageOnGoombaStomp(int attacker, int client, float& damageMultiplier, float& damageAdd, float& JumpPower)
{
	BaseBoss boss = BaseBoss(client);
	/// Players Stomping the Boss
	if( boss.bIsBoss ) {
		switch( boss.iBossType ) {
			/// Ignore if not boss at all.
			case -1: {}
			/// Default behaviour for Goomba Stompoing the Boss
			default: {
				damageAdd = float(g_vsh2.m_hCvars.GoombaDamageAdd.IntValue);
				damageMultiplier = g_vsh2.m_hCvars.GoombaLifeMultiplier.FloatValue;
				JumpPower = g_vsh2.m_hCvars.GoombaReboundPower.FloatValue;

				//PrintToChatAll("%N Just Goomba stomped %N(The Boss)!", attacker, client);
				CPrintToChatAllEx(attacker, "{olive}>> {teamcolor}%N {default}just goomba stomped {unique}%N{default}!", attacker, client);
				return Plugin_Changed;
			}
		}
		return Plugin_Continue;
	}

	boss = BaseBoss(attacker);
	/// The Boss(es) Stomping a player
	if( boss.bIsBoss ) {
		switch( boss.iBossType ) {
			/// Ignore if not boss at all.
			case -1: {}
			/// Default behaviour for the Boss Goomba Stomping other players.
			default: {
				/// Block the Boss from Goomba Stomping if disabled.
				if( !g_vsh2.m_hCvars.CanBossGoomba.BoolValue ) {
					return Plugin_Handled;
				}
				//PrintToChatAll("%N(The Boss) just got stomped by %N!", client, attacker);
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
#endif

public void ManageBossKillPlayer(const BaseBoss attacker, const BaseBoss victim, Event event)
{
	Action act = Call_OnPlayerKilled(attacker, victim, event);
	if( act > Plugin_Changed ) {
		return;
	}
	//int dmgbits = event.GetInt("damagebits");
	int deathflags = event.GetInt("death_flags");

	/// If victim is a boss, kill him off
	if( victim.bIsBoss ) {
		RequestFrame(_BossDeath, victim.userid);
		//SetPawnTimer(_BossDeath, 0.1, victim.userid);
	}
	if( attacker.bIsBoss ) {
		switch( attacker.iBossType ) {
			case -1: {}
			case VSH2Boss_Hale: {
				if( deathflags & TF_DEATHFLAG_DEADRINGER ) {
					event.SetString("weapon", "fists");
				} else {
					ToCHale(attacker).KilledPlayer(victim, event);
				}
			}
			case VSH2Boss_Vagineer: ToCVagineer(attacker).KilledPlayer(victim, event);
			case VSH2Boss_CBS:      ToCChristian(attacker).KilledPlayer(victim, event);
			case VSH2Boss_HHHjr:    ToCHHHJr(attacker).KilledPlayer(victim, event);
			case VSH2Boss_Bunny:    ToCBunny(attacker).KilledPlayer(victim, event);
		}
	}
}
public void ManageHurtPlayer(const BaseBoss attacker, const BaseBoss victim, Event event)
{
	Action act = Call_OnPlayerHurt(attacker, victim, event);
	if( act > Plugin_Changed ) {
		return;
	}
	int damage = event.GetInt("damageamount");
	int custom = event.GetInt("custom");
	int weapon = event.GetInt("weaponid");
	switch( victim.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale, VSH2Boss_Vagineer, VSH2Boss_CBS, VSH2Boss_HHHjr, VSH2Boss_Bunny: {
			victim.GiveRage(damage);
		}
	}

	/// Minions shouldn't have their damage tracked.
	if( attacker.bIsMinion ) {
		return;
	}

	/// Telefrags normally 1-shot the boss but let's cap damage at 9k
	if( custom == TF_CUSTOM_TELEFRAG ) {
		damage = (IsPlayerAlive(attacker.index) ? 9001 : 1);
	}
	/// block off bosses from doing the rest of things but track their damage.
	attacker.iDamage += damage;
	if( attacker.bIsBoss ) {
		return;
	}

	if( attacker.iTFClass==TFClass_Heavy && weapon==TF_WEAPON_SHOTGUN_HWG ) {
		/// Heavy Shotgun healing.
		int health = GetClientHealth(attacker.index);
		int maxhp = GetEntProp(attacker.index, Prop_Data, "m_iMaxHealth");
		int heavy_overheal = RoundFloat(FindConVar("tf_max_health_boost").FloatValue * maxhp);

		int health_from_dmg = (( health < maxhp ) ? (maxhp - health) : (heavy_overheal - health)) % damage;
		if( health_from_dmg==0 ) {
			health_from_dmg = damage >> view_as< int >(health > maxhp);
		}
		HealPlayer(attacker.index, health_from_dmg, true);
	}

	/// Medics now count as 3/5 of a backstab, similar to telefrag assists.
	int healers = GetEntProp(attacker.index, Prop_Send, "m_nNumHealers");
	int healercount;
	for( int i=0; i<healers; i++ ) {
		if( 0 < GetHealerByIndex(attacker.index, i) <= MaxClients ) {
			healercount++;
		}
	}

	BaseBoss medic;
	for( int r; r<healers; r++ ) {
		medic = BaseBoss(GetHealerByIndex(attacker.index, r));
		if( 0 < medic.index <= MaxClients ) {
			if( damage < 10 || medic.iUberTarget == attacker.userid ) {
				medic.iDamage += damage;
			} else {
				medic.iDamage += damage/(healercount+1);
			}
		}
	}
}

public void ManagePlayerAirblast(const BaseBoss airblaster, const BaseBoss airblasted, Event event)
{
	Action act = Call_OnPlayerAirblasted(airblaster, airblasted, event);
	if( act > Plugin_Changed )
		return;

	switch( airblasted.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale, VSH2Boss_CBS, VSH2Boss_HHHjr, VSH2Boss_Bunny:
			airblasted.flRAGE += g_vsh2.m_hCvars.AirblastRage.FloatValue;
		case VSH2Boss_Vagineer: {
			if( TF2_IsPlayerInCondition(airblasted.index, TFCond_Ubercharged) ) {
				float dur      = GetConditionDuration(airblasted.index, TFCond_Ubercharged);
				float max_dur  = g_vsh2.m_hCvars.VagineerUberTime.FloatValue;
				float increase = g_vsh2.m_hCvars.VagineerUberAirBlast.FloatValue;
				SetConditionDuration(airblasted.index, TFCond_Ubercharged, dur + increase < max_dur ? dur + increase : max_dur);
			} else {
				airblasted.flRAGE += g_vsh2.m_hCvars.AirblastRage.FloatValue;
			}
		}
	}
}

public Action ManageTraceHit(const BaseBoss victim, const BaseBoss attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	return Call_OnTraceAttack(victim, attacker, inflictor, damage, damagetype, ammotype, hitbox, hitgroup);
}
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if( !g_vsh2.m_hCvars.Enabled.BoolValue || !IsPlayerAlive(client) )
		return Plugin_Continue;

	BaseBoss base = BaseBoss(client);
	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Bunny: {
			if( GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) == GetActiveWep(client) ) {
				buttons &= ~IN_ATTACK;
				return Plugin_Changed;
			}
		}
		case VSH2Boss_HHHjr: {
			if( base.flCharge >= 47.0 && (buttons & IN_ATTACK) ) {
				buttons &= ~IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	BaseBoss player = BaseBoss(client);
	if( !player.bIsBoss ) {
		return;
	}
	bool remove;
	switch( condition ) {
		case TFCond_Disguised, TFCond_Jarated, TFCond_MarkedForDeath:
			remove = true;
	}

	if( Call_OnBossConditionChange(player, condition, remove) <= Plugin_Changed && remove ) {
		TF2_RemoveCondition(client, condition);
	}
}

public void ManageBossMedicCall(const BaseBoss base)
{
	Action act = Call_OnBossMedicCall(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale, VSH2Boss_Vagineer, VSH2Boss_CBS, VSH2Boss_HHHjr, VSH2Boss_Bunny: {
			if( base.flRAGE < 100.0 ) {
				return;
			}
			DoTaunt(base.index, "", 0);
			base.flRAGE = 0.0;
		}
	}
}
public void ManageBossTaunt(const BaseBoss base)
{
	Action act = Call_OnBossTaunt(base);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(base).RageAbility();
		case VSH2Boss_Vagineer: ToCVagineer(base).RageAbility();
		case VSH2Boss_CBS:      ToCChristian(base).RageAbility();
		case VSH2Boss_HHHjr:    ToCHHHJr(base).RageAbility();
		case VSH2Boss_Bunny:    ToCBunny(base).RageAbility();
	}
}

public void ManageBuildingDestroyed(const BaseBoss base, const int building, const int objecttype, Event event)
{
	Action act = Call_OnBossKillBuilding(base, building, event);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale: {
			event.SetString("weapon", "fists");
			ToCHale(base).KillToy();
		}
	}
}

public void ManagePlayerJarated(const BaseBoss attacker, const BaseBoss victim)
{
	Action act = Call_OnBossJarated(victim, attacker);
	if( act > Plugin_Changed )
		return;

	switch( victim.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale, VSH2Boss_Vagineer, VSH2Boss_CBS, VSH2Boss_HHHjr, VSH2Boss_Bunny:
			victim.flRAGE -= g_vsh2.m_hCvars.JarateRage.FloatValue;
	}
}

public Action HookSound(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags)
{
	if( !g_vsh2.m_hCvars.Enabled.BoolValue || !IsValidClient(entity) )
		return Plugin_Continue;

	BaseBoss base = BaseBoss(entity);
	Action act = Call_OnSoundHook(base, sample, channel, volume, level, pitch, flags);
	if( act != Plugin_Continue )
		return act;

	switch( base.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale: {
			if( !strncmp(sample, "vo", 2, false) ) {
				return Plugin_Handled;
			}
		}
		case VSH2Boss_Vagineer: {
			if( StrContains(sample, "vo/engineer_laughlong01", false) != -1 ) {
				strcopy(sample, PLATFORM_MAX_PATH, VagineerKSpree);
				return Plugin_Changed;
			}
			if( !strncmp(sample, "vo", 2, false) ) {
				if( StrContains(sample, "positivevocalization01", false) != -1 ) {
					/// For backstab sound
					return Plugin_Continue;
				}
				if( StrContains(sample, "engineer_moveup", false) != -1 ) {
					Format(sample, PLATFORM_MAX_PATH, "%s%i.wav", VagineerJump, GetRandomInt(1, 2));
				} else if( StrContains(sample, "engineer_no", false) != -1 || GetRandomInt(0, 9) > 6 ) {
					strcopy(sample, PLATFORM_MAX_PATH, "vo/engineer_no01.wav");
				} else {
					strcopy(sample, PLATFORM_MAX_PATH, "vo/engineer_jeers02.wav");
				}
				return Plugin_Changed;
			} else {
				return Plugin_Continue;
			}
		}
		case VSH2Boss_HHHjr: {
			if( !strncmp(sample, "vo", 2, false) ) {
				if( GetRandomInt(0, 30) <= 10 ) {
					Format(sample, PLATFORM_MAX_PATH, "%s0%i.wav", HHHLaught, GetRandomInt(1, 4));
					return Plugin_Changed;
				}
				if( StrContains(sample, "halloween_boss") == -1 ) {
					return Plugin_Handled;
				}
			}
		}
		case VSH2Boss_Bunny: {
			if( StrContains(sample, "gibberish", false) == -1
				&& StrContains(sample, "burp", false) == -1
				&& !GetRandomInt(0, 2) ) /// Do sound things
			{
				strcopy(sample, PLATFORM_MAX_PATH, BunnyRandomVoice[GetRandomInt(0, sizeof(BunnyRandomVoice)-1)]);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if( !g_vsh2.m_hCvars.Enabled.BoolValue )
		return Plugin_Continue;

	BaseBoss base = BaseBoss(client);
	if( base.bIsBoss ) {
		switch( base.iBossType ) {
			case -1: {}
			case VSH2Boss_HHHjr: {
				if( base.iClimbs < g_vsh2.m_hCvars.HHHMaxClimbs.IntValue && base.ClimbWall(weapon, g_vsh2.m_hCvars.HHHClimbVelocity.FloatValue, 0.0, false) ) {
					base.flWeighDown = 0.0;
				}
			}
		}

		/// Fuck random crits
		if( TF2_IsPlayerCritBuffed(base.index) ) {
			return Plugin_Continue;
		}
		result = false;
		return Plugin_Changed;
	} else if( !base.bIsMinion ) {
		if( base.iTFClass==TFClass_Sniper
				&& IsWeaponSlotActive(client, TFWeaponSlot_Melee)
				&& g_vsh2.m_hCvars.AllowSniperClimbing.BoolValue ) {
			base.ClimbWall(weapon, g_vsh2.m_hCvars.SniperClimbVelocity.FloatValue, g_vsh2.m_hCvars.SniperClimbDmg.FloatValue, true);
		}
	}
	return Plugin_Continue;
}

public void ManageMessageIntro(BaseBoss[] bosses, const int len)
{
	if( g_vshgm.bDoors ) {
		int ent = -1;
		while( (ent = FindEntityByClassname(ent, "func_door")) != -1 ) {
			AcceptEntityInput(ent, "Open");
			AcceptEntityInput(ent, "Unlock");
		}
	}

	char intro_msg[MAXMESSAGE];
	int i;
	for( i=0; i<len; ++i ) {
		BaseBoss base = bosses[i];
		if( base==view_as< BaseBoss >(0) )
			continue;

		char name[MAX_BOSS_NAME_SIZE], boss_msg[MAXMESSAGE];
		base.GetName(name);

		Format(boss_msg, sizeof boss_msg, "%N has become %s with %i Health", base.index, name, base.iHealth);
		Action act = Call_OnMessageIntro(base, boss_msg);
		if( act > Plugin_Changed )
			continue;

		StrCat(intro_msg, MAXMESSAGE, boss_msg);
		StrCat(intro_msg, MAXMESSAGE, "\n");
	}

	SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
	for( i=MaxClients; i; --i ) {
		if( IsClientInGame(i) ) {
			ShowHudText(i, -1, "%s", intro_msg);
		}
	}
	g_vshgm.iRoundState = StateRunning;
}

public void ManageBossPickUpItem(const BaseBoss base, const char item[64])
{
	Action act = Call_OnBossPickUpItem(base, item);
	if( act > Plugin_Changed )
		return;

	switch( base.iBossType ) {
		case -1: {}
	}
}

public void ManageResetVariables(const BaseBoss base)
{
	Action act = Call_OnVariablesReset(base);
	if( act > Plugin_Changed )
		return;

	base.iBossType     = -1;
	base.iStabbed      = 0;
	base.iMarketted    = 0;
	base.flRAGE        = 0.0;
	base.bIsMinion     = false;
	base.iDamage       = 0;
	base.iAirDamage    = 0;
	base.iUberTarget   = 0;
	base.flCharge      = 0.0;
	base.flGlowtime    = 0.0;
	base.bUsedUltimate = false;
	base.iOwnerBoss    = 0;
	base.iSongPick     = -1;
	SetEntityRenderColor(base.index, 255, 255, 255, 255);
	base.flLastShot    = 0.0;
	base.flLastHit     = 0.0;
	base.iState        = -1;
	base.iHits         = 0;
	base.iLives        = ((g_vshgm.bMedieval || g_vsh2.m_hCvars.ForceLives.BoolValue) ? g_vsh2.m_hCvars.MedievalLives.IntValue : 0);
	base.iMaxHealth    = 0;
	base.iShieldDmg    = 0;
	base.iClimbs       = 0;
	base.bSuperCharge  = false;
	base.bInJump       = false; /// PATCH: rocket jumping at end of round then respawning keeps this on true with perma-crit market gardener.
}
public void ManageEntityCreated(const int entity, const char[] classname)
{
	if( StrContains(classname, "rune") != -1 ) {
		CreateTimer(0.1, RemoveEnt, EntIndexToEntRef(entity));
	} else if( StrEqual(classname, "tf_dropped_weapon") && !g_vsh2.m_hCvars.DroppedWeapons.BoolValue ) {
		/// Remove dropped weapons to avoid bad things
		AcceptEntityInput(entity, "kill");
	} else if( !strcmp(classname, "tf_projectile_cleaver", false) ) {
		SDKHook(entity, SDKHook_SpawnPost, OnCleaverSpawned);
	} else if( g_vshgm.iRoundState == StateRunning ) {
		if( !strcmp(classname, "tf_projectile_pipe", false) ) {
			SDKHook(entity, SDKHook_SpawnPost, OnEggBombSpawned);
		} else if( !strcmp(classname, "item_healthkit_medium", false) || !strcmp(classname, "item_healthkit_small", false) ) {
			int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
			if( team != VSH2Team_Red ) {
				SetEntProp(entity, Prop_Send, "m_iTeamNum", VSH2Team_Red, 4);
			}
		}
	}
}
public void OnEggBombSpawned(int entity)
{
	int owner = GetOwner(entity);
	BaseBoss boss = BaseBoss(owner);
	if( IsClientValid(owner) && boss.bIsBoss && boss.iBossType == VSH2Boss_Bunny ) {
		CreateTimer(0.0, Timer_SetEggBomb, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}
public void OnCleaverSpawned(int entity)
{
	int client = GetThrower(entity);
	if( IsClientValid(client) && TF2_GetPlayerClass(client)==TFClass_Spy ) {
		char kunai_model[] = "models/weapons/c_models/c_shogun_kunai/c_shogun_kunai.mdl";
		PrecacheModel(kunai_model, true);
		SetEntityModel(entity, kunai_model);
		SetEntityGravity(entity, 10.0);
	}
}

public void ManageUberDeploy(const BaseBoss medic, const BaseBoss patient)
{
	int medigun = GetPlayerWeaponSlot(medic.index, TFWeaponSlot_Secondary);
	if( IsValidEntity(medigun) ) {
		char strMedigun[32]; GetEdictClassname(medigun, strMedigun, sizeof(strMedigun));
		if( !strcmp(strMedigun, "tf_weapon_medigun", false) ) {
			Action act = Call_OnUberDeployed(medic, patient);
			if( act > Plugin_Changed )
				return;

			SetMediCharge(medigun, g_vsh2.m_hCvars.UberDeployChargeAmnt.FloatValue);
			TF2_AddCondition(medic.index, TFCond_CritOnWin, 0.5, medic.index);
			if( IsClientValid(patient.index) && IsPlayerAlive(patient.index) ) {
				TF2_AddCondition(patient.index, TFCond_CritOnWin, 0.5, medic.index);
				medic.iUberTarget = patient.userid;
			} else {
				medic.iUberTarget = 0;
			}
			CreateTimer(0.1, Timer_UberLoop, EntIndexToEntRef(medigun), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void ManageMusic(char song[PLATFORM_MAX_PATH], float& time, float& vol)
{
	/// UNFORTUNATELY, we have to get a random boss so we can set our music, tragic I know...
	/// Remember that you can get a random boss filtered by type as well!
	BaseBoss currBoss = VSHGameMode.GetRandomBoss(true);
	Action act = Call_OnMusic(song, time, currBoss, vol);
	if( act > Plugin_Changed )
		return;

	if( currBoss && song[0]=='\0' ) {
		switch( currBoss.iBossType ) {
			case -1: {song = "\0"; time = -1.0;}
			case VSH2Boss_CBS: {
				strcopy(song, sizeof(song), CBSTheme);
				time = 140.0;
			}
			case VSH2Boss_HHHjr: {
				strcopy(song, sizeof(song), HHHTheme);
				time = 90.0;
			}
			case VSH2Boss_Bunny, VSH2Boss_Hale, VSH2Boss_Vagineer: {
				song = "\0";
				time = -1.0;
			}
		}
	}
}
public void StopBackGroundMusic()
{
	if( g_vsh2.m_strCurrSong[0] != 0 ) {
		for( int i=MaxClients; i; --i ) {
			if( !IsClientValid(i) ) {
				continue;
			}
			BaseBoss(i).StopMusic();
		}
	}
}

public void ManageRoundEndBossInfo(BaseBoss[] bosses, const int len, const bool bossWon)
{
	char round_end_msg[MAXMESSAGE];
	BaseBoss base;
	for( int i; i<len; i++ ) {
		base = bosses[i];
		if( base==view_as< BaseBoss >(0) )
			continue;

		char name[MAX_BOSS_NAME_SIZE], boss_msg[MAXMESSAGE];
		base.GetName(name);

		Format(boss_msg, sizeof boss_msg, "%s (%N) had %i (of %i) health left.", name, base.index, base.iHealth, base.iMaxHealth);

		Action act = Call_OnRoundEndInfo(base, bossWon, boss_msg);
		if( act > Plugin_Changed )
			continue;

		StrCat(round_end_msg, MAXMESSAGE, boss_msg);
		StrCat(round_end_msg, MAXMESSAGE, "\n");

		if( bossWon ) {
			switch( base.iBossType ) {
				case -1: {}
				case VSH2Boss_Vagineer: ToCVagineer(base).PlayWinSound();
				case VSH2Boss_Bunny:    ToCBunny(base).PlayWinSound();
				case VSH2Boss_Hale:     ToCHale(base).PlayWinSound();
			}
		}
		base.iDifficulty = 0;
	}
	if( round_end_msg[0] != '\0' ) {
		CPrintToChatAll("{olive}[VSH 2] End of Round{default} %s", round_end_msg);
		SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
		for( int i=MaxClients; i; --i ) {
			if( IsValidClient(i) && !(GetClientButtons(i) & IN_SCORE) ) {
				ShowHudText(i, -1, "%s", round_end_msg);
			}
		}
	}
}
public void ManageLastPlayer()
{
	BaseBoss currBoss = VSHGameMode.GetRandomBoss(true);
	Action act = Call_OnLastPlayer(currBoss);
	if( act > Plugin_Changed )
		return;

	switch( currBoss.iBossType ) {
		case -1: {}
		case VSH2Boss_Hale:     ToCHale(currBoss).LastPlayerSoundClip();
		case VSH2Boss_Vagineer: ToCVagineer(currBoss).LastPlayerSoundClip();
		case VSH2Boss_CBS:      ToCChristian(currBoss).LastPlayerSoundClip();
		case VSH2Boss_Bunny:    ToCBunny(currBoss).LastPlayerSoundClip();
	}
}

public void ManageBossCheckHealth(const BaseBoss base)
{
	static int LastBossTotalHealth;
	float currtime = GetGameTime();

	/// If a boss reveals their own health, only show that one boss' health.
	if( base.bIsBoss && IsPlayerAlive(base.index) ) {
		char health_check[MAXMESSAGE];
		Action act = Call_OnBossHealthCheck(base, true, health_check);
		if( act > Plugin_Changed )
			return;

		char name[MAX_BOSS_NAME_SIZE];
		base.GetName(name);
		PrintCenterTextAll("%s showed his current HP: %i of %i", name, base.iHealth, base.iMaxHealth);
		LastBossTotalHealth = base.iHealth;
		return;
	} else if( currtime >= g_vshgm.flHealthTime ) {
		/// If a non-boss is checking health, reveal all Boss' hp
		g_vshgm.iHealthChecks++;
		int totalHealth;
		char health_check[MAXMESSAGE];
		for( int i=MaxClients; i; --i ) {
			/// exclude dead bosses for health check
			if( !IsValidClient(i) || !IsPlayerAlive(i) )
				continue;

			BaseBoss boss = BaseBoss(i);
			if( !boss.bIsBoss )
				continue;

			char name[MAX_BOSS_NAME_SIZE], boss_msg[MAXMESSAGE];
			boss.GetName(name);
			Format(boss_msg, sizeof boss_msg, "%s's current health is: %i of %i", name, boss.iHealth, boss.iMaxHealth);

			Action act = Call_OnBossHealthCheck(boss, false, boss_msg);
			if( act > Plugin_Changed )
				continue;

			StrCat(health_check, MAXMESSAGE, boss_msg);
			StrCat(health_check, MAXMESSAGE, "\n");
			totalHealth += boss.iHealth;
		}
		PrintCenterTextAll(health_check);
		CPrintToChatAll("{olive}[VSH 2] {axis}Boss Health Check{default} %s", health_check);
		LastBossTotalHealth = totalHealth;
		g_vshgm.flHealthTime = currtime + ((g_vshgm.iHealthChecks < 3) ? 10.0 : 60.0);
	} else {
		CPrintToChat(base.index, "{olive}[VSH 2]{default} You cannot see the Boss HP now (wait %i seconds). Last known total boss health was %i.", RoundFloat(g_vshgm.flHealthTime-currtime), LastBossTotalHealth);
	}
}

public void CheckAlivePlayers(const any nil)
{
	if( g_vshgm.iRoundState != StateRunning )
		return;

	int living = GetLivingPlayers(VSH2Team_Red);
	if( !living ) {
		ForceTeamWin(VSH2Team_Boss);
	} else if( living == 1 && VSHGameMode.CountBosses(true) > 0 && g_vshgm.iTimeLeft <= 0 ) {
		ManageLastPlayer(); /// in handler.sp
		g_vshgm.iTimeLeft = g_vsh2.m_hCvars.LastPlayerTime.IntValue;

		/// maybe some day...
		/*
		int round_timer = -1;
		round_timer = FindEntityByClassname(RoundTimer, "team_round_timer");
		if( round_timer <= 0 )
			round_timer = CreateEntityByName("team_round_timer");

		if( round_timer > MaxClients && IsValidEntity(round_timer) ) {
			SetVariantInt(g_vsh2.m_hCvars.LastPlayerTime.IntValue);
			//DispatchKeyValue(round_timer, "targetname", TIMER_NAME);
			//DispatchKeyValue(round_timer, "setup_length", setupLength);
			//DispatchKeyValue(round_timer, "setup_length", "30");
			DispatchKeyValue(round_timer, "reset_time", "1");
			DispatchKeyValue(round_timer, "auto_countdown", "1");
			char time[5];
			IntToString(g_vsh2.m_hCvars.LastPlayerTime.IntValue, time, sizeof(time));
			DispatchKeyValue(round_timer, "timer_length", time);
			DispatchSpawn(round_timer);
		}
		*/
		CreateTimer(1.0, Timer_DrawGame, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	int enable_alive = g_vsh2.m_hCvars.AliveToEnable.IntValue;
	if( !g_vsh2.m_hCvars.PointType.BoolValue && living <= enable_alive && !g_vshgm.bPointReady ) {
		PrintHintTextToAll("%i players are left; control point enabled!", living);
		if( living==enable_alive ) {
			EmitSoundToAll("vo/announcer_am_capenabled02.wav");
		} else if( living < enable_alive ) {
			char cap_incite_snd[][] = {
				"vo/announcer_am_capincite01.wav",
				"vo/announcer_am_capincite03.wav"
			};
			EmitSoundToAll(cap_incite_snd[GetRandomInt(0, 1)]);
		}
		SetControlPoint(true);
		g_vshgm.bPointReady = true;
	}
}

public void ManageOnBossCap(char sCappers[MAXPLAYERS+1], const int capping_team, BaseBoss[] cappers, const int capper_count)
{
	Call_OnControlPointCapped(sCappers, capping_team, cappers, capper_count);
}

public void _SkipBossPanel()
{
	BaseBoss[] upnext = new BaseBoss[MaxClients];
	VSHGameMode.GetQueue(upnext);
	for( int j; j<3; j++ ) {
		if( !upnext[j] ) {
			continue;
		}

		/// If up next to become a boss.
		int player = upnext[j].index;
		if( !j ) {
			SkipBossPanelNotify(player);
		} else if( !IsFakeClient(player) ) {
			CPrintToChat(player, "{olive}[VSH 2]{default} You are going to be a Boss soon! Type {olive}/halenext{default} to check/reset your queue points & !setboss to set your boss.");
		}
	}
}

public void PrepPlayers(const BaseBoss player)
{
	int client = player.index;
	if( g_vshgm.iRoundState == StateEnding || !IsValidClient(client) || !IsPlayerAlive(client) || player.bIsBoss )
		return;

	Action act = Call_OnPrepRedTeam(player);
	if( act > Plugin_Changed )
		return;

	/// Added fix by Chdata to correct team colors
	int player_team = GetClientTeam(client);
	if( player_team > VSH2Team_Spectator && player_team != VSH2Team_Red ) {
		player.ForceTeamChange(VSH2Team_Red);
		TF2_RegeneratePlayer(client);
	}
	TF2_RegeneratePlayer(client);
	SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	if( !GetRandomInt(0, 1) ) {
		player.HelpPanelClass();
	}
}

public void ManageFighterThink(const BaseBoss fighter)
{
	int i = fighter.index;
	if( GetClientTeam(i) != VSH2Team_Red ) {
		return;
	}

	Action act = Call_OnRedPlayerThink(fighter);
	if( act > Plugin_Changed ) {
		return;
	}

	if( HasEntProp(i, Prop_Send, "m_iKillStreak") ) {
		/// killstreak support code.
		int killstreaker = fighter.iDamage / 1000;
		if( killstreaker > 0 && GetEntProp(i, Prop_Send, "m_iKillStreak") >= 0 ) {
			SetEntProp(i, Prop_Send, "m_iKillStreak", killstreaker);
		}
	}
	ManageFighterHUD(fighter);
	ManageFighterCrits(fighter);
	Call_OnRedPlayerThinkPost(fighter);
}

public void ManageFighterCrits(const BaseBoss fighter) {
	int i = fighter.index;
	TFClassType tfclass = fighter.iTFClass;

	char wepclassname[64];
	int weapon = GetActiveWep(i);
	bool validwep = (weapon != -1 && IsValidEntity(weapon));
	if( validwep ) {
		GetEdictClassname(weapon, wepclassname, sizeof(wepclassname));
	}

	if( !TF2_IsPlayerInCondition(i, TFCond_Cloaked) ) {
		switch( GetLivingPlayers(VSH2Team_Red) ) {
			case 1: {
				TF2_AddCondition(i, TFCond_CritOnWin, 0.2);
				TF2_AddCondition(i, TFCond_Buffed,    0.2);
				int primary = GetPlayerWeaponSlot(i, TFWeaponSlot_Primary);
				if( tfclass==TFClass_Engineer && weapon==primary && StrEqual(wepclassname, "tf_weapon_sentry_revenge", false) ) {
					SetEntProp(i, Prop_Send, "m_iRevengeCrits", 3);
				}
				return;
			}
			case 2: {
				TF2_AddCondition(i, TFCond_Buffed, 0.2);
			}
		}
	}

	int crit_flags = 0;
	if( TF2_IsPlayerInCondition(i, TFCond_CritCola) && (tfclass==TFClass_Scout || tfclass==TFClass_Heavy) ) {
		crit_flags = CRITFLAG_FULL;
		Action act = Call_OnRedPlayerCrits(fighter, crit_flags);
		if( act <= Plugin_Changed ) {
			TF2_AddCondition(i, TFCond_CritOnWin, 0.2);
		}
		return;
	}

	int healers = GetEntProp(i, Prop_Send, "m_nNumHealers");
	for( int u; u<healers; u++ ) {
		if( 0 < GetHealerByIndex(i, u) <= MaxClients ) {
			crit_flags |= CRITFLAG_STACK;
			break;
		}
	}

	if( validwep ) {
		switch( GetSlotFromWeapon(i, weapon) ) {
			case TFWeaponSlot_Melee: {
				/// slightly longer check but makes sure that any weapon that can backstab will not crit (e.g. Saxxy)
				crit_flags |= view_as< int >(!!strcmp(wepclassname, "tf_weapon_knife", false)) << 1;
			}
			case TFWeaponSlot_Primary: {
				bool is_wep_class = (
					StrStarts(wepclassname, "tf_weapon_compound_bow") /// Sniper bows
					|| StrStarts(wepclassname, "tf_weapon_crossbow") /// Medic crossbows
					|| StrEqual(wepclassname,  "tf_weapon_shotgun_building_rescue") /// Engineer Rescue Ranger
					|| StrEqual(wepclassname,  "tf_weapon_drg_pomson") /// Engie Laser Shotty.
				);
				crit_flags |= view_as< int >(is_wep_class) << 1;
			}
			case TFWeaponSlot_Secondary: {
				if( StrStarts(wepclassname, "tf_weapon_pistol") /// Engineer/Scout pistols
					|| StrStarts(wepclassname, "tf_weapon_handgun_scout_secondary") /// Scout pistols
					|| StrStarts(wepclassname, "tf_weapon_flaregun")  /// Flare guns
					|| StrStarts(wepclassname, "tf_weapon_smg") /// Sniper SMGs minus Cleaner's Carbine
				) {
					crit_flags |= CRITFLAG_FULL;

					if( tfclass==TFClass_Scout ) {
						crit_flags = CRITFLAG_MINI;
					}
				}

				/// Jarate/Milk + Flying Guillotine
				crit_flags |= view_as< int >((StrStarts(wepclassname, "tf_weapon_jar") || StrEqual(wepclassname, "tf_weapon_cleaver"))) << 1;
			}
		}
	}

	/// overheal cond does nothing.
	Action act = Call_OnRedPlayerCrits(fighter, crit_flags);
	if( act > Plugin_Changed )
		return;

	if( crit_flags & CRITFLAG_MINI ) {
		TF2_AddCondition(i, TFCond_Buffed, 0.2);
	}
	if( crit_flags & CRITFLAG_FULL ) {
		if( crit_flags & CRITFLAG_STACK ) {
			TF2_AddCondition(i, TFCond_Buffed, 0.2);
		}
		TF2_AddCondition(i, TFCond_CritOnWin, 0.2);
	}

	switch( tfclass ) {
		case TFClass_Spy: {
			/// If Spies are cloaked or disguised, make sure they're not showing crit FX.
			if( validwep && weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Primary) ) {
				if( !TF2_IsPlayerCritBuffed(i)
					&& !TF2_IsPlayerInCondition(i, TFCond_Buffed)
					&& !TF2_IsPlayerInCondition(i, TFCond_Cloaked)
					&& !TF2_IsPlayerInCondition(i, TFCond_Disguised)
				) {
					TF2_AddCondition(i, TFCond_CritCola, 0.2);
				}
			}
		}
		case TFClass_Engineer: {
			/// Frontier Justice revenge-crits code.
			if( weapon == GetPlayerWeaponSlot(i, TFWeaponSlot_Primary) && StrEqual(wepclassname, "tf_weapon_sentry_revenge", false) ) {
				int sentry = FindSentry(i);
				if( IsValidEntity(sentry) ) {
					/// Trying to target minions as well
					int enemy = GetEntPropEnt(sentry, Prop_Send, "m_hEnemy");
					if( enemy > 0 && GetClientTeam(enemy) == VSH2Team_Boss ) {
						SetEntProp(i, Prop_Send, "m_iRevengeCrits", 3);
						TF2_AddCondition(i, TFCond_Kritzkrieged, 0.2);
					} else {
						if( HasEntProp(i, Prop_Send, "m_iRevengeCrits") ) {
							SetEntProp(i, Prop_Send, "m_iRevengeCrits", 0);
						} else if( TF2_IsPlayerInCondition(i, TFCond_Kritzkrieged) && !TF2_IsPlayerInCondition(i, TFCond_Healing) ) {
							TF2_RemoveCondition(i, TFCond_Kritzkrieged);
						}
					}
				}
			}
		}
	}
}

public void ManageFighterHUD(const BaseBoss fighter) {
	int i = fighter.index;

	/// HUD code
	char HUDText[PLAYER_HUD_SIZE];
	Format(HUDText, sizeof(HUDText), "Damage: %d", fighter.iDamage);
	if( !IsPlayerAlive(i) ) {
		int obstarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
		if( IsValidClient(obstarget) && GetClientTeam(obstarget) != VSH2Team_Boss && obstarget != i ) {
			BaseBoss observ = BaseBoss(obstarget);
			Format(HUDText, sizeof(HUDText), "%s - %N's Damage: %d", HUDText, obstarget, observ.iDamage);
		}
	} else if( g_vshgm.bMedieval || g_vsh2.m_hCvars.ForceLives.BoolValue ) {
		Format(HUDText, sizeof(HUDText), "%s | Lives: %d", HUDText, fighter.iLives);
	}

	TFClassType tfclass = fighter.iTFClass;
	char wepclassname[64];
	int weapon = GetActiveWep(i);
	bool validwep = (weapon != -1 && IsValidEntity(weapon));
	if( validwep ) {
		GetEdictClassname(weapon, wepclassname, sizeof(wepclassname));
	}

	switch( tfclass ) {
		/// Chdata's Deadringer Notifier
		case TFClass_Spy: {
			int spy_secondary = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			if( spy_secondary > MaxClients && IsValidEntity(spy_secondary) ) {
				Format(HUDText, sizeof(HUDText), "%s | Kunai: %s", HUDText, GetWeaponAmmo(spy_secondary) ? "Ready" : "None");
			}
		}
		case TFClass_Medic: {
			int medigun = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			char mediclassname[32];
			if( medigun > MaxClients && IsValidEntity(medigun) ) {
				GetEdictClassname(medigun, mediclassname, sizeof(mediclassname));
				if( !strcmp(mediclassname, "tf_weapon_medigun", false) ) {
					float charge_level = GetMediCharge(medigun);
					int charge = RoundToFloor(charge_level * 100);
					Format(HUDText, sizeof(HUDText), "%s\nUbercharge: %i%%", HUDText, charge);

					/// Fixes Ubercharges ending prematurely on Medics.
					if( GetEntProp(medigun, Prop_Send, "m_bChargeRelease") && charge_level > 0.0 && GetActiveWep(i)==medigun ) {
						TF2_AddCondition(i, TFCond_Ubercharged, 1.0);
					}
				}
			}
		}
	}

	Action act = Call_OnRedPlayerHUD(fighter, HUDText);
	if( act > Plugin_Changed ) {
		return;
	}

	if( !(GetClientButtons(i) & IN_SCORE) ) {
		SetHudTextParams(-1.0, 0.88, 0.35, 90, 255, 90, 255, 0, 0.35, 0.0, 0.1);
		ShowSyncHudText(i, g_vsh2.m_hHUDs[PlayerHUD], HUDText);
	}
}

/// too many temp funcs just to call as a timer. No wonder sourcepawn needs lambda funcs...
public void _RespawnPlayer(const int userid) {
	if( g_vshgm.iRoundState==StateRunning ) {
		TF2_RespawnPlayer(GetClientOfUserId(userid));
	}
}
