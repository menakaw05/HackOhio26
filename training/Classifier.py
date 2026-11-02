import os, glob, json, ast, uuid, math, random
import numpy as np
import pandas as pd
from pathlib import Path
from collections import Counter

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
import itertools


###############################################################################
# ====================== CONFIG ======================
###############################################################################

# folder that has your .jsonl attempt logs
FOLDER_PATH = "Data"

# this is your master "attempt level" CSV we'll build
MASTER_ATTEMPT_CSV = "fulldata.csv"

# which phoneme are we training a model for RIGHT NOW
TARGET_PHONEME = "O"

# where to dump artifacts for this phoneme
OUTPUT_DIR = Path(f"model_outputs_{TARGET_PHONEME}")
OUTPUT_DIR.mkdir(exist_ok=True, parents=True)

# how many frames to use when smoothing per-attempt predictions
SMOOTH_WINDOW = 20


###############################################################################
# reproducibility + device
###############################################################################

def set_seed(s=42):
    random.seed(s)
    np.random.seed(s)
    torch.manual_seed(s)
    torch.cuda.manual_seed_all(s)

set_seed(42)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("using device:", device)


###############################################################################
# 1. LOAD RAW JSONL (attempt-level) AND BUILD fulldata.csv
#    each jsonl line is one attempt with keys: phoneme, quality_label, frames
###############################################################################

def load_attempt_level_dataframe(folder_path, out_csv_path):
    json_pattern = os.path.join(folder_path, "*.jsonl")
    json_files = glob.glob(json_pattern)

    rows = []
    for file_path in json_files:
        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    rows.append(obj)
                except Exception as e:
                    print("json loading error in", file_path, e)

    df = pd.DataFrame(rows)
    df.to_csv(out_csv_path, index=False)

    print(df.head())
    print(f"Loaded {len(df)} rows from {len(json_files)} files")
    return df

# build fulldata.csv if it doesn't exist already
if not os.path.exists(MASTER_ATTEMPT_CSV):
    print("Building", MASTER_ATTEMPT_CSV, "from .jsonl files...")
    attempt_df_all = load_attempt_level_dataframe(FOLDER_PATH, MASTER_ATTEMPT_CSV)
else:
    attempt_df_all = pd.read_csv(MASTER_ATTEMPT_CSV)
    print("Loaded existing", MASTER_ATTEMPT_CSV, "with", len(attempt_df_all), "rows")


###############################################################################
# 2. FEATURE EXTRACTION from frames[] inside each attempt row
###############################################################################

def centroid(points):
    # avg x,y of list of {x:..., y:...}
    if not points or len(points) == 0:
        return None
    sx = 0.0
    sy = 0.0
    n = 0
    for p in points:
        if ("x" in p) and ("y" in p):
            sx += p["x"]
            sy += p["y"]
            n += 1
    if n == 0:
        return None
    return (sx / n, sy / n)

def euclidean_distance(p1, p2):
    if p1 is None or p2 is None:
        return None
    dx = p1[0] - p2[0]
    dy = p1[1] - p2[1]
    return math.sqrt(dx * dx + dy * dy)

def vertical_distance(p1, p2):
    if p1 is None or p2 is None:
        return None
    return abs(p1[1] - p2[1])

def mouth_corners(points):
    # get leftmost and rightmost point (by x)
    if not points or len(points) == 0:
        return (None, None)
    left = min(points, key=lambda p: p.get("x", float("inf")))
    right = max(points, key=lambda p: p.get("x", float("-inf")))
    if "x" in left and "y" in left and "x" in right and "y" in right:
        return ((left["x"], left["y"]), (right["x"], right["y"]))
    return (None, None)

