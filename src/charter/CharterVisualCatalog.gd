class_name CharterVisualCatalog
extends RefCounted

const BUILDING_KEYS := [
	"cargo_charter_office",
	"cargo_warehouse",
	"logistics_gate_checkpoint",
	"cargo_aircraft_stand"
]

const SURFACE_KEYS := [
	"loading_dock_pad",
	"service_road_tile",
	"container_storage_pad",
	"pallet_sorting_yard"
]

const OPTIONAL_VEHICLE_KEYS := [
	"cargo_plane",
	"cargo_tug",
	"forklift",
	"conveyor",
	"service_pickup"
]


static func required_asset_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for key in BUILDING_KEYS:
		result.append(String(key))
	for key in SURFACE_KEYS:
		result.append(String(key))
	return result


static func world_sprite_paths(
	asset_key: String
) -> PackedStringArray:
	return PackedStringArray([
		CharterVisualPack.make_uri(asset_key, 0),
		CharterVisualPack.make_uri(asset_key, 1)
	])


static func building_visuals() -> Array[Dictionary]:
	return [
		{
			"id": "cargo_charter_office",
			"asset_key": "cargo_charter_office",
			"placement_zone": "LOGISTICS",
			"footprint": Vector2i(2, 2),
			"rotatable": true,
			"world_sprite_size": Vector2(218, 184),
			"anchor": "bottom_center",
			"bottom_anchor_lift": 4.0,
			"world_sprite_offsets": [
				Vector2(0, 0),
				Vector2(0, 0)
			]
		},
		{
			"id": "cargo_warehouse",
			"asset_key": "cargo_warehouse",
			"placement_zone": "LOGISTICS",
			"footprint": Vector2i(3, 2),
			"rotatable": true,
			"world_sprite_size": Vector2(294, 224),
			"anchor": "bottom_center",
			"bottom_anchor_lift": 6.0,
			"world_sprite_offsets": [
				Vector2(0, 0),
				Vector2(0, 0)
			]
		},
		{
			"id": "logistics_gate_checkpoint",
			"asset_key": "logistics_gate_checkpoint",
			"placement_zone": "LOGISTICS",
			"footprint": Vector2i(2, 1),
			"rotatable": true,
			"world_sprite_size": Vector2(188, 138),
			"anchor": "bottom_center",
			"bottom_anchor_lift": 3.0,
			"world_sprite_offsets": [
				Vector2(0, 0),
				Vector2(0, 0)
			]
		},
		{
			"id": "cargo_aircraft_stand",
			"asset_key": "cargo_aircraft_stand",
			"placement_zone": "LOGISTICS",
			"footprint": Vector2i(3, 3),
			"rotatable": true,
			"world_sprite_size": Vector2(300, 226),
			"anchor": "center",
			"world_sprite_offsets": [
				Vector2(0, 0),
				Vector2(0, 0)
			]
		}
	]


static func surface_visuals() -> Array[Dictionary]:
	return [
		{
			"id": "loading_dock_pad",
			"asset_key": "loading_dock_pad",
			"footprint": Vector2i(2, 1),
			"world_sprite_size": Vector2(194, 120)
		},
		{
			"id": "service_road_tile",
			"asset_key": "service_road_tile",
			"footprint": Vector2i(1, 1),
			"world_sprite_size": Vector2(104, 72)
		},
		{
			"id": "container_storage_pad",
			"asset_key": "container_storage_pad",
			"footprint": Vector2i(2, 2),
			"world_sprite_size": Vector2(210, 156)
		},
		{
			"id": "pallet_sorting_yard",
			"asset_key": "pallet_sorting_yard",
			"footprint": Vector2i(2, 2),
			"world_sprite_size": Vector2(210, 156)
		}
	]


static func visual_for(
	visual_id: String
) -> Dictionary:
	for definition in building_visuals():
		if String(definition.get("id", "")) == visual_id:
			var result := definition.duplicate(true)
			result["world_sprite_paths"] = world_sprite_paths(
				String(result.get("asset_key", ""))
			)
			return result
	for definition in surface_visuals():
		if String(definition.get("id", "")) == visual_id:
			var result := definition.duplicate(true)
			result["world_sprite_paths"] = world_sprite_paths(
				String(result.get("asset_key", ""))
			)
			return result
	return {}
