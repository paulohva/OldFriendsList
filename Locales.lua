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
	L["Offline, last seen %s"] = "Offline, visto %s"
	L["Last seen %s"] = "Visto pela última vez %s"
	L["Last zone: %s"] = "Última zona: %s"
	L["Double-click to whisper, right-click for options."] = "Clique duplo para sussurrar, botão direito para opções."
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
	L["Add to Old Friends"] = "Adicionar à Old Friends"
	L["Remove from Old Friends"] = "Remover da Old Friends"

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
	L["Add a friend..."] = "Adicionar amigo..."
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
	L["Show the Old Friends List button around the minimap."] = "Mostra o botão da Old Friends List ao redor do minimapa."
	L["Share my zone with friends"] = "Compartilhar minha zona com amigos"
	L["Tell friends who also use Old Friends List which zone you're in. Only people on your own list get it."] =
		"Informa a sua zona aos amigos que também usam a Old Friends List. Só quem está na sua lista recebe."
	L["Check interval"] = "Intervalo de verificação"
	L["How often each friend is checked. Lower is faster to notice logins; friends who use the addon are always instant."] =
		"De quanto em quanto tempo cada amigo é verificado. Menor detecta entradas mais rápido; amigos que usam o addon são sempre instantâneos."
	L["Set the key under Key Bindings > AddOns > Old Friends List."] = "Defina a tecla em Teclas de atalho > AddOns > Old Friends List."
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
