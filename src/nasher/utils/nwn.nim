import json, os, osproc, streams, strformat, strutils
from sequtils import mapIt, toSeq
import cli

const
  Options = {poUsePath, poStdErrToStdOut}

  GffExtensions* = @[
    "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw",
    "git", "are", "gic", "mod", "ifo", "fac", "dlg", "itp", "bic",
    "jrl", "gff", "gui"
  ]

proc gffToJson(file, bin, args: string): JsonNode =
  ## Converts ``file`` to json, stripping the module ID if ``file`` is
  ## module.ifo.
  let
    cmd = join([bin, args, "-i", file, "-k json -p"], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not parse {file}: {output}")

  result = output.parseJson

  ## TODO: truncate floats
  if file.extractFilename == "module.ifo" and result.hasKey("Mod_ID"):
    result.delete("Mod_ID")


proc jsonToGff(inFile, outFile, bin, args: string) =
  ## Converts a json ``inFile`` to an erf ``outFile``.
  let
    cmd = join([bin, args, "-i", inFile, "-o", outFile], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not convert {inFile}: {output}")

proc gffConvert*(inFile, outFile, bin, args: string) =
  ## Converts ``inFile`` to ``outFile``
  let
    (dir, name, ext) = outFile.splitFile
    fileType = ext.strip(chars = {'.'})
    outFormat = if fileType in GffExtensions: "gff" else: fileType

  try:
    createDir(dir)
  except OSError:
    let msg = osErrorMsg(osLastError())
    fatal(fmt"Could not create {dir}: {msg}")

  let category = if outFormat in ["json", "gff"]: "Converting" else: "Copying"
  info(category, "$1 -> $2" % [inFile.extractFilename, name & ext])

  ## TODO: Add gron and yaml support
  case outFormat
  of "json":
    let text = gffToJson(inFile, bin, args).pretty
    writeFile(outFile, text)
  of "gff":
    jsonToGff(inFile, outFile, bin, args)
  else:
    copyFile(inFile, outFile)

proc removeUnusedAreas*(dir, bin, args: string) =
  ## Removes any areas not in ``dir`` from the module.ifo file in ``dir``.
  let
    fileGff = dir / "module.ifo"
    fileJson = fileGff & ".json"
    areas = toSeq(walkFiles(dir / "*.are")).mapIt(it.splitFile.name)

  if not existsFile(fileGff):
    return

  var
    ifoJson = gffToJson(fileGff, bin, args)
    ifoAreas: seq[JsonNode]

  let
    entryArea = ifoJson["Mod_Entry_Area"]["value"].getStr

  if entryArea notin areas:
    fatal("This module does not have a valid starting area!")

  for key, value in ifoJson["Mod_Area_list"]["value"].getElems.pairs:
    let area = value["Area_Name"]["value"].getStr
    if area in areas:
      ifoAreas.add(value)
    else:
      info("Removing", fmt"unused area {area.escape} from module.ifo")

  ifoJson["Mod_Area_list"]["value"] = %ifoAreas
  writeFile(fileJson, $ifoJson)
  jsonToGff(fileJson, fileGff, bin, args)
  removeFile(fileJson)

proc updateHaks*(dir, bin, args, haksDir: string) =
  ## Rebuilds the hak list based on the .hak files present in the configurated `haksLocation` folder.
  if isNilOrWhitespace haksDir:
    return
  let
    fileGff = dir / "module.ifo"
    fileJson = fileGff & ".json"
    haks = toSeq(walkFiles(haksDir / "*.hak")).mapIt(it.splitFile.name)

  if not existsFile(fileGff):
    return

  var
    ifoJson = gffToJson(fileGff, bin, args)
    ifoHaks: seq[JsonNode]

  for hak in haks:
    var hak_json = %* {"__struct_id": 8,"Mod_Hak": {"type": "cexostring","value": hak}}
    ifoHaks.add(hak_json)
    info("Adding", fmt"hak {hak.escape} to module.ifo")

  ifoJson["Mod_HakList"]["value"] = %ifoHaks
  writeFile(fileJson, $ifoJson)
  jsonToGff(fileJson, fileGff, bin, args)
  removeFile(fileJson)

proc extractErf*(file, bin, args: string) =
  ## Extracts the erf ``file`` into the current directory.
  let
    cmd = join([bin, args, "-x -f", file], " ")
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not extract {file}: {output}")

proc createErf*(dir, outFile, bin, args: string, noPackNSS: bool) =
  ## Creates an erf file at ``outFile`` from all files in ``dir``, passing
  ## ``args`` to the ``nwn_erf`` utiltity.
  var cmd: string
  if not noPackNSS:
      cmd = join([bin, args, "-c -f", outFile, dir / "*"], " ")
  else:
      cmd = join([bin, args, "-c -f", outFile, dir / "{*.ut?,*.are,*.dlg,*.fac,*.git,*.ifo,*.itp,*.jrl,*.ncs}"], " ")

  let
    (output, errCode) = execCmdEx(cmd, Options)

  if errCode != 0:
    fatal(fmt"Could not pack {outFile}: {output}")
