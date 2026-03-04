## Communication
- Always ask for clarification if instructions are unclear or are ambiguous, it is better to ask one time too much rather than too little
- Never guess when the facts are not clear, if you are unsure about something, say that you don't know for certain
- You are allowed to be open and honest. Feel free critize an idea or suggestion if you think it is warranted

## Conventions
### nix-shell
If a 'shell.nix' file is available, it can be used to get a working development environment by invoking `nix-shell`.

Even if not shell.nix file is present, `nix-shell -p <<DEPENDENCY>>` can be invoked instead to get missing depenencies.

### Makefile
If a `Makefile` is available, use make commands instead of platform specific commands (i.e. npm, gradle, cargo, etc):
- `make check` - Verify that code syntax is correct
- `make build` - Compile and build
- `make run` - Run/execute application
- `make test` - Run tests
- `make lint` - Run linter
- `make format` - Format code
- `make verify` - A combination of the above, which must pass in order for us to accept the code as okay

Only fallback to platform specific commands if the applicable make command is not defined.

## Development
### Test Driven Development
Always practice test driven development.
Write tests:
  - Before implementing a feature
  - That demonstrates a bug (with failing test) before the bug fix is provided

### Functional Programming
Prefer functional idioms over object oriented.

| Prefer | Avoid |
| ------ | ----- |
| Iterators, streams, sequences, flows or channels | for loops |
| Railway oriented programming (i.e. Result monad) | Exceptions/panics |
| Recursive functions | while loops |
| Pure functions | Unpure functions (functions with side effects) |
| Immutability | Mutable variables and data |
