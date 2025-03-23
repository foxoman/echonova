# EchoNova - A library for message display with progress indicators
# Copyright (C) 2025. All rights reserved.
# BSD License. See license.txt for more info.
#
# Philosophy for the messages that EchoNova displays:
#   - Green is only shown when the requested operation is successful.
#   - Blue can be used to emphasize certain keywords, for example actions such
#     as "Downloading" or "Reading".
#   - Red is used when the requested operation fails with an error.
#   - Yellow is used for warnings.
#
#   - Dim for LowPriority.
#   - Bright for HighPriority.
#   - Normal for MediumPriority.

import terminal, sets, strutils

export terminal # Re-export terminal to avoid additional imports

type
  EchoNova* = ref object
    level*: Priority
    warnings: HashSet[(string, string)]
    suppressionCount*: int ## Amount of messages which were not shown.
    showColor*: bool ## Whether messages should be colored.
    suppressMessages*: bool ## Whether Warning, Message and Success messages
                           ## should be suppressed, useful for
                           ## commands whose output should be machine readable.

  Priority* = enum
    DebugPriority, LowPriority, MediumPriority, HighPriority, SilentPriority

  DisplayType* = enum
    Error, Warning, Details, Hint, Message, Success, Progress 

  ForcePrompt* = enum
    dontForcePrompt, forcePromptYes, forcePromptNo
    
  DisplayError* = object of CatchableError
    hint*: string  # Hint to display after the error

const
  longestCategory = len("Downloading")
  foregrounds: array[Error .. Progress, ForegroundColor] =
    [fgRed, fgYellow, fgBlue, fgWhite, fgCyan, fgGreen, fgMagenta]
  styles: array[DebugPriority .. HighPriority, set[Style]] =
    [{styleDim}, {styleDim}, {}, {styleBright}]

var 
  lastWasDot = false
  lastCharidx = 0
  spinChars: array[0..7, string] = ["⣷","⣯","⣟","⡿","⢿","⣻","⣽","⣾"]

proc newEchoNova*(): EchoNova =
  ## Creates a new EchoNova instance
  result = EchoNova(
    level: HighPriority,
    showColor: true,
  )

var globalCLI* = newEchoNova()

proc calculateCategoryOffset(category: string): int =
  assert category.len <= longestCategory
  return longestCategory - category.len

proc isSuppressed(cli: EchoNova, displayType: DisplayType): bool =
  # Don't print any Warning, Message or Success messages when suppression of
  # warnings is enabled. That is, unless the user asked for --verbose output.
  if cli.suppressMessages and displayType >= Warning and
     cli.level == HighPriority:
    return true

proc displayFormatted*(cli: EchoNova, displayType: DisplayType, msgs: varargs[string]) =
  ## For styling outputs lines using the DisplayTypes
  for msg in msgs:
    if cli.showColor:
      stdout.styledWrite(foregrounds[displayType], msg)
    else:
      stdout.write(msg)

proc displayInfoLine*(cli: EchoNova, field, msg: string) =
  ## Display an information line with field and message
  cli.displayFormatted(Success, field)
  cli.displayFormatted(Details, msg)
  cli.displayFormatted(Hint, "\n")

proc displayCategory(cli: EchoNova, category: string, displayType: DisplayType,
                     priority: Priority) =
  if cli.isSuppressed(displayType):
    return

  # Calculate how much the `category` must be offset to align along a center
  # line.
  let offset = calculateCategoryOffset(category)

  # Display the category.
  let text = "$1$2 " % [spaces(offset), category]
  if cli.showColor:
    if priority != DebugPriority:
      setForegroundColor(stdout, foregrounds[displayType])
    writeStyled(text, styles[priority])
    resetAttributes()
  else:
    stdout.write(text)

proc displayLineReset*(cli: EchoNova) =
  if lastWasDot:
    try:
      stdout.cursorUp(1)
      stdout.eraseLine()
    except OSError:
      discard # this breaks on windows a lot so we ignore it
    lastWasDot = false