def extract_frame_features_single(frame_dict, prev_feats=None):
    """
    frame_dict is one frame from frames[]
    we compute:
      lip_gap_norm, mouth_height_norm, round_ratio
      deltas to previous frame
    """
    ts = frame_dict.get("timestamp", None)
    frame_idx = frame_dict.get("frame_index", None)

    mc = frame_dict.get("mouthContours", {})

    upperLipBottom = mc.get("upperLipBottom")
    lowerLipTop    = mc.get("lowerLipTop")
    upperLipTop    = mc.get("upperLipTop")
    lowerLipBottom = mc.get("lowerLipBottom")

    upBotCenter  = centroid(upperLipBottom)
    lowTopCenter = centroid(lowerLipTop)
    upTopCenter  = centroid(upperLipTop)
    lowBotCenter = centroid(lowerLipBottom)

    # vertical distances
    lip_gap = vertical_distance(upBotCenter, lowTopCenter)
    mouth_height = vertical_distance(upTopCenter, lowBotCenter)

    # mouth width from extreme corners
    ref_for_corners = lowerLipTop if (lowerLipTop and len(lowerLipTop) > 0) else upperLipBottom
    left_corner, right_corner = mouth_corners(ref_for_corners)
    mouth_width = euclidean_distance(left_corner, right_corner)

    if (
        mouth_width is None or mouth_width == 0
        or lip_gap is None
        or mouth_height is None
    ):
        return None

    lip_gap_norm = lip_gap / mouth_width
    mouth_height_norm = mouth_height / mouth_width
    round_ratio = mouth_width / mouth_height if mouth_height > 0 else float("inf")

    if prev_feats is not None:
        lip_gap_prev_norm = prev_feats["lip_gap_norm"]
        lip_gap_delta_norm = lip_gap_norm - lip_gap_prev_norm

        mouth_height_prev_norm = prev_feats["mouth_height_norm"]
        mouth_height_delta_norm = mouth_height_norm - mouth_height_prev_norm
    else:
        # first frame in attempt → no previous context yet
        lip_gap_prev_norm = lip_gap_norm
        lip_gap_delta_norm = 0.0
        mouth_height_prev_norm = mouth_height_norm
        mouth_height_delta_norm = 0.0

    return {
        "timestamp": ts,
        "frame_index": frame_idx,
        "lip_gap_norm": lip_gap_norm,
        "mouth_height_norm": mouth_height_norm,
        "round_ratio": round_ratio,
        "lip_gap_prev_norm": lip_gap_prev_norm,
        "lip_gap_delta_norm": lip_gap_delta_norm,
        "mouth_height_delta_norm": mouth_height_delta_norm,
    }

def explode_attempt_rows_to_frames(attempt_df):
    """
    attempt_df rows should have:
       phoneme, quality_label, frames
    frames can be either a real list or a string of a list (so we ast.literal_eval it)

    returns a per-frame df with:
       attempt_id, phoneme, class_label, frame_index, timestamp, and features...
    """
    out_rows = []

    for _, row in attempt_df.iterrows():
        phoneme = row["phoneme"]
        class_label = row["quality_label"]

        frames_obj = row["frames"]
        if isinstance(frames_obj, str):
            # turn string like "[{...}, {...}, ...]" into python list
            frames_list = ast.literal_eval(frames_obj)
        else:
            frames_list = frames_obj

        attempt_id = str(uuid.uuid4())

        prev_feats = None
        for fdict in frames_list:
            feats = extract_frame_features_single(fdict, prev_feats=prev_feats)
            if feats is None:
                # bad geometry for this frame, skip it
                continue
            out_rows.append({
                "attempt_id": attempt_id,
                "phoneme": phoneme,
                "class_label": class_label,
                **feats
            })
            prev_feats = feats

    return pd.DataFrame(out_rows)


###############################################################################
# 3. ADD TEMPORAL CONTEXT (rolling mean/std + deltas) PER ATTEMPT
###############################################################################

def add_temporal_context(df, base_feat_cols, window=5):
    """
    For each attempt separately:
    - sort by frame_index
    - rolling mean/std for each base feature
    - first-difference delta of each base feature
    """
    out_chunks = []

    for attempt_id, group in df.groupby("attempt_id"):
        g = group.sort_values("frame_index").copy()

        for feat in base_feat_cols:
            roll_mean_col = f"{feat}_rollmean{window}"
            roll_std_col  = f"{feat}_rollstd{window}"
            delta_col     = f"{feat}_delta"

            g[roll_mean_col] = (
                g[feat].rolling(window=window, min_periods=1).mean()
            )
            g[roll_std_col] = (
                g[feat].rolling(window=window, min_periods=1).std().fillna(0.0)
            )
            g[delta_col] = g[feat].diff().fillna(0.0)

        out_chunks.append(g)

    return pd.concat(out_chunks, ignore_index=True)


###############################################################################
# 4. BUILD FRAME-LEVEL DATAFRAME FOR TARGET PHONEME
###############################################################################

# keep only attempts with the phoneme we care about right now
attempt_level_df = attempt_df_all[attempt_df_all["phoneme"] == TARGET_PHONEME].reset_index(drop=True)

# explode attempts into per-frame rows
frame_df = explode_attempt_rows_to_frames(attempt_level_df)

