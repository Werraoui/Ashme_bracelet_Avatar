FROM python:3.10

WORKDIR /app

# install system tools
RUN apt-get update && apt-get install -y curl

# install uv
RUN curl -Ls https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# copy project
COPY . .

# install dependencies using uv
RUN uv pip install --system .

# HF Spaces port
EXPOSE 7860

# run FastAPI (CHANGE if your file is not app.py)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]