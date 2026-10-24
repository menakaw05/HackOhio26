// GET /api/speech-token: a 10-minute Azure Speech token for the avatar page,
// so the browser never sees the key. Uses the same AzureSpeech:Key/Region
// settings as PronunciationAssess.

using System.Net.Http;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

public static class SpeechTokenEndpoint
{
    public static void MapSpeechToken(this WebApplication app)
    {
        app.MapGet("/api/speech-token", async (IHttpClientFactory factory, IConfiguration cfg) =>
        {
            var region = cfg["AzureSpeech:Region"];
            var key = cfg["AzureSpeech:Key"];

            using var req = new HttpRequestMessage(
                HttpMethod.Post,
                $"https://{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken");
            req.Headers.Add("Ocp-Apim-Subscription-Key", key);

            var res = await factory.CreateClient().SendAsync(req);
            if (!res.IsSuccessStatusCode)
                return Results.Problem($"Token request failed: {(int)res.StatusCode}");

            var token = await res.Content.ReadAsStringAsync();
            return Results.Json(new { token, region });
        });
    }
}
