// Copyright (c) 2018, it0uchpods (PID tuning and some autoflight logic), SNOWY1 (everything else)
// This file is licensed under the MIT license.



//it0uchpods PID constant magic
set pitchKp to 0.075.
set pitchKi to 0.06.
set pitchKd to 0.001.

set rollKp to 0.02.
set rollKi to 0.003.
set rollKd to 0.0.

set yawKp to 0.08.
set yawKi to 0.01.
set yawKd to 0.4.

set throttleKp to 0.16.
set throttleKi to 0.02.
set throttleKd to 0.015.

//other control constants
set rollLimit to 30.
//set turningRollConstant to 1.8. //ratio between remaining heading difference and roll used

declare function turningRollCoefficient
{
	if(airspeed<80)
	{
		return (0.6/80)*airspeed.
	}
	return (0.02*airspeed)+(-1).
}

//state variable initialization
//This function should be called before the loop.
declare function init
{
	//Clear the message queue to prevent performance problems.
	core:messages:clear().
	
	set terminal:charheight to 16.
	set terminal:height to 5.
	set terminal:width to 32.

	set pitchRatePID to pidloop(pitchKp, pitchKi, pitchKd, -1, 1).
	set rollRatePID to pidloop(rollKp, rollKi, rollKd, -1, 1).
	set yawPID to pidloop(yawKp, yawKi, yawKd, -1, 1).
	set throttlePID to pidloop(throttleKp, throttleKi, throttleKd, -0.4, 0.4).

	set pitchRatePID:minoutput to -1.
	set pitchRatePID:maxoutput to 1.
	set rollRatePID:minoutput to -1.
	set rollRatePID:maxoutput to 1.
	set yawPID:minoutput to -1.
	set yawPID:maxoutput to 1.
	set throttlePID:minoutput to -0.4.
	set throttlePID:maxoutput to 0.4.

	set pitchMaster to false.
	set lateralMaster to false.
	set autoThrottleMaster to false.

	//Pitch modes:
	//fpa: hold the current flight path angle
	//level: seek vertical speed 0
	//fms: seek a heading specified by the FMS
	set pitchMode to "fpa".
	//Lateral modes:
	//level: seek roll 0
	//FMS: Seek the heading specified by the FMS
	set lateralMode to "level".
	//Throttle modes:
	//Hold: hold the airspeed when it is set
	//FMS: do what the FMS tells it to do; this can be a speed or "HIGH" and "LOW".
	set autoThrottleMode to "hold".

	//these should be overwritten by the program at runtime. These are just declarations.
	//NEVER DIRECTLY SET THESE EXCEPT WITHIN THE IMPLEMENTATION OF AN AUTOPILOT MODE!
	set targetPitch to 0.
	set targetHeading to 0.
	set targetRoll to 0.
	
	set manualTargetAirspeed to 0.

	set pitchRate to 0.
	set rollRate to 0.
	set previousPitch to 0.
	set previousRoll to 0.
	set previousHeading to 0.
	set previousAirspeed to 0.
	set previousMeasurementTime to time:seconds.

	set manualTargetFPA to 0.

	set externalTargetFPA to 0.
	set externalFPAExplanation to "".
	set externalTargetHeading to 0.
	set externalHeadingExplanation to "".
	set externalAutothrustControl to "0". //It is a string.
	set externalAutothrustExplanation to "".
	
	set timeOfLastFMSAlive to 0.
	set FMSAlive to true. //this is to let all parts of the program access the FMS status without concentrating all the code conditional on it into one block.
	
	lock radarAltitude to alt:radar.

	wait 0.01. //This is to prevent a divide-by-0 error on the first loop iteration
}

declare function targetRollFromHeadingDifference
{
	declare parameter th, ch. //target and current
	set headingDifference to findHeadingDifference(th, ch).

	//set answer to turningRollConstant*headingDifference.
	set answer to turningRollCoefficient()*headingDifference.
	if(abs(answer)>rollLimit)
	{
		set answer to rollLimit * (answer / abs(answer)). //set it to the limit with the same sign as the original.
	}
	return answer.
	//print answer.
}

declare function findHeadingDifference
{
	declare parameter a, b.
	//print a.
	//print b.
	//print a-b.
	//a is target, b is current
	if(abs(a-b)>180)
	{
		set ans to -((a-b)/abs(a-b))*abs(360-(a-b)). //360 minus the difference, in the opposite sign to the original
	}
	else
	{
		set ans to a-b.
	}
	return ans.
}

