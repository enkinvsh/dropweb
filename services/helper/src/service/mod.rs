pub mod hub;
#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub mod windows;

#[cfg(all(feature = "windows-service", any(test, target_os = "windows")))]
pub mod windows_lifecycle;
