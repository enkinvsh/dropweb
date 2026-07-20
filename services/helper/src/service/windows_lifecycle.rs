use std::path::PathBuf;

// allow: SIZE_OK - the approved plan requires one isolated Win32 lifecycle/FFI boundary.

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ChildIdentity {
    pub pid: u32,
    pub creation_time_100ns: u64,
    pub canonical_path: PathBuf,
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
    #[cfg(target_os = "windows")]
    child: Option<windows_process::ContainedProcess>,
}

impl LifecycleOwner {
    pub const fn stopped() -> Self {
        Self {
            state: LifecycleState::Stopped,
            child_identity: None,
            #[cfg(target_os = "windows")]
            child: None,
        }
    }

    #[cfg(test)]
    fn running(child_identity: ChildIdentity) -> Self {
        Self {
            state: LifecycleState::Running,
            child_identity: Some(child_identity),
            #[cfg(target_os = "windows")]
            child: None,
        }
    }

    pub fn child_identity(&self) -> Option<&ChildIdentity> {
        self.child_identity.as_ref()
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
pub use windows_process::{LifecycleError, SpawnRequest};

#[cfg(target_os = "windows")]
mod windows_process {
    use super::{ChildIdentity, LifecycleOwner, LifecycleState};
    use std::ffi::{c_void, OsStr, OsString};
    use std::fs::File;
    use std::mem::size_of;
    use std::os::windows::ffi::{OsStrExt, OsStringExt};
    use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
    use std::path::{Path, PathBuf};
    use std::ptr;
    use std::time::Duration;
    use thiserror::Error;
    use windows::core::{PCWSTR, PWSTR};
    use windows::Win32::Foundation::{
        GetLastError, SetHandleInformation, HANDLE, HANDLE_FLAGS, HANDLE_FLAG_INHERIT, WAIT_FAILED,
        WAIT_OBJECT_0, WAIT_TIMEOUT,
    };
    use windows::Win32::Security::SECURITY_ATTRIBUTES;
    use windows::Win32::Storage::FileSystem::{
        CreateFileW, GetFinalPathNameByHandleW, FILE_ATTRIBUTE_NORMAL, FILE_NAME_NORMALIZED,
        FILE_READ_ATTRIBUTES, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE,
        GETFINALPATHNAMEBYHANDLE_FLAGS, OPEN_EXISTING, VOLUME_NAME_DOS,
    };
    use windows::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
        SetInformationJobObject, TerminateJobObject, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    };
    use windows::Win32::System::Pipes::CreatePipe;
    use windows::Win32::System::Threading::{
        CreateProcessW, GetProcessTimes, QueryFullProcessImageNameW, ResumeThread,
        TerminateProcess, WaitForSingleObject, CREATE_NO_WINDOW, CREATE_SUSPENDED,
        CREATE_UNICODE_ENVIRONMENT, INFINITE, PROCESS_INFORMATION, PROCESS_NAME_WIN32,
        STARTF_USESTDHANDLES, STARTUPINFOW,
    };

    const WINDOWS_PATH_BUFFER_LEN: usize = 32_768;
    const RESUME_THREAD_FAILED: u32 = u32::MAX;

    #[derive(Debug)]
    pub struct SpawnRequest<'a> {
        pub path: &'a Path,
        pub argument: &'a str,
        pub home_dir: Option<&'a OsStr>,
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
        let argument = parse_bridge_port(request.argument)?;
        let mut command_line = Vec::with_capacity(path_wide.len() + 8);
        command_line.push(u16::from(b'"'));
        command_line.extend_from_slice(&path_wide[..path_wide.len() - 1]);
        command_line.push(u16::from(b'"'));
        command_line.push(u16::from(b' '));
        command_line.extend(argument.to_string().encode_utf16());
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
        let mut creation = Default::default();
        let mut exit = Default::default();
        let mut kernel = Default::default();
        let mut user = Default::default();
        // SAFETY: Category 8 (FFI boundary). The process handle is valid and all
        // FILETIME output pointers reference initialized writable values.
        unsafe {
            GetProcessTimes(
                raw_handle(&child.process),
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
            canonical_path: query_canonical_process_path(child)?,
        })
    }

    fn query_canonical_process_path(child: &ContainedProcess) -> Result<PathBuf, LifecycleError> {
        let mut image = vec![0_u16; WINDOWS_PATH_BUFFER_LEN];
        let mut image_len = u32::try_from(image.len())
            .map_err(|_| LifecycleError::InvalidInput("process path buffer overflow"))?;
        // SAFETY: Category 8 (FFI boundary). image is a writable u16 buffer and
        // image_len accurately describes its capacity.
        unsafe {
            QueryFullProcessImageNameW(
                raw_handle(&child.process),
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

    fn parse_bridge_port(argument: &str) -> Result<u16, LifecycleError> {
        argument
            .parse::<u16>()
            .map_err(|_| LifecycleError::InvalidInput("bridge argument must be a TCP port"))
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
    use super::{ChildIdentity, LifecycleOwner, LifecycleState};
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
}
