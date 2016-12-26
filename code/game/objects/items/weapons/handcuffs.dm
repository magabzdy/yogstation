/obj/item/weapon/restraints
	breakouttime = 600

//Handcuffs

/obj/item/weapon/restraints/handcuffs
	name = "handcuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "handcuff"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	throwforce = 0
	w_class = 2
	throw_speed = 3
	throw_range = 5
	materials = list(MAT_METAL=500)
	origin_tech = "engineering=3;combat=3"
	breakouttime = 600 //Deciseconds = 60s = 1 minute
	var/cuffsound = 'sound/weapons/handcuffs.ogg'
	var/trashtype = null //for disposable cuffs

/obj/item/weapon/restraints/handcuffs/attack(mob/living/carbon/C, mob/living/carbon/human/user)
	if(!istype(C))
		return
	if(user.disabilities & CLUMSY && prob(50))
		user << "<span class='warning'>Uh... how do those things work?!</span>"
		apply_cuffs(user,user)
		return

	if(C.dna.species.id == "abomination")
		user <<"<span class='warning'>[C] doesn't have much hands to speak of!</span>"
		return

	if(!C.handcuffed)
		if(C.get_num_arms() >= 2)
			add_logs(user, C, "attempted to handcuff")
			C.visible_message("<span class='danger'>[user] is trying to put [src.name] on [C]!</span>", \
								"<span class='userdanger'>[user] is trying to put [src.name] on [C]!</span>")

			playsound(loc, cuffsound, 30, 1, -2)
			if(do_mob(user, C, 30) && C.get_num_arms() >= 2)
				if(C.dna.species.id == "abomination")
					user <<"<span class='warning'>[C] doesn't have much hands to speak of!</span>"
					return
				apply_cuffs(C,user)
				user << "<span class='notice'>You handcuff [C].</span>"
				if(istype(src, /obj/item/weapon/restraints/handcuffs/cable))
					feedback_add_details("handcuffs","C")
				else
					feedback_add_details("handcuffs","H")

				add_logs(user, C, "handcuffed")
			else
				user << "<span class='warning'>You fail to handcuff [C]!</span>"
		else
			user << "<span class='warning'>[C] doesn't have two hands...</span>"

/obj/item/weapon/restraints/handcuffs/proc/apply_cuffs(mob/living/carbon/target, mob/user, var/dispense = 0)
	if(target.handcuffed)
		return

	if(!user.drop_item() && !dispense)
		return

	var/obj/item/weapon/restraints/handcuffs/cuffs = src
	if(trashtype)
		cuffs = new trashtype()
	else if(dispense)
		cuffs = new type()

	cuffs.loc = target
	target.handcuffed = cuffs

	target.update_handcuffed()
	if(trashtype && !dispense)
		qdel(src)
	return

/obj/item/weapon/restraints/handcuffs/sinew
	name = "sinew restraints"
	desc = "A pair of restraints fashioned from long strands of flesh."
	icon = 'icons/obj/mining.dmi'
	icon_state = "sinewcuff"
	item_state = "sinewcuff"
	breakouttime = 300 //Deciseconds = 30s
	cuffsound = 'sound/weapons/cablecuff.ogg'

/obj/item/weapon/restraints/handcuffs/cable
	name = "cable restraints"
	desc = "Looks like some cables tied together. Could be used to tie something up."
	icon_state = "cuff_cable"
	item_state = "coil_red"
	materials = list(MAT_METAL=150, MAT_GLASS=75)
	origin_tech = "engineering=2"
	breakouttime = 300 //Deciseconds = 30s
	cuffsound = 'sound/weapons/cablecuff.ogg'
	var/datum/robot_energy_storage/wirestorage = null

/obj/item/weapon/restraints/handcuffs/cable/attack(mob/living/carbon/C, mob/living/carbon/human/user)
	if(!istype(C))
		return
	if(wirestorage && wirestorage.energy < 15)
		user << "<span class='warning'>You need at least 15 wire to restrain [C]!</span>"
		return
	return ..()

