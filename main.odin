package main
/* 
//uncomment this for web builds

package game
import "os"

//run this:
WEB:
c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web\source>cd c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web && cmd /c "c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web\build_web.bat" 

DESKTOP
c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web\source>cd c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web && cmd /c "c:\Users\cobou\Documents\LanguagesRandom\odin\game_test\odin-raylib-web\build_desktop.bat" && 
build\desktop\game_desktop.exe
 */
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:sort"
import ray "vendor:raylib"

track_video_clip :: struct {
	using rect:    ray.Rectangle,
	color:         ray.Color,
	draw_priority: int,
}
single_track :: [dynamic]track_video_clip
all_tracks: [dynamic]single_track
clip_being_dragged: ^track_video_clip
dragging_rect_starting_pos: ray.Vector2
dragging_rect_starting_offset: ray.Vector2
screen_x_dim := 1280
screen_y_dim := 720
track_height := 100
track_width := 70
should_run_game := true
//dont try to calculate things here, do that in init
track_y_pos := 0
highest_draw_priority := 1

main :: proc() {
	context.logger = log.create_console_logger()
	init()
	update()
	shutdown()
}

setup_all_tracks :: proc() {
	using ray
	rand.reset(42)

	clear(&all_tracks)
	for y in 0 ..< 3 {
		append(&all_tracks, single_track{})
		for x in 0 ..< 5 {
			append(
				&all_tracks[y],
				track_video_clip {
					rect = Rectangle {
						f32(
							0 if x == 0 else all_tracks[y][x - 1].rect.x + all_tracks[y][x - 1].rect.width,
						),
						f32(track_y_pos - y * track_height),
						f32(25 * u8(rand.float32() * 5 + 2)),
						f32(track_height),
					},
					color = Color {
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						255,
					},
				},
			)
		}
		// log.info("Logging works!")
		// log.info(all_tracks[y])
	}
}

init :: proc() {
	using ray
	track_y_pos = (screen_y_dim - track_height - 30)
	SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	InitWindow(i32(screen_x_dim), i32(screen_y_dim), "First Odin Game2")
	// log.info("track_y_pos", track_y_pos)

	ray.SetExitKey(ray.KeyboardKey.ESCAPE)
	ray.SetTargetFPS(60)
	setup_all_tracks()
}

update :: proc() {
	using ray
	for should_run_game {
		game_logic()
		run_drawing()
		if WindowShouldClose() ||
		   (IsKeyDown(KeyboardKey.LEFT_CONTROL) && IsKeyPressed(KeyboardKey.B)) ||
		   (IsKeyDown(KeyboardKey.F8)) {
			should_run_game = false
		}
	}
	free_all(context.temp_allocator)
}

game_logic :: proc() {
	using ray
	if IsKeyPressed(KeyboardKey.R) {
		setup_all_tracks()
	}
	drag_rectangles()
	if IsKeyPressed(KeyboardKey.C) {
		// log.info("before", clip_being_dragged)
		// clip_being_dragged = mem.ptr_offset(clip_being_dragged, size_of(track_video_clip))
		// log.info("after", clip_being_dragged)
	}
}

drag_rectangles :: proc() {
	using ray
	if !IsMouseButtonDown(MouseButton.LEFT) || clip_being_dragged == nil {
		for y in 0 ..< len(all_tracks) {
			reorder_clips_on_track(y)
		}
	}

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
					dragging_rect_starting_offset = GetMousePosition() - Vector2{clip.x, clip.y}

					clip_being_dragged.draw_priority = highest_draw_priority
					highest_draw_priority += 1
				}
			}
		}
	} else {
		new_pos :=
			dragging_rect_starting_pos +
			(GetMousePosition() - dragging_rect_starting_pos) -
			dragging_rect_starting_offset

		clip_being_dragged^.rect.x = new_pos.x
		// clip_being_dragged += 
		// swap
		// for y in 0 ..< len(all_tracks) {
		// 	reorder_clips_on_track(y)
		// }
		// rect_being_dragged^.y = new_pos.y
	}
}

reorder_clips_on_track :: proc(track_index: int) {
	assert(track_index < len(all_tracks))

	slice.sort_by_key(all_tracks[track_index][:], proc(clip: track_video_clip) -> f32 {
		return clip.x + clip.width / 2
	})
	// all_tracks[track_index][:] = 
	for &clip, i in all_tracks[track_index] {
		goal :=
			0 if i == 0 else all_tracks[track_index][i - 1].x + all_tracks[track_index][i - 1].width
		dist_to_goal := goal - clip.x
		clip.x = goal - dist_to_goal / 1.5
	}
}

run_drawing :: proc() {
	using ray
	BeginDrawing()
	ClearBackground(SKYBLUE)
	// the track background
	DrawRectangle(0, i32(track_y_pos), i32(screen_x_dim), i32(track_height), DARKGRAY)
	all_clips: [dynamic]track_video_clip
	for y in 0 ..< 3 {
		for &clip in all_tracks[y] {
			append(&all_clips, clip)
		}
	}
	slice.sort_by_key(all_clips[:], proc(x: track_video_clip) -> int {
		return x.draw_priority
	})
	for &clip in all_clips {
		DrawRectangleRec(clip.rect, clip.color)
		DrawRectangleLinesEx(clip.rect, 3, BLACK)
	}
	if clip_being_dragged != nil {
		DrawRectangleRec(clip_being_dragged.rect, clip_being_dragged.color)
		DrawRectangleRec(clip_being_dragged.rect, Color{0, 0, 0, 40})
		DrawRectangleLinesEx(clip_being_dragged.rect, 6, BLACK)
	}
	EndDrawing()

}


// In a web build, this is called when browser changes size. Remove the
// `ray.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	ray.SetWindowSize(i32(w), i32(h))
}

shutdown :: proc() {
	ray.CloseWindow()
}
