import tensorflow as tf
import tensorflow_addons as tfa
from network_building_blocks import downsample, upsample
from tensorflow import keras
from tensorflow.keras import layers

'''
Constructs ResNet-based generator with that consists of 9 Resnet blocks between a few downsampling/upsampling operations.
    
    Parameters: None
    
    Returns:
        resnet_model    (TensorFlow.keras.Model)  : The constructed keras Model object with the desired ResNet structure 
        loss_object     (TensorFlow.keras.losses) : The type of GAN loss that the generator will incorporate
'''
def build_model():

    # Define the structure of the OCT image passing into the generator
    gen_input = layers.Input(shape=[256, 256, 3], name='OCT_image')

    NUM_BLOCKS = 9
    NUM_OUTPUT_CHANNELS = 3
    NUM_FILTERS = 64  # Number of filters in last convolutional layer
    USE_DROPOUT = True
    NORM_TYPE = "instance"  # Define Normalization layer type: can be "batch" or "instance"

    # Weights of all convolutional layers are randomly initialized from a Gaussian distribution with mean 0 and
    # standard deviation 0.02
    initializer = tf.random_normal_initializer(0., 0.02)

    # Pad the input tensor using the reflection of the input boundary (similar to nn.ReflectionPad2d in PyTorch)
    ref_pad = tf.pad(gen_input, paddings=[[0, 0], [3, 3], [3, 3], [0, 0]], mode='REFLECT')

    # Pass padded tensor through a convolutional layer (bias terms are initialized to 0)
    conv1 = layers.Conv2D(NUM_FILTERS, 7, kernel_initializer=initializer, use_bias=NORM_TYPE == "instance")(ref_pad)

    # Apply a normalization layer
    if NORM_TYPE == "batch":
        norm1 = layers.BatchNormalization()(conv1)
    elif NORM_TYPE == "instance":
        # Use instance norm over the channels
        # (no scaling by gamma or offset by beta - corresponds to affine=False in PyTorch)
        norm1 = tfa.layers.InstanceNormalization(axis=-1, epsilon=1e-5, center=False, scale=False)(conv1)
    else:
        raise Exception("NORM_TYPE must be 'instance' or 'batch'")

    # Apply ReLU function
    downsample_input = layers.ReLU()(norm1)

    # Apply downsampling layers
    n_downsampling = 2
    for i in range(n_downsampling):
        mult = 2 ** i
        # Refer to:
        # https://stackoverflow.com/questions/53819528/how-does-tf-keras-layers-conv2d-with-padding-same-and-strides-1-behave
        # for more information about the padding dimensions. Ultimately, this downsampling procedure involves padding the
        # input by 1 in this case.
        downsample_input = layers.ZeroPadding2D(padding=1)(downsample_input)
        downsample_input = downsample(NUM_FILTERS * mult * 2, 3, norm_type=NORM_TYPE, apply_leaky_relu=False)(downsample_input)

    mult = 2 ** n_downsampling
    # Apply ResNet blocks
    resnet_input = downsample_input
    for i in range(NUM_BLOCKS):
        resnet_input = resnet_block(resnet_input, NUM_FILTERS * mult, USE_DROPOUT, NORM_TYPE)

    upsample_input = resnet_input
    # Upsampling Block
    for i in range(n_downsampling):  # add upsampling layers
        mult = 2 ** (n_downsampling - i)
        upsample_input = layers.ZeroPadding2D(padding=1)(upsample_input)
        upsample_input = upsample(int(NUM_FILTERS * mult) / 2, 3, norm_type=NORM_TYPE, out_pad=1)(upsample_input)

    # Pad the upsampled tensor using the reflection of the input boundary (similar to nn.ReflectionPad2d in PyTorch)
    upsampled_pad = tf.pad(upsample_input, paddings=[[0, 0], [3, 3], [3, 3], [0, 0]], mode='REFLECT')

    # Pass padded tensor through one last conv layer with 3 filters and apply the tanh activation function
    conv_out = layers.Conv2D(NUM_OUTPUT_CHANNELS, 7, kernel_initializer=initializer)(upsampled_pad)
    gen_output = layers.Activation('tanh')(conv_out)

    # Define the model constructed by the above layers as well as the associated loss function
    resnet_model = keras.Model(inputs=gen_input, outputs=gen_output)
    loss_object = keras.losses.BinaryCrossentropy(from_logits=True)
    return resnet_model, loss_object

