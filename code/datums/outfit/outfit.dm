/*
 * Outfit datums
 * For equipping characters with special provisions for race and so on
 *

	VARS :
	- items_to_spawn: items to spawn, arranged if needed by race.
	  "Default" is the list of items for humans.
	- use_pref_bag: if we use the backpack he has in prefs, or if we give him a standard backpack.
	- equip_survival_gear: if we give him the basic survival gear.
	- items_to_collect: item to put in the backbag
		The associative key is for when to put it if we have no backbag.

	PROCS :
	-- "Static" procs
		- equip(var/mob/living/carbon/human/H) : tries to equip everything on the list to the relevant slots

	-- Procs you can override
		- misc_stuff(var/mob/living/carbon/human/H) : for things like implants.

*/

/datum/outfit/
	var/outfit_name = "Abstract outfit datum"

	var/associated_job = null

	var/list/items_to_spawn = list(
		"Default" = list(),
	)

	var/list/backpack_types = list(
		BACKPACK_STRING = null,
		SATCHEL_NORM_STRING = null,
		SATCHEL_ALT_STRING = null,
		MESSENGER_BAG_STRING = null,
	)

	var/use_pref_bag = TRUE
	var/give_disabilities_equipement = TRUE
	var/equip_survival_gear = SURVIVAL_NORMAL

	var/list/items_to_collect = list()

	var/list/implant_types = list()

	var/pda_slot 
	var/pda_type = null
	var/id_type = null

/datum/outfit/New()
	return

/datum/outfit/proc/pre_equip(var/mob/living/carbon/human/H)
	return

/datum/outfit/proc/equip(var/mob/living/carbon/human/H)
	if (!H || !H.mind)
		return
	
	pre_equip(H)
	var/species = H.species.type
	var/list/L = items_to_spawn[species]
	if (!L) // Couldn't find the particular species
		L = items_to_spawn["Default"]

	for (var/slot in L)
		var/obj_type = L[slot]
		if (islist(obj_type))
			var/list/L2 = obj_type
			obj_type = L2[H.mind.role_alt_title]
		if (!obj_type)
			continue
		slot = text2num(slot)
		H.equip_to_slot_or_del(new obj_type(H), slot, TRUE)

	equip_backbag(H)

	for (var/imp_type in implant_types)
		var/obj/item/weapon/implant/I = new imp_type(H)
		I.imp_in = H
		I.implanted = 1
		var/datum/organ/external/affected = H.get_organ(LIMB_HEAD) // By default, all implants go to the head.
		affected.implants += I
		I.part = affected

	species_final_equip(H)
	spawn_id(H)
	post_equip(H) // Accessories, IDs, etc.
	give_disabilities_equipement(H)
	H.update_icons()

/datum/outfit/proc/equip_backbag(var/mob/living/carbon/human/H)
	// -- Backbag
	var/obj/item/chosen_backpack = null
	if (use_pref_bag)
		var/backbag_string = num2text(H.backbag)
		chosen_backpack = backpack_types[backbag_string]
	else
		chosen_backpack = backpack_types[BACKPACK_STRING]

	// -- The (wo)man has a backpack, let's put stuff in them

	if (chosen_backpack)
		H.equip_to_slot_or_del(new chosen_backpack(H), slot_back, 1)
		for (var/item in items_to_collect)
			var/item_type = item
			if (islist(item)) // For alt-titles.
				item_type = item[H.mind.role_alt_title]
			H.equip_or_collect(new item_type(H.back), slot_in_backpack)
		if (equip_survival_gear)
			if (ispath(equip_survival_gear))
				H.equip_or_collect(new equip_survival_gear(H.back), slot_in_backpack)
			else
				H.equip_or_collect(new H.species.survival_gear(H.back), slot_in_backpack)

	// -- No backbag, let's improvise
	
	else
		var/obj/item/weapon/storage/box/survival/pack
		if (equip_survival_gear)
			if (ispath(equip_survival_gear))
				pack = new equip_survival_gear(H)
				H.put_in_hand(GRASP_RIGHT_HAND, pack)
			else
				pack = new H.species.survival_gear(H)
				H.put_in_hand(GRASP_RIGHT_HAND, pack)
		for (var/item in items_to_collect)
			if (items_to_collect[item] == "Surival Box" && pack)
				new item(pack)
			else
				var/hand_slot = text2num(items_to_collect[item])
				if (hand_slot) // ie, if it's an actual number
					H.put_in_hand(hand_slot, new item)
				else // It's supposed to be in the survival box or something
					new item(H)

/datum/outfit/proc/species_final_equip(var/mob/living/carbon/human/H)
	if (H.species)
		H.species.final_equip(H)

/datum/outfit/proc/spawn_id(var/mob/living/carbon/human/H, rank)
	if (!associated_job)
		CRASH("Outfit [outfit_name] has no associated job, and the proc to spawn the ID is not overriden.")
	var/datum/job/concrete_job = new associated_job

	var/obj/item/weapon/card/id/C
	C = new id_type(H)
	C.access = concrete_job.get_access()
	C.registered_name = H.real_name
	C.rank = rank
	C.assignment = H.mind.role_alt_title
	C.name = "[C.registered_name]'s ID Card ([C.assignment])"
	C.associated_account_number = H.mind.initial_account.account_number
	H.equip_or_collect(C, slot_wear_id)
		
	if (pda_type)
		var/obj/item/device/pda/pda = new pda_type
		pda.owner = H.real_name
		pda.ownjob = C.assignment
		pda.name = "PDA-[H.real_name] ([pda.ownjob])"
		H.equip_or_collect(pda, pda_slot)


/datum/outfit/proc/post_equip(var/mob/living/carbon/human/H)
	return // Empty

// -- Work in progress !!
/datum/outfit/proc/give_disabilities_equipement(var/mob/living/carbon/human/H)
	if (!give_disabilities_equipement)
		return
	
	return 1

// Strike teams have 2 particularities : a leader, and several specialised roles.
// Give the concrete (instancied) outfit datum the right "specialisation" after the player made his choice.
// Then, call "equip_special_items(player)" to give him the items associated.

/datum/outfit/striketeam/
	give_disabilities_equipement = FALSE
	var/is_leader = FALSE

	var/list/specs = list()

	var/chosen_spec = null

/datum/outfit/striketeam/proc/equip_special_items(var/mob/living/carbon/human/H)
	if (!chosen_spec)
		return

	if (!(chosen_spec in specs))
		CRASH("Trying to give [chosen_spec] to [H], but cannot find this spec in [src.type].")

	var/list/to_equip = specs[chosen_spec]

	for (var/slot_str in to_equip)
		var/equipement = to_equip[slot_str]

		switch (slot_str)
			if (ACCESSORY_ITEM) // It's an accesory. We put it in their hands if possible.
				H.put_in_hands(new equipement(H))

			else // It's a concrete item.
				var/slot = text2num(slot_str) // slots stored are STRINGS.

				if (islist(equipement)) // List of things to equip
					for (var/item in equipement)
						for (var/i = 1 to equipement[item]) // Give them this much of that item
							var/concrete_item = new item(H)
							if (!H.equip_to_slot_or_drop(concrete_item, slot)) // Can't put them in the designate slot ? Put it in their hands.
								H.put_in_hands(concrete_item)
				else
					var/concrete_item = new equipement(H)
					if (!H.equip_to_slot_or_drop(concrete_item, slot))
						H.put_in_hands(concrete_item)