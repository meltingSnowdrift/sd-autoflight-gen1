// Copyright (c) 2018, it0uchpods (PID tuning and some autoflight logic), SNOWY1 (everything else)
// This file is licensed under the MIT license.



declare function init
{
	core:messages:clear().
	
	set navMultiplier to 4. //how aggressively the system tries to follow radials; must be at least 2.
	set glideslopeFollowingMultiplier to 2.5. //how aggressively the system tries to follow glideslopes; must be at least 1
	
	set buffer to "". //input buffer
	set page to 0.
	set inputField to 0.
	set numFields to 0.

	set pageSetupComplete to false.

	set enterPressed to false.
	
	set pageList to list
	(
		lateralModeSelectionPage@,
		verticalModeSelectionPage@,
		speedModeSelectionPage@,
		navaidsPage@,
		nav1CDIPage@,
		nav2CDIPage@,
		selsCDIPage@,
		routePage@,
		landingSetupPage@,
		safetySystemPage@
	).
	set numPages to pageList:length.
	
	set lateralModeFunctionTable to lexicon
	(
		"lm_plan", lateralPlanMode@,
		"lm_nav1", lateralNav1Mode@,
		"lm_nav2", lateralNav2Mode@,
		"lm_loc", lateralLocalizerMode@,
		"lm_manualHdg", lateralManualHeadingMode@
	).
	set verticalModeFunctionTable to lexicon
	(
		"vm_vnav", verticalVNAVMode@,
		"vm_fpa", verticalFPAMode@,
		"vm_vs", verticalVSMode@,
		"vm_alt", verticalAltitudeMode@,
		"vm_flch", verticalFLCHMode@,
		"vm_gs", verticalGlideslopeMode@,
		"vm_flare", verticalFlareMode@
	).
	set autothrustModeFunctionTable to lexicon
	(
		"tm_spd", thrustSpeedMode@,
		"tm_high", thrustHighMode@,
		"tm_low", thrustLowMode@
	).
	set speedModeFunctionTable to lexicon
	(
		"sm_selected", speedSelectedMode@,
		"sm_managed", speedManagedMode@
	).
	
	set vnavSubmodesTable to lexicon
	(
		"vsm_flch", vnavFLCHSubmode@,
		"vsm_alt", vnavAltitudeSubmode@,
		"vsm_lin", vnavLinearSubmode@
	).
	
	set lateralMode to "lm_manualHdg".
	set verticalMode to "vm_fpa".
	set thrustMode to "tm_spd".
	set speedMode to "sm_selected".
	
	set vnavSubmode to "vsm_flch".
	
	lock radarAltitude to alt:radar.
	
	set altitudeHoldTarget to 0. //This is not directly modifiable by the user.
	set verticalSpeedForAltitudeHold to 9999. //This is global because it is read by other modes for capture.
	set targetSpeed to 0.
	
	set previousAirspeed to 0.
	set previousMeasurementTime to 0.
	
	//it0uchpods magic
	set flchKp to -3.1.
	set flchKi to -1.5.
	set flchKd to -0.01.
	set flchPID to pidloop(flchKp, flchKi, flchKd, -51, 51).
	set vnavPID to pidloop(flchKp, flchKi, flchKd, -51, 51).
	
	//it0uchpods magic
	set flareTable to lexicon
	(
		15, -2.5,
		12, -2.0,
		9, -1.5,
		6, -1.0,
		3, -0.8,
		1.5, -0.7
	).
	
	//I try some magic of my own.
	set vnavNormalSpeedTable to lexicon
	(
		1000, 100,
		3000, 130,
		6000, 210,
		8000, 220
	).
	
	set vnavDescentSpeedTable to lexicon
	(
		1000, 90,
		3000, 130,
		6000, 180
	).
	
	set vnavCaptureTimeConstant to 10. //seconds before projected target altitude crossing at which a capture from VNAV occurs
	set vnavOptimalDescentAngle to 5.
	set vnavSteepestDescentAngle to 15.
	set vnavShallowestDescentAngle to 3.
	
	
	set timeOfLastAutopilotAlive to 0.
	set autopilotListeningInPitch to false.
	
	initPages.
	initRouteSystem.
}

declare function initPages
{
	//for lateral mode sesect page
	set manualHdg to 0.
	
	//for vertical mode select page
	set manualFPA to 0.
	set manualVS to 0.
	set glideslopeArmed to false.
	set altitudeSelection to "---".
	
	//for speed mode select page
	set airspeedSelection to 130.
	
	//This initializes lateralModeResultTable so that no crash occurs when doPages is run for the first time before doFMSLateralModes and doFMSVerticalModes.
	set lateralModeResultTable to lexicon
	(
		"lm_plan", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"lm_nav1", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"lm_nav2", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"lm_loc", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"lm_manualHdg", list(0, "---", "THIS SHOULD NEVER BE SEEN!")
	).
	
	//The same is done for verticalModeResultTable.
	set verticalModeResultTable to lexicon
	(
		"vm_vnav", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_fpa", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_alt", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_vs", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_flch", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_gs", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"vm_flare", list(0, "---", "THIS SHOULD NEVER BE SEEN!")
	).
	
	set thrustModeResultTable to lexicon
	(
		"tm_spd", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"tm_high", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"tm_low", list(0, "---", "THIS SHOULD NEVER BE SEEN!")
	).
	
	set speedModeResultTable to lexicon
	(
		"sm_managed", list(0, "---", "THIS SHOULD NEVER BE SEEN!"),
		"sm_selected", list(0, "---", "THIS SHOULD NEVER BE SEEN!")
	).

	//for navaids page
	set nav1Name to "---".
	set nav2Name to "---".
	set nav1Bearing to "---".
	set Nav2Bearing to "---".
	
	//for landing configuration page
	set selsName to "---".
	set selsHeading to "---".
	set selsAngle to "---".
	set decisionHeight to "---".
	set autobrakeArmed to false.
	set spoilerArmed to false.

	//for PID tuning page
	set pitchKp to "---".
	set pitchKi to "---".
	set pitchKd to "---".

	set rollKp to "---".
	set rollKi to "---".
	set rollKd to "---".

	set yawKp to "---".
	set yawKi to "---".
	set yawKd to "---".

	//for safety page
	set GPWSEnable to true.
	set GPWSLandingMode to false.
	set needUpdateSafety to false.
	
	//for all CDI pages
	set cdiHalfLines to 10. //There is a central line. This constant is the number of additional lines to each side of it.
	set cdiHalfColumns to 20.
	set cdiHorizontalAngle to 10. //The edge of the CDI display is this number of degrees away from the centre. A wikipedia article states that full deflection to each side corresponds to 10 degrees.
	set cdiVerticalAngle to 3.

	set updateCoefficients to false.
}

declare function initRouteSystem
{
	set fixDatabase to list(). //This cannot be a lexicon because it must be possible for waypoints of the same name to exist.
	initFixDatabase.
	
	set route to list().
	set activeWaypoint to -1.
	set waypointToEdit to -1.
	set routeInitStartName to "---".
	set routeInitEndName to "---".
	set routePageInEditMode to false.
	set WaypointIDToInsert to "---".
	set routePageDisplayStartIndex to 0. //the index of the waypoint to be displayed at the top of the route page
}

declare function initFixDatabase
{
	//print "quack".
	set fixListRaw to open("fixes.txt"):readall:string.
	set fixListLines to fixListRaw:split(char(10)). //windows newline sequence
	//clearscreen. print fixListLines. print fixListLines[0]. wait 5.
	for s in fixListLines
	{
		set fixData to s:split(" ").
		//print fixData. wait 5.
		if(fixData:length = 3) //This is to skip the closing newline and any similar things.
		{
			fixDatabase:add(list(fixData[0], latlng(fixData[1]:tonumber, fixData[2]:tonumber))). //name, coordinates
		}
	}
}



declare function waypointNameExists //This checks if a vessel or a fix exists of the specified name.
{
	declare parameter testName.
	
	if(vesselExists(testName))
	{
		return true.
	}
	
	for f in fixDatabase
	{
		if(f[0] = testName)
		{
			return true.
		}
	}
	return false.
}

declare function waypointFromName
{
	declare parameter waypointName.
	declare parameter referenceCoordinates. //The function will return the waypoint of the specified name that is closest to these coordinates.
	
	local candidates is list().
	for f in fixDatabase
	{
		if(f[0] = waypointName)
		{
			candidates:add(list("fix", f[1])).
		}
	}
	
	list targets in vesselCandidates.
	for v in vesselCandidates
	{
		if(v:shipname = waypointName)
		{
			candidates:add(list("navaid", v:geoposition)).
		}
	}
	
	//Select the item on the candidates list closest to referenceCoordinates.
	set temp to 9999999.
	set answer to candidates[0].
	for p in candidates
	{
		if(distanceBetweenCoordinates(p[1], referenceCoordinates) < temp)
		{
			set answer to p.
			set temp to distanceBetweenCoordinates(p[1], referenceCoordinates).
		}
	}
	
	return list(answer[0], waypointName, answer[1], "---"). //type, name, coordinates, altitude
}

declare function distanceBetweenCoordinates
{
	declare parameter c1.
	declare parameter c2.
	//return (c1:altitudeposition(0)-c2:altitudeposition(0)):mag.
	
	//Wikipedia magic
	local centralAngle is 2*arcsin(sqrt(
		 (sin((c1:lat-c2:lat)/2) ^ 2)
		 + ( cos(c1:lat) * cos(c2:lat) * (sin((c1:lng-c2:lng)/2) ^ 2) )
	 )).
	
	local kerbinRadius is 600000.
	local answer is kerbinRadius * (centralAngle*Constant:DegToRad).
	return answer.
}

