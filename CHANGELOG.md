# Changelog

All notable changes to Old Friends List are listed here.

## Unreleased

## 0.2.0

- **Keyboard shortcut**: press **Shift-O** to open the list. It's set for you on first login,
  only if Shift-O isn't already used for something else.
- **Options panel** in *Options → AddOns → Old Friends List*: change the key binding, and turn
  notifications, sound, zone sharing, the check interval and the minimap button on or off.
- A small gear in the list window's top-right corner opens the options panel.
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
