use once_cell::sync::Lazy;
#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::convert::Infallible;
use std::fs::File;
use std::future;
use std::io::{BufRead, Error, Read};
#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
#[cfg(all(feature = "windows-service", target_os = "windows"))]
use std::time::Duration;
use warp::{Filter, Reply};

#[cfg(all(feature = "windows-service", target_os = "windows"))]
use crate::service::windows_lifecycle::lease::{StartCoreRequest, StopCoreRequest};
#[cfg(all(feature = "windows-service", target_os = "windows"))]
use crate::service::windows_lifecycle::{
    start_transaction, stop_for_service, stop_transaction, LifecycleError, LifecycleOwner,
};
#[cfg(all(feature = "windows-service", target_os = "windows"))]
use std::sync::atomic::{AtomicBool, Ordering};

const LISTEN_PORT: u16 = 47896;
#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub const STOP_BUDGET: Duration = Duration::from_secs(10);

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct StartParams {
    pub path: String,
    pub arg: String,
    pub home_dir: Option<String>,
}

fn sha256_file(path: &str) -> Result<String, Error> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 4096];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));
#[cfg(all(feature = "windows-service", target_os = "windows"))]
static PROCESS: Lazy<Arc<Mutex<LifecycleOwner>>> =
    Lazy::new(|| Arc::new(Mutex::new(LifecycleOwner::stopped())));
