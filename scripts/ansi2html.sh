#!/bin/sh

# Convert ANSI (terminal) colours and attributes to HTML

# Author:
#    http://www.pixelbeat.org/docs/terminal_colours/
# Notes:
#    Generally one can use the `script` util to capture full terminal output.
#    We only support 16 colour terminals, so we don't support apps that output
#    256 colours on xterm-256color. So to capture and process vim output try:
#      TERM=xterm vim file | tee term.cap; ansi2html.sh <term.cap >term.html
# Changes:
#    V0.1, 24 Apr 2008, Initial release
#    V0.2, 01 Jan 2009, Phil Harnish <philharnish@gmail.com>
#                         Support `git diff --color` output by
#                         matching ANSI codes that specify only
#                         bold or background colour.
#                       P@draigBrady.com
#                         Support `ls --color` output by stripping
#                         redundant leading 0s from ANSI codes.
#                         Support `grep --color=always` by stripping
#                         unhandled ANSI codes (specifically ^[[K).
#    V0.3, 20 Mar 2009, http://eexpress.blog.ubuntu.org.cn/
#                         Remove cat -v usage which mangled non ascii input
#                         Cleanup regular expressions used.
#                         Support other attributes like reverse, ...
#                       P@draigBrady.com
#                         Correctly nest <span> tags (even across lines).
#                         Add a command line option to use a dark background.
#                         Strip more terminal control codes.
#    V0.4, 17 Sep 2009, P@draigBrady.com
#                         Handle codes with combined attributes and color
#                         Handle isolated <bold> attributes with css.
#                         Strip more terminal control codes.

if [ "$1" = "--version" ]; then
    echo "0.4" && exit
fi

if [ "$1" = "--help" ]; then
    echo "This utility converts ANSI codes in data passed to stdin" >&2
    echo "It has 1 optional parameter: --bg=dark" >&2
    echo "E.g.: ls -l --color=always | ansi2html.sh --bg=dark > ls.html" >&2
    exit
fi

[ "$1" = "--bg=dark" ] && black_bg=yes

echo -n '<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<style type="text/css">
/* linux console palette */
.f0 { color: #000000; }
.f1 { color: #AA0000; }
.f2 { color: #00AA00; }
.f3 { color: #AA5500; }
.f4 { color: #0000AA; }
.f5 { color: #AA00AA; }
.f6 { color: #00AAAA; }
.f7 { color: #AAAAAA; }
.b0 { background-color: #000000; }
.b1 { background-color: #AA0000; }
.b2 { background-color: #00AA00; }
.b3 { background-color: #AA5500; }
.b4 { background-color: #0000AA; }
.b5 { background-color: #AA00AA; }
.b6 { background-color: #00AAAA; }
.b7 { background-color: #AAAAAA; }
.f0 > .bold,.bold > .f0 { color: #555555; font-weight: normal; }
.f1 > .bold,.bold > .f1 { color: #FF5555; font-weight: normal; }
.f2 > .bold,.bold > .f2 { color: #55FF55; font-weight: normal; }
.f3 > .bold,.bold > .f3 { color: #FFFF55; font-weight: normal; }
.f4 > .bold,.bold > .f4 { color: #5555FF; font-weight: normal; }
.f5 > .bold,.bold > .f5 { color: #FF55FF; font-weight: normal; }
.f6 > .bold,.bold > .f6 { color: #55FFFF; font-weight: normal; }
.f7 > .bold,.bold > .f7 { color: #FFFFFF; font-weight: normal; }
body.b0 > pre > .bold   { color: #FFFFFF; font-weight: normal; }
body.b8 > pre > .bold   { font-weight: bold; } /* allow for black on white */
.reverse {
  /* CSS doesnt support swapping fg and bg colours unfortunately,
     so just hardcode something that will look OK on all backgrounds. */
  color: #000000; background-color: #AAAAAA;
}
.underline { text-decoration: underline; }
.line-through { text-decoration: line-through; }
.blink { text-decoration: blink; }
</style>
</head>
'
[ "$black_bg" ] && body_class=' class="f7 b0"' || body_class=' class="b8"'
echo -n "
<body$body_class>

<pre>
"

p='\x1b\['        #shortcut to match escape codes
P="\(^[^°]*\)¡$p" #expression to match prepended codes below

sed "
# strip non SGR codes
s#[\x0d\x07]##g
s#\x1b[]>=\][0-9;]*##g
s#\x1bP+.\{5\}##g
s#\x1b(B##g
s#${p}[0-9;?]*[^0-9;?m]##g

# escape HTML
s#\&#\&amp;#g; s#>#\&gt;#g; s#<#\&lt;#g; s#\"#\&quot;#g

# normalize SGR codes a little
:c
s#${p}\([0-9]\{1,\}\);\([0-9;]\{1,\}\)m#${p}\1m${p}\2m#g; t c   # split combined
s#${p}0\([0-7]\)#${p}\1#g                                 #strip leading 0
s#${p}1m\(\(${p}[4579]m\)*\)#\1${p}1m#g;                  #bold last (with clr)
s#${p}m#${p}0m#g                                          #add leading 0 to norm

# change 'reset' code to a single char, and prepend a single char to
# other codes so that we can easily do negative matching, as sed
# does not support look behind expressions etc.
s#°#\&deg;#g; s#${p}0m#°#g
s#¡#\&iexcl;#g; s#${p}[0-9;]*m#¡&#g
" |

sed "
:ansi_to_span # replace ANSI codes with CSS classes
t ansi_to_span # hack so t commands below only apply to preceeding s cmd

/^[^¡]*°/ { b span_end } # replace 'reset code' if no preceeding code

# common combinations to minimise html (optional)
s#${P}3\([0-7]\)m¡${p}4\([0-7]\)m#\1<span class=\"f\2 b\3\">#;t span_count
s#${P}4\([0-7]\)m¡${p}3\([0-7]\)m#\1<span class=\"f\3 b\2\">#;t span_count

s#${P}1m#\1<span class=\"bold\">#;                            t span_count
s#${P}4m#\1<span class=\"underline\">#;                       t span_count
s#${P}5m#\1<span class=\"blink\">#;                           t span_count
s#${P}7m#\1<span class=\"reverse\">#;                         t span_count
s#${P}9m#\1<span class=\"line-through\">#;                    t span_count
s#${P}3\([0-7]\)m#\1<span class=\"f\2\">#;                    t span_count
s#${P}4\([0-7]\)m#\1<span class=\"b\2\">#;                    t span_count

s#${P}[0-9;]*m#\1#g; t ansi_to_span # strip unhandled codes

b # next line of input

# add a corresponding span end flag
:span_count
x; s/^/s/; x
b ansi_to_span

# replace 'reset code' with correct number of </span> tags
:span_end
x
/^s/ {
  s/^.//
  x
  s#°#</span>°#
  b span_end
}
x
s#°##
b ansi_to_span
"
echo "</pre>
</body>
</html>"