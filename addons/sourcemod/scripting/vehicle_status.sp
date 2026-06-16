/**
 * vehicles_status.sp
 * Displays vehicle health and occupants via PrintCenterText when a player
 * outside a vehicle looks at one.
 *
 * Author: claude.ai guided by DNA.styx
 * Version: 1.0.2
 *
 * Requires: vehicles plugin (vehicles.smx)
 */

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <vehicles>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION          "1.0.2"
#define VEHICLE_CLASSNAME       "prop_vehicle_driveable"
#define VEHICLE_MAX_LOOK_DIST   500.0

public Plugin myinfo =
{
	name        = "Vehicles Status",
	author      = "claude.ai guided by DNA.styx",
	description = "Shows vehicle HP and occupants when looking at a vehicle.",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/DNA-styx/source-vehicles"
};

//-----------------------------------------------------------------------------
// SourceMod Forwards
//-----------------------------------------------------------------------------

public void OnPluginStart()
{
	CreateConVar("sm_vehicle_inspector_version", PLUGIN_VERSION,
		"Vehicle Inspector version", FCVAR_SPONLY | FCVAR_NOTIFY);

	CreateTimer(0.2, Timer_VehicleInspect, _, TIMER_REPEAT);
}

//-----------------------------------------------------------------------------
// Timer
//-----------------------------------------------------------------------------

public Action Timer_VehicleInspect(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
			continue;

		// Only show to players outside a vehicle
		if (GetEntPropEnt(client, Prop_Send, "m_hVehicle") != -1)
			continue;

		int vehicle = GetVehicleInLineOfSight(client);
		if (vehicle == -1)
			continue;

		// Distance check
		float eyePos[3], vehiclePos[3];
		GetClientEyePosition(client, eyePos);
		GetEntPropVector(vehicle, Prop_Data, "m_vecOrigin", vehiclePos);
		if (GetVectorDistance(eyePos, vehiclePos) > VEHICLE_MAX_LOOK_DIST)
			continue;

		DisplayVehicleInfo(client, vehicle);
	}

	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
// Display
//-----------------------------------------------------------------------------

void DisplayVehicleInfo(int client, int vehicle)
{
	float health    = Vehicle(vehicle).Health;
	int   driver    = GetEntPropEnt(vehicle, Prop_Data, "m_hPlayer");
	int   shooter   = Vehicle(vehicle).Shooter;

	// Line 1: HP
	char display[512];
	Format(display, sizeof(display), "HP: %d", RoundToFloor(health));

	// Line 2: driver (skip if seat empty)
	if (driver > 0 && driver <= MaxClients && IsClientInGame(driver))
	{
		char driverName[MAX_NAME_LENGTH];
		GetClientName(driver, driverName, sizeof(driverName));
		Format(display, sizeof(display), "%s\nDriver: %s", display, driverName);
	}

	// Line 3: gunner (skip if seat empty)
	if (shooter > 0 && shooter <= MaxClients && IsClientInGame(shooter))
	{
		char shooterName[MAX_NAME_LENGTH];
		GetClientName(shooter, shooterName, sizeof(shooterName));
		Format(display, sizeof(display), "%s\nGunner: %s", display, shooterName);
	}

	PrintCenterText(client, display);
}

//-----------------------------------------------------------------------------
// Trace
//-----------------------------------------------------------------------------

int GetVehicleInLineOfSight(int looker)
{
	float eyePos[3], eyeAngles[3];
	GetClientEyePosition(looker, eyePos);
	GetClientEyeAngles(looker, eyeAngles);

	TR_TraceRayFilter(eyePos, eyeAngles, MASK_SHOT, RayType_Infinite,
		TraceFilter_SkipClient, looker);

	if (!TR_DidHit())
		return -1;

	int entity = TR_GetEntityIndex();

	if (!IsValidEntity(entity))
		return -1;

	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (!StrEqual(classname, VEHICLE_CLASSNAME))
		return -1;

	return entity;
}

public bool TraceFilter_SkipClient(int entity, int contentsMask, any data)
{
	return entity != data;
}
