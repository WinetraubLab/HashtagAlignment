import input_pipeline as ip
from oct2hist_model import *
import time
# from IPython import display
import os
from matplotlib import pyplot as plt


def generate_images(model, test_input, tar):
    prediction = model(test_input, training=True)
    plt.figure(figsize=(15, 15))

    display_list = [test_input[0], tar[0], prediction[0]]
    title = ['Input Image', 'Ground Truth', 'Predicted Image']

    for i in range(3):
        plt.subplot(1, 3, i + 1)
        plt.title(title[i])
        # getting the pixel values between [0, 1] to plot it.
        plt.imshow(display_list[i] * 0.5 + 0.5)
        plt.axis('off')
    plt.show()


if __name__ == '__main__':

    train_dataset = ip.load_dataset('patches_1024px_512px/train_A/', 'patches_1024px_512px/train_B/', is_train=False)
    #test_dataset = ip.load_dataset('patches_1024px_512px/test_A/', 'patches_1024px_512px/test_B/', is_train=False)
    model = OCT2HistModel()
    checkpoint_dir = './training_checkpoints'
    checkpoint_prefix = os.path.join(checkpoint_dir, "ckpt")
    checkpoint = tf.train.Checkpoint(generator_optimizer=model.generator_optimizer,
                                     discriminator_optimizer=model.discriminator_optimizer,
                                     generator=model.generator,
                                     discriminator=model.discriminator)

    checkpoint.restore(tf.train.latest_checkpoint(checkpoint_dir))

    for example_input, example_target in train_dataset.take(5):
        generate_images(model.generator, example_input, example_target)

