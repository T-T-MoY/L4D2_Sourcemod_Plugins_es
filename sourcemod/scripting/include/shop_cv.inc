// Shop shared constant variables v1.4-ES - Modificado para L4D2 Shop Español
#define STR stock char

/** SF cv start **/
// Eliminados AUTO_BHOP y QING_GONG, solo quedan Laser Tags
enum
{
	GRAY_AMMO
	, GREEN_AMMO
	, BLUE_AMMO
	, GOLD_AMMO
	, RED_AMMO
	, SF_SIZE
}

// Special functoins - Precios y Descripciones en Español
STR g_sSF[][][] =
{	// FunctionNo		Trial price		permanent price 	Description				
	{ "GRAY_AMMO",		"20",			"200",			"Láser Gris"}	// 0
	, { "GREEN_AMMO",	"30",			"300",			"Láser Verde"}	// 1
	, { "BLUE_AMMO",	"40",			"400",			"Láser Azul"}	// 2
	, { "GOLD_AMMO",	"60",			"600",			"Láser Dorado"}	// 3
	, { "RED_AMMO",		"99",			"999",			"Láser Rojo"}	// 4
};
/** SF cv end **/

/** Shop cv start **/
// SHOP_INDEX
enum
{
	SHOP_MAIN,
	SHOP_INFECTED,
	SHOP_GUNS,
	SHOP_SMGS,
	SHOP_RIFLES,
	SHOP_SNIPERS,
	SHOP_SHOTGUNS,
	SHOP_OTHERS,
	SHOP_MELEES,
	SHOP_THROWABLES,
	SHOP_AMMOS,
	SHOP_MEDICINES,
	SHOP_SF_TRIAL,
	SHOP_SF_PERMANENT,
	SHOP_SF,
	SHOP_SF_BAG,
	SHOP_TRANSFER,
	SHOP_SIZE,
};

// how to open the above shops by cmd
STR g_sShopCmds[SHOP_SIZE][64];

STR g_sShopNames[][] =
{
	"SHOP_MAIN",
	"SHOP_INFECTED",
	"SHOP_GUNS",
	"SHOP_SMGS",
	"SHOP_RIFLES",
	"SHOP_SNIPERS",
	"SHOP_SHOTGUNS",
	"SHOP_OTHERS",
	"SHOP_MELEES",
	"SHOP_THROWABLES",
	"SHOP_AMMOS",
	"SHOP_MEDICINES",
	"SHOP_SF_TRIAL",
	"SHOP_SF_PERMANENT",
	"SHOP_SF",
	"SHOP_SF_BAG",
	"SHOP_TRANSFER",
};

// Shop menu mapping
STR g_sMainShop[][] = {"SHOP_GUNS","SHOP_MELEES","SHOP_THROWABLES","SHOP_AMMOS","SHOP_MEDICINES","SHOP_SF","SHOP_TRANSFER"};
STR g_sGunsShop[][] = {"SHOP_SMGS","SHOP_RIFLES","SHOP_SNIPERS","SHOP_SHOTGUNS","SHOP_OTHERS",};
STR g_sSFShop[][] = {"SHOP_SF_TRIAL","SHOP_SF_PERMANENT", "SHOP_SF_BAG",};

// Shop items ------------------------------------>
// ** Si el precio es -1, el ítem se deshabilita **

STR g_sInfectedItems[][][] =
{	//item name								price 	Description (Español)
	{ "kill",								"4",	"Suicidarse (Respawn rápido)"}			// 0
	, { "health",							"10",	"Curación Completa"}					// 1
	, { "boomer",							"10",	"Convertirse en Boomer"}				// 2
	, { "hunter",							"5",	"Convertirse en Hunter"}				// 3
	, { "smoker",							"7",	"Convertirse en Smoker"}				// 4
	, { "spitter",							"7",	"Convertirse en Spitter"}				// 5
	, { "charger",							"7",	"Convertirse en Charger"}				// 6
	, { "jockey",							"7",	"Convertirse en Jockey"}				// 7
	, { "tank",								"50",	"Convertirse en Tank"}					// 8
	, { "witch",							"30",	"Invocar Witch"}						// 9
	, { "mob",								"18",	"Invocar Horda"}						// 10
	, { "director_force_panic_event",		"23",	"Evento de Pánico"}						// 11
};

STR g_sSmgs[][][] =
{	//item name								price 	Description
	{ "smg",								"13",	"Uzi"}									// 0
	, { "smg_silenced",						"13",	"Mac-10 Silenciada"}					// 1
	, { "smg_mp5",							"13",	"MP5"}									// 2
};

