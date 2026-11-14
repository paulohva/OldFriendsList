# Changelog

All notable changes to Old Friends List are listed here.

## Unreleased

## 0.3.0

- **Old Friends in the Social window (O):** optionally, your Old Friends appear as a group
  "Old Friends List x/y" above Favorites in the game's friends window, collapsible like the
  others, with level, class, zone and the same right-click menu. Shift-O still opens the
  separate window. If a game update changes that window, the addon falls back to its own window.
- **First-time setup:** on the first login you choose between the Social window and a separate
  window, with a picture of each. The separate window can take **O** (the Social window moves
  to Shift-O). Run it again with `/ofl setup` or from the options.
- **Options:** both keys (Old Friends List and the game's Social window) in the Key Binding
  section; new **Social window** section with the mode, the key swap and the tab.
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
