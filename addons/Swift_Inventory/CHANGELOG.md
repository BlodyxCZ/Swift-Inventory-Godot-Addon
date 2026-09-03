# Changelog

## v2.2.0 - 04/09/2026

### Added

- Added `SwiftItemStack.instance_data` for stack-specific runtime state such as durability or
  enchantments.
- Added `SwiftItemStack.can_stack_with()` for item-ID and instance-data compatibility checks.
- Added validated `SwiftInventory.has_stack()` and `SwiftInventory.get_stack()` query methods.

### Changed

- Replaced overlapping container-level refresh and synchronization hooks with one full/address
  reconciliation contract; `SwiftSlot.refresh()` now exclusively updates slot presentation.
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
