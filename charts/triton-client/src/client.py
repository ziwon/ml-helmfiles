import os
import time
import numpy as np
import tensorflow as tf

from datasets import load_dataset
from PIL import Image

import tritonclient.grpc as grpcclient
from tritonclient.grpc import InferInput, InferRequestedOutput


def preprocess(image):
    img = image.convert('L')
    img = img.resize((224, 224), Image.BILINEAR)
    img = np.array(img).astype(np.float32) / 255.0  # Normalize to [0, 1]
    img = np.expand_dims(img, axis=0)  # Add channel dimension
    return img

def main():
    model_name = os.getenv("MODEL_NAME", "mnist")
    num_samples = int(os.getenv("NUM_SAMPLES", 10))
    model_version = os.getenv("MODEL_VERSION", "1")
    triton_server_url = os.getenv("TRITON_SERVER_URL", "triton-server-default:5001")
    dataset = os.getenv("DATASET", "ylecun/mnist")

    # Load the MNIST dataset from Hugging Face
    dataset = load_dataset(dataset, split="test")

    # Randomly select 10 images from the dataset
    samples = dataset.shuffle(seed=42).select(range(num_samples))

    # Preprocess the images
    input_data = [preprocess(sample["image"]) for sample in samples]
    labels = [sample["label"] for sample in samples]

    # Stack the input data to form a batch and add batch dimension
    input_data = np.stack(input_data)
    #input_data = np.expand_dims(input_data, axis=1)

    # Create Triton client
    triton_client = grpcclient.InferenceServerClient(url=triton_server_url, verbose=False)

    # Create inference input and set data
    inputs = []
    input_tensor = InferInput("input", input_data.shape, "FP32")
    input_tensor.set_data_from_numpy(input_data)
    inputs.append(input_tensor)

    # Define output
    outputs = []
    output = InferRequestedOutput("output")
    outputs.append(output)

    # Perform inference and log latency
    start_time = time.time()
    results = triton_client.infer(model_name=model_name, model_version=model_version, inputs=inputs, outputs=outputs)
    latency = (time.time() - start_time) * 1000
    print(f"Inference latency: {latency:.2f} ms")

    # Get and print the output
    output_data = results.as_numpy("output")
    print("Inference result (logits):", output_data)

    # Convert logits to predicted class
    predicted_classes = np.argmax(output_data, axis=1)
    print("Predicted classes:", predicted_classes)

    # Print grouped truth label
    print("Ground truth labels:", labels)

if __name__ == "__main__":
    main()