declare function insertWaypoint
{
	declare parameter waypointToInsert. //This is a list representing a waypoint, produced by waypointFromName.
	Declare parameter insertionIndex. //Entries at and after this index will have their indices incremented after insertion.
	route:insert(insertionIndex, waypointToInsert).
	//Yes, I know this is just a wrapper for an existing function, but it exists so that other functionality can easily be attached to this action if needed.
}

declare function deleteWaypoint
{
	declare parameter deletionIndex.
	route:remove(deletionIndex).
	//Yes, I know this is just a wrapper for an existing function, but it exists so that other functionality can easily be attached to this action if needed.
}

declare function headingToWaypoint
{
	declare parameter targetWaypointIndex.
	return route[targetWaypointIndex][2]:heading.
}

declare function passingWaypoint
{
	declare parameter checkWaypointIndex.
	//If the aircraft os close to a waypoint and is facing away from it, the waypoint has probably been passed.
	if(distanceBetweenCoordinates(ship:geoposition, route[checkWaypointIndex][2]) < 1000) //This should suffice as a crude check for closeness.
	{
		if(-ship:bearing >= 0)
		{
			set hdg to -ship:bearing.
		}
		else
		{
			set hdg to -ship:bearing + 360.
		}
		
		if(abs(findHeadingDifference(headingToWaypoint(checkWaypointIndex), hdg)) > 90)
		{
			return true.
		}
	}
	return false.
}

declare function activeWaypointAvailable
{
	return not(activeWaypoint < 0 or activeWaypoint >= route:length).
}

declare function checkActiveWaypointPass
{
	if(activeWaypointAvailable)
	{
		if(passingWaypoint(activeWaypoint))
		{
			set activeWaypoint to activeWaypoint + 1.
			if(not(activeWaypointAvailable)) //In this case, this basically checks if the end of the route has been reached.
			{
				set activeWaypoint to -1.
			}
			else
			{
				waypointChangeTriggeredChecks.
			}
		}
	}
}

declare function waypointChangeTriggeredChecks
{
	//copied from vnavLinearSubmode
	local spec is nextAltitudeSpecification(activeWaypoint).
	
	if(spec = "---")
	{
		return.
	}
	
	//bottom of descent for linear descent
	if(vnavSubmode = "vsm_lin")
	{
		//copied from vnavLinearSubmode
		local linearDescentAngle is -arctan((altitude - spec[0])/spec[1]).
		if(linearDescentAngle > -vnavShallowestDescentAngle) //vnavShallowestDescentAngle is positive
		{
			set vnavSubmode to "vsm_alt".
			//This will hold the previous specified altitude because nothing else has triggered a transition check that would update vnavAltitudeToHold.
		}
		else
		{
			set vnavAltitudeToHold to spec[0]. //Update the altitude to hold.
		}
	}
	
	//bottom of climb
	if(spec[0] > altitude)
	{
		set vnavSubmode to "vsm_flch". //If it is just a small difference and there is no need for FLCH, the capture check will automatically change the submode back to vsm_alt.
		set vnavAltitudeToHold to spec[0].
	}
}

declare function distanceToWaypoint
{
	declare parameter indexToCheckDistance.
	local distanceToActiveWaypoint is distanceBetweenCoordinates(ship:geoposition, route[activeWaypoint][2]).
	local totalDistance is distanceToActiveWaypoint.
	local i is activeWaypoint+1.
	until(i > indexToCheckDistance)
	{
		//print "i " + i. //debug
		set totalDistance to totalDistance + distanceBetweenCoordinates(route[i-1][2], route[i][2]).
		set i to i + 1.
	}
	return totalDistance.
}

declare function nextAltitudeSpecification
{
	declare parameter firstIndexToCheck. //When used in VNAV, this should be the index of the active waypoint.
	
	if(firstIndexToCheck<0 or firstIndexToCheck > route:length)
	{
		return "---".
	}
	
	local indexToCheck is firstIndexToCheck.
	until(indexToCheck = route:length)
	{
		if(not(route[indexToCheck][3] = "---"))//if the waypoint at this index has an altitude
		{
			return list(route[indexToCheck][3], distanceToWaypoint(indexToCheck)).
		}
		set indexToCheck to indexToCheck + 1.
	}
	return "---".
}

declare function nextWaypointAltitude //I am a lazy developer. This function exists to avoid having to change a lot of code that uses a function of this name which was replaced.
{
	declare parameter a.
	local temp is nextAltitudeSpecification(a).
	if(not(temp = "---"))
	{
		return temp[0].
	}
	return temp.
}



declare function findHeadingDifference //copied from sd_ap
{
	declare parameter a, b.
	//print a.
	//print b.
	//print a-b.
	//a is target, b is current
	if(abs(a-b)>180)
	{
		set ans to -(sgn(a-b))*abs(360-(a-b)). //360 minus the difference, in the opposite sign to the original
	}
	else
	{
		set ans to a-b.
	}
	return ans.
} //end of copied function

declare function sgn
{
	declare parameter a.
	if(a = 0)
	{
		return 0.
	}
	return abs(a) / a.
}

declare function vesselExists
{
	declare parameter vesselName.
	set answer to false.

	list targets in temp. //sets temp to a list of all vessels
	for temp2 in temp //look for the requested object
	{
		if(temp2:shipname = vesselName)
		{
			set answer to true.
			break.
		}
	}
	return answer.
}

declare function stringField
{
	declare parameter content.
	declare parameter selected.
	if(selected)
	{
		return ">("+content+")".
	}
	else
	{
		return " ("+content+")".
	}
}

declare function boolField
{
	declare parameter content. //string content of the field. This part does not change. It is like a label for the field.
	declare parameter value. //whether the value of this field is on or off
	declare parameter selected. //whether this field is selected for data entry
	if(value)
	{
		if(selected)
		{
			return ">#"+content.
		}
		else
		{
			return " #"+content.
		}
	}
	else
	{
		if(selected)
		{
			return ">-"+content.
		}
		else
		{
			return " -"+content.
		}
	}
}

declare function waypointField
{
	declare parameter waypointIndex.
	declare parameter selected.
	
	set answer to "".
	if(selected)
	{
		set answer to answer + ">".
	}
	else
	{
		set answer to answer + " ".
	}
	
	local waypointName is route[waypointIndex][1].
	set answer to answer + waypointName.
	
	if(not(route[waypointIndex][3] = "---"))
	{
		set answer to answer + ": " + route[waypointIndex][3].
	}
	
	if(activeWaypoint = waypointIndex)
	{
		set answer to answer + "  <---- REMAIN " + round(distanceToWaypoint(waypointIndex)/100)/10 + "km".
	}
	
	return answer.
}

declare function handleKeystroke
{
	if(terminal:input:haschar)
	{
		set ch to terminal:input:getchar.
		set isSpecialChar to false.

		//if it is the backspace key, clear the buffer.
		if(ch = terminal:input:BACKSPACE)
		{
			set isSpecialChar to true.
			if(buffer = "")
			{
				// If buffer is empty, this means to add a clear command to the buffer.
				set buffer to "CLEAR".
			}
			else
			{
				set buffer to "".
			}
		}

		//if it is the enter key, send the buffer text to the selected field.
		if(ch = terminal:input:RETURN)
		{
			set isSpecialChar to true.
			set enterPressed to true.
		}
		//enterPressed is cleared at the end of the loop so that it is false even if nothing was pressed since then.

		//if it is an up arrow, select the previous field.
		if(ch = terminal:input:UPCURSORONE)
		{
			set isSpecialChar to true.
			if(inputField>1) //Field 0 does not exist. The selected field number is set to 0 when there are no fields to select.
			{
				set inputField to inputField - 1.
			}
		}

		//if it is a down arrow, select the next field.
		if(ch = terminal:input:DOWNCURSORONE)
		{
			set isSpecialChar to true.
			if(inputField<numFields and not(inputField = 0)) //Fields are indexed from 1 to numFields. The check for 0 is used to prevent field selection on pages that should not allow it.
			{
				set inputField to inputField + 1.
			}
		}

		//if it is a left arrow, go to the previous page.
		if(ch = terminal:input:LEFTCURSORONE)
		{
			set isSpecialChar to true.
			if(page > 0)
			{
				set page to page - 1.
				set inputField to 0.
				set pageSetupComplete to false.
			}
		}

		//if it is a right arrow, go to the next page.
		if(ch = terminal:input:RIGHTCURSORONE)
		{
			set isSpecialChar to true.
			if(page < numPages - 1)
			{
				set page to page + 1.
				set inputField to 0.
				set pageSetupComplete to false.
			}
		}

		//These keys are not used. This structure exists to prevent their addition to the input buffer.
		if(ch = terminal:input:PAGEUPCURSOR or ch = terminal:input:PAGEDOWNCURSOR or ch = terminal:input:HOMECURSOR or ch = terminal:input:ENDCURSOR or ch = terminal:input:DELETERIGHT)
		{
			set isSpecialChar to true.
		}

		//if not any of those things, add the char to the buffer.
		if(not isSpecialChar)
		{
			set buffer to buffer + ch.
		}
	}
}

declare function updateAltitudeHoldTarget
{
	if(not(altitudeSelection = "---"))
	{
		set altitudeHoldTarget to altitudeSelection.
	}
}