# add rolling context features
base_feat_cols = [
    "lip_gap_norm",
    "mouth_height_norm",
    "round_ratio"
]
frame_df = add_temporal_context(frame_df, base_feat_cols, window=5)

# clean infinities / NaNs etc.
frame_df = frame_df.replace([np.inf, -np.inf], np.nan)

# which final columns are we going to feed to the model
feature_cols = [
    "lip_gap_norm",
    "mouth_height_norm",
    "round_ratio",
    "lip_gap_prev_norm",
    "lip_gap_delta_norm",
    "mouth_height_delta_norm",
    "lip_gap_norm_rollmean5",
    "lip_gap_norm_rollstd5",
    "lip_gap_norm_delta",
    "mouth_height_norm_rollmean5",
    "mouth_height_norm_rollstd5",
    "mouth_height_norm_delta",
    "round_ratio_rollmean5",
    "round_ratio_rollstd5",
    "round_ratio_delta",
]

# get rid of any rows missing features or labels
frame_df = frame_df.dropna(subset=feature_cols + ["class_label", "attempt_id", "frame_index"])

# optional debug dump to inspect
exploded_out_path = OUTPUT_DIR / f"{TARGET_PHONEME}_frames_exploded.csv"
frame_df.to_csv(exploded_out_path, index=False)
print("wrote exploded frame data to:", exploded_out_path)


###############################################################################
# 5. LABEL ENCODING, TRAIN/VAL/TEST SPLIT (BY ATTEMPT)
###############################################################################

le = LabelEncoder()
frame_df["class_id"] = le.fit_transform(frame_df["class_label"])

print("label map:")
for i, name in enumerate(le.classes_):
    print(f"{i}: {name}")

# make a table of unique attempts and their label
attempt_table = frame_df[["attempt_id", "class_label"]].drop_duplicates()

attempt_trainval, attempt_test = train_test_split(
    attempt_table,
    test_size=0.15,
    random_state=42,
    stratify=attempt_table["class_label"]
)

attempt_train, attempt_val = train_test_split(
    attempt_trainval,
    test_size=0.1765,  # ~15% overall
    random_state=42,
    stratify=attempt_trainval["class_label"]
)

train_ids = set(attempt_train["attempt_id"])
val_ids   = set(attempt_val["attempt_id"])
test_ids  = set(attempt_test["attempt_id"])

train_df = frame_df[frame_df["attempt_id"].isin(train_ids)].reset_index(drop=True)
val_df   = frame_df[frame_df["attempt_id"].isin(val_ids)].reset_index(drop=True)
test_df  = frame_df[frame_df["attempt_id"].isin(test_ids)].reset_index(drop=True)

X_train = train_df[feature_cols].to_numpy(np.float32)
y_train = train_df["class_id"].to_numpy(int)

X_val   = val_df[feature_cols].to_numpy(np.float32)
y_val   = val_df["class_id"].to_numpy(int)

X_test  = test_df[feature_cols].to_numpy(np.float32)
y_test  = test_df["class_id"].to_numpy(int)

print("sizes:",
      "train frames", X_train.shape[0],
      "val frames",   X_val.shape[0],
      "test frames",  X_test.shape[0])

num_classes = len(le.classes_)
input_dim = X_train.shape[1]

# compute class weights so the loss doesn't ignore rare class
cls_weights_arr = compute_class_weight(
    class_weight="balanced",
    classes=np.unique(y_train),
    y=y_train
)
cls_weights = torch.tensor(cls_weights_arr, dtype=torch.float32).to(device)


###############################################################################
# 6. Datasets / Dataloaders
###############################################################################

class FrameDataset(Dataset):
    def __init__(self, X, y):
        self.X = torch.tensor(X, dtype=torch.float32)
        self.y = torch.tensor(y, dtype=torch.long)
    def __len__(self):
        return self.X.shape[0]
    def __getitem__(self, idx):
        return self.X[idx], self.y[idx]

train_ds = FrameDataset(X_train, y_train)
val_ds   = FrameDataset(X_val, y_val)
test_ds  = FrameDataset(X_test, y_test)

def make_loader(ds, batch_size, shuffle):
    return DataLoader(ds, batch_size=batch_size, shuffle=shuffle, drop_last=False)


###############################################################################
# 7. The model (2-layer MLP)
###############################################################################

