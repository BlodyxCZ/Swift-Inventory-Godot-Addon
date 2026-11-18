# Changelog

## v2.3.0 - Unreleased

### Added

- Added `SwiftItemQuery` and inventory methods for finding and counting stacks by item ID, tags, text, or metadata.
- Added grid filtering and sorting without changing stored addresses or hotbar order.
- Added rule-aware stack merging and compaction.
- Added one-stack quick transfer and Take All, with optional middle-click transfer in grids.
- Added reusable item actions and an optional right-click menu that rechecks the original stack.
- Added `SwiftWorldPickup` for partial, metadata-preserving transfers between world pickups and inventories.
- Added optional width-based slot scaling for grids and hotbars.
- Redesigned the example scene around the chest, player inventory, and a persistent item details panel with contextual actions.

### Fixed

- Restored removed stacks and slot rules when undoing grid capacity edits in the Inspector.
- Kept free-form slots in proportion to the resized drop area and preserved their placements across UI state saves.
- Added keyboard focus, slot navigation, and a click-or-keyboard alternative to dragging stacks.
- Added quick-transfer results for partial and blocked moves. The example now explains empty filters, capacity limits, and failed world drops.
- Improved the example's slot contrast and text size, and made the hotbar number keys functional.

## v2.2.1 - 18/11/2026

### Fixed

- Detached packed arrays when copying stack metadata and recording drag or tooltip state.
- Aligned stack replacement previews with ownership checks and shared swap validation between the inventory and drag UI.
- Kept inventory address edits from mutating assigned dictionaries, including editor undo history.
- Fixed autosave callbacks that changed a container's configuration during a save or tree exit.
- Preserved drop-area positions set before the view is ready and prevented transfers into a view rebound during expansion.
- Rejected invalid drop positions and malformed drag payloads, and handled unavailable sources in drag previews.
- Applied hotbar selection color changes immediately and kept existing items when an Inspector quantity edit could not copy the stack.
- Accepted binary `.res` item definitions in the editor alongside `.tres` files.

### Compatibility

- Swaps now share `SwiftRule` validation with drag previews. Inventory subclasses that enforce swap restrictions in `can_set_stack()` should move those checks into a `SwiftRule`.

## v2.2.0 - 06/09/2026

### Added

- Added `SwiftItemStack.instance_data` for stack-specific runtime state such as durability or
  enchantments.
- Added `SwiftItemStack.can_stack_with()` for item-ID and instance-data compatibility checks.
- Added validated `SwiftInventory.has_stack()` and `SwiftInventory.get_stack()` query methods.
- Added `SwiftContainer.auto_persist` and `save_path` for runtime inventory loading on startup,
  batched autosaving after changes, and a final save on scene exit. Available on grids, hotbars,
  and drop areas; disabled in editor previews. Duplicate writers and failed-load overwrites
  are rejected, with completion and failure signals for gameplay integration.

### Changed

- Replaced overlapping container-level refresh and synchronization hooks with one full/address
  reconciliation contract. `SwiftSlot.refresh()` now exclusively updates slot presentation.
- Updated `SwiftInventory.set_stack()` to validate addresses and stack invariants, support clearing
  with `null`, and emit address-specific change notifications.
- Updated stack merging to require matching item IDs and matching `instance_data`.
- Updated `SwiftInventory.try_add()` to reject missing item data and non-positive stack capacities.
- Updated bulk inventory transfers to preserve stack metadata and fill compatible stacks before
  empty addresses.

### Fixed

- Fixed `SwiftGrid` hanging when its inventory shrank.
- Fixed grid slot counting and layout when a container has non-slot children.
- Fixed `SwiftDropArea` retaining stale slot bindings after inventory reassignment.
- Fixed `SwiftDropArea` reconciliation failing when the container has non-slot children.
- Fixed split moves and transfers losing stack-specific metadata or sharing its dictionary.
- Removed duplicate slot refreshes during inventory reassignment and grid size changes.
- Removed accidental debug output from inventory change notifications.

### Documentation

- Added the browser-playable example scene link and documented stack-specific metadata behavior.
- Clarified how `SwiftHotbar.selection_actions` maps Input Map names to visible slots.

### Development

- Added the GitHub Actions workflow used to package and publish the playable scene preview.

## v2.1.0 - 23/08/2026

### Added

- Added the abstract `SwiftContainer` base class for inventory-backed slot containers.
- Added experimental `SwiftDropArea` behavior for free-form, positioned item drops and
  cross-inventory transfers.
- Added a drop-area panel and dedicated inventory resource to the included example scene.

### Changed

- Refactored `SwiftGrid` to inherit shared inventory synchronization and slot management from
  `SwiftContainer`.
- Split stack assignment into `SwiftInventory.set_stack()` for existing stack resources and
  `SwiftInventory.set_stack_from_data()` for validated stacks created from item data.
- Updated `SwiftSlot` to support direct runtime stack assignment while retaining editor-friendly
  item-data and amount properties.

### Fixed

- Updated editor drag feedback to show the can-drop cursor when a valid `SwiftItemData` resource
  is positioned over a `SwiftSlot`.

### Documentation

- Added Godot-style class-reference documentation to all eight public add-on classes.

## v2.0.0 - 23/08/2026 - Initial release

- Released Swift Inventory 2.0.0.
