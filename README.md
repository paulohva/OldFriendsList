# Old Friends List

**The classic friends list, back in World of Warcraft: Forever.**

Forever's friends system is account-based only: you add people, not characters. Old Friends List
brings back the old way. Add the *characters* you meet, see at a glance who's online, whisper or
invite them with a click, and get the familiar yellow line in chat when one of them logs in:

> **[Asha Brightvale]** has come online.

It works with any character, whether or not they use the addon.

---

## Features

- **A list of characters.** Add them by name, or right-click a player and choose
  **Add to Old Friends**: on portraits, party and raid frames, names in chat and the guild roster.
- **Online status at a glance.** Level, class and zone for each friend, and "last seen" with the
  last known level and class for friends who are offline.
- **One-click actions.** Double-click a friend to whisper them; use the buttons or the right-click
  menu to **Invite**, **Who**, **Set Note** or **Remove**.
- **Login and logout notifications.** A chat line and a sound when a friend comes online, a line
  when they go offline, and one summary line after you log in.
- **Shortcut and options.** **Shift-O** opens the list. The gear in the window (or `/ofl config`)
  opens the options: level and zone in the list, class colors, notifications, minimap button and
  the key binding.
- **Minimap button.** Hover it to see who's online; click to open the list, right-click for quick
  settings. Optionally, a tab in the game's Social window (O) opens it too.
- **Better with friends.** Friends who also run Old Friends List show up instantly and share
  their level, class and zone.

## Languages

Old Friends List follows your game client's language. It includes **English** and
**Português (Brasil)**; other languages fall back to English, except for the texts the game
already translates (buttons like Whisper and Invite, "Level 23 Warrior", the "has come online"
message), which always match your client. Translations are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Installation

- **CurseForge:** install *Old Friends List* with the CurseForge app.
- **Manual:**
  1. Download the latest release zip.
  2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`. You should end up with
     `...\AddOns\OldFriendsList\OldFriendsList.toc`.
  3. Restart the game, or type `/reload` if you're already logged in.

## Usage

Press **Shift-O** or type `/ofl` to open the list. Shift-O is set on your first login if that key
is free; change it in the options.

| Command | What it does |
|---|---|
| `/ofl` | Open or close the list |
| `/ofl add <first last>` | Add a character, e.g. `/ofl add Asha Brightvale` |
| `/ofl remove <first last>` | Remove a character |
| `/ofl note <first last> <text>` | Set a note; leave the text out to clear it |
| `/ofl list` | Print your list in chat |
| `/ofl config` | Open the options (settings and key binding) |
| `/ofl minimap` | Show or hide the minimap button |

Type `/ofl advanced` in game for every command (notification toggles, check interval, `diag`,
`debug`...).

## How it works

WoW: Forever has no character friends list, and addons can only send `/who` when you click. So
Old Friends List checks your friends another way:

1. **Silent check.** The addon sends each friend a tiny invisible message every so often. If
   they're offline, the server says so; the addon hides that reply and marks them offline. No
   reply means they're online.
2. **Handshake.** Friends who also run the addon answer straight away, and their addon tells
   yours when they log in.
3. **What you see.** Chatting, grouping with or targeting a friend also updates their status.
4. **Who.** Right-click a friend and choose **Who** for a fresh `/who` on them.

Level, class and zone come from your group, your target, a friend's addon or **Who**, and are
remembered.

### Limitations

- **Same faction.** You can only reach characters of your own faction, the same limit as whispers
  and invites. Your list is shared across your account, and each character only sees the friends
  of its own faction.
- **Paused in combat and instances.** Checks pause there, because the game blocks addon messages.
  Statuses shown meanwhile are the last ones known.
- **A short delay.** A friend who doesn't use the addon shows as online within about a minute of
  logging in, depending on how many friends you have and the check interval.

### Privacy

The only data the addon sends is the invisible check message and, between two players who both
use the addon, their class, level and zone. Your zone is sent only to people who are on *your*
list, and you can turn that off in the options. Everything else stays in your local saved
variables.

## Contributing

Bug reports, ideas and pull requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) to get
started. When reporting a bug, please include the output of `/ofl diag` and any Lua error text.

## Credits

Old Friends List was developed with the help of AI tools.

## License

[MIT](LICENSE). You're free to use, modify and share this addon. Please keep the copyright notice.
