import pandas as pd
import os
import ast
import numpy as np
import re
import pathlib

#-------------------------------------------------------------------------------
# 0.SETUP
#-------------------------------------------------------------------------------

# set paths
input_path = 'Data/raw_data'
out_path = 'Data/cleaned_data'

# load cities 
with open('files/cities.txt') as f:
    contents = f.read()
    cities = ast.literal_eval(contents)

#-------------------------------------------------------------------------------
# 1.AGGREGATE DATA
#-------------------------------------------------------------------------------

df_list = list()

for city in cities:
    location = city['city']
    path_to_csv_data = os.path.join(input_path, location, 'csv_data')
    city_data = pd.read_csv(os.path.join(path_to_csv_data, 'salaries_' + location + '.csv'))
    city_data['country_code'] = city['country_code']
    city_data['location'] = location

    df_list.append(city_data)

data = pd.concat(df_list)
data.reset_index(inplace=True, drop=True)

#-------------------------------------------------------------------------------
# 2.DATA CLEANING
#-------------------------------------------------------------------------------

#*******************************************************************************
# 2.1 Convert epochs to datatime and drop old datapoints
#*******************************************************************************

# for col in data.filter(regex=r'^lastUpdateTimestamp_'):
for col in data.loc[:, data.columns.str.startswith('lastUpdateTimestamp_')]:
    data[col] = pd.to_datetime(data[col], unit='ms')

# check that values are always updated synchrounously
all_cols_equal = data.loc[:, data.columns.str.startswith('lastUpdateTimestamp_')].eq(data.loc[:, 'lastUpdateTimestamp_daily'], axis=0).all().all()

# if so, keep only one timestamp
if all_cols_equal == True:
    data['last_updated'] = data['lastUpdateTimestamp_daily']
    data.drop(data.columns[data.columns.str.startswith('lastUpdateTimestamp_')], axis=1, inplace=True)
    # drop data not recently updated
    data = data[data['last_updated']>='2022']
else:
    raise NotImplementedError

#*******************************************************************************
# 2.2 Remove countries and cities with data on less than 20 job positions'
#*******************************************************************************

# some data points mistakenly refer to countries and should be droppped
data = data[data['type']!='COUNTRY']

# clean location name
pattern = re.compile(r"--.*")
data['location'] = data['location'].str.replace(pattern, '', regex=True)

# data[data['location']!=data['city_name']][['location', 'city_name']].head(100)
data['city_n_postings'] = data.groupby('location').transform('size')
# print(data['city_n_postings'].value_counts())
data = data[data['city_n_postings']>=20]

#*******************************************************************************
# 2.3 Calculate sample size
#*******************************************************************************

# get samples size across different levels
data['numDataPoints'] = data.loc[:, data.columns.str.startswith('numDataPoints_')].sum(axis=1)
data.drop(data.columns[data.columns.str.startswith('numDataPoints_')], axis=1, inplace=True)

#*******************************************************************************
# 2.4 Drop useless columns
#*******************************************************************************

# inferred appears to be always false (not clear what it means), while salaryType
# simply repeats the level (e.g. MONTHLY, YEARLY, ...)
data.drop(data.columns[data.columns.str.startswith(tuple(['salaryType_', 'inferred_']))], axis=1, inplace=True)

#*******************************************************************************
# 2.5 Keep only monthly and yearly data
#*******************************************************************************

data.drop(data.columns[data.columns.str.endswith(tuple(['_hourly', '_daily', '_weekly']))], axis=1, inplace=True)

#*******************************************************************************
# 2.6 Uniform currencies to Euros
#*******************************************************************************

# load file with exchange rates
with open('files/exchange_rates_to_eur_20230514.txt') as f:
    contents = f.read()
    exchange_rates = ast.literal_eval(contents)
exchange_rates = pd.DataFrame(list(exchange_rates.items()), columns=['currency', 'rate'])
data = pd.merge(data, exchange_rates, on='currency', how='inner')

# define prefixes of columns not expressed in currency
for col in data.columns[data.columns.str.startswith(tuple(['mean', 'std', 'estimated']))]:
    data[col] = np.round(data[col]*data['rate'], 2)

data.drop(['rate', 'currency'], axis=1, inplace=True)

#-------------------------------------------------------------------------------
# 3.STORE CLEANED DATA
#-------------------------------------------------------------------------------

pathlib.Path(out_path).mkdir(parents=True, exist_ok=True)
data.to_csv(os.path.join(out_path, 'final_salaries_data.csv'), index=False)
print('Data Cleaned Successfully!')