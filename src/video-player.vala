[GtkTemplate ( ui = "/net/arthurclho/invplayer/ui/video-controls.ui" )]
public class VideoControls : Gtk.Grid {
    [GtkChild]
    private unowned Gtk.Scale slider;

    public VideoControls() {
        halign = Gtk.Align.FILL;
        valign = Gtk.Align.END;

        slider.set_range(0.0, 1.0);
    }
}

[GtkTemplate ( ui = "/net/arthurclho/invplayer/ui/video-player.ui" )]
public class VideoPlayer : Gtk.Overlay {
    private Gtk.GLArea gl_area;

    private Mpv.Context? mpv_ctx = null;
    private MpvRender.Context *render_context;

    private int gl_width;
    private int gl_height;

    static void *get_proc_address(void *ctx, string name) {
        // TODO: Check if wayland
        return GLX.get_proc_address(name);
    }

    static void wakeup_callback(void *userdata) {
        print ("wakeup\n");
    }

    static void update_callback(void *userdata) {
        var self = (VideoPlayer*) userdata;
        self->frame_ready();
    }

    public signal void frame_ready();

    public void init() {
    
        /*
         * We create this here instead of having it in the .ui file because,
         * for some reason I haven't been able to debug yet, it doesn't work
         * when it's done like that
        */
        gl_area = new Gtk.GLArea ();
        add(gl_area);
        gl_area.show();

        var controls = new VideoControls();
        controls.get_style_context().add_class("videocontrols");
        controls.show();
        add_overlay(controls);

        GLib.Intl.setlocale (GLib.LocaleCategory.NUMERIC, "C");

        mpv_ctx = new Mpv.Context();

        if (mpv_ctx.set_option_string("vo", "libmpv") != 0) {
            print ("Error setting mpv vo");
        }

        mpv_ctx.set_option_string("terminal", "yes");

        mpv_ctx.request_log_messages("debug");
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

        mpv_ctx.set_wakeup_callback(wakeup_callback, null);
        render_context->set_update_callback(update_callback, this);
    }

    public void play(string name) {
        string[] cmd = { "loadfile", name };
        mpv_ctx.command(cmd);
    }
}
