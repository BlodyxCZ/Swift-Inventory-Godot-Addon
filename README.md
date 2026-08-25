<div align="center">

<img src="addons/Swift_Inventory/Icons/SwiftGrid.svg" alt="Swift Inventory" width="112">

# Swift Inventory

### A small, data-driven inventory system for Godot 4

Build inventories with unmatched speed.

[![Godot Engine](https://img.shields.io/badge/Godot-4.4%2B-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/Language-GDScript-478CBF?logo=godot-engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Version](https://img.shields.io/badge/Version-2.1.0-6C63FF)](addons/Swift_Inventory/plugin.cfg)
![Status](https://img.shields.io/badge/Status-In%20Development-orange)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

[Godot Asset Store](https://store.godotengine.org/asset/blodyx/swift-inventory/) · [GitHub](https://github.com/BlodyxCZ/Swift-Inventory-Godot-Addon) · [Included Example](addons/Swift_Inventory/Example/example_scene.tscn)

</div>

## ⛑️ Development Status

Swift Inventory is actively being developed. The core inventory resources, grid UI, free-form drop areas, slots, stacking, transfers, runtime drag and drop, and editor workflow are available now.

Known limitation:

- `SwiftInfo` has a known issue where the information panel can hide after a dragged item is dropped.
- Left an accidental debug `prints()` in `SwiftInventory`.

If you encounter another problem, [open a GitHub issue](https://github.com/BlodyxCZ/Swift-Inventory-Godot-Addon/issues).

## ✨ Features

- **Resource-based data** — inventory state and item definitions are independent from the UI.
- **Automatic stacking** — compatible stacks are filled before empty slots are used.
- **Per-item stack limits** — every item defines its own `max_stack_size`.
- **Move, split, swap, and transfer operations** — manipulate stacks within one inventory or between inventories.
- **Automatic grid synchronization** — `SwiftGrid` creates and binds slots to match inventory size.
- **Free-form drop areas** — `SwiftDropArea` places occupied slots where stacks are dropped and supports cross-inventory transfers.
- **Runtime drag and drop** — `SwiftSlot` can move, merge, swap, or transfer stacks.
- **Editor tooling** — select generated slots and drop `SwiftItemData` resources onto them in the 2D editor.
- **Change notifications** — react to inventory mutations through one typed signal.
- **Extensible item information UI** — subclass `SwiftInfo` to create a custom tooltip or hover panel.
- **Included example** — inspect or run player, chest, and free-form drop-area inventories.
- **Lightweight integration** — no singleton is required, and the inventory logic is not tied to a particular game.

> [!TIP]
> `SwiftInventory` owns the data. `SwiftGrid`, `SwiftDropArea`, and `SwiftSlot` present and interact with that data. This separation lets multiple gameplay systems or interfaces use the same inventory resource.

## 🧩 Architecture

| Class | Base type | Responsibility |
| --- | --- | --- |
| `SwiftItemData` | `Resource` | Static item definition: ID, name, description, icon, tags, and stack limit |
| `SwiftItemStack` | `Resource` | An item definition plus its current amount |
| `SwiftInventory` | `Resource` | Inventory size, stack state, operations, and change notifications |
| `SwiftContainer` | `Container` | Shared inventory synchronization and slot management for container layouts |
| `SwiftGrid` | `SwiftContainer` | Creates, binds, sizes, and lays out every inventory address in a grid |
| `SwiftDropArea` | `SwiftContainer` | Places occupied inventory slots at their free-form drop positions |
| `SwiftSlot` | `Panel` | Displays one inventory address and handles drag and drop |
| `SwiftInfo` | `Control` | Base control for a custom item hover panel |
| `Swift_Inventory.gd` | `EditorPlugin` | Adds slot selection and item-resource dropping to the 2D editor |

## 🗃️ Installation

### Godot Asset Store

1. Open the [Swift Inventory store page](https://store.godotengine.org/asset/blodyx/swift-inventory/).
2. Add the asset to your library and download it.
3. Install the `addons/Swift_Inventory` folder into your project.

### GitHub

1. Download the repository from [GitHub](https://github.com/BlodyxCZ/Swift-Inventory-Godot-Addon). (Code > Download .ZIP)
2. Copy `addons/Swift_Inventory` into your project's `addons` folder.

Your project should contain:

```text
res://
└── addons/
    └── Swift_Inventory/
        ├── Classes/
        ├── Example/
        ├── Icons/
        ├── Swift_Inventory.gd
        └── plugin.cfg
```

Open **Project > Project Settings > Plugins** and enable **Swift Inventory** to use its editor enhancements.

The scripts use `class_name`, so their types become available directly in GDScript after Godot imports the add-on. The runtime inventory API does not require an autoload.

## ⏱️ Quick Start

### 1. Create an item definition

In the FileSystem dock, create a `SwiftItemData` resource and save it as a `.tres` file. Configure it in the Inspector:

```text
id              = "health_potion"
display_name    = "Health Potion"
description     = "Restores a little health."
icon            = <your texture>
max_stack_size  = 10
tags            = ["consumable", "potion"]
```

The same `SwiftItemData` resource can be reused by every stack of that item.

### 2. Create an inventory

Create a `SwiftInventory` resource, save it as a `.tres` file, and set its size. You can also assign it to a script and populate it at runtime:

```gdscript
@export var inventory: SwiftInventory
@export var health_potion: SwiftItemData


func _ready() -> void:
    inventory.size = 24

    var remaining := inventory.try_add(health_potion, 5)
    if remaining > 0:
        print("Inventory could not fit %d potions." % remaining)
```

`try_add()` returns the quantity that could not be inserted, which makes overflow explicit.

### 3. Display it with `SwiftGrid`

1. Add a `SwiftGrid` node to a `Control`-based scene.
2. Assign the `SwiftInventory` resource to `swift_inventory`.
3. Set `inventory_size`, `slot_size`, and `separation` in the Inspector.
4. Give the grid enough width for the number of columns you want. Slots wrap to the next row based on the available width.

`SwiftGrid` creates the required `SwiftSlot` children and keeps them bound to their matching inventory addresses. Changing the inventory size automatically resynchronizes the grid.

### 4. Try the included example

Open and run:

```text
res://addons/Swift_Inventory/Example/example_scene.tscn
```

The scene demonstrates grid and free-form inventories, item resources, stack amounts, runtime drag and drop, and a `SwiftInfo` panel.

## 🫴 Free-Form Drop Areas

Add a `SwiftDropArea` to a `Control`-based scene, assign a `SwiftInventory` to `swift_inventory`, and configure `slot_size`. When a stack is dropped onto the area, it transfers into the first available address and its `SwiftSlot` is positioned at the drop point.

Unlike `SwiftGrid`, a `SwiftDropArea` only creates slots for occupied addresses. If every existing address is occupied, a successful drop expands the destination inventory by one address.

## 🔀 Editor Workflow

With the plugin enabled:

1. Select a configured `SwiftGrid` in the 2D editor.
2. Click one of its generated slots. The first click selects the `SwiftGrid`; with the grid selected, a second click inspects the `SwiftSlot`.
3. Drag a `.tres` file containing `SwiftItemData` from the FileSystem dock onto a visible slot. The cursor changes to the can-drop shape over a valid target.
4. Select the slot to adjust its item or amount in the Inspector.

These edits update the assigned `SwiftInventory` resource. Only `.tres` resources containing `SwiftItemData` are accepted by the editor drop workflow.

## 🛠️ Working With Items

### Add items

```gdscript
var remaining := inventory.try_add(item_data, 20)

if remaining > 0:
    print("%d items did not fit." % remaining)
```

Existing compatible stacks are filled first. New stacks are then placed in empty addresses until the quantity is exhausted or every address is occupied.

### Remove items

```gdscript
var result := inventory.try_remove(3, 2)

if result != OK:
    print("Could not remove the requested items.")
```

`try_remove()` succeeds only when the address is valid, contains a stack, and holds the full requested quantity.

### Move or merge stacks

```gdscript
var remaining := inventory.try_move(
    0, # source address
    5, # destination address
    3  # quantity
)
```

An empty destination receives the stack or a split stack. A destination containing the same item is filled up to its stack limit. Different item types are not moved by this method.

### Swap stacks

```gdscript
var result := inventory.try_swap(0, 4)
```

Both addresses must contain an item. To swap occupied addresses between inventories:

```gdscript
var result := inventory_a.try_swap(
    0,
    2,
    inventory_b
)
```

### Transfer between inventories

```gdscript
var remaining := inventory_a.try_transfer(
    0,           # source address
    inventory_b,
    3,           # destination address
    5            # quantity
)
```

To transfer as much of an entire inventory as possible:

```gdscript
var result := inventory_a.transfer_to(inventory_b)
```

`transfer_to()` returns `OK` only when the source inventory becomes empty. It returns `FAILED` if any items remain.

### Set or clear an address

```gdscript
inventory.set_stack_from_data(4, item_data, 3)
```

`set_stack_from_data()` validates the address, clamps the quantity to the item's `max_stack_size`, and emits a change notification. Clear the address by passing `null` or a non-positive quantity:

```gdscript
inventory.set_stack_from_data(4, null)
```

Use `set_stack()` when you already have a `SwiftItemStack` resource and intentionally want to assign it directly without address validation or a change notification:

```gdscript
inventory.set_stack(4, SwiftItemStack.new(item_data, 3))
```

## 🫳 Runtime Drag and Drop

`SwiftSlot` implements Godot's built-in drag-and-drop callbacks. A dragged stack uses this payload:

```gdscript
{
    "inventory": swift_inventory,
    "address": address,
    "quantity": item.amount,
}
```

Dropping onto another `SwiftSlot` can:

- move a stack into an empty address,
- merge matching stacks,
- swap different occupied stacks,
- transfer items between inventories.

Dropping onto a `SwiftDropArea` transfers the stack to its inventory and positions the resulting slot at the drop point. Custom UI can participate in the same workflow by producing or accepting the same payload shape.

## 📡 Reacting to Inventory Changes

Every `SwiftInventory` exposes:

```gdscript
signal on_change(
    type: CHANGES,
    from_address: int,
    to_address: int
)
```

Connect once and react to the changes relevant to your game or UI:

```gdscript
func _ready() -> void:
    inventory.on_change.connect(_on_inventory_changed)


func _on_inventory_changed(
    type: SwiftInventory.CHANGES,
    from_address: int,
    to_address: int
) -> void:
    match type:
        SwiftInventory.CHANGES.add:
            print("Added an item at ", to_address)
        SwiftInventory.CHANGES.remove:
            print("Removed an item from ", from_address)
        SwiftInventory.CHANGES.move:
            print("Moved ", from_address, " -> ", to_address)
        SwiftInventory.CHANGES.swap:
            print("Swapped ", from_address, " <-> ", to_address)
        SwiftInventory.CHANGES.transfer:
            print("An inventory transfer changed an address")
        SwiftInventory.CHANGES.set:
            print("Set the stack at ", to_address)
        SwiftInventory.CHANGES.size:
            print("Inventory size changed")
        SwiftInventory.CHANGES.inventory:
            print("The inventory dictionary was replaced")
```

The available change types are:

```gdscript
enum CHANGES {
    add,
    remove,
    move,
    swap,
    transfer,
    set,
    size,
    inventory,
}
```

An unused address is reported as `-1`. For example, an add event has no source address, while each side of a cross-inventory transfer receives its own event.

## 🪄 Extending Item Data

`SwiftItemData` intentionally contains only common item metadata:

```gdscript
class_name SwiftItemData
extends Resource

@export var id: StringName = "NewItem"
@export var display_name: String = "NewItem"
@export var description: String = "NewDescription"
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var tags: Array[StringName] = []
```

Extend it when your game needs additional fields:

```gdscript
class_name EquipmentData
extends SwiftItemData

@export var damage: float
@export var durability: int
@export var equipment_slot: StringName
```

Stacks continue to accept subclasses because they reference the `SwiftItemData` base type.

## 📰 Custom Item Information

Subclass `SwiftInfo` and connect its `on_info_changed(new_item: SwiftItemStack)` signal to update your own labels, icons, or statistics. The control follows the pointer and displays information for the currently hovered `SwiftSlot`.

The pointer offset property is currently named `position_offest` in the API. See the included `example_info_panel.gd` for a minimal signal handler.

## 🔧 API Reference

<details>
<summary><strong>SwiftInventory</strong></summary>

<br>

| API | Returns | Description |
| --- | --- | --- |
| `try_add(data, quantity)` | `int` | Adds as much as possible and returns the quantity that did not fit |
| `try_remove(address, quantity)` | `Error` | Removes an exact quantity from one occupied address |
| `try_move(from, to, quantity)` | `int` | Moves or merges a stack and returns the remaining movable quantity |
| `try_swap(first, second, other_inventory = null)` | `Error` | Swaps two occupied addresses |
| `try_transfer(from, other_inventory, to, quantity)` | `int` | Transfers items and returns the remaining transferable quantity |
| `transfer_to(other_inventory)` | `Error` | Moves as much of this inventory as possible into another inventory |
| `set_stack(address, stack)` | `Error` | Directly assigns an existing stack resource without validation or notification |
| `set_stack_from_data(address, data, quantity = 1)` | `Error` | Validates, replaces, or clears one address and emits a change notification |
| `is_full()` | `bool` | Returns whether every address is occupied |
| `size` | `int` | Number of valid inventory addresses |
| `inventory` | `Dictionary[int, SwiftItemStack]` | Address-to-stack mapping |
| `on_change` | `Signal` | Reports successful mutations and property changes |

</details>

<details>
<summary><strong>SwiftItemData and SwiftItemStack</strong></summary>

<br>

| Type | API | Description |
| --- | --- | --- |
| `SwiftItemData` | `id` | Identifier used to decide whether stacks contain the same item type |
| `SwiftItemData` | `display_name` | User-facing item name |
| `SwiftItemData` | `description` | User-facing item description |
| `SwiftItemData` | `icon` | Texture displayed by `SwiftSlot` |
| `SwiftItemData` | `max_stack_size` | Maximum quantity accepted by a stack |
| `SwiftItemData` | `tags` | Game-defined item categories |
| `SwiftItemStack` | `item_data` | Item definition represented by the stack |
| `SwiftItemStack` | `amount` | Current stack quantity |
| `SwiftItemStack` | `get_reserve()` | Remaining room before reaching the stack limit |

</details>

<details>
<summary><strong>SwiftContainer, SwiftGrid, SwiftDropArea, SwiftSlot, and SwiftInfo</strong></summary>

<br>

| Type | API | Description |
| --- | --- | --- |
| `SwiftContainer` | `swift_inventory` | Inventory represented by the container |
| `SwiftContainer` | `slot_size` | Pixel size assigned to child slots |
| `SwiftGrid` | `swift_inventory` | Inventory represented by the grid |
| `SwiftGrid` | `inventory_size` | Proxy for `swift_inventory.size` |
| `SwiftGrid` | `slot_size` | Pixel size of generated slots |
| `SwiftGrid` | `separation` | Horizontal and vertical space between slots |
| `SwiftDropArea` | `swift_inventory` | Inventory that receives dropped stacks |
| `SwiftDropArea` | `slot_size` | Pixel size of positioned slots |
| `SwiftSlot` | `item_data` | Editor-facing item definition for this address |
| `SwiftSlot` | `amount` | Editor-facing amount for this address |
| `SwiftSlot` | `swift_inventory` | Inventory to which the slot is bound |
| `SwiftSlot` | `address` | Address represented by the slot |
| `SwiftSlot` | `refreshed` | Signal emitted after the slot refreshes its presentation |
| `SwiftInfo` | `position_offest` | Offset applied to the pointer-following information control |
| `SwiftInfo` | `on_info_changed` | Signal emitted when the hovered item changes |

</details>

## 🫶 Support

Support me and this project on [![Ko-fi](https://img.shields.io/badge/Ko--fi-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/blodyx).

## ⚖️ License and Credits

Swift Inventory is available under the [MIT License](LICENSE).

Some icons are based on [@icons — Custom node icons](https://github.com/Voxybuns/at-icons?tab=MIT-1-ov-file) by [Voxybuns](https://github.com/Voxybuns), also licensed under the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for details.

---

<div align="center">

### Built for Godot. Kept swift.

If Swift Inventory helps your project, consider leaving a review on the Godot Asset Store or starring the repository on GitHub.

</div>
