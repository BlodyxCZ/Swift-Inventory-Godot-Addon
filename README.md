<div align="center">

<img src="addons/Swift_Inventory/Icons/SwiftGrid.svg" alt="SwiftInv" width="112">

# SwiftInv

### A small, data-driven inventory system for Godot 4

Build inventories with unmatched speed.

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/Language-GDScript-478CBF?logo=godot-engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
![Status](https://img.shields.io/badge/Status-In%20Development-orange)

</div>

---

## ✨ Features

- **Resource-based inventory data** — inventories and item definitions are independent from the UI.
- **Automatic stacking** — fills compatible stacks before occupying empty slots.
- **Stack limits** — every item defines its own `max_stack_size`.
- **Move, swap & transfer** — manipulate stacks inside one inventory or between multiple inventories.
- **Partial stack movement** — move only as much as the destination can accept.
- **Automatic grid synchronization** — `SwiftGrid` creates and binds slots to match inventory size.
- **Drag & drop** — `SwiftSlot` provides built-in inventory drag/drop behavior.
- **Editor-friendly workflow** — create item resources and populate slots directly from the Inspector.
- **Change notifications** — react to inventory mutations through a single typed signal.
- **Extensible item info UI** — subclass `SwiftInfo` to build your own tooltip or hover panel.
- **Lightweight architecture** — no required singleton and no inventory logic coupled to a specific game.

> [!TIP]
> `SwiftInventory` owns the data. `SwiftGrid` and `SwiftSlot` only represent it.  
> That separation makes the same inventory usable by different UIs or gameplay systems.

---

## 🧩 Architecture

| Class | Responsibility |
| --- | --- |
| `SwiftItemData` | Static item definition: ID, name, description, icon, tags and stack size |
| `SwiftItemStack` | An item definition plus its current amount |
| `SwiftInventory` | Inventory state and all inventory operations |
| `SwiftGrid` | Automatically creates, binds and lays out inventory slots |
| `SwiftSlot` | Displays one inventory address and handles drag/drop |
| `SwiftInfo` | Base control for custom hover information |

---

## 📦 Installation

Copy the addon into your Godot project so the structure looks like:

```text
res://
└── addons/
    └── Swift_Inventory/
        ├── SwiftInventory.gd
        ├── SwiftItemData.gd
        ├── SwiftItemStack.gd
        ├── SwiftGrid.gd
        ├── SwiftSlot.gd
        ├── SwiftInfo.gd
        └── Icons/
```

Because the scripts use `class_name`, the SwiftInv classes become available directly in GDScript once Godot imports them.

---

## 🚀 Quick Start

### 1. Create an item

Create a new `SwiftItemData` resource and configure it in the Inspector.

For example:

```text
id              = "health_potion"
display_name    = "Health Potion"
description     = "Restores a little health."
icon            = <your texture>
max_stack_size  = 10
tags            = ["consumable", "potion"]
```

A single `SwiftItemData` resource can be reused by every stack of that item.

### 2. Create an inventory

Create a `SwiftInventory` resource and give it a size.

```gdscript
@export var inventory: SwiftInventory
@export var health_potion: SwiftItemData

func _ready() -> void:
    inventory.size = 24

    var remaining := inventory.try_add(health_potion, 5)

    if remaining > 0:
        print("Inventory could not fit %d potions." % remaining)
```

`try_add()` returns the quantity that **could not** be inserted, making overflow easy to handle.

### 3. Display it with `SwiftGrid`

Add a `SwiftGrid` node and assign your `SwiftInventory` resource to its `swift_inventory` property.

Then configure:

```text
Inventory Size  24
Slot Size       48 × 48
Separation       6 × 6
```

The grid automatically creates the required `SwiftSlot` children and keeps them bound to their matching inventory addresses.

Changing the inventory size updates the grid automatically.

---

## 🎒 Working With Items

### Add items

```gdscript
var remaining := inventory.try_add(item_data, 20)

if remaining > 0:
    print("%d items did not fit." % remaining)
```

SwiftInv first fills existing compatible stacks, then creates new stacks in empty addresses.

### Remove items

```gdscript
var result := inventory.try_remove(3, 2)

if result != OK:
    print("Could not remove the requested items.")
```

### Move or stack items

```gdscript
var remaining := inventory.try_move(
    0, # from address
    5, # to address
    3  # quantity
)
```

If the destination is empty, the stack is moved or split.

If it contains the same item, SwiftInv fills the destination up to its stack limit.

### Swap stacks

```gdscript
var result := inventory.try_swap(0, 4)
```

You can also swap between two inventories:

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

`transfer_to()` returns `OK` only when the source inventory was completely transferred.

### Set a slot directly

```gdscript
inventory.set_stack(4, item_data, 3)
```

Clear it by passing `null`:

```gdscript
inventory.set_stack(4, null)
```

This is also the operation used by editor-facing slot properties.

---

## 🖱️ Drag & Drop

`SwiftSlot` implements Godot's built-in drag/drop callbacks.

Dragging a stack carries:

```gdscript
{
    "inventory": swift_inventory,
    "address": address,
    "quantity": item.amount,
}
```

Dropping onto another slot can:

- move a stack,
- merge matching stacks,
- swap different items,
- transfer items between inventories.

That means custom UI can participate in SwiftInv's drag/drop system by using the same payload shape.

---

## 📡 Reacting to Inventory Changes

Every `SwiftInventory` exposes:

```gdscript
signal on_change(
    type: CHANGES,
    from_address: int,
    to_address: int
)
```

Connect once and react only to the mutations your UI or game system cares about:

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
            print("Added item at ", to_address)

        SwiftInventory.CHANGES.remove:
            print("Removed item from ", from_address)

        SwiftInventory.CHANGES.move:
            print("Moved ", from_address, " -> ", to_address)

        SwiftInventory.CHANGES.swap:
            print("Swapped ", from_address, " <-> ", to_address)

        SwiftInventory.CHANGES.transfer:
            print("Inventory transfer changed an address")

        SwiftInventory.CHANGES.set:
            print("Set stack at ", to_address)

        SwiftInventory.CHANGES.size:
            print("Inventory size changed")
```

Available change types:

```gdscript
enum CHANGES {
    add,
    remove,
    move,
    swap,
    transfer,
    set,
    size
}
```

---

## 🏷️ Item Data

`SwiftItemData` intentionally stays simple:

```gdscript
class_name SwiftItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var tags: Array[StringName] = []
```

Extend it when your game needs more metadata:

```gdscript
class_name EquipmentData
extends SwiftItemData

@export var damage: float
@export var durability: int
@export var equipment_slot: StringName
```

The inventory continues working with subclasses because stacks reference `SwiftItemData`.

---

## 🔧 API Reference

<details>
<summary><strong>SwiftInventory</strong></summary>

<br>

| API | Returns | Description |
| --- | --- | --- |
| `try_add(data, quantity)` | `int` | Adds as much as possible and returns the remaining quantity |
| `try_remove(address, quantity)` | `Error` | Removes an exact quantity from a stack |
| `try_move(from, to, quantity)` | `int` | Moves/stacks items and returns the remaining quantity |
| `try_swap(first, second, other_inventory = null)` | `Error` | Swaps two occupied addresses |
| `try_transfer(from, other_inventory, to, quantity)` | `int` | Transfers items and returns the remaining quantity |
| `transfer_to(other_inventory)` | `Error` | Attempts to transfer the entire inventory |
| `set_stack(address, data, quantity = 1)` | `Error` | Replaces or clears one address |
| `is_full()` | `bool` | Returns whether no empty address remains |

</details>

<details>
<summary><strong>SwiftItemStack</strong></summary>

<br>

| API | Returns | Description |
| --- | --- | --- |
| `item_data` | `SwiftItemData` | Item represented by the stack |
| `amount` | `int` | Current stack quantity |
| `get_reserve()` | `int` | Remaining space before reaching the stack limit |

</details>

<details>
<summary><strong>SwiftGrid</strong></summary>

<br>

| Property | Description |
| --- | --- |
| `swift_inventory` | Inventory represented by the grid |
| `inventory_size` | Proxy for `swift_inventory.size` |
| `slot_size` | Pixel size of generated slots |
| `separation` | Horizontal and vertical spacing between slots |

</details>

---

<div align="center">

### Built for Godot. Kept swift.

If SwiftInv helps your project, consider giving the repository a ⭐.

### Credits

Some icons are based on icons from [@icons — Custom node icons](https://github.com/Voxybuns/at-icons?tab=MIT-1-ov-file)
by [Voxybuns](https://github.com/Voxybuns), licensed under the MIT License.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

</div>
