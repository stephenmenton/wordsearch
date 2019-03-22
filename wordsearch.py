#!/usr/bin/env python
"""
Usage: wordsearch.py -f FILENAME [OPTIONS]
Searches for words in a file like a wordsearch puzzle
Required:
  -f FILENAME    file containing wordsearch content
Optional:
  -c COUNT       minimum count per word (default is 1)
  -d DICTIONARY  dictionary file to use
  -l LENGTH      minimum word length (default is 3)
  -w WAYS        comma delimited way(s) to search
                 supported values: ul, u, ur, l, r, dl, d, dr
                 e.g. -w "ul, ur, dl, dr"

Report bugs to <aquaone@gmail.com>
"""

"""
Copyright [2017] [Stephen F. Menton <aquaone@gmail.com>]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
__author__ = 'Stephen Menton'

import getopt, os.path, re, sys

script_name = os.path.basename(__file__)
script_version = '1.0.17'

# basic args
if len(sys.argv) == 1: sys.exit(globals()['__doc__'].strip())

if re.match('^--?(h(elp)?|\?)$', sys.argv[1]):
  print globals()['__doc__'].strip()
  sys.exit(0)

if re.match('^--?(v(er(sion)?)?)$', sys.argv[1]):
  print script_name, script_version
  sys.exit(0)

# defaults
min_count, min_length = 1, 3
dictionary = '/usr/share/dict/words'
ways = {} # ways is populated later if nothing passed

# arg parsing
opts, args = getopt.gnu_getopt(sys.argv[1:], "f:c:d:l:w:", ['file=', 'count=', 'dictionary=', 'length=', 'ways='])
for opt, val in opts:
  if opt in ('-f', '--file'):
    if not os.path.exists(val): sys.exit("ERROR: wordsearch file %s does not exist" % val)
    wordsearch_file = val
  elif opt in ('-c', '--count'):
    if not re.match('^\d+$', val): sys.exit("ERROR: count %s is not an integer" % val)
    min_count = val
  elif opt in ('-d', '--dictionary'):
    if not os.path.exists(val): sys.exit("ERROR: dictionary file %s does not exist" % val)
    dictionary_file = val
  elif opt in ('-l', '--length'):
    if not re.match('^\d+$', val): sys.exit("ERROR: length %s is not an integer" % val)
    min_length = val
  elif opt in ('-w', '--ways'):
    ways_opts = val.split(',')
    for ways_opt in ways_opts:
      ways_opt.lower().strip()
      if not re.match('^([lr]|[ud][lr]?)$', ways_opt): print "WARNING: %s is not a valid way" % ways_opt
      else: ways[ways_opt] = 1

if not ways: ways = {'ul': 1, 'u': 1, 'ur': 1, 'l': 1, 'r': 1, 'dl': 1, 'd': 1, 'dr': 1}

# read dictionary to list
dictionary = set()
with open(dictionary_file, 'r') as df:
  for line in df.read().splitlines():
    if len(line) >= int(min_length): dictionary.add(line)
df.close()

# build found words
ws = []
with open(wordsearch_file) as wf:
  for wordsearch_line in wf.read().splitlines():
    ws.extend(wordsearch_line.split())

# offsets
xo, yo = {}, {}
for way in ('ul', 'l', 'dl'): xo[way] = -1
for way in ('u', 'd'):        xo[way] = 0
for way in ('ur', 'r', 'dr'): xo[way] = 1
for way in ('ul', 'u', 'ur'): yo[way] = -1
for way in ('l', 'r'):        yo[way] = 0
for way in ('dl', 'd', 'dr'): yo[way] = 1

x, y, words = 0, 0, {}
height = len(ws)
while y < height:
  x, width = 0, len(ws[y])
  while x < width:
    for way in ways.keys():
      xl, yl, str = x, y, '' 
      while 0 <= xl < width and 0 <= yl < height and ws[yl][xl]:
        str += ws[yl][xl]
        if str in dictionary:
          words.setdefault(str, [])
          words[str].append({'x': x, 'y': x, 'way': way})
        xl += xo[way]
        yl += yo[way]
    x += 1
  y += 1

print("%d %d+ words (searching %s)," % (len(words.keys()), int(min_length), ', '.join(sorted(ways.keys())))),
formatted = [];
for word in sorted(words.keys()):
  count = len(words[word])
  if count >= min_count:
    if count > 1: formatted.append("%s (%s)," % (word, count))
    else:         formatted.append(word)
print ', '.join(formatted)

