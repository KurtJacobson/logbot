#!/bin/bash

dirs='/srv/arch-mirror/arch/arch/archlinux32/irc-logs/'

declare -A colors

create_color() {
  if [ -z "${colors["$1"]}" ]; then
    colors["$1"]=$(
      find "${dirs}" -type f -name '*-*-*.html' -exec \
        grep -h "style=\"color:#[0-9a-f]\{6\}\">&lt;$1&gt;" {} \; | \
        sed 's@.* style="color:#\([0-9a-f]\{6\}\)">&lt;.*@\1@' | \
        sort -u
    )
  fi
  if [ -z "${colors["$1"]}" ]; then
    colors["${b}"]=$(hexdump -n 4 -e '4/4 "%08X" 1 "\n"' /dev/urandom | head -c 6)
#    >&2 printf 'unkown user "%s"\n' "$1"
#    exit 42
  fi
  if [ $(echo "${colors["$1"]}" | wc -l) -ne 1 ]; then
    >&2 printf 'user "%s" has multiple colors\n' "$1"
    exit 42
  fi
}

# the desired format is:
# "time nick | msg"
# "time --> | nick ... channel"
# "time <-- | nick ... (reason)"
# "time -- | old-nick new-nick"
# "time * | nick action"
# we reformat other formats accordingly

if [ "$1" = 'tyzoid' ]; then
  shift
  channel="$1"
  shift
  sed '
    s/^\[\([^]]\+\)] \*\*\* Joins: \(\S\+\) .*$/\1 --> | \2 has joined '"${channel}"' /
    t
    s/^\[\([^]]\+\)] \*\*\* Quits: \(\S\+\) (\(.*\))$/\1 <-- | \2 has quit (\3)/
    t
    s/\[\([^]]\+\)] <\(\S\+\)> /\1 \2 | /
    t
    d
  '
elif [ "$1" = 'html' ]; then
  shift
  channel="$1"
  shift
  sed -n '
    /^<font size="2">/{
      s@^<font size="2">(\([^)]\+\))</font><b> @\1 @
      /entered the room\.<\/b><br\/>$/{
        s@^\(\S\+\) \(.*\S\) \[.*] entered the room\.<\/b><br\/>$@\1 --> | \2 has joined '"${channel}"' @
        p
        d
      }
      / left the room /{
        s@^\(\S\+\) \(.*\S\) left the room (quit: \(.*\))\.</b><br/>$@\1 <-- | \2 has quit (\3)@
        p
        d
      }
      / left the room\./{
        s@^\(\S\+\) \(.*\S\) left the room\.</b><br/>$@\1 <-- | \2 has quit (Quit: \2)@
        p
        d
      }
      / is now known as /{
        s@^\(\S\+\) \(.*\S\)\s*</b><br/>$@\1 -- | \2@
        p
        d
      }
      d
    }
    \@</font> <b>\*\*\*\S\+</b></font> @{
      s@^<font color="#[0-9A-F]\{6\}"><font size="2">(\([^)]\+\))</font> <b>\*\*\*\(\S*\)</b></font> \(.*\)<br/>$@\1 * | \2 \3@
      p
      d
    }
    /<font size="2">/{
      s@^<font color="#[0-9A-F]\{6\}"><font size="2">(\([^)]\+\))</font> <b>\(\S\+\):</b></font> @\1 \2 | @
      s@<br/>$@@
      p
      d
    }
  '
else
  cat
fi | \
  sponge | \
  sed '
    s/([^()]*@[^()]*) //
  ' | \
  sed '
    :a
      $!N
      s/\n\s\+ | / /
      ta
    P
    D
  ' | \
  sed '
    s@\(\s\)\(https\?://\S\+\)@\1<a href="\2" target="_blank">\2</a>@g
  ' | \
  while read -r a b dummy c; do
    if [ "${dummy}" != '|' ]; then
      >&2 printf 'wrong dummy "%s"\n' "${dummy}"
      exit 42
    fi
    time=$(
      date -d@$(($(date -d"${a}" +%s)+3600*$1)) +%T
    )
    if [ "${b}" = '-->' ]; then
      name="${c%% *}"
      channel="${c##* }"
      printf '<a href="#%s" name="%s" class="time">[%s]</a> -!- <span class="join">%s</span> has joined %s\n<br />\n' \
        "${time}"  "${time}" "${time}" "${name}" "${channel}"
      continue
    fi
    if [ "${b}" = '<--' ]; then
      name="${c%% *}"
      reason="${c##* (}"
      reason="${reason%)*}"
      printf '<a href="#%s" name="%s" class="time">[%s]</a> -!- <span class="quit">%s</span> has quit [%s]\n<br />\n' \
        "${time}"  "${time}" "${time}" "${name}" "${reason}"
      continue
    fi
    if [ "${b}" = '--' ]; then
      before="${c%% *}"
      after="${c##* }"
      printf '<a href="#%s" name="%s" class="time">[%s]</a> <span class="nick">%s</span> is now known as <span class="nick">%s</span>\n<br />\n' \
        "${time}" "${time}" "${time}" "${before}" "${after}"
      continue
    fi
    if [ "${b}" = '*' ]; then
      nick="${c%% *}"
      action="${c#* }"
      create_color "${nick}"
      printf '<a href="#%s" name="%s" class="time">[%s]</a> <span class="person" style="color:#%s">* %s %s</span>\n<br />\n' \
        "${time}" "${time}" "${time}" "${colors["${nick}"]}" "${nick}" "${action}"
      continue
    fi
    create_color "${b}"
    printf '<a href="#%s" name="%s" class="time">[%s]</a> <span class="person" style="color:#%s">&lt;%s&gt;</span> %s\n<br />\n' \
      "${time}" "${time}" "${time}" "${colors["${b}"]}" "${b}" "${c}"
  done
