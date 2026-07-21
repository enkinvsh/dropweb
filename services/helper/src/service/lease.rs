use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use thiserror::Error;

const RUN_TOKEN_HEX_LEN: usize = 32;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(try_from = "String", into = "String")]
pub struct RunToken(String);

impl RunToken {
    pub fn parse(value: &str) -> Result<Self, RunTokenError> {
        if value.len() != RUN_TOKEN_HEX_LEN
            || !value
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        {
            return Err(RunTokenError);
        }
        Ok(Self(value.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl TryFrom<String> for RunToken {
    type Error = RunTokenError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::parse(&value)
    }
}

impl From<RunToken> for String {
    fn from(value: RunToken) -> Self {
        value.0
    }
}

#[derive(Clone, Copy, Debug, Error, Eq, PartialEq)]
#[error("runToken must be 32 lowercase hexadecimal characters")]
pub struct RunTokenError;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppIdentity {
    pub pid: u32,
    pub creation_time_100ns: u64,
    pub session_id: u32,
    pub bridge_port: u16,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CoreIdentity {
    pub pid: u32,
    pub creation_time_100ns: u64,
    pub canonical_path: PathBuf,
    pub run_token: RunToken,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartCoreRequest {
    pub path: String,
    pub bridge_port: u16,
    pub home_dir: Option<String>,
    pub run_token: RunToken,
    pub app_pid: u32,
    pub app_creation_time_100ns: u64,
    pub app_session_id: u32,
}

impl StartCoreRequest {
    pub fn app_identity(&self) -> AppIdentity {
        AppIdentity {
            pid: self.app_pid,
            creation_time_100ns: self.app_creation_time_100ns,
            session_id: self.app_session_id,
            bridge_port: self.bridge_port,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartCoreResponse {
    pub core_pid: u32,
    pub core_creation_time_100ns: u64,
    pub run_token: RunToken,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StopCoreRequest {
    pub core_pid: u32,
    pub core_creation_time_100ns: u64,
    pub run_token: RunToken,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LeaseRecord {
    pub app: AppIdentity,
    pub core: CoreIdentity,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BridgeState {
    ListeningByApp,
    NotListening,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AppLiveness {
    Live,
    Dead,
    Unknown,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Candidate {
    Retained {
        expected: CoreIdentity,
        observed: CoreIdentity,
    },
    Leased {
        requesting_app: AppIdentity,
        leased_app: AppIdentity,
        app_liveness: AppLiveness,
        core_is_exact: bool,
        bridge: BridgeState,
    },
    Legacy {
        observed_path: Option<PathBuf>,
        expected_path: PathBuf,
        bridge: BridgeState,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CandidateDecision {
    Terminate,
    Conflict,
    Refuse,
    Ignore,
}

pub fn evaluate_candidate(candidate: &Candidate) -> CandidateDecision {
    match candidate {
        Candidate::Retained { expected, observed } => {
            if core_identity_eq(expected, observed) {
                CandidateDecision::Terminate
            } else {
                CandidateDecision::Refuse
            }
        }
        Candidate::Leased {
            requesting_app,
            leased_app,
            app_liveness,
            core_is_exact,
            bridge,
        } => {
            let owned_by_requester = requesting_app == leased_app && *core_is_exact;
            match app_liveness {
                AppLiveness::Live => {
                    if owned_by_requester {
                        CandidateDecision::Terminate
                    } else {
                        CandidateDecision::Conflict
                    }
                }
                AppLiveness::Dead => {
                    let proven_stale = *core_is_exact && *bridge == BridgeState::NotListening;
                    if owned_by_requester || proven_stale {
                        CandidateDecision::Terminate
                    } else {
                        CandidateDecision::Conflict
                    }
                }
                AppLiveness::Unknown => CandidateDecision::Conflict,
            }
        }
        Candidate::Legacy {
            observed_path,
            expected_path,
            bridge,
        } => match observed_path {
            Some(path) if path_eq(path, expected_path) => match bridge {
                BridgeState::NotListening => CandidateDecision::Terminate,
                BridgeState::ListeningByApp | BridgeState::Unknown => CandidateDecision::Conflict,
            },
            Some(_) => CandidateDecision::Ignore,
            None => CandidateDecision::Refuse,
        },
    }
}

fn core_identity_eq(left: &CoreIdentity, right: &CoreIdentity) -> bool {
    left.pid == right.pid
        && left.creation_time_100ns == right.creation_time_100ns
        && path_eq(&left.canonical_path, &right.canonical_path)
        && left.run_token == right.run_token
}

fn path_eq(left: &std::path::Path, right: &std::path::Path) -> bool {
    left.to_string_lossy()
        .eq_ignore_ascii_case(&right.to_string_lossy())
}

#[cfg(test)]
mod tests {
    use super::{
        evaluate_candidate, AppIdentity, AppLiveness, BridgeState, Candidate, CandidateDecision,
        CoreIdentity,
    };
    use std::path::PathBuf;

    fn app(pid: u32, creation_time_100ns: u64, session_id: u32) -> AppIdentity {
        AppIdentity {
            pid,
            creation_time_100ns,
            session_id,
            bridge_port: 59_750,
        }
    }

    fn core(path: &str, creation_time_100ns: u64) -> CoreIdentity {
        CoreIdentity {
            pid: 42,
            creation_time_100ns,
            canonical_path: PathBuf::from(path),
            run_token: super::RunToken::parse("0123456789abcdef0123456789abcdef")
                .expect("test token is valid"),
        }
    }

    #[test]
    fn candidate_policy_covers_exact_identity_conflict_and_legacy_safety() {
        let helper_core = r"C:\Program Files\dropweb\DropwebCore.exe";
        let sibling_core = r"D:\Portable\dropweb\DropwebCore.exe";
        let owner = app(100, 1_000, 7);
        let foreign = app(200, 2_000, 8);
        let exact_core = core(helper_core, 3_000);
        let cases = [
            (
                "exact retained identity may stop",
                Candidate::Retained {
                    expected: exact_core.clone(),
                    observed: exact_core.clone(),
                },
                CandidateDecision::Terminate,
            ),
            (
                "same pid with new creation time is refused",
                Candidate::Retained {
                    expected: exact_core.clone(),
                    observed: core(helper_core, 3_001),
                },
                CandidateDecision::Refuse,
            ),
            (
                "path mismatch is refused",
                Candidate::Retained {
                    expected: exact_core.clone(),
                    observed: core(sibling_core, 3_000),
                },
                CandidateDecision::Refuse,
            ),
            (
                "foreign live lease conflicts",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: foreign.clone(),
                    app_liveness: AppLiveness::Live,
                    core_is_exact: true,
                    bridge: BridgeState::ListeningByApp,
                },
                CandidateDecision::Conflict,
            ),
            (
                "same app may replace its child",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: owner.clone(),
                    app_liveness: AppLiveness::Live,
                    core_is_exact: true,
                    bridge: BridgeState::ListeningByApp,
                },
                CandidateDecision::Terminate,
            ),
            (
                "foreign dead lease with idle bridge may terminate",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: foreign.clone(),
                    app_liveness: AppLiveness::Dead,
                    core_is_exact: true,
                    bridge: BridgeState::NotListening,
                },
                CandidateDecision::Terminate,
            ),
            (
                "foreign dead lease with unknown bridge conflicts",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: foreign,
                    app_liveness: AppLiveness::Dead,
                    core_is_exact: true,
                    bridge: BridgeState::Unknown,
                },
                CandidateDecision::Conflict,
            ),
            (
                "unknown same-app liveness still conflicts",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: owner.clone(),
                    app_liveness: AppLiveness::Unknown,
                    core_is_exact: true,
                    bridge: BridgeState::NotListening,
                },
                CandidateDecision::Conflict,
            ),
            (
                "unknown app liveness with idle bridge conflicts",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: app(300, 3_000, 9),
                    app_liveness: AppLiveness::Unknown,
                    core_is_exact: true,
                    bridge: BridgeState::NotListening,
                },
                CandidateDecision::Conflict,
            ),
            (
                "unknown app liveness with listening bridge conflicts",
                Candidate::Leased {
                    requesting_app: owner.clone(),
                    leased_app: app(300, 3_000, 9),
                    app_liveness: AppLiveness::Unknown,
                    core_is_exact: true,
                    bridge: BridgeState::ListeningByApp,
                },
                CandidateDecision::Conflict,
            ),
            (
                "portable sibling is ignored",
                Candidate::Legacy {
                    observed_path: Some(PathBuf::from(sibling_core)),
                    expected_path: PathBuf::from(helper_core),
                    bridge: BridgeState::NotListening,
                },
                CandidateDecision::Ignore,
            ),
            (
                "exact legacy with dead bridge may terminate",
                Candidate::Legacy {
                    observed_path: Some(PathBuf::from(helper_core)),
                    expected_path: PathBuf::from(helper_core),
                    bridge: BridgeState::NotListening,
                },
                CandidateDecision::Terminate,
            ),
            (
                "legacy live bridge conflicts",
                Candidate::Legacy {
                    observed_path: Some(PathBuf::from(helper_core)),
                    expected_path: PathBuf::from(helper_core),
                    bridge: BridgeState::Unknown,
                },
                CandidateDecision::Conflict,
            ),
        ];

        for (name, candidate, expected) in cases {
            assert_eq!(evaluate_candidate(&candidate), expected, "{name}");
        }
    }
}
