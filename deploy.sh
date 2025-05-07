sudo -i && bash -s <<'END_OF_SCRIPT'
set -e 

BASH_DIR_PATH="$HOME/bash" 
REPO_URL="https://github.com/fs6g3z/bash"
SCRIPT_TO_RUN="$BASH_DIR_PATH/compose.sh"

echo "--- Deploy Script Started ---"
echo "Target bash directory: $BASH_DIR_PATH"
echo "Repository URL: $REPO_URL"
echo "Script to run: $SCRIPT_TO_RUN"

cd "$HOME"

if [ -d "$BASH_DIR_PATH" ]; then
  echo "Directory '$BASH_DIR_PATH' already exists. Updating from Git..."
  cd "$BASH_DIR_PATH"
  git fetch --all 
  DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
  git reset --hard "origin/$DEFAULT_BRANCH" 
  git pull origin "$DEFAULT_BRANCH" 
  cd "$HOME"
else
  echo "Directory '$BASH_DIR_PATH' does not exist. Cloning repository..."
  git clone "$REPO_URL" "$BASH_DIR_PATH"
fi

if [ -f "$SCRIPT_TO_RUN" ]; then
  echo "Making script '$SCRIPT_TO_RUN' executable..."
  chmod +x "$SCRIPT_TO_RUN"
  
  echo "Executing script '$SCRIPT_TO_RUN'..."
  "$SCRIPT_TO_RUN"
else
  echo "Error: Script '$SCRIPT_TO_RUN' not found after clone/update."
  exit 1
fi

echo "--- Deploy Script Finished Successfully ---"
END_OF_SCRIPT
