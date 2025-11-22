from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)

@app.get("/")
def root():
    return {
        "message": "Hello from DevFest GitOps Demo 🚀", 
        "version": "v1",
        "environment": "production"
    }