/obj/item/weapon/restraints/handcuffs/cable/apply_cuffs(mob/living/carbon/target, mob/user, var/dispense = 0)
	if(wirestorage)
		if(!wirestorage.use_charge(15))
			user << "<span class='warning'>You need at least 15 wire to restrain [target]!</span>"
			return
		return ..(target, user, 1)

	return ..()

/obj/item/weapon/restraints/handcuffs/cable/attack_self(mob/user)
		var/obj/item/stack/cable_coil/new_coil = new /obj/item/stack/cable_coil
		new_coil.amount = 15
		qdel(src)
		new_coil.item_color = item_color
		new_coil.update_icon()
		usr.put_in_hands(new_coil)
		usr.visible_message("<span class='notice'>[user.name] unties the knot holding together [src].</span>")

/obj/item/weapon/restraints/handcuffs/cable/update_icon()
	color = color2code(item_color)
	item_state = "coil_[item_color]"

/obj/item/weapon/restraints/handcuffs/alien
	icon_state = "handcuffAlien"

/obj/item/weapon/restraints/handcuffs/fake
	name = "fake handcuffs"
	desc = "Fake handcuffs meant for gag purposes."
	breakouttime = 10 //Deciseconds = 1s

/obj/item/weapon/restraints/handcuffs/fake/kinky
	name = "kinky handcuffs"
	desc = "Fake handcuffs meant for erotic roleplay."
	icon_state = "handcuffGag"

/obj/item/weapon/restraints/handcuffs/cable/attackby(obj/item/I, mob/user, params)
	..()
	if(istype(I, /obj/item/stack/rods))
		var/obj/item/stack/rods/R = I
		if (R.use(1))
			var/obj/item/weapon/wirerod/W = new /obj/item/weapon/wirerod
			if(!remove_item_from_storage(user))
				user.unEquip(src)
			user.put_in_hands(W)
			user << "<span class='notice'>You wrap the cable restraint around the top of the rod.</span>"
			qdel(src)
		else
			user << "<span class='warning'>You need one rod to make a wired rod!</span>"
			return
	else if(istype(I, /obj/item/stack/sheet/metal))
		var/obj/item/stack/sheet/metal/M = I
		if(M.amount < 6)
			user << "<span class='warning'>You need at least six metal sheets to make good enough weights!</span>"
			return
		user << "<span class='notice'>You begin to apply [I] to [src]...</span>"
		if(do_after(user, 35, target = src))
			var/obj/item/weapon/restraints/legcuffs/bola/S = new /obj/item/weapon/restraints/legcuffs/bola
			M.use(6)
			user.put_in_hands(S)
			user << "<span class='notice'>You make some weights out of [I] and tie them to [src].</span>"
			if(!remove_item_from_storage(user))
				user.unEquip(src)
			qdel(src)
	else
		return ..()

/obj/item/weapon/restraints/handcuffs/cable/zipties/cyborg/attack(mob/living/carbon/C, mob/user)
	if(isrobot(user))
		if(!C.handcuffed)
			playsound(loc, 'sound/weapons/cablecuff.ogg', 30, 1, -2)
			C.visible_message("<span class='danger'>[user] is trying to put zipties on [C]!</span>", \
								"<span class='userdanger'>[user] is trying to put zipties on [C]!</span>")
			if(do_mob(user, C, 30))
				if(!C.handcuffed)
					C.handcuffed = new /obj/item/weapon/restraints/handcuffs/cable/zipties/used(C)
					C.update_handcuffed()
					user << "<span class='notice'>You handcuff [C].</span>"
					add_logs(user, C, "handcuffed")
			else
				user << "<span class='warning'>You fail to handcuff [C]!</span>"

/obj/item/weapon/restraints/handcuffs/cable/zipties
	name = "zipties"
	desc = "Plastic, disposable zipties that can be used to restrain temporarily but are destroyed after use."
	icon_state = "cuff_cable"
	item_state = "coil_white"
	materials = list()
	breakouttime = 450 //Deciseconds = 45s
	trashtype = /obj/item/weapon/restraints/handcuffs/cable/zipties/used

