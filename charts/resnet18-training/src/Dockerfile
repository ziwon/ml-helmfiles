FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

WORKDIR /app

ENV DATA_DIR=/app/data
ENV MODEL_DIR=/app/models
ENV LOG_DIR=/app/logs

ENV VERSION=1
ENV ACCELERATOR=auto
ENV BATCH_SIZE=64
ENV NUM_WORKERS=4
ENV MAX_EPOCHS=10
ENV WEIGHT_DECAY=0.0001
ENV LEARNING_RATE=0.001
ENV DISTRIBUTED_BACKEND=auto

RUN mkdir -p $DATA_DIR $MODEL_DIR $LOG_DIR
RUN useradd -ms /bin/bash app
RUN chown -R app:app /app
USER app

COPY train.py .
COPY requirements.txt .
RUN pip install -r requirements.txt
CMD sh -c 'python train.py \
            --data_dir $DATA_DIR \
            --model_dir $MODEL_DIR \
            --log_dir $LOG_DIR \
            --version $VERSION'