proc displayLine(cli: EchoNova, category, line: string, displayType: DisplayType,
                 priority: Priority) =
  cli.displayLineReset()

  if cli.isSuppressed(displayType):
    stdout.write "+"
    return

  cli.displayCategory(category, displayType, priority)

  # Display the message.
  if displayType != Progress:
    echo(line)
  else:
    stdout.write(spinChars[lastCharidx], " ", line, "\n")
    lastCharidx = (lastCharidx + 1) mod spinChars.len()
    stdout.flushFile()
    lastWasDot = true

proc display*(cli: EchoNova, category, msg: string, displayType = Message,
              priority = MediumPriority) =
  ## Display a message with the specified category, display type, and priority
  # Multiple warnings containing the same messages should not be shown.
  let warningPair = (category, msg)
  if displayType == Warning:
    if warningPair in cli.warnings:
      return
    else:
      cli.warnings.incl(warningPair)

  # Suppress this message if its priority isn't high enough.
  if priority < cli.level:
    if priority != DebugPriority:
      cli.suppressionCount.inc
    if cli.showColor and cli.level != SilentPriority:
      # some heuristics here
      if category == "Executing" and msg.endsWith("printPkgInfo"):
        cli.displayLine("Scanning", "", Progress, HighPriority)
      elif msg.startsWith("git"):
        cli.displayLine("Updating", "", Progress, HighPriority)
      else:
        cli.displayLine("Working", "", Progress, HighPriority)
    return

  # Display each line in the message.
  var i = 0
  for line in msg.splitLines():
    if len(line) == 0: continue
    cli.displayLine(if i == 0: category else: "...", line, displayType, priority)
    i.inc

# Convenience methods for global CLI instance
proc display*(category, msg: string, displayType = Message,
              priority = MediumPriority) =
  ## Use the global CLI instance to display a message
  globalCLI.display(category, msg, displayType, priority)

# Common display methods for specific message types
proc displayWarning*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display a warning message
  cli.display("Warning: ", message, Warning, priority)

proc displayHint*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display a hint message
  cli.display("Hint: ", message, Hint, priority)

proc displayDetails*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display details message
  cli.display("Details: ", message, Details, priority)

proc displaySuccess*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display a success message
  cli.display("Success: ", message, Success, priority)

proc displayError*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display an error message
  cli.display("Error: ", message, Error, priority)

proc displayInfo*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display an info message
  cli.display("Info: ", message, Message, priority)

proc displayProgress*(cli: EchoNova, message: string, priority = HighPriority) =
  ## Display a progress message with spinner
  cli.display("Progress: ", message, Progress, priority)

# Error object methods
proc displayDetails*(cli: EchoNova, error: ref CatchableError, priority = HighPriority) =
  ## Display details for a CatchableError
  cli.displayDetails(error.msg, priority)
  if error.parent != nil:
    cli.displayDetails((ref CatchableError)(error.parent), priority)

proc displayError*(cli: EchoNova, error: ref CatchableError, priority = HighPriority) =
  ## Display an error for a CatchableError
  cli.displayError(error.msg, priority)
  if error.parent != nil:
    cli.displayDetails((ref CatchableError)(error.parent), priority)

proc displayError*(cli: EchoNova, error: DisplayError, priority = HighPriority) =
  ## Display an error for a DisplayError with hint
  cli.displayError(error.msg, priority)
  if error.hint.len > 0:
    cli.displayHint(error.hint, priority)
  if error.parent != nil:
    cli.displayDetails((ref CatchableError)(error.parent), priority)

proc displayWarning*(cli: EchoNova, error: ref CatchableError, priority = HighPriority) =
  ## Display a warning for a CatchableError
  cli.displayWarning(error.msg, priority)
  if error.parent != nil:
    cli.displayDetails((ref CatchableError)(error.parent), priority)

# Global convenience methods
proc displayWarning*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display a warning
  globalCLI.displayWarning(message, priority)

proc displayHint*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display a hint
  globalCLI.displayHint(message, priority)

proc displayDetails*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display details
  globalCLI.displayDetails(message, priority)

proc displaySuccess*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display a success message
  globalCLI.displaySuccess(message, priority)

proc displayError*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display an error
  globalCLI.displayError(message, priority)

proc displayInfo*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display info
  globalCLI.displayInfo(message, priority)

proc displayProgress*(message: string, priority = HighPriority) =
  ## Use the global CLI instance to display progress
  globalCLI.displayProgress(message, priority)

