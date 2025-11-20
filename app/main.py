from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {
        "message": "Hello from DevFest GitOps Demo 🚀", 
        "version": "v1"
    }
