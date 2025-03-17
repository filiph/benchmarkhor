#!/bin/bash

# Takes stdin, puts it into a file, and asks timg to show it.
AS_FILE=$(mktemp)
cat - > "$AS_FILE"
timg -p iterm2 "$AS_FILE"
rm "$AS_FILE"
