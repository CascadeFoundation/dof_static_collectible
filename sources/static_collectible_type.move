module dof_static_collectible::static_collectible_type;

use blob_utils::blob_utils;
use dos_collection::collection::{Self, assert_is_authorized};
use dos_collection::collection_manager::{CollectionManager, CollectionManagerAdminCap};
use dos_collection::collection_metadata::CollectionMetadata;
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

//=== Init Function ===

#[allow(lint(share_owned))]
fun init(otw: STATIC_COLLECTIBLE_TYPE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let display = display::new<StaticCollectibleType>(&publisher, ctx);

    let (collection_metadata, collection_manager, collection_manager_admin_cap) = collection::new<
        StaticCollectibleType,
    >(
        &publisher,
        address::from_bytes(COLLECTION_CREATOR_ADDRESS),
        COLLECTION_NAME.to_string(),
        COLLECTION_DESCRIPTION.to_string(),
        COLLECTION_EXTERNAL_URL.to_string(),
        COLLECTION_IMAGE_URI.to_string(),
        COLLECTION_TOTAL_SUPPLY,
        ctx,
    );

    transfer::public_transfer(collection_manager_admin_cap, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());

    transfer::public_freeze_object(collection_metadata);
    transfer::public_share_object(collection_manager);
}

//=== Public Function ===

const EInvalidNamesQuantity: u64 = 10000;
const EInvalidNumbersQuantity: u64 = 10001;
const EInvalidDescriptionsQuantity: u64 = 10002;
const EInvalidImagesQuantity: u64 = 10003;
const EInvalidAnimationUrlsQuantity: u64 = 10004;
const EInvalidExternalUrlsQuantity: u64 = 10005;
const EInvalidAttributeKeysQuantity: u64 = 10006;
const EInvalidAttributeValuesQuantity: u64 = 10007;
const EInvalidCollectionMetadata: u64 = 10008;

// Create a new PFP.
public fun new(
    cap: &CollectionManagerAdminCap,
    publisher: &Publisher,
    name: String,
    number: u64,
    description: String,
    image_uri: String,
    animation_url: String,
    external_url: String,
    collection_manager: &mut CollectionManager,
    collection_metadata: &CollectionMetadata,
    ctx: &mut TxContext,
): StaticCollectibleType {
    // Assert the CollectionManagerAdminCap, CollectionManager, and CollectionMetadata are linked to each other.
    assert_is_authorized(cap, collection_manager, collection_metadata);

    internal_new(
        cap,
        publisher,
        collection_metadata.creator(),
        name,
        number,
        description,
        image_uri,
        animation_url,
        external_url,
        collection_manager,
        collection_metadata,
        ctx,
    )
}

// Create multiple collectibles at once by providing vectors of data.
// Be sure to provided reversed vectors for names, descriptions, image_uris,
// animation_urls, and external_urls because pop_back() is used to remove
// elements from the vectors. At the same time, number assignment is done
// sequentially starting from 1.
public fun new_bulk(
    cap: &CollectionManagerAdminCap,
    publisher: &Publisher,
    quantity: u64,
    mut names: vector<String>,
    mut numbers: vector<u64>,
    mut descriptions: vector<String>,
    mut image_uris: vector<String>,
    mut animation_urls: vector<String>,
    mut external_urls: vector<String>,
    collection_manager: &mut CollectionManager,
    collection_metadata: &CollectionMetadata,
    ctx: &mut TxContext,
): vector<StaticCollectibleType> {
    // Assert the CollectionManagerAdminCap, CollectionManager, and CollectionMetadata are linked to each other.
    assert_is_authorized(cap, collection_manager, collection_metadata);

    assert!(names.length() == quantity, EInvalidNamesQuantity);
    assert!(numbers.length() == quantity, EInvalidNumbersQuantity);
    assert!(descriptions.length() == quantity, EInvalidDescriptionsQuantity);
    assert!(image_uris.length() == quantity, EInvalidImagesQuantity);
    assert!(animation_urls.length() == quantity, EInvalidAnimationUrlsQuantity);
    assert!(external_urls.length() == quantity, EInvalidExternalUrlsQuantity);

    let static_collectible_types = vector::tabulate!(
        quantity,
        |_| internal_new(
            cap,
            publisher,
            collection_metadata.creator(),
            names.pop_back(),
            numbers.pop_back(),
            descriptions.pop_back(),
            image_uris.pop_back(),
            animation_urls.pop_back(),
            external_urls.pop_back(),
            collection_manager,
            collection_metadata,
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

// Reveal a PFP with attributes keys, attribute values, and an image_uri URI.
public fun reveal(
    self: &mut StaticCollectibleType,
    cap: &CollectionManagerAdminCap,
    attribute_keys: vector<String>,
    attribute_values: vector<String>,
    collection_manager: &mut CollectionManager,
    collection_metadata: &CollectionMetadata,
) {
    assert_is_authorized(cap, collection_manager, collection_metadata);
    internal_reveal(self, attribute_keys, attribute_values, collection_metadata);
}

// Reveal multiple collectibles. Be sure to provide reversed vectors for
// attribute_keys and attribute_values because pop_back() is used to remove
// elements from the vectors, and the do_mut!() macro DOES NOT reverse the
// vectors before applying the reveal function to each collectible.
public fun reveal_bulk(
    cap: &CollectionManagerAdminCap,
    static_collectible_types: &mut vector<StaticCollectibleType>,
    mut attribute_keys: vector<vector<String>>,
    mut attribute_values: vector<vector<String>>,
    collection_manager: &mut CollectionManager,
    collection_metadata: &CollectionMetadata,
) {
    assert_is_authorized(cap, collection_manager, collection_metadata);

    let quantity = static_collectible_types.length();

    assert!(attribute_keys.length() == quantity, EInvalidAttributeKeysQuantity);
    assert!(attribute_values.length() == quantity, EInvalidAttributeValuesQuantity);

    static_collectible_types.do_mut!(
        |static_collectible| internal_reveal(
            static_collectible,
            attribute_keys.pop_back(),
            attribute_values.pop_back(),
            collection_metadata,
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

public fun image_uri(self: &StaticCollectibleType): String {
    self.collectible.image_uri()
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
    cap: &CollectionManagerAdminCap,
    publisher: &Publisher,
    creator: address,
    name: String,
    number: u64,
    description: String,
    image_uri: String,
    animation_url: String,
    external_url: String,
    collection_manager: &mut CollectionManager,
    collection_metadata: &CollectionMetadata,
    ctx: &mut TxContext,
): StaticCollectibleType {
    collection_manager.assert_blob_reserved(blob_utils::blob_id_to_u256(image_uri));

    let static_collectible_type = StaticCollectibleType {
        id: object::new(ctx),
        collection_id: object::id(collection_metadata),
        collectible: static_collectible::new<StaticCollectibleType>(
            publisher,
            creator,
            name,
            number,
            description,
            image_uri,
            animation_url,
            external_url,
        ),
    };

    collection_manager.register_item(
        cap,
        static_collectible_type.collectible.number(),
        &static_collectible_type,
    );

    static_collectible_type
}

fun internal_reveal(
    self: &mut StaticCollectibleType,
    attribute_keys: vector<String>,
    attribute_values: vector<String>,
    collection_metadata: &CollectionMetadata,
) {
    assert!(self.collection_id == object::id(collection_metadata), EInvalidCollectionMetadata);
    self.collectible.reveal(attribute_keys, attribute_values);
}
