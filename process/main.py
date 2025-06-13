from fastapi import FastAPI 
from mangum import Mangum
import boto3
import uuid
import os

app = FastAPI()
handler = Mangum(app)

BUCKET_NAME = os.environ.get("BUCKET_NAME", "")

dynamodb = boto3.resource('dynamodb', region_name='us-east-2')
table = dynamodb.Table('VisionCleanImages')

@app.post("/procesar-imagen")
def procesar_imagen():
    image_id = str(uuid.uuid4())
    resultado = {
        "id": image_id,
        "estado": "procesada",
        "resultado": "imagen limpia"
    }
    table.put_item(Item=resultado)
    return {"message": "Procesada", "item": resultado}
