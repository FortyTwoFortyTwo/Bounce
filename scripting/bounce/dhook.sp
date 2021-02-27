static DynamicHook g_hHookVPhysicsCollision;
static DynamicHook g_hHookResolveFlyCollisionCustom;
static DynamicHook g_hHookPipebombTouch;
static DynamicHook g_hHookExplodesOnHit;

static int g_iOffsetGameCollisionEventPreVelocity;
static int g_iOffsetGameCollisionEventEntities;

static int g_iPhysicsCollision = INVALID_ENT_REFERENCE;
static bool g_bExplodesOnHit;

void DHook_Init(GameData hGameData)
{
	g_hHookVPhysicsCollision = DHook_CreateVirtual(hGameData, "CBaseEntity::VPhysicsCollision");
	g_hHookResolveFlyCollisionCustom = DHook_CreateVirtual(hGameData, "CBaseEntity::ResolveFlyCollisionCustom");
	g_hHookPipebombTouch = DHook_CreateVirtual(hGameData, "CTFGrenadePipebombProjectile::PipebombTouch");
	g_hHookExplodesOnHit = DHook_CreateVirtual(hGameData, "CTFGrenadePipebombProjectile::ExplodesOnHit");
	
	g_iOffsetGameCollisionEventPreVelocity = hGameData.GetOffset("gamevcollisionevent_t::preVelocity");
	g_iOffsetGameCollisionEventEntities = hGameData.GetOffset("gamevcollisionevent_t::pEntities");
}

DynamicHook DHook_CreateVirtual(GameData hGameData, const char[] sName)
{
	DynamicHook hHook = DynamicHook.FromConf(hGameData, sName);
	if (!hHook)
		LogError("Failed to create hook: %s", sName);
	
	return hHook;
}

void DHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (Config_IsClassnameForVPhysicsCollision(sClassname))
	{
		g_hHookVPhysicsCollision.HookEntity(Hook_Pre, iEntity, DHook_VPhysicsCollisionPre);
		g_hHookVPhysicsCollision.HookEntity(Hook_Post, iEntity, DHook_VPhysicsCollisionPost);
	}
	
	if (Config_IsClassnameForFlyCollisionCustom(sClassname))
		g_hHookResolveFlyCollisionCustom.HookEntity(Hook_Pre, iEntity, DHook_ResolveFlyCollisionCustom);
	
	//Should give hooks below a better name...
	
	if (Config_IsClassnameForPipebombTouch(sClassname))
		g_hHookPipebombTouch.HookEntity(Hook_Pre, iEntity, DHook_PipebombTouch);
	
	if (Config_IsClassnameForExplodesOnHit(sClassname))
	{
		g_hHookPipebombTouch.HookEntity(Hook_Pre, iEntity, DHook_PipebombTouchPre);
		g_hHookPipebombTouch.HookEntity(Hook_Post, iEntity, DHook_PipebombTouchPost);
		g_hHookExplodesOnHit.HookEntity(Hook_Pre, iEntity, DHook_ExplodesOnHit);
	}
}

public MRESReturn DHook_VPhysicsCollisionPre(int iProjectile, DHookParam hParams)
{
	if (g_aExpiredLifetime.FindValue(iProjectile) >= 0)
		return MRES_Ignored;
	
	// vcollisionevent_t size 32(?) + start of gamevcollisionevent_t size 72(?)
	if (hParams.Get(1))
	{
		g_iPhysicsCollision = hParams.GetObjectVar(2, g_iOffsetGameCollisionEventEntities, ObjectValueType_CBaseEntityPtr);
		hParams.SetObjectVar(2, g_iOffsetGameCollisionEventEntities, ObjectValueType_Int, 0);	// NULL
	}
	else
	{
		g_iPhysicsCollision = hParams.GetObjectVar(2, g_iOffsetGameCollisionEventEntities + 4, ObjectValueType_CBaseEntityPtr);
		hParams.SetObjectVar(2, g_iOffsetGameCollisionEventEntities + 4, ObjectValueType_Int, 0);	// NULL
	}
	
	return MRES_ChangedOverride;
}

public MRESReturn DHook_VPhysicsCollisionPost(int iProjectile, DHookParam hParams)
{
	if (g_aExpiredLifetime.FindValue(iProjectile) >= 0)
		return MRES_Ignored;
	
	//SetEntProp(iProjectile, Prop_Send, "m_bTouched", false);	//not needed
	
	// sizeof(vcollisionevent_t), 32 + start of gamevcollisionevent_t size 72 = 104
	float vecVelocity[3];
	if (hParams.Get(1))
	{
		hParams.GetObjectVarVector(2, g_iOffsetGameCollisionEventPreVelocity + 12, ObjectValueType_Vector, vecVelocity);
		hParams.SetObjectVar(2, g_iOffsetGameCollisionEventEntities, ObjectValueType_CBaseEntityPtr, g_iPhysicsCollision);
	}
	else
	{
		hParams.GetObjectVarVector(2, g_iOffsetGameCollisionEventPreVelocity, ObjectValueType_Vector, vecVelocity);
		hParams.SetObjectVar(2, g_iOffsetGameCollisionEventEntities + 4, ObjectValueType_CBaseEntityPtr, g_iPhysicsCollision);
	}
	
	static float flLastBounce;
	static ArrayList g_aProjectilesBounce;
	if (!g_aProjectilesBounce)
		g_aProjectilesBounce = new ArrayList();
	
	float flGameTime = GetGameTime();
	if (flLastBounce != flGameTime)
	{
		flLastBounce = flGameTime;
		g_aProjectilesBounce.Clear();
	}
	
	//Hook can weirdly be called twice at same frame, if so just keep pre velocity without bounce
	if (g_aProjectilesBounce.FindValue(iProjectile) == -1)
	{
		BounceProjectile(iProjectile, g_iPhysicsCollision, vecVelocity);
		g_aProjectilesBounce.Push(iProjectile);
	}
	
	//Attempting to set postVelocity in gamevcollisionevent_t won't work and may give troubles, so thats why this sdkcall is used instead
	SDKCall_SetVelocity(iProjectile, vecVelocity, NULL_VECTOR);
	
	g_iPhysicsCollision = INVALID_ENT_REFERENCE;
	
	return MRES_ChangedOverride;
}

public MRESReturn DHook_ResolveFlyCollisionCustom(int iProjectile, DHookParam hParams)
{
	if (g_aExpiredLifetime.FindValue(iProjectile) >= 0)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn DHook_PipebombTouch(int iProjectile, DHookParam hParams)
{
	int iToucher = hParams.Get(1);
	if (CanDamageEntity(iToucher) || !IsEntitySolid(iToucher))
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn DHook_PipebombTouchPre(int iProjectile, DHookParam hParams)
{
	int iToucher = hParams.Get(1);
	if (CanDamageEntity(iToucher))
		g_bExplodesOnHit = true;
}

public MRESReturn DHook_PipebombTouchPost(int iProjectile, DHookParam hParams)
{
	g_bExplodesOnHit = false;
}

public MRESReturn DHook_ExplodesOnHit(int iProjectile, DHookReturn hReturn)
{
	if (!g_bExplodesOnHit)
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}