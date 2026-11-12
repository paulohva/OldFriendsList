# Contributing to Old Friends List

Thanks for helping out! Bug reports, ideas and pull requests are all welcome.

## Reporting a bug

Open an issue and include:

- what you did, what you expected, and what happened instead;
- the output of `/ofl diag`;
- the full Lua error text, if there was one ([BugSack](https://www.curseforge.com/wow/addons/bugsack) makes this easy);
- your game version (shown by `/ofl diag`).

## Development setup

1. Clone the repository anywhere you like.
2. Link the folder into the game, so `/reload` picks up your changes. From an elevated Command Prompt:

   ```bat
   mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\OldFriendsList" "C:\path\to\your\clone"
   ```

   On macOS, use `ln -s` into `/Applications/World of Warcraft/_forever_/Interface/AddOns/`.

3. Log in, make changes, and type `/reload`. `/ofl debug` prints what the addon is doing.

## Code layout

| File | Purpose |
|---|---|
| `Core.lua` | Namespace, secret-safe helpers, event dispatcher, saved variables |
| `Data.lua` | Name normalization, the friends list, online status |
| `Notify.lua` | Chat notifications and sound |
| `Comm.lua` | Addon messages between players (`PING` / `PONG`) |
| `Presence.lua` | The check scheduler, the hidden "No player named" filter, passive signals, `/who` |
| `Menus.lua` | Right-click menu entries |
| `UI/` | The main window (`MainFrame.lua`) and its row template (`Row.xml`) |
| `Slash.lua` | `/ofl` commands |

## Guidelines

- **Indentation:** use tabs in Lua and XML, matching the existing code.
- **Language:** everything the player sees is in English.
- **Secret values:** WoW: Forever restricts addons the same way as Midnight. Game values can be
  *secret*, and addon messages are blocked in combat and in instances. Read game values through
  `ns.Safe` (`Safe.Value`, `Safe.Call`), and never assume an addon message went out.
- **Taint:** don't hook or modify Blizzard frames when a menu entry or a separate frame would do.
- **One change per pull request**, with a short description of what it does and how you tested it
  in game.
- **Changelog:** add a line under *Unreleased* in `CHANGELOG.md`.

## Releasing (maintainers)

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) on GitHub
Actions.

1. Move the *Unreleased* changelog entries under a new version heading.
2. Push a version tag, for example `git tag v0.2.0 && git push origin v0.2.0`.

The workflow builds the zip, creates a GitHub release and uploads it to CurseForge. This needs the
`CF_API_KEY` repository secret, and the CurseForge project ID in the `.toc` (`## X-Curse-Project-ID`).

By contributing, you agree that your contributions are licensed under the project's
[MIT License](LICENSE).
