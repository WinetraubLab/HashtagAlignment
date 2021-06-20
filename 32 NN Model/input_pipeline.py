import tensorflow as tf
import os
import tensorflow_addons as tfa
import math

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
		num_batches      (float)           - The number of batches created from the dataset 
'''


def load_dataset(OCT_data_folders, hist_data_folders=[''], is_train=True):
    BUFFER_SIZE = 553
    BATCH_SIZE = 1

    # If OCT_data_folders and OCT_data_folders are strings, convert them each to lists of length 1
    if isinstance(OCT_data_folders, str):
        OCT_data_folders = [OCT_data_folders]
    if isinstance(hist_data_folders, str):
        hist_data_folders = [hist_data_folders]

    # Verify that is_train is set to True only if there are no empty folder names in hist_data_folders
    if ('' in hist_data_folders or len(OCT_data_folders) > len(hist_data_folders)) and is_train:
        raise Exception('hist_data_folders cannot be empty or cannot contain less folder names than OCT_data_folders '
                        'when generating a train dataset')

    # Verify that the number of folders in hist_data_folders list is <= the number of folders in hist_data_folders list
    if len(OCT_data_folders) < len(hist_data_folders):
        raise Exception('Length of the list hist_data_folders can only be less than or equal to the length of list '
                        'OCT_data_folders.')

    # Pad the hist_data_folders lists with empty strings for the OCT data folders that don't have corresponding
    # histology data folders
    elif len(OCT_data_folders) < len(hist_data_folders):
        while len(OCT_data_folders) != len(hist_data_folders):
            hist_data_folders.append('')

    num_images = 0

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
                raise Exception(
                    '1 or more jpg images in {} does not contain a corresponding jpg image of the same name '
                    'in {} (or vice versa).'.format(OCT_data_folder, hist_data_folder))
            # Keep track of number of OCT-Histology image pairs in the dataset
            num_images += len(OCT_jpg_names)
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
                          num_parallel_calls=tf.data.experimental.AUTOTUNE)

    # Randomly shuffle the elements of the dataset
    # The dataset fills a buffer with BUFFER_SIZE elements, then randomly samples elements from this buffer,
    # replacing the selected elements with new elements. For perfect shuffling, a buffer size >= the full size
    # of the dataset is needed
    dataset = dataset.shuffle(BUFFER_SIZE, seed=8)

    # Combine consecutive elements of this dataset into batches
    # The components of the resulting element will have an additional outer dimension which will be BATCH_SIZE
    dataset = dataset.batch(BATCH_SIZE)

    return dataset, math.ceil(num_images / BATCH_SIZE)

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
    IMG_JIT_WIDTH = 286
    IMG_JIT_HEIGHT = 286
    IMG_WIDTH = 256
    IMG_HEIGHT = 256

    # Read in the images, decode the JPEG-encoded images to uint8 tensor, and cast them as a set of floats
    # Convert the OCT from grayscale to RGB
    OCT_image = tf.io.read_file(OCT_image_file)
    OCT_image = tf.image.decode_jpeg(OCT_image, channels=3)
    OCT_image = tf.cast(OCT_image, tf.float32)

    hist_image = tf.io.read_file(hist_image_file)
    hist_image = tf.image.decode_jpeg(hist_image)
    hist_image = tf.cast(hist_image, tf.float32)

    if is_train:
        # Translate images by a random amount to increase robustness. Also apply random jittering (resize by
        # 286 x 286 x 3, random crop to 256 x 256 x 3 image size, and apply random mirroring)
        OCT_image, hist_image = random_translate_jitter(OCT_image, hist_image, IMG_HEIGHT, IMG_WIDTH, IMG_JIT_HEIGHT,
                                                        IMG_JIT_WIDTH)

    else:
        # resize to 256 x 256 x 3 image size
        OCT_image, hist_image = resize(OCT_image, hist_image, IMG_HEIGHT, IMG_WIDTH)

    # normalize image values to be in range [-1, 1]
    OCT_image, hist_image = normalize(OCT_image, hist_image)

    return (OCT_image, hist_image)


'''
Resizes the input image and corresponding real image to the specified dimensions

	Parameters:
		input_image (Tensor) : A tensor holding the image that is to be translated by the GAN model
		real_image	(Tensor) : A tensor holding the image of the real translation of the input image
		height		(int)	 : Desired height for resizing the tensors
		width		(int)	 : Desired width for resizing the tensors

	Returns:
		resized_input_image (Tensor) : Resized version of input_image Tensor with dimensions (height x width)
		resized_real_image	(Tensor) : Resized version of real_image Tensor with dimensions (height x width)
