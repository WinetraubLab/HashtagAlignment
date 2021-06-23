"""This module contains simple helper functions """
from __future__ import print_function
import tensorflow as tf
import numpy as np
from PIL import Image
import os


def tensor2im(input_image, imtype=np.uint8):
    """"Converts a Tensor array into a numpy image array.

    Parameters:
        input_image (tensor) --  the input image tensor array
        imtype (type)        --  the desired type of the converted numpy array
    """
    if not isinstance(input_image, np.ndarray):
        if isinstance(input_image, tf.Tensor):  # get the data from a variable
            image_numpy = input_image.numpy()[0]
        else:
            return input_image
        if image_numpy.shape[0] == 1:  # grayscale to RGB
            image_numpy = np.tile(image_numpy, (3, 1, 1))
        image_numpy = (image_numpy + 1) / 2.0 * 255.0  # post-processing: tranpose and scaling
    else:  # if it is a numpy array, do nothing
        image_numpy = input_image
    return image_numpy.astype(imtype)

'''Save a numpy image to the disk

    Parameters:
        image_numpy (numpy array) -- input numpy array
        image_path (str)          -- the path of the image
        original_image_dims (tuple) -- the dimensions of the original image before pre-processing
'''

def save_image(image_numpy, image_path, original_image_dims=None):
    image_pil = Image.fromarray(image_numpy)
    h, w, _ = image_numpy.shape

    if original_image_dims is not None:
        image_pil = image_pil.resize(original_image_dims, Image.ANTIALIAS)
    image_pil.save(image_path, quality=95)


def mkdirs(paths):
    """create empty directories if they don't exist

    Parameters:
        paths (str list) -- a list of directory paths
    """
    if isinstance(paths, list) and not isinstance(paths, str):
        for path in paths:
            mkdir(path)
    else:
        mkdir(paths)


def mkdir(path):
    """create a single empty directory if it didn't exist

    Parameters:
        path (str) -- a single directory path
    """
    if not os.path.exists(path):
        os.makedirs(path)
