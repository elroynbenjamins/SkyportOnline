extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var ambient := AirportAmbientLife.new()
	root.add_child(ambient)
	ambient.configure(grid)
	await process_frame

	var medium := CareerAircraft.new()
	root.add_child(medium)
	await process_frame
	medium.configure_aircraft_type("nimbus_n40")

	if medium.aircraft_size != "M":
		_fail("Nimbus should remain M-class for choreography testing.")
		return

	medium._set_state("WAITING_UNLOAD")
	var snapshot := ambient.get_apron_choreography_snapshot(medium)
	if not bool(snapshot.get("medium_heavy", false)):
		_fail("M-class choreography should identify the heavier apron profile.")
		return
	if int(snapshot.get("prop_count", 0)) != 4:
		_fail("M-class WAITING_UNLOAD should stage four visible apron pieces.")
		return
	if int(snapshot.get("crew_count", 0)) != 1:
		_fail("M-class WAITING_UNLOAD should keep one attendant before the tap.")
		return

	medium._set_state("UNLOADING")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 7:
		_fail("M-class unloading should stage seven apron pieces.")
		return
	if int(snapshot.get("crew_count", 0)) != 4:
		_fail("M-class active unloading should use four crew.")
		return
	if int(snapshot.get("cargo_units", 0)) != 2:
		_fail("M-class unloading should show two cargo/ULD units.")
		return

	medium._set_state("WAITING_SERVICE")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 4:
		_fail("M-class WAITING_SERVICE should remain visibly busier than S-class.")
		return

	medium._set_state("SERVICING")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 6:
		_fail("M-class servicing should stage six apron pieces.")
		return
	if int(snapshot.get("support_units", 0)) != 2:
		_fail("M-class service should show GPU plus an extra support vehicle.")
		return
	if int(snapshot.get("crew_count", 0)) != 4:
		_fail("M-class servicing should keep four active crew.")
		return

	medium._set_state("WAITING_PASSENGERS")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 4:
		_fail("M-class LOAD gate should retain four staged apron pieces.")
		return

	medium._set_state("LOADING")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 7:
		_fail("M-class loading should return to the seven-piece active setup.")
		return
	if int(snapshot.get("cargo_units", 0)) != 2:
		_fail("M-class loading should stage two ULD/cargo units.")
		return

	medium._set_state("READY_FOR_DEPARTURE")
	snapshot = ambient.get_apron_choreography_snapshot(medium)
	if int(snapshot.get("prop_count", 0)) != 3:
		_fail("M-class SEND gate should leave a three-piece safety/pushback setup.")
		return
	if not bool(snapshot.get("marshaller", false)):
		_fail("M-class SEND gate should retain a marshaller.")
		return

	var small := CareerAircraft.new()
	root.add_child(small)
	await process_frame
	small.configure_aircraft_type("pico_p8")
	small._set_state("UNLOADING")
	var small_snapshot := ambient.get_apron_choreography_snapshot(small)
	if int(small_snapshot.get("prop_count", 0)) != 5:
		_fail("S-class unloading density should stay unchanged.")
		return
	if int(small_snapshot.get("crew_count", 0)) != 2:
		_fail("S-class crew density should stay unchanged.")
		return

	if AirportAmbientLife.MAX_APRON_PROPS > 22:
		_fail("M-class density pass should keep the mobile apron prop cap bounded.")
		return
	if AirportAmbientLife.MAX_CREW > 14:
		_fail("M-class density pass should keep the mobile crew cap bounded.")
		return

	print(
		"M_CLASS_TURNAROUND_CHOREOGRAPHY_OK unload=7 service=6 load=7 "
		+ "crew=4 s_class_unchanged=true caps_bounded=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
