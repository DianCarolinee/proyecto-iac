from fastapi import FastAPI
from mangum import Mangum
import boto3
import uuid
import os
import logging

app = FastAPI()
handler = Mangum(app)

table = boto3.resource('dynamodb', region_name='us-east-2').Table("VisionCleanImages")  # Puedes cambiar a otra tabla si deseas

logging.basicConfig(level=logging.INFO)

@app.post("/empleado")
def crear_empleado():
    empleado_id = str(uuid.uuid4())
    item = {"id": empleado_id, "nombre": "Empleado X"}
    table.put_item(Item=item)
    logging.info(f"Empleado creado: {empleado_id}")
    return item