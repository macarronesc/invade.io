extends ScrollPage

## Retos: recompensa diaria con su racha, desafío del día y las tres misiones diarias.
## Nada aparece por sorpresa: todo lo pendiente se recoge aquí y se avisa con un punto en la barra.

var _day := -1
## Icono de cada regla de continente: el mismo que la insignia de las bases que la protagonizan
const RULE_ICONS := {"rule_europe": "star", "rule_africa": "star", "rule_north_america": "bolt",
	"rule_asia": "shield", "rule_south_america": "speed", "rule_oceania": "globe"}

func _ready() -> void:
	super()
	# Si la pantalla sigue abierta a medianoche, los retos se renuevan solos
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(func():
		if DailyRewards.today() > _day:
			rebuild())
	add_child(timer)

func _build() -> void:
	GameManager.ensure_missions()
	_day = int(GameManager.missions["day"])
	UIThemeHelper.section(content, LocaleStrings.text("tab_challenges"), LocaleStrings.text("challenges_sub"))
	_build_reward()
	_build_daily_challenge()
	UIThemeHelper.section(content, LocaleStrings.text("missions"), LocaleStrings.text("mission_reset"), "Heading")
	for mission in GameManager.mission_definitions(_day):
		_build_mission(mission)

## Recompensa diaria: los 7 días del ciclo de racha, con el de hoy resaltado
func _build_reward() -> void:
	var state := GameManager.get_daily_reward_state()
	var can_claim: bool = state["can_claim"]
	var streak: int = state["streak"] if can_claim else int(GameManager.daily["streak"])
	var card := UIThemeHelper.card(content)
	card.add_child(UIThemeHelper.item_row(Icons.rect("gift", 64, UIThemeHelper.colors.gold), LocaleStrings.text("daily_title"),
		LocaleStrings.text("daily_ready" if can_claim else "daily_wait") % streak))
	var days := UIThemeHelper.hbox(8)
	var today := posmod(streak - 1, DailyRewards.STREAK_REWARDS.size())
	for i in DailyRewards.STREAK_REWARDS.size():
		var col := UIThemeHelper.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(0, 14)
		var reached := i < today or (i == today and not can_claim)
		var color: Color = UIThemeHelper.colors.gold if reached else (UIThemeHelper.colors.text if i == today else UIThemeHelper.colors.surface_2)
		dot.add_theme_stylebox_override("panel", UIThemeHelper.box(color, 999, 0))
		col.add_child(dot)
		var amount := UIThemeHelper.label("+%d" % DailyRewards.STREAK_REWARDS[i], "Caption", UIThemeHelper.colors.text if i == today else UIThemeHelper.colors.muted)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(amount)
		days.add_child(col)
	card.add_child(days)
	if can_claim:
		var claim := UIThemeHelper.button(LocaleStrings.text("daily_claim") % state["reward"], "GoldButton", "coin")
		claim.name = "BtnClaimDaily"
		# Cobrar emite coins_updated y la sección se redibuja sola
		claim.pressed.connect(func():
			if GameManager.claim_daily_reward() > 0:
				AudioManager.play_star_reveal(2)
				GameManager.haptic(30))
		card.add_child(claim)

func _build_daily_challenge() -> void:
	var day := DailyRewards.today()
	var id := DailyRewards.challenge_id(day)
	var data := LevelDatabase.get_level_data(id)
	var done := GameManager.is_daily_challenge_done(day)
	var card := UIThemeHelper.card(content)
	card.add_child(UIThemeHelper.item_row(Icons.rect("check" if done else "target", 64, UIThemeHelper.colors.success if done else UIThemeHelper.colors.gold),
		LocaleStrings.text("daily"), data["name"]))
	var best := GameManager.daily_best
	var has_best := not best.is_empty() and int(best["day"]) == day and int(best.get("balance_version", 0)) == DailyRewards.BALANCE_VERSION
	var status := LocaleStrings.text("daily_row") % DailyRewards.DAILY_CHALLENGE_GOLD
	if has_best:
		status = LocaleStrings.text("daily_best") % ["★".repeat(int(best["stars"])), ceili(float(best["time"]))]
	card.add_child(UIThemeHelper.label(status, "", UIThemeHelper.colors.success if done else UIThemeHelper.colors.text))
	if not best.is_empty() and int(best["day"]) == day and not has_best:
		card.add_child(UIThemeHelper.paragraph(LocaleStrings.text("daily_legacy_best") % ceili(float(best["time"]))))
	# Cada día rota una regla de continente: se anuncia antes de jugar, en etiquetas breves
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 12)
	tags.add_theme_constant_override("v_separation", 12)
	var twist := CampaignRules.description(data).strip_edges().split("\n", false)
	for i in twist.size():
		tags.add_child(UIThemeHelper.chip(twist[i], RULE_ICONS.get(data.get("rule_key", ""), "") if i == 0 else "", UIThemeHelper.colors.gold))
	if data.has("objective"):
		tags.add_child(UIThemeHelper.chip(LocaleStrings.text(data["objective"]) % int(data["hold_seconds"]), "target", UIThemeHelper.colors.success))
	tags.add_child(UIThemeHelper.chip(LocaleStrings.text("daily_normalized"), "", UIThemeHelper.colors.muted))
	card.add_child(tags)
	var actions := UIThemeHelper.hbox(16)
	var play := UIThemeHelper.button(LocaleStrings.text("replay" if done else "play"), "PrimaryButton", "retry" if done else "play")
	play.name = "BtnPlayDaily"
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(UIThemeHelper.start_battle.bind(self, id))
	actions.add_child(play)
	if has_best:
		var share := UIThemeHelper.button(LocaleStrings.text("share"), "", "share")
		share.pressed.connect(func():
			DisplayServer.clipboard_set(DailyShare.text(best))
			Toasts.show_toast("✅", "invade.io", LocaleStrings.text("copied")))
		actions.add_child(share)
	card.add_child(actions)

func _build_mission(mission: Dictionary) -> void:
	var progress := int(GameManager.missions["progress"].get(mission["id"], 0))
	var goal := int(mission["goal"])
	var claimed: bool = GameManager.missions["claimed"].has(mission["id"])
	var card := UIThemeHelper.card(content, "", 16)
	var top := UIThemeHelper.hbox(16)
	top.add_child(UIThemeHelper.paragraph(LocaleStrings.text(mission["key"]) % goal, ""))
	top.add_child(UIThemeHelper.chip("+%d · +%d XP" % [mission["gold"], mission["xp"]], "coin"))
	card.add_child(top)
	var bar_row := UIThemeHelper.hbox(16)
	bar_row.add_child(UIThemeHelper.progress(progress, goal, "GoldBar" if progress >= goal else ""))
	bar_row.add_child(UIThemeHelper.label("%d/%d" % [progress, goal], "Caption"))
	card.add_child(bar_row)
	if claimed:
		var done := UIThemeHelper.hbox(10)
		done.add_child(Icons.rect("check", 36, UIThemeHelper.colors.success))
		done.add_child(UIThemeHelper.label(LocaleStrings.text("mission_claimed"), "Caption", UIThemeHelper.colors.success))
		card.add_child(done)
	elif progress >= goal:
		var claim := UIThemeHelper.button(LocaleStrings.text("mission_claim"), "GoldButton", "coin")
		claim.name = "Claim_" + mission["id"]
		claim.pressed.connect(func():
			if GameManager.claim_mission(mission["id"]):
				AudioManager.play_star_reveal(1))
		card.add_child(claim)
