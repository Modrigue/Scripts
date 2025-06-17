@REM List installed and current distributions
wsl -l -v

@REM Set default distribution
wsl --set-default <DISTRIBUTION_NAME>

@REM find files in current directory containing "foo" (case insensitive)
wsl sh -c "find . -type f -exec grep -i -l 'foo' '{}' +"

