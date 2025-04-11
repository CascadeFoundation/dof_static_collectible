module dof_static_collectible::static_collectible_type;

use blob_utils::blob_utils::b64_to_u256;
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
public use fun collectible_image as StaticCollectibleType.image;
public use fun collectible_animation_url as StaticCollectibleType.animation_url;
public use fun collectible_external_url as StaticCollectibleType.external_url;
public use fun collectible_attributes as StaticCollectibleType.attributes;

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

//=== Bulk Functions ===

const EInvalidNamesQuantity: u64 = 0;
const EInvalidDescriptionsQuantity: u64 = 1;
const EInvalidImagesQuantity: u64 = 2;
const EInvalidAnimationUrlsQuantity: u64 = 3;
const EInvalidExternalUrlsQuantity: u64 = 4;
const EInvalidAttributeKeysQuantity: u64 = 5;
const EInvalidAttributeValuesQuantity: u64 = 6;

public fun new_bulk(
    collection_admin_cap: &CollectionAdminCap,
    mut mint_caps: vector<MintCap<StaticCollectible>>,
    mut names: vector<String>,
    mut descriptions: vector<String>,
    mut images: vector<String>,
    mut animation_urls: vector<String>,
    mut external_urls: vector<String>,
    collection: &mut Collection,
    ctx: &mut TxContext,
): vector<StaticCollectibleType> {
    let quantity = mint_caps.length();

    assert!(names.length() == quantity, EInvalidNamesQuantity);
    assert!(descriptions.length() == quantity, EInvalidDescriptionsQuantity);
    assert!(images.length() == quantity, EInvalidImagesQuantity);
    assert!(animation_urls.length() == quantity, EInvalidAnimationUrlsQuantity);
    assert!(external_urls.length() == quantity, EInvalidExternalUrlsQuantity);

    let mut static_collectible_types: vector<StaticCollectibleType> = vector[];

    while (!mint_caps.is_empty()) {
        let static_collectible_type = new(
            collection_admin_cap,
            mint_caps.pop_back(),
            names.pop_back(),
            descriptions.pop_back(),
            images.pop_back(),
            animation_urls.pop_back(),
            external_urls.pop_back(),
            collection,
            ctx,
        );

        static_collectible_types.push_back(static_collectible_type);
    };

    mint_caps.destroy_empty();

    static_collectible_types
}

// Create a new PFP.
public fun new(
    collection_admin_cap: &CollectionAdminCap,
    mint_cap: MintCap<StaticCollectible>,
    name: String,
    description: String,
    image: String,
    animation_url: String,
    external_url: String,
    collection: &mut Collection,
    ctx: &mut TxContext,
): StaticCollectibleType {
    collection.assert_blob_reserved(b64_to_u256(image));

    let static_collectible_type = StaticCollectibleType {
        id: object::new(ctx),
        collection_id: object::id(collection),
        collectible: static_collectible::new(
            mint_cap,
            name,
            collection.registered_count() + 1,
            description,
            image,
            animation_url,
            external_url,
        ),
    };

    collection.register_item(
        collection_admin_cap,
        static_collectible_type.collectible.number(),
        &static_collectible_type,
    );

    static_collectible_type
}

// Receive an object that's been sent to the collectible.
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
) {
    assert!(cap.collection_id() == self.collection_id, EInvalidCollectionAdminCap);
    self.collectible.reveal(attribute_keys, attribute_values);
}

public fun reveal_bulk(
    collection_admin_cap: &CollectionAdminCap,
    static_collectible_types: &mut vector<StaticCollectibleType>,
    mut attribute_keys: vector<vector<String>>,
    mut attribute_values: vector<vector<String>>,
) {
    let quantity = static_collectible_types.length();

    assert!(attribute_keys.length() == quantity, EInvalidAttributeKeysQuantity);
    assert!(attribute_values.length() == quantity, EInvalidAttributeValuesQuantity);

    // Reverse the attribute vectors because do_mut!() calls reverse on the target vector.
    attribute_keys.reverse();
    attribute_values.reverse();

    static_collectible_types.do_mut!(
        |static_collectible| reveal(
            static_collectible,
            collection_admin_cap,
            attribute_keys.pop_back(),
            attribute_values.pop_back(),
        ),
    );
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

public fun collectible_image(self: &StaticCollectibleType): String {
    self.collectible.image()
}

public fun collectible_animation_url(self: &StaticCollectibleType): String {
    self.collectible.animation_url()
}

public fun collectible_external_url(self: &StaticCollectibleType): String {
    self.collectible.external_url()
}

public fun collectible_attributes(self: &StaticCollectibleType): VecMap<String, String> {
    self.collectible.attributes()
}
