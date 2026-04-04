FROM python:3.13-slim

WORKDIR /service

COPY pyproject.toml README.md /service/
COPY app /service/app

RUN pip install --no-cache-dir .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
