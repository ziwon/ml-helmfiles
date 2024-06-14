FROM python:3.9

ENV MODEL_NAME=mnist
ENV MODEL_VERSION=1
ENV NUM_SAMPLES=10
ENV DATASET=ylecun/mnist
ENV TRITON_SERVER_URL=triton-server-default:5001

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt
CMD ["python3", "client.py"]
