static Handle g_hCallFireRocket;
static Handle g_hCallSetVelocity;

void SDKCall_Init(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CObjectSentrygun::FireRocket");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hCallFireRocket = EndPrepSDKCall();
	if (!g_hCallFireRocket)
		LogMessage("Failed to create SDKCall: CObjectSentrygun::FireRocket");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "IPhysicsObject::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	g_hCallSetVelocity = EndPrepSDKCall();
	if (!g_hCallSetVelocity)
		LogMessage("Failed to create SDKCall: IPhysicsObject::SetVelocity");
}

bool SDKCall_FireRocket(int iEntity)
{
	return SDKCall(g_hCallFireRocket, iEntity);
}

void SDKCall_SetVelocity(int iEntity, const float vecVelocity[3], const float vecAngVelocity[3])
{
	static int iOffset = -1;
	if (iOffset == -1)
		FindDataMapInfo(iEntity, "m_pPhysicsObject", _, _, iOffset);
	
	if (iOffset == -1)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	Address pPhyObj = view_as<Address>(GetEntData(iEntity, iOffset));
	if (!pPhyObj)
	{
		LogError("Unable to find offset 'm_pPhysicsObject'");
		return;
	}
	
	SDKCall(g_hCallSetVelocity, pPhyObj, vecVelocity, vecAngVelocity);
}