'''
Define a ResNet block and pass your data through it. A ResNet block is a conv block with skip connections. 
Original Resnet paper: https://arxiv.org/pdf/1512.03385.pdf

    Parameters: 
        input               (Tensor)  : Input into the ResNet block 
        num_filters         (Integer) : Number of filters to use in the convolutional layer
        use_dropout         (Boolean) : Indicates whether or not we want ot apply dropout to our model
        norm_type           (String)  : Indicates if the type of normalization layer that should be included in the 
                                        ResNet block. Can be set to "batch", "instance", or "none"
    Returns:
        block_output        (Tensor) : The output of the ResNet block with skip connections 
'''
def resnet_block(input, num_filters, use_dropout, norm_type):

    res_block_input = input
    for i in range(2):
        # Pad the input tensor using the reflection of the input boundary (similar to nn.ReflectionPad2d in PyTorch)
        padded_input = tf.pad(res_block_input, paddings=[[0, 0], [1, 1], [1, 1], [0, 0]], mode='REFLECT')

        # Weights of all convolutional layers are randomly initialized from a Gaussian distribution with mean 0 and
        # standard deviation 0.02
        initializer = tf.random_normal_initializer(0., 0.02)

        # Pass padded tensor through a convolutional layer (bias terms are initialized to 0)
        conv = layers.Conv2D(num_filters, 3, kernel_initializer=initializer, use_bias=norm_type == "instance")(
                padded_input)

        # Apply a normalization layer
        if norm_type == "batch":
            norm = layers.BatchNormalization()(conv)
        elif norm_type == "instance":
            # Use instance norm over the channels
            # (no scaling by gamma or offset by beta - corresponds to affine=False in PyTorch)
            norm = tfa.layers.InstanceNormalization(axis=-1, epsilon=1e-5, center=False, scale=False)(conv)
        else:
            norm = conv

        if i == 0:
            # Apply ReLU function and dropout
            res_block_input = layers.ReLU()(norm)
            if use_dropout:
                res_block_input = layers.Dropout(rate=0.5)(res_block_input)
        else:
            res_block_input = norm

    return input + res_block_input  # add skip connections

'''
Computes the total loss of the generator

    Parameters:
        loss_object             (Tensor) : Loss function associated with the generator model 
        disc_generated_output   (Tensor) : Output of the discriminator when given the image produced by the generator
        gen_output              (Tensor) : Output image from the generator (fake histology image)
        target                  (Tensor) : Real histology image
        
    Returns:
        total_gen_loss          (Tensor) : Combination of adversarial GAN loss and weighted L1 loss
        gan_loss                (Tensor) : Adversarial GAN loss 
        ground_truth_loss       (Tensor) : L1 loss between the real image and image produced by the generator
'''
def compute_loss(loss_object, disc_generated_output, gen_output, target):

    # Weight set to balance between the adversarial GAN loss and the L1 loss. This parameter is set to 100 in the
    # pix2pix paper
    LAMBDA = 100

    # Binary sigmoid cross entropy loss of the fake histology images and array of ones
    # We send an array of ones the same shape as disc_generated_output because we want to train the generator to create
    # images that fool the discriminator. Therefore, the generator is attempting to minimize the loss so that the fake
    # images appear real to the discriminator
    gan_loss = loss_object(tf.ones_like(disc_generated_output), disc_generated_output)

    # mean absolute error (L1 loss) between the real histology image and the corresponding fake histology image
    # produced by the generator
    ground_truth_loss = tf.reduce_mean(tf.abs(target - gen_output))

    # Total generator loss  (See the pix2pix paper for more details: https://arxiv.org/abs/1611.07004)
    total_gen_loss = gan_loss + (LAMBDA * ground_truth_loss)

    return total_gen_loss, gan_loss, ground_truth_loss
