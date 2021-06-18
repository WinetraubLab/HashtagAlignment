import tensorflow as tf
import generator
import tester_helpers


class GeneratorTest(tf.test.TestCase):

    def setUp(self):
        super(GeneratorTest, self).setUp()

        self.OCT_image, self.hist_image = tester_helpers.load_tester_images("test_vectors/sample_OCT.jpg",
                                                                            "test_vectors/sample_histology.jpg")

        self.generator, self.generator_loss = None, None

    # Verify that the generator model is not empty
    def test_build_model_not_empty(self):
        self.generator, self.generator_loss = generator.build_model()
        self.assertIsNotNone(self.generator, msg="Generator model must be initialized.")

    # Generate image of generator architecture for verification
    def test_build_model_visualization(self):
        self.generator, self.generator_loss = generator.build_model()
        tf.keras.utils.plot_model(self.generator, show_shapes=True, dpi=64, to_file="gen_model.png")


if __name__ == '__main__':
    tf.test.main()
