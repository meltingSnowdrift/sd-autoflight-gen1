//SNOWDRIFT safety system
// Copyright (c) 2018, SNOWY1
// This file is licensed under the MIT license.

set masterWarnings to list().
set masterCautions to list().
set advisories to list().
set GPWSAlerts to list().
set GPWSPullUpAlert to false. //This one is treated differently because it can be triggered by multiple modes.

//GPWS persistent internals
set GPWSMode3Peak to -1000.
set GPWSMode4Floor to 0.
lock flapState to ag1. //This should represent the state of the flaps. Maybe change it so that it reflects the actual flap state rather than the flap control.
lock speedbrakeState to rcs. //similar to the above
lock reverserState to abort. //similar to the above

lock radarAltitude to alt:radar. //There is supposedly a better way to find this value, but I cannot find it in the documentation. This line is to allow it to be easily changed if the better way is found.
set previousRadarAltitude to 0.
set previousRadarAltitudeTime to -1. //to prevent division by 0
set groundRelativeVerticalSpeed to 0.

// other persistent internals
set timeOfLastFMSAlive to 0.
set timeOfLastAutopilotAlive to 0.

//Clear the message queue to prevent performance problems.
core:messages:clear().

// user-controlled settings ----------------------------------------------------------------------

set GPWSEnable to true.
set GPWSLandingMode to false.

// GPWS function declarations --------------------------------------------------------------------

declare function GPWSMode1 //Mode 1 alerts based on projected time to ground
{
	if(radarAltitude<1500 and groundRelativeVerticalSpeed < 0 and ((not GPWSLandingMode) or verticalspeed < -10 ) and GPWSDetectFlight)
	{
		set timeToProjectedImpact to radarAltitude / -groundRelativeVerticalSpeed.
		set timeToFlatGroundImpact to radarAltitude / -verticalspeed.
		
		if(timeToFlatGroundImpact < 25 and verticalspeed < 0) //Flat ground impact time is used here to reduce the rate of false alarms.
		{
			GPWSAlerts:add("SINK RATE"). //Text from original system is "SINK RATE", but this seems more representative of the actual functionality.
		}
		if(timeToProjectedImpact < 15)
		{
			set GPWSPullUpAlert to true.
		}
	}
}

declare function GPWSMode2 //Mode 2 alerts based on closure rate with surrounding terrain. At least that is what it should do. Right now, it does nothing.
{
	//Mode 2 GPWS is too hard to implement for now. This is just a placeholder function.
}

declare function GPWSMode3 //Mode 3 alerts when sinking after takeoff or go-around is detected.
{
	if(radarAltitude < 350 and GPWSDetectInitialClimb())
	{
		if(altitude > GPWSMode3Peak)
		{
			set GPWSMode3Peak to altitude.
		}
		if(altitude < GPWSMode3Peak) //Originally, this used 0.9*GPWSMode3Peak. However, this would not account for runway altitude. This solution is not perfectly realistic but should work.
		{
			GPWSAlerts:add("DON'T SINK").
		}
	}
	else
	{
		//Reset the peak altitude. This is required to make this mode work properly during the next takeoff or go-around.
		set GPWSMode3Peak to -1000.
	}
}

declare function GPWSMode4 //Mode 4 calculates a radar altitude floor and alerts if the aircraft is below it. This implementation is somewhat different from actual mode 4.
{
	//Update the floor.
	if(radarAltitude < 400)
	{
		set GPWSMode4Floor to max(GPWSMode4Floor, radarAltitude).
	}
	if(not(GPWSDetectFlight)) //Reset the floor when on the ground
	{
		set GPWSMode4Floor to 0.
	}
	if(not(GPWSLandingMode) and not(GPWSDetectInitialClimb) and radarAltitude < GPWSMode4Floor - 10) //Do not alert during initial climb or go-around because this mode has no use in those phases.
	{
		GPWSAlerts:add("TOO LOW - TERRAIN").
	}
	if(GPWSLandingMode and not(GPWSDetectInitialClimb)) //Do not alert about gear being raised during a go-around.
	{
		if(radarAltitude < 170 and not(gear))
		{
			GPWSAlerts:add("TOO LOW - GEAR").
		}
		//Flap use during landing is not consistently needed in normal operation. Adding a flaps floor would produce far too many nuisance alerts, even if it could be disabled.
	}
}

