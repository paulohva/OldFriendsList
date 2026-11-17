# Changelog

All notable changes to Old Friends List are listed here.

## Unreleased

## 0.3.7

- No more double "has come online" / "has gone offline" lines for friends in your guild. With
  the game's Guild member alert on (Options > Social), the game already prints those lines for
  guild members, so Old Friends List leaves them to it. The login sound still plays, so you know
  it's someone from your list. `/ofl diag` shows whether the alert is on.
- Fixed the "Old Friends List tried to perform an action that was blocked" error when typing in
  the Options search box. The Key Binding section of the addon's options is now a button that
  opens the game's Key Bindings, where Old Friends List is listed under AddOns.

## 0.3.6

- Smaller download and install: the first-time setup pictures are stored at 75% of their size
  and without the unused parts (the addon goes from about 2.4 MB to about 1.1 MB installed).

## 0.3.5

- Social window: when the Old Friends List group has more friends than fit and scrolls, its
  scroll bar now sits in the same column as the game's own scroll bar, to the right of the
  cards, instead of over the cards' edge; the cards keep their full width.
- First-time setup: the two pictures are now real screenshots of each choice (your Old Friends
  in the Social window, and the separate window), instead of drawings, and they're bigger. The
  window keeps its size: the lines at the bottom ("Closing keeps everything as it is", "Change it
  anytime in Options…") are gone to make room.

## 0.3.4

- New icon, matching the new logo: on the minimap button, the Social window tab, the addon list
  and the addon compartment.

## 0.3.3

- New portrait artwork for the Old Friends List window and the first-time setup.

## 0.3.2

- No more summary line on every login ("Old Friends List: 1 friend online: ..."). Friends who
  log in or out after you still get their "has come online" / "has gone offline" line.
- Social window: the space between the "Old Friends List" header and its first friend now
  matches Blizzard's Favorites, and the cards line up with Blizzard's.

## 0.3.1

- First-time setup, clearer:
  - the question is now "How would you like to see your friends?";
  - "Closing keeps everything as it is" only shows when there's something to keep (players
    updating from an older version, or running the setup again), not on a new install;
  - the Social window option no longer says the Old Friends are shown first;
  - the separate window's checkbox now says it's O that opens this window, and the game's
    friends window moves to Shift-O.

## 0.3.0

- **Old Friends in the Social window (O):** optionally, your Old Friends appear as a group
  "Old Friends List x/y" above Favorites in the game's friends window, collapsible like the
  others, with level, class, zone and the same right-click menu. Shift-O still opens the
  separate window. If a game update changes that window, the addon falls back to its own window.
- **Nothing changes unless you choose it.** If you already use Old Friends List, your separate
  window, keys and settings stay exactly as they are: the first-time setup shows the new option
  and a **Keep as it is** button, and closing it keeps everything too.
- **First-time setup:** on the first login you choose between the Social window and a separate
  window, with a picture of each. The separate window can take **O** (the Social window moves
  to Shift-O). Run it again with `/ofl setup` or from the options.
- **Options, reorganised:** General, Social window (the mode, the tab, run the setup again),
  List, Notifications, Key Binding (both keys: Old Friends List and the game's Social window,
  to compare and change) and Advanced (the check interval).
- The Social window tab is hidden when your Old Friends are already in that window.

## 0.2.1

- Friends in your group now show their **zone** without a **Who**, and it follows them as they
  move. Friends you target or mouse over show your current zone (they're right next to you).
- **Faster "has gone offline"** with long lists: friends who are online are checked first, so a
  logout is noticed within the check interval; offline friends use the time that's left.

## 0.2.0

- **Keyboard shortcut**: press **Shift-O** to open the list. It's set for you on first login,
  only if Shift-O isn't already used for something else.
- **Options panel** in *Options → AddOns → Old Friends List*: change the key binding, and turn
  notifications, sound, zone sharing, the check interval and the minimap button on or off.
- A small gear in the list window's top-right corner opens the options panel.
- The big "Old Friends" button under the Social window is replaced by an optional **tab** under
  the side tabs of Forever's Social window (O), styled like them. It's off by default; turn on
  "Show in the Social window" in the options.
- `/ofl config` now opens the options panel; `/ofl status` prints your settings in chat.
- `/ofl help` shows only the everyday commands; `/ofl advanced` shows them all.
- The login summary now reads "Old Friends List: 2 friends online: [A], [B]".
- "[Name] has gone offline." is now on by default (also when updating from 0.1.0). Turn it off
  in the options panel or with `/ofl offline off`.
- The list shows each friend's level and class also while they're offline (the last known), like
  the classic list.
- New **List** options: **Show level and zone** (on by default; off shows only names, in a more
  compact list) and **Class colors** (off by default; names in their class color in the list,
  tooltips and chat).
- Level and class are picked up more reliably from your group, target and mouseover, and a
  friend's level updates when they level up in your group.
- **Fix:** the window couldn't be closed with its X button during combat.
- **Fix:** **Who** on a friend didn't update their level, class and zone when the game showed the
  answer in chat (which it does for small results). It now reads that line, in any language.
- **Languages:** the addon follows the game client's language. English and Portuguese (Brazil)
  are included; texts the game already translates (Whisper, Invite, "Level 23 Warrior", the
  classic "[Name] has come online.") come straight from the game.
- The options panel can't open in combat; the gear and `/ofl config` now say so instead of
  doing nothing.
- The minimap button's right-click menu has a shortcut to the options panel, and its tooltip
  is shorter (just left-click and right-click).

## 0.1.0

First release.

- Character-based friends list: add by name, or right-click a player and choose
  **Add to Old Friends**. Works on target, focus, party, raid, chat names and the guild roster.
- Online status with level, class, zone and "last seen".
- Whisper (double-click), Invite, Who, Set Note and Remove.
- "[Name] has come online." chat notification and sound, plus a summary after you log in.
- Instant status and shared details between players who both use the addon.
- Supports Forever's two-part character names (e.g. "Asha Brightvale").
- Minimap button with an online tooltip, quick settings and drag to move.
- `/ofl` commands, key binding, addon compartment entry and a button under the Friends window.
