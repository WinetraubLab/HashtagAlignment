import input_pipeline as ip
from oct2hist_model import *
import time
import os
import argparse

if __name__ == '__main__':

    # Setup command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--OCT_data_folders', required=True, nargs='*', help='A file path or a list of space-separated file paths pointing to the folder(s) of OCT images. \
                                                                                 Please see the docstring for load_dataset in input_pipeline.py for more formatting details')
    parser.add_argument('--hist_data_folders', nargs='*', help='A file path or a list of space-separated file paths pointing to the folder(s) of histology images. \
                                                                    Please see the docstring for load_dataset in input_pipeline.py for more formatting details')
    args = parser.parse_args()

    # Specify the number of epochs at which the learning rate should be constant and the number of epochs at which
    # the learning rate should decay
    NUM_EPOCHS_CONST_LR = 100
    NUM_EPOCHS_DECAY_LR = 100
    EPOCHS = NUM_EPOCHS_CONST_LR + NUM_EPOCHS_DECAY_LR

    # Initial dataset and the OCT2Hist model with checkpoints
    train_dataset, num_batches = ip.load_dataset(args.OCT_data_folders, args.hist_data_folders, is_train=True)
    model = OCT2HistModel(num_epochs_const_lr=NUM_EPOCHS_CONST_LR, num_epochs_decay_lr=NUM_EPOCHS_DECAY_LR,
                          num_batches=num_batches, is_train=True)
    checkpoint_dir = './training_checkpoints'
    checkpoint_prefix = os.path.join(checkpoint_dir, "ckpt")
    checkpoint = tf.train.Checkpoint(generator_optimizer=model.generator_optimizer,
                                     discriminator_optimizer=model.discriminator_optimizer,
                                     generator=model.generator,
                                     discriminator=model.discriminator)

    # Training loop
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
