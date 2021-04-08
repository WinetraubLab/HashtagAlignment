import tensorflow as tf
import os
import random

'''
Constructs a TensorFlow dataset object

	Parameters:
		OCT_data_folders  (string or list) - A file path or a list of file paths pointing to the folder(s) of OCT images
		hist_data_folders (string or list) - (OPTIONAL) A file path or a list of file paths pointing to the folder(s) of
		 									 histology images. This value can be a blank string or the list can contain 
		 									 blank string entries, in which case the returned TensorFlow dataset object 
		 									 cannot be used for training (is_train = False).
											  
											NOTES:
											
											1. Folder names must end with '/'
											 
											2. The order of OCT and histology folder names in the OCT_data_folders list 
											   and the hist_data_folders list must be in corresponding order across both
											   lists. 
											   
											   Example: 
											   OCT_data_folders  = ['OCT_folder_A/', 'OCT_folder_B/', 'OCT_folder_C/']
											   hist_data_folders = ['hist_folder_A/', 'hist_folder_B/', 'hist_folder_C/']
											
											3. If one or more folders of OCT images don't have a corresponding folder of 
											   histology images, make sure these folder names appear at the end of the 
											   OCT_data_folders list
											   
											   Example: 
											   OCT_data_folders  = ['OCT_folder_A/', 'OCT_folder_C/', 'OCT_folder_B/']
											   hist_data_folders = ['hist_folder_A/', 'hist_folder_C/']
											
											4. Corresponding OCT and histology images must have the same file name 
											   within corresponding data folders. 
											   
											5. The images must be in jpg format.
											  
		is_train     	 (boolean)		   - Indicates whether the OCT_data_folders and hist_data_folders are pointing 
											 to train data or test data. 
											 ** NOTE: When generating the train dataset, we introduce randomization 
											  		  in the form of reshuffling and additional pre-processing to make
											  		  the algorithm more robust. For more information, see docstring 
											  		  for the _preprocess_image function below. **

	Returns:
		dataset 		 (tf.data.Dataset) - A TensorFlow dataset object containing images from data_folder
'''
def load_dataset(OCT_data_folders, hist_data_folders=[''], is_train=True):
	BUFFER_SIZE = 400
	BATCH_SIZE = 1

	# If OCT_data_folders and OCT_data_folders are strings, convert them each to lists of length 1
	if isinstance(OCT_data_folders, str) and isinstance(hist_data_folders, str):
		OCT_data_folders = [OCT_data_folders]
		hist_data_folders = [hist_data_folders]

	# Verify that is_train is set to True only if there are no empty folder names in hist_data_folders
	assert ('' not in hist_data_folders or len(OCT_data_folders) < len(hist_data_folders)) and is_train, \
		'hist_data_folders cannot be empty or cannot contain less folder names than OCT_data_folders when generating ' \
		'a train dataset'

	# Verify that the number of folders in hist_data_folders list is <= the number of folders in hist_data_folders list
	if len(OCT_data_folders) < len(hist_data_folders):
		raise Exception('Length of the list hist_data_folders can only be less than or equal to the length of list '
						'OCT_data_folders.')

	# Pad the hist_data_folders lists with empty strings for the OCT data folders that don't have corresponding
	# histology data folders
	elif len(OCT_data_folders) < len(hist_data_folders):
		while len(OCT_data_folders) != len(hist_data_folders):
			hist_data_folders.append('')

	# Construct TensorFlow dataset by iterating through OCT_data_folders and hist_data_folders
	for i, (OCT_data_folder, hist_data_folder) in enumerate(zip(OCT_data_folders, hist_data_folders)):
		# Create OCT and histology datasets of all files matching the glob pattern jpg
		OCT_dataset = tf.data.Dataset.list_files(OCT_data_folder + '*.jpg', shuffle=False)
		if hist_data_folder != '':
			hist_dataset = tf.data.Dataset.list_files(hist_data_folder + '*.jpg', shuffle=False)
			# Verify that each jpg file in the OCT_data_folder contains a corresponding jpg image of the same name in
			# the hist_data_folder (and vice versa). Throw an exception otherwise.
			OCT_jpg_names = [os.path.basename(x) for x in tf.data.Dataset.as_numpy_iterator(OCT_dataset)]
			hist_jpg_names = [os.path.basename(x) for x in tf.data.Dataset.as_numpy_iterator(hist_dataset)]
			if OCT_jpg_names.sort() != hist_jpg_names.sort():
				raise Exception('1 or more jpg images in {} does not contain a corresponding jpg image of the same name '
								'in {} (or vice versa).'.format(OCT_data_folder, hist_data_folder))

		# If histology images were provided, pair the corresponding OCT and histology images together
		if hist_data_folder != '':
			tmp_dataset = tf.data.Dataset.zip((OCT_dataset, hist_dataset))
		else:
			# If no histology images are provided, duplicate the OCT images in the dataset for tensor format consistency
			tmp_dataset = tf.data.Dataset.zip((OCT_dataset, OCT_dataset))

		# Instantiate dataset on first iteration
		if i == 0:
			dataset = tmp_dataset
		# Append to tmp_dataset to dataset
		else:
			dataset.concatenate(tmp_dataset)

	# Apply the _preprocess_image function to each element of the OCT and histology/OCT datasets and return
	# a new dataset containing the transformed elements, in the same order as they appeared before pre-processing
	dataset = dataset.map(lambda OCT, hist: _preprocess_image(OCT, hist, is_train),
                          num_parallel_calls=tf.data.AUTOTUNE)

	# Randomly shuffle the elements of the dataset
	# The dataset fills a buffer with BUFFER_SIZE elements, then randomly samples elements from this buffer,
	# replacing the selected elements with new elements. For perfect shuffling, a buffer size >= the full size
	# of the dataset is needed
	dataset = dataset.shuffle(BUFFER_SIZE)

	# Combine consecutive elements of this dataset into batches
	# The components of the resulting element will have an additional outer dimension which will be BATCH_SIZE
	dataset = dataset.batch(BATCH_SIZE)

	return dataset

'''
Applies preprocessing steps to the input image. 

If the image is from the train set, it is randomly translated, resized to 286 x 286, randomly cropped to be 256 x 256,
and then the image may be randomly chosen to be mirrored. If the image is from the test set, it is only resized to 
256 x 256. Images from the train and test set are both normalized to have values between -1 and 1. 

	Parameters: 
		OCT_image_file  (string)  : A file path to the OCT image 
		hist_image_file (string)  : A file path to the histology image 
		is_train        (boolean) : Indicates whether the OCT_image_file and hist_image_file are part of the train 
									data or test data

	Returns:
		preprocessed_image (Tensor) : The preprocessed OCT image
'''


def _preprocess_image(OCT_image_file, hist_image_file, is_train):
	# Read in the image, decode the JPEG-encoded image to uint8 tensor, and cast it as a set of floats
	print('placeholder')

	if is_train:
		# translate images by a random amount to increase robustness (only if we are in training mode)
		print('placeholder')
	# resize by 286 x 286 x 3

	# random crop to 256 x 256 x 3 image size

	# random mirroring

	else:

		# resize to 256 x 256 x 3 image size
		print('placeholder')

	# normalize image values to be in range [-1, 1]

	return (OCT_image_file, hist_image_file)
