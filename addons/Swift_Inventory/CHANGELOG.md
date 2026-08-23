# Changelog

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

## v2.0.0 - 23/08/206 - Initial release

- Released Swift Inventory 2.0.0.
