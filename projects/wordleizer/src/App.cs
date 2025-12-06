// See https://aka.ms/new-console-template for more information
Console.WriteLine("Hello, World!");

var stream = File.OpenRead(@"data\dwyl\words_alpha.txt");
using var reader = new StreamReader(stream);

readonly var root = new Node { Value = ' ' };

while (!reader.EndOfStream)
{
    var line = reader.ReadLine();
    if (line.Length == 5)
    {
        Console.WriteLine(line);

        var tracer = root;

        foreach(var c in line)
        {
            tracer.ChildMap.TryGetValue(c, out var childNode);
            if (childNode == null)
            {
                childNode = new Node { Value = c, Count = 0 };
                tracer.ChildMap[c] = childNode;
            }
            childNode.Count += 1;
            tracer = tracer.ChildMap[c];            
        }
    }
}

class Node
{
    public char Value { get; set; }
    public int Count { get; set; } = 0;
    public IDictionary<char, Node> ChildMap { get; set; } = new Dictionary<char, Node>();
}   