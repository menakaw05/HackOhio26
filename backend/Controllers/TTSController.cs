using System.Security;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TTSController : ControllerBase
    {
        private const string VoiceName = "en-US-JennyNeural";

        // "/u/" style segments in the text are spoken as that IPA sound
        private static readonly Regex IpaSegment = new(@"/([^/\s]+)/");

        private readonly string _speechKey;
        private readonly string _speechRegion;

        public TTSController(IConfiguration config)
        {
            _speechKey = config["AzureSpeech:Key"] ?? "";
            _speechRegion = config["AzureSpeech:Region"] ?? "";
            if (string.IsNullOrWhiteSpace(_speechKey) || string.IsNullOrWhiteSpace(_speechRegion))
            {
                throw new InvalidOperationException("Azure Speech credentials are missing from configuration.");
            }
        }

        [HttpGet("speak")]
        public async Task<IActionResult> Speak([FromQuery] string text)
        {
            Console.WriteLine($"TTS request for: {text}");
            if (string.IsNullOrWhiteSpace(text))
                return BadRequest("Text is required.");

            var speechConfig = SpeechConfig.FromSubscription(_speechKey, _speechRegion);
            speechConfig.SpeechSynthesisVoiceName = VoiceName;
            speechConfig.SetSpeechSynthesisOutputFormat(
                SpeechSynthesisOutputFormat.Audio24Khz48KBitRateMonoMp3
            );

            // null audio config: keep the audio in memory instead of playing it on the server
            using var synthesizer = new SpeechSynthesizer(speechConfig, null);

            var result = await synthesizer.SpeakSsmlAsync(BuildSsml(text));

            if (result.Reason == ResultReason.Canceled)
            {
                var cancellation = SpeechSynthesisCancellationDetails.FromResult(result);
                Console.WriteLine($"TTS canceled: {cancellation.Reason}, {cancellation.ErrorDetails}");
                return StatusCode(500, $"TTS failed: {cancellation.Reason}, {cancellation.ErrorDetails}");
            }

            Console.WriteLine($"Generated TTS audio: {result.AudioData.Length} bytes");

            // Return MP3 directly as streaming content
            return File(result.AudioData, "audio/mpeg");
        }

        public static string BuildSsml(string text)
        {
            var body = "";
            var last = 0;
            foreach (Match m in IpaSegment.Matches(text))
            {
                body += SecurityElement.Escape(text[last..m.Index]);
                var ipa = SecurityElement.Escape(m.Groups[1].Value);
                body += $"<phoneme alphabet='ipa' ph='{ipa}'>{ipa}</phoneme>";
                last = m.Index + m.Length;
            }
            body += SecurityElement.Escape(text[last..]);

            return $@"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>
    <voice name='{VoiceName}'>{body}</voice>
</speak>";
        }
    }
}
