import tensorflow as tf
import input_pipeline as ip
import tester_helpers


class InputPipelineTest(tf.test.TestCase):

    def setUp(self):
        super(InputPipelineTest, self).setUp()

        self.OCT_image, self.hist_image = tester_helpers.load_tester_images("test_vectors/sample_OCT.jpg",
                                                                            "test_vectors/sample_histology.jpg")

        self.rtj_OCT_image, self.rtj_hist_image = ip.random_translate_jitter(self.OCT_image, self.hist_image)

        self.rtj_OCT_image1, self.rtj_OCT_image2 = ip.random_translate_jitter(self.OCT_image, self.OCT_image)

    # Verify that the dimensions of the OCT and histology image match up
    def test_random_translate_jitter_matching_dimensions(self):
        self.assertAllEqual(tf.shape(self.rtj_OCT_image), tf.shape(self.rtj_hist_image),
                         msg="OCT and histology images must both have the same width, height, and number of channels.")

    # Verify that the dimensions of the OCT image is 256x256x3
    def test_random_translate_jitter_OCT_correct_dimensions(self):
        self.assertAllEqual(tf.shape(self.rtj_OCT_image), tf.shape(tf.ones([256, 256, 3])),
                            msg="OCT images must both have shape 256x256x3.")

    # Verify that the dimensions of the histology image is 256x256x3
    def test_random_translate_jitter_hist_correct_dimensions(self):
        self.assertAllEqual(tf.shape(self.rtj_OCT_image), tf.shape(tf.ones([256, 256, 3])),
                            msg="Histology images must both have shape 256x256x3.")

    # Verify that both OCT images undergo the same random transformation
    def test_random_translate_jitter_consistency(self):
        self.assertAllEqual(self.rtj_OCT_image1, self.rtj_OCT_image2,
                         msg="Both input images must undergo the same random transformation")

    # Verify that the transformation (translation+jitter+flip) is not the same for every OCT+hist image pair
    def test_random_translate_jitter_deterministic(self):
        self.assertNotAllEqual(self.rtj_OCT_image, self.rtj_OCT_image1,
                            msg="Both input images must undergo the same random transformation")

    # Verify that the dimensions of the OCT and histology image match up for resize function


if __name__ == '__main__':
    tf.test.main()
