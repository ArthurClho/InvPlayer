[GtkTemplate ( ui = "/net/arthurclho/invplayer/ui/application-window.ui" )]
public class ApplicationWindow : Gtk.ApplicationWindow {
    [GtkChild]
    private unowned VideoPlayer video_player;
    [GtkChild]
    private unowned SearchPage search_page;
    [GtkChild]
    private unowned Gtk.Stack the_stack;

    public ApplicationWindow ( Gtk.Application app ) {
        Object ( application: app );

        var screen = Gdk.Screen.get_default();
        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource("/net/arthurclho/invplayer/ui/video-controls.css");

        Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        search_page.video_chosen.connect((id) => {
            the_stack.set_visible_child (video_player);
            video_player.play("https://youtube.com/watch?v=" + id);
        });

        video_player.init();
    }
}

public class Application : Gtk.Application {
    private Gtk.ApplicationWindow window;

    public Application () {
        Object (application_id: "com.example.GtkApplication", flags: GLib.ApplicationFlags.DEFAULT_FLAGS);
    }

    protected override void activate () {
        window = new ApplicationWindow (this);
        window.show_all ();
    }
}

