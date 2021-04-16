import tensorflow as tf
from network_building_blocks import downsample

'''
Constructs a PatchGAN discriminator model. Each block in the discriminator is (Conv -> BatchNorm -> Leaky ReLU)
The shape of the output after the last layer is (batch_size, 30, 30, 1). Each 30x30 patch of the output classifies a 
70x70 portion of the input image (this architecture is what defines the PatchGAN: https://arxiv.org/abs/1611.07004).

    Parameters: None

    Returns:
        patch_GAN_model     (TensorFlow.keras.Model)  : The constructed keras Model object with the desired PatchGAN 
                                                        structure 
        loss_object         (TensorFlow.keras.losses) : The type of GAN loss that the generator will incorporate
'''
def build_model():

    # Weights of all convolutional layers are randomly initialized from a Gaussian distribution with mean 0 and
    # standard deviation 0.02
    initializer = tf.random_normal_initializer(0., 0.02)

    # Define the structure of the images (OCT image and histology image - real or fake) passing into the discriminator.
    # Define the discriminator input as the concatenation of the OCT_image and hist_image Input Tensors
    OCT_image = tf.keras.layers.Input(shape=[256, 256, 3], name='OCT_image')
    hist_image = tf.keras.layers.Input(shape=[256, 256, 3], name='hist_image')
    disc_input = tf.keras.layers.concatenate([OCT_image, hist_image])  # (bs=batch_size, 256, 256, channels*2)

    # Downsample the image dimensions by a factor of 2 three times
    down1 = downsample(64, 4, False)(disc_input)  # (bs, 128, 128, 64)
    down2 = downsample(128, 4)(down1)  # (bs, 64, 64, 128)
    down3 = downsample(256, 4)(down2)  # (bs, 32, 32, 256)

    # Zero pad the height and width by 1 on each side and pass the zero padded result into a convolution layer
    zero_pad1 = tf.keras.layers.ZeroPadding2D()(down3)  # (bs, 34, 34, 256)
    conv = tf.keras.layers.Conv2D(512, 4, strides=1, kernel_initializer=initializer,
                                  use_bias=False)(zero_pad1)  # (bs, 31, 31, 512)

    # Apply batch normalization and a Leaky ReLU activation function
    batchnorm1 = tf.keras.layers.BatchNormalization()(conv)
    leaky_relu = tf.keras.layers.LeakyReLU(alpha=0.2)(batchnorm1)

    # Repeat the zero-padding and convolution steps one more time
    zero_pad2 = tf.keras.layers.ZeroPadding2D()(leaky_relu)  # (bs, 33, 33, 512)
    last = tf.keras.layers.Conv2D(1, 4, strides=1, kernel_initializer=initializer)(zero_pad2)  # (bs, 30, 30, 1)

    # Define the model constructed by the above layers as well as the associated loss function
    patch_GAN_model = tf.keras.Model(inputs=[OCT_image, hist_image], outputs=last)
    loss_object = tf.keras.losses.BinaryCrossentropy(from_logits=True)

    return patch_GAN_model, loss_object

'''
Computes the total loss of the discriminator

    Parameters:
        loss_object             (Tensor) : Loss function associated with the discriminator model 
        disc_real_output        (Tensor) : Output of the discriminator when given the real image
        disc_generated_output   (Tensor) : Output of the discriminator when given the image produced by the generator

    Returns:
        total_disc_loss         (Tensor) : Total discriminator loss
'''
def compute_loss(loss_object, disc_real_output, disc_generated_output):

    # Binary sigmoid cross entropy loss of the discriminator when the discriminator inputs are the real histology images
    # We send an array of ones the same shape as disc_real_output to indicate that all the images are real
    real_loss = loss_object(tf.ones_like(disc_real_output), disc_real_output)

    # Binary sigmoid cross entropy loss of the discriminator when the discriminator inputs are the fake histology images
    # We send an array of zeros the same shape as disc_generated_output to indicate that all the images are fake
    generated_loss = loss_object(tf.zeros_like(disc_generated_output), disc_generated_output)

    # Combine both cross entropy losses (See the pix2pix paper for more details: https://arxiv.org/abs/1611.07004)
    total_disc_loss = real_loss + generated_loss

    return total_disc_loss