#[cfg(all(feature = "windows-service", target_os = "windows"))]
static SERVICE_STOPPING: AtomicBool = AtomicBool::new(false);

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
async fn start(start_params: StartParams) -> Result<impl Reply, Infallible> {
    let response = match tokio::task::spawn_blocking(move || start_blocking(start_params)).await {
        Ok(response) => response,
        Err(error) => error.to_string(),
    };
    Ok(response)
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
fn start_blocking(start_params: StartParams) -> String {
    let sha256 = sha256_file(start_params.path.as_str()).unwrap_or_default();
    let expected_sha256 = env!("TOKEN");
    if expected_sha256.is_empty() || sha256 != expected_sha256 {
        return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256, env!("TOKEN"));
    }

    match restart_core(&start_params) {
        Ok(stderr) => {
            thread::spawn(move || {
                for line in std::io::BufReader::new(stderr).lines() {
                    match line {
                        Ok(output) => log_message(output),
                        Err(_) => break,
                    }
                }
            });
            String::new()
        }
        Err(error) => {
            log_message(error.to_string());
            error.to_string()
        }
    }
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
async fn start(request: StartCoreRequest) -> Result<warp::reply::Response, Infallible> {
    let response = match tokio::task::spawn_blocking(move || start_blocking(request)).await {
        Ok(response) => response,
        Err(error) => error_response(
            warp::http::StatusCode::INTERNAL_SERVER_ERROR,
            "lifecycleInternalError",
            &error.to_string(),
        ),
    };
    Ok(response)
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
fn start_blocking(request: StartCoreRequest) -> warp::reply::Response {
    let sha256 = sha256_file(&request.path).unwrap_or_default();
    let expected_sha256 = env!("TOKEN");
    if expected_sha256.is_empty() || sha256 != expected_sha256 {
        return error_response(
            warp::http::StatusCode::FORBIDDEN,
            "coreHashMismatch",
            "requested core hash does not match the installed candidate",
        );
    }
    if SERVICE_STOPPING.load(Ordering::Acquire) {
        return error_response(
            warp::http::StatusCode::SERVICE_UNAVAILABLE,
            "serviceStopping",
            "helper service is stopping",
        );
    }
    let result = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))
        .and_then(|mut owner| {
            start_transaction(&mut owner, &request, STOP_BUDGET, &mut log_message)
                .map_err(anyhow::Error::new)
        });
    match result {
        Ok((stderr, response)) => {
            thread::spawn(move || {
                for line in std::io::BufReader::new(stderr).lines() {
                    match line {
                        Ok(output) => log_message(output),
                        Err(_) => break,
                    }
                }
            });
            warp::reply::json(&response).into_response()
        }
        Err(error) => {
            log_message(error.to_string());
            if error
                .downcast_ref::<LifecycleError>()
                .is_some_and(|error| matches!(error, LifecycleError::ActiveInAnotherSession))
            {
                error_response(
                    warp::http::StatusCode::CONFLICT,
                    "activeInAnotherSession",
                    "another Windows app session owns the active core",
                )
            } else {
                error_response(
                    warp::http::StatusCode::INTERNAL_SERVER_ERROR,
                    "lifecycleRejected",
                    &error.to_string(),
                )
            }
        }
    }
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
fn error_response(
    status: warp::http::StatusCode,
    code: &str,
    message: &str,
) -> warp::reply::Response {
    let body = serde_json::json!({ "code": code, "message": message });
    warp::reply::with_status(warp::reply::json(&body), status).into_response()
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
fn restart_core(start_params: &StartParams) -> anyhow::Result<Box<dyn Read + Send>> {
    let mut process = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?;
    if let Some(mut child) = process.take() {
        if child.try_wait()?.is_none() {
            child.kill()?;
        }
        child.wait()?;
    }
    let mut command = Command::new(&start_params.path);
    command.stderr(Stdio::piped()).arg(&start_params.arg);
    if let Some(home_dir) = &start_params.home_dir {
        command.env("SAFE_PATHS", home_dir);
    }

    let mut child = command.spawn()?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| anyhow::anyhow!("spawned core stderr pipe is absent"))?;
    *process = Some(child);
    Ok(Box::new(stderr))
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
async fn stop() -> Result<impl Reply, Infallible> {
    let response = match tokio::task::spawn_blocking(stop_core).await {
        Ok(Ok(())) => String::new(),
        Ok(Err(error)) => {
            log_message(error.to_string());
            error.to_string()
        }
        Err(error) => error.to_string(),
    };
    Ok(response)
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
async fn stop(request: StopCoreRequest) -> Result<warp::reply::Response, Infallible> {
    let response = match tokio::task::spawn_blocking(move || stop_core_request(&request)).await {
        Ok(Ok(())) => warp::reply::json(&serde_json::json!({ "stopped": true })).into_response(),
        Ok(Err(error)) => {
            log_message(error.to_string());
            if error
                .downcast_ref::<LifecycleError>()
                .is_some_and(|error| matches!(error, LifecycleError::IdentityMismatch(_)))
            {
                error_response(
                    warp::http::StatusCode::CONFLICT,
                    "lifecycleIdentityMismatch",
                    &error.to_string(),
                )
            } else {
                error_response(
                    warp::http::StatusCode::INTERNAL_SERVER_ERROR,
                    "lifecycleInternalError",
                    &error.to_string(),
                )
            }
        }
        Err(error) => error_response(
            warp::http::StatusCode::INTERNAL_SERVER_ERROR,
            "lifecycleInternalError",
            &error.to_string(),
        ),
    };
    Ok(response)
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
fn stop_core_request(request: &StopCoreRequest) -> anyhow::Result<()> {
    let mut owner = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?;
    stop_transaction(&mut owner, request, STOP_BUDGET, &mut log_message)?;
    Ok(())
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub fn begin_service_shutdown() {
    SERVICE_STOPPING.store(true, Ordering::Release);
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
pub fn stop_core() -> anyhow::Result<()> {
    let mut process = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?;
    if let Some(mut child) = process.take() {
        if child.try_wait()?.is_none() {
            child.kill()?;
        }
        child.wait()?;
    }
    Ok(())
}

#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub fn stop_core() -> anyhow::Result<()> {
    let mut owner = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?;
    stop_for_service(&mut owner, STOP_BUDGET, &mut log_message)?;
    Ok(())
}

fn log_message(message: String) {
    let mut log_buffer = LOGS.lock().unwrap();
    if log_buffer.len() == 100 {
        log_buffer.pop_front();
    }
    log_buffer.push_back(format!("{}\n", message));
}

fn get_logs() -> impl Reply {
    let log_buffer = LOGS.lock().unwrap();
    let value = log_buffer
        .iter()
        .cloned()
        .collect::<Vec<String>>()
        .join("\n");
    warp::reply::with_header(value, "Content-Type", "text/plain")
}

fn routes() -> impl Filter<Extract = (impl Reply,), Error = warp::Rejection> + Clone {
    let api_ping = warp::get().and(warp::path("ping")).map(|| env!("TOKEN"));
    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::body::json())
        .and_then(start);
    #[cfg(all(feature = "windows-service", target_os = "windows"))]
    let api_stop = warp::post()
        .and(warp::path("stop"))
        .and(warp::body::json())
        .and_then(stop);
    #[cfg(not(all(feature = "windows-service", target_os = "windows")))]
    let api_stop = warp::post().and(warp::path("stop")).and_then(stop);
    let api_logs = warp::get().and(warp::path("logs")).map(get_logs);

    api_ping.or(api_start).or(api_stop).or(api_logs)
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
pub async fn run_service() -> anyhow::Result<()> {
    run_service_until(future::pending()).await
}

pub async fn run_service_until<F>(shutdown: F) -> anyhow::Result<()>
where
    F: future::Future<Output = ()> + Send + 'static,
{
    let (_, server) =
        warp::serve(routes()).bind_with_graceful_shutdown(([127, 0, 0, 1], LISTEN_PORT), shutdown);
    server.await;
    Ok(())
}
