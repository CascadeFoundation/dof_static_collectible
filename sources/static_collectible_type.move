module dof_static_collectible::static_collectible_type;

use blob_utils::blob_utils::blob_id_b64_to_u256;
use cascade_protocol::mint_cap::MintCap;
use dos_collection::collection::{Self, Collection, CollectionAdminCap};
use dos_static_collectible::static_collectible::{Self, StaticCollectible};
use std::string::String;
use sui::display;
use sui::package::{Self, Publisher};
use sui::transfer::Receiving;
use sui::vec_map::VecMap;

//=== Aliases ===

public use fun collectible_name as StaticCollectibleType.name;
public use fun collectible_number as StaticCollectibleType.number;
public use fun collectible_description as StaticCollectibleType.description;
public use fun collectible_image_uri as StaticCollectibleType.image_uri;
public use fun collectible_attributes as StaticCollectibleType.attributes;
public use fun collectible_provenance_hash as StaticCollectibleType.provenance_hash;

//=== Structs ===

public struct STATIC_COLLECTIBLE_TYPE has drop {}

public struct InitializeCollectionCap has key, store {
    id: UID,
}

// A wrapper type around StaticCollectibleType that provides control over a unique type.
public struct StaticCollectibleType has key, store {
    id: UID,
    collection_id: ID,
    collectible: StaticCollectible,
}

//=== Constants ===

const COLLECTION_NAME: vector<u8> = b"<COLLECTION_NAME>";
const COLLECTION_DESCRIPTION: vector<u8> = b"<COLLECTION_DESCRIPTION>";
const COLLECTION_EXTERNAL_URL: vector<u8> = b"<COLLECTION_EXTERNAL_URL>";
const COLLECTION_IMAGE_URI: vector<u8> = b"<COLLECTION_IMAGE_URI>";
const COLLECTION_TOTAL_SUPPLY: u64 = 0;

//=== Errors ===

const EInvalidCollectionAdminCap: u64 = 0;

//=== Init Function ===

#[allow(lint(freeze_wrapped))]
fun init(otw: STATIC_COLLECTIBLE_TYPE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut display = display::new<StaticCollectibleType>(&publisher, ctx);
    display.add(b"collection_id".to_string(), b"{collection_id}".to_string());
    display.add(b"name".to_string(), b"{collectible.name}".to_string());
    display.add(b"number".to_string(), b"{collectible.number}".to_string());
    display.add(b"description".to_string(), b"{collectible.description}".to_string());
    display.add(b"external_url".to_string(), b"{collectible.external_url}".to_string());
    display.add(b"image_uri".to_string(), b"{collectible.image_uri}".to_string());
    display.add(b"attributes".to_string(), b"{collectible.attributes}".to_string());

    let initialize_collection_cap = InitializeCollectionCap {
        id: object::new(ctx),
    };

    transfer::public_transfer(display, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(initialize_collection_cap, ctx.sender());
}

//=== Public Function ===

// Create a Collection!
public fun initialize(
    initialize_collection_cap: InitializeCollectionCap,
    mint_cap: MintCap<Collection>,
    publisher: &Publisher,
    ctx: &mut TxContext,
): (Collection, CollectionAdminCap) {
    let (collection, collection_admin_cap) = collection::new<StaticCollectibleType>(
        mint_cap,
        publisher,
        @creator,
        COLLECTION_NAME.to_string(),
        COLLECTION_DESCRIPTION.to_string(),
        COLLECTION_EXTERNAL_URL.to_string(),
        COLLECTION_IMAGE_URI.to_string(),
        COLLECTION_TOTAL_SUPPLY,
        ctx,
    );

    let InitializeCollectionCap { id } = initialize_collection_cap;
    id.delete();

    (collection, collection_admin_cap)
}

// Create a new PFP.
public fun new(
    collection_admin_cap: &CollectionAdminCap,
    mint_cap: MintCap<StaticCollectible>,
    name: String,
    description: String,
    external_url: String,
    provenance_hash: String,
    collection: &mut Collection,
    ctx: &mut TxContext,
): StaticCollectibleType {
    collection.assert_state_initialized();

    let collectible_type = StaticCollectibleType {
        id: object::new(ctx),
        collection_id: object::id(collection),
        collectible: static_collectible::new(
            mint_cap,
            name,
            collection.current_supply() + 1,
            description,
            external_url,
            provenance_hash,
        ),
    };
    collection.register_item(
        collection_admin_cap,
        collectible_type.collectible.number(),
        &collectible_type,
    );

    collectible_type
}

// Create a new PFP and reveal it immediately.
// This function is useful for situations where a PFP is not held in a shared object that
// can be accessed by the creator and buyer before the reveal.
public fun new_revealed(
    cap: &CollectionAdminCap,
    mint_cap: MintCap<StaticCollectible>,
    name: String,
    description: String,
    external_url: String,
    provenance_hash: String,
    attribute_keys: vector<String>,
    attribute_values: vector<String>,
    image_uri: String,
    collection: &mut Collection,
    ctx: &mut TxContext,
): StaticCollectibleType {
    collection.assert_state_initialized();

    let mut collectible_type = StaticCollectibleType {
        id: object::new(ctx),
        collection_id: object::id(collection),
        collectible: static_collectible::new(
            mint_cap,
            name,
            collection.current_supply() + 1,
            description,
            external_url,
            provenance_hash,
        ),
    };

    // Call reveal() directly.
    reveal(
        &mut collectible_type,
        cap,
        attribute_keys,
        attribute_values,
        image_uri,
        collection,
    );

    collection.register_item(
        cap,
        collectible_type.collectible.number(),
        &collectible_type,
    );

    collectible_type
}

public fun receive<T: key + store>(
    self: &mut StaticCollectibleType,
    obj_to_receive: Receiving<T>,
): T {
    transfer::public_receive(&mut self.id, obj_to_receive)
}

// Reveal a PFP with attributes keys, attribute values, and an image URI.
public fun reveal(
    self: &mut StaticCollectibleType,
    cap: &CollectionAdminCap,
    attribute_keys: vector<String>,
    attribute_values: vector<String>,
    image_uri: String,
    collection: &mut Collection,
) {
    assert!(cap.collection_id() == self.collection_id, EInvalidCollectionAdminCap);

    collection.assert_blob_reserved(blob_id_b64_to_u256(self.collectible.image_uri()));
    self.collectible.reveal(attribute_keys, attribute_values, image_uri);
}

//=== View Functions ===

public fun collection_id(self: &StaticCollectibleType): ID {
    self.collection_id
}

public fun collectible_number(self: &StaticCollectibleType): u64 {
    self.collectible.number()
}

public fun collectible_name(self: &StaticCollectibleType): String {
    self.collectible.name()
}

public fun collectible_description(self: &StaticCollectibleType): String {
    self.collectible.description()
}

public fun collectible_image_uri(self: &StaticCollectibleType): String {
    self.collectible.image_uri()
}

public fun collectible_attributes(self: &StaticCollectibleType): VecMap<String, String> {
    self.collectible.attributes()
}

public fun collectible_provenance_hash(self: &StaticCollectibleType): String {
    self.collectible.provenance_hash()
}
