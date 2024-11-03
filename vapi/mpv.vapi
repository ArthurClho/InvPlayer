[CCode (cheader_filename = "mpv/render_gl.h")]
namespace MpvOpenGL {
    [CCode (has_target = false)]
    public delegate void *GetProcAddressFunc(void *ctx, string name);
    [CCode (cname = "mpv_opengl_init_params", has_type_id = false)]
    [SimpleType]
    public struct InitParams {
        GetProcAddressFunc get_proc_address;
        void *get_proc_address_ctx;
    }

    [CCode (cname = "mpv_opengl_fbo")]
    [SimpleType]
    public struct Fbo {
        int fbo;
        int w;
        int h;
        int internal_format;
    }
}

[CCode (cheader_filename = "mpv/render.h", cprefix = "mpv_render_")]
namespace MpvRender {
    [CCode (cprefix = "MPV_RENDER_PARAM_")]
    public enum ParamType {
        /**
         * Not a valid value, but also used to terminate a params array. Its value
         * is always guaranteed to be 0 (even if the ABI changes in the future).
         */
        INVALID = 0,
        /**
         * The render API to use. Valid for mpv_render_context_create().
         *
         * Type: char*
         *
         * Defined APIs:
         *
         *   MPV_RENDER_API_TYPE_OPENGL:
         *      OpenGL desktop 2.1 or later (preferably core profile compatible to
         *      OpenGL 3.2), or OpenGLES 2.0 or later.
         *      Providing MPV_RENDER_PARAM_OPENGL_INIT_PARAMS is required.
         *      It is expected that an OpenGL context is valid and "current" when
         *      calling mpv_render_* functions (unless specified otherwise). It
         *      must be the same context for the same mpv_render_context.
         */
        API_TYPE = 1,
        /**
         * Required parameters for initializing the OpenGL renderer. Valid for
         * mpv_render_context_create().
         * Type: mpv_opengl_init_params*
         */
        OPENGL_INIT_PARAMS = 2,
        /**
         * Describes a GL render target. Valid for mpv_render_context_render().
         * Type: mpv_opengl_fbo*
         */
        OPENGL_FBO = 3,
        /**
         * Control flipped rendering. Valid for mpv_render_context_render().
         * Type: int*
         * If the value is set to 0, render normally. Otherwise, render it flipped,
         * which is needed e.g. when rendering to an OpenGL default framebuffer
         * (which has a flipped coordinate system).
         */
        FLIP_Y = 4,
        /**
         * Control surface depth. Valid for mpv_render_context_render().
         * Type: int*
         * This implies the depth of the surface passed to the render function in
         * bits per channel. If omitted or set to 0, the renderer will assume 8.
         * Typically used to control dithering.
         */
        DEPTH = 5,
        /**
         * ICC profile blob. Valid for mpv_render_context_set_parameter().
         * Type: mpv_byte_array*
         * Set an ICC profile for use with the "icc-profile-auto" option. (If the
         * option is not enabled, the ICC data will not be used.)
         */
        ICC_PROFILE = 6,
        /**
         * Ambient light in lux. Valid for mpv_render_context_set_parameter().
         * Type: int*
         * This can be used for automatic gamma correction.
         */
        AMBIENT_LIGHT = 7,
        /**
         * X11 Display, sometimes used for hwdec. Valid for
         * mpv_render_context_create(). The Display must stay valid for the lifetime
         * of the mpv_render_context.
         * Type: Display*
         */
        X11_DISPLAY = 8,
        /**
         * Wayland display, sometimes used for hwdec. Valid for
         * mpv_render_context_create(). The wl_display must stay valid for the
         * lifetime of the mpv_render_context.
         * Type: struct wl_display*
         */
        WL_DISPLAY = 9,
        /**
         * Better control about rendering and enabling some advanced features. Valid
         * for mpv_render_context_create().
         *
         * This conflates multiple requirements the API user promises to abide if
         * this option is enabled:
         *
         *  - The API user's render thread, which is calling the mpv_render_*()
         *    functions, never waits for the core. Otherwise deadlocks can happen.
         *    See "Threading" section.
         *  - The callback set with mpv_render_context_set_update_callback() can now
         *    be called even if there is no new frame. The API user should call the
         *    mpv_render_context_update() function, and interpret the return value
         *    for whether a new frame should be rendered.
         *  - Correct functionality is impossible if the update callback is not set,
         *    or not set soon enough after mpv_render_context_create() (the core can
         *    block while waiting for you to call mpv_render_context_update(), and
         *    if the update callback is not correctly set, it will deadlock, or
         *    block for too long).
         *
         * In general, setting this option will enable the following features (and
         * possibly more):
         *
         *  - "Direct rendering", which means the player decodes directly to a
         *    texture, which saves a copy per video frame ("vd-lavc-dr" option
         *    needs to be enabled, and the rendering backend as well as the
         *    underlying GPU API/driver needs to have support for it).
         *  - Rendering screenshots with the GPU API if supported by the backend
         *    (instead of using a suboptimal software fallback via libswscale).
         *
         * Warning: do not just add this without reading the "Threading" section
         *          above, and then wondering that deadlocks happen. The
         *          requirements are tricky. But also note that even if advanced
         *          control is disabled, not adhering to the rules will lead to
         *          playback problems. Enabling advanced controls simply makes
         *          violating these rules fatal.
         *
         * Type: int*: 0 for disable (default), 1 for enable
         */
        ADVANCED_CONTROL = 10,
        /**
         * Return information about the next frame to render. Valid for
         * mpv_render_context_get_info().
         *
         * Type: mpv_render_frame_info*
         *
         * It strictly returns information about the _next_ frame. The implication
         * is that e.g. mpv_render_context_update()'s return value will have
         * MPV_RENDER_UPDATE_FRAME set, and the user is supposed to call
         * mpv_render_context_render(). If there is no next frame, then the
         * return value will have is_valid set to 0.
         */
        NEXT_FRAME_INFO = 11,
        /**
         * Enable or disable video timing. Valid for mpv_render_context_render().
         *
         * Type: int*: 0 for disable, 1 for enable (default)
         *
         * When video is timed to audio, the player attempts to render video a bit
         * ahead, and then do a blocking wait until the target display time is
         * reached. This blocks mpv_render_context_render() for up to the amount
         * specified with the "video-timing-offset" global option. You can set
         * this parameter to 0 to disable this kind of waiting. If you do, it's
         * recommended to use the target time value in mpv_render_frame_info to
         * wait yourself, or to set the "video-timing-offset" to 0 instead.
         *
         * Disabling this without doing anything in addition will result in A/V sync
         * being slightly off.
         */
        BLOCK_FOR_TARGET_TIME = 12,
        /**
         * Use to skip rendering in mpv_render_context_render().
         *
         * Type: int*: 0 for rendering (default), 1 for skipping
         *
         * If this is set, you don't need to pass a target surface to the render
         * function (and if you do, it's completely ignored). This can still call
         * into the lower level APIs (i.e. if you use OpenGL, the OpenGL context
         * must be set).
         *
         * Be aware that the render API will consider this frame as having been
         * rendered. All other normal rules also apply, for example about whether
         * you have to call mpv_render_context_report_swap(). It also does timing
         * in the same way.
         */
        SKIP_RENDERING = 13,
        /**
         * Deprecated. Not supported. Use MPV_RENDER_PARAM_DRM_DISPLAY_V2 instead.
         * Type : struct mpv_opengl_drm_params*
         */
        DRM_DISPLAY = 14,
        /**
         * DRM draw surface size, contains draw surface dimensions.
         * Valid for mpv_render_context_create().
         * Type : struct mpv_opengl_drm_draw_surface_size*
         */
        DRM_DRAW_SURFACE_SIZE = 15,
        /**
         * DRM display, contains drm display handles.
         * Valid for mpv_render_context_create().
         * Type : struct mpv_opengl_drm_params_v2*
        */
        DRM_DISPLAY_V2 = 16,
        /**
         * MPV_RENDER_API_TYPE_SW only: rendering target surface size, mandatory.
         * Valid for MPV_RENDER_API_TYPE_SW & mpv_render_context_render().
         * Type: int[2] (e.g.: int s[2] = {w, h}; param.data = &s[0];)
         *
         * The video frame is transformed as with other VOs. Typically, this means
         * the video gets scaled and black bars are added if the video size or
         * aspect ratio mismatches with the target size.
         */
        SW_SIZE = 17,
        /**
         * MPV_RENDER_API_TYPE_SW only: rendering target surface pixel format,
         * mandatory.
         * Valid for MPV_RENDER_API_TYPE_SW & mpv_render_context_render().
         * Type: char* (e.g.: char *f = "rgb0"; param.data = f;)
         *
         * Valid values are:
         *  "rgb0", "bgr0", "0bgr", "0rgb"
         *      4 bytes per pixel RGB, 1 byte (8 bit) per component, component bytes
         *      with increasing address from left to right (e.g. "rgb0" has r at
         *      address 0), the "0" component contains uninitialized garbage (often
         *      the value 0, but not necessarily; the bad naming is inherited from
         *      FFmpeg)
         *      Pixel alignment size: 4 bytes
         *  "rgb24"
         *      3 bytes per pixel RGB. This is strongly discouraged because it is
         *      very slow.
         *      Pixel alignment size: 1 bytes
         *  other
         *      The API may accept other pixel formats, using mpv internal format
         *      names, as long as it's internally marked as RGB, has exactly 1
         *      plane, and is supported as conversion output. It is not a good idea
         *      to rely on any of these. Their semantics and handling could change.
         */
        SW_FORMAT = 18,
        /**
         * MPV_RENDER_API_TYPE_SW only: rendering target surface bytes per line,
         * mandatory.
         * Valid for MPV_RENDER_API_TYPE_SW & mpv_render_context_render().
         * Type: size_t*
         *
         * This is the number of bytes between a pixel (x, y) and (x, y + 1) on the
         * target surface. It must be a multiple of the pixel size, and have space
         * for the surface width as specified by MPV_RENDER_PARAM_SW_SIZE.
         *
         * Both stride and pointer value should be a multiple of 64 to facilitate
         * fast SIMD operation. Lower alignment might trigger slower code paths,
         * and in the worst case, will copy the entire target frame. If mpv is built
         * with zimg (and zimg is not disabled), the performance impact might be
         * less.
         * In either cases, the pointer and stride must be aligned at least to the
         * pixel alignment size. Otherwise, crashes and undefined behavior is
         * possible on platforms which do not support unaligned accesses (either
         * through normal memory access or aligned SIMD memory access instructions).
         */
        SW_STRIDE = 19,
        /*
         * MPV_RENDER_API_TYPE_SW only: rendering target surface pixel data pointer,
         * mandatory.
         * Valid for MPV_RENDER_API_TYPE_SW & mpv_render_context_render().
         * Type: void*
         *
         * This points to the first pixel at the left/top corner (0, 0). In
         * particular, each line y starts at (pointer + stride * y). Upon rendering,
         * all data between pointer and (pointer + stride * h) is overwritten.
         * Whether the padding between (w, y) and (0, y + 1) is overwritten is left
         * unspecified (it should not be, but unfortunately some scaler backends
         * will do it anyway). It is assumed that even the padding after the last
         * line (starting at bytepos(w, h) until (pointer + stride * h)) is
         * writable.
         *
         * See MPV_RENDER_PARAM_SW_STRIDE for alignment requirements.
         */
        SW_POINTER = 20,
    }

