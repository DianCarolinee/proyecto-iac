docker pull bridgecrew/checkov

docker run --rm \
-v ${PWD}/iac:/app \ 
--workdir /app \
bridgecrew/checkov \ 
--directory /app \
-o junitxml \
--output-file-path results.xml