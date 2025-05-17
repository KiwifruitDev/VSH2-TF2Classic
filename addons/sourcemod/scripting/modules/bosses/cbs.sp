/// defines
#define CBSModel		"models/player/saxton_hale/cbs_v4.mdl"
// #define CBSModelPrefix		"models/player/saxton_hale/cbs_v4"

/// Christian Brutal Sniper voicelines
#define CBS0			"vo/sniper_specialweapon08.wav"
#define CBS1			"vo/taunts/sniper_taunts02.wav"
#define CBS2			"vo/sniper_award"
#define CBS3			"vo/sniper_battlecry03.wav"
#define CBS4			"vo/sniper_domination"
#define CBSJump1		"vo/sniper_specialcompleted02.wav"

#define CBSTheme		"saxton_hale/the_millionaires_holiday.mp3"

#define CBSRAGEDIST		320.0
#define CBS_MAX_ARROWS		9



methodmap CChristian < BaseBoss {
	public CChristian(const int ind, bool uid=false) {
		return view_as< CChristian >( BaseBoss(ind, uid) );
	}
	
	public void PlaySpawnClip() {
		this.PlayVoiceClip(CBS0, VSH2_VOICE_INTRO);
	}
	
	public void Think()
	{
		if( !IsPlayerAlive(this.index) )
			return;
		
		this.SpeedThink(HALESPEED);
		this.GlowThink(0.1);
		
		if( this.SuperJumpThink(2.5, HALE_JUMPCHARGE) ) {
			this.SuperJump(this.flCharge, -100.0);
			this.PlayVoiceClip(CBSJump1, VSH2_VOICE_ABILITY);
		}
		
		if( OnlyScoutsLeft(VSH2Team_Red) )
			this.flRAGE += g_vsh2.m_hCvars.ScoutRageGen.FloatValue;
		
		this.WeighDownThink(HALE_WEIGHDOWN_TIME);
		
		SetHudTextParams(-1.0, 0.77, 0.35, 255, 255, 255, 255);
		float jmp = this.flCharge;
		if( this.flRAGE >= 100.0 )
			ShowSyncHudText(this.index, g_vsh2.m_hHUDs[PlayerHUD], "Jump: %i%% | Rage: FULL - Call Medic (default: E) to activate", this.bSuperCharge ? 1000 : RoundFloat(jmp) * 4);
		else ShowSyncHudText(this.index, g_vsh2.m_hHUDs[PlayerHUD], "Jump: %i%% | Rage: %0.1f", this.bSuperCharge ? 1000 : RoundFloat(jmp) * 4, this.flRAGE);
	}
	public void SetModel() {
		SetVariantString(CBSModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		//SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.25);
	}
	
	public void Death() {
		// char ded_snd[PLATFORM_MAX_PATH];
		//EmitSoundToAll(snd, this.index, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC);
	}
	
	public void Equip() {
		this.SetName("The Christian Brutal Sniper");
		this.RemoveAllItems();
		this.SpawnWeapon(BossWeapon_ChristianBrutalSniper_Kukri);
	}
	public void RageAbility() {
		TF2_AddCondition(this.index, view_as< TFCond >(42), 4.0);
		TF2_RemoveCondition(this.index, TFCond_Taunting);
		this.SetModel();
		this.DoGenericStun(CBSRAGEDIST);
		this.PlayVoiceClip(GetRandomInt(0, 1) ? CBS1 : CBS3, VSH2_VOICE_RAGE);
		
		TF2_RemoveWeaponSlot(this.index, TFWeaponSlot_Primary);
		this.SpawnWeapon(BossWeapon_ChristianBrutalSniper_Huntsman);
	}
	
	public void KilledPlayer(const BaseBoss victim, Event event)
	{
		int living = GetLivingPlayers(VSH2Team_Red);
		if( !GetRandomInt(0, 3) && living != 1 ) {
			switch( victim.iTFClass ) {
				case TFClass_Spy: {
					this.PlayVoiceClip("vo/sniper_dominationspy04.wav", VSH2_VOICE_SPREE);
				}
			}
		}
		int weapon = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		if( weapon == GetPlayerWeaponSlot(this.index, TFWeaponSlot_Melee) ) {
			TF2_RemoveWeaponSlot(this.index, TFWeaponSlot_Melee);
			this.SpawnWeapon(BossWeapon_ChristianBrutalSniper_Kukri);
		}

		float curtime = GetGameTime();
		if( curtime <= this.flKillSpree )
			this.iKills++;
		else this.iKills = 0;
		
		if( this.iKills == 3 && living != 1 ) {
			char spree_snd[PLATFORM_MAX_PATH];
			if( !GetRandomInt(0, 3) )
				Format(spree_snd, PLATFORM_MAX_PATH, CBS0);
			else if( !GetRandomInt(0, 3) )
				Format(spree_snd, PLATFORM_MAX_PATH, CBS1);
			else Format(spree_snd, PLATFORM_MAX_PATH, "%s%02i.wav", CBS2, GetRandomInt(1, 9));
			this.PlayVoiceClip(spree_snd, VSH2_VOICE_SPREE);
			this.iKills = 0;
		}
		else this.flKillSpree = curtime+5;
	}
	public void Help() {
		if( IsVoteInProgress() )
			return;
		char helpstr[] = "Christian Brutal Sniper:\nSuper Jump: crouch, look up and stand up.\nWeigh-down: in midair, look down and crouch\nRage (Huntsman Bow): taunt when Rage is full (9 arrows).\nVery close-by enemies are stunned.";
		Panel panel = new Panel();
		panel.SetTitle(helpstr);
		panel.DrawItem("Exit");
		panel.Send(this.index, HintPanel, 10);
		delete panel;
	}
	public void LastPlayerSoundClip() {
		char lastguy_snd[PLATFORM_MAX_PATH];
		if( !GetRandomInt(0, 2) )
			Format(lastguy_snd, PLATFORM_MAX_PATH, "%s", CBS0);
		else Format(lastguy_snd, PLATFORM_MAX_PATH, "%s%i.wav", CBS4, GetRandomInt(1, 25));
		this.PlayVoiceClip(lastguy_snd, VSH2_VOICE_LASTGUY);
	}
};

public CChristian ToCChristian (const BaseBoss guy)
{
	return view_as< CChristian >(guy);
}

public void AddCBSToDownloads()
{
	PrepareModel(CBSModel);
	PrepareMaterial("materials/models/player/saxton_hale/sniper_red");
	PrepareMaterial("materials/models/player/saxton_hale/sniper_lens");
	PrepareMaterial("materials/models/player/saxton_hale/sniper_head");
	PrepareMaterial("materials/models/player/saxton_hale/sniper_head_red");
	
	PrecacheSound(CBS0, true);
	PrecacheSound(CBS1, true);
	PrecacheSound(CBS3, true);
	PrecacheSound(CBSJump1, true);
	PrepareSound(CBSTheme);
	
	for( int i=1; i <= 25; i++ ) {
		char s[PLATFORM_MAX_PATH];
		if( i <= 9 ) {
			Format(s, PLATFORM_MAX_PATH, "%s%i.wav", CBS2, i);
			PrecacheSound(s, true);
		}
		Format(s, PLATFORM_MAX_PATH, "%s%i.wav", CBS4, i);
		PrecacheSound(s, true);
	}
	PrecacheSound("vo/sniper_dominationspy04.wav", true);
}

public void AddCBSToMenu(Menu& menu)
{
	char bossid[5]; IntToString(VSH2Boss_CBS, bossid, sizeof(bossid));
	menu.AddItem(bossid, "Christian Brutal Sniper");
}