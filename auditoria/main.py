import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    for record in event["Records"]:
        message = record["body"]
        logger.info(f"Mensaje de auditoría recibido: {message}")
    return {"statusCode": 200}
