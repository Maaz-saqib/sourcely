import os
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"
from langchain_huggingface import HuggingFaceEmbeddings
emb = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
print("Success")
