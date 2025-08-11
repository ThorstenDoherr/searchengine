"""
python seml.py
Trains a neural network based on meta information and scrutinized training samples to identify false positives in 
SearchEngine results. Several network profiles will be trained and the best in regard of the retained sub-sample 
will be used to predict false positives in the meta data. The retention represents the out-of-sample prediction to
prevent overfitting. 

Requirements:
The script will need Python 3.x. It will try to automatically download all necessary python packages if not already
installed. Following packages are required: tensorflow (includes numpy and keras), scikit-learn, pandas and pyarrow.
If you want to have more control over the installation you can install them manually with:
python -m pip install <package-name>
Tensorflow may throw exceptions if specific system requirements are not fulfilled. On Windows systems, many of these are
related to a missing or outdated "Microsoft Visual C++ Redistributable", which can be downloaded for free directly from
Microsoft (just google it).

Input:
meta.txt - full meta data export of the SearchEngine result table.
*sample*.txt - scrutinized samples in ExtendedExport format, i.e. sample1.txt, export_sample.txt
               Multiple sample files matching the template *sample*.txt will be merged.
			   If there is no sample file, the script will only conduct the prediction based on an already trained
			   network in seml.brain.

All txt files have to be tab-delimited.

Output:
meta.feather - prepared and compressed meta data (csv format also available, see "output" setting).
sample.csv - assigns the essential "equal" variable to every candidate based on the sample files and default setting.
training.csv - training data: canidate assignment (searched, found, equal), retention indicator, and the meta data.
seml.brain.log - training output of the confusion matrices if applicable.
seml.brain - neural network model save file (zipped keras model + variable names used for training).
seml.csv - prediction file (contains reference to sample data if applicable).

All csv files are comma-separated.

Labeling:
- Read the manual about efficient labeling.
- The "equal" variable has to be 1 (match) or 9 (non-match) in sample files (zeroes are considered missings).
- The data is separated into candidate blocks consisting of a header with the search term followed by candidates.
- A value in a candidate block header defines the default value for the block (reduces typing).
- The default value in the canidate block header is used for all missings and zeroes within a block.
- You can define a global default value for the candidate block header in the settings (see below). 

Script schedule:
If the file seml.brain does not exists, the script will start with the training based on the meta and the sample data.
If the seml.brain file is created or already existing, it will commence with the prediction.
It will always try to use the csv files first but will compile them from the txt files if necessary.
To retrain the network with different settings: delete the seml.brain file.
To retrain the network with different retention: additionally delete the training.csv file
To retrain the network after changes to the sample file(s): additionally delete the sample.csv file.
To retrain the network after changes to meta.txt: additionally delete the meta.feather file.

Settings:
default - global default if "equal" assignment in the candidate block header is missing:
          0 = keep missing (default), 1 = true positive, 9 = false positive
conflict - preference in case of conflicting "equal" assignments in multiple sample files:
           0 = keep first occurrence based on file order (default), 1 = true positive, 9 = false positive
retention - share that will not be used for training but for out-of-sample prediction (default 0.1)
verbose - 0 = mute (default), 1 = show iterations, 2 = progress bar per iteration
hidden - list of neural network hidden layer layouts competing for best out-of-sample accuracy:
         [[0], [25], [50], [100], [25,25], [50,50], [100,100]]
balance - balancing of true and false positives in case of heavily skewed distributions:
          False = keep original distribution (default), True = balancing of true and false positives
epochs - number of training iterations (default 500)
batch - batch size for training (default 8)
output - output format for the meta data based on extension:
         csv = slow comma-separated text format but highly interoperable with many systems
         feather = fast binary format but almost only used in the python world (default)
"""
default = 0 # default for equal: 0 = keep missing, 1 = missing is true positive, 9 = missing is false positive
conflict = 0 # multiple samples conflict preference: 9 = false pos., 1 = true pos., 0 = keep first occurrence  
retention = 0.1 # 0.1 will retain 10% of the training data for out-of-sample simulation 
verbose = 0 # 0 = silent, 1 = noisy, 2 = loud
hidden = [[0], [25], [50], [100], [25,25], [50,50], [100,100]] # remove layouts when in a hurry
balanced = False # True for balancing false & true positives, False otherwise
epochs = 500 # reduce when in a hurry, increase for diminishing returns
batch = 8 # lower is slower with very slight gains in efficiency
output = "feather" # use "csv" (comma-separated text) for slower but more flexible format for the meta data

