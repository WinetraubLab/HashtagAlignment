import tensorflow as tf
import os
import random


'''
Constructs a TensorFlow dataset object

	Parameters:
		OCT_data_folder  (string) 			- A file path pointing to the folder of OCT images
		hist_data_folder (string, optional) - A file path pointing to the folder of histology images. This value can 
											  be blank, in which case the returned TensorFlow dataset object cannot 
											  be used for training (isTrain = False).
											  ** NOTE: We expect corresponding OCT and histology images to have the 
											  		   same file name across both data folders. The images also must 
											  		    be in jpg format. **

		isTrain     	 (boolean)			- Indicates whether the OCT_data_folder and hist_data_folder are pointing 
											  to train data or test data. 
											  ** NOTE: When generating the train dataset, we introduce randomization 
											  		   in the form of reshuffling and additional pre-processing to make
											  		   the algorithm more robust. For more information, see docstring 
											  		   for the _preprocess_image function below. **

	Returns:
		dataset 		 (tf.data.Dataset)  - A TensorFlow dataset object containing images from data_folder
'''
def load_dataset(OCT_data_folder, hist_data_folder='', isTrain=True):

	BUFFER_SIZE = 400
	BATCH_SIZE = 1

	# Create OCT and histology datasets of all files matching the glob pattern jpg
	OCT_dataset = tf.data.Dataset.list_files(OCT_data_folder+'*.jpg', shuffle=False)
	if hist_data_folder != '':
		hist_dataset = tf.data.Dataset.list_files(hist_data_folder+'*.jpg', shuffle=False)
		# Verify that each jpg file in the OCT_data_folder contains a corresponding jpg image of the same name in
		# the hist_data_folder (and vice versa). Throw an exception otherwise.
		OCT_jpg_names = [os.path.basename(x) for x in tf.data.Dataset.as_numpy_iterator(OCT_dataset)]
		hist_jpg_names = [os.path.basename(x) for x in tf.data.Dataset.as_numpy_iterator(hist_dataset)]
		if OCT_jpg_names.sort() != hist_jpg_names.sort():
			raise Exception('1 or more jpg images in OCT_data_folder does not contain a corresponding jpg image of the '
							'same name in hist_data_folder (or vice versa).')
	# Verify that isTrain is set to True only if the user provides a folder of histology images
	elif isTrain:
		raise Exception('hist_data_folder cannot be empty when generating a train dataset')

	# Generate train dataset
	if isTrain:

		# Pair the corresponding OCT and histology images together
		dataset = tf.data.Dataset.zip((OCT_dataset, hist_dataset))

		# Apply the _preprocess_image function to each element of the OCT and histology datasets and return
		# a new dataset containing the transformed elements, in the same order as they appeared before pre-processing
		dataset = dataset.map(lambda OCT, hist: _preprocess_image(OCT, hist, isTrain),
							  num_parallel_calls=tf.data.AUTOTUNE)

		# Randomly shuffle the elements of the dataset
		# The dataset fills a buffer with BUFFER_SIZE elements, then randomly samples elements from this buffer,
		# replacing the selected elements with new elements. For perfect shuffling, a buffer size >= the full size
		# of the dataset is needed
		dataset = dataset.shuffle(BUFFER_SIZE)

	# Generate test dataset
	else:

		# If histology images were provided, pair the corresponding OCT and histology images together
		if hist_data_folder != '':
			dataset = tf.data.Dataset.zip((OCT_dataset, hist_dataset))
		else:
			# If no histology images are provided in the test set, duplicate the OCT images in the dataset for
			# tensor format consistency
			dataset = tf.data.Dataset.zip((OCT_dataset, OCT_dataset))

		# Apply the _preprocess_image function to each element of the OCT and histology/OCT datasets and return
		# a new dataset containing the transformed elements, in the same order as they appeared before pre-processing
		dataset = dataset.map(lambda OCT, hist: _preprocess_image(OCT, hist, isTrain))

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
		isTrain         (boolean) : Indicates whether the OCT_image_file and hist_image_file are part of the train 
									data or test data

	Returns:
		preprocessed_image (Tensor) : The preprocessed OCT image
'''
def _preprocess_image(OCT_image_file, hist_image_file, isTrain):

	# Read in the image, decode the JPEG-encoded image to uint8 tensor, and cast it as a set of floats
	print('placeholder')

	if isTrain:
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


