## 2025-02-28 - Missing Server-Side Validation on Network Events
**Vulnerability:** The `qbx_parkingbrake:server:toggle` network event lacked validation for the vehicle class, relying entirely on the client to check `Config.ExcludedClasses`.
**Learning:** In multiplayer game development (FiveM), clients cannot be trusted. Malicious actors can spoof network events to bypass client-side checks and modify server state for unsupported entities (like applying a parking brake to a helicopter).
**Prevention:** Always implement server-side validation mirroring or enforcing the constraints defined in configuration files for any action that mutates global state (`Entity().state`).
