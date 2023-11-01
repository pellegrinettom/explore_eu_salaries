import requests
import json
import pandas as pd
import ast
import time
import random
from tqdm import tqdm
import pathlib
from termcolor import colored
# from googletrans import Translator # translating job titles in local lang

#-------------------------------------------------------------------------------
# SETUP
#-------------------------------------------------------------------------------

# set paths
out_path = 'Data/raw_data/'

# read cookies and headers to access the webpage
with open('secrets/cookies.txt') as f:
    contents = f.read()
    cookies = ast.literal_eval(contents)

with open('secrets/headers.txt') as f:
    contents = f.read()
    headers = ast.literal_eval(contents)

# import data on cities and jobs to scrape
with open('files/cities.txt') as f:
    contents = f.read()
    cities = ast.literal_eval(contents)

with open('files/jobs.txt') as f:
    contents = f.read()
    jobs = ast.literal_eval(contents)

# initialize a progress bar
total_iterations = len(jobs) * len(cities)
progress_bar = tqdm(total=total_iterations)

# create an instance of the Translator class
# translator = Translator()

#-------------------------------------------------------------------------------
# RUN THE SCRAPER
#-------------------------------------------------------------------------------

problematic_extractions = []

for city in cities: 

    location, country, locale = city.values()

    # create folders for storing data
    city_txt_path = out_path + location + '/txt_data/'
    pathlib.Path(city_txt_path).mkdir(parents=True, exist_ok=True)
    city_csv_path = out_path + location + '/csv_data/'
    pathlib.Path(city_csv_path).mkdir(parents=True, exist_ok=True)

    # init dict for the city
    city_dict = dict()

    pause = random.randint(5,10)
    time.sleep(pause)

    for job in jobs:

        # translate a string from English to local lang (currently not implemented)
        # job_translated = translator.translate(job, dest=country.lower())

        print('Scraping city data on {} in {} ({})'.format(job, location, country))
        progress_bar.update(1)
        pause = random.randint(2,4)
        time.sleep(pause)

        city_dict[job] = dict()

        params = {
            'country': country,
            'locale': locale,
            'location': location,
            }
        
        url = 'add/URL/here{}'.format(job.replace(' ', '%20'))
        response = requests.get(url,
                params=params,
                cookies=cookies,
                headers=headers,
            )
        
        if response.status_code != 200:
            print('Problematic extraction:', job, location)
            problematic_extractions.append((job, location))
            continue
        
        response_dict = json.loads(response.content.decode('utf-8'))

        # check that the dictionary has all the necessary keywords
        if all(key in response_dict.keys() for key in ['salaries', 'location']) == False:
            print(colored("WARNING: Some keys are not present in the dictionary. Skipping job...", 'yellow'))
            problematic_extractions.append((job, location))
            continue

        if all(key in response_dict['location']['locationDetails'].keys() for key in ['name', 'population']) == False:
            print(colored("WARNING: Some location keys are not present in the dictionary. Skipping job...", 'yellow'))
            problematic_extractions.append((job, location))
            continue

        if all(key in response_dict['salaries'].keys() for key in ['currency', 'salaries']) == False:
            print(colored("WARNING: Some salaries keys are not present in the dictionary. Skipping job...", 'yellow'))
            problematic_extractions.append((job, location))
            continue

        # success flag for the presence of salaries data at at least one level
        success = False

        for level in ['HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']:

            try:
                for key in list(response_dict['salaries']['salaries'][level].keys()):

                    new_key = key + '_' + level.lower()

                    # rename the key
                    city_dict[job][new_key] = response_dict['salaries']['salaries'][level][key]
                    success = True


            except KeyError:
                    # print("Some LEVEL keys are not present in the dictionary.")
                    continue
        
        # if no level found, skip to the next job position
        if success == False:
            print(colored("WARNING: Salaries not available. Skipping job...", 'yellow'))
            problematic_extractions.append((job, location))
            continue   

        # get data on locations
        city_dict[job]['city_name'] = response_dict['location']['locationDetails']['name']
        city_dict[job]['type'] = response_dict['location']['locationDetails']['type']
        city_dict[job]['city_population'] = response_dict['location']['locationDetails']['population']

        # get data on currency
        city_dict[job]['currency'] = response_dict['salaries']['currency']

        # save dictionary as a txt for possible further analyses
        with open(city_txt_path + 'salaries_{}_{}.txt'.format(location, job.replace(' ', '-')), 'w') as file:
            file.write(json.dumps(response_dict))

    # store data in a pandas data frame
    city_data = pd.DataFrame.from_dict(city_dict, orient='index')
    city_data.reset_index(inplace=True, drop=False)
    city_data.rename(columns={'index':'job'}, inplace=True)
    city_data.to_csv(city_csv_path + 'salaries_' + location + '.csv', index=False)

# keep track of problematic extractions
log_problems = dict()
log_problems['problematic extractions'] = problematic_extractions

with open(out_path + 'problematic_extractions.txt', 'w') as file:
    file.write(json.dumps(log_problems))







