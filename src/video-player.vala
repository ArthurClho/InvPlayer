[GtkTemplate ( ui = "/net/arthurclho/invplayer/ui/video-controls.ui" )]
public class VideoControls : Gtk.Grid {
    [GtkChild]
    private unowned Gtk.Scale slider;
    [GtkChild]
    private unowned Gtk.Button play_pause_button;
    [GtkChild]
    private unowned Gtk.Label duration_label;
    [GtkChild]
    private unowned Gtk.Label time_played_label;

    public signal void play_pause_pressed(bool pause);

    private bool _playing = false;
    public bool playing {
        get { return _playing; }
        set {
            _playing = value;
            update_play_button();
        }
    }

    private double _duration;
    public double duration {
        get { return _duration; }
        set {
            _duration = value;
            update_times();
        }
    }

    private double _time_pos;
    public double time_pos {
        get { return _time_pos; }
        set {
            _time_pos = value;
            update_times();
        }
    }

    public VideoControls() {
        halign = Gtk.Align.FILL;
        valign = Gtk.Align.END;

        duration = 0.0;
        time_pos = 0.0;

        slider.set_range(0.0, 1.0);
        // Leave it disabled until I implement seeking
        slider.sensitive = false;

        update_play_button();
    }

    static void set_label_time(Gtk.Label label, GLib.DateTime datetime) {
        string duration_string;
        if (datetime.to_unix() >= 60 * 60) {
            duration_string = datetime.format("%T");
        } else {
            duration_string = datetime.format("%M:%S");
        }
    
        label.set_text(duration_string);
    }

    void update_times() {
        set_label_time(duration_label, new GLib.DateTime.from_unix_utc((int64) Math.floor(_duration)));
        set_label_time(time_played_label, new GLib.DateTime.from_unix_utc((int64) Math.floor(_time_pos)));

        slider.set_value(_time_pos / _duration);
    }

    void update_play_button() {
        string icon_name;
        if (_playing) {
            icon_name = "media-playback-pause-symbolic";
        } else {
            icon_name = "media-playback-start-symbolic";
        }

        var img = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.BUTTON);
        play_pause_button.set_image (img);
    }

    [GtkCallback]
    void play_pause_button_clicked() {
        play_pause_pressed(_playing);
    }
}

[GtkTemplate ( ui = "/net/arthurclho/invplayer/ui/video-player.ui" )]
public class VideoPlayer : Gtk.Overlay {
    private Gtk.GLArea gl_area;
    private VideoControls video_controls;

    private Mpv.Context? mpv_ctx = null;
    private MpvRender.Context *render_context;

    private int gl_width;
    private int gl_height;

    static void *get_proc_address(void *ctx, string name) {
        // TODO: Check if wayland
        return GLX.get_proc_address(name);
    }

    static void wakeup_callback(void *userdata) {
        var self = (VideoPlayer *) userdata;

        GLib.Idle.add_full(GLib.Priority.HIGH_IDLE, () => {
            self->handle_mpv_events();
            return false;
        });
    }

    static void update_callback(void *userdata) {
        var self = (VideoPlayer*) userdata;
        self->frame_ready();
    }

    signal void frame_ready();

    void handle_mpv_property_change(Mpv.PropertyEvent *event) {
        if (event.format == Mpv.Format.NONE) {
            print ("handle_mpv_event ERROR: format is NONE\n");
            return;
        }
    
        switch (event.name) {
            case "pause":
                var paused = *((bool*) event.data);
                video_controls.playing = !paused;
                break;
            case "duration":
                var duration = (double*) event.data;
                video_controls.duration = *duration;
                break;
            default:
                print ("Unhandled mpv property change: '%s'\n", event.name);
                break;
        }
    }

    void handle_mpv_events() {
        while (true) {
            var event = mpv_ctx.wait_event(0.0);

            if (event.event_id == Mpv.EventID.NONE) {
                break;
            }

            switch (event.event_id) {
                case Mpv.EventID.LOG_MESSAGE:
                    var msg = (Mpv.LogMessage *) event.data;
                    print ("%s [%s] %s", msg.prefix, msg.level, msg.text);
                    break;
                case Mpv.EventID.PROPERTY_CHANGE:
                    handle_mpv_property_change((Mpv.PropertyEvent*) event.data);
                    break;
                case Mpv.EventID.IDLE:
                    /* ignored */
                    break;
                default:
                    print ("Unhandled mpv event: %d\n", event.event_id);
                    break;
            }
        }
    }

    public void init() {
        /*
         * We create this here instead of having it in the .ui file because,
         * for some reason I haven't been able to debug yet, it doesn't work
         * when it's done like that
        */
        gl_area = new Gtk.GLArea ();
        add(gl_area);
        gl_area.show();

        video_controls = new VideoControls();
        video_controls.get_style_context().add_class("videocontrols");
        video_controls.show();
        add_overlay(video_controls);

        video_controls.play_pause_pressed.connect((paused) => {
            mpv_ctx.set_property("pause", Mpv.Format.FLAG, &paused);
        });

        GLib.Intl.setlocale (GLib.LocaleCategory.NUMERIC, "C");

        mpv_ctx = new Mpv.Context();

        if (mpv_ctx.set_option_string("vo", "libmpv") != 0) {
            print ("Error setting mpv vo");
        }

        mpv_ctx.set_option_string("terminal", "yes");

        // TODO should not be hardcoded
        mpv_ctx.set_option_string("ytdl-format", "best[height<=720]");

        var log_request = GLib.Environment.get_variable("INVPLAYER_MPV_DEBUG");
        if (log_request != null) {
            mpv_ctx.request_log_messages(log_request);
        }

        if (mpv_ctx.initialize() < 0) {
            print ("Error initializing mpv\n");
        }

        frame_ready.connect(() => {
            gl_area.queue_render();
        });

        gl_area.render.connect(() => {
            if (render_context != null) {
                int fbo = -1;
                GL.GetIntegerv(GL.FRAMEBUFFER_BINDING, &fbo);

                int t = 1;
                MpvOpenGL.Fbo mpv_fbo = { fbo, gl_width, gl_height, 0 };
                MpvRender.Param[] params = {
                    { MpvRender.ParamType.OPENGL_FBO, &mpv_fbo },
                    { MpvRender.ParamType.FLIP_Y, &t }
                };

                render_context->render(params);
            }
            
            return true;
        });

        gl_area.resize.connect((width, height) => {
            gl_width = width;
            gl_height = height;
        });

        gl_area.realize ();
        gl_area.make_current ();
    
        MpvOpenGL.InitParams opengl_params = {
            get_proc_address, null
        };
        MpvRender.Param[] params = {
            { MpvRender.ParamType.API_TYPE, "opengl" },
            { MpvRender.ParamType.OPENGL_INIT_PARAMS, &opengl_params },
        };

        if (MpvRender.context_create(&render_context, mpv_ctx, params) < 0) {
            print ("Error creating render context\n");
        }

        mpv_ctx.set_wakeup_callback(wakeup_callback, this);
        render_context->set_update_callback(update_callback, this);

        mpv_ctx.observe_property (0, "pause", Mpv.Format.FLAG);
        mpv_ctx.observe_property (0, "duration", Mpv.Format.DOUBLE);

        GLib.Timeout.add_seconds(1, () => {
            double time = 0.0;
            if (mpv_ctx.get_property("time-pos", Mpv.Format.DOUBLE, &time) == 0) {
                video_controls.time_pos = time;
            }

            return true;
        });
    }

    public void play(string name) {
        string[] cmd = { "loadfile", name };
        mpv_ctx.command(cmd);
    }
}