declare function updateAirspeedRate
{
	set airspeedRate to (previousAirspeed - airspeed)/(previousMeasurementTime-time:seconds).
	set previousMeasurementTime to time:seconds.
	set previousAirspeed to airspeed.
}

declare function airspeedLinearPrediction
{
	declare parameter lookAheadTime.
	return airspeed + (airspeedRate*lookAheadTime).
}

declare function detectFlight //copied from sd_safety
{
	return radarAltitude > 3.5.
}

declare function safeHeadingToVessel //I am not strictly sure if this function is necessary. However, it may have helped fix a problem.
{
	declare parameter v. //the vessel to check
	if(abs(v:distance / (v:altitude - altitude)) - 1 < 0.01) //This checks if the aircraft is nearly on top of the reference vessel
	{
		//copied from sd_ap
		if(-ship:bearing >= 0)
		{
			return -ship:bearing.
		}
		else
		{
			return -ship:bearing + 360.
		}
		//This should only occur for a fraction of a second, and it is less dangerous than returning a constant.
	}
	else
	{
		return v:heading.
	}
}

declare function safeAngleToVessel //Maybe eventually use this function in glideslope mode, but something equivalent is implemented there already anyway and I am lazy.
{
	declare parameter v.
	if(abs(v:distance / (v:altitude - altitude)) - 1 < 0.01) //This checks if the aircraft is nearly on top of the emiter; it prevents crashes when overflying it.
	{
		print "quack3".
		return 0. //This should be safe becasue GS mode does not use it in this state anyway.
	}
	else
	{
		return arcsin((v:altitude - ship:altitude)/v:distance).
	}
}

declare function linearEstimation //It appears that the work from the autotrim project is not wasted.
{
	declare parameter x1.
	declare parameter y1.
	declare parameter x2.
	declare parameter y2.
	declare parameter currentX.
	
	//debug
	//print "("+x1+", "+y1+")".
	//print "("+x2+", "+y2+")".
	
	//Given points (x1, y1) and (x2, y2), interpolate or extrapolate linearly to find the y value for currentX.
	set m to (y2-y1)/(x2-x1).
	set b to y1-(m*x1).
	set answer to (m*currentX)+b.
	return answer.
}

declare function tableEstimation //This function does automatic linear interpolation using a lexicon with numerical keys and values.
{
	declare parameter table.
	declare parameter currentX.
	
	//Find the key no more than currentX that is closest to it. If no such key exists, select the lowest key.
	local lowX is "".
	for k in table:keys
	{
		//If the table contains currentX, just look it up and return the corresponding value. This is necessary because, otherwise, this case would cause a crash.
		if(k = currentX)
		{
			return table[k].
		}
		
		if(k <= currentX)
		{
			if(lowX = "") //if there is no lowX yet
			{
				set lowX to k.
			}
			else
			{
				if(k > lowX)
				{
					set lowX to k.
				}
			}
		}
	}
	if(lowX = "") //if currentX is lower than all keys
	{
		//Select the lowest key.
		set lowX to 99999.
		for k in table:keys
		{
			if(k < lowX)
			{
				set lowX to k.
			}
		}
	}
	
	//Find the key no less than currentX that is closest to it. If all keys are less than currentX, select the highest key.
	set highX to "".
	for k in table:keys
	{
		if(k >= currentX and k > lowX)
		{
			if(highX = "")
			{
				set highX to k.
			}
			else
			{
				if(k < highX)
				{
					set highX to k.
				}
			}
		}
		//print "k " + k.
		//print "highX " + highX.
	}
	if(highX = "") //if currentX is higher than all keys
	{
		//lowX is the highest key when this is true.
		set highX to lowX.
		
		//Find a new lowX that is the closest to highX
		set lowX to -99999.
		for k in table:keys
		{
			if(k > lowX and k < highX)
			{
				set lowX to k.
			}
		}
	}
	
	//Now estimate.
	return linearEstimation(lowX, table[lowx], highX, table[highX], currentX).
}



declare function doPages
{
	pageList[page]:call.

	print "--------------------------------".
	print "[ " + buffer + " ]".
}

declare function lateralModeSelectionPage
{
	if(not pageSetupComplete)
	{
		set numFields to 6.
		set inputField to 1. //there are fields, so allow selection
		set pageSetupComplete to true.
	}

	print "     LATERAL MODE SELECT".
	//print lateralModeNumbers.
	//print lateralModeResultTable.
	print boolField("PLAN: "+lateralModeResultTable["lm_plan"][1], lateralMode = "lm_plan", inputField = 1).
	print boolField("NAV1: "+lateralModeResultTable["lm_nav1"][1], lateralMode = "lm_nav1", inputField = 2).
	print boolField("NAV2: "+lateralModeResultTable["lm_nav2"][1], lateralMode = "lm_nav2", inputField = 3).
	print boolField("LOC: "+lateralModeResultTable["lm_loc"][1], lateralMode = "lm_loc", inputField = 4).
	print boolField("HDG: "+lateralModeResultTable["lm_manualHdg"][1], lateralMode = "lm_manualHdg", inputField = 5).
	print "SET HDG: " + stringField(manualHdg, inputField = 6).

	if(enterPressed)
	{
		//For boolean fields, the content of the buffer is ignored. The field is set whenever the enter key is pressed while it is selected.

		//plan mode select
		if(inputField = 1)
		{
			if(not (lateralModeResultTable["lm_plan"][1] = "---"))
			{
				set lateralMode to "lm_plan".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}

		//nav1 mode select
		if(inputField = 2)
		{
			if(not (lateralModeResultTable["lm_nav1"][1] = "---"))
			{
				set lateralMode to "lm_nav1".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}

		//nav2 mode select
		if(inputField = 3)
		{
			if(not (lateralModeResultTable["lm_nav2"][1] = "---"))
			{
				set lateralMode to "lm_nav2".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 4)
		{
			if(not (lateralModeResultTable["lm_loc"][1] = "---"))
			{
				set lateralMode to "lm_loc".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}

		//manual hdg mode select
		if(inputField = 5)
		{
			if(not (lateralModeResultTable["lm_manualHdg"][1] = "---"))
			{
				set lateralMode to "lm_manualHdg".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}

		//manual hdg input
		if(inputField = 6)
		{
			//this is the number entry field for manual heading mode
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 360)
			{
				//invalid number format (-9999) or heading out of range
				set buffer to "NOT ALLOWED".
			}
			else
			{
				set manualHdg to temp.
			}
		}
	}
}

declare function verticalModeSelectionPage
{
	if(not(pageSetupComplete))
	{
		set numFields to 8.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	
	print "     VERTICAL MODE SELECT".
	if(not(autopilotListeningInPitch))
	{
		print " --AP NOT LISTENING IN PITCH--".
	}
	print boolField("VNAV: "+verticalModeResultTable["vm_vnav"][1], verticalMode = "vm_vnav", inputField = 1).
	print boolField("FPA: "+verticalModeResultTable["vm_fpa"][1], verticalMode = "vm_fpa", inputField = 2).
	print boolField("VS: "+verticalModeResultTable["vm_vs"][1], verticalMode = "vm_vs", inputField = 3).
	print boolField("FLCH: "+verticalModeResultTable["vm_flch"][1], verticalMode = "vm_flch", inputField = 4).
	print boolField("GS ARM", glideslopeArmed, inputField = 5).
	
	if(verticalMode = "vm_alt")
	{
		print "  ALT HOLD ACTIVE: " + verticalModeResultTable["vm_alt"][1].
	}
	else
	{
		if(verticalMode = "vm_gs")
		{
			print "  GLIDESLOPE FOLLOW ACTIVE: " + verticalModeResultTable["vm_gs"][1].
		}
		else
		{
			if(verticalMode = "vm_flare")
			{
				print "  FLARE".
			}
			else
			{
				print " ". //Apparently a blank string produces no newline.
			}
		}
	}
	
	print "SET FPA: "+stringField(manualFPA, inputField = 6).
	print "SET VS: "+stringField(manualVS, inputField = 7).
	print "ALT SELECT: "+stringField(altitudeSelection, inputField = 8).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			if(not(verticalModeResultTable["vm_vnav"][1] = "---"))
			{
				set verticalMode to "vm_vnav".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 2)
		{
			if(not(verticalModeResultTable["vm_fpa"][1] = "---"))
			{
				set verticalMode to "vm_fpa".
				updateAltitudeHoldTarget.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 3)
		{
			if(not(verticalModeResultTable["vm_vs"][1] = "---"))
			{
				set verticalMode to "vm_vs".
				updateAltitudeHoldTarget.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 4)
		{
			if(not(verticalModeResultTable["vm_flch"][1] = "---"))
			{
				set verticalMode to "vm_flch".
				updateAltitudeHoldTarget.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 5)
		{
			set glideslopeArmed to not(glideslopeArmed).
		}
		
		//manual FPA input
		if(inputField = 6)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < -20 or temp > 20)
			{
				//invalid number format (-9999) or value out of range
				set buffer to "NOT ALLOWED".
			}
			else
			{
				set manualFPA to temp.
			}
		}
		
		//manual VS input
		if(inputField = 7)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < -50 or temp > 50)
			{
				//invalid number format (-9999) or value out of range
				set buffer to "NOT ALLOWED".
			}
			else
			{
				set manualVS to temp.
			}
		}
		
		//altitude preselection for vertical modes
		if(inputField = 8)
		{
			//The user can clear this field to have vertical modes function with no preselection.
			if(buffer = "CLEAR")
			{
				set altitudeSelection to "---".
			}
			else
			{
				set temp to buffer:tonumber(-9999).
				if(temp < 0 or temp > 15000)
				{
					//invalid number format (-9999) or value out of range
					set buffer to "NOT ALLOWED".
				}
				else
				{
					set altitudeSelection to temp.
					//If the selection is changed or set while automated vertical movement is ongoing, set or update the capture point.
					if(not(verticalMode = "vm_alt"))
					{
						set altitudeHoldTarget to altitudeSelection.
					}
				}
			}
		}
	}
}

declare function speedModeSelectionPage
{
	if(not(pageSetupComplete))
	{
		set numFields to 3.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	
	print "     SPEED MODE SELECT".
	print boolField("SEL: "+speedModeResultTable["sm_selected"][1], speedMode = "sm_selected", inputField = 1).
	print boolField("MANAGED: "+speedModeResultTable["sm_managed"][1], speedMode = "sm_managed", inputField = 2).
	
	if(thrustMode = "tm_spd")
	{
		print "Autothrust mode: SPEED".
	}
	else
	{
		if(thrustMode = "tm_high")
		{
			print "Autothrust mode: HIGH".
		}
		else
		{
			//it must be in low mode
			print "Autothrust mode: LOW".
		}
	}
	//print "targetSpeed " + targetSpeed. //debug
	
	print " ".
	print "SPD SELECT: " + stringField(airspeedSelection, inputField = 3).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			if(not (speedModeResultTable["sm_selected"][1] = "---"))
			{
				set speedMode to "sm_selected".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 2)
		{
			if(not (speedModeResultTable["sm_managed"][1] = "---"))
			{
				set speedMode to "sm_managed".
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 3)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 45 or temp > 310)
			{
				//invalid number format (-9999) or value out of range
				set buffer to "NOT ALLOWED".
			}
			else
			{
				set airspeedSelection to temp.
			}
		}
	}
}

declare function navaidsPage
{
	if(not pageSetupComplete)
	{
		set numFields to 4.
		set inputField to 1. //there are fields, so allow selection
		set pageSetupComplete to true.
	}

	print "     NAVAIDS".
	print "NAV1 " + stringField(nav1Name, inputField = 1).
	print "NAV1 BEARING " + stringField(nav1Bearing, inputField = 2).
	print "NAV2 " + stringField(nav2Name, inputField = 3).
	print "NAV2 BEARING " + stringField(nav2Bearing, inputField = 4).

	if(enterPressed)
	{
		//nav1 navaid name
		if(inputField = 1)
		{
			if(buffer = "CLEAR")
			{
				set nav1Name to "---".
			}
			if(vesselExists(buffer))
			{
				set nav1Name to buffer.
			}
			else
			{
				set buffer to "NAVAID NOT FOUND".
			}
		}

		//nav1 bearing
		if(inputField = 2)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 360)
			{
				if(buffer = "CLEAR")
				{
					set nav1Bearing to "---".
				}
				else
				{
					//invalid number format (-9999) or heading out of range
					set buffer to "NOT ALLOWED".
				}
			}
			else
			{
				set nav1Bearing to temp.
			}
		}

		//nav2 navaid name
		if(inputField = 3)
		{
			if(buffer = "CLEAR")
			{
				set nav2Name to "---".
			}
			if(vesselExists(buffer))
			{
				set nav2Name to buffer.
			}
			else
			{
				set buffer to "NAVAID NOT FOUND".
			}
		}

		//nav2 bearing
		if(inputField = 4)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 360)
			{
				if(buffer = "CLEAR")
				{
					set nav2Bearing to "---".
				}
				else
				{
					//invalid number format (-9999) or heading out of range
					set buffer to "NOT ALLOWED".
				}
			}
			else
			{
				set nav2Bearing to temp.
			}
		}
	}
}