class SimpleMLP(nn.Module):
    def __init__(self, in_dim, hidden1, hidden2, out_dim, dropout):
        super().__init__()
        self.fc1   = nn.Linear(in_dim, hidden1)
        self.act1  = nn.ReLU()
        self.drop1 = nn.Dropout(dropout)

        self.fc2   = nn.Linear(hidden1, hidden2)
        self.act2  = nn.ReLU()
        self.drop2 = nn.Dropout(dropout)

        self.fc3   = nn.Linear(hidden2, out_dim)  # logits

    def forward(self, x):
        x = self.fc1(x)
        x = self.act1(x)
        x = self.drop1(x)

        x = self.fc2(x)
        x = self.act2(x)
        x = self.drop2(x)

        x = self.fc3(x)
        return x


###############################################################################
# 8. Train ONE model for given hyperparams
###############################################################################

def train_model(hidden1, hidden2, lr, batch_size, epochs, dropout):
    model = SimpleMLP(
        in_dim=input_dim,
        hidden1=hidden1,
        hidden2=hidden2,
        out_dim=num_classes,
        dropout=dropout
    ).to(device)

    opt = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = nn.CrossEntropyLoss(weight=cls_weights)

    train_loader = make_loader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader   = make_loader(val_ds, batch_size=batch_size, shuffle=False)

    best_val_acc = 0.0
    best_state = None

    for epoch in range(epochs):
        # ---- train step ----
        model.train()
        run_loss = 0.0
        run_correct = 0
        run_total = 0

        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)

            opt.zero_grad()
            logits = model(xb)
            loss = loss_fn(logits, yb)
            loss.backward()
            opt.step()

            run_loss += loss.item() * xb.size(0)
            preds = torch.argmax(logits, dim=1)
            run_correct += (preds == yb).sum().item()
            run_total += xb.size(0)

        train_loss = run_loss / run_total
        train_acc = run_correct / run_total

        # ---- val step ----
        model.eval()
        val_correct = 0
        val_total = 0
        with torch.no_grad():
            for xb, yb in val_loader:
                xb = xb.to(device)
                yb = yb.to(device)

                logits = model(xb)
                preds = torch.argmax(logits, dim=1)
                val_correct += (preds == yb).sum().item()
                val_total += xb.size(0)

        val_acc = val_correct / val_total if val_total > 0 else 0.0

        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(f"[h1={hidden1} h2={hidden2} lr={lr} bs={batch_size} drop={dropout}] "
                  f"epoch {epoch+1}/{epochs} "
                  f"train_loss={train_loss:.4f} "
                  f"train_acc={train_acc*100:.1f}% "
                  f"val_acc={val_acc*100:.1f}%")

        # track best val snapshot
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_state = {
                "model_state": model.state_dict(),
                "hidden1": hidden1,
                "hidden2": hidden2,
                "lr": lr,
                "batch_size": batch_size,
                "epochs": epochs,
                "dropout": dropout,
                "val_acc": val_acc
            }

    # load best weights before returning
    if best_state is not None:
        model.load_state_dict(best_state["model_state"])

    return model, best_val_acc, best_state


###############################################################################
# 9. Eval helpers
###############################################################################

def eval_model_frame_level(model, dataset, batch_size=128):
    loader = make_loader(dataset, batch_size=batch_size, shuffle=False)
    model.eval()

    all_true = []
    all_pred = []

    with torch.no_grad():
        for xb, yb in loader:
            xb = xb.to(device)
            yb = yb.to(device)
            logits = model(xb)
            preds = torch.argmax(logits, dim=1)
            all_true.append(yb.cpu().numpy())
            all_pred.append(preds.cpu().numpy())

    all_true = np.concatenate(all_true)
    all_pred = np.concatenate(all_pred)
    return all_true, all_pred


def model_predict_frames(model, X_np):
    model.eval()
    with torch.no_grad():
        xb = torch.tensor(X_np, dtype=torch.float32).to(device)
        logits = model(xb)
        preds = torch.argmax(logits, dim=1)
    return preds.cpu().numpy()

def smooth_sliding_majority(pred_seq, window=5):
    out = []
    for i in range(len(pred_seq)):
        start = max(0, i - window + 1)
        window_slice = pred_seq[start:i+1]
        c = Counter(window_slice)
        out.append(c.most_common(1)[0][0])
    return np.array(out)

