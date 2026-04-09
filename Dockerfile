FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake build-essential git curl \
    && rm -rf /var/lib/apt/lists/*

# Build s2.cpp with CUDA support
RUN git clone --recurse-submodules https://github.com/rodrigomatta/s2.cpp.git /opt/s2.cpp && \
    cd /opt/s2.cpp && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DS2_CUDA=ON && \
    cmake --build build --parallel $(nproc) && \
    cp build/s2 /usr/local/bin/s2 && \
    rm -rf /opt/s2.cpp/build

# Download Q8_0 model and tokenizer
RUN mkdir -p /models && \
    curl -L -o /models/s2-pro-q8_0.gguf \
    "https://huggingface.co/rodrigomt/s2-pro-gguf/resolve/main/s2-pro-q8_0.gguf" && \
    curl -L -o /models/tokenizer.json \
    "https://huggingface.co/rodrigomt/s2-pro-gguf/resolve/main/tokenizer.json"

# Create references directory
RUN mkdir -p /references

ENV MODEL_PATH=/models/s2-pro-q8_0.gguf
ENV TOKENIZER_PATH=/models/tokenizer.json
ENV HOST=0.0.0.0
ENV PORT=3030
ENV CUDA_DEVICE=0

EXPOSE ${PORT}

CMD s2 -m ${MODEL_PATH} -t ${TOKENIZER_PATH} --server -H ${HOST} -P ${PORT} -c ${CUDA_DEVICE}