declare function GPWSMode5 //Mode 5 alerts if the aircraft deviates below the glideslope during approach.
{
	// IMPLEMENT! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
}

declare function GPWSMode6 //Mode 6 alerts if bank angle is excessive.
{
	set roll to 90 - vectorangle(vxcl(up:vector,ship:facing:starvector),ship:facing:topvector). //copied from sd_ap; same as "bankAngle" used there
	set GPWSBankAngle to abs(roll). //This is not the same as the "bankAngle" used in the autopilot.
	set bankAngleLimit to min(45, 0.025*radarAltitude + 20).
	if(GPWSBankAngle > bankAngleLimit)
	{
		GPWSAlerts:add("BANK ANGLE").
	}
}

//Mode 7 is not applicable to any aircraft in KSP because windshear is not simulated.

declare function GPWSStateMessages
{
	if(not(GPWSEnable))
	{
		advisories:add("GPWS DISABLE").
	}
	if(GPWSLandingMode)
	{
		advisories:add("GPWS LANDING MODE").
	}
}

declare function GPWSDetectInitialClimb //This function returns true if the aircraft appears to be in an initial climb.
{
	if(not(GPWSDetectFlight))
	{
		return false.
	}
	set pitch to 90 - vectorangle(up:vector,ship:facing:vector). //copied from sd_ap.
	return ((pitch > 0 or flapState) and throttle > 0.7) or (gear and verticalspeed > 5) or throttle > 0.9.
}

declare function GPWSDetectFlight //This function detects if the aircraft is in flight.
{
	return radarAltitude > 3.5.
}

// other checks ----------------------------------------------------------------------------------------------------
declare function checkFMSAlive
{
	if(time:seconds - timeOfLastFMSAlive > 1)
	{
		masterCautions:add("FMS FAIL").
	}
}

declare function checkAutopilotAlive
{
	if(time:seconds - timeOfLastAutopilotAlive > 1)
	{
		masterCautions:add("AUTOPILOT FAIL").
		set ship:control:neutralize to true. //When the autopilot fails, it may leave the controls in a locked state that prevents user input. This is to free the controls if that happens.
	}
}

declare function checkFlaps
{
	if(flapState and airspeed > 100)
	{
		if(airspeed > 150)
		{
			masterWarnings:add("FLAPS OVERSPEED").
		}
		else
		{
			masterCautions:add("FLAPS OVERSPEED").
		}
	}
}

declare function checkGear
{
	if(gear and airspeed > 120)
	{
		if(airspeed > 150)
		{
			masterWarnings:add("GEAR OVERSPEED").
		}
		else
		{
			masterCautions:add("GEAR OVERSPEED").
		}
	}
}

declare function checkSpeedbrakes
{
	if(speedbrakeState)
	{
		if(throttle > 0.3)
		{
			masterWarnings:add("SPEEDBRAKE OPEN WHEN THROTTLE HIGH").
		}
	}
}

declare function checkReversers
{
	if(GPWSDetectFlight)
	{
		if(reverserState)
		{
			masterWarnings:add("REVERSERS").
		}
	}
}

declare function checkTakeoffConfiguration
{
	if(not(GPWSDetectFlight) and not(GPWSLandingMode) and throttle > 0.4)
	{
		if(speedbrakeState)
		{
			masterWarnings:add("CONFIG SPOILERS").
		}
		if(not(flapState))
		{
			masterWarnings:add("CONFIG FLAPS").
		}
		if(brakes)
		{
			masterWarnings:add("CONFIG BRAKES").
		}
		if(reverserState)
		{
			masterWarnings:add("CONFIG REVERSERS").
		}
		if(GPWSLandingMode)
		{
			masterWarnings:add("CONFIG GPWS MODE").
		}
	}
}

// display results -------------------------------------------------------------------------------------------------
declare function displayResults
{
	//There is no clearscreen command here to allow debug printing from functions that come before this one in the loop.
	if(GPWSPullUpAlert)
	{
		print "       !!!!!!!!!!!!!!!!!!!".
		print "       !!!!! PULL UP !!!!!".
		print "       !!!!!!!!!!!!!!!!!!!".
	}
	else
	{
		if(GPWSAlerts:length > 0)
		{
			print "---GPWS---".
			for a in GPWSAlerts
			{
				print a.
			}
		}
		if(masterWarnings:length > 0)
		{
			print "---MASTER WARNING---".
			for a in masterWarnings
			{
				print a.
			}
		}
		if(masterCautions:length > 0)
		{
			print "---MASTER CAUTION---".
			for a in masterCautions
			{
				print a.
			}
		}
		if(advisories:length > 0)
		{
			print "---ADVISORY---".
			for a in advisories
			{
				print a.
			}
		}
	}
}