def attempt_final_pred(model, attempt_frames_df, window=5):
    # sort frames in time
    att_sorted = attempt_frames_df.sort_values("frame_index")
    X_attempt = att_sorted[feature_cols].to_numpy(np.float32)

    frame_preds = model_predict_frames(model, X_attempt)
    frame_preds_smoothed = smooth_sliding_majority(frame_preds, window=window)

    # final predicted class for this attempt = mode of smoothed preds
    final_vote = Counter(frame_preds_smoothed).most_common(1)[0][0]
    return final_vote

def evaluate_attempt_level(model, full_test_df, attempt_ids, label_encoder, window=5):
    y_true_attempt = []
    y_pred_attempt = []

    for aid in attempt_ids:
        att_df = full_test_df[full_test_df["attempt_id"] == aid]

        # ground truth = most common label in that attempt
        true_label_str = Counter(att_df["class_label"]).most_common(1)[0][0]
        true_label_id = label_encoder.transform([true_label_str])[0]

        pred_label_id = attempt_final_pred(model, att_df, window=window)

        y_true_attempt.append(true_label_id)
        y_pred_attempt.append(pred_label_id)

    y_true_attempt = np.array(y_true_attempt)
    y_pred_attempt = np.array(y_pred_attempt)

    print("\n=== ATTEMPT-LEVEL TEST METRICS (smoothed) ===")
    print(classification_report(y_true_attempt, y_pred_attempt, target_names=label_encoder.classes_))
    print("Confusion matrix (attempt-level):")
    print(confusion_matrix(y_true_attempt, y_pred_attempt))


###############################################################################
# 10. hyperparam search
###############################################################################

param_grid = {
    "hidden1":    [128],
    "hidden2":    [32,64],
    "lr":         [1e-3],
    "batch_size": [32],
    "epochs":     [200],
    "dropout":    [0.2],
}

combos = list(itertools.product(
    param_grid["hidden1"],
    param_grid["hidden2"],
    param_grid["lr"],
    param_grid["batch_size"],
    param_grid["epochs"],
    param_grid["dropout"]
))

print("trying", len(combos), "hyperparam combos")

best_combo = None
best_model = None

for (h1, h2, lr, bs, ep, dr) in combos:
    m, val_acc, state = train_model(
        hidden1=h1,
        hidden2=h2,
        lr=lr,
        batch_size=bs,
        epochs=ep,
        dropout=dr
    )

    if best_combo is None or val_acc > best_combo["val_acc"]:
        best_combo = {
            "val_acc": val_acc,
            "hidden1": h1,
            "hidden2": h2,
            "lr": lr,
            "batch_size": bs,
            "epochs": ep,
            "dropout": dr,
            "state": state
        }
        best_model = m

print("\nBest settings:", best_combo)


###############################################################################
# 11. final evals (frame-level + attempt-level)
###############################################################################

# frame-level metrics
y_train_true, y_train_pred = eval_model_frame_level(best_model, train_ds)
y_val_true,   y_val_pred   = eval_model_frame_level(best_model, val_ds)
y_test_true,  y_test_pred  = eval_model_frame_level(best_model, test_ds)

print("\n=== FRAME-LEVEL TRAIN ===")
print(classification_report(y_train_true, y_train_pred, target_names=le.classes_))

print("\n=== FRAME-LEVEL VAL ===")
print(classification_report(y_val_true, y_val_pred, target_names=le.classes_))

print("\n=== FRAME-LEVEL TEST ===")
print(classification_report(y_test_true, y_test_pred, target_names=le.classes_))

print("\nFrame-level confusion (test):")
print(confusion_matrix(y_test_true, y_test_pred))

# attempt-level metrics (what you'd show in demo / pitch)
evaluate_attempt_level(
    best_model,
    test_df,      # only the attempts in test split
    test_ids,
    le,
    window=SMOOTH_WINDOW
)


###############################################################################
# 12. save model weights + label map (no ONNX right now)
###############################################################################

torch_save_path = OUTPUT_DIR / "best_phoneme_model.pth"
torch.save({
    "model_state": best_model.state_dict(),
    "input_dim": input_dim,
    "hidden1": best_combo["hidden1"],
    "hidden2": best_combo["hidden2"],
    "num_classes": num_classes,
    "dropout": best_combo["dropout"],
    "label_classes": le.classes_.tolist(),
    "feature_cols": feature_cols
}, torch_save_path)
print("saved best model ->", torch_save_path)

label_map_path = OUTPUT_DIR / "class_label_map.json"
with open(label_map_path, "w") as f:
    json.dump({int(i): name for i, name in enumerate(le.classes_)}, f)
print("saved label map ->", label_map_path)

print("done.")

