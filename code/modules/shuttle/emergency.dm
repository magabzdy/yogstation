#define TIME_LEFT (SSshuttle.emergency.timeLeft())
#define ENGINES_START_TIME 10
#define ENGINES_STARTED (TIME_LEFT <= ENGINES_START_TIME)
#define IS_DOCKED (SSshuttle.emergency.mode == SHUTTLE_DOCKED)

/obj/machinery/computer/emergency_shuttle
	name = "emergency shuttle console"
	desc = "For shuttle control."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	var/auth_need = 3
	var/list/authorized = list()
	paiAllowed = 0

/obj/machinery/computer/emergency_shuttle/attackby(obj/item/I, mob/user,params)
	if(istype(I, /obj/item/weapon/card/id))
		say("Please equip your ID card into your ID slot to authenticate.")
	. = ..()

/obj/machinery/computer/emergency_shuttle/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = human_adjacent_state)

	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "emergency_shuttle_console", name,
			400, 400, master_ui, state)
		ui.open()

/obj/machinery/computer/emergency_shuttle/ui_data()
	var/list/data = list()

	data["timer_str"] = SSshuttle.emergency.getTimerStr()
	data["engines_started"] = ENGINES_STARTED
	data["authorizations_remaining"] = max((auth_need - authorized.len), 0)
	var/list/A = list()
	for(var/i in authorized)
		var/obj/item/weapon/card/id/ID = i
		var/name = ID.registered_name
		var/job = ID.assignment

		if(emagged)
			name = Gibberish(name, 0)
			job = Gibberish(job, 0)
		A += list(list("name" = name, "job" = job))
	data["authorizations"] = A

	data["enabled"] = (IS_DOCKED && !ENGINES_STARTED)
	data["emagged"] = emagged
	return data

/obj/machinery/computer/emergency_shuttle/ui_act(action, params, datum/tgui/ui)
	if(..())
		return
	if(ENGINES_STARTED) // past the point of no return
		return
	if(!IS_DOCKED) // shuttle computer only has uses when onstation
		return

	var/mob/user = usr
	. = FALSE

	var/obj/item/weapon/card/id/ID = user.get_idcard()

	if(!ID)
		to_chat(user, "<span class='warning'>You don't have an ID.</span>")
		return

	if(!(access_heads in ID.access))
		to_chat(user, "<span class='warning'>The access level of your card is not high enough.</span>")
		return

	var/old_len = authorized.len

	switch(action)
		if("authorize")
			. = authorize(user)

		if("repeal")
			authorized -= ID

		if("abort")
			if(authorized.len)
				// Abort. The action for when heads are fighting over whether
				// to launch early.
				authorized.Cut()
				. = TRUE

	if((old_len != authorized.len) && !ENGINES_STARTED)
		var/alert = (authorized.len > old_len)
		if(authorized.len)
			minor_announce("[auth_need - authorized.len] authorizations \
				needed until shuttle is launched early", null, alert)
		else
			minor_announce("All authorizations to launch the shuttle \
				early have been revoked.")

/obj/machinery/computer/emergency_shuttle/proc/authorize(mob/user, source)
	var/obj/item/weapon/card/id/ID = user.get_idcard()

	if(ID in authorized)
		return FALSE
	for(var/i in authorized)
		var/obj/item/weapon/card/id/other = i
		if(other.registered_name == ID.registered_name)
			return FALSE // No using IDs with the same name

	authorized += ID

	message_admins("[key_name_admin(user.client)] \
		(<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) \
		(<A HREF='?_src_=holder;adminplayerobservefollow=\ref[user]'>FLW</A>) \
		has authorized early shuttle launch", 0, 1)
	log_game("[key_name(user)] has authorized early shuttle launch in \
		([x],[y],[z])")
	// Now check if we're on our way
	. = TRUE
	process()

/obj/machinery/computer/emergency_shuttle/process()
	// Launch check is in process in case auth_need changes for some reason
	// probably external.
	. = FALSE
	if(ENGINES_STARTED || (!IS_DOCKED))
		return .

	// Check to see if we've reached criteria for early launch
	if((authorized.len >= auth_need) || emagged)
		// shuttle timers use 1/10th seconds internally
		SSshuttle.emergency.setTimer(ENGINES_START_TIME * 10)
		var/system_error = emagged ? "SYSTEM ERROR:" : null
		minor_announce("The emergency shuttle will launch in \
			[ENGINES_START_TIME] seconds", system_error, alert=TRUE)
		. = TRUE

