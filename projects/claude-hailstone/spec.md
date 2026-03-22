# Hailstone Numbers

Calculate and display the hailstone sequence (Collatz conjecture) for a given integer n.

- If n is even: next = n / 2
- If n is odd:  next = 3n + 1
- Stop when n reaches 1

## Interface
- CLI: accept n as an argument
- Print each step in the sequence
- Print total step count at the end

## Examples
Input: 6
Output: 6 -> 3 -> 10 -> 5 -> 16 -> 8 -> 4 -> 2 -> 1 (8 steps)

## Tech
- C# 13 / .NET 10
- Top-level statements, no boilerplate class/namespace
- Prefer records and pattern matching where appropriate

## Environment
- Run and build inside a Docker container
- Base image: mcr.microsoft.com/dotnet/sdk:10.0
- Dev workflow: docker compose up rebuilds and runs the app
- No dependency on local dotnet install
- Interactive CLI — requires stdin/tty
- docker compose run hailstone 6

## Workflow
- After each logical change, update PROMPTS.md with the prompt and any 
  notable decisions, then git add and commit with a descriptive message
- Keep commits atomic — one logical change per commit