// aural alerts ----------------------------------------------------------------------------------------------------
set GPWSPullUpSound to note(600, 1).
set GPWSAlertSound to note(500, 1).
set masterWarningSound to list(slidenote(400, 450, 0.5), note("R", 0.5)).
set masterCautionSound to list(note(350, 0.2), note("R", 0.2)).
set v0 to getvoice(0).
declare function auralAlerts
{
	if(not(v0:isplaying)) //Only start a new sound if the old one is done.
	{
		if(GPWSPullUpAlert)
		{
			v0:play(GPWSPullUpSound).
		}
		else
		{
			if(not(GPWSAlerts:empty))
			{
				v0:play(GPWSAlertSound).
			}
			else
			{
				if(not(masterWarnings:empty))
				{
					v0:play(masterWarningSound).
				}
				else
				{
					if(not(masterCautions:empty))
					{
						v0:play(masterCautionSound).
					}
				}
			}
		}
	}
}

//message handling -------------------------------------------------------------------------------------------------
declare function handleMessages
{
	until(core:messages:empty)
	{
		//print "quack".
		set m to core:messages:pop.
		set messageParts to m:content:split(" ").
		set messageType to messageParts[0].

		if(messageType = "safetyGPWSEnable")
		{
			set GPWSEnable to (messageParts[1] = "true").
		}
		if(messageType = "safetyGPWSLandingMode")
		{
			set GPWSLandingMode to (messageParts[1] = "true").
		}
		if(messageType = "FMSAlive")
		{
			set timeOfLastFMSAlive to time:seconds.
		}
		if(messageType = "AutopilotAlive")
		{
			set timeOfLastAutopilotAlive to time:seconds.
		}
	}
}

// TEMPORARY STUFF FOR DEVELOPMENT AND TESTING <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
set timeOfLastAutotrimLog to 0.
//heading line
//log "airspeed, altitude, pitch control" to "autotrim_data.csv".
//log "airspeed, altitude, pitch control" to "autotrim_data_flaps.csv".
declare function collectDataForAutotrim
{
	if(not(time:seconds>timeOfLastAutotrimLog + 0.5)) //Do nothing if delay not done.
	{
		return.
	}

	if(abs(verticalspeed)<2) //ignore data points where the aircraft is strongly climbing or descending
	{
		set logLine to airspeed + ", " + altitude + ", " + ship:control:pitch.
		if(flapState)
		{
			log logLine to "autotrim_data_flaps.csv".
		}
		else
		{
			log logLine to "autotrim_data.csv".
		}
	}
	set timeOfLastAutotrimLog to time:seconds.
}

// main loop -------------------------------------------------------------------------------------------------------
until(false)
{
	//comment out when not in use
	//collectDataForAutotrim.

	set groundRelativeVerticalSpeed to (radarAltitude - previousRadarAltitude)/(time:seconds - previousRadarAltitudeTime).

	clearscreen.
	handleMessages.

	GPWSStateMessages.
	if(GPWSEnable)
	{
		GPWSMode1.
		GPWSMode2.
		GPWSMode3.
		GPWSMode4.
		GPWSMode5.
		GPWSMode6.
	}

	checkAutopilotAlive.
	checkFMSAlive.
	checkFlaps.
	checkSpeedbrakes.
	checkGear.
	checkTakeoffConfiguration.

	//debugging
	//print "groundRelativeVerticalSpeed: " + groundRelativeVerticalSpeed.
	//print "GPWSMode3Peak: " + GPWSMode3Peak.
	//print "GPWSMode4Floor: " + GPWSMode4Floor.

	displayResults.
	auralAlerts.

	//Update calculation of groundRelativeVerticalSpeed.
	set previousRadarAltitude to radarAltitude.
	set previousRadarAltitudeTime to time:seconds.

	//Reset all globally declared non-persistent state.
	set masterWarnings to list().
	set masterCautions to list().
	set advisories to list().
	set GPWSAlerts to list().
	set GPWSPullUpAlert to false. //This one is treated differently because it can be triggered by multiple modes.

	wait 0.
}