/obj/machinery/computer/emergency_shuttle/emag_act(mob/user)
	// How did you even get on the shuttle before it go to the station?
	if(!IS_DOCKED)
		return

	var/time = TIME_LEFT
	message_admins("[key_name_admin(user.client)] \
	(<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) \
	(<A HREF='?_src_=holder;adminplayerobservefollow=\ref[user]'>FLW</A>) \
	has emagged the emergency shuttle [time] seconds before launch.", 0, 1)
	log_game("[key_name(user)] has emagged the emergency shuttle in \
		([x],[y],[z]) [time] seconds before launch.")
	emagged = TRUE
	var/datum/species/S = new
	for(var/i in 1 to 10)
		// the shuttle system doesn't know who these people are, but they
		// must be important, surely
		var/obj/item/weapon/card/id/ID = new(src)
		var/datum/job/J = pick(SSjob.occupations)
		ID.registered_name = S.random_name(pick(MALE, FEMALE))
		ID.assignment = J.title

		authorized += ID

	if(ENGINES_STARTED)
		// Give them a message anyway
		to_chat(user, "<span class='warning'>The shuttle is already about to launch!</span>")
	else
		process()

/obj/machinery/computer/emergency_shuttle/Destroy()
	// Our fake IDs that the emag generated are just there for colour
	// They're not supposed to be accessible

	for(var/obj/item/weapon/card/id/ID in src)
		qdel(ID)

	. = ..()

/obj/docking_port/mobile/emergency
	name = "emergency shuttle"
	id = "emergency"

	dwidth = 9
	width = 22
	height = 11
	dir = 4
	travelDir = -90
	roundstart_move = "emergency_away"
	var/sound_played = 0 //If the launch sound has been sent to all players on the shuttle itself

/obj/docking_port/mobile/emergency/register()
	. = ..()
	SSshuttle.emergency = src

/obj/docking_port/mobile/emergency/Destroy(force)
	if(force)
		// This'll make the shuttle subsystem use the backup shuttle.
		if(src == SSshuttle.emergency)
			// If we're the selected emergency shuttle
			SSshuttle.emergencyDeregister()

	. = ..()

/obj/docking_port/mobile/emergency/timeLeft(divisor)
	if(divisor <= 0)
		divisor = 10
	if(!timer)
		return round(SSshuttle.emergencyCallTime/divisor, 1)

	var/dtime = world.time - timer
	switch(mode)
		if(SHUTTLE_ESCAPE)
			dtime = max(SSshuttle.emergencyEscapeTime - dtime, 0)
		if(SHUTTLE_DOCKED)
			dtime = max(SSshuttle.emergencyDockTime - dtime, 0)
		else
			dtime = max(SSshuttle.emergencyCallTime - dtime, 0)
	return round(dtime/divisor, 1)

/obj/docking_port/mobile/emergency/request(obj/docking_port/stationary/S, coefficient=1, area/signalOrigin, reason, redAlert)
	SSshuttle.emergencyCallTime = initial(SSshuttle.emergencyCallTime) * coefficient
	switch(mode)
		if(SHUTTLE_RECALL)
			mode = SHUTTLE_CALL
			timer = world.time - timeLeft(1)
		if(SHUTTLE_IDLE)
			mode = SHUTTLE_CALL
			timer = world.time
		if(SHUTTLE_CALL)
			if(world.time < timer)	//this is just failsafe
				timer = world.time
		else
			return

	if(prob(70))
		SSshuttle.emergencyLastCallLoc = signalOrigin
	else
		SSshuttle.emergencyLastCallLoc = null

	priority_announce("The emergency shuttle has been called. [redAlert ? "Red Alert state confirmed: Dispatching priority shuttle. " : "" ]It will arrive in [timeLeft(600)] minutes.[reason][SSshuttle.emergencyLastCallLoc ? "\n\nCall signal traced. Results can be viewed on any communications console." : "" ]", null, 'sound/AI/shuttlecalled.ogg', "Priority")

/obj/docking_port/mobile/emergency/cancel(area/signalOrigin)
	if(mode != SHUTTLE_CALL)
		return

	timer = world.time - timeLeft(1)
	mode = SHUTTLE_RECALL

	if(prob(70))
		SSshuttle.emergencyLastCallLoc = signalOrigin
	else
		SSshuttle.emergencyLastCallLoc = null
	priority_announce("The emergency shuttle has been recalled.[SSshuttle.emergencyLastCallLoc ? " Recall signal traced. Results can be viewed on any communications console." : "" ]", null, 'sound/AI/shuttlerecalled.ogg', "Priority")

