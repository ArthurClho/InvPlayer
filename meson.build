project(
  'InvPlayer', 'vala',
  version: '0.1',
  license: 'GPL3'
)

gnome = import('gnome')

gtk = dependency('gtk+-3.0')
soup = dependency('libsoup-2.4')
json = dependency('json-glib-1.0')
mpv = dependency('mpv')

add_project_arguments(
  ['--vapidir', meson.current_source_dir() + '/vapi'],
  language : 'vala'
)

subdir('ui')
subdir('src')
