# Prompts & Decisions

## Implement Hailstone CLI

**Prompt:**
> Implement the following plan:
> - `Hailstone.csproj` — targets net10.0, LangVersion 13
> - `Program.cs` — top-level statements, pattern matching switch for even/odd, prints sequence and step count
> - `Dockerfile` — build and run with `mcr.microsoft.com/dotnet/sdk:10.0`
> - `docker-compose.yml` — service named `hailstone`, passes CLI args through

**Notable decisions:**
- Used `long` instead of `int` to avoid overflow on large sequences
- Iterator method (`IEnumerable<long>`) keeps sequence generation lazy
- Pattern matching switch expression for even/odd rule: `n switch { var x when x % 2 == 0 => x / 2, var x => 3 * x + 1 }`
- Step count = `sequence.Count - 1` (excludes starting number, matching spec: 6→1 is 8 steps)
- Single-stage SDK image in Dockerfile — no separate runtime image needed for dev workflow
- Added `<ImplicitUsings>enable</ImplicitUsings>` to csproj — required for `Console` and `IEnumerable<>` to be available in top-level statements without explicit `using` directives
