// See https://aka.ms/new-console-template for more information
using System.ComponentModel.DataAnnotations;

Console.WriteLine("Hello, World!");

var stream = File.OpenRead(@"data/dwyl/words_alpha.txt");
using var reader = new StreamReader(stream);

var root = new Node { Value = ' ' };
int count = 0;
int inputWordCount = 0;
while (!reader.EndOfStream)
{
    var line = reader.ReadLine();

    if (line == null) continue;

    if (line.Length != 5) continue;
    //Console.WriteLine(line);

    inputWordCount++;   

    var tracer = root;

    foreach (var c in line)
    {
        tracer.ChildMap.TryGetValue(c, out var childNode);
        if (childNode == null)
        {
            count++;
            childNode = new Node { Value = c, Count = 0 };
            tracer.ChildMap[c] = childNode;
        }
        childNode.Count += 1;
        tracer = childNode; // Use the non-null reference directly
    }
}

static string PickNextWord(Node root, string guess, string result, int position = 0)
{
    if (root.ChildMap.Count == 0) return string.Empty;

    if (result[position] == 'v')
    {
        return guess[position].ToString() + PickNextWord(root.ChildMap[guess[position]], guess, result, position + 1);
    }

    var excludeChars = new HashSet<char>();
    for(int x = 0; x < guess.Length; x++)
    {
        if (result[x] == 'x')
        {
            excludeChars.Add(guess[x]);
        }
        if (result[x] == '~' && x == position)
        {
            excludeChars.Add(guess[x]);
        }
    }

    while(true)
    {
        var max = root.ChildMap
                        .Where(kv => !excludeChars.Contains(kv.Key))
                        .MaxBy(kv => kv.Value.Count);

        if (position == 4)
        {
            return max.Key.ToString();
        }

        var nextWord = PickNextWord(max.Value, guess, result, position + 1);

        if (nextWord == string.Empty)
        {
            excludeChars.Add(max.Key);
            continue;
        }

        return max.Key + nextWord;
    }
}

var word = root;
while (word != null)
{
    if (word.ChildMap.Count == 0) break;        

    var max = word.ChildMap.MaxBy(kv => kv.Value.Count);
    Console.WriteLine(max.Key + " " + max.Value.Count);
    word = max.Value;
}

var total = root.ChildMap.Values.Sum(n1 => n1.Count);
Console.WriteLine($"Total words: {total}"); 

Console.WriteLine($"Input words: {inputWordCount}");
Console.WriteLine($"Total unique nodes: {count}");

var nextWord = PickNextWord(root, "audio", "x~xvx");    
Console.WriteLine($"Next word: {nextWord}");    

class Node
{
    public char Value { get; set; }
    public int Count { get; set; } = 0;
    public IDictionary<char, Node> ChildMap { get; set; } = new Dictionary<char, Node>();
}
