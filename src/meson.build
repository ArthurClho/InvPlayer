vala_sources = [
  'main.vala',
  'application.vala',
  'video-player.vala',
  
  # Valac ignores this .vapi, it's here so that meson will trigger a
  # rebuild when it's changed
  '../vapi/mpv.vapi',
]

dependencies = [
  gtk,
  soup,
  json,
  mpv
]

executable('invplayer', vala_sources,
  gresources_ui,
  dependencies: dependencies,
  vala_args: ['--vapidir', meson.current_source_dir()],
  link_args: ['-lepoxy']
)