/obj/item/weapon/restraints/handcuffs/cable/zipties/used
	desc = "A pair of broken zipties."
	icon_state = "cuff_white_used"

/obj/item/weapon/restraints/handcuffs/cable/zipties/used/attack()
	return


/obj/item/weapon/restraints/handcuffs/cable/zipties/attack_self(mob/user)
	return


//Legcuffs

/obj/item/weapon/restraints/legcuffs
	name = "leg cuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "handcuff"
	flags = CONDUCT
	throwforce = 0
	w_class = 3
	origin_tech = "engineering=3;combat=3"
	slowdown = 7
	breakouttime = 300	//Deciseconds = 30s = 0.5 minute

/obj/item/weapon/restraints/legcuffs/beartrap
	name = "bear trap"
	throw_speed = 1
	throw_range = 1
	icon_state = "beartrap"
	desc = "A trap used to catch bears and other legged creatures."
	origin_tech = "engineering=4"
	var/armed = 0
	var/trap_damage = 20

/obj/item/weapon/restraints/legcuffs/beartrap/New()
	..()
	icon_state = "[initial(icon_state)][armed]"

/obj/item/weapon/restraints/legcuffs/beartrap/suicide_act(mob/user)
	user.visible_message("<span class='suicide'>[user] is sticking \his head in the [src.name]! It looks like \he's trying to commit suicide.</span>")
	playsound(loc, 'sound/weapons/bladeslice.ogg', 50, 1, -1)
	return (BRUTELOSS)

/obj/item/weapon/restraints/legcuffs/beartrap/attack_self(mob/user)
	..()
	if(ishuman(user) && !user.stat && !user.restrained())
		armed = !armed
		icon_state = "[initial(icon_state)][armed]"
		user << "<span class='notice'>[src] is now [armed ? "armed" : "disarmed"]</span>"

/obj/item/weapon/restraints/legcuffs/beartrap/Crossed(AM as mob|obj)
	if(armed && isturf(src.loc))
		if(isliving(AM))
			var/mob/living/L = AM
			var/snap = 0
			var/def_zone = "chest"
			if(iscarbon(L))
				var/mob/living/carbon/C = L
				snap = 1
				if(!C.lying)
					def_zone = pick("l_leg", "r_leg")
					if(!C.legcuffed && C.get_num_legs() >= 2) //beartrap can't cuff your leg if there's already a beartrap or legcuffs, or you don't have two legs.
						C.legcuffed = src
						src.loc = C
						C.update_inv_legcuffed()
						feedback_add_details("handcuffs","B") //Yes, I know they're legcuffs. Don't change this, no need for an extra variable. The "B" is used to tell them apart.
			else if(isanimal(L))
				var/mob/living/simple_animal/SA = L
				if(!SA.flying && SA.mob_size > MOB_SIZE_TINY)
					snap = 1
			if(snap)
				armed = 0
				icon_state = "[initial(icon_state)][armed]"
				playsound(src.loc, 'sound/effects/snap.ogg', 50, 1)
				L.visible_message("<span class='danger'>[L] triggers \the [src].</span>", \
						"<span class='userdanger'>You trigger \the [src]!</span>")
				L.apply_damage(trap_damage,BRUTE, def_zone)
	..()

/obj/item/weapon/restraints/legcuffs/beartrap/energy
	name = "energy snare"
	armed = 1
	icon_state = "e_snare"
	trap_damage = 0
	flags = DROPDEL

/obj/item/weapon/restraints/legcuffs/beartrap/energy/New()
	..()
	addtimer(src, "dissipate", 100)

/obj/item/weapon/restraints/legcuffs/beartrap/energy/proc/dissipate()
	if(!istype(loc, /mob))
		var/datum/effect_system/spark_spread/sparks = new /datum/effect_system/spark_spread
		sparks.set_up(1, 1, src)
		sparks.start()
		qdel(src)

/obj/item/weapon/restraints/legcuffs/beartrap/energy/attack_hand(mob/user)
	Crossed(user) //honk