# Error display for global CLI
proc displayDetails*(error: ref CatchableError, priority = HighPriority) =
  ## Use the global CLI instance to display error details
  globalCLI.displayDetails(error, priority)

proc displayError*(error: ref CatchableError, priority = HighPriority) =
  ## Use the global CLI instance to display an error
  globalCLI.displayError(error, priority)

proc displayWarning*(error: ref CatchableError, priority = HighPriority) =
  ## Use the global CLI instance to display a warning
  globalCLI.displayWarning(error, priority)

proc displayDebug*(cli: EchoNova, category, msg: string) =
  ## Convenience for displaying debug messages with a custom category
  cli.display(category, msg, priority = DebugPriority)

proc displayDebug*(cli: EchoNova, msg: string) =
  ## Convenience for displaying debug messages with a default category
  cli.displayDebug("Debug:", msg)

proc displayDebug*(category, msg: string) =
  ## Use the global CLI instance to display a debug message with category
  globalCLI.displayDebug(category, msg)

proc displayDebug*(msg: string) =
  ## Use the global CLI instance to display a debug message
  globalCLI.displayDebug(msg)

proc displayTip*(cli: EchoNova) =
  ## Display tips about message suppression
  if cli.suppressionCount > 0:
    let msg = "$1 messages have been suppressed, use --verbose to show them." %
             $cli.suppressionCount
    cli.display("Tip:", msg, Warning, HighPriority)

proc displayTip*() =
  ## Use the global CLI instance to display tips
  globalCLI.displayTip()

# Prompt functions
proc prompt*(cli: EchoNova, forcePrompts: ForcePrompt, question: string): bool =
  ## Display a yes/no prompt and return the result
  case forcePrompts
  of forcePromptYes:
    cli.display("Prompt:", question & " -> [forced yes]", Warning, HighPriority)
    return true
  of forcePromptNo:
    cli.display("Prompt:", question & " -> [forced no]", Warning, HighPriority)
    return false
  of dontForcePrompt:
    if cli.level != SilentPriority:
      cli.display("Prompt:", question & " [y/N]", Warning, HighPriority)
      cli.displayCategory("Answer:", Warning, HighPriority)
      let yn = stdin.readLine()
      case yn.normalize
      of "y", "yes":
        return true
      of "n", "no":
        return false
      else:
        return false
    else:
      # Just say "yes" to every prompt, since we need to be
      # 100% silent.
      return true

proc prompt*(forcePrompts: ForcePrompt, question: string): bool =
  ## Use the global CLI instance for a yes/no prompt
  return globalCLI.prompt(forcePrompts, question)

proc promptCustom*(cli: EchoNova, forcePrompts: ForcePrompt, question, default: string): string =
  ## Display a custom prompt with default value
  case forcePrompts:
  of forcePromptYes:
    cli.display("Prompt:", question & " -> [forced " & default & "]", Warning,
      HighPriority)
    return default
  else:
    if default == "":
      cli.display("Prompt:", question, Warning, HighPriority)
      cli.displayCategory("Answer:", Warning, HighPriority)
      let user = stdin.readLine()
      if user.len == 0: return cli.promptCustom(forcePrompts, question, default)
      else: return user
    else:
      cli.display("Prompt:", question & " [" & default & "]", Warning, HighPriority)
      cli.displayCategory("Answer:", Warning, HighPriority)
      let user = stdin.readLine()
      if user == "": return default
      else: return user

proc promptCustom*(forcePrompts: ForcePrompt, question, default: string): string =
  ## Use the global CLI instance for a custom prompt
  return globalCLI.promptCustom(forcePrompts, question, default)

proc promptCustom*(cli: EchoNova, question, default: string): string =
  ## Display a custom prompt with default value using dontForcePrompt
  return cli.promptCustom(dontForcePrompt, question, default)

proc promptCustom*(question, default: string): string =
  ## Use the global CLI instance for a custom prompt
  return globalCLI.promptCustom(question, default)