declare function landingSetupPage
{
	if(not pageSetupComplete)
	{
		set numFields to 6.
		set inputField to 1. //there are fields, so allow selection
		set pageSetupComplete to true.
	}
	
	print "     LAND CONFIG".
	print "SELS NAVAID " + stringField(selsName, inputField = 1).
	print "RUNWAY HDG " + stringField(selsHeading, inputField = 2).
	print "GLIDESLOPE ANGLE " + stringField(selsAngle, inputField = 3).
	print "DECISION HEIGHT " + stringField(decisionHeight, inputField = 4).
	print boolField("AUTOBRAKE", autobrakeArmed, inputField = 5).
	print boolField("SPOILERS ARM", spoilerArmed, inputField = 6).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			if(vesselExists(buffer))
			{
				set selsName to buffer.
			}
			else
			{
				if(buffer = "CLEAR")
				{
					//There should never exist a vessel called "CLEAR". Such a vessel is likely to break things. A vessel called "---" is also likely to cause problems.
					set selsName to "---".
				}
				else
				{
					set buffer to "NAVAID NOT FOUND".
				}
			}
		}
		
		if(inputField = 2)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 360)
			{
				if(buffer = "CLEAR")
				{
					set selsHeading to "---".
				}
				else
				{
					//invalid number format (-9999) or heading out of range
					set buffer to "NOT ALLOWED".
				}
			}
			else
			{
				set selsHeading to temp.
			}
		}
		
		if(inputField = 3)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 4)
			{
				if(buffer = "CLEAR")
				{
					set selsAngle to "---".
				}
				else
				{
					//invalid number format (-9999) or heading out of range
					set buffer to "NOT ALLOWED".
				}
			}
			else
			{
				set selsAngle to temp.
			}
		}
		
		if(inputField = 4)
		{
			set temp to buffer:tonumber(-9999).
			if(temp < 0 or temp > 1500)
			{
				if(buffer = "CLEAR")
				{
					set decisionHeight to "---".
				}
				else
				{
					//invalid number format (-9999) or heading out of range
					set buffer to "NOT ALLOWED".
				}
			}
			else
			{
				set decisionHeight to temp.
			}
		}
		
		if(inputField = 5)
		{
			set autobrakeArmed to not(autobrakeArmed). //This is always allowed.
		}
		
		if(inputField = 6)
		{
			set spoilerArmed to not(spoilerArmed).
		}
	}
}

