fMRI Beta Regression Analysis
Data Mining Class Project

--------------------------------------------------
PROJECT OVERVIEW
--------------------------------------------------

This project investigates relationships between personality/questionnaire measures and fMRI activation values during a trust-based decision-making task.

The analysis uses machine learning and regression approaches to predict brain activation values (beta values) from questionnaire data.

The notebook evaluates:
- Multiple Linear Regression
- Ridge Regression
- Lasso Regression

Model performance is compared using:
- 5-fold cross-validation
- 10-fold cross-validation
- 80/20 train-test split

--------------------------------------------------
DATASET DESCRIPTION
--------------------------------------------------

File:
BetasCorrelation.xlsx

The dataset contains:
- One row per participant
- fMRI beta values extracted from significant brain regions
- Questionnaire/personality variables used as predictors

Variables include:
1. Brain activation beta values
   - Dependent variables (targets)
   - Represent activation levels extracted from fMRI contrasts

2. Questionnaire variables
   - Independent variables (predictors)
   - Derived from multiple personality and behavioral questionnaires

The dataset was prepared for exploratory data mining and predictive modeling.

--------------------------------------------------
FILES INCLUDED
--------------------------------------------------

1. BetasCorrelation.xlsx
   Main dataset used for all analyses.

2. fmri_beta_regression.ipynb
   Jupyter notebook containing all preprocessing, modeling, evaluation, and visualization code.

--------------------------------------------------
HOW TO RUN THE ANALYSIS
--------------------------------------------------

Requirements:
- Python 3.x
- Jupyter Notebook

Recommended packages:
- pandas
- numpy
- scikit-learn
- matplotlib
- seaborn
- openpyxl

Install packages with:
pip install pandas numpy scikit-learn matplotlib seaborn openpyxl

--------------------------------------------------
RUNNING THE NOTEBOOK
--------------------------------------------------

1. Open the notebook:
   fmri_beta_regression.ipynb

2. Run the first cell.
   You will be prompted to upload:
   BetasCorrelation.xlsx

3. Run the remaining notebook cells.

The notebook will:
- Load and preprocess the dataset
- Standardize predictor variables
- Train regression models
- Perform cross-validation
- Generate evaluation metrics and plots
- Export result files

--------------------------------------------------
OUTPUTS
--------------------------------------------------

The notebook generates:
- Regression performance metrics
- Cross-validation results
- Predicted vs. actual plots
- Feature importance information
- CSV result tables
- PNG visualization files

--------------------------------------------------
PROJECT PURPOSE
--------------------------------------------------

The goal of this project is to explore whether individual differences measured through questionnaires can predict neural activity patterns associated with trust and decision-making.

This project was completed as part of a data mining course using real fMRI-derived research data.

--------------------------------------------------
NOTES
--------------------------------------------------

- This repository is intended for educational and research purposes.
- The analysis focuses on exploratory modeling rather than clinical prediction.
- Interpretation of results should consider the relatively small sample size typical of fMRI studies.
