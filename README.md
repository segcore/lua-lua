# lua-lua

Lua programming language parser, written in lua!

This is just my experimentation and learning programming language parsing.
Probably not useful for any real applications (yet?!)

## Run

`lua lua-lua.lua`

## Functionality

Can lex most of lua into tokens. Currently prints them to the screen.

### Known issues

- Does not support string escapes for `\ddd`, `\xXX`, `\u{XXX}`
- Does not support hexadecimal floating points (honestly?)