declare function updateHelperVariables
{
	set pitch to 90 - vectorangle(up:vector,ship:facing:vector).
	//print pitch.

	set bankAngle to 90 - vectorangle(vxcl(up:vector,ship:facing:starvector),ship:facing:topvector).
	//print bankAngle.

	set track to vectorangle(vxcl(up:vector,ship:srfprograde:vector),ship:north:vector).
	if(vectordotproduct(vectorcrossproduct(vxcl(up:vector,ship:srfprograde:vector),ship:north:vector), up:vector) > 0) //if the cross product and up are similar in direction
	{
		set track to 360-track.
	}
	//print track.

	set aoa to vectorangle( vxcl(ship:facing:vector,ship:facing:topvector) , vxcl(ship:srfprograde:vector,ship:facing:topvector) ).
	if(pitch < 90 - vectorangle(up:vector,ship:srfprograde:vector)) //stupid fix?
	{
		set aoa to -aoa.
	}
	//print aoa.

	set sideslip to vectorangle( vxcl(ship:facing:vector,ship:facing:starvector) , vxcl(ship:srfprograde:vector,ship:facing:starvector) ).
	if(vectordotproduct( vectorcrossproduct(vxcl(ship:facing:vector,ship:facing:starvector),vxcl(ship:srfprograde:vector,ship:facing:starvector)) , ship:facing:topvector) > 0) //if the cross product and the direction up from the ship are similar
	{
		set sideslip to -sideslip.
	}
	//print "sideslip " + sideslip.

	if(-ship:bearing >= 0)
	{
		set hdg to -ship:bearing.
	}
	else
	{
		set hdg to -ship:bearing + 360.
	}

	set fpa to pitch-aoa.
	//print "fpa " + fpa.
}

declare function updateRates
{
	set pitchRate to (previousPitch - pitch)/(previousMeasurementTime-time:seconds).
	set rollRate to (previousRoll - bankAngle)/(previousMeasurementTime-time:seconds).
	set yawRate to findHeadingDifference(previousHeading, hdg)/(previousMeasurementTime-time:seconds).
	set airspeedRate to (previousAirspeed - airspeed)/(previousMeasurementTime-time:seconds).

	//Make new measurements.
	set previousMeasurementTime to time:seconds.
	set previousPitch to pitch.
	set previousRoll to bankAngle.
	set previousHeading to hdg.
	set previousAirspeed to airspeed.
}

declare function airspeedLinearPrediction
{
	declare parameter lookAheadTime.
	return airspeed + (airspeedRate*lookAheadTime).
}

declare function handleMessages
{
	until(core:messages:empty) //until message queue is empty
	{
		set m to core:messages:pop.
		set messageParts to m:content:split(" ").
		set messageType to messageParts[0]. //this always exists.

		if(messageType = "updateTargetFPA")
		{
			set messageValue to messageParts[1].
			set messageExplanation to messageParts[2].
			set externalTargetFPA to messageValue:tonumber.
			set externalFPAExplanation to messageExplanation.
		}
		if(messageType = "updateTargetHeading")
		{
			set messageValue to messageParts[1].
			set messageExplanation to messageParts[2].
			set externalTargetHeading to messageValue:tonumber.
			set externalHeadingExplanation to messageExplanation.
		}
		if(messageType = "disengage")
		{
			//automatic disengage
			disengage.
		}
		if(messageType = "FMSAlive")
		{
			set timeOfLastFMSAlive to time:seconds.
		}
		if(messageType = "updatePID")
		{
			set newConstants to list().
			set i to 0.
			until(i=9)
			{
				newConstants:add(messageParts[1+i]).
				set i to i+1.
			}

			if(not(newConstants[0] = "---"))
			{
				set pitchRatePID:kp to newConstants[0]:tonumber.
			}
			if(not(newConstants[1] = "---"))
			{
				set pitchRatePID:ki to newConstants[1]:tonumber.
			}
			if(not(newConstants[2] = "---"))
			{
				set pitchRatePID:kd to newConstants[2]:tonumber.
			}

			if(not(newConstants[3] = "---"))
			{
				set rollRatePID:kp to newConstants[3]:tonumber.
			}
			if(not(newConstants[4] = "---"))
			{
				set rollRatePID:ki to newConstants[4]:tonumber.
			}
			if(not(newConstants[5] = "---"))
			{
				set rollRatePID:kd to newConstants[5]:tonumber.
			}

			if(not(newConstants[6] = "---"))
			{
				set yawPID:kp to newConstants[6]:tonumber.
			}
			if(not(newConstants[7] = "---"))
			{
				set yawPID:ki to newConstants[7]:tonumber.
			}
			if(not(newConstants[8] = "---"))
			{
				set yawPID:kd to newConstants[8]:tonumber.
			}
		}
		if(messageType = "updateAutoThrottleState")
		{
			set externalAutothrustControl to messageParts[1].
			set externalAutothrustExplanation to messageParts[2].
		}
	}
}

