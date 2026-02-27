# Sentinel Journal

## 2024-05-22 - Missing Server-Side Validation
**Vulnerability:** Client-side checks for excluded vehicle classes were not replicated on the server.
**Learning:** Relying solely on client-side checks allows malicious clients to bypass restrictions (e.g. enabling features on unsupported vehicles).
**Prevention:** Always validate critical business logic (like vehicle class restrictions) on the server side, even if checked on the client.
