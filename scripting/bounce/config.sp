#define FILEPATH_CONFIG_PROJECTILES "configs/bounce/projectiles.cfg"
#define FILEPATH_CONFIG_WEAPONS "configs/bounce/weapons.cfg"

char g_sClassName[][] = {
	"",
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer",
};

static StringMap g_mWeaponsWhitelist;
static int g_iWeaponsDefaultIndex[sizeof(g_sClassName)][view_as<int>(WeaponSlot_BuilderEngie)+1];

static StringMap g_mProjectilesTouch;
static StringMap g_mProjectilesVPhysicsCollision;
static StringMap g_mProjectilesFlyCollisionCustom;
static StringMap g_mProjectilesPipebombTouch;
static StringMap g_mProjectilesExplodesOnHit;
static StringMap g_mProjectilesLifetime;

void Config_Init()
{
	g_mWeaponsWhitelist = new StringMap();
	
	g_mProjectilesTouch = new StringMap();
	g_mProjectilesVPhysicsCollision = new StringMap();
	g_mProjectilesFlyCollisionCustom = new StringMap();
	g_mProjectilesPipebombTouch = new StringMap();
	g_mProjectilesExplodesOnHit = new StringMap();
	g_mProjectilesLifetime = new StringMap();
}

void Config_Refresh()
{
	KeyValues kv = Config_Load(FILEPATH_CONFIG_WEAPONS, "Weapons");
	if (kv)
	{
		Config_LoadStringMapList(kv, "Whitelist", g_mWeaponsWhitelist);
		
		if (kv.JumpToKey("Default"))
		{
			for (int iClass = 1; iClass < sizeof(g_sClassName); iClass++)
			{
				for (int i = 0; i < sizeof(g_iWeaponsDefaultIndex[]); i++)
					g_iWeaponsDefaultIndex[iClass][i] = -1;
				
				if (kv.JumpToKey(g_sClassName[iClass]))
				{
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_Primary] = kv.GetNum("primary", -1);
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_Secondary] = kv.GetNum("secondary", -1);
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_Melee] = kv.GetNum("melee", -1);
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_PDABuild] = kv.GetNum("pda1", -1);
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_PDADestroy] = kv.GetNum("pda2", -1);
					g_iWeaponsDefaultIndex[iClass][WeaponSlot_BuilderEngie] = kv.GetNum("builder", -1);
					kv.GoBack();
				}
			}
			
			kv.GoBack();
		}
		
		delete kv;
	}
	
	kv = Config_Load(FILEPATH_CONFIG_PROJECTILES, "Projectiles");
	if (kv)
	{
		Config_LoadStringMapList(kv, "Touch", g_mProjectilesTouch);
		Config_LoadStringMapList(kv, "VPhysicsCollision", g_mProjectilesVPhysicsCollision);
		Config_LoadStringMapList(kv, "FlyCollisionCustom", g_mProjectilesFlyCollisionCustom);
		Config_LoadStringMapList(kv, "PipebombTouch", g_mProjectilesPipebombTouch);
		Config_LoadStringMapList(kv, "ExplodesOnHit", g_mProjectilesExplodesOnHit);
		
		if (kv.JumpToKey("Lifetime"))
		{
			g_mProjectilesLifetime.Clear();
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sBuffer[256];
					kv.GetSectionName(sBuffer, sizeof(sBuffer));
					g_mProjectilesLifetime.SetValue(sBuffer, kv.GetFloat(NULL_STRING));
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			
			kv.GoBack();
		}
		
		delete kv;
	}
}

KeyValues Config_Load(const char[] sFilepath, const char[] sName)
{
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), sFilepath);
	if (!FileExists(sConfigPath))
	{
		LogError("Failed to load %s config file (file missing): %s", sName, sConfigPath);
		return null;
	}
	
	KeyValues kv = new KeyValues(sName);
	kv.SetEscapeSequences(true);
	
	if (!kv.ImportFromFile(sConfigPath))
	{
		LogError("Failed to parse %s config file: %s", sName, sConfigPath);
		delete kv;
		return null;
	}
	
	return kv;
}

bool Config_LoadStringMapList(KeyValues kv, const char[] sSection, StringMap mList)
{
	if (!kv.JumpToKey(sSection))
		return false;
	
	mList.Clear();
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sBuffer[256];
			kv.GetString(NULL_STRING, sBuffer, sizeof(sBuffer));
			
			mList.SetValue(sBuffer, 1);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	
	kv.GoBack();
	return true;
}

bool Config_IsClassnameInWhitelist(const char[] sClassname)
{
	int iBuffer;
	return g_mWeaponsWhitelist.GetValue(sClassname, iBuffer);
}

int Config_GetDefaultIndex(TFClassType nClass, int iSlot)
{
	return g_iWeaponsDefaultIndex[nClass][iSlot];
}

bool Config_IsClassnameForTouch(const char[] sClassname)
{
	int iBuffer;
	return g_mProjectilesTouch.GetValue(sClassname, iBuffer);
}

bool Config_IsClassnameForVPhysicsCollision(const char[] sClassname)
{
	int iBuffer;
	return g_mProjectilesVPhysicsCollision.GetValue(sClassname, iBuffer);
}

bool Config_IsClassnameForFlyCollisionCustom(const char[] sClassname)
{
	int iBuffer;
	return g_mProjectilesFlyCollisionCustom.GetValue(sClassname, iBuffer);
}

bool Config_IsClassnameForPipebombTouch(const char[] sClassname)
{
	int iBuffer;
	return g_mProjectilesPipebombTouch.GetValue(sClassname, iBuffer);
}

bool Config_IsClassnameForExplodesOnHit(const char[] sClassname)
{
	int iBuffer;
	return g_mProjectilesExplodesOnHit.GetValue(sClassname, iBuffer);
}

float Config_GetProjectilesLifetime(const char[] sClassname)
{
	float flLifetime;
	g_mProjectilesLifetime.GetValue(sClassname, flLifetime);
	return flLifetime;
}