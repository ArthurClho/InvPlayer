vala_sources = [
  'main.vala',
  'application.vala',
  'video-player.vala',
  'search-page.vala',
  
  # Valac ignores this .vapi, it's here so that meson will trigger a
  # rebuild when it's changed
  '../vapi/mpv.vapi',
]

executable('invplayer', vala_sources,
  gresources_ui,
  dependencies: dependencies
)
