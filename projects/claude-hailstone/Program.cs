if (args.Length == 0 || !long.TryParse(args[0], out long n) || n < 1)
{
    Console.Error.WriteLine("Usage: hailstone <positive integer>");
    return 1;
}

var sequence = Hailstone(n).ToList();
Console.WriteLine(string.Join(" -> ", sequence) + $" ({sequence.Count - 1} steps)");
return 0;

static IEnumerable<long> Hailstone(long n)
{
    yield return n;
    while (n != 1)
    {
        n = n switch { var x when x % 2 == 0 => x / 2, var x => 3 * x + 1 };
        yield return n;
    }
}