proc promptListInteractive(cli: EchoNova, question: string, args: openarray[string]): string =
  ## Display an interactive list prompt with arrow key navigation
  cli.display("Prompt:", question, Warning, HighPriority)
  cli.display("Select", "Cycle with 'Tab', 'Enter' when done", Message,
    HighPriority)
  cli.displayCategory("Choices:", Warning, HighPriority)
  var
    current = 0
    selected = false
  # In case the cursor is at the bottom of the terminal
  for arg in args:
    stdout.write "\n"
  # Reset the cursor to the start of the selection prompt
  cursorUp(stdout, args.len)
  cursorForward(stdout, longestCategory)
  hideCursor(stdout)

  # The selection loop
  while not selected:
    setForegroundColor(fgDefault)
    # Loop through the options
    for i, arg in args:
      # Check if the option is the current
      if i == current:
        writeStyled("> " & arg & " <", {styleBright})
      else:
        writeStyled("  " & arg & "  ", {styleDim})
      # Move the cursor back to the start
      for s in 0..<(arg.len + 4):
        cursorBackward(stdout)
      # Move down for the next item
      cursorDown(stdout)
    # Move the cursor back up to the start of the selection prompt
    for i in 0..<(args.len()):
      cursorUp(stdout)
    resetAttributes(stdout)

    # Ensure that the screen is updated before input
    flushFile(stdout)
    # Begin key input
    while true:
      case getch():
      of '\t':
        current = (current + 1) mod args.len
        break
      of '\r':
        selected = true
        break
      of '\3':
        showCursor(stdout)
        raise newException(CatchableError, "Keyboard interrupt")
      of '\27':
        if getch() != '\91': continue
        case getch():
        of char(65): # Up arrow
          current = (args.len + current - 1) mod args.len
          break
        of char(66): # Down arrow
          current = (current + 1) mod args.len
          break
        else: discard
      else: discard

  # Erase all lines of the selection
  for i in 0..<args.len:
    eraseLine(stdout)
    cursorDown(stdout)
  # Move the cursor back up to the initial selection line
  for i in 0..<args.len():
    cursorUp(stdout)
  showCursor(stdout)
  cli.display("Answer:", args[current], Warning, HighPriority)
  return args[current]

proc promptListFallback(cli: EchoNova, question: string, args: openarray[string]): string =
  ## Fallback for non-TTY terminals
  cli.display("Prompt:", question & " [" & join(args, "/") & "]", Warning,
    HighPriority)
  cli.displayCategory("Answer:", Warning, HighPriority)
  result = stdin.readLine()
  for arg in args:
    if arg.cmpIgnoreCase(result) == 0:
      return arg

proc promptList*(cli: EchoNova, forcePrompts: ForcePrompt, question: string, args: openarray[string]): string =
  ## Display a list prompt
  case forcePrompts:
  of forcePromptYes:
    result = args[0]
    cli.display("Prompt:", question & " -> [forced " & result & "]", Warning,
      HighPriority)
  else:
    if isatty(stdout):
      return cli.promptListInteractive(question, args)
    else:
      return cli.promptListFallback(question, args)

proc promptList*(forcePrompts: ForcePrompt, question: string, args: openarray[string]): string =
  ## Use the global CLI instance for a list prompt
  return globalCLI.promptList(forcePrompts, question, args)

proc setVerbosity*(cli: EchoNova, level: Priority) =
  ## Set the verbosity level for messages
  cli.level = level

proc setVerbosity*(level: Priority) =
  ## Set the verbosity level for the global CLI instance
  globalCLI.level = level

proc setShowColor*(cli: EchoNova, val: bool) =
  ## Enable or disable colored output
  cli.showColor = val

proc setShowColor*(val: bool) =
  ## Enable or disable colored output for global CLI
  globalCLI.showColor = val

proc setSuppressMessages*(cli: EchoNova, val: bool) =
  ## Enable or disable message suppression
  cli.suppressMessages = val

proc setSuppressMessages*(val: bool) =
  ## Enable or disable message suppression for global CLI
  globalCLI.suppressMessages = val

proc setSpinChars*(newSpinChars: array[0..7, string]) =
  ## Set custom spinner characters
  spinChars = newSpinChars

# Helper for creating a DisplayError
proc newDisplayError*(msg, hint: string): ref DisplayError =
  ## Create a new DisplayError with a hint
  result = new DisplayError
  result.msg = msg
  result.hint = hint
