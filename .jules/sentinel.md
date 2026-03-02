## 2024-05-27 - Security Callback & Server-Side Validation

**Vulnerability:** The client-side parking brake toggle triggered a raw network event (`TriggerServerEvent('qbx_parkingbrake:server:toggle')`). While the client checked conditions (like vehicle speed, disable status, or excluded classes), a malicious actor could bypass these checks and send the event directly. The server-side was only checking if the player was the driver and cooldowns, allowing unauthorized toggling of the parking brake on vehicles they shouldn't be able to (e.g. while driving fast or on excluded vehicles like helicopters).

**Learning:** When client-side actions trigger network events, always assume the client cannot be trusted. In FiveM, converting raw network events into secure callbacks (e.g., using `lib.callback.register` and `lib.callback.await`) adds a layer of security by requiring a return value and making it slightly harder to blindly trigger events. However, the most critical learning is that ALL validation checks performed on the client (like `GetVehicleClass`, `isVehicleDisabled`, `GetEntitySpeed`, `IsPedDeadOrDying`) MUST be explicitly replicated and enforced on the server-side callback to prevent exploit bypassing.

**Prevention:**
1. Avoid `TriggerServerEvent` / `RegisterNetEvent` for sensitive state changes; use callbacks.
2. Replicate all client-side condition checks on the server within the callback handler.
3. Use defensive, safe-check patterns for natives (e.g., `GetEntitySubmergedLevel and GetEntitySubmergedLevel(veh) >= Config.WaterThreshold or false`) in server-side validation, as some natives may behave differently or be absent on the server build.
