using backend.Controllers;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

builder.Services.AddSingleton<PronunciationAssess>();
builder.Services.AddHttpClient();

var app = builder.Build();

app.MapGet("/", () => "Hello World!");
app.MapControllers();
app.MapSpeechToken();
app.MapWordImages();
app.Run();
