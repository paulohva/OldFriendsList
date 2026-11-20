--------------------------------------------------------------------------------
-- Translations. The addon follows the game client's language:
--  * ns.G("GLOBAL", "English") uses Blizzard's own, already translated text
--    (WHISPER, INVITE, FRIENDS_LEVEL_TEMPLATE, ERR_FRIEND_ONLINE_SS, ...);
--  * ns.L["English text"] is the addon's own text: translated below, English otherwise.
-- To add a language, copy the ptBR block and change the locale code.
--------------------------------------------------------------------------------

local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- Blizzard's translated string, or the English fallback
function ns.G(name, fallback)
	local value = _G[name]
	if type(value) == "string" and value ~= "" then return value end
	return fallback
end

local locale = GetLocale and GetLocale() or "enUS"

if locale == "ptBR" then
	-- list window
	L["Add Friend"] = "Adicionar"
	L["Added %s."] = "%s foi adicionado à lista."
	L["Removed %s."] = "%s foi removido da lista."
	L["Enter the first and last name of the character you want to add:"] = "Digite o nome e o sobrenome do personagem que deseja adicionar:"
	L["Set a note for %s:"] = "Definir uma nota para %s:"
	L["Remove %s from your Old Friends List?"] = "Remover %s da sua Old Friends List?"
	L["Level %d"] = "Nível %d"
	L["Online"] = "Online"
	L["Offline"] = "Offline"
	L["Checking..."] = "Verificando..."
	L["Last online %s"] = "Online pela última vez %s"
	L["Online: |cffffffff%d|r / %d"] = "Online: |cffffffff%d|r / %d"
	L["checks paused: %s"] = "verificação pausada: %s"
	L["in combat"] = "em combate"
	L["in an instance"] = "em uma instância"
	L["trial account"] = "conta de avaliação"
	L["no API"] = "API indisponível"
	L["Notifications, key binding (%s) and more."] = "Notificações, atalho (%s) e mais."
	L["Notifications, key binding and more."] = "Notificações, atalho e mais."
	L["The options panel isn't available; type /ofl help."] = "O painel de opções não está disponível; digite /ofl help."
	L["No friends yet.\n\nClick |cffffd100%s|r, or right-click a player's portrait or name and choose |cffffd100%s|r."] =
		"Nenhum amigo ainda.\n\nClique em |cffffd100%s|r, ou clique com o botão direito no retrato ou no nome de um jogador e escolha |cffffd100%s|r."
	L["%d of %d online"] = "%d de %d online"
	L["Click to open."] = "Clique para abrir."
	L["Your list of characters, the classic way."] = "Sua lista de personagens, do jeito clássico."
	L["Toggle Old Friends List"] = "Abrir/fechar a Old Friends List"

	-- adding friends
	L["That's not a valid character name. Use the first and last name, e.g. Asha Brightvale."] =
		"Esse não é um nome de personagem válido. Use o nome e o sobrenome, por exemplo: Asha Brightvale."
	L["You can't add yourself."] = "Você não pode adicionar a si mesmo."
	L["%s is already on your list."] = "%s já está na sua lista."
	L["%s is on the other faction: you can't whisper or invite them."] = "%s é da outra facção: não é possível sussurrar nem convidar."

	-- "last seen" times
	L["just now"] = "agora mesmo"
	L["1 minute ago"] = "há 1 minuto"
	L["%d minutes ago"] = "há %d minutos"
	L["1 hour ago"] = "há 1 hora"
	L["%d hours ago"] = "há %d horas"
	L["1 day ago"] = "há 1 dia"
	L["%d days ago"] = "há %d dias"

	-- right-click menus
	L["Add to Old Friends List"] = "Adicionar à Old Friends List"
	L["Remove from Old Friends List"] = "Remover da Old Friends List"

	-- notifications
	L["%s has come online."] = "%s está online."
	L["%s has gone offline."] = "%s ficou offline."
	L["%d friend online: %s"] = "%d amigo online: %s"
	L["%d friends online: %s"] = "%d amigos online: %s"
	L["/who isn't available."] = "O /who não está disponível."
	L["Couldn't send /who: %s"] = "Não foi possível enviar o /who: %s"

	-- minimap button
	L["Left-click: open the list"] = "Clique esquerdo: abrir a lista"
	L["Right-click: options"] = "Clique direito: opções"
	L["Open the list"] = "Abrir a lista"
	L["Settings and key binding..."] = "Opções e atalho..."
	L["Hide minimap button"] = "Esconder botão do minimapa"
	L["Minimap button hidden. /ofl minimap brings it back."] = "Botão do minimapa escondido. /ofl minimap mostra de novo."
	L["Minimap button shown."] = "Botão do minimapa visível."

	-- options panel
	L["Key Binding"] = "Atalho"
	L["List"] = "Lista"
	L["Show level and zone"] = "Mostrar nível e zona"
	L["Show each friend's level, class and zone under their name. Turn it off to show only names."] =
		"Mostra o nível, a classe e a zona de cada amigo debaixo do nome. Desligado, mostra só os nomes."
	L["Class colors"] = "Cores de classe"
	L["Show friends' names in their class color, in the list, tooltips and chat messages."] =
		"Mostra o nome dos amigos na cor da classe, na lista, nos tooltips e nas mensagens do chat."
	L["Notifications"] = "Notificações"
	L["General"] = "Geral"
	L["Online messages"] = "Avisos de online"
	L["Offline messages"] = "Avisos de offline"
	L["Login sound"] = "Som ao entrar"
	L["Show a message in chat when a friend logs in."] = "Mostra um aviso no chat quando um amigo entra no jogo."
	L["Show a message in chat when a friend logs out."] = "Mostra um aviso no chat quando um amigo sai do jogo."
	L["Play a sound when a friend comes online."] = "Toca um som quando um amigo fica online."
	L["Show minimap button"] = "Mostrar botão no minimapa"
	L["Shortcut tab in the Blizzard Social window"] = "Aba de atalho na janela de amigos da Blizzard"
	L["Adds an Old Friends List tab under the tabs of the game's Social window (O). Only with the separate window: not shown when Old Friends List is already in that window."] =
		"Acrescenta uma aba da Old Friends List abaixo das abas da janela de amigos do jogo (O). Só com a janela separada: não aparece quando a Old Friends List já está nessa janela."

	-- Social window integration, key swap and first-time setup (0.3.0)
	L["Blizzard Social window"] = "Janela de amigos da Blizzard"
	L["Old Friends List window"] = "Janela da Old Friends List"
	L["Old Friends List %d/%d"] = "Old Friends List %d/%d"
	L["Couldn't add your friends to the Social window; using the separate window."] =
		"Não foi possível adicionar seus amigos à janela de amigos; usando a janela separada."
	L["The game blocked an action (%s). Please report it with the output of /ofl diag."] =
		"O jogo bloqueou uma ação (%s). Por favor, reporte com o resultado de /ofl diag."
	L["Invite to group"] = "Convidar para o grupo"
	L["Already in your group."] = "Já está no seu grupo."
	L["Only the group leader can invite."] = "Só o líder do grupo pode convidar."
	L["Your group is full."] = "Seu grupo está cheio."
	L["Hide friends already shown by Battle.net"] = "Esconder amigos que o Battle.net já mostra"
	L["In the Social window, a character from your Old Friends List that a Battle.net friend is playing right now shows only on Blizzard's card, not in the Old Friends List group. It comes back when they log off or switch character."] =
		"Na janela de amigos, um personagem da sua Old Friends List que um amigo Battle.net está jogando agora aparece só no cartão da Blizzard, não no grupo Old Friends List. Ele volta quando o amigo sair do jogo ou trocar de personagem."
	L["Show Battle.net friends playing WoW"] = "Mostrar amigos Battle.net jogando WoW"
	L["In the separate window, also list your Battle.net friends who are playing right now. Those on the other faction can only get a Battle.net whisper."] =
		"Na janela separada, mostra também seus amigos Battle.net que estão jogando agora. Os da outra facção só podem receber sussurro pelo Battle.net."
	L["Battle.net friend: %s"] = "Amigo Battle.net: %s"
	L["Other faction: double-click for a Battle.net whisper."] = "Outra facção: clique duas vezes para sussurrar pelo Battle.net."
	L["Other region"] = "Outra região"
	L["%s plays in another region: only a Battle.net whisper reaches them."] = "%s joga em outra região: só um sussurro pelo Battle.net chega até lá."
	L["%s is on a %s realm: only a Battle.net whisper reaches them."] = "%s está em um reino %s: só um sussurro pelo Battle.net chega até lá."
	L["%s realm: double-click for a Battle.net whisper."] = "Reino %s: clique duas vezes para sussurrar pelo Battle.net."
	L["Add %s to Old Friends List"] = "Adicionar %s à Old Friends List"
	L["Remove %s from Old Friends List"] = "Remover %s da Old Friends List"
	L["Statuses may be out of date"] = "O status pode estar desatualizado"
	L["Names in the mail"] = "Nomes no correio"
	L["Click the name to whisper: %s"] = "Clique no nome para sussurrar: %s"
	L["Click the name for a Battle.net whisper: %s"] = "Clique no nome para sussurrar pelo Battle.net: %s"
	L["When you type a name in the mail's To: field, also suggest the friends on your Old Friends List."] =
		"Ao escrever um nome no campo A: do correio, sugere também os amigos da sua Old Friends List."
	L["The game doesn't let the addon check your friends right now (%s). They're checked again as soon as it does."] =
		"O jogo não deixa o addon verificar seus amigos agora (%s). Eles são verificados de novo assim que der."
	L["Other region: double-click for a Battle.net whisper."] = "Outra região: clique duas vezes para sussurrar pelo Battle.net."
	L["Battle.net whisper"] = "Sussurrar pelo Battle.net"
	L["You can choose after the fight."] = "Você pode escolher depois do combate."
	L["Battle.net friends"] = "Amigos Battle.net"
	L["Also announce when Battle.net friends who aren't on your Old Friends List log in or out of WoW Forever. Only with Old Friends List in the Social window, or with Battle.net friends shown in the separate window."] =
		"Avisa também quando amigos Battle.net que não estão na sua Old Friends List entram ou saem do WoW Forever. Só com a Old Friends List na janela de amigos, ou com os amigos Battle.net na janela separada."
	L["Add a character"] = "Adicionar personagem"
	L["Add a character to Old Friends List"] = "Adicionar um personagem à Old Friends List"
	L["Key bindings can't change in combat. Try again after the fight."] =
		"Os atalhos não podem ser alterados em combate. Tente de novo depois da luta."
	L["%s is used for \"%s\", so the keys weren't swapped. Change them in Options > AddOns > Old Friends List."] =
		"%s está sendo usado para \"%s\", por isso as teclas não foram trocadas. Mude-as em Opções > AddOns > Old Friends List."
	L["O now opens Old Friends List, and Shift-O the Social window."] =
		"Agora o O abre a Old Friends List, e o Shift-O a janela de amigos."
	L["O opens the Social window again, and Shift-O Old Friends List."] =
		"O O voltou a abrir a janela de amigos, e o Shift-O a Old Friends List."
	L["Where to see Old Friends List"] = "Onde ver a Old Friends List"
	L["Window"] = "Janela"
	L["Old Friends List inside the game's Social window (O), or in a window of its own (Shift-O)."] =
		"A Old Friends List dentro da janela de amigos do jogo (O), ou numa janela própria (Shift-O)."
	L["Old Friends List appears together with the game's friends list. Shift-O still opens the separate window."] =
		"A Old Friends List aparece junto com a lista de amigos do jogo. O Shift-O continua abrindo a janela separada."
	L["Advanced"] = "Avançado"
	L["First-time setup"] = "Configuração inicial"
	L["Run the setup again"] = "Refazer a configuração"
	L["Social window or separate window"] = "Janela de amigos ou janela separada"
	L["Choose again: Old Friends List in the Social window or in a separate window."] =
		"Escolha de novo: a Old Friends List na janela de amigos ou numa janela separada."
	L["Old Friends List now appears in the Social window (O). Shift-O still opens the separate window."] =
		"A Old Friends List agora aparece na janela de amigos (O). O Shift-O continua abrindo a janela separada."
	L["Old Friends List opens in its own window (%s)."] = "A Old Friends List abre na sua própria janela (%s)."
	L["(your current choice)"] = "(sua escolha atual)"
	L["Choose"] = "Escolher"
	L["How would you like to see your friends?"] = "Como você quer ver seus amigos?"
	L["In the Social window (O)"] = "Na janela de amigos (O)"
	L["Separate window"] = "Janela separada"
	L["A classic friends window of its own, opened with Shift-O."] = "Uma janela de amigos clássica, só dela, aberta com Shift-O."
	L["Use O to open this window (the game's friends window moves to Shift-O)"] =
		"Usar o O para abrir esta janela (a janela de amigos do jogo passa para o Shift-O)"
	L["New: Old Friends List can also appear in the game's Social window. Nothing changes unless you pick it."] =
		"Novidade: a Old Friends List também pode aparecer na janela de amigos do jogo. Nada muda a não ser que você escolha isso."
	L["(what you have now: nothing changes)"] = "(o que você tem agora: nada muda)"
	L["Nothing changed: Old Friends List keeps its own window (%s)."] = "Nada mudou: a Old Friends List continua na sua própria janela (%s)."
	L["show the first-time setup again"] = "mostra de novo a configuração inicial"
	L["Show the Old Friends List button around the minimap."] = "Mostra o botão da Old Friends List ao redor do minimapa."
	L["Share my zone with friends"] = "Compartilhar minha zona com amigos"
	L["Tell friends who also use Old Friends List which zone you're in. Only people on your own list get it."] =
		"Informa a sua zona aos amigos que também usam a Old Friends List. Só quem está na sua lista recebe."
	L["Check interval"] = "Intervalo de verificação"
	L["How often each friend is checked. Lower is faster to notice logins; friends who use the addon are always instant."] =
		"De quanto em quanto tempo cada amigo é verificado. Menor detecta entradas mais rápido; amigos que usam o addon são sempre instantâneos."
	L["Set the key under Key Bindings > Old Friends List."] = "Defina a tecla em Teclas de atalho > Old Friends List."
	L["%s is already used for \"%s\", so no key opens the list yet. Pick one in Options > AddOns > Old Friends List."] =
		"%s já é usado para \"%s\", por isso nenhuma tecla abre a lista ainda. Escolha uma em Opções > AddOns > Old Friends List."
	L["Press %s to open your list. You can change it in Options > AddOns > Old Friends List."] =
		"Pressione %s para abrir sua lista. Você pode mudar isso em Opções > AddOns > Old Friends List."
	L["The options can't be opened in combat. Try again after the fight."] =
		"As opções não podem ser abertas em combate. Tente de novo depois da luta."

	-- slash commands
	L["<first last>"] = "<nome sobrenome>"
	L["Commands:"] = "Comandos:"
	L["All commands:"] = "Todos os comandos:"
	L["open or close the list"] = "abre ou fecha a lista"
	L["add a character, e.g. /ofl add Asha Brightvale"] = "adiciona um personagem, por exemplo: /ofl add Asha Brightvale"
	L["remove a character"] = "remove um personagem"
	L["set a note (no text clears it)"] = "define uma nota (sem texto, apaga)"
	L["print the list with who's online"] = "mostra a lista no chat, com quem está online"
	L["open the options (settings and key binding)"] = "abre as opções (configurações e atalho)"
	L["show or hide the minimap button"] = "mostra ou esconde o botão do minimapa"
	L["all commands"] = "todos os comandos"
	L["print your settings in chat"] = "mostra suas opções no chat"
	L["\"has come online\" messages"] = "avisos de online"
	L["\"has gone offline\" messages"] = "avisos de offline"
	L["login sound"] = "som ao entrar"
	L["share your zone with friends who use the addon"] = "compartilha sua zona com amigos que usam o addon"
	L["how often each friend is checked (15-300)"] = "de quanto em quanto tempo cada amigo é verificado (15-300)"
	L["check one character now and print the result"] = "verifica um personagem agora e mostra o resultado"
	L["check which game APIs this client has"] = "verifica quais APIs do jogo este cliente tem"
	L["toggle debug messages"] = "liga ou desliga as mensagens de depuração"
	L["<seconds>"] = "<segundos>"
	L["<text>"] = "<texto>"
	L["on"] = "ligado"
	L["off"] = "desligado"
	L["Settings:"] = "Opções:"
	L["online messages"] = "avisos de online"
	L["offline messages"] = "avisos de offline"
	L["sound"] = "som"
	L["share zone with friends"] = "compartilhar zona"
	L["check interval"] = "intervalo"
	L["key to open the list"] = "tecla para abrir a lista"
	L["none (set one with /ofl config)"] = "nenhuma (defina com /ofl config)"
	L["Your list is empty. /ofl add <first last>"] = "Sua lista está vazia. /ofl add <nome sobrenome>"
	L["%d of %d online:"] = "%d de %d online:"
	L["online"] = "online"
	L["offline"] = "offline"
	L["offline, last seen %s"] = "offline, visto %s"
	L["checking..."] = "verificando..."
	L["%s isn't on your list."] = "%s não está na sua lista."
	L["Note set for %s."] = "Nota definida para %s."
	L["Note cleared for %s."] = "Nota removida de %s."
	L["The interval must be 15 to 300 seconds."] = "O intervalo deve ser de 15 a 300 segundos."
	L["Each friend is checked every %d seconds."] = "Cada amigo é verificado a cada %d segundos."
end
