#load pth files into models

import torch
import torch.nn as nn

# Define same model as before 
class SimpleMLP(nn.Module):
    def __init__(self, in_dim, hidden1, hidden2, out_dim, dropout):
        super().__init__()
        self.fc1   = nn.Linear(in_dim, hidden1)
        self.act1  = nn.ReLU()
        self.drop1 = nn.Dropout(dropout)

        self.fc2   = nn.Linear(hidden1, hidden2)
        self.act2  = nn.ReLU()
        self.drop2 = nn.Dropout(dropout)

        self.fc3   = nn.Linear(hidden2, out_dim)

    def forward(self, x):
        x = self.fc1(x); x = self.act1(x); x = self.drop1(x)
        x = self.fc2(x); x = self.act2(x); x = self.drop2(x)
        x = self.fc3(x)
        return x

# Load .pth checkpoint
phonemes = ["A", "P", "O"]
for phoneme in phonemes:
    checkpoint_path = f"model_outputs_{phoneme}/best_phoneme_model.pth"
    checkpoint = torch.load(checkpoint_path, map_location="cpu")

    input_dim = checkpoint["input_dim"]
    hidden1 = checkpoint["hidden1"]
    hidden2 = checkpoint["hidden2"]
    num_classes = checkpoint["num_classes"]
    dropout = checkpoint["dropout"]

    #  Rebuild + load weights
    model = SimpleMLP(input_dim, hidden1, hidden2, num_classes, dropout)
    model.load_state_dict(checkpoint["model_state"])
    model.eval()

    print("Model loaded successfully!")

    # Export to ONNX
    dummy_input = torch.randn(1, input_dim, dtype=torch.float32)
    onnx_path = f"model_outputs_{phoneme}/phoneme_model.onnx"

    torch.onnx.export(
        model,
        dummy_input,
        onnx_path,
        input_names=["input_features"],
        output_names=["logits"],
        dynamic_axes={"input_features": {0: "batch_size"}, "logits": {0: "batch_size"}},
        opset_version=17,
        external_data=False
    )

    print("Exported ONNX ->", onnx_path)
