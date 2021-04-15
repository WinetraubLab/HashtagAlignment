import tensorflow as tf

'''
Constructs a PatchGAN discriminator model. Each block in the discriminator is (Conv -> BatchNorm -> Leaky ReLU)
The shape of the output after the last layer is (batch_size, 30, 30, 1). Each 30x30 patch of the output classifies a 
70x70 portion of the input image (this architecture is what defines the PatchGAN).

    Parameters: None

    Returns:
        patch_GAN_model     (TensorFlow.keras.Model)  : The constructed keras Model object with the desired PatchGAN 
                                                        structure 
        loss_object         (TensorFlow.keras.losses) : The type of GAN loss that the generator will incorporate
'''
def build_model():
    loss_object = tf.keras.losses.BinaryCrossentropy(from_logits=True)
    return patch_GAN_model, loss_object

'''
Computes the total loss of the discriminator

    Parameters:
        loss_object             (Tensor) : Loss function associated with the discriminator model 
        disc_real_output        (Tensor) : Output of the discriminator when given the real image
        disc_generated_output   (Tensor) : Output of the discriminator when given the image produced by the generator
    ß
    Returns:
        total_disc_loss         (Tensor) : Total discriminator loss
'''
def compute_loss(loss_object, disc_real_output, disc_generated_output):

    real_loss = loss_object(tf.ones_like(disc_real_output), disc_real_output)

    generated_loss = loss_object(tf.zeros_like(disc_generated_output), disc_generated_output)

    total_disc_loss = real_loss + generated_loss

    return total_disc_loss
