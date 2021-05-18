import tensorflow as tf
import tensorflow_addons as tfa

'''
Constructs a downsampling block made up of three different layers.
1. A 2D Convolution layer with num_filters filters, filter dimensions: (filter_size x filter_size), and a stride of 2
2. An Instance or Batch Normalization layer
3. A Leaky ReLU activation function with slope -0.2

    Parameters:
        num_filters             (int) : Number of output filters in the convolution
        filter_size             (int) : Dimension of the filters (filter_size x filter_size)
        norm_type            (string) : Indicates if the type of normalization layer that should be included in the 
                                        downsample block. Can be set to "batch", "instance", or "none"
        apply_leaky_relu    (boolean) : Indicates if the ReLU layer should be leaky or normal 
    
    Returns:
        result  (tf.keras.Sequential) : Downsampling block that contains the convolution, 
                                        batch norm (if apply_batchnorm = True), and LeakyReLU layers 
'''
def downsample(num_filters, filter_size, norm_type, apply_leaky_relu=True):

    # Verify that norm_type is a valid entry
    if norm_type not in ["batch", "instance", "none"]:
        raise Exception("norm_type must be 'instance', 'batch', or 'none'")

    # Weights of the convolutional layer are randomly initialized from a Gaussian distribution with mean 0 and
    # standard deviation 0.02
    initializer = tf.random_normal_initializer(0., 0.02)

    # Define the layers within the downsample block (Conv -> BatchNorm -> Leaky ReLU)
    result = tf.keras.Sequential()
    result.add(
      tf.keras.layers.Conv2D(num_filters, filter_size, strides=2, padding='same', kernel_initializer=initializer,
                             use_bias=norm_type == "instance"))

    # Add a batch or instance normalization layer if specified
    if norm_type == "batch":
        result.add(tf.keras.layers.BatchNormalization())
    elif norm_type == "instance":
        result.add(tfa.layers.InstanceNormalization(axis=-1, epsilon=1e-5, center=False, scale=False))

    # Add a Leaky ReLU activation function with slope -0.2 or add normal ReLU
    if apply_leaky_relu:
        result.add(tf.keras.layers.LeakyReLU(alpha=0.2))
    else:
        result.add(tf.keras.layers.ReLU())

    return result


'''
Constructs an upsampling block made up of three different layers.
1. A 2D Convolution Transpose layer with num_filters filters, filter dimensions: (filter_size x filter_size), 
   and a stride of 2
2. An Instance or Batch Normalization layer
3. A ReLU activation function

    Parameters:
        num_filters             (int) : Number of output filters in the convolution
        filter_size             (int) : Dimension of the filters (filter_size x filter_size)
        norm_type            (string) : Indicates if the type of normalization layer that should be included in the 
                                        downsample block. Can be set to "batch", "instance", or "none"
        out_pad                 (int) : Amount of output padding to add to each size of the image

    Returns:
        result  (tf.keras.Sequential) : Downsampling block that contains the convolution, 
                                        batch norm (if apply_batchnorm = True), and LeakyReLU layers 
'''


def upsample(num_filters, filter_size, norm_type, out_pad):
    # Verify that norm_type is a valid entry
    if norm_type not in ["batch", "instance", "none"]:
        raise Exception("norm_type must be 'instance', 'batch', or 'none'")

    # Weights of the convolutional layer are randomly initialized from a Gaussian distribution with mean 0 and
    # standard deviation 0.02
    initializer = tf.random_normal_initializer(0., 0.02)

    # Define the layers within the downsample block (Conv -> BatchNorm -> Leaky ReLU)
    result = tf.keras.Sequential()
    result.add(
        tf.keras.layers.Conv2DTranspose(num_filters, filter_size, strides=2, padding='same',
                                        kernel_initializer=initializer, use_bias=norm_type == "instance",
                                        output_padding=out_pad))

    # Add a batch or instance normalization layer if specified
    if norm_type == "batch":
        result.add(tf.keras.layers.BatchNormalization())
    elif norm_type == "instance":
        result.add(tfa.layers.InstanceNormalization(axis=-1, epsilon=1e-5, center=False, scale=False))

    # Add normal ReLU layer
    result.add(tf.keras.layers.ReLU())

    return result
