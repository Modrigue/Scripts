#!/bin/bash

# find files in current directory containing "foo" (case sensitive)
find . -type f -exec grep -l "foo" {} +

# find files in current directory containing "foo" (case insensitive)
find . -type f -exec grep -i -l "foo" {} +

# WSL: find files in current directory containing "foo" (case insensitive)
wsl sh -c "find . -type f -exec grep -i -l 'foo' '{}' +"

# find files in current directory named "foo" (case sensitive)
find . -type f -name "*foo*"

# find files in current directory named "foo" (case insensitive)
find . -type f -iname "*foo*"

# find files in current directory with extension ".foo" (case sensitive)
find . -type f -name "*.foo"

# find files in current directory with extension ".foo" (case insensitive)
find . -type f -iname "*.foo"
