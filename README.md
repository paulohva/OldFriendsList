# Old Friends List

**The classic friends list, back in World of Warcraft: Forever.**

Forever's friends system is account-based only: you add people, not characters. Old Friends List
brings back the old way. Add the *characters* you meet, see at a glance who's online, whisper or
invite them with a click, and get the familiar yellow line in chat when one of them logs in:

> **[Thrall]** has come online.

It works with any character, whether or not they use the addon.

---

## Features

- **A list of characters.** Add them by name, or right-click a player and choose
  **Add to Old Friends**. This works on target and focus portraits, party and raid frames, names
  in chat and the guild roster.
- **Online status at a glance.** Each friend shows as online or offline, with level, class and
  zone, and a "last seen" time for people who are offline.
- **One-click actions.** Double-click a friend to whisper them. Use the buttons or the right-click
  menu to **Invite**, **Who**, **Set Note** or **Remove**.
- **Login and logout notifications.** A chat line and a sound when a friend comes online, a chat
  line when they go offline, and one summary line after you log in.
- **Notes.** Keep a short note on each friend ("great tank, met in Gnomeregan").
- **Better with friends.** Friends who also run Old Friends List show up instantly and share
  their level, class and zone.
- **Minimap button.** Hover it to see who's online, click it to open the list, right-click it for
  quick settings, and drag it anywhere around the minimap.
- **Keyboard shortcut.** Press **Shift-O** to open the list. You can change it in
  *Options → AddOns → Old Friends List*.
- **Options panel.** Level and zone in the list, class colors, notifications, sound, zone
  sharing, check interval, minimap button and the key binding, all in
  *Options → AddOns → Old Friends List*.
- **Blizzard look and feel.** A native-style window that closes with Escape. You can also open it
  from the addon compartment, or a button under the Friends window.

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

Press **Shift-O**, or type `/ofl` (or `/oldfriends`), to open the list.

**Shift-O** is set for you the first time you log in, but only if that key isn't already used for
something else. To pick another key, open *Options → AddOns → Old Friends List* (or type
`/ofl config`) and click the key binding. The same panel has all the other settings.

| Command | What it does |
|---|---|
| `/ofl` | Open or close the list |
| `/ofl add <first last>` | Add a character by first and last name, e.g. `/ofl add Asha Brightvale` |
| `/ofl remove <first last>` | Remove a character |
| `/ofl note <first last> <text>` | Set a note; leave the text out to clear it |
| `/ofl list` | Print your list in chat |
| `/ofl config` | Open the options panel (settings and key binding) |
| `/ofl status` | Print your settings in chat |
| `/ofl online on\|off` | Turn "has come online" messages on or off |
| `/ofl offline on\|off` | Turn "has gone offline" messages on or off |
| `/ofl sound on\|off` | Turn the login sound on or off |
| `/ofl zone on\|off` | Turn sharing your zone with friends who use the addon on or off |
| `/ofl interval <seconds>` | Set how often each friend is checked (15–300, default 30) |
| `/ofl minimap` | Show or hide the minimap button |
| `/ofl ping <first last>` | Check one character right now and print the result |
| `/ofl diag` | Show which game features this client supports (handy for bug reports) |
| `/ofl debug` | Turn debug messages on or off |
| `/ofl help` | Show the everyday commands in chat |
| `/ofl advanced` | Show every command in chat |

## How it works

WoW: Forever has no character friends list. Addons also can't send `/who` on their own: the game
only allows `/who` when you click. So Old Friends List checks your friends differently:

1. **Silent check.** Every so often the addon sends each friend a tiny invisible addon message.
   - If the friend is offline, the server replies *"No player named … is currently playing."*
     The addon hides that reply and marks the friend offline.
   - If no reply comes within a few seconds, the friend is online.
2. **Handshake.** If your friend also runs Old Friends List, their addon answers straight away
   with their level, class and zone. When they log in, their addon checks on you right away, so
   you're notified within seconds.
3. **What you see.** Chatting with a friend, grouping with them or targeting them also updates
   their status.
4. **Who.** Right-click a friend and choose **Who** for a fresh `/who` on them.

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
list, and you can turn that off with `/ofl zone off`. Everything else stays in your local saved
variables.

## Contributing

Bug reports, ideas and pull requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) to get
started. When reporting a bug, please include the output of `/ofl diag` and any Lua error text.

## Credits

Old Friends List was developed with the help of AI tools.

## License

[MIT](LICENSE). You're free to use, modify and share this addon. Please keep the copyright notice.
