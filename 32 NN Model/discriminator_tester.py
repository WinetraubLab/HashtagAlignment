import tensorflow as tf
import discriminator
import tester_helpers


class DiscriminatorTest(tf.test.TestCase):

    def setUp(self):
        super(DiscriminatorTest, self).setUp()

        self.OCT_image, self.hist_image = tester_helpers.load_tester_images("test_vectors/sample_OCT.jpg",
                                                                            "test_vectors/sample_histology.jpg")

        self.discriminator, self.discriminator_loss = None, None

    # Verify that the discriminator model is not empty
    def test_build_model_not_empty(self):
        self.discriminator, self.discriminator_loss = discriminator.build_model()
        self.assertIsNotNone(self.discriminator, msg="Discriminator model must be initialized.")

    # Generate image of discriminator architecture for verification
    def test_build_model_visualization(self):
        self.discriminator, self.discriminator_loss = discriminator.build_model()
        tf.keras.utils.plot_model(self.discriminator, show_shapes=True, dpi=64, to_file="disc_model.png")

if __name__ == '__main__':
    tf.test.main()