/obj/item/weapon/restraints/legcuffs/beartrap/energy/cyborg
	breakouttime = 20 // Cyborgs shouldn't have a strong restraint

/obj/item/weapon/restraints/legcuffs/bola
	name = "bola"
	desc = "A restraining device designed to be thrown at the target. Upon connecting with said target, it will wrap around their legs, making it difficult for them to move quickly."
	icon_state = "bola"
	breakouttime = 35//easy to apply, easy to break out of
	gender = NEUTER
	origin_tech = "engineering=3;combat=1"
	var/weaken = 0

/obj/item/weapon/restraints/legcuffs/bola/throw_impact(atom/hit_atom)
	if(..() || !iscarbon(hit_atom))//if it gets caught or the target can't be cuffed,
		return//abort
	var/mob/living/carbon/C = hit_atom
	if(!C.legcuffed && C.get_num_legs() >= 2)
		visible_message("<span class='danger'>\The [src] ensnares [C]!</span>")
		C.legcuffed = src
		src.loc = C
		C.update_inv_legcuffed()
		feedback_add_details("handcuffs","B")
		C << "<span class='userdanger'>\The [src] ensnares you!</span>"
		C.Weaken(weaken)

/obj/item/weapon/restraints/legcuffs/bola/tactical//traitor variant
	name = "reinforced bola"
	desc = "A strong bola, made with a long steel chain. It looks heavy, enough so that it could trip somebody."
	icon_state = "bola_r"
	breakouttime = 70
	origin_tech = "engineering=4;combat=3"
	weaken = 1

/obj/item/weapon/restraints/legcuffs/bola/sec // security variant
	name = "electric bola"
	desc = "A restraining device designed to restrain targets, and give them punishment for moving. Activate in hand before use."
	weaken = 2
	breakouttime = 80
	var/charges = 6
	var/accessed
	var/used

/obj/item/weapon/restraints/legcuffs/bola/sec/attack_self(mob/user)
	if(!(ishuman(user)))
		return

	var/mob/living/carbon/human/H = user
	var/obj/item/weapon/card/id/I = H.get_idcard()

	if(!I)
		user << "<span class='warning'>You need ID to operate [src]!</span>"
		return

	if((1 in I.access))
		accessed = !accessed
		user << "<span class='notice'>You toggle [src] [accessed ? "on" : "off"].</span>"
	else
		user << "<span class='warning'>You don't have the access to use this!</span>"
		if(isliving(user))
			var/mob/living/L = user
			L.electrocute_act(1, "[src]")
			L.Weaken(1)
			PoolOrNew(/obj/effect/particle_effect/sparks, loc)

/obj/item/weapon/restraints/legcuffs/bola/sec/throw_impact(atom/hit_atom)
	if(used)
		visible_message("[src] knocks into [hit_atom]. It has already been used")
		return

	if(iscarbon(hit_atom))
		if(!accessed)
			visible_message("<span class='warning'>[src] hits [hit_atom], but is knocked over. [src] is offline!</span>")
			return

	if(..())
		used = TRUE
		accessed = FALSE

/obj/item/weapon/restraints/legcuffs/bola/sec/cuff_act(mob/user)
	if(user)
		PoolOrNew(/obj/effect/particle_effect/sparks, loc)
		if(!charges)
			user << "<span class='warning'>As [src] slowly diminishes your legs feel a whole lot lighter... AND THAN ZAP!</span>"
			qdel(src)
		if(iscarbon(user))
			var/mob/living/carbon = user
			user << 'sound/magic/lightningbolt.ogg'
			playsound(get_turf(user), 'sound/weapons/taser.ogg', 50, 1)
			carbon << "<span class='warning'>[src] goes off shooting an electric shock wave up your body!</spam>"
			carbon.Stun(5)
			carbon.Weaken(5)
			carbon.apply_effect(STUTTER, 5)
			carbon.do_jitter_animation(50)
			carbon.electrocute_act(2, "[src]")
			charges--