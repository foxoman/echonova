# EchoNova

A modern, flexible library for message display with progress indicators in Nim applications.

> Library extracted from [Nimble CLI source code](https://github.com/nim-lang/nimble/blob/master/src/nimblepkg/cli.nim) for easy reuse in any Nim application.

## Features

- 🎨 **Color-coded messages**: Different colors for success, error, warnings, and more
- 🔄 **Progress indicators**: Animated spinners for long-running operations
- 📊 **Priority levels**: Control message verbosity with customizable priority levels
- 🖥️ **Interactive prompts**: Yes/no, custom, and list selection prompts with keyboard navigation
- 🌈 **Terminal-aware**: Falls back gracefully when not in an interactive terminal
- 🧩 **Modular design**: Use the global instance or create your own instances for different parts of your application

## Philosophy for Message Display

- **Green** is shown when operations are successful
- **Blue** emphasizes keywords and actions (e.g., "Downloading", "Reading")
- **Red** indicates operation failures
- **Yellow** is used for warnings
- Priority levels:
  - **Dim** for LowPriority
  - **Bright** for HighPriority
  - **Normal** for MediumPriority

## Installation
Get always the last release:

```bash
nimble install https://github.com/foxoman/echonova@#head
```

## Basic Usage

```nim
import echonova

# Using the global instance
displayInfo("Starting application")
displaySuccess("Configuration loaded successfully")

# Create a custom instance
var echo = newEchoNova()
echo.setVerbosity(MediumPriority)

# Display different message types
echo.displayInfo("Processing files")
echo.displayWarning("Some files were skipped")
echo.displayError("Failed to process a file")

# Show progress for long-running operations
for i in 1..5:
  echo.displayProgress("Processing item " & $i)
  # Do work...
  sleep(500)

# Reset progress spinner when done
echo.displayLineReset()
echo.displaySuccess("All items processed")
```

## Interactive Prompts

```nim
# Yes/No prompt
if echo.prompt(dontForcePrompt, "Do you want to continue?"):
  echo.displayInfo("Continuing...")
else:
  echo.displayInfo("Operation cancelled")

# Custom prompt with default value
let name = echo.promptCustom("Enter your name", "User")
echo.displayInfo("Hello, " & name)

# List selection with interactive navigation
let option = echo.promptList(dontForcePrompt, "Choose an option",
                           ["Option 1", "Option 2", "Option 3"])
echo.displayInfo("You selected: " & option)
```

## Error Handling

```nim
try:
  # Some operation that might fail
  raise newException(IOError, "Could not open file")
except IOError as e:
  echo.displayError(e)

# Using the DisplayError with hint
let err = newDisplayError("Failed to connect to server",
                         "Check your network connection and try again")
echo.displayError(err)
```

## Customization

```nim
# Set verbosity level
echo.setVerbosity(DebugPriority)  # Show all messages including debug

# Enable/disable colored output
echo.setShowColor(true)

# Suppress certain message types
echo.setSuppressMessages(true)

# Change spinner characters
setSpinChars(["◐", "◓", "◑", "◒", "◐", "◓", "◑", "◒"])
```

## License

BSD License. See license.txt for more info.
