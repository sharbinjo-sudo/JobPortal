/// IO (mobile/desktop) stub for the localStorage token fallback. Native
/// platforms use the secure storage layer directly; these no-op functions are
/// only referenced if the secure layer fails, in which case the in-memory
/// cache keeps the session alive for the current app run.
library;

String? readToken(String key) => null;
void writeToken(String key, String value) {}
void removeToken(String key) {}