import os 
import sys
import glob
import importlib
import subprocess
from zipfile import ZipFile
# import code
# code.interact(local=locals()) evokes interactive console at any position in the code for debugging
  
def install_package(package_name, install_name=None):
    try:
        importlib.import_module(package_name)
    except ImportError:
        print(f"INSTALLING {package_name}...")
        if not install_name:
            install_name = package_name
        subprocess.check_call([sys.executable, "-m", "pip", "install", install_name])

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
install_package('tensorflow')
install_package('sklearn', 'scikit-learn')
install_package('pandas')
install_package('pyarrow')

import numpy as np
import pandas as pd
from sklearn.metrics import confusion_matrix
from sklearn.utils import class_weight
from tensorflow.keras import models, Sequential
from tensorflow.keras.layers import Normalization, Dense

def load_data(file_name):
    file_name, dot, ext = file_name.rpartition('.')
    ext = ext.lower()
    if ext == 'txt':
        return pd.read_csv(file_name+'.txt', delimiter='\t', encoding='latin1', index_col=False)
    return pd.read_csv(file_name+'.csv', delimiter=',', encoding='latin1', index_col=0)

def load_meta(file_name):
    file_name, dot, ext = file_name.rpartition('.')
    ext = ext.lower()
    if ext == 'txt':
        return pd.read_csv(file_name+'.txt', delimiter='\t', encoding='latin1', index_col=False)
    if output == 'csv':
        return pd.read_csv(file_name+'.csv', delimiter=',', encoding='latin1', index_col=0)
    return pd.read_feather(file_name+'.feather')

def save_meta(data, file_name='meta.csv'):
    file_name, dot, ext = file_name.rpartition('.')
    if output == 'csv':
        data.to_csv(file_name+'.csv')
    else:
        data.to_feather(file_name+'.feather')

def read_sample():
    print('checking sample.csv')
    sample = None
    try:
        sample = load_data('sample.csv')
    except:
        print('reading *sample*.txt template')
        files = glob.glob('*sample*.txt')
        samples = []
        for f in files:
            samples.append(read_a_sample(f))
        sample = pd.concat(samples, ignore_index=True)
        del samples
        sample['pos'] = range(1, len(sample)+1)
        sample.sort_values(by=['searched','found','equal'], inplace=True)
        overlap = (sample['searched'] == sample['searched'].shift(1)) & (sample['found'] == sample['found'].shift(1))
        cnt = overlap.sum()
        if cnt > 0:
            print(f'overlap {cnt}')
            strife = (overlap & (sample['equal'] != sample['equal'].shift(1))).sum()
            if strife > 0:
                print(f'conflicts {strife}')
                if conflict == 1:
                    print('preference true positive')
                    sample = sample.drop_duplicates(subset=['searched', 'found'], keep='last')
                elif conflict == 9:
                    print('preference false positive')
                    sample = sample.drop_duplicates(subset=['searched', 'found'], keep='first')
                else:
                    print('preference file order')
                    sample.sort_values(by=['searched','found','pos'], inplace=True)
                    sample = sample.drop_duplicates(subset=['searched', 'found'], keep='first')
            else:
                print('no conflicts')
                sample = sample.drop_duplicates(subset=['searched', 'found'], keep='first')
        sample = sample[['searched','found','equal']]
        print('saving sample.csv')
        sample.to_csv('sample.csv')
    print(f'{sample.shape[0]} rows, {sample.shape[1]} cols')
    return sample
 
