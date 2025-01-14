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
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:slice"
import "core:strings"
import ray "vendor:raylib"

track_video_clip :: struct {
	using rect:        ray.Rectangle,
	color:             ray.Color,
	draw_priority:     int,
	owner_track_index: int,
}

single_track :: struct {
	held_clips: [dynamic]track_video_clip,
	using rect: ray.Rectangle,
}

all_tracks: [dynamic]single_track
clip_being_dragged: ^track_video_clip
old_clip_being_dragged: track_video_clip
dragging_rect_starting_pos: ray.Vector2
dragging_rect_starting_offset: ray.Vector2
screen_x_dim := 1280
screen_y_dim := 720
track_height := 100
track_width := 70
should_run_game := true
bottom_of_bottom_track: f32 = 0

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
		cur_y_pos := f32(track_y_pos - y * track_height)
		append(
			&all_tracks,
			single_track{rect = Rectangle{0, cur_y_pos, f32(screen_x_dim), f32(track_height)}},
		)
		for x in 0 ..< 5 {
			x_pos_to_use :=
				0 if x == 0 else all_tracks[y].held_clips[x - 1].rect.x + all_tracks[y].held_clips[x - 1].rect.width
			append(
				&all_tracks[y].held_clips,
				track_video_clip {
					rect              = Rectangle {
						f32(x_pos_to_use),
						cur_y_pos,
						// f32(25 * u8(rand.float32() * 5 + 2)),
						f32((y + 1) * 40),
						f32(track_height),
					},
					color             = Color {
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						u8(rand.float32() * 255),
						255,
					},
					owner_track_index = y,
				},
			)
		}
	}
}

init :: proc() {
	using ray
	track_y_pos = (screen_y_dim - track_height - 30)
	bottom_of_bottom_track = f32(track_y_pos + track_height)
	SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	InitWindow(i32(screen_x_dim), i32(screen_y_dim), "First Odin Game2")

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
}

move_clip_from_track_a_to_b :: proc(clip_to_move: ^track_video_clip, a, b: int) {
	copy: track_video_clip
	for cur_clip, x in &all_tracks[a].held_clips {
		if cur_clip == clip_to_move^ {
			copy = cur_clip
			ordered_remove(&all_tracks[a].held_clips, x)
			copy.y = all_tracks[b].y
			append(&all_tracks[b].held_clips, copy)
			break
		}
	}
}

drag_rectangles :: proc() {
	using ray
	if !IsMouseButtonDown(MouseButton.LEFT) {
		// change the track that the clip is on
		if clip_being_dragged != nil && old_clip_being_dragged.y != clip_being_dragged.y {
			move_clip_from_track_a_to_b(
				clip_being_dragged,
				old_clip_being_dragged.owner_track_index,
				clip_being_dragged.owner_track_index,
			)
		}

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
		outer: for y in 0 ..< 3 {
			for &clip in all_tracks[y].held_clips {
				if CheckCollisionPointRec(GetMousePosition(), clip.rect) &&
				   IsMouseButtonDown(MouseButton.LEFT) &&
				   clip_being_dragged == nil {
					clip_being_dragged = &clip
					old_clip_being_dragged = clip
					dragging_rect_starting_pos = Vector2{clip.x, clip.y}
					dragging_rect_starting_offset = GetMousePosition() - Vector2{clip.x, clip.y}

					clip_being_dragged.draw_priority = highest_draw_priority
					highest_draw_priority += 1
					break outer
				}
			}
		}
	} else {
		new_pos :=
			dragging_rect_starting_pos +
			(GetMousePosition() - dragging_rect_starting_pos) -
			dragging_rect_starting_offset

		clip_being_dragged^.rect.x = new_pos.x
		new_track_index := int(bottom_of_bottom_track - GetMousePosition().y) / track_height
		if new_track_index >= 0 && new_track_index < len(all_tracks) {
			clip_being_dragged^.owner_track_index = new_track_index
		}
		clip_being_dragged^.rect.y =
			bottom_of_bottom_track - f32((new_track_index + 1) * track_height)

	}
}

reorder_clips_on_track :: proc(track_index: int) {
	assert(track_index < len(all_tracks))

	slice.sort_by_key(all_tracks[track_index].held_clips[:], proc(clip: track_video_clip) -> f32 {
		return clip.x + clip.width / 2
	})
	for &clip, i in all_tracks[track_index].held_clips {
		goal :=
			0 if i == 0 else all_tracks[track_index].held_clips[i - 1].x + all_tracks[track_index].held_clips[i - 1].width
		dist_to_goal := goal - clip.x
		clip.x = goal - dist_to_goal / 1.5
	}
}

run_drawing :: proc() {
	using ray
	BeginDrawing()
	ClearBackground(SKYBLUE)
	// the track background
	for &track in all_tracks {
		DrawRectangleRec(track.rect, DARKGRAY)
	}

	all_clips: [dynamic]track_video_clip
	defer delete(all_clips)
	for y in 0 ..< 3 {
		for &clip in all_tracks[y].held_clips {
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
		words := strings.split(fmt.aprint(clip_being_dragged^, sep = "\n"), " ")
		for word, y in words {
			DrawText(fmt.caprint(word), i32(screen_x_dim / 2), i32(50 + y * 20), 20, BLACK)
		}
	}

	for y in 0 ..< 3 {
		DrawText(
			fmt.caprint(len(all_tracks[y].held_clips)),
			10,
			i32(all_tracks[y].y + all_tracks[y].height / 2),
			20,
			BLACK,
		)
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
