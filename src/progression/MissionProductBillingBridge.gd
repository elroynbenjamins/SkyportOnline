class_name MissionProductBillingBridge
extends Node

signal purchase_requested(product_id: String, store_product_id: String)
signal restore_requested
signal purchase_verified(product_id: String, purchase_token: String)
signal unavailable(product_id: String)

var provider_connected := false
var pending_product_id := ""

func set_provider_connected(value: bool) -> void:
	provider_connected = value

func request_purchase(product_id: String) -> void:
	var product := MissionPassCatalog.product(product_id)
	if product.is_empty():
		unavailable.emit(product_id)
		return
	if not provider_connected:
		unavailable.emit(product_id)
		return
	var store_product_id := String(product.get("store_product_id", ""))
	if store_product_id.is_empty():
		unavailable.emit(product_id)
		return
	pending_product_id = product_id
	purchase_requested.emit(product_id, store_product_id)

func request_restore() -> void:
	if not provider_connected:
		unavailable.emit("")
		return
	restore_requested.emit()

func complete_purchase_from_provider(
	store_product_id: String,
	purchase_token: String
) -> void:
	if not provider_connected or purchase_token.strip_edges().is_empty():
		return
	var product := MissionPassCatalog.product_for_store_id(store_product_id)
	if product.is_empty():
		return
	var product_id := String(product.get("id", ""))
	if not pending_product_id.is_empty() and pending_product_id != product_id:
		return
	pending_product_id = ""
	purchase_verified.emit(product_id, purchase_token.strip_edges())

func complete_restore_from_provider(
	store_product_id: String,
	purchase_token: String
) -> void:
	if not provider_connected or purchase_token.strip_edges().is_empty():
		return
	var product := MissionPassCatalog.product_for_store_id(store_product_id)
	if product.is_empty():
		return
	purchase_verified.emit(
		String(product.get("id", "")),
		purchase_token.strip_edges()
	)