/*
/obj/docking_port/mobile/emergency/findTransitDock()
	. = SSshuttle.getDock("emergency_transit")
	if(.)
		return .
	return ..()
*/


/obj/docking_port/mobile/emergency/check()
	if(!timer)
		return

	var/time_left = timeLeft(1)
	switch(mode)
		if(SHUTTLE_RECALL)
			if(time_left <= 0)
				mode = SHUTTLE_IDLE
				timer = 0
		if(SHUTTLE_CALL)
			if(time_left <= 0)
				//move emergency shuttle to station
				if(dock(SSshuttle.getDock("emergency_home")))
					setTimer(20)
					return
				mode = SHUTTLE_DOCKED
				timer = world.time
				send2irc("Server", "The Emergency Shuttle has docked with the station.")
				priority_announce("The Emergency Shuttle has docked with the station. You have [timeLeft(600)] minutes to board the Emergency Shuttle.", null, 'sound/AI/shuttledock.ogg', "Priority")
				feedback_add_details("emergency_shuttle", src.name)

				//Gangs only have one attempt left if the shuttle has docked with the station to prevent suffering from dominator delays
				for(var/datum/gang/G in ticker.mode.gangs)
					if(isnum(G.dom_timer))

						G.dom_attempts = 0
					else
						G.dom_attempts = min(1,G.dom_attempts)

		if(SHUTTLE_DOCKED)

			if(time_left <= 50 && !sound_played) //4 seconds left:REV UP THOSE ENGINES BOYS. - should sync up with the launch
				sound_played = 1 //Only rev them up once.
				for(var/area/shuttle/escape/E in world)
					E << 'sound/effects/hyperspace_begin.ogg'
					// Play the parallax animation
					parallax_launch_in_area(E, 1)

			if(time_left <= 0 && SSshuttle.emergencyNoEscape)
				priority_announce("Hostile environment detected. Departure has been postponed indefinitely pending conflict resolution.", null, 'sound/misc/notice1.ogg', "Priority")
				sound_played = 0 //Since we didn't launch, we will need to rev up the engines again next pass.
				mode = SHUTTLE_STRANDED

			if(time_left <= 0 && !SSshuttle.emergencyNoEscape)
				//move each escape pod (or applicable spaceship) to its corresponding transit dock
				for(var/A in SSshuttle.mobile)
					var/obj/docking_port/mobile/M = A
					if(M.launch_status == UNLAUNCHED) //Pods will not launch from the mine/planet, and other ships won't launch unless we tell them to.
						M.launch_status = ENDGAME_LAUNCHED
						M.enterTransit()

				//now move the actual emergency shuttle to its transit dock
				for(var/area/shuttle/escape/E in world)
					E << 'sound/effects/hyperspace_progress.ogg'
				enterTransit()
				mode = SHUTTLE_ESCAPE
				launch_status = ENDGAME_LAUNCHED
				timer = world.time
				priority_announce("The Emergency Shuttle has left the station. Estimate [timeLeft(600)] minutes until the shuttle docks at Central Command.", null, null, "Priority")
		if(SHUTTLE_ESCAPE)
			if(time_left <= 0)
				//move each escape pod to its corresponding escape dock
				for(var/A in SSshuttle.mobile)
					var/obj/docking_port/mobile/M = A
					if(M.launch_status == ENDGAME_LAUNCHED)
						if(istype(M, /obj/docking_port/mobile/pod))
							M.dock(SSshuttle.getDock("[M.id]_away")) //Escape pods dock at centcomm
						else
							continue //Mapping a new docking point for each ship mappers could potentially want docking with centcomm would take up lots of space, just let them keep flying off into the sunset for their greentext

				//now move the actual emergency shuttle to centcomm
				for(var/area/shuttle/escape/E in world)
					E << 'sound/effects/hyperspace_end.ogg'
				dock(SSshuttle.getDock("emergency_away"))
				mode = SHUTTLE_ENDGAME
				timer = 0
				open_dock()

/obj/docking_port/mobile/emergency/proc/open_dock()
	for(var/obj/machinery/door/poddoor/shuttledock/D in airlocks)
		var/turf/T = get_step(D, D.checkdir)
		if(!istype(T,/turf/open/space))
			spawn(0)
				D.open()

