// GET /api/images/get?word=boot: a picture for a word, drawn by the Azure OpenAI image
// deployment (gpt-image-1-mini) on a transparent background, trimmed and centered so every
// picture sits the same way in the app, and kept in word-images/. A word that isn't drawn yet answers
// 202 while it's drawn in the background (about 40 s), the same contract as eLEXir's image
// service, so the app shows the word's emoji meanwhile and asks again.
// Settings: ImageGen:Endpoint (the resource's address, or the deployment's whole Target URI),
// ImageGen:Key and ImageGen:Deployment.

using System.Collections.Concurrent;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

public static class WordImageEndpoint
{
    // a word whose drawing failed is tried again after this long
    static readonly TimeSpan RetryFailedAfter = TimeSpan.FromMinutes(2);
    static readonly ConcurrentDictionary<string, Task> Drawing = new();
    static readonly ConcurrentDictionary<string, DateTimeOffset> Failed = new();

    public static void MapWordImages(this WebApplication app)
    {
        var dir = Path.Combine(app.Environment.ContentRootPath, "word-images");
        Directory.CreateDirectory(dir);

        app.MapGet("/api/images/get", (string word, HttpContext http, IHttpClientFactory factory,
            IConfiguration cfg, ILoggerFactory logs) =>
        {
            var id = Normalize(word);
            if (id.Length == 0) return Results.BadRequest("word is required");
            var file = Path.Combine(dir, $"{id}.png");
            if (File.Exists(file))
            {
                var url = $"{http.Request.Scheme}://{http.Request.Host}/api/images/file/{id}.png";
                return Results.Json(new { word = id, fullUrl = url });
            }

            http.Response.Headers["Retry-After"] = "10";
            if (Failed.TryGetValue(id, out var failedAt) && DateTimeOffset.UtcNow - failedAt < RetryFailedAfter)
                return Results.StatusCode(StatusCodes.Status202Accepted);

            var log = logs.CreateLogger("WordImages");
            Drawing.GetOrAdd(id, w => Task.Run(async () =>
            {
                try
                {
                    await Draw(id, file, factory.CreateClient(), cfg);
                    Failed.TryRemove(id, out _);
                    log.LogInformation("Drew '{Word}'", id);
                }
                catch (Exception e)
                {
                    Failed[id] = DateTimeOffset.UtcNow;
                    log.LogWarning("Couldn't draw '{Word}': {Error}", id, e.Message);
                }
                finally
                {
                    Drawing.TryRemove(id, out _);
                }
            }));
            return Results.StatusCode(StatusCodes.Status202Accepted);
        });

        app.MapGet("/api/images/file/{name}", (string name) =>
        {
            var file = Path.Combine(dir, $"{Normalize(Path.GetFileNameWithoutExtension(name))}.png");
            return File.Exists(file) ? Results.File(file, "image/png") : Results.NotFound();
        });
    }

    // letters only, so a word can't reach outside the folder
    static string Normalize(string word) => Regex.Replace(word.Trim().ToLowerInvariant(), "[^a-z]", "");

    static async Task Draw(string word, string file, HttpClient http, IConfiguration cfg)
    {
        var endpoint = cfg["ImageGen:Endpoint"];
        var key = cfg["ImageGen:Key"];
        var deployment = cfg["ImageGen:Deployment"] ?? "gpt-image-1-mini";
        if (string.IsNullOrWhiteSpace(endpoint) || string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException("ImageGen:Endpoint and ImageGen:Key aren't set");

        // just the resource's address, in case the whole Target URI was pasted;
        // gpt-image models need api-version 2025-04-01-preview or later
        var resource = new Uri(endpoint).GetLeftPart(UriPartial.Authority);
        using var req = new HttpRequestMessage(HttpMethod.Post,
            $"{resource}/openai/deployments/{deployment}/images/generations?api-version=2025-04-01-preview");
        req.Headers.Add("api-key", key);
        var body = JsonSerializer.Serialize(new
        {
            prompt = $"A simple cartoon of {word} for a children's picture card: one object, centered, " +
                     "soft pastel colors, thick dark outlines, no text, transparent background",
            size = "1024x1024",
            background = "transparent",
            output_format = "png",
            n = 1,
        });
        req.Content = new StringContent(body, Encoding.UTF8, "application/json");
        http.Timeout = TimeSpan.FromMinutes(3);

        var res = await http.SendAsync(req);
        var text = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
            throw new HttpRequestException($"{(int)res.StatusCode} {text}");

        // gpt-image models send the picture itself, base64
        using var doc = JsonDocument.Parse(text);
        var b64 = doc.RootElement.GetProperty("data")[0].GetProperty("b64_json").GetString()
            ?? throw new InvalidOperationException("no image in the response");
        var tmp = file + ".tmp";
        await File.WriteAllBytesAsync(tmp, Tidy(Convert.FromBase64String(b64)));
        File.Move(tmp, file, overwrite: true);
    }

    /// The drawing alone: background cleared, trimmed to the drawing, centered in a square
    /// with even padding, 512 px (the app shows it at about 120).
    public static byte[] Tidy(byte[] png)
    {
        using var image = Image.Load<Rgba32>(png);
        ClearEdgeBackground(image);

        int minX = image.Width, minY = image.Height, maxX = -1, maxY = -1;
        for (var y = 0; y < image.Height; y++)
            for (var x = 0; x < image.Width; x++)
                if (image[x, y].A >= 24)
                {
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x);
                    minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
                }
        if (maxX < 0) return png; // nothing drawn

        int w = maxX - minX + 1, h = maxY - minY + 1;
        image.Mutate(c => c.Crop(new Rectangle(minX, minY, w, h)));
        var side = (int)(Math.Max(w, h) * 1.12);
        using var square = new Image<Rgba32>(side, side); // starts transparent
        square.Mutate(c => c
            .DrawImage(image, new Point((side - w) / 2, (side - h) / 2), 1f)
            .Resize(512, 512));
        using var output = new MemoryStream();
        square.SaveAsPng(output);
        return output.ToArray();
    }

    /// If the model drew a background anyway (white or cream), clear it: flood-fill the light
    /// pixels reachable from the edges. Light parts inside the drawing's outlines stay.
    static void ClearEdgeBackground(Image<Rgba32> image)
    {
        if (image[0, 0].A < 24) return; // already transparent
        int w = image.Width, h = image.Height;
        var seen = new bool[w * h];
        var queue = new Queue<(int X, int Y)>();
        void Visit(int x, int y)
        {
            if (x < 0 || y < 0 || x >= w || y >= h || seen[y * w + x]) return;
            seen[y * w + x] = true;
            if (IsLight(image[x, y])) queue.Enqueue((x, y));
        }
        for (var x = 0; x < w; x++) { Visit(x, 0); Visit(x, h - 1); }
        for (var y = 0; y < h; y++) { Visit(0, y); Visit(w - 1, y); }
        while (queue.Count > 0)
        {
            var (x, y) = queue.Dequeue();
            var p = image[x, y];
            image[x, y] = new Rgba32(p.R, p.G, p.B, 0);
            Visit(x + 1, y); Visit(x - 1, y); Visit(x, y + 1); Visit(x, y - 1);
        }
    }

    static bool IsLight(Rgba32 p) =>
        p.R > 225 && p.G > 220 && p.B > 205 && Math.Max(p.R, Math.Max(p.G, p.B)) - Math.Min(p.R, Math.Min(p.G, p.B)) < 45;
}