declare function autopilotTuningPage
{
	if(not pageSetupComplete)
	{
		set numFields to 10.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	print "     CONSTANTS".
	print "Pitch:".
	print "Kp "+stringField(pitchKp, inputField = 1).
	print "Ki "+stringField(pitchKi, inputField = 2).
	print "Kd "+stringField(pitchKd, inputField = 3).
	print "Roll:".
	print "Kp "+stringField(rollKp, inputField = 4).
	print "Ki "+stringField(rollKi, inputField = 5).
	print "Kd "+stringField(rollKd, inputField = 6).
	print "Yaw:".
	print "Kp "+stringField(yawKp, inputField = 7).
	print "Ki "+stringField(yawKi, inputField = 8).
	print "Kd "+stringField(yawKd, inputField = 9).
	print boolField("UPDATE", updateCoefficients, inputField = 10).

	if(enterPressed)
	{
		if(inputField = 1)
		{
			set pitchKp to buffer.
		}
		if(inputField = 2)
		{
			set pitchKi to buffer.
		}
		if(inputField = 3)
		{
			set pitchKd to buffer.
		}

		if(inputField = 4)
		{
			set rollKp to buffer.
		}
		if(inputField = 5)
		{
			set rollKi to buffer.
		}
		if(inputField = 6)
		{
			set rollKd to buffer.
		}

		if(inputField = 7)
		{
			set yawKp to buffer.
		}
		if(inputField = 8)
		{
			set yawKi to buffer.
		}
		if(inputField = 9)
		{
			set yawKd to buffer.
		}

		if(inputField = 10)
		{
			set updateCoefficients to true.
		}
	}
}

declare function safetySystemPage
{
	if(not pageSetupComplete)
	{
		set numFields to 2.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	print "     SAFETY".
	print boolField("GPWS ENABLE", GPWSEnable, inputField = 1).
	print boolField("GPWS LANDING MODE", GPWSLandingMode, inputField = 2).

	if(enterPressed)
	{
		set needUpdateSafety to true.
		if(inputField = 1)
		{
			set GPWSEnable to not(GPWSEnable).
		}
		if(inputField = 2)
		{
			set GPWSLandingMode to not(GPWSLandingMode).
		}
	}
}

declare function quackPage
{
	if(not pageSetupComplete)
	{
		set numFields to 3.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	print "     IT0UCHPODS MAGIC INTERFACE".
	print "Kp "+stringField(flchPID:kp, inputField = 1).
	print "Ki "+stringField(flchPID:ki, inputField = 2).
	print "Kd "+stringField(flchPID:kd, inputField = 3).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			set flchPID:kp to buffer:tonumber.
		}
		if(inputField = 2)
		{
			set flchPID:ki to buffer:tonumber.
		}
		if(inputField = 3)
		{
			set flchPID:kd to buffer:tonumber.
		}
	}
}

declare function genericCDIPage
{
	declare parameter cdiNavaidName.
	declare parameter cdiGlideslope. //"---" if no glideslope is to be used; otherwise, a number representing the glideslope angle
	declare parameter cdiCourse. //like above, "---" if no such value; this is the course, along a radial whether inward or outward, to be represented relative to the navaid
	//declare parameter firstLine. //first row on which thisfunction draws the display; this exists to prevent drawing over text on the page
	local firstLine is 5. //This can be left as a constatn for now because all the pages using it are identical in format.
	local cdiNavaidVessel is vessel(cdiNavaidName).
	local facingNavaid is false. //true if the aircraft is pointing toward the navaid
	
	local hdg is 0.
	if(-ship:bearing >= 0)
	{
		set hdg to -ship:bearing.
	}
	else
	{
		set hdg to -ship:bearing + 360.
	}
	
	//debug
	//print "cdiNavaidName " + cdiNavaidName.
	//print "cdiGlideslope " + cdiGlideslope.
	//print "cdiCourse "+ cdiCourse.
	
	//There are no fields.
	if(not(pageSetupComplete))
	{
		set numFields to 0.
		set inputField to 0.
		set pageSetupComplete to true.
	}
	
	local cdiAngleFromNavaid is "quack". //This value whould never be used when it is not valid.
	local cdiHeadingToNavaid is "quack".
	
	local verticalAngularResolution is cdiVerticalAngle / cdiHalfLines.
	local horizontalAngleResolution is cdiHorizontalAngle / cdiHalfColumns.
	//print "verticalAngularResolution " + verticalAngularResolution.
	//print "horizontalAngleResolution " + horizontalAngleResolution.
	
	local centreLine is firstLine + cdiHalfLines + 1.
	local centreColumn is 2 + cdiHalfColumns.
	
	if(not(cdiGlideslope = "---"))
	{
		print "-" at(1, centreLine).
		set cdiAngleFromNavaid to -safeAngleToVessel(cdiNavaidVessel). //Invert the result to get the angle from the navaid rather than the angle to it.
		if(cdiAngleFromNavaid = 0) //This is a return value to indicate a temporarily unavailable value while flying over a navaid. Even if it occurs naturally, it should be momentary.
		{
			set cdiGlideslope to "---". //Treat as if no glideslope is specified.
		}
		else
		{
			set glideslopeDeviation to cdiAngleFromNavaid - cdiGlideslope. //This needs to go in an else block because it requires a valid cdiGlideslope.
		}
		//print "cdiAngleFromNavaid " + cdiAngleFromNavaid. //debug
		//print "glideslopeDeviation " + glideslopeDeviation.
	}
	
	if(not(cdiCourse = "---"))
	{
		print "|" at(centreColumn, firstLine).
		set cdiHeadingToNavaid to safeHeadingToVessel(cdiNavaidVessel).
		if(abs(findHeadingDifference(cdiHeadingToNavaid, hdg)) < 90)
		{
			set facingNavaid to true.
		}
		//print "cdiHeadingToNavaid " + cdiHeadingToNavaid. //debug
		set headingDeviation to findHeadingDifference(cdiCourse, cdiHeadingToNavaid). //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		if(abs(findHeadingDifference(cdiCourse+180, cdiHeadingToNavaid)) < abs(headingDeviation))
		{
			set headingDeviation to findHeadingDifference(cdiCourse+180, cdiHeadingToNavaid).
		}
		//print "headingDeviation " + headingDeviation.
	}
	
	print " DME "+ round(cdiNavaidVessel:distance/100)/10 + " km".
	if(not(cdiCourse = "---"))
	{
		if(facingNavaid)
		{
			print " TO".
		}
		else
		{
			print " FROM".
		}
	}
	
	//Print a lot of newlines to prevent other printed text from covering the display.
	local k is 0.
	until(k = (2*cdiHalfLines)+2)
	{
		print " ".
		set k to k+1.
	}
	
	local markLine is -1.
	local markColumn is -1.
	
	local i is -cdiHalfLines. //current line
	until(i>cdiHalfLines) //find the line to mark
	{
		if(not(cdiGlideslope = "---")) //if a glideslope exists
		{
			if(glideslopeDeviation > (i-0.5) * verticalAngularResolution and glideslopeDeviation < (i+0.5) * verticalAngularResolution) //if this is the line on which to display the glideslope
			{
				set markLine to i + centreLine.
			}
		}
		set i to i + 1.
	}
	
	set j to -cdiHalfColumns.
	until(j>cdiHalfColumns)
	{
		if(not(cdiCourse = "---")) //if a course exists
		{
			if(headingDeviation > (j-0.5) * horizontalAngleResolution and headingDeviation < (j+0.5) * horizontalAngleResolution)
			{
				if(facingNavaid)
				{
					set markColumn to centreColumn - j.
				}
				else
				{
					set markColumn to centreColumn + j.
				}
			}
		}
		set j to j + 1.
	}
	
	//new iterators with same name because the old ones do not need to be reused
	if(not(markColumn = -1))
	{
		set i to centreLine - cdiHalfLines.
		until(i = centreLine + cdiHalfLines + 1)
		{
			print "|" at(markColumn,i).
			set i to i+1.
		}
	}
	
	if(not(markLine = -1))
	{
		set j to centreColumn - cdiHalfColumns.
		until(j = centreColumn + cdiHalfColumns + 1)
		{
			print "-" at(j, markLine).
			set j to j+1.
		}
	}
}

declare function selsCDIPage
{
	print "     CDI: SELS".
	if(not(decisionHeight = "---"))
	{
		if(altitude - vessel(selsName):altitude < decisionHeight)
		{
			print " " + selsName + "    MINIMUMS".
		}
		else
		{
			print " " + selsName.
		}
	}
	
	if(vesselExists(selsName))
	{
		genericCDIPage(selsName, selsAngle, selsHeading).
	}
	else
	{
		print "NOT AVAILABLE".
	}
	//If not, nothing needs to be done because the default state upon a page change is safe for pages with no setup.
}

declare function nav1CDIPage
{
	print "     CDI: NAV1".
	print " " + nav1Name.
	if(vesselExists(nav1Name))
	{
		genericCDIPage(nav1Name, "---", nav1Bearing).
	}
	else
	{
		print "NOT AVAILABLE".
	}
}

declare function nav2CDIPage
{
	print "     CDI: NAV2".
	print " " + nav2Name.
	if(vesselExists(nav2Name))
	{
		genericCDIPage(nav2Name, "---", nav2Bearing).
	}
	else
	{
		print "NOT AVAILABLE".
	}
}

declare function routePage
{
	if(route:length = 0)
	{
		routePageInitialSetupMode.
		return. //This prevents the normal route page from executing while in this mode.
	}
	
	if(routePageInEditMode)
	{
		routePageWaypointEditMode.
		return.
	}
	//print "quack2".
	
	if(not pageSetupComplete)
	{
		set numFields to 12.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	
	print "     ROUTE".
	
	local i is 0.
	until(not(i<10)) //while i<10
	{
		if(routePageDisplayStartIndex + i < route:length) //if a waypoint exists at that index
		{
			print waypointField(routePageDisplayStartIndex + i, inputField = i+1).
		}
		else
		{
			if(inputField = i+1)
			{
				print ">".
			}
			else
			{
				print " ".
			}
		}
		set i to i+1.
	}
	
	print " ".
	print boolField("UP", false, inputField = 11).
	print boolField("DOWN", false, inputField = 12).
	
	if(enterPressed)
	{
		if(inputField < 11)
		{
			if(routePageDisplayStartIndex + inputField - 1 < route:length) //if a waypoint exists at that index
			{
				set waypointToEdit to routePageDisplayStartIndex + inputField - 1.
				
				set routePageInEditMode to true.
				set pageSetupComplete to false.
			}
		}
		
		if(inputField = 11)
		{
			set routePageDisplayStartIndex to max(routePageDisplayStartIndex-10, 0).
		}
		
		if(inputField = 12)
		{
			set routePageDisplayStartIndex to min(routePageDisplayStartIndex+10, route:length-1).
		}
	}
}

declare function routePageInitialSetupMode //Basically, this is a page that replaces the normal route page if the route is not yet initialized.
{
	//print fixDatabase. //debug
	//In this mode, the user should specify two runway end points.When the "INITIALIZE" field is set to true while inputs are valid, the route is initialized with these two points.
	if(not pageSetupComplete)
	{
		set numFields to 3.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	
	print "     ROUTE: INIT".
	print "START: " + stringField(routeInitStartName, inputField = 1).
	print "END: " + stringField(routeInitEndName, inputField = 2).
	
	print " ".
	print boolField("INITIALIZE", false, inputField = 3).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			if(waypointNameExists(buffer))
			{
				set routeInitStartName to buffer.
			}
			else
			{
				set buffer to "WAYPOINT NOT FOUND".
			}
		}
		
		if(inputField = 2)
		{
			if(waypointNameExists(buffer))
			{
				set routeInitEndName to buffer.
			}
			else
			{
				set buffer to "WAYPOINT NOT FOUND".
			}
		}
		
		if(inputField = 3)
		{
			if(waypointNameExists(routeInitStartName) and waypointNameExists(routeInitEndName))
			{
				route:add(waypointFromName(routeInitStartName, ship:geoposition)).
				route:add(waypointFromName(routeInitEndName, ship:geoposition)).
				set pageSetupComplete to false. //Upon adding these points, the page will automatically enter the normal mode.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
	}
}

declare function routePageWaypointEditMode
{
	if(not pageSetupComplete)
	{
		set numFields to 8.
		set inputField to 1.
		set pageSetupComplete to true.
	}
	
	print "     ROUTE: WP EDIT".
	print "ID: " + stringField(route[waypointToEdit][1], inputField = 1)
	+ "   LAT: " + round(route[waypointToEdit][2]:lat) + "  LONG: " + round(route[waypointToEdit][2]:lng).
	print "ALT: " + stringField(route[waypointToEdit][3], inputField = 2).
	print boolField("JUMP", false, inputField = 3).
	print boolField("DELETE", false, inputField = 4).
	
	print " ".
	print "INSERT:".
	print "ID: " + stringField(WaypointIDToInsert, inputField = 5).
	print boolField("INSERT BEFORE", false, inputField = 6).
	print boolField("INSERT AFTER", false, inputField = 7).
	
	print " ".
	print boolField("EXIT", false, inputField = 8).
	
	if(enterPressed)
	{
		if(inputField = 1)
		{
			if(waypointNameExists(buffer))
			{
				//The entire waypoint is replaced. Just changing the name would do nothing.
				//The ship's position is used because previous and next waypoints may not be available.
				set route[waypointToEdit] to waypointFromName(buffer, ship:geoposition).
			}
			else
			{
				set buffer to "WAYPOINT NOT FOUND".
			}
		}
		
		if(inputField = 2)
		{
			//The user can clear this field to have vertical modes function with no preselection.
			if(buffer = "CLEAR")
			{
				set route[waypointToEdit][3] to "---".
			}
			else
			{
				set temp to buffer:tonumber(-9999).
				if(temp < 0 or temp > 15000)
				{
					//invalid number format (-9999) or value out of range
					set buffer to "NOT ALLOWED".
				}
				else
				{
					set route[waypointToEdit][3] to temp.
				}
			}
		}
		
		if(inputField = 3)
		{
			//print "quack". //debug
			//There is no condition because this should always be possible.
			set activeWaypoint to waypointToEdit.
			waypointChangeTriggeredChecks.
			
			set routePageInEditMode to false.
			set pageSetupComplete to false.
		}
		
		if(inputField = 4)
		{
			if(not(waypointToEdit = 0) and not(waypointToEdit = route:length - 1)) //Deletion of the first and last waypoints is not allowed. These are the runway end points.
			{
				deleteWaypoint(waypointToEdit).
				
				set routePageInEditMode to false.
				set pageSetupComplete to false.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 5)
		{
			if(waypointNameExists(buffer))
			{
				set WaypointIDToInsert to buffer.
			}
			else
			{
				set buffer to "WAYPOINT NOT FOUND".
			}
		}
		
		if(inputField = 6)
		{
			if(waypointNameExists(WaypointIDToInsert) and waypointToEdit > 0)//Do not allow inserting before beginning of the route.
			{
				insertWaypoint(waypointFromName(WaypointIDToInsert, route[waypointToEdit][2]), waypointToEdit). //Use position of waypoint being edited as the reference point. Insert at index of the one being edited to put the new one before it.
				
				//Set up for editing the newly inserted one.
				set WaypointIDToInsert to "---".
				//waypointToEdit remains unchanged.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 7)
		{
			if(waypointNameExists(WaypointIDToInsert) and waypointToEdit < route:length-1) //Do not allow inserting after the end of the route because start and end points are treated specially.
			{
				insertWaypoint(waypointFromName(WaypointIDToInsert, route[waypointToEdit][2]), waypointToEdit + 1). //Insert at one after the index of the one being edited to put the new one after it.
				
				//Set up for editing the newly inserted one.
				set WaypointIDToInsert to "---".
				set waypointToEdit to waypointToEdit + 1. //Edit the newly addes waypoint.
			}
			else
			{
				set buffer to "NOT ALLOWED".
			}
		}
		
		if(inputField = 8)
		{
			set routePageDisplayStartIndex to min(routePageDisplayStartIndex, route:length-1). //This ensures that an invalid page will not be displayed when leaving this mode after a lot of deletions.
			set routePageInEditMode to false.
			set pageSetupComplete to false.
		}
	}
}



declare function doFMSLateralModes
{
	//set lateralModeResultTable to list().

	//Execute each mode function to get the result structures and then put them in the result table.
	for key in lateralModeFunctionTable:keys
	{
		//lateralModeResultTable:add(lateralModeFunctionTable[lateralModeNumbers[key]]:call).
		set lateralModeResultTable[key] to lateralModeFunctionTable[key]:call.
	}

	//Select the correct target value and status string from the result table to send to the autopilot.
	set lateralModeOutputHeading to lateralModeResultTable[lateralMode][0].
	set lateralModeOutputExplanation to lateralModeResultTable[lateralMode][2].
}

declare function lateralPlanMode
{
	if(not(activeWaypointAvailable))
	{
		//No valid active waypoint exists.
		if(lateralMode = "lm_plan")
		{
			set lateralMode to "lm_manualHdg".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	//Provide the heading to the active waypoint.
	return list(headingToWaypoint(activeWaypoint), route[activeWaypoint][1], "PLAN").
}

declare function genericLateralNavMode
{
	declare parameter navaidName.
	declare parameter navaidBearing.
	declare parameter modeKey. //key string for the mode in which this is used
	declare parameter dtoString. //to be displayed on AP when DTO
	declare parameter radialString. //to be displayed on AP when radial
	
	//I am a lazy developer. Even when I copy-paste, I only do so once.
	if(vesselExists(navaidName))
	{
		set navVessel to vessel(navaidName).
		if(navaidBearing = "---")
		{
			//direct to
			return list(safeHeadingToVessel(navVessel), navaidName+" DIRECT", dtoString).
		}
		else
		{
			//radial
			set temp1 to findHeadingDifference(safeHeadingToVessel(navVessel), navaidBearing). //heading difference between heading to navaid and selected radial
			if(abs(temp1)<90)
			{
				//heading toward navaid
				set temp3 to navaidBearing + ( sgn(temp1) * min(90, navMultiplier * abs(temp1))).
			}
			else
			{
				//heading away from navaid
				set temp2 to findHeadingDifference(mod(safeHeadingToVessel(navVessel)+180,360), navaidBearing). //opposite of temp1
				set temp3 to navaidBearing + ( -sgn(temp2) * min(90, navMultiplier * abs(temp2))).
			}

			//sometimes, temp3 will be negative.
			if(temp3<0)
			{
				set temp3 to 360+temp3.
			}
			return list(temp3, navaidName+" RADIAL", radialString).
		}
	}
	else //if the navaid does not exist
	{
		if(lateralMode = modeKey)
		{
			set lateralMode to "lm_manualHdg".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
}

declare function lateralNav1Mode
{
	return genericLateralNavMode(nav1Name, nav1Bearing, "lm_nav1", "NAV1 DTO", "NAV1 RAD").
}

declare function lateralNav2Mode
{
	return genericLateralNavMode(nav2Name, nav2Bearing, "lm_nav2", "NAV2 DTO", "NAV2 RAD").
}

declare function lateralLocalizerMode
{
	if(selsHeading = "---")
	{
		//Although genericLateralNavMode is able to deal with the absence of a radial, this should not be allowed during an instrument landing.
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	return genericLateralNavMode(selsName, selsHeading, "lm_loc", "IF YOU SEE THIS THEN I AM A PROFESSIONAL IDIOT", "LOC").
}

declare function lateralManualHeadingMode
{
	return list(manualHdg, manualHdg, "HDG").
}



declare function doFMSVerticalModes
{
	for key in verticalModeFunctionTable:keys
	{
		set verticalModeResultTable[key] to verticalModeFunctionTable[key]:call.
	}
	
	set verticalModeOutputFPA to verticalModeResultTable[verticalMode][0].
	set verticalModeOutputExplanation to verticalModeResultTable[verticalMode][2].
}

declare function verticalVNAVMode
{
	//print "submode "+vnavSubmode. //debug
	
	//copied from vnavLinearSubmode
	local spec is nextAltitudeSpecification(activeWaypoint).
	//print "specification " + spec. //debug
	
	if(not(activeWaypointAvailable) or spec = "---")//if there is nothing for VNAV to do
	{
		if(verticalMode = "vm_vnav")
		{
			//If VNAV is selected when this becomes true, hold the current altitude
			set altitudeSelection to round(altitude).
			set altitudeHoldTarget to altitudeSelection.
			set verticalMode to "vm_alt".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	else
	{
		if(not(verticalMode = "vm_vnav")) //This is placed in this else block because it only makes sense if FLCH is usable.
		{
			//Preset the VNAV submode so that it is in the correct state for activation.
			if(altitude > spec[0])
			{
				//In a transition from non-VNAV to VNAV vertical control, engagement of VNAV should not necessarily cause an altitude change.
				//For example, VNAV may have been briefly disengaged and then reengaged. This should not cause a descent; reengaging VNAV should resume normal operation.
				//The aircraft should fly level unless VNAV would change altitude anyway under normal conditions.
				//By putting it into altitude mode, unwanted altitude changes upon VNAV engagement are avoided, while allowing other state change checks to take it out of altitude mode.
				//This also allows automatic entry into a linear descent from an altitude not on the flightplan.
				set vnavSubmode to "vsm_alt".
				set vnavAltitudeToHold to round(altitude).
				
				//To avoid floating above the target altitude and belatedly reattaining it when resuming VNAV altitude hold, preselect vsm_alt instead if the difference is too small.
				if(altitude - spec[0] < 50)
				{
					set vnavSubmode to "vsm_alt".
				}
			}
			else
			{
				//If a climb is required upon VNAV engagement, the FLCH submode should always be used.
				//If very close to the target altitude, the FLCH capture check will automatically enter the altitude submode.
				set vnavSubmode to "vsm_flch".
			}
		}
	}
	
	if(not(verticalMode = "vm_vnav") or not(vnavSubmode = "vsm_flch"))
	{
		if(not(verticalMode = "vm_flare") and not(verticalMode = "vm_flch"))
		{
			set thrustMode to "tm_spd".
		}
		vnavPID:reset.
	}
	
	//		state transition checks
	
	//copied from vnavLinearSubmode; needed for transition checks
	local linearDescentAngle is -arctan((altitude - spec[0])/spec[1]).
	//print "linearDescentAngle "+linearDescentAngle. //debug
	
	//top of descent
	if(vnavSubmode = "vsm_alt" and spec[0] < altitude)
	{
		if(linearDescentAngle < -vnavOptimalDescentAngle) //vnavOptimalDescentAngle is positive.
		{
			set vnavSubmode to "vsm_lin".
			set vnavAltitudeToHold to spec[0].
		}
	}
	
	//linear descent safety check
	if(vnavSubmode = "vsm_lin")
	{
		if(linearDescentAngle < -vnavSteepestDescentAngle) //vnavSteepestDescentAngle is positive.
		{
			set vnavSubmode to "vsm_flch".
			set vnavAltitudeToHold to spec[0].
		}
	}
	
	//FLCH capture check
	if(vnavSubmode = "vsm_flch")
	{
		if(abs((altitude - spec[0])/verticalspeed) < vnavCaptureTimeConstant)
		{
			set vnavSubmode to "vsm_alt".
			set vnavAltitudeToHold to spec[0].
		}
	}
	
	//Run the selected submode and return its output.
	return vnavSubmodesTable[vnavSubmode]:call.
}

declare function vnavLinearSubmode
{
	//This mode assumes that the waypoint is at a lower altitude than the aircraft.
	local spec is nextAltitudeSpecification(activeWaypoint).
	local linearDescentAngle is -arctan((altitude - spec[0])/spec[1]).
	return list(linearDescentAngle, "LIN "+spec[0], "VNAV").
}

declare function vnavAltitudeSubmode
{
	local vnavVerticalSpeedForAltitudeHold is (5/60)*(vnavAltitudeToHold - altitude).
	local vnavVerticalSpeedForAltitudeHold is max(min(vnavVerticalSpeedForAltitudeHold, 10), -10). //Limit allowed output for safety.
	
	if(abs(vnavVerticalSpeedForAltitudeHold)>airspeed)
	{
		if(verticalMode = "vm_vnav") //Submode functions are only executed when their submodes are active, so there is no need to check that this submode is active.
		{
			set verticalMode to "vm_fpa".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	local temp is fpaFromVerticalSpeed(vnavVerticalSpeedForAltitudeHold).
	return list(temp, vnavAltitudeToHold, "VNAV").
}

declare function vnavFLCHSubmode
{
	//The conditional reset code should be in the main VNAV function.
	
	local lowerVSBound is verticalspeed - 12.
	local upperVSBound is verticalspeed + 12.
	
	local nwa is nextWaypointAltitude(activeWaypoint).
	
	if(nwa= "---")//This can become true if there are no altitudes in the route at all, or if the route does not exist.
	{
		if(verticalMode = "vm_vnav")
		{
			//If this happens while VNAV is selected, hold the current altitude.
			set altitudeSelection to round(altitude).
			set verticalMode to "vm_alt".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	//Calculate vertical speed for altitude hold so that it can be used in capture check.
	local vnavVerticalSpeedForAltitudeHold is (5/60)*(nwa - altitude).
	local vnavVerticalSpeedForAltitudeHold is max(min(vnavVerticalSpeedForAltitudeHold, 10), -10). //Limit allowed output for safety.
	if(abs(vnavVerticalSpeedForAltitudeHold)>airspeed)
	{
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	if(nwa<altitude) //FLCH down
	{
		if(verticalMode = "vm_vnav") //Only control the throttle if this mode is engaged.
		{
			set thrustMode to "tm_low".
		}
		set upperVSBound to -1.
	}
	else //FLCH up
	{
		if(verticalMode = "vm_vnav")
		{
			set thrustMode to "tm_high".
		}
		set lowerVSBound to 1.
	}
	
	set vnavPID:maxoutput to upperVSBound.
	set vnavPID:minoutput to lowerVSBound.
	
	set vnavPID:setpoint to targetSpeed.
	if(verticalMode = "vm_vnav")
	{
		set vnavTargetVerticalSpeed to vnavPID:update(time:seconds, airspeedLinearPrediction(15)).
		//print "vnavTargetVerticalSpeed " + vnavTargetVerticalSpeed.
		if(not(autopilotListeningInPitch))
		{
			set verticalMode to "vm_fpa".
		}
	}
	else
	{
		set vnavTargetVerticalSpeed to 0.
	}
	local temp is fpaFromVerticalSpeed(vnavTargetVerticalSpeed).
	
	if(nwa<altitude)
	{
		return list(temp, "DOWN "+nwa, "VNAV").
	}
	else
	{
		return list(temp, "UP "+nwa, "VNAV").
	}
}

declare function verticalFPAMode
{
	altitudeCaptureCheck("vm_fpa", verticalSpeedFromFPA(manualFPA)).
	
	return list(manualFPA, manualFPA, "FPA SET").
}

declare function verticalVSMode
{
	altitudeCaptureCheck("vm_vs", manualVS).
	
	local temp is fpaFromVerticalSpeed(manualVS).
	return list(temp, manualVS, "VS SET").
}

declare function verticalFLCHMode
{
	if(not(verticalMode = "vm_flch"))
	{
		if(not(verticalMode = "vm_flare") and not(verticalMode = "vm_vnav"))
		{
			set thrustMode to "tm_spd".
		}
		flchPID:reset.
	}
	
	local lowerVSBound is verticalspeed - 12.
	local upperVSBound is verticalspeed + 12.
	if(altitudeSelection = "---" or (altitudeSelection = altitudeHoldTarget and verticalMode = "vm_alt"))
	{
		if(verticalMode = "vm_flch")
		{
			set manualVS to round(verticalspeed).
			set verticalMode to "vm_vs".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	if(altitudeSelection<altitude) //FLCH down
	{
		if(verticalMode = "vm_flch") //Only control the throttle if this mode is engaged.
		{
			set thrustMode to "tm_low".
		}
		set upperVSBound to -1.
	}
	else //FLCH up
	{
		if(verticalMode = "vm_flch")
		{
			set thrustMode to "tm_high".
		}
		set lowerVSBound to 1.
	}
	
	set flchPID:maxoutput to upperVSBound.
	set flchPID:minoutput to lowerVSBound.
	
	set flchPID:setpoint to targetSpeed.
	if(verticalMode = "vm_flch")
	{
		set flchTargetVerticalSpeed to flchPID:update(time:seconds, airspeedLinearPrediction(15)).
		if(not(autopilotListeningInPitch))
		{
			set verticalMode to "vm_fpa".
		}
	}
	else
	{
		set flchTargetVerticalSpeed to 0.
	}
	//set flchTargetVerticalSpeed to max(min(flchTargetVerticalSpeed, upperVSBound), lowerVSBound).
	local temp is fpaFromVerticalSpeed(flchTargetVerticalSpeed).
	
	//The capture check goes at the end of this function because it requires a target VS which is unavailable at the beginning.
	altitudeCaptureCheck("vm_flch", flchTargetVerticalSpeed).
	
	if(altitudeSelection<altitude)
	{
		return list(temp, "DOWN", "FLCH DOWN").
	}
	else
	{
		return list(temp, "UP", "FLCH UP").
	}
}

declare function verticalAltitudeMode
{
	
	//it0uchpods magic
	set verticalSpeedForAltitudeHold to (5/60)*(altitudeHoldTarget - altitude).
	set verticalSpeedForAltitudeHold to max(min(verticalSpeedForAltitudeHold, 10), -10). //Limit allowed output for safety.
	
	if(abs(verticalSpeedForAltitudeHold)>airspeed)
	{
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	
	//copied from above
	local temp is fpaFromVerticalSpeed(verticalSpeedForAltitudeHold).
	return list(temp, altitudeHoldTarget, "ALT HOLD").
}

declare function verticalGlideslopeMode
{
	if(selsHeading = "---" or selsAngle = "---")
	{
		set glideslopeArmed to false.
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
	if(vesselExists(selsName))
	{
		set emitter to vessel(selsName).
		if(emitter:distance < 700 and verticalMode = "vm_gs") //This number is a guess.
		{
			set verticalMode to "vm_flare".
		}
		if(abs(emitter:distance / (emitter:altitude - altitude)) - 1 < 0.01) //This checks if the aircraft is nearly on top of the emiter; it prevents crashes when overflying it.
		{
			return list(0, "---", "THIS SHOULD NEVER BE SEEN!"). //glideslope mode is never needed when this condition is true anyway.
		}
		set angleToEmitter to arcsin((emitter:altitude - ship:altitude)/emitter:distance).
		if(abs(-angleToEmitter-selsAngle)<0.2)
		{
			if(glideslopeArmed and lateralMode = "lm_loc")
			{
				set verticalMode to "vm_gs".
				set glideslopeArmed to false. //This allows the user to easily switch out of GS mode by selecting another mode, without it automatically going back to this.
			}
		}
		set fpaForGlideslopeFollow to angleToEmitter + glideslopeFollowingMultiplier*(angleToEmitter + selsAngle). //angleToEmitter is negative.
		set fpaForGlideslopeFollow to min(fpaForGlideslopeFollow, 0). //The aircraft should never climb toward a glideslope.
		//print "angleToEmitter " + angleToEmitter.
		//print "fpaForGlideslopeFollow " + fpaForGlideslopeFollow.
		return list(fpaForGlideslopeFollow, selsName, "GS").
	}
	else
	{
		if(verticalMode = "vm_gs")
		{
			set verticalMode to "vm_fpa".
		}
		return list(0, "---", "THIS SHOULD NEVER BE SEEN!").
	}
}

declare function verticalFlareMode //This mode is not directly selectable. It becomes selected when the aircraft becomes close enough to the emitter while in glideslope mode.
{
	if(verticalMode = "vm_flare")
	{
		if(radarAltitude < 25)
		{
			set thrustMode to "tm_low".
		}
		
		if(not(detectFlight) and airspeed > 20) //upon landing
		{
			set ship:control:pilotmainthrottle to 0. //This is to make the throttle idle upon unlock.
			set thrustMode to "tm_spd".
			processor("Autopilot"):connection:sendmessage("disengage").
		}
		if(airspeed < 20) //If flare mode were to remain engaged after rollout, it would make taxiing impossible by forcing throttle to 0.
		{
			set verticalMode to "vm_fpa".
		}
	}
	
	//return list(fpaFromVerticalSpeed(tableEstimation(flareTable, radarAltitude)), "IF YOU SEE THIS THEN I AM A PROFESSIONAL IDIOT", "FLARE"). //I could not get this to work.
	
	local highFlareFPA is fpaFromVerticalSpeed(-2.1).
	local lowFlareFPA is fpaFromVerticalSpeed(-1.1).
	if(radarAltitude > 14)
	{
		return list(highFlareFPA, "IF YOU SEE THIS THEN I AM A PROFESSIONAL IDIOT", "FLARE").
	}
	else
	{
		return list(lowFlareFPA, "IF YOU SEE THIS THEN I AM A PROFESSIONAL IDIOT", "FLARE").
	}
}

//This function checks if a vertical speed is less than the vertical speed calculated by altitude hold mode.
//If yes, it switches the vertical mode to altitude hold.
//The input vertical speed can be directly taken from the mode calling it or calculated from an FPA using verticalSpeedFromFPA.
declare function altitudeCaptureCheck
{
	declare parameter conditionMode. //This should be the key of the mode from which this function is called. The check only occurs if the mode is the current mode.
	declare parameter modeVS.
	if(verticalMode = conditionMode and not(altitudeSelection = "---"))
	{
		//print "modeVS: " + modeVS. //debug
		//print "vm_alt output: " + verticalSpeedForAltitudeHold. //debug
		//print "altitudeSelection: " + altitudeSelection. //debug
		//print "altitudeHoldTarget: " + altitudeHoldTarget. //debug
		
		//print sgn(modeVS)+ " " + sgn(verticalSpeedForAltitudeHold). //debug
		if(abs(modeVS) > abs(verticalSpeedForAltitudeHold) and sgn(modeVS) = sgn(verticalSpeedForAltitudeHold) and abs(altitude - altitudeSelection) < 300) //The last condition is to prevent capturing immediately if abs(VS)>10.
		{
			set verticalMode to "vm_alt".
		}
		
		//This is mostly to prevent the user from leaving an established altitude hold with the held altitude still selected. To leave an altitude hold, the altitude selection should be changed or removed.
		if(altitudeSelection = altitudeHoldTarget and abs(altitudeSelection - altitude) < 10)
		{
			set verticalMode to "vm_alt".
		}
	}
}

declare function verticalSpeedFromFPA
{
	declare parameter modeFPA.
	return airspeed * sin(modeFPA).
}

declare function fpaFromVerticalSpeed
{
	declare parameter specifiedVS.
	if(abs(specifiedVS)>airspeed) //safety to prevent program crashes when airspeed is very low, such as on the ground.
	{
		return 0.
	}
	//print airspeed.
	local temp is arcsin(specifiedVS/airspeed).
	return temp.
}



declare function doFMSThrustModes
{
	for key in autothrustModeFunctionTable:keys
	{
		set thrustModeResultTable[key] to autothrustModeFunctionTable[key]:call.
	}
	
	set autothrustOutputString to thrustModeResultTable[thrustMode][0].
	set autothrustOutputExplanation to thrustModeResultTable[thrustMode][2].
}

declare function thrustSpeedMode
{
	return list(targetSpeed, speedModeResultTable[speedMode][1], speedModeResultTable[speedMode][2]).
}

declare function thrustHighMode
{
	return list("HIGH", speedModeResultTable[speedMode][1], speedModeResultTable[speedMode][2]).
}

declare function thrustLowMode
{
	return list("LOW", speedModeResultTable[speedMode][1], speedModeResultTable[speedMode][2]).
}



declare function doFMSSpeedModes
{
	for key in speedModeFunctionTable:keys
	{
		set speedModeResultTable[key] to speedModeFunctionTable[key]:call.
	}
	set targetSpeed to speedModeResultTable[speedMode][0].
}

declare function speedSelectedMode
{
	return list(airspeedSelection, airspeedSelection, "SEL").
}

declare function speedManagedMode
{
	local answer is 0.
	if((verticalMode = "vm_vnav" and altitude > vnavAltitudeToHold and not(vnavSubmode = "vsm_alt")) or (verticalMode = "vm_flch" and altitude > altitudeSelection)) //vnavAltitudeToHold is more correct than nextWaypointAltitude as an indication of where VNAV is going.
	{
		set answer to list(tableEstimation(vnavDescentSpeedTable, altitude), "DES", "MANAGED").
	}
	else
	{
		set answer to list(tableEstimation(vnavNormalSpeedTable, altitude), "NORM", "MANAGED").
	}
	set answer[0] to max(min(answer[0], 230), 90).
	set answer[1] to answer[1] + " " + round(answer[0]). //This is a little confusing, but it should work.
	return answer.
}



declare function doAutoBrake
{
	if(autobrakeArmed)
	{
		if(not(detectFlight))
		{
			if(airspeed > 1 and not(abort = false and throttle > 0.7)) //Automatically disengage if a probable rejected landing is detected. Abort is the reverser control.
			{
				brakes on.
			}
			else
			{
				brakes off.
				set autobrakeArmed to false.
			}
		}
	}
}

declare function doAutoSpolier
{
	if(spoilerArmed)
	{
		if(not(detectFlight))
		{
			if(airspeed > 20 and not(abort = false and throttle > 0.7)) //Automatically disengage if a probable rejected landing is detected.
			{
				rcs on.
			}
			else
			{
				rcs off.
				set spoilerArmed to false.
			}
		}
	}
}

declare function transmitOutput
{
	processor("Autopilot"):connection:sendmessage("updateTargetHeading " + lateralModeOutputHeading + " " + lateralModeOutputExplanation).
	processor("Autopilot"):connection:sendmessage("updateTargetFPA " + verticalModeOutputFPA + " " + verticalModeOutputExplanation).
	processor("Autopilot"):connection:sendmessage("updateAutoThrottleState " + autothrustOutputString + " " + autothrustOutputExplanation).

	if(needUpdateSafety)
	{
		processor("Safety"):connection:sendmessage("safetyGPWSEnable " + GPWSEnable).
		processor("Safety"):connection:sendmessage("safetyGPWSLandingMode " + GPWSLandingMode).
	}

	if(updateCoefficients)
	{
		processor("Autopilot"):connection:sendmessage("updatePID "
		+ pitchKp + " "
		+ pitchKi + " "
		+ pitchKd + " "
		+ rollKp + " "
		+ rollKi + " "
		+ rollKd + " "
		+ yawKp + " "
		+ yawKi + " "
		+ yawKd
		).
		set updateCoefficients to false.
	}

	//Reassure the autopilot and safety system that I am still alive.
	processor("Autopilot"):connection:sendmessage("FMSAlive").
	processor("Safety"):connection:sendmessage("FMSAlive").
}

declare function messaging
{
	until(core:messages:empty)
	{
		set m to core:messages:pop.
		set messageParts to m:content:split(" ").
		set messageType to messageParts[0].
		
		if(messageType = "listeningInPitch")
		{
			set autopilotListeningInPitch to (messageParts[1] = "true").
		}
		if(messageType = "AutopilotAlive")
		{
			set timeOfLastAutopilotAlive to time:seconds.
		}
	}
	
	if(time:seconds - timeOfLastAutopilotAlive > 1)
	{
		set autopilotListeningInPitch to false.
	}
}



declare function thingThatIWasTooLazyToWrite
{
	//Fine, it0uchpods...
	if(enterPressed)
	{
		if(not(buffer = "NOT ALLOWED") and not(buffer = "NAVAID NOT FOUND") and not(buffer = "WAYPOINT NOT FOUND"))
		{
			set buffer to "".
		}
	}
}


//initialize
init.

//main loop
until(false)
{
	//set quack to time:seconds. //debug
	//wait 0.
	
	clearscreen.
	updateAirspeedRate.

	handleKeystroke.
	doPages.

	checkActiveWaypointPass.
	doFMSLateralModes.
	doFMSVerticalModes.
	doFMSSpeedModes.
	doFMSThrustModes.

	doAutoBrake.
	doAutoSpolier.
	
	transmitOutput.
	messaging.
	
	thingThatIWasTooLazyToWrite.
	set enterPressed to false.
	
	//print time:seconds-quack. //debug
	wait 0.05. //The FLCH PID may have to be retuned if this is changed!
}
