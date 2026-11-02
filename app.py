from flask import Flask

app = Flask(__name__)


@app.get("/")
def home():
    return {"message": "Welcome to CareOps Platform"}


@app.get("/health")
def health():
    return {"status": "healthy"}, 200