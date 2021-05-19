import tensorflow as tf
import input_pipeline as ip
import tester_helpers


class InputPipelineTest(tf.test.TestCase):

    def setUp(self):
        super(InputPipelineTest, self).setUp()

        IMG_JIT_WIDTH = 286
        IMG_JIT_HEIGHT = 286
        IMG_WIDTH = 256
        IMG_HEIGHT = 256

        self.OCT_image, self.hist_image = tester_helpers.load_tester_images("test_vectors/sample_OCT.jpg",
                                                                            "test_vectors/sample_histology.jpg")

        self.rtj_OCT_image, self.rtj_hist_image = ip.random_translate_jitter(self.OCT_image, self.hist_image, IMG_HEIGHT
                                                                             , IMG_WIDTH, IMG_JIT_HEIGHT, IMG_JIT_WIDTH)

        self.rtj_OCT_image1, self.rtj_OCT_image2 = ip.random_translate_jitter(self.OCT_image, self.OCT_image, IMG_HEIGHT
                                                                              , IMG_WIDTH, IMG_JIT_HEIGHT,
                                                                              IMG_JIT_WIDTH)

    # Verify that the spatial dimensions of the OCT and histology image match up
    def test_random_translate_jitter_dimensions(self):
        self.assertEqual(tf.shape(self.rtj_OCT_image)[0:1], tf.shape(self.rtj_hist_image)[0:1],
                         msg="OCT and histology images must both have the same width and height.")

    # Verify that both OCT images undergo the same random transformation
    def test_random_translate_jitter_consistency(self):
        self.assertEqual(self.rtj_OCT_image1, self.rtj_OCT_image2,
                         msg="Both input images must undergo the same random transformation")

    # Verify that the transformation (translation+jitter+flip) is not the same for every OCT+hist image pair
    def test_random_translate_jitter_deterministic(self):
        self.assertNotEqual(self.rtj_OCT_image, self.rtj_OCT_image1,
                            msg="Both input images must undergo the same random transformation")


if __name__ == '__main__':
    tf.test.main()