STR g_sRifles[][][] =
{	//item name								price	Description
	{ "rifle",								"30",	"M16"}									// 0
	, { "rifle_desert",						"30",	"SCAR (Ráfagas)"}						// 1
	, { "rifle_ak47",						"30",	"AK-47"}								// 2
	, { "rifle_sg552",						"30",	"SG552 (Mira)"}							// 3
	, { "rifle_m60",						"160",	"M60 (Ametralladora)"}					// 4
};

STR g_sSnipers[][][] =
{	//item name								price	Description
	{ "hunting_rifle",						"25",	"Rifle de Caza"}						// 0
	, { "sniper_military",					"25",	"Francotirador Militar"}				// 1
	, { "sniper_awp",						"50",	"AWP (Potente)"}						// 2
	, { "sniper_scout",						"40",	"Scout (Rápido)"}						// 3
};

STR g_sShotguns[][][] =
{	//item name								price	Description
	{ "pumpshotgun",						"13",	"Escopeta Corredera"}					// 0
	, { "shotgun_chrome",					"13",	"Escopeta Cromada"}						// 1
	, { "autoshotgun",						"30",	"Escopeta Automática (M1014)"}			// 2
	, { "shotgun_spas",						"30",	"Escopeta SPAS"}						// 3
};

STR g_sOthers[][][] =
{	//item name								price	Description
	{ "pistol",								"5",	"Pistola (M1911)"}						// 0
	, { "pistol_magnum",					"13",	"Magnum (Desert Eagle)"}				// 1
	, { "grenade_launcher",					"38",	"Lanzagranadas"}						// 2
	, { "extinguisher",						"40",	"Extintor Táctico"}						// 3
};


STR g_sShopMelees[][][] =
{	//item name								price	Description
	{ "katana",								"9",	"Katana"}								// 0
	, { "fireaxe",							"9",	"Hacha"}								// 1
	, { "machete",							"9",	"Machete"}								// 2
	, { "machete",							"9",	"Machete (Alternativo)"}				// 3
	, { "flamethrower",						"-1",	"Lanzallamas (Desactivado)"}			// 4
	, { "knife",							"5",	"Cuchillo"}								// 5
	, { "chainsaw",							"16",	"Motosierra"}							// 6
	, { "pitchfork",						"9",	"Horca"}								// 7
	, { "shovel",							"9",	"Pala"}									// 8
	, { "golfclub",							"9",	"Palo de Golf"}							// 9
	, { "electric_guitar",					"9",	"Guitarra Eléctrica"}					// 10
	, { "tonfa",							"9",	"Tonfa Policial"}						// 11
	, { "baseball_bat",						"9",	"Bate de Béisbol"}						// 12
	, { "cricket_bat",						"9",	"Bate de Cricket"}						// 13
	, { "frying_pan",						"9",	"Sartén"}								// 14
	, { "crowbar",							"9",	"Palanca"}								// 15
};

STR g_sThrowables[][][] =
{	//item name								price	Description
	{ "pipe_bomb",							"28",	"Bomba Casera (Pipe)"}					// 0
	, { "molotov",							"28",	"Molotov"}								// 1
	, { "vomitjar",							"28",	"Bilis de Boomer"}						// 2
	, { "gascan",							"18",	"Bidón de Gasolina"}					// 3
	, { "propanetank",						"18",	"Tanque de Propano"}					// 4
	, { "fireworkcrate",					"18",	"Caja de Fuegos Artificiales"}			// 5
	, { "oxygentank",						"18",	"Tanque de Oxígeno"}					// 6
	, { "cola_bottles",						"68",	"Pack de Coca-Cola"}					// 7
	, { "gnome",							"68",	"Gnomo de Jardín"}						// 8
};

STR g_sAmmos[][][] =
{	//item name								price	Description
	{ "laser_sight",						"10",	"Mejora: Mira Láser"}					// 0
	, { "ammo",								"12",	"Rellenar Munición"}					// 1
	, { "incendiary_ammo",					"12",	"Cargador Incendiario"}					// 2
	, { "explosive_ammo",					"12",	"Cargador Explosivo"}					// 3
	, { "upgradepack_incendiary",			"18",	"Pack Munición Incendiaria"}			// 4
	, { "upgradepack_explosive",			"18",	"Pack Munición Explosiva"}				// 5
	, { "lethal_ammo_3",					"60",	"Munición Letal (3 Balas)"}				// 6
};

