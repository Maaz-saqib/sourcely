from langchain_community.document_loaders import YoutubeLoader
loader = YoutubeLoader.from_youtube_url("https://www.youtube.com/watch?v=RQMj82U_8Vs", add_video_info=False)
docs = loader.load()
print(len(docs))
