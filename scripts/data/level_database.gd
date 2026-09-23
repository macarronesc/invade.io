extends RefCounted
class_name LevelDatabase

## Base de datos con los niveles de campaña organizados por continentes

static func get_continents() -> Array[Dictionary]:
	return [
		{"id": "europe", "name": "Europa", "color": Color(0.2, 0.6, 0.86), "total_levels": 5},
		{"id": "north_america", "name": "América del Norte", "color": Color(0.9, 0.4, 0.3), "total_levels": 5},
		{"id": "south_america", "name": "América del Sur", "color": Color(0.3, 0.75, 0.4), "total_levels": 5},
		{"id": "africa", "name": "África", "color": Color(0.95, 0.7, 0.2), "total_levels": 5},
		{"id": "asia", "name": "Asia", "color": Color(0.8, 0.3, 0.7), "total_levels": 5},
		{"id": "oceania", "name": "Oceanía", "color": Color(0.1, 0.7, 0.7), "total_levels": 5}
	]

static func get_level_data(level_id: String) -> Dictionary:
	var all_levels = get_all_levels()
	if all_levels.has(level_id):
		return all_levels[level_id]
	# Fallback a europe_1 si no existe
	return all_levels.get("europe_1", {})

static func get_all_levels() -> Dictionary:
	return {
		# ===================== EUROPA =====================
		"europe_1": {
			"id": "europe_1",
			"name": "Nivel 1: Península Ibérica y Galia",
			"continent": "europe",
			"description": "Aprende los conceptos básicos: captura las bases neutrales y vence al enemigo rojo.",
			"target_time": 40,
			"bases": [
				{"id": "b1", "name": "Madrid", "pos": Vector2(320, 1400), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "París", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 10, "tier": 2},
				{"id": "b3", "name": "Londres", "pos": Vector2(360, 600), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b4", "name": "Berlín", "pos": Vector2(760, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 25, "tier": 2}
			]
		},
		"europe_2": {
			"id": "europe_2",
			"name": "Nivel 2: Europa Central",
			"continent": "europe",
			"description": "Una red más densa de bases neutrales separa tu avance de Berlín y Roma.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Lisboa", "pos": Vector2(250, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 1},
				{"id": "b2", "name": "Marsella", "pos": Vector2(450, 1150), "faction": GameManager.Faction.NEUTRAL, "troops": 12, "tier": 1},
				{"id": "b3", "name": "Roma", "pos": Vector2(650, 1250), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 2},
				{"id": "b4", "name": "Praga", "pos": Vector2(540, 750), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b5", "name": "Varsovia", "pos": Vector2(800, 500), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2}
			]
		},
		"europe_3": {
			"id": "europe_3",
			"name": "Nivel 3: Países Nórdicos",
			"continent": "europe",
			"description": "Bases costeras con conexiones estratégicas.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "name": "Ámsterdam", "pos": Vector2(300, 1300), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "Copenhague", "pos": Vector2(540, 950), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "Oslo", "pos": Vector2(400, 550), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "name": "Estocolmo", "pos": Vector2(700, 500), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b5", "name": "Helsinki", "pos": Vector2(850, 750), "faction": GameManager.Faction.ENEMY_1, "troops": 20, "tier": 1}
			]
		},
		"europe_4": {
			"id": "europe_4",
			"name": "Nivel 4: Balcanes y Mediterráneo",
			"continent": "europe",
			"description": "Dos frentes hostiles: Facciones Roja y Amarilla te rodean.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "name": "Atenas", "pos": Vector2(540, 1500), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Belgrado", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2, "type": "fortress"},
				{"id": "b3", "name": "Viena", "pos": Vector2(300, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b4", "name": "Bucarest", "pos": Vector2(780, 650), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2},
				{"id": "b5", "name": "Estambul", "pos": Vector2(850, 1350), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1, "type": "factory"}
			]
		},
		"europe_5": {
			"id": "europe_5",
			"name": "Nivel 5: Capital Continental",
			"continent": "europe",
			"description": "La gran batalla por el control absoluto de Europa.",
			"target_time": 75,
			"ai_archetypes": {
				GameManager.Faction.ENEMY_1: "aggressive",
				GameManager.Faction.ENEMY_2: "expansive"
			},
			"bases": [
				{"id": "b1", "name": "Base Occidental", "pos": Vector2(250, 1500), "faction": GameManager.Faction.PLAYER, "troops": 40, "tier": 3},
				{"id": "b2", "name": "Fortaleza Central", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "name": "Puesto Norte", "pos": Vector2(540, 500), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "factory"},
				{"id": "b4", "name": "Imperio Rojo", "pos": Vector2(850, 450), "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "name": "Imperio Ámbar", "pos": Vector2(850, 1500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "name": "Puesto Sur", "pos": Vector2(250, 750), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},

		# ===================== AMÉRICA DEL NORTE =====================
		"north_america_1": {
			"id": "north_america_1",
			"name": "Nivel 1: Costa Este",
			"continent": "north_america",
			"description": "Inicia la campaña americana asegurando Nueva York y Boston.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Miami", "pos": Vector2(350, 1500), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "Atlanta", "pos": Vector2(540, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 2},
				{"id": "b3", "name": "Nueva York", "pos": Vector2(700, 600), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"north_america_2": {
			"id": "north_america_2",
			"name": "Nivel 2: Grandes Llanuras",
			"continent": "north_america",
			"description": "Territorios amplios donde la velocidad de marcha es vital.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "name": "Dallas", "pos": Vector2(300, 1400), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Kansas", "pos": Vector2(540, 950), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 2},
				{"id": "b3", "name": "Chicago", "pos": Vector2(750, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "factory"},
				{"id": "b4", "name": "Denver", "pos": Vector2(280, 700), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},
		"north_america_3": {
			"id": "north_america_3",
			"name": "Nivel 3: Costa Oeste",
			"continent": "north_america",
			"description": "Batalla a tres facciones entre California y el Pacífico.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "name": "San Diego", "pos": Vector2(250, 1500), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Los Ángeles", "pos": Vector2(300, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "name": "San Francisco", "pos": Vector2(540, 800), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "name": "Seattle", "pos": Vector2(800, 450), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Las Vegas", "pos": Vector2(750, 1300), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 1}
			]
		},
		"north_america_4": {
			"id": "north_america_4",
			"name": "Nivel 4: Gran Norte (Canadá)",
			"continent": "north_america",
			"description": "Grandes distancias y bases de alto nivel.",
			"target_time": 70,
			"bases": [
				{"id": "b1", "name": "Toronto", "pos": Vector2(320, 1400), "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "name": "Montreal", "pos": Vector2(540, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "name": "Calgary", "pos": Vector2(400, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b4", "name": "Vancouver", "pos": Vector2(780, 550), "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"north_america_5": {
			"id": "north_america_5",
			"name": "Nivel 5: Megalópolis Continental",
			"continent": "north_america",
			"description": "Conquista final de Norteamérica frente a tres ejércitos simultáneos.",
			"target_time": 80,
			"ai_archetypes": {
				GameManager.Faction.ENEMY_1: "aggressive",
				GameManager.Faction.ENEMY_2: "expansive",
				GameManager.Faction.ENEMY_3: "opportunist"
			},
			"bases": [
				{"id": "b1", "name": "Base Aliada", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Polo Central", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 3, "type": "fortress"},
				{"id": "b3", "name": "Polo Este", "pos": Vector2(850, 1100), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "factory"},
				{"id": "b4", "name": "Polo Norte", "pos": Vector2(540, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 2},
				{"id": "b5", "name": "Polo Noroeste", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_3, "troops": 35, "tier": 2}
			]
		},

		# ===================== SUDAMÉRICA =====================
		"south_america_1": {
			"id": "south_america_1",
			"name": "Nivel 1: Cono Sur",
			"continent": "south_america",
			"description": "Incursión en Sudamérica comenzando en Buenos Aires y Santiago.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "name": "Buenos Aires", "pos": Vector2(350, 1450), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "Santiago", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "São Paulo", "pos": Vector2(720, 600), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"south_america_2": {
			"id": "south_america_2",
			"name": "Nivel 2: Cordillera de los Andes",
			"continent": "south_america",
			"description": "Avance montañoso a través de bases estratégicas de altura.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Santiago", "pos": Vector2(300, 1500), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "La Paz", "pos": Vector2(380, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 2, "type": "fortress"},
				{"id": "b3", "name": "Lima", "pos": Vector2(320, 750), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "name": "Bogotá", "pos": Vector2(550, 480), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Quito", "pos": Vector2(750, 850), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},
		"south_america_3": {
			"id": "south_america_3",
			"name": "Nivel 3: Cuenca del Amazonas",
			"continent": "south_america",
			"description": "Dos frentes rivales convergen hacia el control del gran río.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "name": "Brasilia", "pos": Vector2(300, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Belém", "pos": Vector2(750, 1300), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "Manaos", "pos": Vector2(540, 950), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "name": "Caracas", "pos": Vector2(350, 500), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Georgetown", "pos": Vector2(750, 550), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2}
			]
		},
		"south_america_4": {
			"id": "south_america_4",
			"name": "Nivel 4: Frentes Cruzados",
			"continent": "south_america",
			"description": "Batalla intensa a tres ejércitos por la costa atlántica.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "name": "Montevideo", "pos": Vector2(280, 1520), "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "name": "Asunción", "pos": Vector2(540, 1200), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b3", "name": "Córdoba", "pos": Vector2(300, 880), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b4", "name": "Salvador", "pos": Vector2(780, 950), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Fortaleza", "pos": Vector2(780, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"south_america_5": {
			"id": "south_america_5",
			"name": "Nivel 5: Dominio Continental",
			"continent": "south_america",
			"description": "Gran batalla final por el control de toda América del Sur frente a 3 facciones.",
			"target_time": 80,
			"bases": [
				{"id": "b1", "name": "Buenos Aires", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Altiplano Central", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "name": "Guayana", "pos": Vector2(540, 550), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "name": "Imperio de Río", "pos": Vector2(850, 1400), "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3, "type": "factory"},
				{"id": "b5", "name": "Fortaleza Bogotá", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "name": "Imperio Pacífico", "pos": Vector2(850, 600), "faction": GameManager.Faction.ENEMY_3, "troops": 35, "tier": 2}
			]
		},

		# ===================== ÁFRICA =====================
		"africa_1": {
			"id": "africa_1",
			"name": "Nivel 1: Delta del Nilo",
			"continent": "africa",
			"description": "Desierto del Sáhara y el valle del Nilo.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "name": "Alejandría", "pos": Vector2(350, 1450), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "El Cairo", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "Asuán", "pos": Vector2(720, 600), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"africa_2": {
			"id": "africa_2",
			"name": "Nivel 2: Magreb y Desierto",
			"continent": "africa",
			"description": "Bases costeras del norte de África y pasos caravaneros.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Marrakech", "pos": Vector2(300, 1480), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "Fez", "pos": Vector2(540, 1200), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "Argel", "pos": Vector2(350, 850), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "name": "Trípoli", "pos": Vector2(750, 700), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "fortress"},
				{"id": "b5", "name": "Túnez", "pos": Vector2(750, 1200), "faction": GameManager.Faction.NEUTRAL, "troops": 16, "tier": 1}
			]
		},
		"africa_3": {
			"id": "africa_3",
			"name": "Nivel 3: Golfo de Guinea",
			"continent": "africa",
			"description": "Alta densidad de bases y frentes convergentes en África Occidental.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "name": "Acra", "pos": Vector2(280, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Abiyán", "pos": Vector2(280, 950), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1},
				{"id": "b3", "name": "Lagos", "pos": Vector2(580, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "name": "Yaundé", "pos": Vector2(800, 1350), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Yamena", "pos": Vector2(700, 550), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2}
			]
		},
		"africa_4": {
			"id": "africa_4",
			"name": "Nivel 4: Valle del Rift y Cuerno",
			"continent": "africa",
			"description": "Lucha por los Grandes Lagos y el este del continente.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "name": "Mombasa", "pos": Vector2(350, 1500), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Nairobi", "pos": Vector2(540, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2, "type": "factory"},
				{"id": "b3", "name": "Kampala", "pos": Vector2(300, 750), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "name": "Adís Abeba", "pos": Vector2(750, 700), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Mogadiscio", "pos": Vector2(800, 1300), "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"africa_5": {
			"id": "africa_5",
			"name": "Nivel 5: Unión Panafricana",
			"continent": "africa",
			"description": "Asedio total a cuatro frentes desde el Cabo hasta el Mediterráneo.",
			"target_time": 85,
			"bases": [
				{"id": "b1", "name": "Ciudad del Cabo", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Cuenca del Congo", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "factory"},
				{"id": "b3", "name": "Oasis del Sáhara", "pos": Vector2(540, 550), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "fortress"},
				{"id": "b4", "name": "Imperio de El Cairo", "pos": Vector2(850, 480), "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "name": "Imperio de Lagos", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "name": "Reino Zulú", "pos": Vector2(850, 1500), "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		},

		# ===================== ASIA =====================
		"asia_1": {
			"id": "asia_1",
			"name": "Nivel 1: Ruta de la Seda",
			"continent": "asia",
			"description": "Un vasto continente con alta densidad militar.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Samarcanda", "pos": Vector2(320, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Pekín", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "name": "Tokio", "pos": Vector2(750, 600), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2}
			]
		},
		"asia_2": {
			"id": "asia_2",
			"name": "Nivel 2: Subcontinente Indio",
			"continent": "asia",
			"description": "Rápida expansión en una península populosa y disputada.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "name": "Bangalore", "pos": Vector2(350, 1500), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Bombay", "pos": Vector2(300, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "name": "Calcuta", "pos": Vector2(750, 1100), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2, "type": "factory"},
				{"id": "b4", "name": "Nueva Delhi", "pos": Vector2(540, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Karachi", "pos": Vector2(300, 600), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1}
			]
		},
		"asia_3": {
			"id": "asia_3",
			"name": "Nivel 3: Oriente Medio",
			"continent": "asia",
			"description": "Encrucijada petrolífera y fortalezas desérticas.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "name": "Mascate", "pos": Vector2(280, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Dubái", "pos": Vector2(540, 1200), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b3", "name": "Riad", "pos": Vector2(320, 850), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "name": "Bagdad", "pos": Vector2(540, 500), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Teherán", "pos": Vector2(800, 750), "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"asia_4": {
			"id": "asia_4",
			"name": "Nivel 4: Dragones de Asia",
			"continent": "asia",
			"description": "Guerra insular y costera de alta velocidad de marcha.",
			"target_time": 70,
			"bases": [
				{"id": "b1", "name": "Singapur", "pos": Vector2(300, 1520), "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "name": "Bangkok", "pos": Vector2(320, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b3", "name": "Yakarta", "pos": Vector2(750, 1450), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 1},
				{"id": "b4", "name": "Taipéi", "pos": Vector2(750, 900), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Seúl", "pos": Vector2(540, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 2}
			]
		},
		"asia_5": {
			"id": "asia_5",
			"name": "Nivel 5: Emperadores de Oriente",
			"continent": "asia",
			"description": "El mayor enfrentamiento táctico del planeta: megabases imperiales.",
			"target_time": 90,
			"ai_archetypes": {
				GameManager.Faction.ENEMY_1: "aggressive",
				GameManager.Faction.ENEMY_2: "expansive",
				GameManager.Faction.ENEMY_3: "opportunist"
			},
			"bases": [
				{"id": "b1", "name": "Base Oriental", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Bastión Central", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 35, "tier": 3, "type": "fortress"},
				{"id": "b3", "name": "Puesto Siberiano", "pos": Vector2(540, 500), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "name": "Imperio de Pekín", "pos": Vector2(850, 480), "faction": GameManager.Faction.ENEMY_1, "troops": 45, "tier": 3},
				{"id": "b5", "name": "Dinastía del Sur", "pos": Vector2(850, 1500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3, "type": "factory"},
				{"id": "b6", "name": "Shogunato de Tokio", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		},

		# ===================== OCEANÍA =====================
		"oceania_1": {
			"id": "oceania_1",
			"name": "Nivel 1: Arrecife de Coral",
			"continent": "oceania",
			"description": "Bases insulares en el Pacífico.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "name": "Sídney", "pos": Vector2(320, 1450), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Melbourne", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "name": "Auckland", "pos": Vector2(750, 600), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2}
			]
		},
		"oceania_2": {
			"id": "oceania_2",
			"name": "Nivel 2: Outback Australiano",
			"continent": "oceania",
			"description": "Inmensas extensiones desérticas donde cada movimiento cuenta.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "name": "Adelaida", "pos": Vector2(300, 1450), "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "name": "Alice Springs", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1, "type": "factory"},
				{"id": "b3", "name": "Darwin", "pos": Vector2(540, 550), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b4", "name": "Perth", "pos": Vector2(780, 1200), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2}
			]
		},
		"oceania_3": {
			"id": "oceania_3",
			"name": "Nivel 3: Polinesia y Mares del Sur",
			"continent": "oceania",
			"description": "Guerra de islas que requiere coordinación de múltiples orígenes.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "name": "Wellington", "pos": Vector2(300, 1480), "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "name": "Christchurch", "pos": Vector2(300, 980), "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1},
				{"id": "b3", "name": "Auckland", "pos": Vector2(700, 1300), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b4", "name": "Fiyi", "pos": Vector2(750, 750), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Samoa", "pos": Vector2(450, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 1}
			]
		},
		"oceania_4": {
			"id": "oceania_4",
			"name": "Nivel 4: Archipiélago Austral",
			"continent": "oceania",
			"description": "Doble frente agresivo en las grandes costas oceánicas.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "name": "Hobart", "pos": Vector2(300, 1500), "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "name": "Melbourne", "pos": Vector2(350, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b3", "name": "Camberra", "pos": Vector2(750, 1150), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "name": "Sídney", "pos": Vector2(780, 680), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "name": "Brisbane", "pos": Vector2(400, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"oceania_5": {
			"id": "oceania_5",
			"name": "Nivel 5: Soberanía del Pacífico",
			"continent": "oceania",
			"description": "La culminación de la campaña mundial: vence a tres imperios insulares.",
			"target_time": 85,
			"bases": [
				{"id": "b1", "name": "Base Austral", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Atolón Central", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "name": "Puesto de Coral", "pos": Vector2(540, 550), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "factory"},
				{"id": "b4", "name": "Imperio Auckland", "pos": Vector2(850, 1450), "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "name": "Flota del Norte", "pos": Vector2(850, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "name": "Reino Pacífico", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		}
	}
