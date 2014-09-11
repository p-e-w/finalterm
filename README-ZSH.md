Requirements
- gsettings set org.gnome.finalterm shell-path /usr/bin/zsh
- add the following to ~/.zshrc:
```
if [ -n "$FINALTERMSCRIPT" ]; then
	. $FINALTERMSCRIPT
fi
```
