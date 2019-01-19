-- local json = require 'json'
-- local url = require 'socket.url'
-- local https = require 'ssl.https'
local mediawiki_alias = require 'mediawiki_alias'

local self =
  { ['ug[maen]'] =
      function (ms, c, t, msg, _, s)
          local map = { ['m'] = 'Morning'
                      , ['a'] = 'Afternoon'
                      , ['e'] = 'Evening'
                      , ['n'] = 'Night'
                      }
          local _, _, l = msg:find('ug(.)')
          ms.irc.privmsg(c, t, s .. ' says “Good (ugt) ' .. map[l] .. ' to all!”')
      end
  , ['die'] =
      function (_, c, _, _, auth)
          if auth then c:close(); os.exit() end
      end
  , ['reload%s+.+'] =
      function (ms, c, t, msg, authed)
          if not authed then return end

          local _, _, what = msg:find('reload%s+(.+)')
          for k in pairs(ms) do
              if what == k then
                  ms.irc.privmsg(c, t, ms.extload(ms, k))
              end
          end
      end
  , ['fact count%s*.*'] =
      function (ms, c, t, msg)
          local _, _, key = msg:find('fact count%s*(.*)')
          ms.irc.privmsg(c, t, ms.irc_factoids.count(key))
      end
  , ['fact search%s*.*'] =
      function (ms, c, t, msg)
          local _, _, key = msg:find('fact search%s*(.*)')
          ms.irc.privmsg(c, t, ms.irc_factoids.search(key))
      end
  , ['list%s*%S*'] =
      function (ms, c, t, msg)
          local list = ''
          local _, _, what = msg:find('list%s*(%S*)')

          local tables = { ['all']      = tables
                         , ['aliases']  = ms.irc_aliases
                         , ['modules']  = ms
                         , ['config']   = ms.config
                         }

          local the_table = what and tables[what] or tables

          for k in pairs(the_table) do
              list = "'" .. k .. "' " .. list
          end; ms.irc.privmsg(c, t, list)
      end
  , ['%-?%d+%.?%d*%s*.+%s+in%s+.+'] =
      function (ms, c, t, msg)
          local _, _, val, src, dest = msg:find('(%-?%d+%.?%d*)%s*(.+)%s+in%s+(.+)')
          if ms.config.debug then
              print(val, src, dest)
          end

          if not tonumber(val) then
              ms.irc.privmsg(c, t, val .. ' is not a number I recognize')
              return
          end
          val = tonumber(val)

          if src == dest then
              ms.irc.privmsg(c, t, ('… %g %s… obviously…'):format(val, src))
              return
          end

          local src_unit, pos = ms.units.parse_unit(src)
          if src_unit == '' or not ms.units.conversion[src_unit] then
              ms.irc.privmsg(c, t, 'I cannot convert ' .. src)
              return
          end

          local val_adj = 1
          if pos > 1 then
              local prefix = src:sub(1, pos - 1)
              val_adj = ms.units.parse_prefix(prefix, ms.units.si_aliases, 10, ms.units.si)
              val_adj = val_adj or
                  ms.units.parse_prefix(prefix, ms.units.iec_aliases, 2, ms.units.iec)
          end
          if ms.config.debug then print(val_adj) end

          local dest_unit, pos = ms.units.parse_unit(dest)

          if src_unit ~= dest_unit and (dest_unit == '' or not ms.units.conversion[src_unit][dest_unit]) then
              if ms.config.debug then print(dest_unit) end
              ms.irc.privmsg(c, t, ('I cannot convert %s to %s'):format(src, dest))
              return
          end

          local dest_adj = 1
          local dest_prefix = ''
          if pos > 1 then
              dest_prefix = dest:sub(1, pos - 1)
              dest_adj = ms.units.parse_prefix(dest_prefix, ms.units.si_aliases, 10, ms.units.si)
              dest_adj = dest_adj or
                  ms.units.parse_prefix(dest_prefix, ms.units.iec_aliases, 2, ms.units.iec)
          end

          local new_val = src_unit == dest_unit
              and (val_adj * val / dest_adj)
              or (ms.units.conversion[src_unit][dest_unit](val_adj * val) / dest_adj)

          ms.irc.privmsg(c, t, ('%g %s is %g %s%s'):format(val, src, new_val, dest_prefix, dest_unit))
      end
  , ['units%s*.*'] =
      function (ms, c, t, msg)
          local list = ''
          local _, _, what = msg:find('units%s*(.*)')

          local the_table
          if not what then
              the_table = ms.units.conversion
          else
              the_table = ms.units.conversion[what] or ms.units.conversion
          end

          for k in pairs(the_table) do
              list = "'" .. k .. "' " .. list
          end; ms.irc.privmsg(c, t, list)
      end
  , ['is.*'] =
      function (ms, c, t)
          local prob =
            { 'certainly', 'possibly', 'categorically', 'negatively'
            , 'positively', 'without-a-doubt', 'maybe', 'perhaps', 'doubtfully'
            , 'likely', 'definitely', 'greatfully', 'thankfully', 'undeniably'
            , 'arguably' }
          local case = { 'so', 'not', 'true', 'false' }
          local punct = { '.', '!', '…' }
          local r1 = math.random(#prob)
          local r2 = math.random(#case)
          local r3 = math.random(#punct)
          ms.irc.privmsg(c, t, prob[r1] .. ' ' .. case[r2] .. punct[r3])
      end
  , ['say%s+.+'] =
      function (ms, c, t, msg)
          local _, _, m = msg:find('say%s+(.+)')
          ms.irc.privmsg(c, t, m)
      end
  , ['act%s+.+'] =
      function (ms, c, t, msg)
          local _, _, m = msg:find('act%s+(.+)')
          ms.irc.privmsg(c, t, '\x01ACTION ' .. m .. '\x01')
      end
  , ['give%s+%S+.+'] =
      function (ms, c, t, msg, _, sndr)
          local _, _, to, what = msg:find('give%s+(%S+)%s+(.*)')
          if what then
              local thing = ms.irc_factoids.find(what:gsub("^%s*(.-)%s*$", "%1"))
              ms.irc.privmsg(c, t, to .. ': ' .. (thing or (sndr .. ' wanted you to have ' .. what)))
          end
      end
  , ['hatroulette'] =
      function (ms, c, t, _, _, sndr)
          local ar = { '-', '+' }
          local md = { 'q', 'b', 'v', 'o', 'kick'}
          local mode_roll = md[math.random(#md)]

          if mode_roll == 'kick' then
              ms.irc.privmsg(c, t, sndr .. ' rolls for a kick!')
              ms.irc.kick(c, t, sndr, 'You asked for this')
              return
          end

          local res = ar[math.random(#ar)] .. mode_roll

          if t:byte() == 35 then
              ms.irc.privmsg(c, t, sndr .. ' rolls for a ' .. res .. '!')
          end

          ms.irc.modeset(c, t, sndr, res)
      end
  , ['[+-][bqvo]%s+.+'] =
      function (ms, c, t, msg, authed)
          local _, _, mode, recipient = msg:find('([+-][bqvo])%s+(.+)')

          if authed then
              ms.irc.modeset(c, t, recipient, mode)
              ms.irc.privmsg(c, t, "Tada!")
          end
      end
  , ['kick%s+%S+%s*.*'] =
      function (ms, c, t, msg, authed)
          local _, _, recipient, message = msg:find('kick%s+(%S+)%s*(.*)')
          message = message or recipient

          if authed then
              ms.irc.kick(c, t, recipient, message)
          end
      end
  , ['you.*'] =
      function (ms, c, t, msg, _, sndr)
          local _, _, attr = msg:find('you(.*)')
          attr = attr or ''
          ms.irc.privmsg(c, t, sndr .. ': No, \x1Dyou\x1D' .. attr .. '!')
      end
  , ['test%s*.*'] =
      function (ms, c, t, msg)
          local _, _, test = msg:find('test%s*(.*)')
          test = test == '' and test or (' ' .. test)

          local prob = math.random()
          local rest = { '3PASS', '5FAIL', '5\x02PANIC\x02' }
          local res = prob < 0.01 and rest[3] or
                      prob < 0.49 and rest[2] or rest[1]

          ms.irc.privmsg(c, t, ('Testing%s: [\x03%s\x03]'):format(test, res))
      end
  , ['roll%s+%d+d%d+'] =
      function (ms, c, t, msg, _, sndr)
          local _, _, numdice, numsides = msg:find('roll%s*(%d+)d(%d+)')
          local rands = ''

          numdice = math.tointeger(numdice)
          numsides = math.tointeger(numsides)
          local invalid = function (n)
              return not (math.type(n) == 'integer' and n >= 1)
          end

          if invalid(numdice) or invalid(numsides) then return end

          for i=1,numdice do
              rands = math.random(numsides) .. ' ' .. rands
              if rands:len() > 510 then break end
          end

          ms.irc.privmsg(c, t, sndr .. ': ' .. rands)
      end
  , ['bloat%s*.*'] =
      function (ms, c, t, msg, _, sndr)
          local _, _, target = msg:find('bloat%s*(.*)')
          target = target == '' and sndr or target
          ms.irc.privmsg(c, t, target .. ' is bloat.')
      end
  , ['[ <]?https?://[^> ]+.*'] =
      function (ms, c, t, msg)
          local _, _, url = msg:find('[ <]?(https?://[^> ]+).*')
          if url then
              local title = ms.get_url_title(url)
              ms.irc.privmsg(c, t, title)
          end
      end
  , ['rot13%s.*'] =
      function (ms, c, t, msg)
          local _, _, text = msg:find('rot13%s(.*)')
          if text then
              local chars = {}
              for i=1,text:len() do
                  chars[i] = text:byte(i)
              end

              local rotted = ""
              for i=1,#chars do
                  local letter = chars[i]
                  if letter >= 65 and letter < 91 then
                      local offset = letter - 65
                      letter = string.char(65 + ((offset + 13) % 26))
                  elseif letter >= 97 and letter < 123 then
                      local offset = letter - 97
                      letter = string.char(97 + ((offset + 13) % 26))
                  else
                      letter = string.char(chars[i])
                  end
                  rotted = rotted .. letter
              end

              ms.irc.privmsg(c, t, rotted)
          end
      end
  , ['restart'] =
      function (_, _, _, _, authed)
          if authed then return true end
      end
  , ['update'] =
      function (ms, c, t, _, authed)
          if authed then
              local _, _, status = os.execute('git pull origin master')
              if status == 0 then
                  ms.irc.privmsg(c, t, "Tada!")
              end
          end
      end
  , ['judges'] =
      function (ms, c, t, _, _, sndr)
          ms.irc.privmsg(c, t, "So close, but " .. sndr .. " won by a nose!")
      end
  , ['join%s+%S+'] =
      function (ms, c, t, msg, authed)
          if authed then
              local _, _, chan = msg:find('join%s+(%S+)')
              if chan then
                  ms.irc.join(c, chan)
                  ms.irc.privmsg(c, t, 'Tada!')
              end
          end
      end
  , ['wiki%s+.+'] =
      mediawiki_alias('wiki%s+(.+)', 'https://en.wikipedia.org/w/api.php')
  , ['archwiki%s+.+'] =
      mediawiki_alias('archwiki%s+(.+)', 'https://wiki.archlinux.org/api.php')
  , ["'.+' is '.+'"] =
      function (ms, c, t, msg)
          local _, _, key, val = msg:find("'(.+)' is '(.+)'")
          if not key or not val then
              ms.irc.privmsg(c, t, '… what?')
          else
              ms.irc_factoids.add(key, val)
              ms.irc.privmsg(c, t, 'Tada!')
          end
      end
  , ["'.+' is nothing"] =
      function (ms, c, t, msg)
          local _, _, key = msg:find("'(.+)' is nothing")
          if not key then
              ms.irc.privmsg(c, t, '… what?')
          else
              ms.irc_factoids.remove(key)
              ms.irc.privmsg(c, t, 'Tada!')
          end
      end
  , ["pick%s+.+"] =
      function (ms, c, t, msg)
          local _, _, str = msg:find("pick%s+(.+)")
          local words = {}
          if str then
              for i in str:gmatch("%S+") do
                  words[#words + 1] = i
              end
          end
          local r = math.random(#words)
          ms.irc.privmsg(c, t, words[r])
      end
  , ['uptime'] =
      function (ms, c, t)
          local upt = io.popen('uptime -p')
          ms.irc.privmsg(c, t, upt:read())
          upt:close()
      end
  , ['sysstats'] =
      function (ms, c, t)
          local disk = 'df /dev/sda1 --output=pcent | tail -n 1'
          local pipe = io.popen(disk)
          local du = pipe:read('*number') .. '%'
          pipe:close()
          pipe = io.popen('free | tail -n 2')
          local ram = pipe:read()
          pipe:close()
          local rampat = 'Mem:%s+(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)'
          local _, _, tot, fre = ram:find(rampat)
          fre = fre or 0
          tot = tot or 1
          local ru = ('%.f%%'):format(fre / tot * 100)
          ms.irc.privmsg(c, t, ('HDD: %s full; RAM: %s free'):format(du, ru))
      end
  , ['version'] =
      function (ms, c, t)
          local upt = io.popen('printf \'0.r%s.%s\' "$(git rev-list --count HEAD)" "$(git log -1 --pretty=format:%h)"')
          ms.irc.privmsg(c, t, upt:read())
          upt:close()
      end
  , ['hug%s.+'] =
      function (ms, c, t, msg)
          local _, _, recipient = msg:find('hug%s(.+)')
          ms.irc.privmsg(c, t, recipient .. ': imma smother you in love')
      end
  , ['who am I%?'] =
      function (ms, c, t, _, authed, sndr)
          local admin = authed and ', an admin' or ''
          ms.irc.privmsg(c, t, sndr .. admin)
      end
  , ['what is%s+.+%??'] =
      function (ms, c, t, msg, _, sndr)
          local _, _, thing = msg:find('what is%s+(.+)%??')
          local responses = {
              '\'tis a silly thing', 'not sure, haven\'t heard of it', 'it tastes good.',
              'wouldn\'t want to be caught up in that', 'phhht', 'oh please',
              'now hang on, iI\'llo ask the questions here.', 'is it tasty?',
              'is that one of those genetically modified things?', 'isn\'t that what halfwit uses?',
              'can you eat it?', 'oh yeah, I put one of those in my truck last year.',
              'we don\'t talk about it.', 'I love it! Definitely my favorite flavor.',
              'Meh, I prefer vanilla.', '\'tis a silly place.',
              'don\'t get the cheap one, it won\'t last a month.',
              'a type of bear, but grizzlies are still the coolest.'
          }

          local response = sndr .. ': ' .. thing .. '? ' .. responses[math.random(#responses)]
          ms.irc.privmsg(c, t, response)
      end
  , ['sudo.*'] =
      function (ms, c, t)
          ms.irc.privmsg(c, t, 'Tada!')
      end
  , ['config%s+%S+%s+%S+%s*%S*'] =
      function (ms, c, t, msg, authed)
          if not authed then return end

          local _, _, action, setting, value = msg:find('config%s+(%S+)%s+(%S+)%s*(%S*)')

          if action == 'toggle' and type(ms.config[setting]) == 'boolean' then
              ms.config[setting] = not ms.config[setting]
              ms.irc.privmsg(c, t, ('set %s to %s. Tada!'):format(setting, ms.config[setting]))
          elseif action == 'get' then
              ms.irc.privmsg(c, t, tostring(ms.config[setting]))
          elseif action == 'type' then
              ms.irc.privmsg(c, t, type(ms.config[setting]))
          elseif action == 'set' then
              if value == 'true' then
                  ms.config[setting] = true
              elseif value == 'false' then
                  ms.config[setting] = true
              elseif tonumber(value) ~= nil then
                  ms.config[setting] = tonumber(value)
              else
                  ms.config[setting] = value
              end

              ms.irc.privmsg(c, t, 'Tada!')
          end
      end
  }

return self