    [CCode (cname = "mpv_render_param")]
    [SimpleType]
    public struct Param {
        public ParamType type;
        public void *data;
    }

    [CCode (has_target = false)]
    public delegate void UpdateCallbackFunc(void *userdata);

    [CCode (cname = "mpv_render_context", cprefix="mpv_render_context_")]
    [SimpleType]
    public class Context {
        public void set_update_callback(UpdateCallbackFunc callback, void *userdata);

        public int render([CCode (array_length = false)] Param[] params); 
    }

    public int context_create(Context **render_context, Mpv.Context mpv_ctx, [CCode (array_length = false)] Param[] params);
}

[CCode (cheader_filename = "mpv/client.h")]
namespace Mpv {
    public enum Format {
        FLAG = 3,
    }

    [CCode (has_target = false)]
    public delegate void WakeupCallbackFunc(void *user_data);

    [Compact]
    [CCode (cname = "mpv_handle", cprefix = "mpv_", free_function="mpv_destroy")]
    public class Context {
        [CCode (cname = "mpv_create")]
        private Context.create();
        
        public Context() {
            this.create ();
        }

        public int set_option_string(string name, string data);

        public int set_option(string name, Format format, void *data);

        public int set_property(string name, Format format, void *data);

        public int initialize();

        public int command([CCode (array_length = false)] string[] command);

