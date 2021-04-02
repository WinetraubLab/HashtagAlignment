import tensorflow as tf
import random


'''
Constructs a TensorFlow dataset object

	Parameters:
		OCT_data_folder  (string) 			- A file path pointing to the folder of OCT images
		hist_data_folder (string, optional) - A file path pointing to the folder of histology images. This value can 
											  be blank, in which case the returned TensorFlow dataset object cannot 
											  be used for training (isTrain = False).
											  ** NOTE: We expect corresponding OCT and histology images to have the 
											  		   same file name across both data folders **

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
		isTrain = False

	if isTrain:

		# Apply the _preprocess_image function to each element of the OCT and histology datasets and return
		# new datasets containing the transformed elements, in the same order as they appeared before pre-processing
		OCT_dataset = OCT_dataset.map(lambda x: preprocess_image(x, isTrain), num_parallel_calls=tf.data.AUTOTUNE) 
		hist_dataset = hist_dataset.map(lambda x: preprocess_image(x, isTrain), num_parallel_calls=tf.data.AUTOTUNE) 

		# Pair the corresponding OCT and histology images together
		dataset = tf.data.Dataset.zip((OCT_dataset, hist_dataset))

		# Randomly shuffle the elements of the dataset
		# The dataset fills a buffer with BUFFER_SIZE elements, then randomly samples elements from this buffer,
		# replacing the selected elements with new elements. For perfect shuffling, a buffer size >= the full size 
		# of the dataset is needed
		dataset = dataset.shuffle(BUFFER_SIZE)

	else:

		# Apply the _preprocess_image function to each element of the OCT dataset and return
		# a new dataset containing the transformed elements, in the same order as they appeared before pre-processing
		OCT_dataset = OCT_dataset.map(lambda x: _preprocess_image(x, isTrain)) 

		# If histology images were provided, apply the _preprocess_image function to each element of the histology
		# dataset and return a new dataset containing the transformed elements, in the same order as they appeared 
		# before pre-processing. Pair the corresponding OCT and histology images together
		if hist_data_folder != '':
			hist_dataset = hist_dataset.map(lambda x: _preprocess_image(x, isTrain)) 
			dataset = tf.data.Dataset.zip((OCT_dataset, hist_dataset))
		else:
			# If no histology images are provided in the test set, duplicate the OCT images in the dataset for
			# tensor format consistency 
			dataset = tf.data.Dataset.zip((OCT_dataset, OCT_dataset)) 

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
		image_file (string)  : A file path to the image (OCT or histology)
		isTrain    (boolean) : Indicates whether the image_file is part of the train data or test data

	Returns:
		preprocessed_image (Tensor) : The preprocessed OCT image
'''
def _preprocess_image(image_file, isTrain):

	# Read in the image, decode the JPEG-encoded image to uint8 tensor, and cast it as a set of floats

    if isTrain:
        # translate images by a random amount to increase robustness (only if we are in training mode)

		# resize by 286 x 286 x 3

		# random crop to 256 x 256 x 3 image size

		# random mirroring

	else:

		# resize to 256 x 256 x 3 image size


	# normalize image values to be in range [-1, 1]

	return preprocessed_image

