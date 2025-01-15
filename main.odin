package main

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:slice"
import "core:strings"
// import "core:sys/windows"
import ray "vendor:raylib"

track_video_clip :: struct {
	using rect:        ray.Rectangle,
	color:             ray.Color,
	draw_priority:     int,
	owner_track_index: int,
	text:              string,
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
undo_states: [dynamic][dynamic]single_track

click_sound : ray.Sound


default_font := ray.GetFontDefault()
cur_level: u64 = 0
// TODO: change to false before release
has_dragged := false
//dont try to calculate things here, do that in init
track_y_pos := 0
highest_draw_priority := 1
red_color := ray.Color{215, 38, 56, 255}
orange_color := ray.Color{244, 96, 54, 255}
yellow_color := ray.Color{255, 210, 63, 255}
blue_color := ray.Color{38, 84, 124, 255}
green_color := ray.Color{33, 161, 121, 255}
teal_color := ray.Color{0, 252, 243, 255}

theme_colors := [6]ray.Color{}

single_level_settings :: struct {
	total_tiles: uint,
	track_count: int,
	top_wants:   [dynamic]ray.Color,
	side_wants:  [dynamic]ray.Color,
}

all_levels_settings: [5]single_level_settings

main :: proc() {
	// context.logger = log.create_console_logger()
	init()
	update()
	shutdown()
}

init :: proc() {
	using ray
	track_y_pos = (screen_y_dim - track_height - 30)
	bottom_of_bottom_track = f32(track_y_pos + track_height)
	SetConfigFlags({.VSYNC_HINT})
	InitWindow(i32(screen_x_dim), i32(screen_y_dim), "First Odin Game2")

	ray.SetExitKey(ray.KeyboardKey.ESCAPE)
	ray.SetTargetFPS(60)
	theme_colors = {red_color, orange_color, yellow_color, blue_color, green_color, teal_color}

	click_sound = LoadSound("assets/click.wav")
	all_levels_settings[0] = single_level_settings {
		total_tiles = 5,
	}
	append(&all_levels_settings[0].side_wants, red_color, orange_color)
	append(&all_levels_settings[0].top_wants, yellow_color, orange_color)

	all_levels_settings[1] = single_level_settings {
		total_tiles = 6,
	}
	append(&all_levels_settings[1].side_wants, red_color, teal_color)
	append(&all_levels_settings[1].top_wants, orange_color, blue_color)

	
	all_levels_settings[2] = single_level_settings {
		total_tiles = 7,
	}
	append(&all_levels_settings[2].side_wants, red_color, teal_color)
	append(&all_levels_settings[2].top_wants, orange_color, blue_color)

	setup_all_tracks()

}

advance_level :: proc() {
	cur_level += 1
	setup_all_tracks()
}

setup_all_tracks :: proc() {
	using ray
	// rand.reset(cur_level)

	clear(&all_tracks)
	color_pos := 0
	for y in 0 ..< 2 {
		cur_y_pos := f32(track_y_pos - y * track_height)
		starting_x := f32(0)
		append(
			&all_tracks,
			single_track {
				rect = Rectangle{starting_x, cur_y_pos, f32(screen_x_dim), f32(track_height)},
			},
		)
		// log.info(all_levels_settings[cur_level].total_tiles)
		for x in 0 ..< all_levels_settings[cur_level].total_tiles / 2 + uint(y % 2) {
			x_pos_to_use :=
				starting_x if x == 0 else all_tracks[y].held_clips[x - 1].rect.x + all_tracks[y].held_clips[x - 1].rect.width
			append(
				&all_tracks[y].held_clips,
				track_video_clip {
					rect = Rectangle {
						f32(x_pos_to_use),
						cur_y_pos,
						f32((y + 1) * 40),
						f32(track_height),
					},
					color = theme_colors[color_pos % len(theme_colors)],
					owner_track_index = y,
					text = "PSD",
				},
			)
			color_pos += 1
		}
	}
}


update :: proc() {
	using ray
	for should_run_game {
		if IsKeyPressed(KeyboardKey.Z) {
			restore_state()
		}
		game_logic()
		run_drawing()
		if WindowShouldClose() ||
		   (IsKeyDown(KeyboardKey.LEFT_CONTROL) && IsKeyPressed(KeyboardKey.B)) ||
		   IsKeyDown(KeyboardKey.F8) ||
		   IsKeyDown(KeyboardKey.LEFT_ALT) {
			should_run_game = false
		}

		free_all(context.temp_allocator)
	}
}

game_logic :: proc() {
	using ray
	if IsKeyPressed(KeyboardKey.R) {
		setup_all_tracks()
	}
	if cur_level == 2 {
		return
	}
	drag_rectangles()
}

move_clip_from_track_a_to_b :: proc(clip_to_move: ^track_video_clip, a, b: int) {
	copy: track_video_clip
	for cur_clip, x in all_tracks[a].held_clips {
		if cur_clip == clip_to_move^ {
			copy = cur_clip
			ordered_remove(&all_tracks[a].held_clips, x)
			copy.y = all_tracks[b].y
			append(&all_tracks[b].held_clips, copy)
			break
		}
	}
}

store_state :: proc() {
	// TODO account for when more tracks are added at run time
	new_state: [dynamic]single_track
	for &old_track in all_tracks {
		new_track: single_track
		new_track.rect = old_track.rect
		for clip in old_track.held_clips {
			append(&new_track.held_clips, clip)
		}
		append(&new_state, new_track)
	}
	append(&undo_states, new_state)
	// log.info("stored state")
}

restore_state :: proc() {
	if len(undo_states) == 0 {
		return
	}
	// log.info("restored state")
	popped_state := pop(&undo_states)
	all_tracks = popped_state
}

release_rectangle_as_needed :: proc() {
	using ray
	// change the track that the clip is on
	if IsMouseButtonDown(MouseButton.LEFT) {
		return
	}

	if clip_being_dragged != nil && old_clip_being_dragged.y != clip_being_dragged.y {
		move_clip_from_track_a_to_b(
			clip_being_dragged,
			old_clip_being_dragged.owner_track_index,
			clip_being_dragged.owner_track_index,
		)
		has_dragged = true
	}
	for y in 0 ..< len(all_tracks) {
		reorder_clips_on_track(y)
	}
}

drag_rectangles :: proc() {
	using ray
	release_rectangle_as_needed()

	if !IsMouseButtonDown(MouseButton.LEFT) {
		clip_being_dragged = nil
		return
	}
	// get the initial offset, the calculation for where to draw is done in run_drawing()
	if clip_being_dragged == nil {
		outer: for y in 0 ..< len(all_tracks) {
			for &clip in all_tracks[y].held_clips {
				if CheckCollisionPointRec(GetMousePosition(), clip.rect) &&
				   IsMouseButtonDown(MouseButton.LEFT) &&
				   clip_being_dragged == nil {
					store_state()
					PlaySound(click_sound)
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
		return clip.x
	})
	for &clip, i in all_tracks[track_index].held_clips {
		goal :=
			0 if i == 0 else all_tracks[track_index].held_clips[i - 1].x + all_tracks[track_index].held_clips[i - 1].width
		dist_to_goal := goal - clip.x
		clip.x = goal - dist_to_goal / 1.5
	}
}

// window_testing :: proc() {
// 	ray.file
// }

get_rect_center :: proc(rect: ^ray.Rectangle) -> (ret: ray.Vector2) {
	ret = {rect.x + rect.width / 2, rect.y + rect.height / 2}
	return ret
}

check_right_view :: proc() -> bool {
	for &required in all_levels_settings[cur_level].side_wants {
		found := false
		for &track, y in all_tracks {
			if len(track.held_clips) >= 1 && track.held_clips[len(track.held_clips) - 1].color == required {
				found = true
			}
		}
		if !found {
			return false
		}
	}
	return true
}

check_top_view :: proc() -> bool {
	for &required in all_levels_settings[cur_level].top_wants {
		found := false
		highest_x_seen: f32 = 0
		#reverse for &track, y in all_tracks {
			for x in 0 ..< len(track.held_clips) {
				if track.held_clips[x].x + track.held_clips[x].width <= highest_x_seen {
					break
				}
				highest_x_seen = max(
					highest_x_seen,
					track.held_clips[x].x + track.held_clips[x].width,
				)
				if track.held_clips[x].color == required {
					// log.info("found", required)
					found = true
				}
			}
		}
		if !found {
			return false
		}
	}
	return true
}

run_drawing :: proc() {
	using ray
	BeginDrawing()
	defer EndDrawing()
	ClearBackground(BLACK)
	if cur_level == 2 {
		DrawText(
			"You win!\n\nI ran out of time (I found out about the jam\nat 9 pm local time, with 9 hours until the deadline).\nI just so happened to start a project a \nfew days ago that could be made to fit the theme, and here\n we are. I didn't want to stay up much past 11 :-)",
			10,
			i32(all_tracks[len(all_tracks) - 1].y) - 100,
			30,
			WHITE,
		)
		return
	}
	//instructions:
	if !has_dragged {
		DrawText(
			"Click and drag to \nmove tiles (even to the other row):",
			10,
			i32(all_tracks[len(all_tracks) - 1].y) - 100,
			30,
			WHITE,
		)
	} else {
		text_x: i32 = 10
		text_y: i32 = 200
		color_square_dim := 50
		DrawText(
			"Make the view from the top see \nat least these (any order)",
			text_x,
			text_y,
			30,
			WHITE,
		)
		text_y += 70
		for &color, x in all_levels_settings[cur_level].top_wants {
			DrawRectangle(text_x + i32(x * color_square_dim + 10), text_y, 50, 50, color)
		}
		text_y += 70
		DrawText(
			"Make the view from the right see at least these (any order)",
			text_x,
			text_y,
			30,
			WHITE,
		)
		text_y += 50

		for &color, x in all_levels_settings[cur_level].side_wants {
			DrawRectangle(text_x + i32(x * color_square_dim), text_y, 50, 50, color)
		}
	}

	// the track background
	for &track in all_tracks {
		DrawRectangleRec(track.rect, WHITE)
	}

	// if (check_right_view()) {
	// 	log.info("right is satisfied")
	// }
	// if (check_top_view()) {
	// 	log.info("top is satisfied")
	// }

	if check_right_view() && check_top_view() {
		advance_level()
	}

	all_clips: [dynamic]track_video_clip
	defer delete(all_clips)
	for y in 0 ..< len(all_tracks) {
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
		DrawRectangleRec(clip_being_dragged.rect, clip_being_dragged.color)
		DrawRectangleRec(clip_being_dragged.rect, Color{0, 0, 0, 40})
		DrawRectangleLinesEx(clip_being_dragged.rect, 6, BLACK)
	}

	
}


// In a web build, this is called when browser changes size. Remove the
// `ray.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	// ray.SetWindowSize(i32(w), i32(h))
}

shutdown :: proc() {
	ray.CloseWindow()
}
