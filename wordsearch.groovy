#!/usr/local/bin/groovy
import org.apache.commons.cli.Option

CliBuilder cli = new CliBuilder(
  usage: "${this.class.simpleName}.groovy -f filename [options]",
  header: 'Options:',
  footer: "\nReport bugs to <stephen@menton.me>"
)
cli.with {
  h longOpt: 'help', 'Show usage information'
  f(longOpt: 'file', args: 1, argName: 'filename', required: false, 'file containing wordsearch content')
  c(longOpt: 'count',      args: 1, argName: 'count',      'minimum count per word (default is 1)')
  d(longOpt: 'dictionary', args: 1, argName: 'dictionary', 'dictionary file to use')
  l(longOpt: 'length',     args: 1, argName: 'length',     'minimum word length (default is 3)')
  w(longOpt: 'way', args: Option.UNLIMITED_VALUES, argName: 'way', valueSeparator: ',', 'comma delimited way(s) to search (ul,u,ur,l,r,dl,d,dr)')
}
OptionAccessor options = cli.parse(args)

int length = options.length ? options.length.toInteger() : 3
int count  = options.count  ? options.count.toInteger()  : 1

// wordsearch file
File wsFile = new File(options.file)
assert wsFile.exists()  : "wordsearch file does not exist"
assert wsFile.canRead() : "wordsearch file cannot be read"
List content = wsFile.readLines()

// dictionary file
File dictFile = new File(options.dictionary ?: '/usr/share/dict/words')
assert dictFile.exists()  : "dictionary file does not exist"
assert dictFile.canRead() : "dictionary file cannot be read"
List dict = dictFile.readLines().findAll { it.length() >= length }.collect { it.toLowerCase() }

List ways = options.ways ?: ['ul', 'u', 'ur', 'l', 'r', 'dl', 'd', 'dr']

// load dictionary
int height = content.size()
int width  = content.max { it.size() }.size()
Map puzzle = [:]
for (y = 0; y < height; y++) {
  for (x = 0; x < width; x++) {
    puzzle[[y, x]] = content.getAt(y).toCharArray().getAt(x)
  }
}

Map offsetX = [:]
Map offsetY = [:]
for (way in ['ul', 'l', 'dl']) { offsetX[way] = -1 }
for (way in ['u',  'd'])       { offsetX[way] = 0  }
for (way in ['ur', 'r', 'dr']) { offsetX[way] = 1  }
for (way in ['ul', 'u', 'ur']) { offsetY[way] = -1 }
for (way in ['l',  'r'])       { offsetY[way] = 0  }
for (way in ['dl', 'd', 'dr']) { offsetY[way] = 1  }

Map words = [:]
for (int y = 0; y < height; y++) {
  for (int x = 0; x < width; x++) {
    for (way in ways) {
      int localX = x
      int localY = y
      String word = ''
      while (localX >= 0 && localY >= 0 && puzzle[[localY, localX]] != null) {
        word += puzzle[[localY, localX]]
        if (dict.contains(word)) {
          words[word] = (words[word] ?: 0) + 1
        }
        localX += offsetX[way]
        localY += offsetY[way]
      }
    }
  }
}

print "${words.size()} ${length}+ words (searching ${ways.join ', '})"
words.sort { it.key }.each { k, v ->
  if (v >= count) {
    printf(", ${k}%s", v > 1 ? " (${v})" : '')
  }
}
print "\n"
