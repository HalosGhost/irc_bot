-- channel moderation

local moderate = {}

moderate.commands = {}

moderate.commands.kick = function (args)
    local _, _, recipient, message = args.message:find('kick%s+(%S+)%s*(.*)')

    if args.modules.config.debug then print(('kicking %s'):format(recipient)) end
    args.modules.irc.kick(args.connection, args.target, recipient, message or recipient)
end

moderate.commands['set-mode'] = function (args)
    local _, _, mode, recipient = args.message:find('([+-][bqvo])%s+(.+)')

    if args.modules.config.debug then print(('setting %s to %s'):format(recipient, mode)) end
    args.modules.irc.modeset(args.connection, args.target, recipient, mode)
end

moderate.commands.join = function (args)
    local _, _, channel = args.message:find('join%s+(%S+)')

    if channel then
        args.modules.irc.join(args.connection, channel)
        args.modules.irc.privmsg(args.connection, args.target, ('Joined %s'):format(channel))
    end
end

local h = ''
for k in pairs(moderate.commands) do
    h = ('%s|%s'):format(h, k)
end
moderate.help = ('usage: moderate <%s>'):format(h:sub(2))

moderate.main = function (args)
    local _, _, action = args.message:find('(%S+)')
    local f = moderate.commands[action]

    if args.authorized and f then return f(args) end

    args.modules.irc.privmsg(args.connection, args.target, moderate.help)
end

return moderate
