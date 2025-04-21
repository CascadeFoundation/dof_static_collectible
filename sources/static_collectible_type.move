module dof_static_collectible::static_collectible_type;

use blob_utils::blob_utils;
use dos_collection::collection::{Self, Collection, CollectionAdminCap};
use dos_static_collectible::static_collectible::{Self, StaticCollectible};
use std::string::String;
use sui::address;
use sui::display;
use sui::package::{Self, Publisher};
use sui::transfer::Receiving;
use sui::vec_map::VecMap;

//=== Structs ===

public struct STATIC_COLLECTIBLE_TYPE has drop {}

// A wrapper type around StaticCollectibleType that provides control over a unique type.
public struct StaticCollectibleType has key, store {
    id: UID,
    collection_id: ID,
    collectible: StaticCollectible,
}

//=== Constants ===

const COLLECTION_CREATOR_ADDRESS: vector<u8> = b"<COLLECTION_CREATOR_ADDRESS>";
const COLLECTION_NAME: vector<u8> = b"<COLLECTION_NAME>";
const COLLECTION_DESCRIPTION: vector<u8> = b"<COLLECTION_DESCRIPTION>";
const COLLECTION_EXTERNAL_URL: vector<u8> = b"<COLLECTION_EXTERNAL_URL>";
const COLLECTION_IMAGE_URI: vector<u8> = b"<COLLECTION_IMAGE_URI>";
const COLLECTION_TOTAL_SUPPLY: u64 = 0;

//=== Errors ===

const EInvalidCollectionAdminCap: u64 = 10000;

//=== Init Function ===

#[allow(lint(share_owned))]
fun init(otw: STATIC_COLLECTIBLE_TYPE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let mut display = display::new<StaticCollectibleType>(&publisher, ctx);

    let (collection, collection_admin_cap) = collection::new<StaticCollectibleType>(
        &publisher,
        address::from_bytes(COLLECTION_CREATOR_ADDRESS),
        COLLECTION_NAME.to_string(),
        COLLECTION_DESCRIPTION.to_string(),
        COLLECTION_EXTERNAL_URL.to_string(),
        COLLECTION_IMAGE_URI.to_string(),
        COLLECTION_TOTAL_SUPPLY,
        ctx,
    );

    transfer::public_transfer(collection_admin_cap, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());

    transfer::public_share_object(collection);
}

//=== Public Function ===

const EInvalidNamesQuantity: u64 = 0;
const EInvalidDescriptionsQuantity: u64 = 1;
const EInvalidImagesQuantity: u64 = 2;
const EInvalidAnimationUrlsQuantity: u64 = 3;
const EInvalidExternalUrlsQuantity: u64 = 4;
const EInvalidAttributeKeysQuantity: u64 = 5;
const EInvalidAttributeValuesQuantity: u64 = 6;

// Create a new PFP.
public fun new(
    collection_admin_cap: &CollectionAdminCap,
    publisher: &Publisher,
    name: String,
    description: String,
    image: String,
    animation_url: String,
    external_url: String,
    collection: &mut Collection,
    ctx: &mut TxContext,
): StaticCollectibleType {
    internal_new(
        collection_admin_cap,
        publisher,
        collection.creator(),
        name,
        description,
        image,
        animation_url,
        external_url,
        collection,
        ctx,
    )
}

// Create multiple collectibles at once by providing vectors of data.
// Be sure to provided reversed vectors for names, descriptions, images,
// animation_urls, and external_urls because pop_back() is used to remove
// elements from the vectors. At the same time, number assignment is done
// sequentially starting from 1.
public fun new_bulk(
    collection_admin_cap: &CollectionAdminCap,
    publisher: &Publisher,
    quantity: u64,
    mut names: vector<String>,
    mut descriptions: vector<String>,
    mut images: vector<String>,
    mut animation_urls: vector<String>,
    mut external_urls: vector<String>,
    collection: &mut Collection,
    ctx: &mut TxContext,
): vector<StaticCollectibleType> {
    assert!(names.length() == quantity, EInvalidNamesQuantity);
    assert!(descriptions.length() == quantity, EInvalidDescriptionsQuantity);
    assert!(images.length() == quantity, EInvalidImagesQuantity);
    assert!(animation_urls.length() == quantity, EInvalidAnimationUrlsQuantity);
    assert!(external_urls.length() == quantity, EInvalidExternalUrlsQuantity);

    let static_collectible_types = vector::tabulate!(
        quantity,
        |_| internal_new(
            collection_admin_cap,
            publisher,
            collection.creator(),
            names.pop_back(),
            descriptions.pop_back(),
            images.pop_back(),
            animation_urls.pop_back(),
            external_urls.pop_back(),
            collection,
            ctx,
        ),
    );

    static_collectible_types
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

// Reveal multiple collectibles. Be sure to provide reversed vectors for
// attribute_keys and attribute_values because pop_back() is used to remove
// elements from the vectors, and the do_mut!() macro DOES NOT reverse the
// vectors before applying the reveal function to each collectible.
public fun reveal_bulk(
    collection_admin_cap: &CollectionAdminCap,
    static_collectible_types: &mut vector<StaticCollectibleType>,
    mut attribute_keys: vector<vector<String>>,
    mut attribute_values: vector<vector<String>>,
) {
    let quantity = static_collectible_types.length();

    assert!(attribute_keys.length() == quantity, EInvalidAttributeKeysQuantity);
    assert!(attribute_values.length() == quantity, EInvalidAttributeValuesQuantity);

    static_collectible_types.do_mut!(
        |static_collectible| reveal(
            static_collectible,
            collection_admin_cap,
            attribute_keys.pop_back(),
            attribute_values.pop_back(),
        ),
    );
}

public fun destroy(self: StaticCollectibleType) {
    let StaticCollectibleType { id, collectible, .. } = self;
    collectible.destroy();
    id.delete();
}

//=== View Functions ===

public fun collection_id(self: &StaticCollectibleType): ID {
    self.collection_id
}

public fun creator(self: &StaticCollectibleType): address {
    self.collectible.creator()
}

public fun number(self: &StaticCollectibleType): u64 {
    self.collectible.number()
}

public fun name(self: &StaticCollectibleType): String {
    self.collectible.name()
}

public fun description(self: &StaticCollectibleType): String {
    self.collectible.description()
}

public fun image(self: &StaticCollectibleType): String {
    self.collectible.image()
}

public fun animation_url(self: &StaticCollectibleType): String {
    self.collectible.animation_url()
}

public fun external_url(self: &StaticCollectibleType): String {
    self.collectible.external_url()
}

public fun attributes(self: &StaticCollectibleType): VecMap<String, String> {
    self.collectible.attributes()
}

//=== Private Functions ===

fun internal_new(
    collection_admin_cap: &CollectionAdminCap,
    publisher: &Publisher,
    creator: address,
    name: String,
    description: String,
    image: String,
    animation_url: String,
    external_url: String,
    collection: &mut Collection,
    ctx: &mut TxContext,
): StaticCollectibleType {
    collection.assert_blob_reserved(blob_utils::blob_id_to_u256(image));

    let static_collectible_type = StaticCollectibleType {
        id: object::new(ctx),
        collection_id: object::id(collection),
        collectible: static_collectible::new<StaticCollectibleType>(
            publisher,
            creator,
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
