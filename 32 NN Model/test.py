import input_pipeline as ip
from oct2hist_model import *
import os
import ntpath
import argparse
from visualization_tools import html, util
from collections import OrderedDict

'''
This function saves images to the disk and saves images stored in 'visuals' to the HTML file specified by 'webpage'.

        Parameters:
            webpage                 (the HTML class) - the HTML webpage class that stores these images (see html.py for more details)
            visuals                 (OrderedDict)    - an ordered dictionary that stores (name, images (either tensor or numpy)) pairs
            image_path              (str)            - the string is used to create image paths
            original_im_dimensions  (tuple)          - the width and height of the image before pre-processing
            width                   (int)            - the images will be resized to width x width
'''


def save_images(webpage, visuals, image_path, original_im_dimensions, width=256):

    # Retrieve directories for image results and name of the image being processed
    image_dir = webpage.get_image_dir()
    image_dir_original_dim = webpage.get_image_original_dim_dir()
    short_path = ntpath.basename(image_path)
    name = os.path.splitext(short_path)[0]

    webpage.add_header(name)
    ims, txts, links = [], [], []

    # Iterate through the OCT, real histology, and generated histology image for each slide
    for label, im_data in visuals.items():
        im = util.tensor2im(im_data)
        image_name = '%s_%s.jpg' % (name, label)
        save_path = os.path.join(image_dir, image_name)
        save_path_original_dim = os.path.join(image_dir_original_dim, image_name)

        util.save_image(im, save_path)
        util.save_image(im, save_path_original_dim, original_im_dimensions)

        ims.append(image_name)
        txts.append(label)
        links.append(image_name)
    webpage.add_images(ims, txts, links, width=width)


if __name__ == '__main__':

    # Setup command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--OCT_data_folders', required=True, nargs='*', help='A file path or a list of space-separated file paths pointing to the folder(s) of OCT images. \
                                                                             Please see the docstring for load_dataset in input_pipeline.py for more formatting details')
    parser.add_argument('--hist_data_folders', nargs='*', help='A file path or a list of space-separated file paths pointing to the folder(s) of histology images. \
                                                                Please see the docstring for load_dataset in input_pipeline.py for more formatting details')
    parser.add_argument('--dataset_type', required=True, type=str, help='Type of dataset: train, test, etc.')

    args = parser.parse_args()

    # Initialize dataset and the OCT2Hist model with checkpoints
    dataset, num_batches = ip.load_dataset(args.OCT_data_folders, args.hist_data_folders, is_train=False)
    model = OCT2HistModel(num_batches=num_batches)
    checkpoint_dir = './training_checkpoints'
    checkpoint_prefix = os.path.join(checkpoint_dir, "ckpt")
    checkpoint = tf.train.Checkpoint(generator_optimizer=model.generator_optimizer,
                                     discriminator_optimizer=model.discriminator_optimizer,
                                     generator=model.generator,
                                     discriminator=model.discriminator)
    # Restore checkpoints from previous training
    checkpoint.restore(tf.train.latest_checkpoint(checkpoint_dir))

    # Save images on disk and create html of images
    phase = args.dataset_type
    web_dir = os.path.join('./results/pix2pix','{}_{}'.format(phase, 'latest'))  # define the website directory
    print('creating web directory', web_dir)
    webpage = html.HTML(web_dir, 'Experiment = %s, Phase = %s, Epoch = %s' % ('pix2pix', phase, 'latest'))

    for n, (filepath, input_image, target) in dataset.enumerate():
        prediction = model.generator(input_image, training=True)
        visuals = OrderedDict([('real_A', input_image), ('fake_B', prediction), ('real_B', target)])
        filepath = str(filepath.numpy()[0])[2:-1]
        save_images(webpage, visuals, filepath, (1024, 512))

    webpage.save()  # save the HTML

