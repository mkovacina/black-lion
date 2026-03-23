# static landing page called HomeBase

HomeBase is a static landing page.
It should be a home page for users that allow them to quickly easily get to sites that they chose.
There should be no server involved.
The page should be responsive, meaning it is functional on a phone, tablet, laptop, or desktop.

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