use std::path::PathBuf;

#[path = "lease.rs"]
pub mod lease;

use lease::{AppIdentity, RunToken};

// allow: SIZE_OK - the approved plan requires one isolated Win32 lifecycle/FFI boundary.

const LIFECYCLE_SECURITY_SDDL: &str = "O:SYD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ChildIdentity {
    pub pid: u32,
    pub creation_time_100ns: u64,
    pub canonical_path: PathBuf,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LeasedProcessIdentityAction {
    ReconcileExact,
    RemoveStaleLease,
}

const fn leased_process_identity_action(identity_matches: bool) -> LeasedProcessIdentityAction {
    if identity_matches {
        LeasedProcessIdentityAction::ReconcileExact
    } else {
        LeasedProcessIdentityAction::RemoveStaleLease
    }
}

fn child_termination_event(reason: &str, pid: u32, creation_time_100ns: u64) -> String {
    format!("[lifecycle] child-decision reason={reason} pid={pid} creation={creation_time_100ns}")
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LifecycleState {
    Running,
    StopPending,
    Stopped,
}

#[derive(Debug)]
pub struct LifecycleOwner {
    state: LifecycleState,
    child_identity: Option<ChildIdentity>,
    retained_app: Option<AppIdentity>,
    run_token: Option<RunToken>,
    #[cfg(target_os = "windows")]
    child: Option<windows_process::ContainedProcess>,
}

impl LifecycleOwner {
    pub const fn stopped() -> Self {
        Self {
            state: LifecycleState::Stopped,
            child_identity: None,
            retained_app: None,
            run_token: None,
            #[cfg(target_os = "windows")]
            child: None,
        }
    }

    #[cfg(test)]
    fn running(child_identity: ChildIdentity) -> Self {
        Self {
            state: LifecycleState::Running,
            child_identity: Some(child_identity),
            retained_app: None,
            run_token: None,
            #[cfg(target_os = "windows")]
            child: None,
        }
    }

    pub fn child_identity(&self) -> Option<&ChildIdentity> {
        self.child_identity.as_ref()
    }

    pub fn retained_app(&self) -> Option<&AppIdentity> {
        self.retained_app.as_ref()
    }

    pub fn run_token(&self) -> Option<&RunToken> {
        self.run_token.as_ref()
    }

    fn request_stop(&mut self) {
        self.state = match self.state {
            LifecycleState::Running | LifecycleState::StopPending => LifecycleState::StopPending,
            LifecycleState::Stopped => LifecycleState::Stopped,
        };
    }

    fn observe_exit(&mut self) {
        self.state = LifecycleState::Stopped;
        self.child_identity = None;
        self.retained_app = None;
        self.run_token = None;
        #[cfg(target_os = "windows")]
        {
            self.child = None;
        }
    }
}

impl Default for LifecycleOwner {
    fn default() -> Self {
        Self::stopped()
    }
}

#[cfg(target_os = "windows")]
pub use windows_process::{start_transaction, stop_for_service, stop_transaction, LifecycleError};

#[cfg(target_os = "windows")]
mod windows_process {
    use super::lease::{
        AppIdentity, BridgeState, Candidate, CandidateDecision, CoreIdentity, LeaseRecord,
        RunToken, StartCoreRequest, StartCoreResponse, StopCoreRequest,
    };
    use super::{
        leased_process_identity_action, ChildIdentity, LeasedProcessIdentityAction, LifecycleOwner,
        LifecycleState,
    };
    use sha2::{Digest, Sha256};
    use std::ffi::{c_void, OsStr, OsString};
    use std::fs::{self, File, OpenOptions};
    use std::io::{Read, Write};
    use std::mem::size_of;
    use std::os::windows::ffi::{OsStrExt, OsStringExt};
    use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
    use std::path::{Path, PathBuf};
    use std::ptr;
    use std::time::Duration;
    use thiserror::Error;
    use windows::core::{PCWSTR, PWSTR};
    use windows::Win32::Foundation::{
        GetLastError, LocalFree, SetHandleInformation, SetLastError, BOOL, ERROR_ALREADY_EXISTS,
        ERROR_INSUFFICIENT_BUFFER, ERROR_NO_MORE_FILES, HANDLE, HANDLE_FLAGS, HANDLE_FLAG_INHERIT,
        HLOCAL, WAIT_ABANDONED, WAIT_FAILED, WAIT_OBJECT_0, WAIT_TIMEOUT,
    };
    use windows::Win32::NetworkManagement::IpHelper::{
        GetExtendedTcpTable, TCP_TABLE_OWNER_PID_ALL, TCP_TABLE_OWNER_PID_LISTENER,
    };
    use windows::Win32::Networking::WinSock::AF_INET;
    use windows::Win32::Security::Authorization::{
        ConvertStringSecurityDescriptorToSecurityDescriptorW, GetNamedSecurityInfoW,
        GetSecurityInfo, SetNamedSecurityInfoW, SE_FILE_OBJECT, SE_KERNEL_OBJECT,
    };
    use windows::Win32::Security::{
        CreateWellKnownSid, EqualSid, GetSecurityDescriptorDacl, GetSecurityDescriptorOwner,
        WinLocalSystemSid, ACL, DACL_SECURITY_INFORMATION, OWNER_SECURITY_INFORMATION,
        PROTECTED_DACL_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, PSID, SECURITY_ATTRIBUTES,
        SECURITY_MAX_SID_SIZE,
    };
    use windows::Win32::Storage::FileSystem::{
        CreateFileW, GetFileAttributesW, GetFinalPathNameByHandleW, MoveFileExW,
        FILE_ATTRIBUTE_NORMAL, FILE_ATTRIBUTE_REPARSE_POINT, FILE_NAME_NORMALIZED,
        FILE_READ_ATTRIBUTES, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE,
        GETFINALPATHNAMEBYHANDLE_FLAGS, MOVEFILE_REPLACE_EXISTING, MOVEFILE_WRITE_THROUGH,
        OPEN_EXISTING, VOLUME_NAME_DOS,
    };
    use windows::Win32::System::Diagnostics::ToolHelp::{
        CreateToolhelp32Snapshot, Process32FirstW, Process32NextW, PROCESSENTRY32W,
        TH32CS_SNAPPROCESS,
    };
    use windows::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
        SetInformationJobObject, TerminateJobObject, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    };
    use windows::Win32::System::Pipes::CreatePipe;
    use windows::Win32::System::RemoteDesktop::ProcessIdToSessionId;
    use windows::Win32::System::Threading::{
        CreateMutexW, CreateProcessW, GetProcessTimes, OpenProcess, QueryFullProcessImageNameW,
        ReleaseMutex, ResumeThread, TerminateProcess, WaitForSingleObject, CREATE_NO_WINDOW,
        CREATE_SUSPENDED, CREATE_UNICODE_ENVIRONMENT, INFINITE, PROCESS_ACCESS_RIGHTS,
        PROCESS_INFORMATION, PROCESS_NAME_WIN32, PROCESS_QUERY_LIMITED_INFORMATION,
        PROCESS_TERMINATE, STARTF_USESTDHANDLES, STARTUPINFOW,
    };

    const WINDOWS_PATH_BUFFER_LEN: usize = 32_768;
    const RESUME_THREAD_FAILED: u32 = u32::MAX;
    const SYNCHRONIZE_PROCESS: PROCESS_ACCESS_RIGHTS = PROCESS_ACCESS_RIGHTS(0x0010_0000);
    const MIB_TCP_STATE_LISTEN: u32 = 2;
    const MIB_TCP_STATE_ESTABLISHED: u32 = 5;
    const TCP_ROW_SIZE: usize = 24;

    #[derive(Clone, Copy, Debug)]
    pub struct SpawnRequest<'a> {
        pub path: &'a Path,
        pub bridge_port: u16,
        pub home_dir: Option<&'a OsStr>,
        pub run_token: &'a RunToken,
        pub app_identity: &'a AppIdentity,
    }

    #[derive(Debug, Error)]
    pub enum LifecycleError {
        #[error("{operation} failed: {source}")]
        Windows {
            operation: &'static str,
            #[source]
            source: windows::core::Error,
        },
        #[error("invalid process input: {0}")]
        InvalidInput(&'static str),
        #[error("process wait returned unexpected status {0:#x}")]
        UnexpectedWait(u32),
        #[error("stop budget exceeds Win32 millisecond range")]
        StopBudgetOverflow,
        #[error("lifecycle conflict: activeInAnotherSession")]
        ActiveInAnotherSession,
        #[error("lifecycle identity mismatch: {0}")]
        IdentityMismatch(&'static str),
        #[error("lease is unreadable or malformed")]
        UnknownLease,
        #[error("{operation} failed: {source}")]
        Io {
            operation: &'static str,
            #[source]
            source: std::io::Error,
        },
        #[error("lease serialization failed: {0}")]
        Json(#[from] serde_json::Error),
    }

    #[derive(Debug)]
    pub(super) struct ContainedProcess {
        process: OwnedHandle,
        job: OwnedHandle,
    }

    impl LifecycleOwner {
        pub fn spawn(&mut self, request: SpawnRequest<'_>) -> Result<File, LifecycleError> {
            if self.state != LifecycleState::Stopped {
                return Err(LifecycleError::InvalidInput(
                    "existing child must be stopped before spawn",
                ));
            }

            let (contained, identity, stderr) = spawn_contained(request)?;
            self.child = Some(contained);
            self.child_identity = Some(identity);
            self.retained_app = Some(request.app_identity.clone());
            self.run_token = Some(request.run_token.clone());
            self.state = LifecycleState::Running;
            Ok(stderr)
        }

        pub fn stop_and_wait(&mut self, budget: Duration) -> Result<(), LifecycleError> {
            if self.child.is_none() {
                self.observe_exit();
                return Ok(());
            }

            self.request_stop();
            let child = match self.child.as_ref() {
                Some(child) => child,
                None => {
                    return Err(LifecycleError::InvalidInput(
                        "missing retained child handles",
                    ))
                }
            };

            if wait_for_process(child, 0)? != WaitOutcome::Exited {
                if let Err(_process_error) = terminate_process(child) {
                    if wait_for_process(child, 0)? != WaitOutcome::Exited {
                        terminate_job(child)?;
                        wait_for_process_mandatory(child)?;
                    }
                } else {
                    let timeout_ms = u32::try_from(budget.as_millis())
                        .map_err(|_| LifecycleError::StopBudgetOverflow)?;
                    if wait_for_process(child, timeout_ms)? == WaitOutcome::TimedOut {
                        terminate_job(child)?;
                        wait_for_process_mandatory(child)?;
                    }
                }
            }

            self.observe_exit();
            Ok(())
        }
    }

    pub fn start_transaction(
        owner: &mut LifecycleOwner,
        request: &StartCoreRequest,
        budget: Duration,
        log: &mut dyn FnMut(String),
    ) -> Result<(File, StartCoreResponse), LifecycleError> {
        let scope = InstallScope::current()?;
        let _guard = scope.acquire()?;
        let requested_path = canonicalize_path(Path::new(&request.path))?;
        if !path_eq(&requested_path, &scope.core_path) {
            return Err(LifecycleError::IdentityMismatch(
                "requested core path is outside this install",
            ));
        }
        let app_identity = validate_app_identity(&request.app_identity())?;

        if let Some(retained_app) = owner.retained_app() {
            if retained_app != &app_identity {
                return Err(LifecycleError::ActiveInAnotherSession);
            }
            if let Some(identity) = owner.child_identity() {
                log(super::child_termination_event(
                    "start-replace",
                    identity.pid,
                    identity.creation_time_100ns,
                ));
            }
            owner.stop_and_wait(budget)?;
            remove_lease_if_present(&scope.lease_path)?;
        }

        reconcile_lease_and_candidates(&scope, &app_identity, budget, log)?;
        let stderr = owner.spawn(SpawnRequest {
            path: &scope.core_path,
            bridge_port: request.bridge_port,
            home_dir: request.home_dir.as_deref().map(OsStr::new),
            run_token: &request.run_token,
            app_identity: &app_identity,
        })?;
        let child = owner
            .child_identity()
            .cloned()
            .ok_or(LifecycleError::IdentityMismatch(
                "spawn completed without retained child identity",
            ))?;
        let lease = LeaseRecord {
            app: app_identity,
            core: CoreIdentity {
                pid: child.pid,
                creation_time_100ns: child.creation_time_100ns,
                canonical_path: child.canonical_path,
                run_token: request.run_token.clone(),
            },
        };
        log(format!(
            "[lifecycle] spawn-success pid={} creation={} bridgePort={}",
            lease.core.pid, lease.core.creation_time_100ns, request.bridge_port
        ));
        if let Err(error) = write_lease_atomic(&scope.lease_path, &lease) {
            log(format!(
                "{} error={error}",
                super::child_termination_event(
                    "lease-write-failed",
                    lease.core.pid,
                    lease.core.creation_time_100ns,
                )
            ));
            let _cleanup_result = owner.stop_and_wait(budget);
            return Err(error);
        }
        Ok((
            stderr,
            StartCoreResponse {
                core_pid: lease.core.pid,
                core_creation_time_100ns: lease.core.creation_time_100ns,
                run_token: lease.core.run_token,
            },
        ))
    }

    pub fn stop_transaction(
        owner: &mut LifecycleOwner,
        request: &StopCoreRequest,
        budget: Duration,
        log: &mut dyn FnMut(String),
    ) -> Result<(), LifecycleError> {
        let scope = InstallScope::current()?;
        let _guard = scope.acquire()?;
        let identity = owner
            .child_identity()
            .cloned()
            .ok_or(LifecycleError::IdentityMismatch("retained child is absent"))?;
        let retained_token = owner
            .run_token()
            .cloned()
            .ok_or(LifecycleError::IdentityMismatch(
                "retained run token is absent",
            ))?;
        let observed = query_process_identity(identity.pid, PROCESS_QUERY_LIMITED_INFORMATION)?;
        if request.core_pid != observed.pid
            || request.core_creation_time_100ns != observed.creation_time_100ns
        {
            return Err(LifecycleError::IdentityMismatch(
                "stop request process identity changed",
            ));
        }
        let decision = super::lease::evaluate_candidate(&Candidate::Retained {
            expected: CoreIdentity {
                pid: identity.pid,
                creation_time_100ns: identity.creation_time_100ns,
                canonical_path: identity.canonical_path,
                run_token: retained_token,
            },
            observed: CoreIdentity {
                pid: observed.pid,
                creation_time_100ns: observed.creation_time_100ns,
                canonical_path: observed.canonical_path,
                run_token: request.run_token.clone(),
            },
        });
        if decision != CandidateDecision::Terminate {
            return Err(LifecycleError::IdentityMismatch(
                "stop request does not match retained child",
            ));
        }
        log(super::child_termination_event(
            "stop-request",
            identity.pid,
            identity.creation_time_100ns,
        ));
        owner.stop_and_wait(budget)?;
        remove_lease_if_present(&scope.lease_path)
    }

    pub fn stop_for_service(
        owner: &mut LifecycleOwner,
        budget: Duration,
        log: &mut dyn FnMut(String),
    ) -> Result<(), LifecycleError> {
        let scope = InstallScope::current()?;
        let _guard = scope.acquire()?;
        let retained_identity = owner.child_identity().cloned();
        if let Some(identity) = retained_identity.as_ref() {
            log(super::child_termination_event(
                "scm-stop",
                identity.pid,
                identity.creation_time_100ns,
            ));
        }
        owner.stop_and_wait(budget)?;
        if retained_identity.is_some() {
            remove_lease_if_present(&scope.lease_path)?;
        }
        Ok(())
    }

    struct InstallScope {
        core_path: PathBuf,
        lease_path: PathBuf,
        mutex_name: Vec<u16>,
    }

    impl InstallScope {
        fn current() -> Result<Self, LifecycleError> {
            let helper = std::env::current_exe().map_err(|source| LifecycleError::Io {
                operation: "current_exe",
                source,
            })?;
            let helper = canonicalize_path(&helper)?;
            let helper_dir = helper.parent().ok_or(LifecycleError::InvalidInput(
                "helper executable has no parent directory",
            ))?;
            let canonical_dir = normalize_path(helper_dir);
            let install_digest = Sha256::digest(canonical_dir.to_lowercase().as_bytes());
            let install_id = install_digest[..16]
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>();
            let program_data = std::env::var_os("ProgramData")
                .ok_or(LifecycleError::InvalidInput("ProgramData is unavailable"))?;
            let lease_dir = PathBuf::from(program_data)
                .join("dropweb")
                .join("lifecycle");
            ensure_restricted_directory(&lease_dir)?;
            let mutex_name = wide_nul(OsStr::new(&format!(
                r"Global\DropwebCoreLifecycle-{install_id}"
            )))?;
            Ok(Self {
                core_path: canonicalize_path(&helper_dir.join("DropwebCore.exe"))?,
                lease_path: lease_dir.join(format!("{install_id}.json")),
                mutex_name,
            })
        }

        fn acquire(&self) -> Result<LifecycleMutexGuard, LifecycleError> {
            let descriptor = restricted_security_descriptor()?;
            let attributes = SECURITY_ATTRIBUTES {
                nLength: u32::try_from(size_of::<SECURITY_ATTRIBUTES>()).map_err(|_| {
                    LifecycleError::InvalidInput("SECURITY_ATTRIBUTES size overflow")
                })?,
                lpSecurityDescriptor: descriptor.0 .0,
                bInheritHandle: false.into(),
            };
            // SAFETY: Category 8 (FFI boundary). The name is NUL-terminated and
            // attributes references a live SYSTEM/Administrators-only descriptor.
            unsafe { SetLastError(windows::Win32::Foundation::WIN32_ERROR(0)) };
            // SAFETY: Category 8 (FFI boundary). Both the name and security
            // attributes remain live and valid for the complete call.
            let handle = unsafe {
                CreateMutexW(
                    Some(ptr::from_ref(&attributes)),
                    false,
                    PCWSTR(self.mutex_name.as_ptr()),
                )
            }
            .map_err(|source| LifecycleError::Windows {
                operation: "CreateMutexW",
                source,
            })?;
            // SAFETY: Category 8 (FFI boundary). This reads last-error
            // immediately after successful CreateMutexW as required by Win32.
            let already_exists = unsafe { GetLastError() } == ERROR_ALREADY_EXISTS;
            let handle = own_handle(handle);
            if already_exists {
                ensure_system_owned_handle(&handle)?;
            }
            // SAFETY: Category 8 (FFI boundary). The owned mutex handle remains
            // valid until the returned guard releases and closes it.
            let status = unsafe { WaitForSingleObject(raw_handle(&handle), INFINITE) };
            match status {
                WAIT_OBJECT_0 | WAIT_ABANDONED => Ok(LifecycleMutexGuard { handle }),
                WAIT_FAILED => Err(last_windows_error("WaitForSingleObject(mutex)")),
                other => Err(LifecycleError::UnexpectedWait(other.0)),
            }
        }
    }

    struct LifecycleMutexGuard {
        handle: OwnedHandle,
    }

    impl Drop for LifecycleMutexGuard {
        fn drop(&mut self) {
            // SAFETY: Category 8 (FFI boundary). This guard is constructed only
            // after the current thread acquired this exact mutex handle.
            let _release_result = unsafe { ReleaseMutex(raw_handle(&self.handle)) };
        }
    }

    fn validate_app_identity(claimed: &AppIdentity) -> Result<AppIdentity, LifecycleError> {
        let process = open_process(claimed.pid, PROCESS_QUERY_LIMITED_INFORMATION)?;
        let observed = query_identity_from_handle(&process, claimed.pid)?;
        let mut session_id = 0_u32;
        // SAFETY: Category 8 (FFI boundary). session_id is a valid writable u32
        // and claimed.pid was supplied as an unsigned process identifier.
        unsafe { ProcessIdToSessionId(claimed.pid, &mut session_id) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "ProcessIdToSessionId",
                source,
            }
        })?;
        if observed.creation_time_100ns != claimed.creation_time_100ns
            || session_id != claimed.session_id
        {
            return Err(LifecycleError::IdentityMismatch(
                "app PID, creation time, or session changed",
            ));
        }
        Ok(claimed.clone())
    }

    fn reconcile_lease_and_candidates(
        scope: &InstallScope,
        requesting_app: &AppIdentity,
        budget: Duration,
        log: &mut dyn FnMut(String),
    ) -> Result<(), LifecycleError> {
        let lease = load_lease(&scope.lease_path)?;
        if let Some(record) = lease.as_ref() {
            match query_process_identity(record.core.pid, PROCESS_QUERY_LIMITED_INFORMATION) {
                Ok(observed)
                    if leased_process_identity_action(core_matches_child(
                        &record.core,
                        &observed,
                    )) == LeasedProcessIdentityAction::ReconcileExact =>
                {
                    let app_is_live = app_identity_is_live(&record.app);
                    let bridge = listener_state(&record.app);
                    let decision = super::lease::evaluate_candidate(&Candidate::Leased {
                        requesting_app: requesting_app.clone(),
                        leased_app: record.app.clone(),
                        app_is_live,
                        core_is_exact: true,
                        bridge,
                    });
                    match decision {
                        CandidateDecision::Terminate => {
                            log(super::child_termination_event(
                                "lease-reconcile",
                                record.core.pid,
                                record.core.creation_time_100ns,
                            ));
                            terminate_revalidated(&record.core, budget)?;
                            remove_lease_if_present(&scope.lease_path)?;
                        }
                        CandidateDecision::Conflict
                        | CandidateDecision::Refuse
                        | CandidateDecision::Ignore => {
                            return Err(LifecycleError::ActiveInAnotherSession)
                        }
                    }
                }
                Ok(_) => {
                    log(super::child_termination_event(
                        "lease-stale-removed",
                        record.core.pid,
                        record.core.creation_time_100ns,
                    ));
                    remove_lease_if_present(&scope.lease_path)?;
                }
                Err(LifecycleError::Windows { .. }) => {
                    if process_id_exists(record.core.pid)? {
                        return Err(LifecycleError::ActiveInAnotherSession);
                    }
                    log(super::child_termination_event(
                        "lease-stale-removed",
                        record.core.pid,
                        record.core.creation_time_100ns,
                    ));
                    remove_lease_if_present(&scope.lease_path)?;
                }
                Err(error) => return Err(error),
            }
        }

        let leased_pid = lease.as_ref().map(|record| record.core.pid);
        for observed in enumerate_exact_core_candidates(&scope.core_path)? {
            if Some(observed.pid) == leased_pid {
                continue;
            }
            let bridge = legacy_bridge_state(observed.pid);
            let decision = super::lease::evaluate_candidate(&Candidate::Legacy {
                observed_path: Some(observed.canonical_path.clone()),
                expected_path: scope.core_path.clone(),
                bridge,
            });
            match decision {
                CandidateDecision::Terminate => {
                    let legacy = CoreIdentity {
                        pid: observed.pid,
                        creation_time_100ns: observed.creation_time_100ns,
                        canonical_path: observed.canonical_path,
                        run_token: super::lease::RunToken::parse(
                            "00000000000000000000000000000000",
                        )
                        .map_err(|_| LifecycleError::InvalidInput("internal legacy token"))?,
                    };
                    log(super::child_termination_event(
                        "legacy-reconcile",
                        legacy.pid,
                        legacy.creation_time_100ns,
                    ));
                    terminate_revalidated(&legacy, budget)?;
                }
                CandidateDecision::Ignore => {}
                CandidateDecision::Conflict | CandidateDecision::Refuse => {
                    return Err(LifecycleError::ActiveInAnotherSession)
                }
            }
        }
        Ok(())
    }

    fn ensure_restricted_directory(path: &Path) -> Result<(), LifecycleError> {
        fs::create_dir_all(path).map_err(|source| LifecycleError::Io {
            operation: "create lifecycle directory",
            source,
        })?;
        ensure_not_reparse_point(path)?;
        apply_restricted_security(path)?;
        ensure_system_owned_path(path)
    }

    fn restricted_security_descriptor() -> Result<LocalSecurityDescriptor, LifecycleError> {
        let sddl = wide_nul(OsStr::new(super::LIFECYCLE_SECURITY_SDDL))?;
        let mut descriptor = PSECURITY_DESCRIPTOR::default();
        // SAFETY: Category 8 (FFI boundary). sddl is a live NUL-terminated UTF-16
        // string and descriptor points to writable initialized storage.
        unsafe {
            ConvertStringSecurityDescriptorToSecurityDescriptorW(
                PCWSTR(sddl.as_ptr()),
                1,
                &mut descriptor,
                None,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "ConvertStringSecurityDescriptorToSecurityDescriptorW",
            source,
        })?;
        Ok(LocalSecurityDescriptor(descriptor))
    }

    fn apply_restricted_security(path: &Path) -> Result<(), LifecycleError> {
        let descriptor_guard = restricted_security_descriptor()?;
        let mut owner = PSID::default();
        let mut owner_defaulted = BOOL::default();
        // SAFETY: Category 8 (FFI boundary). descriptor_guard owns a valid
        // self-relative descriptor and both outputs point to writable storage.
        unsafe { GetSecurityDescriptorOwner(descriptor_guard.0, &mut owner, &mut owner_defaulted) }
            .map_err(|source| LifecycleError::Windows {
                operation: "GetSecurityDescriptorOwner",
                source,
            })?;
        if owner.is_invalid() {
            return Err(LifecycleError::InvalidInput(
                "restricted lifecycle owner is absent",
            ));
        }
        let mut present = BOOL::default();
        let mut defaulted = BOOL::default();
        let mut dacl = ptr::null_mut::<ACL>();
        // SAFETY: Category 8 (FFI boundary). descriptor_guard owns a valid
        // self-relative descriptor and all outputs point to writable storage.
        unsafe {
            GetSecurityDescriptorDacl(descriptor_guard.0, &mut present, &mut dacl, &mut defaulted)
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "GetSecurityDescriptorDacl",
            source,
        })?;
        if !present.as_bool() || dacl.is_null() {
            return Err(LifecycleError::InvalidInput(
                "restricted lifecycle DACL is absent",
            ));
        }
        let path_wide = wide_nul(path.as_os_str())?;
        // SAFETY: Category 8 (FFI boundary). path_wide is NUL-terminated, while
        // owner and dacl remain owned by descriptor_guard for this complete call.
        let status = unsafe {
            SetNamedSecurityInfoW(
                PWSTR(path_wide.as_ptr().cast_mut()),
                SE_FILE_OBJECT,
                OWNER_SECURITY_INFORMATION
                    | DACL_SECURITY_INFORMATION
                    | PROTECTED_DACL_SECURITY_INFORMATION,
                owner,
                PSID::default(),
                Some(dacl),
                None,
            )
        };
        if status.is_err() {
            return Err(LifecycleError::Windows {
                operation: "SetNamedSecurityInfoW",
                source: windows::core::Error::from(status),
            });
        }
        Ok(())
    }

    fn ensure_system_owned_path(path: &Path) -> Result<(), LifecycleError> {
        ensure_not_reparse_point(path)?;
        let path_wide = wide_nul(path.as_os_str())?;
        let mut owner = PSID::default();
        let mut descriptor = PSECURITY_DESCRIPTOR::default();
        // SAFETY: Category 8 (FFI boundary). path_wide is NUL-terminated and the
        // owner/descriptor outputs point to initialized writable values.
        let status = unsafe {
            GetNamedSecurityInfoW(
                PCWSTR(path_wide.as_ptr()),
                SE_FILE_OBJECT,
                OWNER_SECURITY_INFORMATION,
                Some(&mut owner),
                None,
                None,
                None,
                &mut descriptor,
            )
        };
        if status.is_err() {
            return Err(LifecycleError::Windows {
                operation: "GetNamedSecurityInfoW(owner)",
                source: windows::core::Error::from(status),
            });
        }
        let _descriptor_guard = LocalSecurityDescriptor(descriptor);
        if !sid_is_local_system(owner)? {
            return Err(LifecycleError::UnknownLease);
        }
        Ok(())
    }

    fn ensure_not_reparse_point(path: &Path) -> Result<(), LifecycleError> {
        let path_wide = wide_nul(path.as_os_str())?;
        // SAFETY: Category 8 (FFI boundary). path_wide is a live NUL-terminated
        // path and GetFileAttributesW only reads it.
        let attributes = unsafe { GetFileAttributesW(PCWSTR(path_wide.as_ptr())) };
        if attributes == u32::MAX || attributes & FILE_ATTRIBUTE_REPARSE_POINT.0 != 0 {
            return Err(LifecycleError::UnknownLease);
        }
        Ok(())
    }

    fn ensure_system_owned_handle(handle: &OwnedHandle) -> Result<(), LifecycleError> {
        let mut owner = PSID::default();
        let mut descriptor = PSECURITY_DESCRIPTOR::default();
        // SAFETY: Category 8 (FFI boundary). handle is a live kernel-object
        // handle and owner/descriptor point to writable initialized values.
        let status = unsafe {
            GetSecurityInfo(
                raw_handle(handle),
                SE_KERNEL_OBJECT,
                OWNER_SECURITY_INFORMATION,
                Some(&mut owner),
                None,
                None,
                None,
                Some(&mut descriptor),
            )
        };
        if status.is_err() {
            return Err(LifecycleError::Windows {
                operation: "GetSecurityInfo(mutex owner)",
                source: windows::core::Error::from(status),
            });
        }
        let _descriptor_guard = LocalSecurityDescriptor(descriptor);
        if !sid_is_local_system(owner)? {
            return Err(LifecycleError::IdentityMismatch(
                "lifecycle mutex is not owned by LocalSystem",
            ));
        }
        Ok(())
    }

    fn sid_is_local_system(owner: PSID) -> Result<bool, LifecycleError> {
        let mut sid_storage = [0_usize; 9];
        let mut sid_size = SECURITY_MAX_SID_SIZE;
        let system_sid = PSID(sid_storage.as_mut_ptr().cast::<c_void>());
        // SAFETY: Category 8 (FFI boundary). sid_storage is aligned and large
        // enough for SECURITY_MAX_SID_SIZE, with sid_size as a writable length.
        unsafe {
            CreateWellKnownSid(
                WinLocalSystemSid,
                PSID::default(),
                system_sid,
                &mut sid_size,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "CreateWellKnownSid(LocalSystem)",
            source,
        })?;
        // SAFETY: Category 8 (FFI boundary). Both SIDs were returned by Win32
        // security APIs and remain live for this comparison.
        Ok(unsafe { EqualSid(owner, system_sid) }.is_ok())
    }

    struct LocalSecurityDescriptor(PSECURITY_DESCRIPTOR);

    impl Drop for LocalSecurityDescriptor {
        fn drop(&mut self) {
            // SAFETY: Category 8 (FFI boundary). ConvertStringSecurityDescriptor
            // allocated this descriptor with LocalAlloc and ownership is singular.
            let _remaining = unsafe { LocalFree(HLOCAL(self.0 .0)) };
        }
    }

    fn load_lease(path: &Path) -> Result<Option<LeaseRecord>, LifecycleError> {
        if !path.exists() {
            return Ok(None);
        }
        ensure_system_owned_path(path)?;
        apply_restricted_security(path)?;
        let mut file = match File::open(path) {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
            Err(source) => {
                return Err(LifecycleError::Io {
                    operation: "open lifecycle lease",
                    source,
                })
            }
        };
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)
            .map_err(|source| LifecycleError::Io {
                operation: "read lifecycle lease",
                source,
            })?;
        serde_json::from_slice(&bytes)
            .map(Some)
            .map_err(|_| LifecycleError::UnknownLease)
    }

    fn write_lease_atomic(path: &Path, lease: &LeaseRecord) -> Result<(), LifecycleError> {
        let bytes = serde_json::to_vec(lease)?;
        let temp_path = path.with_extension(format!("json.tmp-{}", std::process::id()));
        let mut temp = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temp_path)
            .map_err(|source| LifecycleError::Io {
                operation: "create temporary lifecycle lease",
                source,
            })?;
        temp.write_all(&bytes)
            .map_err(|source| LifecycleError::Io {
                operation: "write temporary lifecycle lease",
                source,
            })?;
        temp.sync_all().map_err(|source| LifecycleError::Io {
            operation: "flush temporary lifecycle lease",
            source,
        })?;
        drop(temp);
        apply_restricted_security(&temp_path)?;
        ensure_system_owned_path(&temp_path)?;
        let temp_wide = wide_nul(temp_path.as_os_str())?;
        let path_wide = wide_nul(path.as_os_str())?;
        // SAFETY: Category 8 (FFI boundary). Both paths are live NUL-terminated
        // UTF-16 strings and the source file handle was flushed and closed.
        let replace_result = unsafe {
            MoveFileExW(
                PCWSTR(temp_wide.as_ptr()),
                PCWSTR(path_wide.as_ptr()),
                MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
            )
        };
        if let Err(source) = replace_result {
            let _remove_result = fs::remove_file(&temp_path);
            return Err(LifecycleError::Windows {
                operation: "MoveFileExW(lifecycle lease)",
                source,
            });
        }
        Ok(())
    }

    fn remove_lease_if_present(path: &Path) -> Result<(), LifecycleError> {
        match fs::remove_file(path) {
            Ok(()) => Ok(()),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(source) => Err(LifecycleError::Io {
                operation: "remove lifecycle lease",
                source,
            }),
        }
    }

    fn app_identity_is_live(expected: &AppIdentity) -> bool {
        let Ok(process) = open_process(expected.pid, PROCESS_QUERY_LIMITED_INFORMATION) else {
            return false;
        };
        let Ok(observed) = query_identity_from_handle(&process, expected.pid) else {
            return false;
        };
        let mut session_id = 0_u32;
        // SAFETY: Category 8 (FFI boundary). session_id is writable and the
        // process identifier is the exact lease value being revalidated.
        let session_result = unsafe { ProcessIdToSessionId(expected.pid, &mut session_id) };
        session_result.is_ok()
            && observed.creation_time_100ns == expected.creation_time_100ns
            && session_id == expected.session_id
    }

    fn listener_state(app: &AppIdentity) -> BridgeState {
        let Ok(rows) = tcp_rows(TCP_TABLE_OWNER_PID_LISTENER) else {
            return BridgeState::Unknown;
        };
        let matching = rows.iter().find(|row| {
            row.state == MIB_TCP_STATE_LISTEN
                && row.local_addr == u32::from_ne_bytes([127, 0, 0, 1])
                && row.local_port == app.bridge_port
        });
        match matching {
            Some(row) if row.pid == app.pid => BridgeState::ListeningByApp,
            Some(_) => BridgeState::Unknown,
            None => BridgeState::NotListening,
        }
    }

    fn legacy_bridge_state(core_pid: u32) -> BridgeState {
        let Ok(rows) = tcp_rows(TCP_TABLE_OWNER_PID_ALL) else {
            return BridgeState::Unknown;
        };
        if rows.iter().any(|row| {
            row.pid == core_pid
                && row.state == MIB_TCP_STATE_ESTABLISHED
                && (row.local_addr == u32::from_ne_bytes([127, 0, 0, 1])
                    || row.remote_addr == u32::from_ne_bytes([127, 0, 0, 1]))
        }) {
            BridgeState::Unknown
        } else {
            BridgeState::NotListening
        }
    }

    struct TcpRow {
        state: u32,
        local_addr: u32,
        local_port: u16,
        remote_addr: u32,
        pid: u32,
    }

    fn tcp_rows(
        table_class: windows::Win32::NetworkManagement::IpHelper::TCP_TABLE_CLASS,
    ) -> Result<Vec<TcpRow>, LifecycleError> {
        let mut size = 0_u32;
        // SAFETY: Category 8 (FFI boundary). The null first buffer is the
        // documented size-query call and size points to writable storage.
        let first = unsafe {
            GetExtendedTcpTable(None, &mut size, false, u32::from(AF_INET.0), table_class, 0)
        };
        if first != ERROR_INSUFFICIENT_BUFFER.0 {
            return Err(last_windows_error("GetExtendedTcpTable(size)"));
        }
        let capacity = usize::try_from(size)
            .map_err(|_| LifecycleError::InvalidInput("TCP table size overflow"))?;
        let mut buffer = vec![0_u8; capacity];
        // SAFETY: Category 8 (FFI boundary). buffer is writable for exactly size
        // bytes and size remains a valid in/out length pointer.
        let status = unsafe {
            GetExtendedTcpTable(
                Some(buffer.as_mut_ptr().cast::<c_void>()),
                &mut size,
                false,
                u32::from(AF_INET.0),
                table_class,
                0,
            )
        };
        if status != 0 {
            return Err(last_windows_error("GetExtendedTcpTable"));
        }
        if buffer.len() < size_of::<u32>() {
            return Err(LifecycleError::InvalidInput("TCP table is truncated"));
        }
        let count = usize::try_from(u32::from_ne_bytes([
            buffer[0], buffer[1], buffer[2], buffer[3],
        ]))
        .map_err(|_| LifecycleError::InvalidInput("TCP row count overflow"))?;
        let required = size_of::<u32>()
            .checked_add(count.saturating_mul(TCP_ROW_SIZE))
            .ok_or(LifecycleError::InvalidInput("TCP table length overflow"))?;
        if required > buffer.len() {
            return Err(LifecycleError::InvalidInput("TCP rows are truncated"));
        }
        let mut rows = Vec::with_capacity(count);
        for index in 0..count {
            let offset = size_of::<u32>() + index * TCP_ROW_SIZE;
            let value = |field: usize| {
                u32::from_ne_bytes([
                    buffer[offset + field],
                    buffer[offset + field + 1],
                    buffer[offset + field + 2],
                    buffer[offset + field + 3],
                ])
            };
            rows.push(TcpRow {
                state: value(0),
                local_addr: value(4),
                local_port: u16::from_be((value(8) & 0xffff) as u16),
                remote_addr: value(12),
                pid: value(20),
            });
        }
        Ok(rows)
    }

    fn enumerate_exact_core_candidates(
        expected_path: &Path,
    ) -> Result<Vec<ChildIdentity>, LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). TH32CS_SNAPPROCESS requests a
        // read-only process snapshot whose handle is immediately transferred to RAII.
        let snapshot =
            unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0) }.map_err(|source| {
                LifecycleError::Windows {
                    operation: "CreateToolhelp32Snapshot",
                    source,
                }
            })?;
        let snapshot = own_handle(snapshot);
        let mut entry = PROCESSENTRY32W {
            dwSize: u32::try_from(size_of::<PROCESSENTRY32W>())
                .map_err(|_| LifecycleError::InvalidInput("PROCESSENTRY32W size overflow"))?,
            ..Default::default()
        };
        // SAFETY: Category 8 (FFI boundary). snapshot is valid and entry has the
        // required dwSize plus writable storage for every output field.
        unsafe { Process32FirstW(raw_handle(&snapshot), &mut entry) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "Process32FirstW",
                source,
            }
        })?;
        let mut candidates = Vec::new();
        loop {
            if entry.th32ProcessID != 0 {
                if let Ok(identity) =
                    query_process_identity(entry.th32ProcessID, PROCESS_QUERY_LIMITED_INFORMATION)
                {
                    if path_eq(&identity.canonical_path, expected_path) {
                        candidates.push(identity);
                    }
                }
            }
            // SAFETY: Category 8 (FFI boundary). snapshot and entry remain valid
            // across iteration and dwSize is preserved as required by ToolHelp.
            if unsafe { Process32NextW(raw_handle(&snapshot), &mut entry) }.is_err() {
                // SAFETY: Category 8 (FFI boundary). This reads the thread-local
                // status immediately after Process32NextW reported failure.
                let last = unsafe { GetLastError() };
                if last == ERROR_NO_MORE_FILES {
                    break;
                }
                return Err(last_windows_error("Process32NextW"));
            }
        }
        Ok(candidates)
    }

    fn process_id_exists(pid: u32) -> Result<bool, LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). TH32CS_SNAPPROCESS creates a
        // read-only snapshot and ownership transfers immediately to RAII.
        let snapshot =
            unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0) }.map_err(|source| {
                LifecycleError::Windows {
                    operation: "CreateToolhelp32Snapshot(process existence)",
                    source,
                }
            })?;
        let snapshot = own_handle(snapshot);
        let mut entry = PROCESSENTRY32W {
            dwSize: u32::try_from(size_of::<PROCESSENTRY32W>())
                .map_err(|_| LifecycleError::InvalidInput("PROCESSENTRY32W size overflow"))?,
            ..Default::default()
        };
        // SAFETY: Category 8 (FFI boundary). snapshot is valid and entry is a
        // correctly sized writable PROCESSENTRY32W.
        unsafe { Process32FirstW(raw_handle(&snapshot), &mut entry) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "Process32FirstW(process existence)",
                source,
            }
        })?;
        loop {
            if entry.th32ProcessID == pid {
                return Ok(true);
            }
            // SAFETY: Category 8 (FFI boundary). snapshot and entry remain live
            // and entry.dwSize remains initialized across the iteration.
            if unsafe { Process32NextW(raw_handle(&snapshot), &mut entry) }.is_err() {
                // SAFETY: Category 8 (FFI boundary). This immediately reads the
                // thread-local failure from Process32NextW.
                let last = unsafe { GetLastError() };
                if last == ERROR_NO_MORE_FILES {
                    return Ok(false);
                }
                return Err(last_windows_error("Process32NextW(process existence)"));
            }
        }
    }

    fn terminate_revalidated(
        expected: &CoreIdentity,
        budget: Duration,
    ) -> Result<(), LifecycleError> {
        let process = open_process(
            expected.pid,
            PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE | SYNCHRONIZE_PROCESS,
        )?;
        let observed = query_identity_from_handle(&process, expected.pid)?;
        if !core_matches_child(expected, &observed) {
            return Err(LifecycleError::IdentityMismatch(
                "candidate changed before termination",
            ));
        }
        // SAFETY: Category 8 (FFI boundary). process is a re-opened handle with
        // PROCESS_TERMINATE rights whose exact PID/creation/path was just rechecked.
        unsafe { TerminateProcess(raw_handle(&process), 0) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "TerminateProcess(reconciled)",
                source,
            }
        })?;
        let timeout_ms =
            u32::try_from(budget.as_millis()).map_err(|_| LifecycleError::StopBudgetOverflow)?;
        // SAFETY: Category 8 (FFI boundary). process includes SYNCHRONIZE rights
        // and remains owned across both waits.
        let status = unsafe { WaitForSingleObject(raw_handle(&process), timeout_ms) };
        match status {
            WAIT_OBJECT_0 => Ok(()),
            WAIT_TIMEOUT => {
                // SAFETY: Category 8 (FFI boundary). The same process handle remains
                // valid and a mandatory wait is required after approved termination.
                let mandatory = unsafe { WaitForSingleObject(raw_handle(&process), INFINITE) };
                match mandatory {
                    WAIT_OBJECT_0 => Ok(()),
                    WAIT_FAILED => Err(last_windows_error("WaitForSingleObject(reconciled)")),
                    other => Err(LifecycleError::UnexpectedWait(other.0)),
                }
            }
            WAIT_FAILED => Err(last_windows_error("WaitForSingleObject(reconciled)")),
            other => Err(LifecycleError::UnexpectedWait(other.0)),
        }
    }

    fn open_process(
        pid: u32,
        rights: PROCESS_ACCESS_RIGHTS,
    ) -> Result<OwnedHandle, LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). pid and access mask are plain values;
        // inheritance is disabled and successful ownership transfers to RAII.
        let handle = unsafe { OpenProcess(rights, false, pid) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "OpenProcess",
                source,
            }
        })?;
        Ok(own_handle(handle))
    }

    fn query_process_identity(
        pid: u32,
        rights: PROCESS_ACCESS_RIGHTS,
    ) -> Result<ChildIdentity, LifecycleError> {
        let process = open_process(pid, rights)?;
        query_identity_from_handle(&process, pid)
    }

    fn query_identity_from_handle(
        process: &OwnedHandle,
        pid: u32,
    ) -> Result<ChildIdentity, LifecycleError> {
        let mut creation = Default::default();
        let mut exit = Default::default();
        let mut kernel = Default::default();
        let mut user = Default::default();
        // SAFETY: Category 8 (FFI boundary). process is a live handle and all
        // FILETIME outputs point to initialized writable values.
        unsafe {
            GetProcessTimes(
                raw_handle(process),
                &mut creation,
                &mut exit,
                &mut kernel,
                &mut user,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "GetProcessTimes",
            source,
        })?;
        Ok(ChildIdentity {
            pid,
            creation_time_100ns: (u64::from(creation.dwHighDateTime) << 32)
                | u64::from(creation.dwLowDateTime),
            canonical_path: query_canonical_process_path_handle(process)?,
        })
    }

    fn core_matches_child(expected: &CoreIdentity, observed: &ChildIdentity) -> bool {
        expected.pid == observed.pid
            && expected.creation_time_100ns == observed.creation_time_100ns
            && path_eq(&expected.canonical_path, &observed.canonical_path)
    }

    fn path_eq(left: &Path, right: &Path) -> bool {
        normalize_path(left).eq_ignore_ascii_case(&normalize_path(right))
    }

    fn canonicalize_path(path: &Path) -> Result<PathBuf, LifecycleError> {
        fs::canonicalize(path).map_err(|source| LifecycleError::Io {
            operation: "canonicalize install path",
            source,
        })
    }

    fn normalize_path(path: &Path) -> String {
        let value = path.to_string_lossy();
        value.strip_prefix(r"\\?\").unwrap_or(&value).to_owned()
    }

    #[derive(Clone, Copy, Debug, Eq, PartialEq)]
    enum WaitOutcome {
        Exited,
        TimedOut,
    }

    // Spawn invariant: no code path leaves a live or suspended child outside a
    // kill-on-close Job.
    fn spawn_contained(
        request: SpawnRequest<'_>,
    ) -> Result<(ContainedProcess, ChildIdentity, File), LifecycleError> {
        let path_wide = wide_nul(request.path.as_os_str())?;
        let mut command_line = Vec::with_capacity(path_wide.len() + 64);
        command_line.push(u16::from(b'"'));
        command_line.extend_from_slice(&path_wide[..path_wide.len() - 1]);
        command_line.push(u16::from(b'"'));
        command_line.push(u16::from(b' '));
        command_line.extend(request.bridge_port.to_string().encode_utf16());
        command_line.extend(" --run-token ".encode_utf16());
        command_line.extend(request.run_token.as_str().encode_utf16());
        command_line.push(0);
        let mut environment = build_environment_block(request.home_dir)?;
        let environment_ptr = if environment.is_empty() {
            None
        } else {
            Some(environment.as_mut_ptr().cast::<c_void>() as *const c_void)
        };

        let job = create_kill_on_close_job()?;
        let (stderr_read, stderr_write) = create_stderr_pipe()?;
        let startup = STARTUPINFOW {
            cb: u32::try_from(size_of::<STARTUPINFOW>())
                .map_err(|_| LifecycleError::InvalidInput("STARTUPINFOW size overflow"))?,
            dwFlags: STARTF_USESTDHANDLES,
            hStdError: raw_handle(&stderr_write),
            ..Default::default()
        };
        let mut process_information = PROCESS_INFORMATION::default();
        let creation_flags = CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT;

        // SAFETY: Category 8 (FFI boundary). All pointers reference live, initialized
        // buffers for the duration of the call; command_line is mutable and NUL-terminated.
        unsafe {
            CreateProcessW(
                PCWSTR(path_wide.as_ptr()),
                PWSTR(command_line.as_mut_ptr()),
                None,
                None,
                true,
                creation_flags,
                environment_ptr,
                PCWSTR::null(),
                &startup,
                &mut process_information,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "CreateProcessW",
            source,
        })?;

        let process = own_handle(process_information.hProcess);
        let primary_thread = own_handle(process_information.hThread);
        let child = ContainedProcess { process, job };

        let resume_result = (|| {
            // SAFETY: Category 8 (FFI boundary). Both handles are valid owned handles
            // returned by successful CreateJobObjectW/CreateProcessW calls.
            unsafe { AssignProcessToJobObject(raw_handle(&child.job), raw_handle(&child.process)) }
                .map_err(|source| LifecycleError::Windows {
                    operation: "AssignProcessToJobObject",
                    source,
                })?;

            let identity = query_identity(&child, process_information.dwProcessId)?;

            // SAFETY: Category 8 (FFI boundary). The retained primary thread handle is
            // valid and the process is still suspended after successful Job assignment.
            let previous_suspend_count = unsafe { ResumeThread(raw_handle(&primary_thread)) };
            if previous_suspend_count == RESUME_THREAD_FAILED {
                return Err(last_windows_error("ResumeThread"));
            }
            Ok(identity)
        })();
        let identity = match resume_result {
            Ok(identity) => identity,
            Err(error) => {
                // Cleanup failure is deliberately ignored so the original spawn error wins.
                let _cleanup_result = terminate_process(&child);
                return Err(error);
            }
        };
        drop(primary_thread);
        drop(stderr_write);

        Ok((child, identity, File::from(stderr_read)))
    }

    fn create_kill_on_close_job() -> Result<OwnedHandle, LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). Null security/name parameters request
        // an unnamed Job with default security and transfer its handle to RAII.
        let job = unsafe { CreateJobObjectW(None, PCWSTR::null()) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "CreateJobObjectW",
                source,
            }
        })?;
        let job = own_handle(job);
        let mut limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
        limits.BasicLimitInformation.LimitFlags |= JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        let limits_size = u32::try_from(size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>())
            .map_err(|_| LifecycleError::InvalidInput("Job information size overflow"))?;

        // SAFETY: Category 8 (FFI boundary). limits points to an initialized value
        // whose byte length exactly matches JOBOBJECT_EXTENDED_LIMIT_INFORMATION.
        unsafe {
            SetInformationJobObject(
                raw_handle(&job),
                JobObjectExtendedLimitInformation,
                ptr::from_ref(&limits).cast::<c_void>(),
                limits_size,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "SetInformationJobObject",
            source,
        })?;
        Ok(job)
    }

    fn create_stderr_pipe() -> Result<(OwnedHandle, OwnedHandle), LifecycleError> {
        let mut read = HANDLE::default();
        let mut write = HANDLE::default();
        let attributes = SECURITY_ATTRIBUTES {
            nLength: u32::try_from(size_of::<SECURITY_ATTRIBUTES>())
                .map_err(|_| LifecycleError::InvalidInput("SECURITY_ATTRIBUTES size overflow"))?,
            lpSecurityDescriptor: ptr::null_mut(),
            bInheritHandle: true.into(),
        };

        // SAFETY: Category 8 (FFI boundary). Output pointers target initialized HANDLE
        // slots and attributes remains live for the call.
        unsafe { CreatePipe(&mut read, &mut write, Some(ptr::from_ref(&attributes)), 0) }.map_err(
            |source| LifecycleError::Windows {
                operation: "CreatePipe",
                source,
            },
        )?;
        let read = own_handle(read);
        let write = own_handle(write);

        // SAFETY: Category 8 (FFI boundary). read is a valid pipe handle; clearing
        // HANDLE_FLAG_INHERIT keeps only the child-side write handle inheritable.
        unsafe {
            SetHandleInformation(
                raw_handle(&read),
                HANDLE_FLAG_INHERIT.0,
                HANDLE_FLAGS::default(),
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "SetHandleInformation",
            source,
        })?;
        Ok((read, write))
    }

    fn query_identity(child: &ContainedProcess, pid: u32) -> Result<ChildIdentity, LifecycleError> {
        query_identity_from_handle(&child.process, pid)
    }

    fn query_canonical_process_path_handle(
        process: &OwnedHandle,
    ) -> Result<PathBuf, LifecycleError> {
        let mut image = vec![0_u16; WINDOWS_PATH_BUFFER_LEN];
        let mut image_len = u32::try_from(image.len())
            .map_err(|_| LifecycleError::InvalidInput("process path buffer overflow"))?;
        // SAFETY: Category 8 (FFI boundary). image is a writable u16 buffer and
        // image_len accurately describes its capacity.
        unsafe {
            QueryFullProcessImageNameW(
                raw_handle(process),
                PROCESS_NAME_WIN32,
                PWSTR(image.as_mut_ptr()),
                &mut image_len,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "QueryFullProcessImageNameW",
            source,
        })?;
        image.truncate(
            usize::try_from(image_len)
                .map_err(|_| LifecycleError::InvalidInput("process path length overflow"))?,
        );
        image.push(0);

        // SAFETY: Category 8 (FFI boundary). image is NUL-terminated and names
        // the executable returned by the retained process handle.
        let file = unsafe {
            CreateFileW(
                PCWSTR(image.as_ptr()),
                FILE_READ_ATTRIBUTES.0,
                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                None,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL,
                None,
            )
        }
        .map_err(|source| LifecycleError::Windows {
            operation: "CreateFileW(process image)",
            source,
        })?;
        let file = own_handle(file);
        let mut final_path = vec![0_u16; WINDOWS_PATH_BUFFER_LEN];
        // SAFETY: Category 8 (FFI boundary). file is a valid executable file handle
        // and final_path is a writable buffer with the exact supplied capacity.
        let final_len = unsafe {
            GetFinalPathNameByHandleW(
                raw_handle(&file),
                &mut final_path,
                GETFINALPATHNAMEBYHANDLE_FLAGS(FILE_NAME_NORMALIZED.0 | VOLUME_NAME_DOS.0),
            )
        };
        if final_len == 0 {
            return Err(last_windows_error("GetFinalPathNameByHandleW"));
        }
        let final_len = usize::try_from(final_len)
            .map_err(|_| LifecycleError::InvalidInput("final path length overflow"))?;
        if final_len >= final_path.len() {
            return Err(LifecycleError::InvalidInput("final path buffer too small"));
        }
        final_path.truncate(final_len);
        let prefix = [
            u16::from(b'\\'),
            u16::from(b'\\'),
            u16::from(b'?'),
            u16::from(b'\\'),
        ];
        let normalized = final_path.strip_prefix(&prefix).unwrap_or(&final_path);
        Ok(PathBuf::from(OsString::from_wide(normalized)))
    }

    fn terminate_process(child: &ContainedProcess) -> Result<(), LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). process is a valid retained handle
        // with PROCESS_TERMINATE rights from CreateProcessW.
        unsafe { TerminateProcess(raw_handle(&child.process), 0) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "TerminateProcess",
                source,
            }
        })
    }

    fn terminate_job(child: &ContainedProcess) -> Result<(), LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). job is the valid retained Job handle
        // that contains this process and all descendants.
        unsafe { TerminateJobObject(raw_handle(&child.job), 1) }.map_err(|source| {
            LifecycleError::Windows {
                operation: "TerminateJobObject",
                source,
            }
        })
    }

    fn wait_for_process(
        child: &ContainedProcess,
        timeout_ms: u32,
    ) -> Result<WaitOutcome, LifecycleError> {
        // SAFETY: Category 8 (FFI boundary). process remains owned for the full wait.
        let status = unsafe { WaitForSingleObject(raw_handle(&child.process), timeout_ms) };
        match status {
            WAIT_OBJECT_0 => Ok(WaitOutcome::Exited),
            WAIT_TIMEOUT => Ok(WaitOutcome::TimedOut),
            WAIT_FAILED => Err(last_windows_error("WaitForSingleObject")),
            other => Err(LifecycleError::UnexpectedWait(other.0)),
        }
    }

    fn wait_for_process_mandatory(child: &ContainedProcess) -> Result<(), LifecycleError> {
        match wait_for_process(child, INFINITE)? {
            WaitOutcome::Exited => Ok(()),
            WaitOutcome::TimedOut => Err(LifecycleError::UnexpectedWait(WAIT_TIMEOUT.0)),
        }
    }

    fn build_environment_block(home_dir: Option<&OsStr>) -> Result<Vec<u16>, LifecycleError> {
        let Some(home_dir) = home_dir else {
            return Ok(Vec::new());
        };
        if home_dir.encode_wide().any(|unit| unit == 0) {
            return Err(LifecycleError::InvalidInput("SAFE_PATHS contains NUL"));
        }

        let mut entries = std::env::vars_os()
            .filter(|(key, _)| !key.to_string_lossy().eq_ignore_ascii_case("SAFE_PATHS"))
            .collect::<Vec<_>>();
        entries.push((OsString::from("SAFE_PATHS"), home_dir.to_os_string()));
        entries.sort_by_key(|(key, _)| key.to_string_lossy().to_uppercase());

        let mut block = Vec::new();
        for (key, value) in entries {
            block.extend(key.encode_wide());
            block.push(u16::from(b'='));
            block.extend(value.encode_wide());
            block.push(0);
        }
        block.push(0);
        Ok(block)
    }

    fn wide_nul(value: &OsStr) -> Result<Vec<u16>, LifecycleError> {
        let mut wide = value.encode_wide().collect::<Vec<_>>();
        if wide.contains(&0) {
            return Err(LifecycleError::InvalidInput("Windows string contains NUL"));
        }
        wide.push(0);
        Ok(wide)
    }

    fn own_handle(handle: HANDLE) -> OwnedHandle {
        // SAFETY: Category 8 (FFI boundary). Callers pass each successful Win32
        // owned HANDLE exactly once, transferring its sole close responsibility.
        unsafe { OwnedHandle::from_raw_handle(handle.0) }
    }

    fn raw_handle(handle: &OwnedHandle) -> HANDLE {
        HANDLE(handle.as_raw_handle())
    }

    fn last_windows_error(operation: &'static str) -> LifecycleError {
        // SAFETY: Category 8 (FFI boundary). This immediately reads the calling
        // thread's last-error value after the failed Win32 operation.
        let code = unsafe { GetLastError() };
        LifecycleError::Windows {
            operation,
            source: windows::core::Error::from(code),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        child_termination_event, leased_process_identity_action, ChildIdentity,
        LeasedProcessIdentityAction, LifecycleOwner, LifecycleState, LIFECYCLE_SECURITY_SDDL,
    };
    use std::path::PathBuf;

    fn child_identity() -> ChildIdentity {
        ChildIdentity {
            pid: 42,
            creation_time_100ns: 1337,
            canonical_path: PathBuf::from(r"C:\Program Files\dropweb\DropwebCore.exe"),
        }
    }

    #[test]
    fn lifecycle_reaches_stopped_only_after_observed_exit() {
        let mut owner = LifecycleOwner::running(child_identity());

        owner.request_stop();

        assert_eq!(owner.state, LifecycleState::StopPending);
        assert_eq!(owner.child_identity(), Some(&child_identity()));

        owner.observe_exit();

        assert_eq!(owner.state, LifecycleState::Stopped);
        assert_eq!(owner.child_identity(), None);
    }

    #[test]
    fn repeated_stop_request_is_idempotent() {
        let mut owner = LifecycleOwner::running(child_identity());

        owner.request_stop();
        owner.request_stop();

        assert_eq!(owner.state, LifecycleState::StopPending);
        assert_eq!(owner.child_identity(), Some(&child_identity()));
    }

    #[test]
    fn recycled_leased_pid_removes_stale_lease_without_termination() {
        let action = leased_process_identity_action(false);

        assert_eq!(action, LeasedProcessIdentityAction::RemoveStaleLease);
    }

    #[test]
    fn lifecycle_security_descriptor_pins_system_owner_and_inheritance() {
        assert_eq!(
            LIFECYCLE_SECURITY_SDDL,
            "O:SYD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"
        );
    }

    #[test]
    fn child_termination_event_contains_reason_and_exact_identity() {
        assert_eq!(
            child_termination_event("start-replace", 42, 1337),
            "[lifecycle] child-decision reason=start-replace pid=42 creation=1337"
        );
    }
}
