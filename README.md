# C8N_DeptStatus

A standalone FiveM resource providing a professional on-duty system for emergency-service roleplay. It gives on-duty members real-time minimap visibility of one another, hides that information from civilians and off-duty personnel, supports multiple departments, and gates access through Discord roles with webhook logging.

## Features

- Toggleable `/duty` on/off command (per department)
- Department-based blip visibility (only visible to others on duty in the same department)
- Multiple departments/roles (LSPD, BCSO, SAHP, Fire/EMS, SANG — fully configurable)
- Discord role-based permissions (direct Discord REST lookup, no extra dependencies)
- Webhook logging for clock-in / clock-out with total shift time
- `/cops` (configurable) active-unit list with department tag and time on duty
- Fully customizable role IDs, blip sprites/colors, per-department webhooks, locale strings
- Admin bypass via ACE permission (`deptstatus.admin`)
- `exports.IsOnDuty(src)` / `exports.GetDuty(src)` for integration with other resources

## Install

1. Drop the `C8N_DeptStatus` folder into your `resources/` directory.
2. Install **one** of the supported permission backends:
   - [DiscordAcePerms](https://github.com/Stuyk/discord-ace-perms) (or any resource that maps Discord roles to ACE groups), **or**
   - [badger_discord_api](https://github.com/AndyBCS/badger_discord_api)
3. Set `Config.PermissionBackend` in `config.lua` to `'discordaceperms'` or `'badgerdiscordapi'`.
4. Add to `server.cfg`:
   ```
   ensure <your chosen permission resource>
   ensure C8N_DeptStatus

   # Optional admin bypass:
   add_ace group.admin deptstatus.admin allow
   ```
5. For `discordaceperms`, grant the ACE perms configured per department (e.g. `add_ace group.lspd deptstatus.lspd allow`) via whatever mechanism the backend uses to map Discord roles to ACE groups.
6. For `badgerdiscordapi`, fill each department's `discordRoles` with the Discord role IDs that should grant access.

## Configure

Edit `config.lua`:

- `Config.OnDutyCommand` / `Config.OffDutyCommand` — command names. Set them to the same value (e.g. both `'duty'`) to use a single toggle command instead of two separate commands.
- `Config.RosterCommand` — command name for the roster list.
- `Config.PermissionBackend` — `'discordaceperms'` or `'badgerdiscordapi'`.
- `Config.Departments` — add/remove departments. Each needs:
  - `acePerms`: list of ACE permission strings (used by `discordaceperms` backend).
  - `discordRoles`: list of Discord role IDs as strings (used by `badgerdiscordapi` backend).
  - `blip`: sprite, color, scale, display, shortRange.
  - `webhook`: optional per-dept webhook URL (falls back to `Config.DefaultWebhook`).
- `Config.AllowMultiDept` — allow being on duty for multiple departments at once.
- `Config.Messages` — localize all user-facing strings.

## Commands

By default:

| Command | Description |
|---|---|
| `/onduty <deptId>` | Goes on duty for the given department (if you have permission). With no args, prints the list of department IDs. |
| `/offduty` | Goes off duty. |
| `/cops` | Lists all on-duty personnel with department tag, name, server ID, and shift time. Restricted to on-duty players and admins. |

If you set `Config.OnDutyCommand = 'duty'` and `Config.OffDutyCommand = 'duty'`, the single `/duty` command toggles: `/duty <deptId>` goes on duty, `/duty` (no args) while on duty goes off duty.

## How permissions work

When a player runs the on-duty command for a department, the server checks the configured backend:

- **`discordaceperms`**: Tests each string in the department's `acePerms` with `IsPlayerAceAllowed`. If any matches, access is granted.
- **`badgerdiscordapi`**: Calls `exports.badger_discord_api:UserHasRole(src, roleId)` for each ID in the department's `discordRoles`. If any matches, access is granted.

Players with the `deptstatus.admin` ACE permission skip the backend check entirely.

## How blips work

- Blips are created **client-side** and only for players who are themselves on duty.
- Only other roster members **in the same department** are drawn.
- The server syncs a minimal roster (`serverId → dept`) to all clients; off-duty clients discard it and draw nothing, so civilians never see department positions.
- Blips are attached to the player entity and move with them. Refresh cadence is controlled by `Config.BlipUpdateRate`.

## Webhook payload

Each on/off duty event sends a Discord embed containing: player name + server ID, Discord mention, department, and (on clock-out) total shift duration.

## Exports

```lua
-- server-side
local onDuty = exports.C8N_DeptStatus:IsOnDuty(src)   -- boolean
local info   = exports.C8N_DeptStatus:GetDuty(src)    -- { dept = 'lspd', startedAt = 1713600000 } or nil
```

## License

See [LICENSE](LICENSE).

