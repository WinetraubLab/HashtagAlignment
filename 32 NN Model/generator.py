import tensorflow as tf
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
    loss_object = tf.keras.losses.BinaryCrossentropy(from_logits=True)
    return resnet_model, loss_object

'''
Define a ResNet block. A ResNet block is a conv block with skip connections. 
Original Resnet paper: https://arxiv.org/pdf/1512.03385.pdf

    Parameters: None
    
    Returns:
        block   (Tensor) : A ResNet block 
'''
def resnet_block():

    return block

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
