package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import ray "vendor:raylib"

single_track: [dynamic]ray.Rectangle
rect_being_dragged: ^ray.Rectangle
dragging_rect_starting_pos: ray.Vector2
dragging_rect_starting_offset: ray.Vector2


main :: proc() {
	using ray
	screen_x_dim := 800
	screen_y_dim := 480
	InitWindow(i32(screen_x_dim), i32(screen_y_dim), "First Odin Game")
	should_run_game := true
	SetExitKey(KeyboardKey.ESCAPE)
	SetTargetFPS(60)
	// current_config_flags : bit_set[ConfigFlag]
	// // current_config_flags[WINDOW_ALWAYS_RUN]
	// SetConfigFlags(..WINDOW_UNDECORATED)
	track_height := 100
	track_width := 70
	for i in 1 ..= 5 {
		append(
			&single_track,
			Rectangle {
				f32(track_width * i),
				cast(f32)(screen_y_dim - track_height - 30),
				f32(track_width),
				f32(track_height),
			},
		)
		fmt.println(single_track[len(single_track) - 1])
	}
	for should_run_game {
		drag_rectangles()
		run_drawing()
		if WindowShouldClose() {
			should_run_game = false
		}
	}
}

drag_rectangles :: proc() {
	using ray
	if !IsMouseButtonDown(MouseButton.LEFT) {
		rect_being_dragged = nil
		return
	}
	// get the initial offset, the calculation for where to draw is done in run_drawing()
	if rect_being_dragged == nil {
		for &rect in single_track {
			if CheckCollisionPointRec(GetMousePosition(), rect) &&
			   IsMouseButtonDown(MouseButton.LEFT) &&
			   (rect_being_dragged == nil || rect != rect_being_dragged^) {
				rect_being_dragged = &rect
				dragging_rect_starting_pos = Vector2{rect.x, rect.y}
				dragging_rect_starting_offset = GetMousePosition() - Vector2{rect.x, rect.y}
			}
		}
	} else {
		new_pos :=
			dragging_rect_starting_pos +
			(GetMousePosition() - dragging_rect_starting_pos) -
			dragging_rect_starting_offset
		rect_being_dragged^.x, rect_being_dragged^.y = new_pos.x, new_pos.y
	}
}

run_drawing :: proc() {
	using ray
	BeginDrawing()
	ClearBackground(SKYBLUE)
	DrawRectangle(100, 400, 50, 50, BLACK)

	rand.reset(123)
	for &rect in single_track {
		color_to_use := Color {
			u8(rand.float32() * 255),
			u8(rand.float32() * 255),
			u8(rand.float32() * 255),
			255,
		}
		DrawRectangle(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height), color_to_use)
	}
	EndDrawing()

}
