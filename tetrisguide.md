1. Prepare the scene for 3 spawn slots above calendar_ui2
In the calendartetris.tscn scene:
Select tetromino_lib.
Add three Position2D (or Node2D) children under it, for example:
spawn_slot_0
spawn_slot_1
spawn_slot_2
Move those 3 nodes in the editor so they sit above calendar_ui2 where you visually want the three pieces to appear.
Leave your existing shape_o_area, shape_i_area, shape_s_area, etc. off to the side where they already are (negative X).
These will act as hidden templates/prefabs from which you duplicate pieces.
2. Attach a new script to tetromino_lib
Select tetromino_lib node.
Click Attach Script → create tetromino_lib.gd.
In that script, plan these members:
References:
onready var board = $"../grid_container" (your 20×10 board node).
onready var slots = [ $spawn_slot_0, $spawn_slot_1, $spawn_slot_2 ].
Library of shapes:
A way to map shape names to the template nodes, e.g.:
"O" → $shape_o_area
"I" → $shape_i_area
…
Active pieces array (one per slot):
Each element is a dictionary like:
shape_id
rotation_index
area (the actual Area2D instance you drag)
slot_index
placed (bool)
original_position (Vector2)
Drag state:
var dragging = false
var selected_slot = -1
var drag_offset = Vector2.ZERO
3. Implement spawning 3 random pieces from the templates
In tetromino_lib.gd:
In _ready():
Fill an array of your template nodes, for example:
var template_shapes = [ $shape_o_area, $shape_i_area, $shape_s_area, $shape_z_area, $shape_l_area, $shape_j_area, $shape_t_area ]
Initialize your pieces array to size 3.
For slot_index in 0, 1, 2, call a helper: spawn_piece(slot_index).
spawn_piece(slot_index) should:
Pick a random template from template_shapes.
Duplicate it:
var new_piece = template.duplicate()
(make sure to pass true if you want to duplicate subnodes, depending on your Godot version).
Add it as a child of tetromino_lib:
add_child(new_piece)
Move it to the slot position:
new_piece.global_position = slots[slot_index].global_position
Make sure it’s visible and its collision is enabled if needed.
Build a dictionary and store it:
pieces[slot_index] = { "shape_id": some_id, "rotation_index": 0, "area": new_piece, "slot_index": slot_index, "placed": false, "original_position": new_piece.global_position }
Now, when the scene runs, you should see 3 pieces above calendar_ui2.
4. Add basic board helpers to grid_container (your existing script)
You currently only draw tiles. You’ll need a bit of logic there to accept pieces. In calendartetris.gd you can:
Add grid state:
A 2D array or 1D array marking whether each cell is empty or full.
Add helper functions:
world_to_cell(world_pos: Vector2) -> Vector2i
(using position of grid_container and TILE_SIZE).
can_place_piece(cells: Array[Vector2i], base_cell: Vector2i) -> bool
(check bounds and occupancy).
place_piece(cells: Array[Vector2i], base_cell: Vector2i, shape_id)
(mark cells occupied; later you can change visuals if you like).
You can do this later; for now you just need to know you will call something like:
board.can_place_piece(piece_cells, base_cell)
board.place_piece(piece_cells, base_cell, shape_id)
from tetromino_lib.
5. Handle mouse input centrally in tetromino_lib
In tetromino_lib.gd:
Enable _unhandled_input(event) (or _input if you prefer).
Left mouse press (start drag):
When left button is pressed:
Get the mouse global position: get_global_mouse_position().
Loop over the 3 pieces:
Skip if piece["placed"] or piece is null.
For each piece:
Get its Area2D node: piece["area"].
Option 1 (simple): check distance from mouse to area.global_position.
Option 2 (better): use its collision shape to check overlap (use area.get_overlapping_bodies() or do a manual rectangle check).
When you find the first that contains the mouse:
selected_slot = slot_index
dragging = true
drag_offset = piece["area"].global_position - mouse_position
Break.
Mouse motion (drag move):
When dragging == true and selected_slot != -1 and you receive mouse motion:
Get the piece dictionary: var piece = pieces[selected_slot].
Update position:
piece["area"].global_position = mouse_position + drag_offset
Right mouse press (rotate):
If dragging and selected_slot != -1 and right mouse just pressed:
Get the selected piece.
Increase its rotation_index: (rotation_index + 1) % 4 (or however many rotations).
Apply the rotation: there are 2 options:
Simple visual rotation: call piece["area"].rotation += PI/2.
Cell-based (if you have precomputed rotated CollisionPolygon2D / data): change which polygon or transform you use.
For now, even pure visual rotation (rotating the Area2D + Sprite2D) is enough to get behavior working.
Left mouse release (attempt place):
When left button released and dragging and selected_slot != -1:
dragging = false
Call a helper: try_place_piece_on_board(selected_slot).
6. try_place_piece_on_board in tetromino_lib
In tetromino_lib.gd, add:
Get the selected piece:
var piece = pieces[slot_index]
Compute a base cell from the piece’s position:
For example: center of the piece:
var world_pos = piece["area"].global_position
Convert to cell with your board helper: var base_cell = board.world_to_cell(world_pos)
Get the relative cells of this tetromino:
You may already have this logic as arrays in your collision data.
For now assume you can get cells_for_shape_and_rotation(shape_id, rotation_index) returning an array of Vector2i (0/1 offsets).
Let that be var local_cells = ....
Ask the board:
if board.can_place_piece(local_cells, base_cell):
board.place_piece(local_cells, base_cell, piece["shape_id"])
Mark piece["placed"] = true
Optionally: piece["area"].queue_free() or hide it.
pieces[slot_index] = null
Call spawn_piece(slot_index) to create a new random piece at that slot.
Else:
Move piece back:
piece["area"].global_position = piece["original_position"]
7. Enforce “can’t be moved after placed”
This falls out naturally:
You only ever start dragging if:
piece["placed"] == false.
Once you mark placed = true and either free or hide the node, there’s literally nothing to drag in that slot until the new piece is spawned.
So no additional trick is needed.
8. Recap in your exact terms
No new scene required. All logic goes into a new script on tetromino_lib.
Your existing shape_*_area nodes under tetromino_lib act as prefabs.
On start, tetromino_lib duplicates 3 random shapes and positions them at three spawn_slot_* nodes above calendar_ui2.
tetromino_lib:
Handles input:
Left-click to pick a piece and drag it.
Right-click (while dragging) to rotate it.
Release to ask grid_container (“board”) if it can be placed.
Talks to grid_container to validate and bake placement.
When a piece is successfully placed, it immediately spawns a fresh random one in that slot.
If you want, paste your eventual tetromino_lib.gd draft here and I can adjust the logic so it lines up perfectly with your calendartetris.gd grid and your specific shape/collision data.