declare function checkFMSAlive
{
	if(time:seconds - timeOfLastFMSAlive > 1) //The FMS appears to be dead.
	{
		print "-- FMS NOT FOUND --".
		set FMSAlive to false.
	}
	else //The FMS is alive.
	{
		set FMSAlive to true.
	}
}

declare function updateModeStates
{
	//2 autoththrottle master
	if(ag2)
	{
		if(autoThrottleMaster = false)
		{
			set manualTargetAirspeed to airspeed.
		}
		set autoThrottleMaster to true.
	}
	else
	{
		set autoThrottleMaster to false.
	}
	
	//3 pitch master
	if(ag3)
	{
		if(pitchMaster = false) //if pitch master is newly activated, set targets to values at time of activation
		{
			set manualTargetFPA to fpa.
		}
		set pitchMaster to true.
	}
	else
	{
		set pitchMaster to false.
	}

	//4 roll master
	if(ag4)
	{
		//There is no non-FMS heading hold mode, so there is no need to store any starting value to hold.
		set lateralMaster to true.
	}
	else
	{
		set lateralMaster to false.
	}

	//5 switch pitch mode
	if(ag5)
	{
		if(pitchMode = "fpa")
		{
			set pitchMode to "level".
		}
		else if(pitchMode = "level")
		{
			set pitchMode to "fms".
		}
		else if(pitchMode = "fms")
		{
			set pitchMode to "fpa".
			set manualTargetFPA to fpa. //Hold the FPA at the moment of activation.
		}
		ag5 off.
	}

	//6 switch lateral mode
	if(ag6)
	{
		if(lateralMode = "level")
		{
			set lateralMode to "fms".
		}
		else if(lateralMode = "fms")
		{
			set lateralMode to "level".
		}
		ag6 off.
	}
	
	//7 change autoththrottle mode
	if(ag7)
	{
		if(autoThrottleMode = "hold")
		{
			set autoThrottleMode to "fms".
		}
		else if(autoThrottleMode = "fms")
		{
			set autoThrottleMode to "hold".
		}
		ag7 off.
	}

	//fallback functionality when FMS is not found
	//This skips modes that depend on the FMS to prevent undefined behaviour.
	if(not(FMSAlive))
	{
		if(pitchMode = "fms")
		{
			set pitchMode to "fpa".
			set manualTargetFPA to fpa.
		}
		if(lateralMode = "fms")
		{
			set lateralMode to "level".
		}
		if(autoThrottleMode = "fms")
		{
			set autoThrottleMode to "hold".
			set manualTargetAirspeed to airspeed.
		}
	}

	//10 disengage autopilot
	if(ag10)
	{
		disengage.
		ag10 off.
	}
}

declare function disengage
{
	set pitchMaster to false.
	ag2 off.
	ag3 off.
	ag4 off.
	set lateralMaster to false.
	//now set the autopilot modes so that there are no surprises upon reengaging it
	set pitchMode to "fpa".
	set lateralMode to "level".
	set autoThrottleMode to "hold".
	//give control to user
	set ship:control:neutralize to true.
}

declare function targetPitchRateFromTargetPitch
{
	//return 0. //debug
	//it0uchpods magic
	declare parameter a. //target pitch
	return max(min((a - pitch) * 0.75,1.5),-1.5).
}

declare function targetRollRateFromTargetRoll
{
	//return 0. //debug
	//it0uchpods magic
	declare parameter a.
	return max(min((a - bankAngle) * 1.2,4.8),-4.8).
}

declare function doPitchModes
{
	if(pitchMaster)
	{
		if(pitchMode = "fpa")
		{
			set targetPitch to manualTargetFPA + aoa.
		}
		if(pitchMode = "level")
		{
			set targetPitch to aoa.
		}
		if(pitchMode = "fms")
		{
			set targetPitch to aoa + externalTargetFPA.
		}

		set pitchRatePID:setpoint to targetPitchRateFromTargetPitch(targetPitch).
		set ship:control:pitch to pitchRatePID:update (time:seconds, pitchRate).
	}
	else
	{
		set ship:control:pitch to 0. //setting it to 0 unlocks it.
		pitchRatePID:reset().
	}
}

