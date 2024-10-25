project(
  'InvPlayer', 'vala',
  version: '0.1',
  license: 'GPL3'
)

gnome = import('gnome')

dependencies = [
  dependency('gtk+-3.0'),
  dependency('libsoup-2.4'),
  dependency('json-glib-1.0'),
  dependency('mpv'),
  dependency('epoxy')
]

add_project_arguments(
  ['--vapidir', meson.current_source_dir() + '/vapi'],
  language : 'vala'
)

subdir('ui')
subdir('src')
