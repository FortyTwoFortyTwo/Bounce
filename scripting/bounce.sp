#pragma semicolon 1

#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <tf_econ_data>

#pragma newdecls required

#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_VERSION_REVISION	"manual"

enum SolidType_t
{
    SOLID_NONE		= 0,    // no solid model
    SOLID_BSP		= 1,    // a BSP tree
    SOLID_BBOX		= 2,    // an AABB
    SOLID_OBB		= 3,    // an OBB (not implemented yet)
    SOLID_OBB_YAW	= 4,    // an OBB, constrained so that it can only yaw
    SOLID_CUSTOM	= 5,    // Always call into the entity for tests
    SOLID_VPHYSICS	= 6,    // solid vphysics object, get vcollide from the model and collide with that
    SOLID_LAST,
};

enum SolidFlags_t
{
    FSOLID_CUSTOMRAYTEST		= 0x0001,	// Ignore solid type + always call into the entity for ray tests
    FSOLID_CUSTOMBOXTEST		= 0x0002,	// Ignore solid type + always call into the entity for swept box tests
    FSOLID_NOT_SOLID			= 0x0004,	// Are we currently not solid?
    FSOLID_TRIGGER				= 0x0008,	// This is something may be collideable but fires touch functions
    										// even when it's not collideable (when the FSOLID_NOT_SOLID flag is set)
    FSOLID_NOT_STANDABLE		= 0x0010,	// You can't stand on this
    FSOLID_VOLUME_CONTENTS		= 0x0020,	// Contains volumetric contents (like water)
    FSOLID_FORCE_WORLD_ALIGNED	= 0x0040,	// Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
    FSOLID_USE_TRIGGER_BOUNDS	= 0x0080,	// Uses a special trigger bounds separate from the normal OBB
    FSOLID_ROOT_PARENT_ALIGNED	= 0x0100,	// Collisions are defined in root parent's local coordinate space
    FSOLID_TRIGGER_TOUCH_DEBRIS	= 0x0200,	// This trigger will touch debris objects
	
    FSOLID_MAX_BITS    = 10
};

enum
{
	WeaponSlot_Primary = 0,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADisguise = 3,
	WeaponSlot_PDADestroy,
	WeaponSlot_InvisWatch = 4,
	WeaponSlot_BuilderEngie,
	WeaponSlot_Unknown1,
	WeaponSlot_Head,
	WeaponSlot_Misc1,
	WeaponSlot_Action,
	WeaponSlot_Misc2
};

ArrayList g_aExpiredLifetime;

#include "bounce/config.sp"
#include "bounce/dhook.sp"
#include "bounce/sdkcall.sp"
#include "bounce/sdkhook.sp"

public Plugin myinfo =
{
	name = "Bounce",
	author = "42",
	description = "Bouncy Projectiles",
	version = PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
	url = "https://github.com/FortyTwoFortyTwo/Bounce",
};

public void OnPluginStart()
{
	GameData hGameData = new GameData("bounce");
	if (!hGameData)
		SetFailState("Could not find bounce gamedata");
	
	DHook_Init(hGameData);
	SDKCall_Init(hGameData);
	
	delete hGameData;
	
	Config_Init();
	Config_Refresh();
	
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	
	g_aExpiredLifetime = new ArrayList();
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	DHook_OnEntityCreated(iEntity, sClassname);
	SDKHook_OnEntityCreated(iEntity, sClassname);
	
	float flLifetime = Config_GetProjectilesLifetime(sClassname);
	if (flLifetime > 0.0)
		CreateTimer(flLifetime, Timer_ExpiredLifetime, EntIndexToEntRef(iEntity));
}

public void OnEntityDestroyed(int iEntity)
{
	int iIndex = g_aExpiredLifetime.FindValue(iEntity);
	if (iIndex >= 0)
		g_aExpiredLifetime.Erase(iIndex);
}