/obj/docking_port/mobile/pod
	name = "escape pod"
	id = "pod"
	dwidth = 1
	width = 3
	height = 4
	launch_status = UNLAUNCHED

/obj/docking_port/mobile/pod/request()
	if((security_level == SEC_LEVEL_RED || security_level == SEC_LEVEL_DELTA) && launch_status == UNLAUNCHED)
		launch_status = EARLY_LAUNCHED
		return ..()

/obj/docking_port/mobile/pod/New()
	if(id == "pod")
		WARNING("[type] id has not been changed from the default. Use the id convention \"pod1\" \"pod2\" etc.")
	..()

/obj/docking_port/mobile/pod/cancel()
	return

/obj/machinery/computer/shuttle/pod
	name = "pod control computer"
	admin_controlled = 1
	shuttleId = "pod"
	possible_destinations = "pod_asteroid"
	icon = 'icons/obj/terminals.dmi'
	icon_state = "dorm_available"
	density = 0
	clockwork = TRUE //it'd look weird

/obj/machinery/computer/shuttle/pod/update_icon()
	return

/obj/docking_port/stationary/random
	name = "escape pod"
	id = "pod"
	dwidth = 1
	width = 3
	height = 4
	var/target_area = /area/lavaland/surface/outdoors

/obj/docking_port/stationary/random/initialize()
	..()
	var/list/turfs = get_area_turfs(target_area)
	var/turf/T = pick(turfs)
	src.loc = T

//Pod suits/pickaxes


/obj/item/clothing/head/helmet/space/orange
	name = "emergency space helmet"
	icon_state = "syndicate-helm-orange"
	item_state = "syndicate-helm-orange"

/obj/item/clothing/suit/space/orange
	name = "emergency space suit"
	icon_state = "syndicate-orange"
	item_state = "syndicate-orange"
	slowdown = 3

/obj/item/weapon/pickaxe/emergency
	name = "emergency disembarkation tool"
	desc = "For extracting yourself from rough landings."

/obj/item/weapon/storage/pod
	name = "emergency space suits"
	desc = "A wall-mounted safe containing space suits. Will only open in emergencies."
	anchored = 1
	density = 0
	icon = 'icons/obj/storage.dmi'
	icon_state = "safe"

/obj/item/weapon/storage/pod/New()
	..()
	new /obj/item/clothing/head/helmet/space/orange(src)
	new /obj/item/clothing/head/helmet/space/orange(src)
	new /obj/item/clothing/suit/space/orange(src)
	new /obj/item/clothing/suit/space/orange(src)
	new /obj/item/clothing/mask/gas(src)
	new /obj/item/clothing/mask/gas(src)
	new /obj/item/weapon/tank/internals/oxygen/red(src)
	new /obj/item/weapon/tank/internals/oxygen/red(src)
	new /obj/item/weapon/pickaxe/emergency(src)
	new /obj/item/weapon/pickaxe/emergency(src)
	new /obj/item/weapon/survivalcapsule(src)

/obj/item/weapon/storage/pod/attackby(obj/item/weapon/W, mob/user, params)
	return

/obj/item/weapon/storage/pod/MouseDrop(over_object, src_location, over_location)
	if(security_level == SEC_LEVEL_RED || security_level == SEC_LEVEL_DELTA)
		return ..()
	else
		to_chat(usr, "The storage unit will only unlock during a Red or Delta security alert.")

/obj/item/weapon/storage/pod/attack_hand(mob/user)
	return

/obj/docking_port/mobile/emergency/backup
	name = "backup shuttle"
	id = "backup"
	dwidth = 2
	width = 8
	height = 8
	dir = 4

	roundstart_move = "backup_away"

/obj/docking_port/mobile/emergency/backup/New()
	// We want to be a valid emergency shuttle
	// but not be the main one, keep whatever's set
	// valid.
	// backup shuttle ignores `timid` because THERE SHOULD BE NO TOUCHING IT
	var/current_emergency = SSshuttle.emergency
	..()
	SSshuttle.emergency = current_emergency
	SSshuttle.backup_shuttle = src

#undef UNLAUNCHED
#undef LAUNCHED
#undef EARLY_LAUNCHED
#undef TIMELEFT
#undef ENGINES_START_TIME
#undef ENGINES_STARTED
#undef IS_DOCKED
