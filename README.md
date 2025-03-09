# Temporal and Associative Analysis of Vaccine Adverse Events

## Overview
This project applies **Natural Language Processing (NLP) and Machine Learning (ML)** techniques to analyze **Vaccine Adverse Event Reporting System (VAERS)** data, focusing on:
- **Temporal Analysis:** Generating a **chronologically ordered list of symptoms** for each adverse event report.
- **Associative Analysis:** Identifying **frequent symptom co-occurrences** and their relationships using **association rule mining**.

## Objectives
- Develop an **NLP-based system** to generate **temporally ordered symptom sequences** from VAERS reports.
- Fine-tune transformer models for **sequence generation** and apply **LLMs for CoT prompting**.
- Perform **associative analysis** to uncover **frequent symptom patterns** and quantify relationships.

## Approach

### **1️⃣ Data Processing & Annotation**
- Extracted **SYMPTOM TEXT** and standard **symptoms list** from VAERS reports for MODERNA COVID-19 vaccines.
- Used **few-shot inference with Google Gemini API** to generate **ground truth labels** for **temporally ordered symptoms**.
- Manually validated a subset of generated labels to ensure **accuracy**.

### **2️⃣ Temporal Symptom Ordering (Seq2Seq & LLMs)**
- **Fine-tuned transformer-based seq2seq models (BioBART-v2, Flan-T5)** using **LoRA-based PEFT** for symptom ordering.
- Applied **Chain of Thought (CoT) prompting** with **Claude-3.5-Sonnet** as an alternative approach.
- Evaluated models using **Kendall’s Tau, LCS Ratio, and Levenshtein Ratio** to compare fine-tuning vs. LLM inference.

### **3️⃣ Associative Analysis (Co-Occurrence Mining)**
- Identified **frequent symptom patterns** using the **Apriori algorithm**.
- Computed **support, confidence, and lift** to quantify symptom relationships.

## Tools & Technologies
- **Programming:** Python
- **Data Processing:** Pandas, NumPy
- **NLP & LLMs:** Google Gemini API, Claude-3.5-Sonnet, SpaCy, NLTK
- **Machine Learning:** BioBART-v2, Flan-T5, LoRA Fine-Tuning (PEFT)
- **Association Rule Mining:** Apriori Algorithm
- **Evaluation Metrics:** Kendall’s Tau, LCS Ratio, Levenshtein Ratio

## Challenges & Solutions
| Challenge | Solution |
|-----------|----------|
| No ground truth labels for temporal ordering | Used **few-shot inference with Google Gemini API** to generate labels. |
| Computational constraints for model fine-tuning | Utilized **Google Colab/Kaggle cloud GPUs** for training. |

