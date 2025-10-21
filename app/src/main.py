from fastapi import FastAPI
import os, time

app = FastAPI()
START_TIME = time.time()

@app.get("/healthz")
def health():
    return {"status":"ok","uptime": round(time.time()-START_TIME,2)}

@app.get("/version")
def version():
    return {
        "app": os.getenv("APP_NAME","devops-api"),
        "version": os.getenv("IMAGE_TAG","dev"),
        "instance": os.getenv("INSTANCE_ID","local")
    }

@app.post("/backup")
def backup():
    # demo: non fa nulla, ma torna 200
    return {"status":"queued","bucket": os.getenv("BACKUP_BUCKET","n/a")}
