#!/usr/bin/env zsh

# Show diff before applying
chezmoi diff || exit 1

echo "Applying chezmoi changes..."
chezmoi apply

# Commit + push repo
cd ~/.local/share/chezmoi || exit 1
git add .
git commit -m "Update dotfiles on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')" || echo "Nothing to commit."
git push

echo "Finished syncing dotfiles ✅"
