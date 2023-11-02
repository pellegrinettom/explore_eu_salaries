# Project Description
This repository contains the code and output for an exploratory analysis of salaries in major European cities.
The main goal of this project is to compare the distribution of median salaries for more than 90 different job titles across 28 European cities. ChatGPT was used to define the composition of the sample of job titles, and salary data was collected from a well-known job search engine. The data collection and cleaning processes were conducted using Python, while the visualizations were created using R.

# Code Description
Here is a description of the scripts in the ```codes``` folder:
- ```01_scrape_data.py```: Sources salary data from the job search engine to build our dataset.
- ```02_clean_data.py```: Cleans raw data to ensure data quality and consistency.
- ```03_create_visuals.R```: Creates data visualizations with ggplot2.

# Visuals
![Fig. 1]('visuals/avgmediansalary.png') <br>
![Fig. 2]('visuals/avgmediansalarybox.png') <br>
![Fig. 3]('visuals/avgmediansalarymap.png') <br>
![Fig. 4]('visuals/corrheatmap.png') <br>
![Fig. 5]('visuals/highestandlowestsalaries.png') <br>
![Fig. 6]('visuals/ridgeslargecities.png') <br>

# Disclaimer
The results of this analysis are for educational and exploratory purposes only.
They should not be considered representative of real-world salary conditions in the selected European cities. This analysis is an outcome of a learning exercise and does not provide definitive insights into actual salary patterns. Any reproduction of the visuals in this repository requires explicit consent from the author.
