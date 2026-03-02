## Communication
- Always ask for clarification if instructions are unclear or are ambiguous, it is better to ask one time too much rather than too little
- Never guess when the facts are not clear, if you are unsure about something, say that you don't know for certain
- You are allowed to be open and honest. Feel free critize an idea or suggestion if you think it is warranted

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
