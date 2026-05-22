/// Whether the Send to TV / LAN subscription-sharing entry points are
/// allowed in the UI.
///
/// Android is the Google Play target: the Send to TV flow posts the
/// subscription URL over plain local HTTP to an arbitrary
/// `add-profile` endpoint on another device on the LAN. It is not
/// essential for the Play v1 release and is hidden on Android to keep
/// the Play-facing surface free of LAN subscription-URL sharing.
/// Non-Android builds (iOS, desktop direct-distribution) keep the
/// existing user-explicit local sharing flow intact.
bool shouldShowSendToTv({required bool isAndroid}) => !isAndroid;
