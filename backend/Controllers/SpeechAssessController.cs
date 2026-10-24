using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech.PronunciationAssessment;
using backend.Models.Speech;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SpeechAssessController : ControllerBase
    {
        private readonly PronunciationAssess _pronunciationAssess;

        public SpeechAssessController(PronunciationAssess pronunciationAssess)
        {
            _pronunciationAssess = pronunciationAssess;
        }

        [HttpPost("assess")]
        public async Task<ActionResult<PAResult>> AssessPronunciation(
            IFormFile audio,
            [FromForm] string referenceText,
            [FromForm] string gradinglevel = "Phoneme")
        {
            Console.WriteLine("landed in backend woohoo");

            if (audio == null || string.IsNullOrWhiteSpace(referenceText))
                return BadRequest("Audio and referenceText are required.");

            if (!Enum.TryParse<Granularity>(gradinglevel, true, out var granularity))
            {
                return BadRequest($"Invalid grading level: {gradinglevel}");
            }

            var tempFilePath = Path.GetTempFileName();

            try
            {
                Console.WriteLine("Saving uploaded audio file...");
                using (var stream = System.IO.File.Create(tempFilePath))
                {
                    await audio.CopyToAsync(stream);
                }

                Console.WriteLine($"File saved to: {tempFilePath}");
                Console.WriteLine($"Reference text: {referenceText}");
                Console.WriteLine("Calling Azure SDK...");

                var result = await _pronunciationAssess.GetResults(tempFilePath, referenceText, granularity);

                Console.WriteLine("Overall Accuracy: " + result.AccuracyScore);
                Console.WriteLine("Words count: " + result.Words.Count);
                foreach (var w in result.Words)
                {
                    Console.WriteLine($"Word: {w.Word}, Phonemes: {string.Join(", ", w.Phonemes.Select(p => $"{p.Phoneme}={p.AccuracyScore}"))}");
                }

                Console.WriteLine("Azure assessment complete");
                return Ok(result);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"EXCEPTION: {ex}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
            finally
            {
                // Clean up temp file
                if (System.IO.File.Exists(tempFilePath))
                    System.IO.File.Delete(tempFilePath);
            }
        }
    }
}