def read_a_sample(file):
    print(f'reading {file}')
    sample = load_data(file)
    sample.columns = sample.columns.str.lower()
    sample = sample[['searched','found','equal']].replace(0, np.nan)
    sample = sample.loc[sample['searched'].notna()]
    equal = sample.loc[sample['found'].isna(),['searched','equal']]
    equal['equal'] = equal['equal'].fillna(default)
    sample.dropna(subset=['found'], inplace=True)
    sample = sample.merge(equal, how='left', on='searched', suffixes=(None, '_u'))
    sample['equal'] = sample['equal'].fillna(sample['equal_u'])
    sample = sample.drop(columns=['equal_u']).dropna().astype('int')
    sample['equal'] = sample['equal'].apply(lambda x : 1 if x > 0 and x <= 5 else 0 if x > 5 and x <= 9 else 9)
    sample.drop(sample[sample['equal'] == 9].index, inplace=True)
    sample_unique = sample.drop_duplicates(subset=['searched', 'found'], keep='first')
    if len(sample_unique) < len(sample):
        print(f'dropping duplicates {len(sample)-len(sample_unique)}')
    return sample_unique
    
def read_meta():
    print('checking meta.csv')
    meta = None
    try:
        meta = load_meta('meta.csv')
    except:
        print('reading meta.txt')
        meta = load_meta('meta.txt')
        meta.columns = meta.columns.str.lower()
        meta['searched'] = meta['searched'].astype('int')
        meta['found'] = meta['found'].astype('int')
        meta['cntln'] = np.log(meta['cnt'])
        # standard deviations of string comparisons within "searched" group
        for c in meta.columns:
            if (c.startswith('csf') or c.startswith('cfs')) and c[3:].isdigit():
                meta[c+'sd'] = meta.groupby('searched')[c].transform('std').fillna(0)
        print(f'saving meta.{output}')
        save_meta(meta)
    print(f'{meta.shape[0]} rows, {meta.shape[1]} cols')
    return meta

def compose_training():
    print('checking training.csv')
    try:
        train = load_data('training.csv')
    except:
        sample = read_sample()
        sample['retention'] = np.random.uniform(size=len(sample))
        sample['retention'] = np.where(sample['retention'] <= retention, 1, 0).astype('int')
        sample = sample[['searched','found','retention','equal']]
        meta = read_meta()
        train = sample.merge(meta, how='inner', on=['searched','found'])
        if len(train) != len(sample):
            raise ValueError(f'sample records not found in meta: {len(sample)-len(train)}')
        del sample, meta # free memory
        # no variation within train data
        min = train.loc[train['retention'] == 0, train.columns.difference(['searched','found','equal','retention'])].min()
        max = train.loc[train['retention'] == 0, train.columns.difference(['searched','found','equal','retention'])].max()
        drop = min[min == max]
        if drop.shape[0]:
            train.drop(columns=drop.index, inplace=True)
            print(f'columns without variation in training data:\n{", ".join(drop.index)}')
        print('saving training.csv')
        train.to_csv('training.csv')
    print(f'{train.shape[0]} rows, {train.shape[1]} cols')
    print('training and retention')
    tab = train[['retention','equal']].groupby(['retention','equal']).value_counts().to_frame().reset_index()
    tab['equal'] = tab['equal'].replace(0, 9)
    print(tab.to_string(index=False))
    return train

def training(train):
    print('training...')
    x_train = train.loc[train['retention']==0,'identity':].reset_index(drop=True)
    y_train = train.loc[train['retention']==0,'equal'].reset_index(drop=True)
    x_test = train.loc[train['retention']==1,'identity':].reset_index(drop=True)
    y_test = train.loc[train['retention']==1,'equal'].reset_index(drop=True)
    normalizer = Normalization(axis=-1)
    normalizer.adapt(x_train.values)
    if balanced:
        class_weights = dict(enumerate(class_weight.compute_class_weight(class_weight='balanced', classes=np.unique(y_train), y=y_train)))
    else:
        class_weights = {0: np.float64(1), 1: np.float64(1)}
    best_acc = 0
    best_layer = 0
    best_model = None
    best_cm = None
    with open('seml.brain.log', 'w') as log:
        for num, layers in enumerate(hidden):
            layers = [l for l in layers if l > 0]
            line = f"model {num+1}: layers {'x'.join([str(l) for l in [len(x_train.columns)]+layers+[1]])}, epochs {epochs}, batch {batch}{', balanced' if balanced else ''}" 
            print(line)
            log.write(line+'\n')
            model = Sequential()
            model.add(normalizer)
            for layer in layers:
                model.add(Dense(units=layer, activation='relu'))
            model.add(Dense(units=1, activation='sigmoid'))
            model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
            model.fit(x_train, y_train, class_weight=class_weights, epochs=epochs, batch_size=batch, verbose=verbose)
            y_pred = (model.predict(x_test, verbose=0) > 0.5).astype('int')
            cm = confusion_matrix(y_test, y_pred)
            acc, tab = confuse(cm)
            print(tab)
            log.write(tab+'\n')
            if acc > best_acc:
                best_acc = acc
                best_layer = num
                best_model = model
                best_cm = cm
        line = f"best model {best_layer+1}: layers {'x'.join([str(l) for l in [len(x_train.columns)]+hidden[best_layer]+[1]])}, epochs {epochs}, batch {batch}{', balanced' if balanced else ''}"
        acc, tab = confuse(best_cm)
        print(line)
        print(tab)
        log.write(line+'\n')
        log.write(tab+'\n')
    print('saving seml.brain')
    names = list(x_train.columns)
    save_brain(model, names)
    return model, names

