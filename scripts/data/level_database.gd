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
				{"id": "b2", "name": "Belgrado", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b3", "name": "Viena", "pos": Vector2(300, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b4", "name": "Bucarest", "pos": Vector2(780, 650), "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2},
				{"id": "b5", "name": "Estambul", "pos": Vector2(850, 1350), "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},
		"europe_5": {
			"id": "europe_5",
			"name": "Nivel 5: Capital Continental",
			"continent": "europe",
			"description": "La gran batalla por el control absoluto de Europa.",
			"target_time": 75,
			"bases": [
				{"id": "b1", "name": "Base Occidental", "pos": Vector2(250, 1500), "faction": GameManager.Faction.PLAYER, "troops": 40, "tier": 3},
				{"id": "b2", "name": "Fortaleza Central", "pos": Vector2(540, 1000), "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3},
				{"id": "b3", "name": "Puesto Norte", "pos": Vector2(540, 500), "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
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
				{"id": "b3", "name": "Chicago", "pos": Vector2(750, 650), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
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
			"bases": [
				{"id": "b1", "name": "Base Aliada", "pos": Vector2(250, 1550), "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "name": "Polo Central", "pos": Vector2(540, 1050), "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 3},
				{"id": "b3", "name": "Polo Este", "pos": Vector2(850, 1100), "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b4", "name": "Polo Norte", "pos": Vector2(540, 500), "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 2},
				{"id": "b5", "name": "Polo Noroeste", "pos": Vector2(250, 550), "faction": GameManager.Faction.ENEMY_3, "troops": 35, "tier": 2}
			]
		},

		# ===================== ASIA, SUDAMÉRICA, ÁFRICA, OCEANÍA =====================
		# Plantillas para los primeros niveles de los demás continentes
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
		}
	}
