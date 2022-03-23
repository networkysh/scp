import times, os
import random, math
import strutils
import httpclient, htmlparser, xmltree, strtabs
import sequtils
import parseopt2, pegs


let version = "0.1.3"
let doc = """
SCP-Wiki Reader.

Usage:
  scp 2019
    - Read scp entry 2019.
  scp (-h | --help | -ic | --version | --nocache | --no-pic) <num>
    - Reads a random SCP entry.

Options:
  -h --help       Show this screen.
  --version       Show the current version.
  -ic            Set imagecat path.
  --nocache       Don't cache the SCP entry.
  --no-pic        Don't show pictures with imgcat if avaliable.
"""

proc epoch_int(): int = int(round(epochTime() * 100))

proc gen_scp_num(): int =
  return toSeq(1..2999)[random(2998) + 1]

proc shell_program_exists(name: string): bool =
  return not (execShellCmd("/usr/bin/type -P $1" % name) == 1)

proc read_scp(data: XMLNode) =
  for s_node in data.findAll("p"):
    echo s_node.innerText().strip()

proc find_image_url(node: XMLNode): string =
  for s_div in node.findAll("img"):
    for attrb in s_div.attrs().pairs():
      if attrb[0] == "class" and attrb[1] == "image":
        return s_div.attr("src")
  return nil

proc find_page_content(node: XMLNode): XMLNode =
  for s_div in node.findAll("div"):
    for attrb in s_div.attrs().pairs():
      if attrb[0] == "id" and attrb[1] == "page-content":
        return s_div
  return nil


proc main() =
  randomize epoch_int()
  var no_cache = false
  var show_picture = true
  var imgcat_path = "imgcat"
  var rand_num = gen_scp_num()
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      try:
        rand_num = parseInt(key)
      except ValueError:
        echo "failed to parse scp number. (invalid int) [$2]" % getCurrentExceptionMsg().strip()
        return
    of cmdShortOption, cmdLongOption:
      case key
      of "help", "h": echo doc; return
      of "nocache", "nc": no_cache = true
      of "ic": imgcat_path = val
      of "no-picture", "no-pic": show_picture = false
      of "version":
        echo version
        return
      else: discard
    of cmdEnd: discard

  let http_client = newHttpClient()
  var url = "<undefined>"
  try:
    let config_file = "/etc/scp-reader/imgcat-path"
    if not shell_program_exists("imgcat"):
      if existsFile(config_file):
        imgcat_path = readFile config_file

    var temp_file = "cached/scp-$1.html" % $rand_num
    # save file for loading / caching
    url = "http://www.scp-wiki.net/scp-$1" % intToStr(rand_num, (if rand_num < 1000: 3 else: 1 ))
    if not no_cache:
      if not existsDir("cached"):
        createDir("cached")
      if not existsFile(temp_file):
        writeFile(temp_file, http_client.getContent(url))
    else:
      temp_file = "/tmp/scp-reader/scp-$1.html" % $rand_num

    let scp_html = loadHTML(temp_file)
    let page_content_div = find_page_content(scp_html)
    let image_url = find_image_url(page_content_div)
    let image_path = "cached/images/scp-$1.jpg" % $rand_num
    if show_picture and image_url != nil:
      if not existsDir("cached/images"):
        createDir("cached/images")
      writeFile(image_path, http_client.getContent(image_url))

    if page_content_div != nil:
      discard execShellCmd("$1 $2" % [imgcat_path, image_path])
      read_scp(page_content_div)
    else:
      echo "[err-non-fatal]: could not find page-content div. invalid html?"
  except HttpRequestError:
    echo repr(getCurrentException())
  except:
    echo "[err] $1 link=[\"$2\"]" % [toLowerAscii(getCurrentExceptionMsg()), toLowerAscii(url)]


main()
