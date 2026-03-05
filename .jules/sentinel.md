## 2024-05-24 - Missing server-side validation and insecure network event
**Vulnerability:** The `qbx_parkingbrake:server:toggle` event in `server/main.lua` was an insecure network event (`RegisterNetEvent`) without any server-side validation of the player's health, vehicle class, speed, or disabled state.
**Learning:** Client-side validation is insufficient to prevent exploiters from bypassing checks. Always mirror client-side validation on the server-side to ensure security.
**Prevention:** Use `lib.callback.register` for sensitive requests and always perform server-side validation using safe native checks to prevent exploiters from bypassing client-side validation.
