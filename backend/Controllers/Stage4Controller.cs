using System.Security;
using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.Audio;
using Microsoft.CognitiveServices.Speech.PronunciationAssessment;
using Newtonsoft.Json.Linq;

namespace backend.Controllers
{
    /// Test-only helper for the stage 4 screen: the phonemes of a word and when each one happens
    /// when the avatar says it. Synthesizes the word with the avatar's voice and speed, then runs
    /// pronunciation assessment on that audio to get per-phoneme offsets. In the real flow the
    /// phoneme breakdown comes from the learner's full-word attempt instead.
    [ApiController]
    [Route("api/[controller]")]
    public class Stage4Controller : ControllerBase
    {
        // must match avatar-web/src/azureTts.js so the timings line up with the avatar's clip
        private const string AvatarVoice = "en-US-AnaNeural";
        private const string AvatarRate = "-30%";

        private readonly string _speechKey;
        private readonly string _speechRegion;

        public Stage4Controller(IConfiguration config)
        {
            _speechKey = config["AzureSpeech:Key"] ?? "";
            _speechRegion = config["AzureSpeech:Region"] ?? "";
            if (string.IsNullOrWhiteSpace(_speechKey) || string.IsNullOrWhiteSpace(_speechRegion))
            {
                throw new InvalidOperationException("Azure Speech credentials are missing from configuration.");
            }
        }

        [HttpGet("phonemes")]
        public async Task<IActionResult> Phonemes([FromQuery] string word)
        {
            if (string.IsNullOrWhiteSpace(word))
                return BadRequest("Word is required.");

            var tempFilePath = Path.GetTempFileName();
            try
            {
                // 1. the word, as the avatar says it, as 16 kHz WAV for the recognizer
                var ttsConfig = SpeechConfig.FromSubscription(_speechKey, _speechRegion);
                ttsConfig.SetSpeechSynthesisOutputFormat(SpeechSynthesisOutputFormat.Riff16Khz16BitMonoPcm);
                using (var synthesizer = new SpeechSynthesizer(ttsConfig, null))
                {
                    var ssml = $@"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>
    <voice name='{AvatarVoice}'><prosody rate='{AvatarRate}'>{SecurityElement.Escape(word)}</prosody></voice>
</speak>";
                    SpeechSynthesisResult tts;
                    await TTSController.Synthesis.WaitAsync();
                    try { tts = await synthesizer.SpeakSsmlAsync(ssml); }
                    finally { TTSController.Synthesis.Release(); }
                    if (tts.Reason == ResultReason.Canceled)
                    {
                        var c = SpeechSynthesisCancellationDetails.FromResult(tts);
                        return StatusCode(500, $"TTS failed: {c.Reason}, {c.ErrorDetails}");
                    }
                    await System.IO.File.WriteAllBytesAsync(tempFilePath, tts.AudioData);
                }

                // 2. pronunciation assessment on that audio, for phonemes with offsets
                var srConfig = SpeechConfig.FromSubscription(_speechKey, _speechRegion);
                srConfig.SpeechRecognitionLanguage = "en-US";
                srConfig.OutputFormat = OutputFormat.Detailed;
                using var audioConfig = AudioConfig.FromWavFileInput(tempFilePath);
                using var recognizer = new SpeechRecognizer(srConfig, audioConfig);
                var paConfig = new PronunciationAssessmentConfig(
                    word, GradingSystem.HundredMark, Granularity.Phoneme, enableMiscue: false);
                paConfig.PhonemeAlphabet = "IPA";
                paConfig.ApplyTo(recognizer);

                var result = await recognizer.RecognizeOnceAsync();
                if (result.Reason != ResultReason.RecognizedSpeech)
                    return StatusCode(500, $"Could not get phonemes for \"{word}\": {result.Reason}");

                var json = JObject.Parse(result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult));
                var phonemes = new List<object>();
                foreach (var w in json["NBest"]?[0]?["Words"] ?? new JArray())
                {
                    foreach (var p in w["Phonemes"] ?? new JArray())
                    {
                        phonemes.Add(new
                        {
                            phoneme = (string?)p["Phoneme"] ?? "",
                            // Azure reports times in 100-ns ticks
                            offsetMs = ((long?)p["Offset"] ?? 0) / 10_000.0,
                            durationMs = ((long?)p["Duration"] ?? 0) / 10_000.0,
                        });
                    }
                }

                Console.WriteLine($"Stage 4 phonemes for \"{word}\": {phonemes.Count}");
                return Ok(new { word, voice = AvatarVoice, rate = AvatarRate, phonemes });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"EXCEPTION: {ex}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
            finally
            {
                if (System.IO.File.Exists(tempFilePath))
                    System.IO.File.Delete(tempFilePath);
            }
        }
    }
}
