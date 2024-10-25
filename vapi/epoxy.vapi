[CCode (cheader_filename = "epoxy/gl.h")]
namespace GL {
    [CCode (cname="GL_FRAMEBUFFER_BINDING")]
    public const int FRAMEBUFFER_BINDING;

    [CCode (cname="glGetIntegerv")]
    void GetIntegerv(int enum, void *data);
}

[CCode (cheader_filename = "epoxy/glx.h")]
namespace GLX {
    [CCode (cname="glXGetProcAddress")]
    public void* get_proc_address(string name);
}

