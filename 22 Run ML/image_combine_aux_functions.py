import os
import shutil
import numpy as np
import cv2

# Generic function to combine two images
def combine_images (img_fold_A, img_fold_B, img_fold_AB):
    img_fold_A = os.path.expanduser(img_fold_A)
    img_fold_B = os.path.expanduser(img_fold_B)
    img_fold_AB = os.path.expanduser(img_fold_AB)
    
    # Setup a clean directory
    def setup_clean_dir(d, is_clean=True):
        if is_clean:
            clear_dir(d)
        if not os.path.exists(d):
            os.mkdir(d)

    # Setup parent directory
    setup_clean_dir(os.path.abspath(os.path.join(img_fold_AB, '..')), is_clean = False)
    # Setup AB directory
    setup_clean_dir(img_fold_AB)

    img_list = os.listdir(img_fold_A)
    num_imgs = len(img_list)
    
    for n in range(num_imgs):
        name_A = img_list[n]
        path_A = os.path.join(img_fold_A, name_A)
        name_B = name_A
        path_B = os.path.join(img_fold_B, name_B)
    
        if os.path.isfile(path_A) and os.path.isfile(path_B):
            name_AB = name_A
            path_AB = os.path.join(img_fold_AB, name_AB)
            im_A = cv2.imread(path_A, 1) # python2: cv2.CV_LOAD_IMAGE_COLOR; python3: cv2.IMREAD_COLOR
            im_B = cv2.imread(path_B, 1) # python2: cv2.CV_LOAD_IMAGE_COLOR; python3: cv2.IMREAD_COLOR
            im_AB = np.concatenate([im_A, im_B], 1)
            cv2.imwrite(path_AB, im_AB)

                        
def clear_dir(d):
    if os.path.exists(d) and os.path.isdir(d):
        shutil.rmtree(d)
                     