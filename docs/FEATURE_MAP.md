# JellyAmp — Feature Map

**Read this before fixing any bug.** It maps every user-facing screen, menu,
button, setting, gesture and shortcut to the file/widget that implements it.
If you change the UI, update this file in the same PR.

Repo layout: `lib/screens/` (route-level screens) · `lib/components/`
(widgets, grouped by screen) · `lib/services/` (state/audio/network) ·
`lib/menus/` (long-press / popup menus) · `lib/theme/` (design system).

Route names are registered in `lib/app.dart` (`routes: { … }`).

---

## 1. App shell & navigation

| Feature | How to reach it | Implemented in |
|---|---|---|
| Splash / startup | app launch | `lib/screens/splash_screen.dart` |
| Login | first run, or logout | `lib/screens/login_screen.dart`, flow in `lib/components/LoginScreen/login_flow.dart` |
| Library view selector | after login / from home | `lib/screens/view_selector.dart`, `lib/components/ViewSelector/` |
| Navigation rail (tablet/desktop) | wide layouts | `lib/components/HomeScreen/finamp_navigation_rail.dart` |
| Bottom navigation / tabs | phone layouts | `lib/components/HomeScreen/` + tab config in `lib/services/` (`tab` models) |
| Tab visibility & order | Settings → Tabs | `lib/screens/tabs_settings_screen.dart` |
| Connectivity banner (offline) | automatic | `lib/services/connectivity_state.dart`, `lib/components/connectivity_status_indicator.dart` |

---

## 2. Home

| Feature | How to reach it | Implemented in |
|---|---|---|
| Home sections (recently played, favourites, etc.) | Home tab | `lib/components/HomeScreen/home_screen_content.dart` |
| Section editor (choose/reorder) | Home → edit | `lib/components/HomeScreen/home_section_editor.dart` |
| Quick action button | Home → FAB | `lib/components/HomeScreen/home_screen_quick_action_button.dart` |
| Quick action editor | Home settings | `lib/components/HomeScreen/quick_action_editor.dart` |
| "Show all" | section footer | `lib/components/HomeScreen/show_all_button.dart` |
| Search field | Music/Home header | `lib/components/HomeScreen/finamp_music_screen_header.dart` (250 ms debounce) |

---

## 3. Library / Music

| Feature | How to reach it | Implemented in |
|---|---|---|
| Music screen (tabs: albums, artists, genres, playlists) | Home / rail | `lib/screens/music_screen.dart`, `lib/components/MusicScreen/` |
| Track list item (tap = play, long-press = menu) | any list | `lib/components/AlbumScreen/track_list_tile.dart` |
| Item wrapper (album/artist tiles) | grid lists | `lib/components/MusicScreen/item_wrapper.dart` |
| Downloaded indicator | on tracks/albums | `lib/components/downloaded_indicator.dart` |
| Filter chips (curated rows) | album/artist rows | `lib/components/curated_item_filter_row.dart`, `curated_item_sections.dart` |
| Sort & view options | list header | `lib/components/MusicScreen/` + `lib/services/` sort models |

---

## 4. Album / Artist / Genre

| Feature | How to reach it | Implemented in |
|---|---|---|
| Album screen | tap album | `lib/screens/album_screen.dart`, `lib/components/AlbumScreen/` |
| Artist screen | tap artist | `lib/screens/artist_screen.dart`, `lib/components/ArtistScreen/` |
| Genre screen | tap genre | `lib/screens/genre_screen.dart`, `lib/components/GenreScreen/` |
| Play / shuffle album | album header | `lib/components/AlbumScreen/` |
| Favourite toggle | album/track | `lib/components/favorite_button.dart` |
| Add to playlist | track menu | `lib/components/AddToPlaylistScreen/` |

---

## 5. Player

| Feature | How to reach it | Implemented in |
|---|---|---|
| Player screen | tap mini-player | `lib/screens/player_screen.dart`, `lib/components/PlayerScreen/` |
| Split-screen player (tablet) | wide layouts | `lib/components/PlayerScreen/player_split_screen_scaffold.dart` |
| Big artwork | player top | `lib/components/PlayerScreen/player_screen_album_image.dart` |
| Blurred art background | player background | `lib/screens/blurred_player_screen_background.dart` |
| Seek bar (drag to seek) | player middle | `lib/components/PlayerScreen/progress_slider.dart` |
| Play/pause, skip prev/next | player controls | `lib/components/PlayerScreen/player_buttons.dart` |
| Loop mode | player controls | `lib/components/PlayerScreen/player_buttons_loop_mode.dart` |
| Playback order (shuffle) | player controls | `lib/components/PlayerScreen/player_buttons_playback_order.dart` |
| "More" menu (sleep timer, etc.) | player bottom-right | `lib/components/PlayerScreen/player_buttons_more.dart` |
| Sleep timer | More menu | `lib/components/PlayerScreen/sleep_timer_cancel_dialog.dart` |
| Queue button | player controls | `lib/components/PlayerScreen/queue_button.dart` |
| Queue list / reorder | player → queue | `lib/components/PlayerScreen/queue_list.dart` |
| Feature chips (bitrate, codec, etc.) | player info | `lib/components/PlayerScreen/feature_chips.dart` |
| Track info sheet | player → info | `lib/components/PlayerScreen/track_info_sheet.dart` |
| Lyrics | player → lyrics | `lib/screens/lyrics_screen.dart` |
| Volume normalisation indicator | player | `lib/screens/volume_normalization_settings_screen.dart` |
| Mini-player bar | bottom of every screen | `lib/components/now_playing_bar.dart` |

