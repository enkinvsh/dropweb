/// How far along anything in meowzic is that has to be fetched.
///
/// One enum for the search results, the library grid and an opened container.
/// There used to be three — `MeowzicPhase`, `SpotifyLibraryPhase`,
/// `SpotifyDetailPhase` — with identical members, which is how a screen ends up
/// answering the same question differently from its neighbour: a fix to one
/// `switch` leaves the other two alone, and nothing tells you they existed.
///
/// It is deliberately NOT the place for `SpotifyPhase`. Sign-in has four states
/// too, but they are `signedOut, working, signedIn, failed` — "signed out" is
/// not "idle" and never becomes "done" — and folding a genuinely different
/// lifecycle in here to save an enum would be the opposite of this.
enum MeowzicPhase { idle, loading, done, failed }