STR g_sMedicines[][][] =
{	//item name								price	Description
	{ "first_aid_kit",						"88",	"Botiquín"}								// 0
	, { "adrenaline",						"43",	"Adrenalina"}							// 1
	, { "pain_pills",						"43",	"Píldoras"}								// 2
	, { "defibrillator",					"50",	"Desfibrilador"}						// 3
	, { "health",							"98",	"Curación Completa (Instant)"}			// 4
	, { "revive_self",						"50",	"Revivirse (Costo Progresivo)"}			// 5 - NUEVO ITEM
};

// <------------------------------------ Shop items

// Shortcut variables
STR g_sShortcutItemCmds[][][]=
{
	// full form				//shortcut
	{"pistol",					"gun"},
	{"pistol_magnum",			"eagle"},
	{"pistol_magnum",			"magnum"},
	{"smg_silenced",			"slient"},
	{"smg_silenced",			"silenced"},
	{"smg_mp5",					"mp5"},
	{"rifle_ak47",				"ak"},
	{"rifle_ak47",				"ak47"},
	{"rifle",					"m16"},
	{"rifle_desert",			"desert"},
	{"rifle_desert",			"scar"},
	{"rifle_sg552",				"sg552"},
	{"rifle_m60",				"m60"},
	{"autoshotgun",				"auto"},
	{"shotgun_spas",			"spas"},
	{"pumpshotgun",				"pump"},
	{"shotgun_chrome",			"chrome"},
	{"hunting_rifle",			"hunt"},
	{"hunting_rifle",			"hunting"},
	{"hunting_rifle",			"hrifle"},
	{"sniper_military",			"mili"},
	{"sniper_military",			"military"},
	{"sniper_military",			"sniper"},
	{"sniper_awp",				"awp"},
	{"sniper_scout",			"scout"},
	{"grenade_launcher",		"grenade"},
	{"grenade_launcher",		"launcher"},
	{"grenade_launcher",		"nuke"},
	{"katana",					"kat"},
	{"fireaxe",					"axe"},
	{"machete",					"mac"},
	{"knife",					"cs"},
	{"chainsaw",				"saw"},
	{"pitchfork",				"fork"},
	{"golfclub",				"golf"},
	{"golfclub",				"club"},
	{"tonfa",					"police"},
	{"tonfa",					"nightstick"},
	{"tonfa",					"stick"},
	{"baseball_bat",			"bat"},
	{"baseball_bat",			"baseball"},
	{"cricket_bat",				"cricket"},
	{"cricket_bat",				"ket"},
	{"frying_pan",				"frying"},
	{"frying_pan",				"pan"},
	{"crowbar",					"crow"},
	{"crowbar",					"bar"},
	{"electric_guitar",			"guitar"},
	{"pipe_bomb",				"pipe"},
	{"pipe_bomb",				"bomb"},
	{"molotov",					"molo"},
	{"molotov",					"moly"},
	{"molotov",					"molly"},
	{"vomitjar",				"jar"},
	{"vomitjar",				"bile"},
	{"upgradepack_incendiary",	"packfire"},
	{"upgradepack_explosive",	"packexp"},
	{"laser_sight",				"laser"},
	{"incendiary_ammo",			"fireammo"},
	{"explosive_ammo",			"expammo"},
	{"explosive_ammo",			"exp"},
	{"ammo",					"a"},
	{"first_aid_kit",			"first"},
	{"first_aid_kit",			"aid"},
	{"first_aid_kit",			"kit"},
	{"first_aid_kit",			"healthpack"},
	{"first_aid_kit",			"medkit"},
	{"adrenaline",				"adren"},
	{"pain_pills",				"pill"},
	{"pain_pills",				"pills"},
	{"defibrillator",			"defib"},
	{"health",					"heal"},
	{"health",					"full"},
	{"health",					"fheal"},
	{"gascan",					"gas"},
	{"propanetank",				"propane"},
	{"fireworkcrate",			"firework"},
	{"oxygentank",				"oxygen"},
	{"extinguisher",			"extinguisher"},
	{"extinguisher",			"ext"},
	{"extinguisher",			"flamethrower"},
	{"extinguisher",			"flamer"},
	{"extinguisher",			"fire"},
	// Added Revive shortcut
	{"revive_self",				"revive"},
	{"revive_self",				"respawn"},
};
/** Shop cv end **/