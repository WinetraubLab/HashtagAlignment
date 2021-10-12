import tensorflow as tf
import discriminator
import generator
import datetime
from learning_rate_scheduler import DelayedLinearDecayLR

'''
This class contains all the components of the OCT2Hist model and with the train_step method. 

    Class Members:  
        
        discriminator            (TensorFlow.keras.Model)       : The constructed keras Model object with the desired 
                                                                  PatchGAN structure 
                                                                  
        discriminator_loss       (TensorFlow.keras.losses)      : The type of GAN loss that the discriminator will incorporate
        
        discriminator_optimizer  (TensorFlow.keras.optimizer)   : The optimizer used to update the discriminator weights
        
        generator                (TensorFlow.keras.Model)       : The constructed keras Model object with the desired 
                                                                  ResNet structure 
                                                                  
        generator_loss           (TensorFlow.keras.losses)      : The type of GAN loss that the generator will incorporate
        
        generator_optimizer      (TensorFlow.keras.optimizer)   : The optimizer used to update the generator weights
        
        summary_writer           (TensorFlow.summary.SummaryWriter) : The SummaryWriter object which tracks metrics (loss, 
                                                                      accuracy, etc.) that can be viewed on TensorBoard
'''


class OCT2HistModel:

    '''
    Initialize class variables

    Parameters:
        num_epochs_const_lr (int)       : The number of epochs at which the learning rate should be constant
        num_epochs_decay_lr (int)       : The number of epochs at which the learning rate should decay
        num_batches         (int)       : Number of batches in an epoch
        is_train            (Boolean)   : Indicates whether the model is being used for training or testing
    '''
    def __init__(self, num_epochs_const_lr=0, num_epochs_decay_lr=0, num_batches=0, is_train=False):
        log_dir = "logs/"
        self.summary_writer = tf.summary.create_file_writer(
            log_dir + "fit/" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))

        self.discriminator, self.discriminator_loss = discriminator.build_model()
        self.generator, self.generator_loss = generator.build_model()

        if is_train:
            self.generator_optimizer = tf.keras.optimizers.Adam(DelayedLinearDecayLR(2e-4, num_epochs_const_lr,
                                                                                     num_epochs_decay_lr, num_batches,
                                                                                     self.summary_writer),
                                                                                     beta_1=0.5, epsilon=1e-8)
            self.discriminator_optimizer = tf.keras.optimizers.Adam(DelayedLinearDecayLR(2e-4, num_epochs_const_lr,
                                                                                         num_epochs_decay_lr, num_batches,
                                                                                         self.summary_writer),
                                                                                         beta_1=0.5, epsilon=1e-8)
        else:
            self.generator_optimizer = tf.keras.optimizers.Adam(2e-4, beta_1=0.5)
            self.discriminator_optimizer = tf.keras.optimizers.Adam(2e-4, beta_1=0.5)

    '''
    Run the OCT and histology image pair through the GAN model and record the losses to be logged on TensorBoard. 
    
    Parameters:
        input_image (Tensor) : The OCT image to be passed through the model 
        target      (Tensor) : The corresponding histology image to be passed through the model 
        epoch       (int)    : Epoch index
    '''
    @tf.function
    def train_step(self, input_image, target, epoch):

        # Enable GradientTape in order to keep track of weight gradients for the discriminator and generator
        with tf.GradientTape() as gen_tape, tf.GradientTape() as disc_tape:

            # Pass the OCT through the generator network
            gen_output = self.generator(input_image, training=True)

            # Pass the OCT and real histology images through the discriminator
            disc_real_output = self.discriminator([input_image, target], training=True)
            # Pass the OCT and fake histology images through the discriminator
            disc_generated_output = self.discriminator([input_image, gen_output], training=True)

            # Compute the GAN adversarial loss, the L1 loss, and the total generator loss using:
            # 1. The generator output
            # 2. The discriminator output (when the discriminator is given the fake histology image)
            # 3. The real histology image
            gen_total_loss, gen_gan_loss, gen_l1_loss = generator.compute_loss(self.generator_loss,
                                                                               disc_generated_output, gen_output,
                                                                               target)

            # Compute the discriminator loss using:
            # 1. The output of the discriminator when it is given the real histology image
            # 2. The output of the discriminator when it is given the fake histology image
            disc_loss = discriminator.compute_loss(self.discriminator_loss, disc_real_output, disc_generated_output)

        # Calculate the generator and discriminator weight gradients
        generator_gradients = gen_tape.gradient(gen_total_loss, self.generator.trainable_variables)
        discriminator_gradients = disc_tape.gradient(disc_loss, self.discriminator.trainable_variables)

        # Update the weights of the generator and discriminator using the calculated gradients
        self.generator_optimizer.apply_gradients(zip(generator_gradients, self.generator.trainable_variables))
        self.discriminator_optimizer.apply_gradients(
            zip(discriminator_gradients, self.discriminator.trainable_variables))

        # Store the loss metrics for future plotting in TensorBoard
        with self.summary_writer.as_default():
            tf.summary.scalar('gen_total_loss', gen_total_loss, step=epoch)
            tf.summary.scalar('gen_gan_loss', gen_gan_loss, step=epoch)
            tf.summary.scalar('gen_l1_loss', gen_l1_loss, step=epoch)
            tf.summary.scalar('disc_loss', disc_loss, step=epoch)
            #tf.summary.image("Training Data", tf.squeeze([input_image, gen_output]), step=epoch)
