use once_cell::sync::Lazy;
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
use crate::service::windows_lifecycle::{LifecycleError, LifecycleOwner, SpawnRequest};
#[cfg(all(feature = "windows-service", target_os = "windows"))]
use std::sync::atomic::{AtomicBool, Ordering};

const LISTEN_PORT: u16 = 47896;
#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub const STOP_BUDGET: Duration = Duration::from_secs(10);

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

async fn start(start_params: StartParams) -> Result<impl Reply, Infallible> {
    let response = match tokio::task::spawn_blocking(move || start_blocking(start_params)).await {
        Ok(response) => response,
        Err(error) => error.to_string(),
    };
    Ok(response)
}

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

#[cfg(all(feature = "windows-service", target_os = "windows"))]
fn restart_core(start_params: &StartParams) -> anyhow::Result<Box<dyn Read + Send>> {
    let mut owner = PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?;
    if SERVICE_STOPPING.load(Ordering::Acquire) {
        return Err(anyhow::anyhow!("helper service is stopping"));
    }
    owner.stop_and_wait(STOP_BUDGET)?;
    let stderr = owner
        .spawn(SpawnRequest {
            path: std::path::Path::new(&start_params.path),
            argument: &start_params.arg,
            home_dir: start_params.home_dir.as_deref().map(std::ffi::OsStr::new),
        })
        .map_err(|error: LifecycleError| anyhow::Error::new(error))?;
    if let Some(identity) = owner.child_identity() {
        log_message(format!(
            "core lifecycle started: pid={} creationTime100ns={} path={}",
            identity.pid,
            identity.creation_time_100ns,
            identity.canonical_path.display()
        ));
    }
    Ok(Box::new(stderr))
}

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
    PROCESS
        .lock()
        .map_err(|_| anyhow::anyhow!("core lifecycle lock poisoned"))?
        .stop_and_wait(STOP_BUDGET)?;
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