def prediction(model, names):
    meta = read_meta()
    meta.drop(meta.columns.difference(['searched','found']+names), axis=1, inplace=True)
    meta.columns = ['searched','found']+names
    seml = meta.loc[:,['searched','found']]  # separate keys from data
    meta.drop(['searched','found'], axis=1, inplace=True)  # pure data without keys
    print('predicting...')
    print(f'{meta.shape[0]} rows, {meta.shape[1]} cols')
    seml.loc[:,['brain']] = model.predict(meta.values, verbose=verbose)
    seml['equal'] = np.where(seml['brain'] > 0.5, 1, 9).astype('int')
    tab = seml[['equal']].groupby(['equal']).value_counts()
    tab['sum'] = tab.sum()
    tab = tab.to_frame()
    tab['share'] = tab['count']/tab.loc['sum','count']*100
    print(tab.reset_index().to_string(index=False))
    try:
        sample = load_data('sample.csv')
    except:
        print('no sample.csv detected')
    else:
        print('attaching sample.csv')
        seml = seml.merge(sample, how='left', on=['searched','found'], suffixes=('','_s'))
        seml['sample'] = np.where(seml['equal_s'] == 0, 9, seml['equal_s'])
        seml['sample'] = seml['sample'].fillna(0).astype('int')
        seml.drop(seml.columns.difference(['searched','found','brain','equal','sample']), axis=1, inplace=True)
        tab = seml.loc[seml['sample'] != 0, ['equal','sample']].groupby(['equal','sample']).value_counts().to_frame()
        print(tab.reset_index().to_string(index=False))
    print('saving seml.csv')
    seml.to_csv('seml.csv', index=False, float_format='%.6f')
    
def confuse(cm):
    tn, fp = cm[0]
    fn, tp = cm[1]
    acc = (tp+tn)/(tp+tn+fp+fn)
    tab = f'acc {acc*100:6.2f}            true        false\n'
    tab += f'positive      {tp:12} {fp:12}\n'
    tab += f'negative      {tn:12} {fn:12}\n'
    tab += f'recall              {tp/(tp+fn)*100:6.2f}       {tn/(tn+fp)*100:6.2f}\n'
    tab += f'precision           {tp/(tp+fp)*100:6.2f}       {tn/(tn+fn)*100:6.2f}'
    return (acc, tab) 
    
def save_brain(model, names):
    model.save("seml.keras")
    with open("seml.names", mode="w") as f:
        f.write(",".join(names))
    with ZipFile("seml.brain", mode="w") as f:
        f.write("seml.keras")
        f.write("seml.names")
    os.remove("seml.keras")
    os.remove("seml.names")
   
def load_brain():
    with ZipFile("seml.brain", mode="r") as f:
        f.extract("seml.keras")
        f.extract("seml.names")
    model = models.load_model("seml.keras")
    with open("seml.names", mode="r") as f:
        names = f.readline().strip().split(',')
    os.remove("seml.keras")
    os.remove("seml.names")
    return (model, names)

def main(argv):
    try:
        model, names = load_brain()
    except FileNotFoundError:
        print('TRAINING')
        train = compose_training()
        model, names = training(train)
        del train
    print('PREDICTION')
    prediction(model, names)
    print('done.')
    
if __name__ == "__main__": sys.exit(main(sys.argv))
