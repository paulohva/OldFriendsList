# Changelog

All notable changes to Old Friends List are listed here.

## Unreleased

## 1.0.2

- **Login and logout lines for Battle.net friends** who aren't on your Old Friends List, when
  they log in or out of WoW Forever: the classic line with their character and, in Battle.net
  blue, their BattleTag (e.g. "[Sr Coxinha] Andre has come online."). Characters on your Old
  Friends List keep their usual line, never twice.
- Turn them on with the new option **Battle.net friends** under Notifications (off by default).
  It applies with Old Friends List in the Social window, or with Battle.net friends shown in the
  separate window. The Online messages, Offline messages and Login sound options apply to these
  lines too. The game's own Battle.net alert names only the account (and not on a character
  switch), which is why these lines name the character.
- **Battle.net friends playing in another region** now show in the separate window too (with
  "Other region" next to them) and get the login and logout lines. As with the other faction,
  only a Battle.net whisper reaches them: no invite, Who or adding them to your Old Friends List.
- **Battle.net friends on the other faction or in another region can't be added** to your Old
  Friends List by name either (typed, or right-clicking their name in chat): they stay
  Battle.net-only.
- **After a `/reload` or a quick relog**, friends keep the status they had a moment ago (up to
  10 minutes) instead of showing "Checking..." until checked again. That matters most in
  dungeons and raids, where the game doesn't let the addon check anyone.
- **Options, reorganised:** at the top, **Where to see Old Friends List** (a choice between the
  Social window and the separate window), then a section with the options for each: **Blizzard
  Social window** (hide friends already shown by Battle.net) and **Old Friends List window**
  (Battle.net friends, and the tab in the Social window, now called **Shortcut tab in the
  Blizzard Social window**). The first-time setup has its own section, near the end, before
  Advanced.
- **First-time setup in combat:** the Choose buttons wait for the end of the fight, with a line
  saying so (the game doesn't let key bindings change mid-fight, so a choice made then could
  leave the O / Shift-O keys as they were).

## 1.0.1

- **Fix:** opening the Social window (O) in combat, soon after logging in or a `/reload`, could
  leave Favorites and the friends list empty until the fight was over. The list now fits its
  friends straight away, in combat too.

## 1.0.0

- **One scroll bar in the Social window (O):** the Old Friends List group and the game's friends
  list now scroll together, with a single scroll bar in the game's own column. The group shows
  all your friends, with no scroll bar of its own.
- **Invite button on the Old Friends List cards** in the Social window, like the game's own:
  enabled when you can invite that friend right now. When you can't, its tooltip says why
  (offline, already in your group, only the leader can invite, group full).
- **"+" on the Old Friends List header** in the Social window: add a character without leaving
  that window. With an empty list the header still shows, so you can add the first one.
- **Battle.net friends:**
  - A character on your Old Friends List that a Battle.net friend is playing right now shows as
    online at once, with level, class and zone, even on the other faction.
  - New option, off by default: **Hide friends already shown by Battle.net**. In the Social
    window, such a character then shows only on the game's card, not twice.
  - New option, off by default: **Show Battle.net friends playing WoW**. The separate window
    also lists your Battle.net friends who are playing now. On your faction: whisper, invite,
    Who and add to Old Friends List. On the other faction: a Battle.net whisper.
  - Both options are in the first-time setup and in the options.
- The separate window's **Invite** button follows the same rules as the cards.
- **Key Bindings:** Old Friends List has its own group in the game's Key Bindings, instead of
  being under AddOns.
- **Always "Old Friends List":** menus, options and messages now use the full name, e.g.
  right-click a player → **Add to Old Friends List**.
- **First-time setup:** both buttons say **Choose**; the green line marks your current choice.
- **Minimap button:** the right-click menu has just Open the list, Options and Hide minimap
  button. Everything else is in the options.
- If the game ever blocks an action and blames Old Friends List, it now says so in chat once,
  and `/ofl diag` lists it, to make reporting easier.

## 0.3.9

- Friends in your guild: with the game's Guild member alert on, the game plays its own sound
  when they log in, so Old Friends List no longer plays its login sound for them either. One
  line and one sound, both from the game.

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
