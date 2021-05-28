import input_pipeline as ip
from oct2hist_model import *
import time
import os

if __name__ == '__main__':

    train_dataset = ip.load_dataset('patches_1024px_512px/train_A/', 'patches_1024px_512px/train_B/', is_train=True)
    model = OCT2HistModel()
    checkpoint_dir = './training_checkpoints'
    checkpoint_prefix = os.path.join(checkpoint_dir, "ckpt")
    checkpoint = tf.train.Checkpoint(generator_optimizer=model.generator_optimizer,
                                     discriminator_optimizer=model.discriminator_optimizer,
                                     generator=model.generator,
                                     discriminator=model.discriminator)
    EPOCHS = 200

    for epoch in range(EPOCHS):
        start = time.time()

        print("Epoch: ", epoch)

        # Train
        for n, (input_image, target) in train_dataset.enumerate():
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
