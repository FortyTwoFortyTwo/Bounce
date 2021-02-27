void SDKHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (Config_IsClassnameForTouch(sClassname))
	{
		SDKHook(iEntity, SDKHook_StartTouch, Rocket_StartTouch);
		SDKHook(iEntity, SDKHook_Touch, Rocket_Touch);
	}
	
	if (StrEqual(sClassname, "obj_sentrygun"))
		SDKHook(iEntity, SDKHook_SpawnPost, SentryGun_SpawnPost);
}


public Action Rocket_StartTouch(int iProjectile, int iToucher)
{
	if (CanDamageEntity(iToucher) || !IsEntitySolid(iToucher))
		return Plugin_Continue;
	
	if (g_aExpiredLifetime.FindValue(iProjectile) >= 0)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action Rocket_Touch(int iProjectile, int iToucher)
{
	if (CanDamageEntity(iToucher) || !IsEntitySolid(iToucher))
		return Plugin_Continue;
	
	if (g_aExpiredLifetime.FindValue(iProjectile) >= 0)
		return Plugin_Continue;
	
	float vecVelocity[3];
	GetEntPropVector(iProjectile, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	if (BounceProjectile(iProjectile, iToucher, vecVelocity))
	{
		float vecAngles[3];
		GetVectorAngles(vecVelocity, vecAngles);
		TeleportEntity(iProjectile, NULL_VECTOR, vecAngles, vecVelocity);
	}
	else
	{
		RemoveEntity(iProjectile);	//Touching sky
	}
	
	return Plugin_Handled;
}

public void SentryGun_SpawnPost(int iSentry)
{
	//Always set sentry gun lvl 3, let it build over time
	SetEntProp(iSentry, Prop_Send, "m_iHighestUpgradeLevel", 3);
}