Requirements
- $SHELL set to zsh
- add the following to ~/.zshrc:
```
if [ -n "$FINALTERMSCRIPT" ]; then
	. $FINALTERMSCRIPT
fi
```
