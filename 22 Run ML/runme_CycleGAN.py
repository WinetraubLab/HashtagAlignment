#!/usr/bin/env python
# coding: utf-8

# #  Run CycleGAN 
# This notebook is optimized for using pytorch (look at the environment on the top right). <br>
# This is the main folder path: [~/ml/](http://localhost:8888/tree/ml)<br>
# Image dataset is located here: [~/ml/dataset_oct_histology/](http://localhost:8888/tree/ml/dataset_oct_histology)<br>
# [Github Link](https://github.com/junyanz/pytorch-CycleGAN-and-pix2pix)<br>
# <br>
# ## Install

# In[ ]:


# Set up general varibles
root_path = '~/ml/'
dataset_path = root_path + 'dataset_oct_histology/'
code_main_folder = root_path + 'pix2pix_and_CycleGAN/'

# Install environment dependencies
get_ipython().system('pip install --upgrade pip')
get_ipython().system('pip install opencv-python')
    
# Get main model
get_ipython().system('git clone --single-branch https://github.com/junyanz/pytorch-CycleGAN-and-pix2pix {code_main_folder}')
get_ipython().system('pip install -r {code_main_folder}requirements.txt')


# ## Train
# Run code below to train model.<br>
# Results can be viewed here: [~/ml/checkpoints/CycleGAN/web/index.html](http://localhost:8888/view/ml/checkpoints/CycleGAN/web/index.html) as the model trains.<br>

# In[ ]:


# Default setting includes flip which trains on left-right flips as well.
# If model is stuck, restart using --continue_train --epoch_count <number> to get numbering right.

patches_folder = dataset_path + 'patches_256px_256px/'

# Make correct data structure
get_ipython().system('cp -r {patches_folder}train_A {patches_folder}trainA ')
get_ipython().system('cp -r {patches_folder}train_B {patches_folder}trainB ')

get_ipython().system('python {code_main_folder}train.py --name CycleGAN --dataroot {patches_folder} --model cycle_gan --checkpoints_dir {root_path}checkpoints')


# ## Test
# 
# Main test results can be viewed here: [~/ml/results/CycleGAN/test_latest/index.html](http://localhost:8888/view/ml/results/CycleGAN/test_latest/index.html) after test command
# 

# In[ ]:


# Make correct data structure
get_ipython().system('cp -r {patches_folder}test_A {patches_folder}testA ')
get_ipython().system('cp -r {patches_folder}test_B {patches_folder}testB ')

# Main test results
get_ipython().system('python {code_main_folder}test.py --name CycleGAN --dataroot {patches_folder} --model cycle_gan --checkpoints_dir {root_path}checkpoints --results_dir {root_path}results')

