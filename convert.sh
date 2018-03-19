#!/bin/bash

dir='/srv/arch-mirror/arch/arch/archlinux32/irc-logs/#archlinux-ports/'

declare -A colors

if [ "$1" = 'html' ]; then
  shift
  sed -n '
    /^<font size="2">/{
      s@^<font size="2">(\([^)]\+\))</font><b> @\1 @
      /entered the room\.<\/b><br\/>$/{
        s@^\(\S\+\) \(.*\S\) \[.*] entered the room\.<\/b><br\/>$@\1 --> | \2 has joined #archlinux-ports @
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
    /<font size="2">/{
      s@^<font color="#[0-9A-F]\{6\}"><font size="2">(\([^)]\+\))</font> <b>\(\S\+\):</b></font> @\1 \2 | @
      s@<br/>$@@
      p
      d
    }
  '
else
  sed '
    s/([^()]*@[^()]*) //
  '
  cat
fi | \
sed '
  :a
    $!N
    s/\n\s\+ | / /
    ta
  P
  D
' | \
while read -r a b dummy c; do
  if [ "${dummy}" != '|' ]; then
    >&2 printf 'wrong dummy "%s"\n' "${dummy}"
    exit 42
  fi
  time=$(
    date -d@$(($(date -d"${a}" +%s)+3600*$2)) +%T
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
  if [ -z "${colors["${b}"]}" ]; then
    colors["${b}"]=$(
      find "${dir}" -type f -name '*-*-*.html' -exec \
        grep -h "style=\"color:#[0-9a-f]\{6\}\">&lt;${b}&gt;" {} \; | \
        sed 's@.* style="color:#\([0-9a-f]\{6\}\)">&lt;.*@\1@' | \
        sort -u
    )
  fi
  if [ -z "${colors["${b}"]}" ]; then
    colors["${b}"]=$(hexdump -n 4 -e '4/4 "%08X" 1 "\n"' /dev/urandom | head -c 6)
#    >&2 printf 'unkown user "%s"\n' "${b}"
#    exit 42
  fi
  if [ $(echo "${colors["${b}"]}" | wc -l) -ne 1 ]; then
    >&2 printf 'user "%s" has multiple colors\n' "${b}"
    exit 42
  fi
  printf '<a href="#%s" name="%s" class="time">[%s]</a> <span class="person" style="color:#%s">&lt;%s&gt;</span> %s\n<br />\n' \
    "${time}" "${time}" "${time}" "${colors["${b}"]}" "${b}" "${c}"
done