declare function doLateralModes
{
	if(lateralMaster)
	{
		if(lateralMode = "level")
		{
			set targetRoll to 0.
		}
		if(lateralMode = "fms")
		{
			set targetHeading to externalTargetHeading.
			set targetRoll to targetRollFromHeadingDifference(targetHeading, hdg).
			
			set bankAngleLimit to min(45, 0.025*radarAltitude + 20). //copied from sd_safety
			set targetRoll to max(min(targetRoll, bankAngleLimit-2), -bankAngleLimit+2).
		}

		set rollRatePID:setpoint to targetRollRateFromTargetRoll(targetRoll).
		set ship:control:roll to rollRatePID:update(time:seconds, rollRate).

		//yaw so that sideslip goes to 0
		set yawPID:setpoint to 0.
		
		//it0uchpods magic
		set yawDamp to max(min(yawRate*-0.087,0.1),-0.1).
		set ship:control:yaw to yawPID:update(time:seconds, sideslip) + yawDamp.
		//set ship:control:yaw to yawDamp.
		//print "output " + yawDamp.
	}
	else
	{
		set ship:control:roll to 0. //setting it to 0 unlocks it.
		set ship:control:yaw to 0. //setting it to 0 unlocks it.
		rollRatePID:reset().
		yawPID:reset().
		
	}
}

declare function doThrottleModes
{
	if(autoThrottleMaster)
	{
		if(autoThrottleMode = "hold")
		{
			set throttlePID:setpoint to manualTargetAirspeed.
			lock throttle to throttlePID:update(time:seconds, airspeedLinearPrediction(5)) + 0.5.
		}
		if(autoThrottleMode = "fms")
		{
			if(externalAutothrustControl = "HIGH")
			{
				lock throttle to 0.9. //This gives a little room to increase thrust if it is really needed.
			}
			else
			{
				if(externalAutothrustControl = "LOW")
				{
					lock throttle to 0.1. //The engine takes too long to spin up from a complete idle.
				}
				else
				{
					//It is a target speed.
					set throttlePID:setpoint to externalAutothrustControl:tonumber.
					lock throttle to throttlePID:update(time:seconds, airspeedLinearPrediction(5)) + 0.5.
				}
			}
		}
	}
	else
	{
		unlock throttle.
		throttlePID:reset().
	}
	//print airspeedLinearPrediction(5).
}

declare function displayState
{
	if(pitchMaster)
	{
		if(pitchMode = "fpa")
		{
			print "PITCH: FPA HOLD".
		}
		if(pitchMode = "level")
		{
			print "PITCH: LEVEL".
		}
		if(pitchMode = "fms")
		{
			print "PITCH: FMS " + externalFPAExplanation.
		}
	}
	else
	{
		if(pitchMode = "fpa")
		{
			print "pitch: manual -> FPA hold".
		}
		if(pitchMode = "level")
		{
			print "pitch: manual -> level".
		}
		if(pitchMode = "fms")
		{
			print "pitch: manual -> fms " + externalFPAExplanation.
		}
	}

	if(lateralMaster)
	{
		if(lateralMode = "level")
		{
			print "ROLL: LEVEL".
		}
		if(lateralMode = "fms")
		{
			print "ROLL: FMS " + externalHeadingExplanation.
		}
	}
	else
	{
		if(lateralMode = "level")
		{
			print "roll: manual -> level".
		}
		if(lateralMode = "fms")
		{
			print "roll: manual -> fms "+externalHeadingExplanation.
		}
	}
	
	if(autoThrottleMaster)
	{
		if(autoThrottleMode = "hold")
		{
			print "THR: SPD".
		}
		if(autoThrottleMode = "fms")
		{
			print "THR: FMS " + externalAutothrustExplanation.
		}
	}
	else
	{
		if(autoThrottleMode = "hold")
		{
			print "thr: manual -> spd".
		}
		if(autoThrottleMode = "fms")
		{
			print "thr: manual -> fms " + externalAutothrustExplanation.
		}
	}
}

//initialize upon start
init.

//main loop
until(false)
{
	clearscreen.
	sas off.

	updateHelperVariables.
	updateRates.

	updateModeStates.

	handleMessages.
	checkFMSAlive.

	doPitchModes.
	doLateralModes.
	doThrottleModes.

	displayState.

	//Report to safety system.
	processor("Safety"):connection:sendmessage("AutopilotAlive").
	//Reassure the FMS that the autopilot is working.
	processor("FMS"):connection:sendmessage("AutopilotAlive").
	
	//This is a crude hack to make FLCH work safely.
	processor("FMS"):connection:sendmessage("listeningInPitch " + (pitchMaster and pitchMode="fms")).

	wait 0.05. //Good luck...
	wait 0. //Maybe waiting for two ticks will help with performance issues without a fixed-length delay.
}
