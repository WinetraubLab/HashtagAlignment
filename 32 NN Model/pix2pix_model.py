import tensorflow as tf
import discriminator
import generator
import datetime

'''
This class contains all the components of the Pix2Pix model and with the train_step method. 

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
class Pix2PixModel:

    def __init__(self):
        self.discriminator, self.discriminator_loss = discriminator.build_model()
        self.generator, self.generator_loss = generator.build_model()
        self.generator_optimizer = tf.keras.optimizers.Adam(2e-4, beta_1=0.5)
        self.discriminator_optimizer = tf.keras.optimizers.Adam(2e-4, beta_1=0.5)

        log_dir = "logs/"
        self.summary_writer = tf.summary.create_file_writer(
            log_dir + "fit/" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))

    '''
    Run the OCT and histology image pair through the GAN model and record the losses to be logged on TensorBoard. 
    
    Parameters:
        input_image (Tensor) : The OCT image to be passed through the model 
        target      (Tensor) : The corresponding histology image to be passed through the model 
        epoch       (int)    : Epoch index
    '''
    @tf.function
    def train_step(self, input_image, target, epoch):
        pass
