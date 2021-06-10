import tensorflow as tf

'''
This class contains the linearly decaying learning rate scheduler used in the OCT2Hist model 

    Class Members:  
        initial_lr          (float)     : The initial learning rate 
        num_epochs_const_lr (int)       : The number of epochs at which the learning rate should be constant
        num_epochs_decay_lr (int)       : The number of epochs at which the learning rate should decay
'''
class DelayedLinearDecayLR(tf.keras.optimizers.schedules.LearningRateSchedule):

    def __init__(self, initial_lr, num_epochs_const_lr, num_epochs_decay_lr):
        self.initial_learning_rate = initial_lr
        self.num_epochs_const_lr = num_epochs_const_lr
        self.num_epochs_decay_lr = num_epochs_decay_lr

    '''
    Keeps the learning rate equal to <initial_lr> for the first <num_epochs_const_lr> epochs and then linearly decays 
    the learning rate at each epoch for <num_epochs_decay_lr> epochs 

        Class Members:  
            initial_lr          (float)     : The initial learning rate 
            num_epochs_const_lr (int)       : The number of epochs at which the learning rate should be constant
            num_epochs_decay_lr (int)       : The number of epochs at which the learning rate should decay
    '''
    def __call__(self, step):
        return (1.0 - tf.maximum(0.0, step + 1 - self.num_epochs_const_lr) / float(self.num_epochs_decay_lr + 1)) \
               * self.initial_learning_rate