---

## 6. Gestures & shortcuts

| Gesture / key | Where | Effect | Implemented in |
|---|---|---|---|
| Tap mini-player | mini-player | open Player screen | `lib/components/now_playing_bar.dart` |
| Swipe mini-player **left/right** | mini-player | skip next / previous | `lib/components/now_playing_bar.dart` (horizontal `Dismissible`) |
| Swipe mini-player **up** | mini-player | open queue | `lib/components/now_playing_bar.dart` |
| Long-press track | any track list | track menu | `lib/menus/track_menu.dart` |
| Long-press album/artist | grid | item menu | `lib/menus/` |
| Drag seek bar | player | seek | `lib/components/PlayerScreen/progress_slider.dart` |
| Swipe to dismiss | dialogs/sheets | close | 33 `DismissDirection` uses across `lib/components/` |
| Media keys / headset | global | play/pause/skip | `lib/components/Shortcuts/music_control_shortcuts.dart` |
| Global shortcuts | desktop | app-wide keys | `lib/components/Shortcuts/global_shortcut_manager.dart` |

---

## 7. Downloads

| Feature | How to reach it | Implemented in |
|---|---|---|
| Downloads screen | Settings → Downloads | `lib/screens/downloads_screen.dart`, `lib/components/DownloadsScreen/` |
| Active downloads (progress) | Downloads | `lib/screens/active_downloads_screen.dart` |
| Download errors | Downloads | `lib/components/DownloadsScreen/downloads_error_screen.dart` |
| Download locations list | Settings → Downloads → Locations | `lib/screens/downloads_location_screen.dart` |
| Add download location | Locations → add | `lib/screens/add_download_location_screen.dart` |
| Downloaded marker | lists | `lib/components/downloaded_indicator.dart` |

---

## 8. Settings (18 sub-screens)

Entry: `lib/screens/settings_screen.dart`, widgets in
`lib/components/SettingsScreen/`.

| Setting | File |
|---|---|
| Home screen layout/sections | `lib/screens/home_screen_settings_screen.dart` |
| Tabs (which tabs show) | `lib/screens/tabs_settings_screen.dart` |
| Layout (grid/list, sizing) | `lib/screens/layout_settings_screen.dart` |
| Interaction (tap behaviour) | `lib/screens/interaction_settings_screen.dart` |
| Playback / audio service | `lib/screens/audio_service_settings_screen.dart` |
| Transcoding | `lib/screens/transcoding_settings_screen.dart` |
| Volume normalisation | `lib/screens/volume_normalization_settings_screen.dart` |
| Downloads | `lib/screens/downloads_settings_screen.dart` |
| Download locations | `lib/screens/downloads_location_screen.dart` |
| Album settings | `lib/screens/album_settings_screen.dart` |
| Artist settings | `lib/screens/artist_settings_screen.dart` |
| Genre settings | `lib/screens/genre_settings_screen.dart` |
| Player settings | `lib/screens/player_settings_screen.dart` |
| Lyrics settings | `lib/screens/lyrics_settings_screen.dart` |
| Playback reporting | `lib/screens/playback_reporting_settings_screen.dart` |
| Network | `lib/screens/network_settings_screen.dart` |
| Customisation (theme/colour) | `lib/screens/customization_settings_screen.dart` |
| Accessibility | `lib/screens/accessibility_settings_screen.dart` |
| Language | `lib/screens/language_selection_screen.dart` |
| Logs | `lib/screens/logs_screen.dart` |
| Playback history | `lib/screens/playback_history_screen.dart` |
| Queue restore | `lib/screens/queue_restore_screen.dart` |

---

## 9. Theme / design system

| Feature | File |
|---|---|
| Design tokens + component themes (cards, chips, nav, lists) | `lib/theme/jellyamp_theme.dart` |
| Colour schemes (light/dark, dynamic from album art) | `lib/theme/color_schemes.g.dart`, `lib/services/theme_provider.dart` |
| Brand colours | ice `#7DD3FC` · charcoal `#0B0F14` · platinum `#F4F7FA` |
| Seek-bar style (player only) | `lib/components/PlayerScreen/progress_slider.dart` |

Dynamic colour comes from `FinampThemeFromImage` in
`lib/services/theme_provider.dart` (palette extracted from album art).

---

## 10. Update / release plumbing

| Feature | File |
|---|---|
| In-app update check (GitHub releases) | `lib/services/update_checker.dart` |
| Update banner + install (SHA-256 verified) | `lib/components/update_banner.dart` |
| Update installer | `lib/services/update_installer.dart` |
| APK build + release (CI) | `.github/workflows/build-apk.yml` |
| Desktop builds (Linux/Windows) + release upload | `.github/workflows/build.yml` |
| Formatting/codegen gate | `.github/workflows/pr-healthchecks.yml` |

**Release contract:** the updater looks for asset `jellyamp-<version>.apk`
(leading `v` stripped from the tag) and reads the `SHA-256: <hex>` line from the
release **body**. A release missing either is refused at install time.

---

## Keeping this file honest

- Adding/renaming/removing a screen, button, setting, menu item or gesture?
  Update the matching row **in the same PR**.
- If you find a row that no longer matches the code, fix it while you're there.
