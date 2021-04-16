import tensorflow as tf

'''
Constructs a downsampling block made up of three different layers.
1. A 2D Convolution layer with num_filters filters, filter dimensions: (filter_size x filter_size), and a stride of 2
2. A Batch Normalization layer
3. A Leaky ReLU activation function with slope -0.2

    Parameters:
        num_filters             (int) : Number of output filters in the convolution
        filter_size             (int) : Dimension of the filters (filter_size x filter_size)
        apply_batchnorm     (boolean) : Indicates if the batch normalization layer should be included in the 
                                        downsample block 
    
    Returns:
        result  (tf.keras.Sequential) : Downsampling block that contains the convolution, 
                                        batch norm (if apply_batchnorm = True), and LeakyReLU layers 
'''
def downsample(num_filters, filter_size, apply_batchnorm=True):

    # Weights of the convolutional layer are randomly initialized from a Gaussian distribution with mean 0 and
    # standard deviation 0.02
    initializer = tf.random_normal_initializer(0., 0.02)

    # Define the layers within the downsample block (Conv -> BatchNorm -> Leaky ReLU)
    result = tf.keras.Sequential()
    result.add(
      tf.keras.layers.Conv2D(num_filters, filter_size, strides=2, padding='same', kernel_initializer=initializer,
                             use_bias=False))

    # Add a batch normalization layer if specified
    if apply_batchnorm:
        result.add(tf.keras.layers.BatchNormalization())

    # Add a Leaky ReLU activation function with slope -0.2
    result.add(tf.keras.layers.LeakyReLU(alpha=0.2))

    return result
