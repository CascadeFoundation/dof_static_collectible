# Cascade DOF-1 (Static Collectible)

Cascade DOF-1 implements a framework for minting a collection of static collectibles. To do this, DOF-1 uses `DosCollection` and `DosStaticCollectible`.

- [DosCollection](https://github.com/cascadefoundation/dos_collection)
- [DosStaticCollectible](https://github.com/cascadefoundation/dos_static_collectible)

```
public struct StaticCollectibleType has key, store {
    id: UID,
    collection_id: ID,
    collectible: StaticCollectible,
}
```
