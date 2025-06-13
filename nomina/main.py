from fastapi import FastAPI
from mangum import Mangum
import boto3
import uuid
import json
import os
import logging

app = FastAPI()
handler = Mangum(app)

sqs = boto3.client("sqs", region_name="us-east-2")
QUEUE_URL = os.environ.get("QUEUE_URL")

@app.post("/nomina")
def registrar_pago():
    payload = {
        "id": str(uuid.uuid4()),
        "accion": "pago realizado"
    }
    logging.info("Registrando pago y enviando a SQS")
    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(payload))
    return {"message": "Pago registrado"}