public void OnGameFrame()
{
	int iWeapon = MaxClients+1;
	while ((iWeapon = FindEntityByClassname(iWeapon, "tf_weapon_flamethrower")) > MaxClients)
		if (GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") - 0.5 < GetGameTime())	//because this appearently affects airblast timing
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);	//no primary attack
	
	static int iOffsetNextAttack = -1;
	if (iOffsetNextAttack == -1)
		iOffsetNextAttack = FindSendPropInfo("CObjectSentrygun", "m_iState") + 4;	//m_flNextAttack
	
	int iSentry = MaxClients+1;
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) > MaxClients)
	{
		//Never allow sentry shoot bullets
		SetEntDataFloat(iSentry, iOffsetNextAttack, GetGameTime() + 10.0);
		
		//However it prevents shooting rockets, so we have to manually call function
		if (GetEntProp(iSentry, Prop_Send, "m_iState") == 2	//SENTRY_STATE_ATTACKING
			&& GetEntProp(iSentry, Prop_Send, "m_iUpgradeLevel") == 3
			&& GetEntProp(iSentry, Prop_Send, "m_nShieldLevel") == 0)
			SDKCall_FireRocket(iSentry);
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return Plugin_Continue;
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	//Managing player's weapon without touching wearables in 2021? crazy shit man
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon != INVALID_ENT_REFERENCE)
		{
			char sClassname[256];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			if (!Config_IsClassnameInWhitelist(sClassname))
			{
				TF2_RemoveWeaponSlot(iClient, iSlot);
				
				int iIndex = Config_GetDefaultIndex(nClass, iSlot);
				if (iIndex >= 0)
				{
					iWeapon = TF2_CreateWeapon(iIndex, nClass);
					if (iWeapon != INVALID_ENT_REFERENCE)
						EquipPlayerWeapon(iClient, iWeapon);
				}
			}
			
			if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == INVALID_ENT_REFERENCE && iWeapon != INVALID_ENT_REFERENCE)
				TF2_SwitchActiveWeapon(iClient, iWeapon);
		}
	}
	
	return Plugin_Continue;
}

bool BounceProjectile(int iProjectile, int iToucher, float vecVelocity[3])
{
	float vecNormal[3];
	if (!GetEntityToWorldPlaneNormal(iProjectile, iToucher, vecVelocity, vecNormal))
		return false;
	
	float flDotProduct = GetVectorDotProduct(vecNormal, vecVelocity);
	ScaleVector(vecNormal, flDotProduct);
	ScaleVector(vecNormal, 2.0);
	
	SubtractVectors(vecVelocity, vecNormal, vecVelocity);
	return true;
}

bool GetEntityToWorldPlaneNormal(int iEntity, int iToucher, const float vecVelocity[3], float vecNormal[3])
{
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vecOrigin);
	GetVectorAngles(vecVelocity, vecAngles);
	
	TR_TraceRayFilter(vecOrigin, vecAngles, MASK_ALL, RayType_Infinite, Trace_OnlyThisEntity, iToucher);
	if (!TR_DidHit() || TR_GetSurfaceFlags() & SURF_SKY)
		return false;	//Entity should be deleted
	
	TR_GetPlaneNormal(null, vecNormal);
	return true;
}

bool Trace_OnlyThisEntity(int iEntity, int iMask, int iData)
{
	return iEntity == iData;
}

bool IsEntitySolid(int iEntity)
{
	return GetEntProp(iEntity, Prop_Send, "m_nSolidType") != view_as<int>(SOLID_NONE) && !(GetEntProp(iEntity, Prop_Send, "m_usSolidFlags") & view_as<int>(FSOLID_NOT_SOLID));
}

bool CanDamageEntity(int iEntity)
{
	//Is there a better way to do this? just listed all ents that called npc_hurt event
	static char sClassnameDamage[][] = {
		"base_boss",
		"boss_alpha",
		"bot_boss",
		"bot_npc_minion",
		"eyeball_boss",
		"headless_hatman",
		"merasmus",
		"obj_",
		"player",
		"tank_boss",
	};
	
	char sClassname[256];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	for (int i = 0; i < sizeof(sClassnameDamage); i++)
		if (StrContains(sClassname, sClassnameDamage[i]) == 0)
			return true;
	
	return false;
}

stock int TF2_CreateWeapon(int iIndex, TFClassType nClass)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), nClass);
	
	int iWeapon = CreateEntityByName(sClassname);
	if (iWeapon != INVALID_ENT_REFERENCE)
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		//SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		DispatchSpawn(iWeapon);
		
		//Reset charge meter
		//SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, iSlot);
	}
	
	return iWeapon;
}

stock void TF2_SwitchActiveWeapon(int iClient, int iWeapon)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	FakeClientCommand(iClient, "use %s", sClassname);
}

public Action Timer_ExpiredLifetime(Handle hTimer, int iRef)
{
	int iProjectile = EntRefToEntIndex(iRef);
	if (iProjectile == INVALID_ENT_REFERENCE)
		return Plugin_Continue;
	
	g_aExpiredLifetime.Push(iProjectile);
	return Plugin_Continue;
}