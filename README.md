# Banking Fraud & Risk Intelligence System

Analysis of 550,000 Indian banking transactions to identify fraud patterns, engineer behavioral risk features, build and evaluate machine learning models for fraud detection, and deliver a risk-based investigation prioritization system — backed by an interactive Power BI dashboard.

**Dashboard:** `dashboard/Banking_Fraud_Risk_Dashboard.pbix`
**Headline finding:** Fraud accounts for just 0.886% of transactions but represents **₹58.2 crore** in exposed value. Reviewing just the highest-risk ~1% of transactions captures a disproportionate share of that exposure.

---

## 1. Business Objective

Banks process millions of transactions where fraud is rare (well under 1%) but costly. This project builds an end-to-end pipeline — from raw transaction data to a deployable risk-scoring system — that helps a fraud investigation team prioritize limited review capacity toward the transactions most likely to be fraudulent.

## 2. Dataset

- **Source:** Indian Banking Transactions dataset (synthetic), 2019–2024
- **Size:** 550,000 transactions, 20 original columns, ~79,900 unique customers
- **Fraud rate:** 0.886% (4,873 fraud transactions)
- **Known limitations** (identified and documented, not hidden):
  - `transaction_amount` and `account_balance` were generated independently — ~11.85% of debit transactions show an amount exceeding the account's balance. This turned out to be a *useful* signal (see Feature Engineering) rather than a flaw to clean away.
  - `transaction_hour` is distributed almost perfectly uniformly across all 24 hours (~22.5–23k transactions/hour), suggesting hour was randomly assigned rather than reflecting real customer behavior.
  - Average transactions per customer is low (~6.9, max ~12), which limited the reliability of customer-level (as opposed to transaction-level) fraud analysis.

## 3. Project Pipeline

| Phase | Tool | Notebook/File | Summary |
|---|---|---|---|
| 1. Data Cleaning & Understanding | Python | `01_Data_Cleaning.ipynb` | Null handling, consistency checks, outlier investigation |
| 2. SQL Business Analysis | MySQL | `sql/banking_fraud_analysis.sql` | Fraud-rate breakdowns across transaction type, geography, time, customer risk factors |
| 3. EDA Visuals | Python | `02_EDA_Visuals.ipynb` | Supporting charts for key SQL findings |
| 4. Feature Engineering | Python | `03_Feature_Engineering.ipynb` | Leakage-safe behavioral features |
| 5. Machine Learning | Python | `04_Fraud_Modeling.ipynb` | Logistic Regression, Random Forest, XGBoost |
| 6. Evaluation & Threshold Tuning | Python | `04_Fraud_Modeling.ipynb` | Precision/recall trade-off, operational-volume-aware threshold selection |
| 7. Risk Scoring | Python | `04_Fraud_Modeling.ipynb` | Risk bands (Low/Medium/High/Critical), investigation priority list |
| 8. Explainability | Python | `05_Model_Explainability.ipynb` | SHAP global and local feature attribution |
| 9. Dashboard | Power BI | `dashboard/Banking_Fraud_Risk_Dashboard.pbix` | Single-page interactive dashboard |

## 4. Key Findings

### Where fraud risk concentrates
- **Transaction type is the strongest standalone signal.** RTGS transactions show a 1.854% fraud rate — **~2.1x** the 0.886% baseline — despite being a relatively low-volume channel. Cheque is second-highest (1.179%). UPI, the highest-volume channel, is one of the *safest* (0.786%).
- **Merchant category, state, time of day, KYC status, and credit score all showed no meaningful fraud-rate variation** (each stayed within a narrow band close to the baseline). This was tested explicitly, not assumed — ruling these out was as important to the analysis as finding what *does* matter.

### Engineered features (Phase 4)
| Feature | What it captures | Fraud vs. Legitimate | Signal |
|---|---|---|---|
| `exceeds_balance` | Transaction amount exceeds account balance (debit) | 1.31% vs 0.81% fraud rate | Strong |
| `amount_to_balance_ratio` | Continuous version of the above, capped at 10 | 1.54 vs 0.79 (mean) | Strong |
| `amount_vs_customer_avg` | Transaction size relative to that customer's own historical average (built leakage-safely, using only prior transactions) | 2.45 vs 1.86 (mean) | Moderate |
| `days_since_last_transaction` | Gap since the customer's previous transaction | 215 vs 221 days | None |

