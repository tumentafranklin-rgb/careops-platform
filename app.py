from flask import Flask

app = Flask(__name__)


@app.get("/")
def home():
    return {
        "message": "Welcome to CareOps Platform",
        "version": "v3",
    }


@app.get("/health")
def health():
    return {"status": "healthy"}, 200