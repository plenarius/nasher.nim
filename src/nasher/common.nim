import os, osproc

import cli
export cli

const nasherVersion* = "nasher 0.1.0"

template tryOrQuit*(msg: string, statements: untyped) =
  try:
    statements
  except:
    fatal(msg)

template tryOrQuit*(statements: untyped) =
  try:
    statements
  except:
    fatal(getCurrentExceptionMsg())

template sandwich*(statements: untyped) =
  stdout.write("\n")
  statements
  stdout.write("\n")

template doAfter*(val: var bool, statements: untyped) =
  if val:
    statements
  else:
    val = true

template doAfterDebug*(val: var bool, statements: untyped) =
  if isLogging(DebugPriority):
    if val:
      statements
    else:
      val = true

proc getPkgRoot*(baseDir = getCurrentDir()): string =
  ## Returns the first parent of baseDir that contains a nasher config
  result = baseDir.absolutePath()

  for dir in parentDirs(result):
    if existsFile(dir / "nasher.cfg"):
      return dir

proc getGlobalCfgFile*: string =
  getConfigDir() / "nasher" / "nasher.cfg"

proc getPkgCfgFile*(baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / "nasher.cfg"

proc getCacheDir*(file: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "cache" / file.extractFilename()

proc getBuildDir*(build: string, baseDir = getCurrentDir()): string =
  getPkgRoot(baseDir) / ".nasher" / "build" / build

proc isNasherProject*(dir = getCurrentDir()): bool =
  existsFile(getPkgCfgFile(dir))

proc getNwnInstallDir*: string =
  when defined(Linux):
    getHomeDir() / ".local" / "share" / "Neverwinter Nights"
  else:
    getHomeDir() / "Documents" / "Neverwinter Nights"

template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

proc execCmdOrDefault*(cmd: string, default = ""): string =
  let (output, errcode) = execCmdEx(cmd)
  if errcode != 0:
    default
  else:
    output

const helpAll* = """
nasher: a build tool for Neverwinter Nights projects

Usage:
  nasher init [options] [<dir> [<file>]]
  nasher list [options]
  nasher compile [options] [<target>]
  nasher pack [options] [<target>]
  nasher install [options] [<target>]
  nasher unpack [options] <file> [<dir>]

Commands:
  init           Initializes a nasher repository
  list           Lists the names and descriptions of all build targets
  compile        Compiles all nss sources for a build target
  pack           Converts, compiles, and packs all sources for a build target
  install        As pack, but installs the target file to the NWN install path
  unpack         Unpacks a file into the source tree
"""

const helpOptions* ="""
Global Options:
  -h, --help     Display help for nasher or one of its commands
  -v, --version  Display version information
  --config FILE  Use FILE rather than the package config file (can be repeated)

Logging:
  --debug        Enable debug logging
  --verbose      Enable additional messages about normal operation
  --quiet        Disable all logging except errors
  --no-color     Disable color output (automatic if not a tty)
"""

const helpInit* = """
Usage:
  nasher init [options] [<dir> [<file>]]

Description:
  Initializes a directory as a nasher project. If supplied, <dir> will be
  created if needed and set as the project root; otherwise, the current
  directory will be the project root.

  If supplied, <file> will be unpacked into the project root's source tree.

Options:
  --default      Automatically accept the default answers to prompts
"""

const helpList* = """
Usage:
  nasher list [options]

Description:
  Lists the names of all build targets. These names can be passed to the compile
  or pack commands. If called with --verbose, also lists the descriptions,
  source files, and the filename of the final target.
"""

const helpCompile* = """
Usage:
  nasher compile [options] [<target>]

Description:
  Compiles all nss sources for <target>. If <target> is not supplied, the first
  target supplied by the config files will be compiled. The input and output
  files are placed in $PKG_ROOT/.nasher/build/<target>.

  Compilation of scripts is handled automatically by 'nasher pack', so you only
  need to use this if you want to compile the scripts without converting gff
  sources and packing the target file.
"""

const helpPack* = """
Usage:
  nasher pack [options] [<target>]

Description:
  Converts, compiles, and packs all sources for <target>. If <target> is not
  supplied, the first target supplied by the config files will be packed. The
  assembled files are placed in $PKG_ROOT/.nasher/build/<target>, but the packed
  file is placed in $PKG_ROOT.

  If the packed file would overwrite an existing file, you will be prompted to
  overwrite the file. The newly packaged file will have a modification time
  equal to the modification time of the newest source file. If the packed file
  is newer than the existing file, the default is to overwrite the existing file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""

const helpInstall* = """
Usage:
  nasher install [options] [<target>]

Description:
  Converts, compiles, and packs all sources for <target>, then installs the
  packed file into the NWN installation directory. If <target> is not supplied,
  the first target found in the config files will be packed and installed.

  The location of the NWN install can be set in the [User] section of the global
  nasher configuration file (default '~/Documents/Neverwinter Nights').

  If the file to be installed would overwrite an existing file, you will be
  prompted to overwrite it. The default answer is to keep the newer file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""

const helpUnpack* = """
Usage:
  nasher unpack [options] <file>

Description:
  Unpacks <file> into the project source tree.

  Each extracted file is checked against the source tree (as defined in the 
  [Package] section of the package config). If the file exists in one location,
  it is copied there, overwriting the existing file. If the file exists in
  multiple folders, you will be prompted to select where it should be copied.

  If the extracted file does not exist in the source tree already, it is checked
  against each pattern listed in the [Rules] section of the package config. If
  a match is found, the file is copied to that location.

  If, after checking the source tree and rules, a suitable location has not been
  found, the file is copied into a folder in the project root called "unknown"
  so you can manually move it later.

  If an unpacked source would overwrite an existing source, you will be prompted
  to overwrite the file. The newly unpacked file will have a modification time
  less than or equal to the modification time of the file being unpacked. If the
  source file is newer than the existing file, the default is to overwrite the
  existing file.

Options:
  --yes, --no    Automatically answer yes/no to the overwrite prompt
  --default      Automatically accept the default answer to the overwrite prompt
"""