'''


def resize(input_image, real_image, height, width):
    resized_input_image = tf.image.resize(input_image, [height, width], method=tf.image.ResizeMethod.BICUBIC)
    resized_real_image = tf.image.resize(real_image, [height, width], method=tf.image.ResizeMethod.BICUBIC)

    return resized_input_image, resized_real_image


'''
Randomly crops the input image and corresponding real image to the specified dimensions

	Parameters:
		input_image 		(Tensor) : A tensor holding the image that is to be translated by the GAN model
		real_image			(Tensor) : A tensor holding the image of the real translation of the input image
		height				(int)	 : Desired height for cropping the tensors
		width				(int)	 : Desired width for cropping the tensors

	Returns:
		cropped_image[0]	(Tensor) : Cropped version of input_image Tensor with dimensions (height x width)
		cropped_image[1]	(Tensor) : Cropped version of real_image Tensor with dimensions (height x width)
'''


def random_crop(input_image, real_image, height, width):
    stacked_image = tf.stack([input_image, real_image], axis=0)
    cropped_image = tf.image.random_crop(stacked_image, size=[2, height, width, 3])

    return cropped_image[0], cropped_image[1]


'''
Normalizes the input image and corresponding real image to have values in range [-1, 1]

	Parameters:
		input_image 		(Tensor) : A tensor holding the image that is to be translated by the GAN model
		real_image			(Tensor) : A tensor holding the image of the real translation of the input image

	Returns:
		norm_input_image	(Tensor) : Normalized version of input_image Tensor 
		norm_real_image		(Tensor) : Normalized version of real_image Tensor 
'''


def normalize(input_image, real_image):
    norm_input_image = (input_image / 127.5) - 1
    norm_real_image = (real_image / 127.5) - 1

    return norm_input_image, norm_real_image


'''
Translates images by a random amount to increase robustness. Also apply random jittering (resize by
286 x 286 x 3, random crop to 256 x 256 x 3 image size, and apply random mirroring). These transformations are applied 
to increase robustness in the model.  

	Parameters:
		input_image (Tensor) : A tensor holding the image that is to be translated by the GAN model
		real_image	(Tensor) : A tensor holding the image of the real translation of the input image
		im_height	(int)	 : Desired height for the output Tensors
		im_width	(int)	 : Desired width for the output Tensors
		jit_height	(int)	 : Resize height for jittering
		jit_width	(int)	 : Resize width for jittering

	Returns:
		final_input_image 	(Tensor) : Translated and jittered version of input_image Tensor with dimensions (im_height x im_width)
		final_real_image	(Tensor) : Translated and jittered version of real_image Tensor with dimensions (im_height x im_width)
'''


@tf.function
def random_translate_jitter(input_image, real_image, im_height=256, im_width=256, jit_height=286, jit_width=286):

    shape = tf.shape(input_image)
    height = tf.cast(shape[0], tf.float32)
    width = tf.cast(shape[1], tf.float32)

    # translate images by a random amount to increase robustness
    scale = 0.5
    randx = tf.random.uniform(shape=[], minval=-1, maxval=1) * width * scale
    randy = tf.random.uniform(shape=[], minval=-1, maxval=1) * height * scale

    input_image = tfa.image.translate(input_image, translations=[randx, randy])#, fill_mode='nearest')
    real_image = tfa.image.translate(real_image, translations=[randx, randy])#, fill_mode='nearest')

    # resize
    input_image, real_image = resize(input_image, real_image, jit_height, jit_width)

    # random crop
    out_input_image, out_real_image = random_crop(input_image, real_image, im_height, im_width)

    # random mirroring
    if tf.random.uniform(()) > 0.5:
        out_input_image = tf.image.flip_left_right(out_input_image)
        out_real_image = tf.image.flip_left_right(out_real_image)

    return out_input_image, out_real_image
