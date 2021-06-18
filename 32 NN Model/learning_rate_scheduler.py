import tensorflow as tf

'''
This class contains the linearly decaying learning rate scheduler used in the OCT2Hist model 

    Class Members:  
        initial_lr          (float)     : The initial learning rate 
        num_epochs_const_lr (int)       : The number of epochs at which the learning rate should be constant
        num_epochs_decay_lr (int)       : The number of epochs at which the learning rate should decay
        num_batches         (int)       : Number of batches in an epoch
'''
class DelayedLinearDecayLR(tf.keras.optimizers.schedules.LearningRateSchedule):

    def __init__(self, initial_lr, num_epochs_const_lr, num_epochs_decay_lr, num_batches, summary_writer):
        self.initial_learning_rate = initial_lr
        self.num_epochs_const_lr = num_epochs_const_lr
        self.num_epochs_decay_lr = num_epochs_decay_lr
        self.num_batches = num_batches
        self.summary_writer = summary_writer

    '''
    Keeps the learning rate equal to <initial_lr> for the first <num_epochs_const_lr> epochs and then linearly decays 
    the learning rate at each epoch for <num_epochs_decay_lr> epochs 

        Parameters:  
            initial_lr          (float)     : The initial learning rate 
            num_epochs_const_lr (int)       : The number of epochs at which the learning rate should be constant
            num_epochs_decay_lr (int)       : The number of epochs at which the learning rate should decay
            num_batches         (int)       : Number of batches in an epoch
    '''
    def __call__(self, step):
        epoch = step // self.num_batches
        lambda_val = 1.0 - (tf.maximum(0.0, epoch + 1 - self.num_epochs_const_lr) / float(self.num_epochs_decay_lr + 1))
        lr = lambda_val * self.initial_learning_rate

        with self.summary_writer.as_default():
            tf.summary.scalar('lr', lr, step=tf.cast(epoch, tf.int64))

        return lr
