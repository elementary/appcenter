/* flatpak.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "Flatpak", gir_namespace = "Flatpak", gir_version = "1.0", lower_case_cprefix = "flatpak_")]
namespace Flatpak {
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_bundle_ref_get_type ()")]
	public class BundleRef : Flatpak.Ref {
		[CCode (has_construct_function = false)]
		public BundleRef (GLib.File file) throws GLib.Error;
		public GLib.Bytes get_appstream ();
		public GLib.File get_file ();
		public GLib.Bytes get_icon (int size);
		public uint64 get_installed_size ();
		public GLib.Bytes get_metadata ();
		public string get_origin ();
		[Version (since = "0.8.0")]
		public string get_runtime_repo_url ();
		public GLib.File file { owned get; construct; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_installation_get_type ()")]
	public class Installation : GLib.Object {
		[CCode (has_construct_function = false)]
		protected Installation ();
		[Version (since = "0.10.0")]
		public bool cleanup_local_refs_sync (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.FileMonitor create_monitor (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool drop_caches (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.Bytes fetch_remote_metadata_sync (string remote_name, Flatpak.Ref @ref, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.RemoteRef fetch_remote_ref_sync (string remote_name, Flatpak.RefKind kind, string name, string? arch, string? branch, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool fetch_remote_size_sync (string remote_name, Flatpak.Ref @ref, out uint64 download_size, out uint64 installed_size, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[CCode (has_construct_function = false)]
		public Installation.for_path (GLib.File path, bool user, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public string get_config (string key, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.InstalledRef get_current_installed_app (string name, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.8")]
		public unowned string get_display_name ();
		[Version (since = "0.8")]
		public unowned string get_id ();
		public Flatpak.InstalledRef get_installed_ref (Flatpak.RefKind kind, string name, string? arch, string? branch, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool get_is_user ();
		public GLib.File get_path ();
		[Version (since = "0.8")]
		public int get_priority ();
		public Flatpak.Remote get_remote_by_name (string name, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.8")]
		public Flatpak.StorageType get_storage_type ();
		public Flatpak.InstalledRef install (string remote_name, Flatpak.RefKind kind, string name, string? arch, string? branch, ProgressCallback cb, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.InstalledRef install_bundle (GLib.File file, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.InstalledRef install_full (Flatpak.InstallFlags flags, string remote_name, Flatpak.RefKind kind, string name, string? arch, string? branch, [CCode (array_length = false, array_null_terminated = true)] string[]? subpaths, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.6.10")]
		public Flatpak.RemoteRef install_ref_file (GLib.Bytes ref_file_data, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool launch (string name, string? arch, string? branch, string? commit, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.InstalledRef> list_installed_refs (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.InstalledRef> list_installed_refs_by_kind (Flatpak.RefKind kind, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.InstalledRef> list_installed_refs_for_update (GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.6.7")]
		public GLib.GenericArray<weak Flatpak.RelatedRef> list_installed_related_refs_sync (string remote_name, string @ref, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.RemoteRef> list_remote_refs_sync (string remote_or_uri, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.6.7")]
		public GLib.GenericArray<weak Flatpak.RelatedRef> list_remote_related_refs_sync (string remote_name, string @ref, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.Remote> list_remotes (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public GLib.GenericArray<weak Flatpak.Remote> list_remotes_by_type ([CCode (array_length_cname = "num_types", array_length_pos = 1.5, array_length_type = "gsize")] Flatpak.RemoteType[] types, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public string load_app_overrides (string app_id, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool modify_remote (Flatpak.Remote remote, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.10.0")]
		public bool prune_local_repo (GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.10.0")]
		public bool remove_local_ref_sync (string remote_name, string @ref, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool remove_remote (string name, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "1.0.3")]
		public bool run_triggers (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool set_config_sync (string key, string value, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[CCode (has_construct_function = false)]
		public Installation.system (GLib.Cancellable? cancellable = null) throws GLib.Error;
		[CCode (has_construct_function = false)]
		[Version (since = "0.8")]
		public Installation.system_with_id (string? id, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool uninstall (Flatpak.RefKind kind, string name, string? arch, string? branch, ProgressCallback cb, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.11.8")]
		public bool uninstall_full (Flatpak.UninstallFlags flags, Flatpak.RefKind kind, string name, string? arch, string? branch, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.InstalledRef update (Flatpak.UpdateFlags flags, Flatpak.RefKind kind, string name, string? arch, string? branch, ProgressCallback cb, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool update_appstream_full_sync (string remote_name, string arch, bool? out_changed, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool update_appstream_sync (string remote_name, string arch, bool? out_changed, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.InstalledRef update_full (Flatpak.UpdateFlags flags, Flatpak.RefKind kind, string name, string? arch, string? branch, [CCode (array_length = false, array_null_terminated = true)] string[]? subpaths, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.6.13")]
		public bool update_remote_sync (string name, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[CCode (has_construct_function = false)]
		public Installation.user (GLib.Cancellable? cancellable = null) throws GLib.Error;
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_installed_ref_get_type ()")]
	public class InstalledRef : Flatpak.Ref {
		[CCode (has_construct_function = false)]
		protected InstalledRef ();
		public unowned string get_deploy_dir ();
		public unowned string get_eol ();
		public unowned string get_eol_rebase ();
		public uint64 get_installed_size ();
		public bool get_is_current ();
		public unowned string get_latest_commit ();
		public unowned string get_origin ();
		[CCode (array_length = false, array_null_terminated = true)]
		public unowned string[] get_subpaths ();
		public GLib.Bytes load_metadata (GLib.Cancellable? cancellable = null) throws GLib.Error;
		[NoAccessorMethod]
		public string deploy_dir { owned get; set; }
		[NoAccessorMethod]
		public string end_of_life { owned get; construct; }
		[NoAccessorMethod]
		public string end_of_life_rebase { owned get; construct; }
		[NoAccessorMethod]
		public uint64 installed_size { get; set; }
		[NoAccessorMethod]
		public bool is_current { get; set; }
		[NoAccessorMethod]
		public string latest_commit { owned get; set; }
		[NoAccessorMethod]
		public string origin { owned get; set; }
		[CCode (array_length = false, array_null_terminated = true)]
		[NoAccessorMethod]
		public string[] subpaths { owned get; set; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_ref_get_type ()")]
	public class Ref : GLib.Object {
		[CCode (has_construct_function = false)]
		protected Ref ();
		public string format_ref ();
		public unowned string get_arch ();
		public unowned string get_branch ();
		public unowned string get_collection_id ();
		public unowned string get_commit ();
		public Flatpak.RefKind get_kind ();
		public unowned string get_name ();
		public static Flatpak.Ref parse (string @ref) throws GLib.Error;
		public string arch { get; construct; }
		public string branch { get; construct; }
		public string collection_id { get; construct; }
		public string commit { get; construct; }
		public Flatpak.RefKind kind { get; construct; }
		public string name { get; construct; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_related_ref_get_type ()")]
	public class RelatedRef : Flatpak.Ref {
		[CCode (has_construct_function = false)]
		protected RelatedRef ();
		[CCode (array_length = false, array_null_terminated = true)]
		[Version (since = "0.6.7")]
		public unowned string[] get_subpaths ();
		[NoAccessorMethod]
		public bool should_autoprune { get; construct; }
		[NoAccessorMethod]
		public bool should_delete { get; construct; }
		[NoAccessorMethod]
		public bool should_download { get; construct; }
		[CCode (array_length = false, array_null_terminated = true)]
		public string[] subpaths { get; construct; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_remote_get_type ()")]
	public class Remote : GLib.Object {
		[CCode (has_construct_function = false)]
		public Remote (string name);
		public GLib.File get_appstream_dir (string? arch);
		public GLib.File get_appstream_timestamp (string? arch);
		public string? get_collection_id ();
		[Version (since = "0.6.12")]
		public string get_default_branch ();
		public bool get_disabled ();
		public bool get_gpg_verify ();
		public unowned string get_name ();
		public bool get_nodeps ();
		public bool get_noenumerate ();
		public int get_prio ();
		[Version (since = "0.9.8")]
		public Flatpak.RemoteType get_remote_type ();
		public string get_title ();
		public string get_url ();
		public void set_collection_id (string? collection_id);
		[Version (since = "0.6.12")]
		public void set_default_branch (string default_branch);
		public void set_disabled (bool disabled);
		public void set_gpg_key (GLib.Bytes gpg_key);
		public void set_gpg_verify (bool gpg_verify);
		public void set_nodeps (bool nodeps);
		public void set_noenumerate (bool noenumerate);
		public void set_prio (int prio);
		public void set_title (string title);
		public void set_url (string url);
		[NoAccessorMethod]
		public string name { owned get; set; }
		[NoAccessorMethod]
		[Version (since = "0.9.8")]
		public Flatpak.RemoteType type { get; construct; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_remote_ref_get_type ()")]
	public class RemoteRef : Flatpak.Ref {
		[CCode (has_construct_function = false)]
		protected RemoteRef ();
		public uint64 get_download_size ();
		public unowned string get_eol ();
		public unowned string get_eol_rebase ();
		public uint64 get_installed_size ();
		public unowned GLib.Bytes? get_metadata ();
		public unowned string get_remote_name ();
		public uint64 download_size { get; construct; }
		[NoAccessorMethod]
		public string end_of_life { owned get; construct; }
		[NoAccessorMethod]
		public string end_of_life_rebase { owned get; construct; }
		public uint64 installed_size { get; construct; }
		public GLib.Bytes metadata { get; construct; }
		public string remote_name { get; construct; }
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_transaction_get_type ()")]
	public class Transaction : GLib.Object, GLib.Initable {
		[CCode (has_construct_function = false)]
		protected Transaction ();
		public void add_default_dependency_sources ();
		public void add_dependency_source (Flatpak.Installation installation);
		public bool add_install (string remote, string @ref, [CCode (array_length = false, array_null_terminated = true)] string[]? subpaths) throws GLib.Error;
		public bool add_install_bundle (GLib.File file, GLib.Bytes? gpg_data) throws GLib.Error;
		public bool add_install_flatpakref (GLib.Bytes flatpakref_data) throws GLib.Error;
		public bool add_uninstall (string @ref) throws GLib.Error;
		public bool add_update (string @ref, [CCode (array_length = false, array_null_terminated = true)] string[]? subpaths, string? commit) throws GLib.Error;
		[CCode (has_construct_function = false)]
		public Transaction.for_installation (Flatpak.Installation installation, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public Flatpak.TransactionOperation get_current_operation ();
		public Flatpak.Installation get_installation ();
		public GLib.List<Flatpak.TransactionOperation> get_operations ();
		public bool is_empty ();
		public bool run (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public void set_default_arch (string arch);
		public void set_disable_dependencies (bool disable_dependencies);
		public void set_disable_prune (bool disable_prune);
		public void set_disable_related (bool disable_related);
		public void set_disable_static_deltas (bool disable_static_deltas);
		public void set_force_uninstall (bool force_uninstall);
		public void set_no_deploy (bool no_deploy);
		public void set_no_pull (bool no_pull);
		public void set_reinstall (bool reinstall);
		public Flatpak.Installation installation { owned get; construct; }
		public virtual signal bool add_new_remote (int reason, string from_id, string remote_name, string url);
		public virtual signal int choose_remote_for_ref (string for_ref, string runtime_ref, [CCode (array_length = false, array_null_terminated = true)] string[] remotes);
		public virtual signal void end_of_lifed (string @ref, string reason, string rebase);
		public virtual signal void new_operation (Flatpak.TransactionOperation operation, Flatpak.TransactionProgress progress);
		public virtual signal void operation_done (Flatpak.TransactionOperation operation, string commit, int details);
		public virtual signal bool operation_error (Flatpak.TransactionOperation operation, GLib.Error error, int detail);
		public virtual signal bool ready ();
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_transaction_operation_get_type ()")]
	public class TransactionOperation : GLib.Object {
		[CCode (has_construct_function = false)]
		protected TransactionOperation ();
		public unowned GLib.File get_bundle_path ();
		public unowned string get_commit ();
		public unowned GLib.KeyFile get_metadata ();
		public unowned GLib.KeyFile get_old_metadata ();
		public Flatpak.TransactionOperationType get_operation_type ();
		public unowned string get_ref ();
		public unowned string get_remote ();
	}
	[CCode (cheader_filename = "flatpak.h", type_id = "flatpak_transaction_progress_get_type ()")]
	public class TransactionProgress : GLib.Object {
		[CCode (has_construct_function = false)]
		protected TransactionProgress ();
		public bool get_is_estimating ();
		public int get_progress ();
		public unowned string get_status ();
		public void set_update_frequency (uint update_frequency);
		public signal void changed ();
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_INSTALL_FLAGS_", type_id = "flatpak_install_flags_get_type ()")]
	[Flags]
	public enum InstallFlags {
		NONE,
		NO_STATIC_DELTAS,
		NO_DEPLOY,
		NO_PULL,
		NO_TRIGGERS
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_REF_KIND_", type_id = "flatpak_ref_kind_get_type ()")]
	public enum RefKind {
		APP,
		RUNTIME
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_REMOTE_TYPE_", type_id = "flatpak_remote_type_get_type ()")]
	public enum RemoteType {
		STATIC,
		USB,
		LAN
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_STORAGE_TYPE_", type_id = "flatpak_storage_type_get_type ()")]
	[Version (since = "0.6.15")]
	public enum StorageType {
		DEFAULT,
		HARD_DISK,
		SDCARD,
		MMC,
		NETWORK
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_TRANSACTION_ERROR_DETAILS_NON_", type_id = "flatpak_transaction_error_details_get_type ()")]
	[Flags]
	public enum TransactionErrorDetails {
		FATAL
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_TRANSACTION_OPERATION_", type_id = "flatpak_transaction_operation_type_get_type ()")]
	public enum TransactionOperationType {
		INSTALL,
		UPDATE,
		INSTALL_BUNDLE,
		UNINSTALL,
		LAST_TYPE;
		public unowned string to_string ();
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_TRANSACTION_REMOTE_", type_id = "flatpak_transaction_remote_reason_get_type ()")]
	public enum TransactionRemoteReason {
		GENERIC_REPO,
		RUNTIME_DEPS
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_TRANSACTION_RESULT_NO_", type_id = "flatpak_transaction_result_get_type ()")]
	[Flags]
	public enum TransactionResult {
		CHANGE
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_UNINSTALL_FLAGS_", type_id = "flatpak_uninstall_flags_get_type ()")]
	[Flags]
	[Version (since = "0.11.8")]
	public enum UninstallFlags {
		NONE,
		NO_PRUNE,
		NO_TRIGGERS
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_UPDATE_FLAGS_", type_id = "flatpak_update_flags_get_type ()")]
	[Flags]
	public enum UpdateFlags {
		NONE,
		NO_DEPLOY,
		NO_PULL,
		NO_STATIC_DELTAS,
		NO_PRUNE,
		NO_TRIGGERS
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_ERROR_")]
	public errordomain Error {
		ALREADY_INSTALLED,
		NOT_INSTALLED,
		ONLY_PULLED,
		DIFFERENT_REMOTE,
		ABORTED,
		SKIPPED,
		NEED_NEW_FLATPAK,
		REMOTE_NOT_FOUND,
		RUNTIME_NOT_FOUND,
		DOWNGRADE,
		INVALID_REF,
		INVALID_DATA,
		UNTRUSTED,
		SETUP_FAILED,
		EXPORT_FAILED,
		REMOTE_USED,
		RUNTIME_USED,
		INVALID_NAME;
		public static GLib.Quark quark ();
	}
	[CCode (cheader_filename = "flatpak.h", cprefix = "FLATPAK_PORTAL_ERROR_")]
	public errordomain PortalError {
		FAILED,
		INVALID_ARGUMENT,
		NOT_FOUND,
		EXISTS,
		NOT_ALLOWED,
		CANCELLED,
		WINDOW_DESTROYED;
		public static GLib.Quark quark ();
	}
	[CCode (cheader_filename = "flatpak.h", instance_pos = 3.9)]
	public delegate void ProgressCallback (string status, uint progress, bool estimating);
	[CCode (cheader_filename = "flatpak.h", cname = "FLATPAK_MAJOR_VERSION")]
	public const int MAJOR_VERSION;
	[CCode (cheader_filename = "flatpak.h", cname = "FLATPAK_MICRO_VERSION")]
	public const int MICRO_VERSION;
	[CCode (cheader_filename = "flatpak.h", cname = "FLATPAK_MINOR_VERSION")]
	public const int MINOR_VERSION;
	[CCode (cheader_filename = "flatpak.h")]
	public static unowned string get_default_arch ();
	[CCode (array_length = false, array_null_terminated = true, cheader_filename = "flatpak.h")]
	public static unowned string[] get_supported_arches ();
	[CCode (cheader_filename = "flatpak.h")]
	[Version (since = "0.8")]
	public static GLib.GenericArray<weak Flatpak.Installation> get_system_installations (GLib.Cancellable? cancellable = null) throws GLib.Error;
}

