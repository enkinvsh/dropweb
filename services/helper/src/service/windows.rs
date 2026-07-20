use crate::service::hub::{begin_service_shutdown, run_service_until, stop_core, STOP_BUDGET};
use std::ffi::OsString;
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::sync::watch;
use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult, ServiceStatusHandle},
    service_dispatcher, Result,
};

const SERVICE_NAME: &str = "DropwebHelperService";
const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;
const STOP_PROGRESS_INTERVAL: Duration = Duration::from_secs(2);
const HTTP_SHUTDOWN_BUDGET: Duration = Duration::from_secs(1);

pub fn main() -> Result<()> {
    start_service()
}

pub fn start_service() -> Result<()> {
    service_dispatcher::start(SERVICE_NAME, service_entry)
}

define_windows_service!(service_entry, service_main);

pub fn service_main(_arguments: Vec<OsString>) {
    if let Ok(runtime) = Runtime::new() {
        runtime.block_on(async {
            if let Err(error) = run_windows_service().await {
                eprintln!("Windows helper service failed: {error}");
            }
        });
    }
}

async fn run_windows_service() -> anyhow::Result<()> {
    let (shutdown_sender, mut shutdown_receiver) = watch::channel(false);
    let status_handle = service_control_handler::register(
        SERVICE_NAME,
        move |event| -> ServiceControlHandlerResult {
            match event {
                ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,
                ServiceControl::Stop => {
                    begin_service_shutdown();
                    shutdown_sender.send_replace(true);
                    ServiceControlHandlerResult::NoError
                }
                _ => ServiceControlHandlerResult::NotImplemented,
            }
        },
    )?;

    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Running,
        controls_accepted: ServiceControlAccept::STOP,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    let (http_shutdown_sender, mut http_shutdown_receiver) = watch::channel(false);
    let mut http_task = tokio::spawn(run_service_until(async move {
        while !*http_shutdown_receiver.borrow() {
            if http_shutdown_receiver.changed().await.is_err() {
                break;
            }
        }
    }));

    tokio::select! {
        changed = shutdown_receiver.changed() => {
            changed.map_err(|_| anyhow::anyhow!("SCM shutdown channel closed"))?;
        }
        server = &mut http_task => {
            server.map_err(|error| anyhow::anyhow!("HTTP service task failed: {error}"))??;
            return Err(anyhow::anyhow!("HTTP service stopped before SCM shutdown"));
        }
    }

    let mut checkpoint = 1;
    set_stop_pending(&status_handle, checkpoint)?;
    http_shutdown_sender.send_replace(true);
    match tokio::time::timeout(HTTP_SHUTDOWN_BUDGET, &mut http_task).await {
        Ok(result) => {
            result.map_err(|error| {
                anyhow::anyhow!("HTTP service task failed during shutdown: {error}")
            })??;
        }
        Err(_) => {
            http_task.abort();
            match http_task.await {
                Err(error) if error.is_cancelled() => {}
                Err(error) => {
                    return Err(anyhow::anyhow!(
                        "HTTP service task failed while aborting shutdown: {error}"
                    ))
                }
                Ok(result) => result?,
            }
        }
    }

    let mut stop_task = tokio::task::spawn_blocking(stop_core);
    let mut progress = tokio::time::interval(STOP_PROGRESS_INTERVAL);
    progress.tick().await;
    loop {
        tokio::select! {
            result = &mut stop_task => {
                result.map_err(|error| anyhow::anyhow!("core stop task failed: {error}"))??;
                break;
            }
            _ = progress.tick() => {
                checkpoint = checkpoint.saturating_add(1);
                set_stop_pending(&status_handle, checkpoint)?;
            }
        }
    }

    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Stopped,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;
    Ok(())
}

fn set_stop_pending(status_handle: &ServiceStatusHandle, checkpoint: u32) -> Result<()> {
    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::StopPending,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint,
        wait_hint: STOP_BUDGET,
        process_id: None,
    })
}
