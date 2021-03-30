import tensorflow as tf
import random


'''
Constructs a TensorFlow dataset object

	Parameters:
		data_folder (string) : A file path of the aligned OCT and Histology images
		isTrain     (boolean): Indicates whether the data_folder is pointing to train data or test data

	Returns:
		dataset (tf.data.Dataset) : A TensorFlow dataset object containing images from data_folder
'''
def load_dataset(data_folder, isTrain=True):

	BUFFER_SIZE = 400
	BATCH_SIZE = 1

	# Creates a dataset of all files matching the glob pattern jpg
	dataset = tf.data.Dataset.list_files(data_folder+'*.jpg') 

	if isTrain:

		# Applies the preprocess_image function to each element of this dataset and returns
		# a new dataset containing the transformed elements, in the same order as they appeared in the input
		# NOTE: num_parallel was only specified for train not test (this may need to be changed)
		dataset = dataset.map(lambda x: preprocess_image(x, isTrain), num_parallel_calls=tf.data.AUTOTUNE) 

		# Randomly shuffles the elements of this dataset
		# This dataset fills a buffer with BUFFER_SIZE elements, then randomly samples elements from this buffer,
		# replacing the selected elements with new elements. For perfect shuffling, a buffer size >= the full size 
		# of the dataset is needed
		dataset = dataset.shuffle(BUFFER_SIZE)

	else:

		# Applies the preprocess_image function to each element of this dataset and returns
		# a new dataset containing the transformed elements, in the same order as they appeared in the input
		dataset = dataset.map(lambda x: preprocess_image(x, isTrain)) 

	# Combines consecutive elements of this dataset into batches 
	# The components of the resulting element will have an additional outer dimension which will be BATCH_SIZE
	dataset = dataset.batch(BATCH_SIZE)

	return dataset

'''
Applies preprocessing steps to OCT+Histology image pair. The first step is to separate the OCT+Histology pair
into two separate images. If the OCT and histology images are from the train set, they are randomly translated, 
resized to 286 x 286, randomly cropped to be 256 x 256, and then some images are randomly chosen to be mirrored. 
If the OCT anf histology images are from the test set, they are only resized to 256 x 256. Images from the train 
and test set are both normalized to have values between -1 and 1. 

	Parameters: 
		image_file (string)  : A file path to the OCT+Histology image pair 
		isTrain    (boolean) : Indicates whether the image_file is part of the train data or test data

	Returns:
		input_image (Tensor) : The preprocessed OCT image
		real_image  (Tensor) : The preprocessed histology image
'''
def preprocess_image(image_file, isTrain):

	# Read in the OCT+Histology image pair and decode the JPEG-encoded image to a uint8 tensor

	# Extract the OCT image and cast it as a set of floats

	# Extract the histology image and cast it as a set of floats

    if isTrain:
        # translate images by a random amount to increase robustness (only if we are in training mode)

		# resize by 286 x 286 x 3

		# random crop to 256 x 256 x 3 image size

		# random mirroring

	else:

		# resize to 256 x 256 x 3 image size


	# normalize image values to be in range [-1, 1]

	return input_image, real_image