All customer-relative features were built using only each customer's *past* transactions at the time of each row, to avoid data leakage from future information the model wouldn't realistically have access to.

### Machine Learning
Fraud detection on a 0.886%-imbalanced dataset makes accuracy a meaningless metric — a model that always predicts "not fraud" scores ~99% accuracy while catching zero fraud. All models were evaluated on precision, recall, and a business-realistic constraint: **what % of transactions would actually get flagged for human review.**

- **Logistic Regression** (baseline): with class balancing, achieved 30% recall at 1% precision (26,455 false positives) — illustrates the imbalance problem directly.
- **Random Forest**: at the default 0.5 threshold, caught almost no fraud. An initial "optimized" threshold (0.02) looked strong on paper (61.3% recall) but was found to flag **55.6% of all transactions** — operationally unusable for any real investigation team. Re-tuning with flagged-volume as an explicit constraint produced a workable threshold of **0.10**: ~1.28% of transactions flagged, 8.4% recall, ~6% precision.
- **XGBoost**: tested as a third model after Random Forest showed weak probability separation. Required careful tuning of `scale_pos_weight` — the naive "full ratio" setting (110) caused the model to flag 74% of all transactions; a moderate setting (30) gave comparable recall to Random Forest but still over-flagged. **Conclusion: the feature set, not the algorithm, is the primary ceiling on performance** — a more complex model did not meaningfully outperform a properly-tuned simpler one.

### Explainability (SHAP)
- Random Forest's built-in `feature_importances_` was shown to be **unreliable**: it ranked `exceeds_balance` outside the top 15 features despite its strong validated fraud signal — a known bias of that method toward high-cardinality numeric columns.
- Proper SHAP analysis confirmed this and explained *why*: `exceeds_balance` correlates 0.537 with `amount_to_balance_ratio` (both derived from the same two underlying columns), so the model relies on the richer continuous feature and treats the binary flag as largely redundant — a genuine feature-redundancy finding, not a contradiction of the earlier EDA result.

### Risk Scoring & Investigation Prioritization
Transactions were bucketed into Low/Medium/High/Critical risk bands based on model probability. The bands validate cleanly against real fraud rates:

| Risk Band | Fraud Rate |
|---|---|
| Low | 0.82% |
| Medium | 5.60% |
| High | 6.52% |
| Critical | 15.38% (~19x baseline) |

On the held-out test set, focusing investigation effort on just the **197 transactions** flagged High/Critical surfaced **14 real fraud cases worth ₹1.28 crore** — a ~40x improvement in hit rate over random review.

## 5. Dashboard

A single-page Power BI dashboard (dark theme, charcoal & amber palette) consolidates the above into:
- Executive KPIs (total transactions, fraud rate, fraud value exposed, value captured)
- Monthly fraud rate trend
- Fraud rate by transaction type (RTGS highlighted)
- Fraud rate: exceeds-balance vs. normal transactions
- Risk band distribution table
- Investigation priority list — real transaction IDs ranked by model risk score, filtered to the model's genuinely held-out test set to avoid showing artificially inflated training-data scores

## 6. Limitations

- The dataset is synthetic; some patterns real banking data would show (e.g., time-of-day fraud clustering, KYC-status correlation) are absent here because the generator did not simulate them.
- Low average transactions-per-customer limited the reliability of customer-level (repeat-offender) fraud analysis — this was tested, found statistically unreliable, and the project's feature engineering was redirected toward transaction-level signals as a result.
- Model precision at operational thresholds remains modest (~6%), reflecting the genuine difficulty of fraud detection under severe class imbalance rather than a flaw in the pipeline — this is consistent with published results on other well-known fraud datasets.

## 7. Tech Stack

Python (Pandas, NumPy, scikit-learn, XGBoost, SHAP, Matplotlib/Seaborn) · MySQL · Power BI · Jupyter

## 8. Repository Structure

```
fraud_risk_management/
├── data/
├── notebooks/
│   ├── 01_Data_Cleaning.ipynb
│   ├── 02_EDA_Visuals.ipynb
│   ├── 03_Feature_Engineering.ipynb
│   ├── 04_Fraud_Modeling.ipynb
│   └── 05_Model_Explainability.ipynb
├── sql/
│   └── banking_fraud_analysis.sql
├── dashboard/
│   └── Banking_Fraud_Risk_Dashboard.pbix
├── images/
└── README.md
```

## 9. Author

Anchita Bose