        public unowned Event* wait_event(double timeout);

        public int request_log_messages(string level);

        public void set_wakeup_callback(WakeupCallbackFunc callback, void* userdata);
    }

    [CCode (cprefix = "MPV_EVENT_")]
    public enum EventID {
        /**
         * Nothing happened. Happens on timeouts or sporadic wakeups.
         */
        NONE              = 0,
        /**
         * Happens when the player quits. The player enters a state where it tries
         * to disconnect all clients. Most requests to the player will fail, and
         * the client should react to this and quit with mpv_destroy() as soon as
         * possible.
         */
        SHUTDOWN          = 1,
        /**
         * See mpv_request_log_messages().
         */
        LOG_MESSAGE       = 2,
        /**
         * Reply to a mpv_get_property_async() request.
         * See also mpv_event and mpv_event_property.
         */
        GET_PROPERTY_REPLY = 3,
        /**
         * Reply to a mpv_set_property_async() request.
         * (Unlike MPV_EVENT_GET_PROPERTY, mpv_event_property is not used.)
         */
        SET_PROPERTY_REPLY = 4,
        /**
         * Reply to a mpv_command_async() or mpv_command_node_async() request.
         * See also mpv_event and mpv_event_command.
         */
        COMMAND_REPLY     = 5,
        /**
         * Notification before playback start of a file (before the file is loaded).
         * See also mpv_event and mpv_event_start_file.
         */
        START_FILE        = 6,
        /**
         * Notification after playback end (after the file was unloaded).
         * See also mpv_event and mpv_event_end_file.
         */
        END_FILE          = 7,
        /**
         * Notification when the file has been loaded (headers were read etc.), and
         * decoding starts.
         */
        FILE_LOADED       = 8,
        /**
         * Idle mode was entered. In this mode, no file is played, and the playback
         * core waits for new commands. (The command line player normally quits
         * instead of entering idle mode, unless --idle was specified. If mpv
         * was started with mpv_create(), idle mode is enabled by default.)
         *
         * @deprecated This is equivalent to using mpv_observe_property() on the
         *             "idle-active" property. The event is redundant, and might be
         *             removed in the far future. As a further warning, this event
         *             is not necessarily sent at the right point anymore (at the
         *             start of the program), while the property behaves correctly.
         */
        IDLE              = 11,
        /**
         * Sent every time after a video frame is displayed. Note that currently,
         * this will be sent in lower frequency if there is no video, or playback
         * is paused - but that will be removed in the future, and it will be
         * restricted to video frames only.
         *
         * @deprecated Use mpv_observe_property() with relevant properties instead
         *             (such as "playback-time").
         */
        TICK              = 14,
        /**
         * Triggered by the script-message input command. The command uses the
         * first argument of the command as client name (see mpv_client_name()) to
         * dispatch the message, and passes along all arguments starting from the
         * second argument as strings.
         * See also mpv_event and mpv_event_client_message.
         */
        CLIENT_MESSAGE    = 16,
        /**
         * Happens after video changed in some way. This can happen on resolution
         * changes, pixel format changes, or video filter changes. The event is
         * sent after the video filters and the VO are reconfigured. Applications
         * embedding a mpv window should listen to this event in order to resize
         * the window if needed.
         * Note that this event can happen sporadically, and you should check
         * yourself whether the video parameters really changed before doing
         * something expensive.
         */
        VIDEO_RECONFIG    = 17,
        /**
         * Similar to MPV_EVENT_VIDEO_RECONFIG. This is relatively uninteresting,
         * because there is no such thing as audio output embedding.
         */
        AUDIO_RECONFIG    = 18,
        /**
         * Happens when a seek was initiated. Playback stops. Usually it will
         * resume with MPV_EVENT_PLAYBACK_RESTART as soon as the seek is finished.
         */
        SEEK              = 20,
        /**
         * There was a discontinuity of some sort (like a seek), and playback
         * was reinitialized. Usually happens on start of playback and after
         * seeking. The main purpose is allowing the client to detect when a seek
         * request is finished.
         */
        PLAYBACK_RESTART  = 21,
        /**
         * Event sent due to mpv_observe_property().
         * See also mpv_event and mpv_event_property.
         */
        PROPERTY_CHANGE   = 22,
        /**
         * Happens if the internal per-mpv_handle ringbuffer overflows, and at
         * least 1 event had to be dropped. This can happen if the client doesn't
         * read the event queue quickly enough with mpv_wait_event(), or if the
         * client makes a very large number of asynchronous calls at once.
         *
         * Event delivery will continue normally once this event was returned
         * (this forces the client to empty the queue completely).
         */
        QUEUE_OVERFLOW    = 24,
        /**
         * Triggered if a hook handler was registered with mpv_hook_add(), and the
         * hook is invoked. If you receive this, you must handle it, and continue
         * the hook with mpv_hook_continue().
         * See also mpv_event and mpv_event_hook.
         */
        HOOK              = 25,
    }

    [CCode (cname = "mpv_log_level", cprefix="MPV_LOG_LEVEL_")]
    public enum LogLevel {
        NONE  = 0,    /// "no"    - disable absolutely all messages
        FATAL = 10,   /// "fatal" - critical/aborting errors
        ERROR = 20,   /// "error" - simple errors
        WARN  = 30,   /// "warn"  - possible problems
        INFO  = 40,   /// "info"  - informational message
        V     = 50,   /// "v"     - noisy informational message
        DEBUG = 60,   /// "debug" - very noisy technical information
        TRACE = 70,   /// "trace" - extremely noisy
    }

    [CCode (cname = "mpv_event_log_message")]
    [SimpleType]
    public struct LogMessage {
        unowned string prefix;
        unowned string level;
        unowned string text;
        LogLevel log_level;
    }

    [CCode (cname = "mpv_event")]
    [SimpleType]
    public struct Event {
        EventID event_id;
        int error;
        uint64 reply_userdata;
        void *data;
    }

    public unowned string error_string(int error_code);
}
