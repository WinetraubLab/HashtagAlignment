import tensorflow as tf

def load_tester_images(OCT_img_file_path, hist_img_file_path):

    OCT_image = tf.io.read_file(OCT_img_file_path)
    OCT_image = tf.image.decode_jpeg(OCT_image)
    OCT_image = tf.cast(OCT_image, tf.float32)

    hist_image = tf.io.read_file(hist_img_file_path)
    hist_image = tf.image.decode_jpeg(hist_image)
    hist_image = tf.cast(hist_image, tf.float32)

    return OCT_image, hist_image



