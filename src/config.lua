local config = {}

config.debug = true
config.dbpath = 'bot.db'

config.irc = { name = 'freenode'
             , address = 'chat.freenode.net'
             , port = 7000
             , handle = 'ailur'
             , ident = 'ailur'
             , gecos = '🐼'
             , admins =
                 { ['.*@archlinux/support/halosghost'] = 1
                 , ['.*@unaffiliated/meskarune'] = 2
                 , ['.*@durr/im/a/sheep'] = 3
                 }
             , channels =
                 { '##meskarune'
                 }
             , sslparams =
                 { mode = 'client'
                 , protocol = 'tlsv1_2'
                 , verify = 'none'
                 , options = { 'all' }
                 }
             }

return config
