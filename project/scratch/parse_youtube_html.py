import re

html_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\assets\Ahmed_Amer_YouTube.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

print("HTML Length:", len(content))

# Find video IDs using regex (e.g. watch?v=XXXXXX)
video_ids = list(set(re.findall(r'watch\?v=([a-zA-Z0-9_-]{11})', content)))
print("Found video IDs:", len(video_ids), video_ids[:10])

# Find playlist IDs using regex (e.g. list=PLXXXXXX)
playlist_ids = list(set(re.findall(r'list=(PL[a-zA-Z0-9_-]+)', content)))
print("Found playlist IDs:", len(playlist_ids), playlist_ids)

# Find video items with title and videoId
items = re.findall(r'"videoId":"([a-zA-Z0-9_-]{11})".*?"title":\{"runs":\[\{"text":"([^"]+)"\}', content)
print("Found items count:", len(items))
for vid, title in items[:15]:
    print(f"VideoId: {vid} | Title: {title}")
