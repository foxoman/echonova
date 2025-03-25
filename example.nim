# Example usage of the EchoNova library
import os
import echonova

# You can either use the global CLI instance:
displayInfo("Starting application")
displaySuccess("Configuration loaded successfully")

# Or create your own instance:
var echo = newEchoNova()
echo.setVerbosity(MediumPriority)
echo.setShowColor(true)

# Basic message display
echo.display("Status", "Processing files", Message)
echo.displaySuccess("Files processed successfully")
echo.displayWarning("Some files were skipped")

# Progress indication
for i in 1 .. 5:
  echo.displayProgress("Processing item " & $i)
  # Simulate work
  sleep(500)

# Reset progress display when done
echo.displayLineReset()
echo.displaySuccess("All items processed")

  # Error handling
try:
    # Simulate an error
    raise newException(IOError, "Could not open file")
except IOError as e:
    echo.displayError(e) # Using the DisplayError with hint

let err = newDisplayError(
  "Failed to connect to server", "Check your network connection and try again"
)
echo.displayError(err)

# Interactive prompts
if echo.prompt(dontForcePrompt, "Do you want to continue?"):
  echo.displayInfo("Continuing...")
else:
  echo.displayInfo("Operation cancelled")

let name = echo.promptCustom("Enter your name", "User")
echo.displayInfo("Hello, " & name)

# List selection
let option = echo.promptList(
  dontForcePrompt, "Choose an option", ["Option 1", "Option 2", "Option 3"]
)
echo.displayInfo("You selected: " & option) # Show suppression tips at the end
echo.displayTip()
