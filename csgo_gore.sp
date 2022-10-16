public Plugin:myinfo =
{
	name = "Goremod light",
	author = "Zeisen (Credit to DiscoBBQ)",
	description = "Goooooo",
	version = "1.0",
	url = ""
}

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

bool g_lateLoad;
int overflow[MAXPLAYERS + 1];

void CreateParticle(int client, const float origin[3], float angle[3], const char[] particleName, bool reverseAngle = false)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEdict(particle) || !IsValidEdict(client))
		return;
	
	if (reverseAngle)
		angle[1] -= 180.0;
	
	TeleportEntity(particle, origin, angle, NULL_VECTOR);
	DispatchKeyValue(particle, "effect_name", particleName);
	DispatchSpawn(particle);
	
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");

	CreateTimer(1.0, DeleteParticle, particle);
}

public Action DeleteParticle(Handle Timer, int particle)
{
	if (IsValidEdict(particle))
	{	
		char className[64];
		GetEdictClassname(particle, className, sizeof(className));

		if(StrEqual(className, "info_particle_system", false))
			RemoveEdict(particle);
	}
}

ForcePrecache(const char[] particleName)
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle))
		return;
		
	DispatchKeyValue(particle, "effect_name", particleName);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(1.0, DeleteParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapStart()
{
	ForcePrecache("blood_impact_headshot");
	ForcePrecache("blood_impact_headshot_01c");

	for (new i = 1; i < MaxClients; i++)
		overflow[i] = -1;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	
	return APLRes_Success;
}

public OnPluginStart()
{
	if (g_lateLoad)
	{
		OnMapStart();
		for (int i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	overflow[client] = -1;
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}	

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
	if (attacker == 0 || attacker > MAXPLAYERS)
		return;

	if (GetClientTeam(victim) == GetClientTeam(attacker))
		return;
	
	int tick = GetSysTickCount();
	if (overflow[victim] == tick)
		return;

	bool dead = GetEntProp(victim, Prop_Data, "m_iHealth") <= 0;
	if (dead)
	{
		overflow[victim] = tick;
		float angle[3];
		GetClientEyeAngles(attacker, angle);

		bool isHeadshot = !!(damagetype & CS_DMG_HEADSHOT);
		char particleName[64];
		strcopy(particleName, sizeof(particleName), isHeadshot ? "blood_impact_headshot" : "blood_impact_headshot_01c");
		CreateParticle(victim, damagePosition, angle, particleName, !isHeadshot);
	}
}