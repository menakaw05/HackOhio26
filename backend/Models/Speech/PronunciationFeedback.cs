namespace backend.Models.Speech;

public class PAResult
{
    public string RecognizedText { get; set; } = "";
    public double AccuracyScore { get; set; }
    public double FluencyScore { get; set; }
    public double CompletenessScore { get; set; }
    public double ProsodyScore { get; set; }
    public double PronunciationScore { get; set; }
    public List<WordAssessment> Words { get; set; } = new();
}

public class WordAssessment
{
    public string Word { get; set; } = "";
    public double AccuracyScore { get; set; }
    public string ErrorType { get; set; } = "";
    public List<PhonemeAssessment> Phonemes { get; set; } = new();
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class PhonemeAssessment
{
    public string Phoneme { get; set; } = "";
    public double AccuracyScore { get; set; }
    public List<PhonemeConfusion> NBestPhonemes { get; set; } = new();
}

public class PhonemeConfusion
{
    public string Phoneme { get; set; } = "";
    public double Score { get; set; }
}
