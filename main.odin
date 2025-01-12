package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import ray "vendor:raylib"

track_video_clip :: struct {
	using rect:  ray.Rectangle,
	color: ray.Color,
}
single_track :: [dynamic]track_video_clip
all_tracks: [dynamic]single_track
clip_being_dragged: ^track_video_clip
dragging_rect_starting_pos: ray.Vector2
dragging_rect_starting_offset: ray.Vector2
screen_x_dim := 800
screen_y_dim := 480
track_height := 100
track_width := 70
track_y_pos := (screen_y_dim - track_height - 30)


main :: proc() {
	using ray
	InitWindow(i32(screen_x_dim), i32(screen_y_dim), "First Odin Game")
	should_run_game := true
	SetExitKey(KeyboardKey.ESCAPE)
	SetTargetFPS(60)
	// current_config_flags : bit_set[ConfigFlag]
	// // current_config_flags[WINDOW_ALWAYS_RUN]
	// SetConfigFlags(..WINDOW_UNDECORATED)
	rand.reset(42)

	for y in 0 ..< 3 {
		append(&all_tracks, single_track{})
		for x in 0 ..< 5 {
			append(
				&all_tracks[y],
				track_video_clip {
					Rectangle {
						f32(
							0 if x == 0 else all_tracks[y][x - 1].rect.x + all_tracks[y][x - 1].rect.width,
						),
						f32(track_y_pos - y * track_height),
						f32(25 * u8(rand.float32() * 5 + 2)),
						f32(track_height),
					},
					Color {
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						255,
					},
				},
			)
		}
	}
	for should_run_game {
		drag_rectangles()
		run_drawing()
		if WindowShouldClose() ||
		   (IsKeyDown(KeyboardKey.LEFT_CONTROL) && IsKeyPressed(KeyboardKey.B)) {
			should_run_game = false
		}
	}
}

drag_rectangles :: proc() {
	using ray
	if !IsMouseButtonDown(MouseButton.LEFT) {
		clip_being_dragged = nil
		return
	}
	// get the initial offset, the calculation for where to draw is done in run_drawing()
	if clip_being_dragged == nil {
		for y in 0 ..< 3 {
			for &clip in all_tracks[y] {
				if CheckCollisionPointRec(GetMousePosition(), clip.rect) &&
				   IsMouseButtonDown(MouseButton.LEFT) &&
				   (clip_being_dragged == nil || clip != clip_being_dragged^) {
					clip_being_dragged = &clip
					dragging_rect_starting_pos = Vector2{clip.x, clip.y}
					dragging_rect_starting_offset =
						GetMousePosition() - Vector2{clip.x, clip.y}
				}
			}
		}
	} else {
		new_pos :=
			dragging_rect_starting_pos +
			(GetMousePosition() - dragging_rect_starting_pos) -
			dragging_rect_starting_offset

		clip_being_dragged^.x = new_pos.x
		// rect_being_dragged^.y = new_pos.y
	}
}

run_drawing :: proc() {
	using ray
	BeginDrawing()
	ClearBackground(SKYBLUE)
	// the track background
	DrawRectangle(0, i32(track_y_pos), i32(screen_x_dim), i32(track_height), DARKGRAY)

	for y in 0 ..< 3 {
		for &clip in all_tracks[y] {
            using clip
			DrawRectangleRec(rect, color)
		}
	}
	if clip_being_dragged != nil {
        using clip_being_dragged
		DrawRectangleRec(rect, color)
		DrawRectangleLinesEx(rect, 5, BLACK)
	}
	EndDrawing()

}
