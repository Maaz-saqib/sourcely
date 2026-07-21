from langchain_community.document_loaders import YoutubeLoader
import sys
try:
    loader = YoutubeLoader.from_youtube_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ", add_video_info=False)
    docs = loader.load()
    print("Rickroll worked! Length:", len(docs[0].page_content))
except Exception as e:
    print("Failed:", type(e), e)
