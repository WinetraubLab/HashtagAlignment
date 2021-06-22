import input_pipeline as ip
from oct2hist_model import *
import time
import os

if __name__ == '__main__':

    # Specify the number of epochs at which the learning rate should be constant and the number of epochs at which
    # the learning rate should decay
    NUM_EPOCHS_CONST_LR = 100
    NUM_EPOCHS_DECAY_LR = 100
    EPOCHS = NUM_EPOCHS_CONST_LR + NUM_EPOCHS_DECAY_LR

    train_dataset, num_batches = ip.load_dataset('patches_1024px_512px/train_A/', 'patches_1024px_512px/train_B/',
                                                 is_train=True)
    model = OCT2HistModel(num_epochs_const_lr=NUM_EPOCHS_CONST_LR, num_epochs_decay_lr=NUM_EPOCHS_DECAY_LR,
                          num_batches=num_batches, is_train=True)
    checkpoint_dir = './training_checkpoints'
    checkpoint_prefix = os.path.join(checkpoint_dir, "ckpt")
    checkpoint = tf.train.Checkpoint(generator_optimizer=model.generator_optimizer,
                                     discriminator_optimizer=model.discriminator_optimizer,
                                     generator=model.generator,
                                     discriminator=model.discriminator)

    for epoch in range(EPOCHS):
        start = time.time()

        print("Epoch: ", epoch)

        # Train
        for n, (filepath, input_image, target) in train_dataset.enumerate():
            print('.', end='')
            if (n + 1) % 100 == 0:
                print()
            model.train_step(input_image, target, epoch)
        print()

        # saving (checkpoint) the model every 20 epochs
        if (epoch + 1) % 20 == 0:
            checkpoint.save(file_prefix=checkpoint_prefix)

        print('Time taken for epoch {} is {} sec\n'.format(epoch + 1, time.time() - start))
    checkpoint.save(file_prefix=checkpoint_prefix)
