# SpamGuard 🚫📩

**On-Device Intelligent Spam Detection System**

SpamGuard is an end-to-end spam detection system designed to identify and classify spam messages in real time while preserving user privacy. The system leverages a lightweight transformer-based NLP model deployed directly on the device, ensuring that sensitive message data never leaves the user's phone.

---

## 🔥 Key Highlights

- **On-device NLP inference** (no cloud dependency)
- **Privacy-first design** — messages are never uploaded
- **Transformer-based model (TinyBERT)**
- **Real-time notification interception**
- **Accurate spam vs ham classification**
- **Optimized for low latency and low memory usage**

---

## 🧠 How It Works

1. **Notification Listener Service**
   - Listens to incoming message notifications from apps (WhatsApp, SMS, etc.)
   - Extracts message content securely at the device level
   - Deduplicates messages to avoid reprocessing bundled notifications

2. **Text Preprocessing**
   - Lowercasing
   - Unicode normalization
   - Removal/masking of URLs, emails, phone numbers
   - Whitespace normalization

3. **NLP Model**
   - Uses a **pretrained TinyBERT transformer**
   - Fine-tuned on labeled spam/ham datasets
   - Optimized using mixed-precision and efficient tokenization

4. **Inference Pipeline**
   - Message → Tokenizer → TinyBERT → Spam probability
   - Output classified as **Ham** or **Spam**
   - Result used to update counters or trigger alerts

---

## 📊 Model Details

- **Architecture:** TinyBERT (Distilled Transformer)
- **Task:** Binary Text Classification
- **Labels:** `ham`, `spam`
- **Tokenizer:** WordPiece
- **Loss Function:** Cross Entropy Loss
- **Optimizer:** AdamW
- **Training Strategy:**
  - Transfer learning
  - Stratified train-test split
  - Class-balanced sampling

---

## 🧪 Dataset Handling

- Data loaded into Hugging Face `Dataset`
- Labels cast using `ClassLabel`
- Stratified split ensures balanced spam/ham distribution

```python
from datasets import Dataset, ClassLabel

label_classes = ClassLabel(names=["ham", "spam"])
dataset = Dataset.from_pandas(df)
dataset = dataset.cast_column("label", label_classes)
dataset = dataset.train_test_split(
    test_size=0.2,
    seed=42,
    stratify_by_column="label"
)
```

---

## 📱 On-Device Deployment

- Model exported to TensorFlow Lite
- Supports FP32 and FP16 inference
- Designed for Android deployment
- Minimal memory footprint and fast inference

---

## 🛡️ Privacy & Security

- No message content is stored permanently
- No data sent to servers
- All processing happens locally on the device
- Notification deduplication prevents double counting

---

## 🚀 Features

- Real-time spam detection
- Notification-level message extraction
- Accurate handling of bundled/group notifications
- Low-latency inference
- Battery-efficient design

---

## 🧰 Tech Stack

- Python
- PyTorch
- Hugging Face Transformers
- TensorFlow Lite
- Android NotificationListenerService
- Flutter (UI integration)

---

## 📈 Future Improvements

- Multilingual spam detection
- Adaptive learning based on user feedback
- Sender-level spam profiling
- Federated learning (privacy-preserving updates)

---

## 👨‍💻 Author

**Krishna**  
Independent Developer  
Focused on privacy-preserving AI and on-device intelligence

---

## ⭐ If you like this project

Give it a ⭐ on GitHub — it really helps!
