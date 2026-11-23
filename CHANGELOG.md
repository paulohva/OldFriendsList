# Changelog

All notable changes to Old Friends List are listed here.

## Unreleased

## 1.2.6

- **Fix:** with a controller, moving the cursor in the Social window (O) could show "Interface
  action failed because of an AddOn" and stop at the Old Friends List group. With the game's
  controller interface on, Blizzard's list now stays in its own scroll, and the controller's
  cursor moves through the Old Friends List cards too: select a friend, or open their menu to
  whisper or invite. In the separate window the cursor skips the list and goes to the buttons.
  With mouse and keyboard nothing changes.
- `/ofl diag` is easier to read: the setup (where your list is shown, controller interface on or
  off), status sources and missing game APIs, and the problems last. It also counts the game's
  "action failed" messages (and where they came from) and this addon's script errors.
- New `/ofl errors`, for bug reports: turns on the game's taint log and its Lua errors on screen
  (typed again, turns them off and puts Lua errors back as they were). It stays on at each login
  until turned off, and says so once in chat.

## 1.2.5

- **Fix:** in the separate window, the Whisper button didn't sink when clicked. It now presses
  down like the other buttons.

## 1.2.4

- **Fix:** in the separate window, with a friend selected, the Remove, Invite and Add buttons
  didn't take clicks: an invisible part of the Whisper button ran over them. It now covers just
  the Whisper button.
- **Fix:** in the separate window, the Whisper button's highlight blinked while the mouse moved
  over it, and could stay lit after moving on to the next button. It now lights up and goes out
  like the other buttons.

## 1.2.3

- **Fix:** moving the mouse straight onto a card's Invite button (from the right) sometimes showed
  the card's tooltip instead of the button's, and the button's could then stay on the card.
- **Fix:** a friend's tooltip could take a moment to show, right after the mouse came from a
  player or creature in the world (whose tooltip was still fading). It shows at once now.
- Offline friends read like Blizzard's cards: "Last online 3 hours ago" (in the game's own words,
  in any language) on the card and in its tooltip, instead of "Offline, last seen 3 hours ago".
- Friend tooltips without the "Double-click to whisper" line, like Blizzard's. It stays only
  where the whisper goes through Battle.net (other faction, realm type or region).

## 1.2.2

- **Fix:** after the mouse went over a card's Invite button and back onto the card, the card's
  tooltip didn't come back. It does now.

## 1.2.1

- **Fix:** "Interface action failed because of an AddOn" (or "OldFriendsList has been blocked
  from an action") could still show up in combat: opening the separate window for the first
  time, or the first click on a friend, used something the game forbids mid-fight. Gone.
- Opening the Social window shows the Old Friends List group up to date at once (it showed its
  old state for a split second).
- Shorter friend tooltips: online, the zone; offline, just "Offline" (the card already says when
  they were last seen). And the tooltip goes away as soon as the window closes (Esc or the key),
  like on Blizzard's cards.

## 1.2.0

- **Fix:** "Interface action failed because of an AddOn" (or "OldFriendsList has been blocked
  from an action") could show up after adding, removing or noting a friend, for instance later
  when releasing your spirit or answering a group invite. The Add, Note and Remove dialogs used
  the game's shared dialog boxes, which the game reuses for those; Old Friends List now has its
  own, with the same look.
- **Lighter:** the friend checks every few seconds no longer rebuild the list each time, and a
  Battle.net friend's change now reads only that friend instead of all of them (that read was
  the addon's most expensive one). With the Social window or the separate window open, the
  mouse-over highlight is checked 20 times a second instead of every frame. Old Friends List was
  already light; now it's lighter.

## 1.1.4

- In the Social window, only one card is selected at a time: selecting an Old Friends List card
  clears the selection on Blizzard's cards (Favorites, friends), and selecting one of those
  clears ours.
- Closing the Social window or the separate window clears the selection of Old Friends List
  friends.

## 1.1.3

- With the mouse on an Old Friends List card in the Social window, its online/offline dot keeps
  its colour, like on Blizzard's cards (the card's highlight used to wash it out).

## 1.1.2

- The online/offline dot on Old Friends List cards in the Social window now matches Blizzard's
  exactly: same size and place, and it grows with the game's text size like theirs.

## 1.1.1

- **Fix:** after whispering a friend from Old Friends List, whispering someone from the game's
  own Social window cards could show "OldFriendsList has been blocked from an action" and leave
  Favorites and the friends list empty until a `/reload`. Whispers from Old Friends List are now
  opened by the game itself, so this can't happen anymore.
- Double-click a friend (Social window or separate window) or use the **Whisper** button: the
  whisper opens straight away, as before. In the Social window, a single click now selects the
  card, like Blizzard's.
- **Whisper** in the right-click menu writes a line in chat with the friend's name to click
  (the menu can't open it directly without the same problem).
- The highlight on Old Friends List cards and rows follows the mouse properly (only one at a
  time, no flicker).

## 1.1.0

- **Old Friends List names in the mail:** when you type a name in the mail's To: field, the
  game's suggestions now include the friends on your Old Friends List too (online first), after
  the game's own. Pick one with Tab, Enter or a click, as always. Only friends you can mail are
  suggested (your faction and realm type). Turn it off in the options (**Names in the mail**,
  under List). Thanks to nvrtv on CurseForge for the idea.

## 1.0.3

- **Realm types:** characters on another realm type (PvP, PvE, RP, RP-PvP) can't be whispered
  by name or invited, so Old Friends List now treats them like the other faction. Battle.net
  friends playing there show in the separate window with the realm type next to them (e.g.
  "(PvE)"), for a Battle.net whisper only, and they can't be added to your Old Friends List.
- Your Old Friends List shows the friends of your character's realm type (and faction), so each
  character sees the friends it can play with. Friends added before this version show
  everywhere until the addon learns their realm type (through Battle.net or a target).
- **Add a Battle.net friend's character from the Social window:** right-click a Battle.net
  friend (in Favorites or the list) for **Add [character] to Old Friends List**, when they're
  playing a character you can group with. Already on your list: **Remove** instead.
- **Statuses may be out of date:** in a dungeon, raid or battleground the game doesn't let the
  addon check anyone. A small clock now shows it, next to the online count in the separate
  window and on the Old Friends List group in the Social window (its tooltip says why).
- The first-time setup's picture of the Social window shows its current look.

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
