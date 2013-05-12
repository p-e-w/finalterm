
[CCode (cprefix = "KEYBINDER", lower_case_cprefix = "keybinder_",
        cheader_filename="keybinder.h")]
namespace Keybinder {
	[CCode (has_target=false)]
	public delegate void Handler (string keystring, void *udata);

	public void init();
	public bool bind (string keystring, Handler hander, void *udata);
	public void unbind (string keystring, Handler handler);
	public uint32 get_current_event_time ();
}
