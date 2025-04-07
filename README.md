# Cascade DOF-1 (Static Collectible)

Cascade DOF-1 implements a framework for minting static collectible objects.

- [DosCollection](https://github.com/cascadefoundation/dos_collection)
- [DosStaticCollectible](https://github.com/cascadefoundation/dos_static_collectible)

```
public struct StaticCollectibleType has key, store {
    id: UID,
    collection_id: ID,
    collectible: StaticCollectible,
}
```
