import json

json_path = r"c:\Users\User\Documents\Obsidian\projects\Streamer_app\project\scratch\ahmed_amer_videos.json"

with open(json_path, "r", encoding="utf-8") as f:
    videos = json.load(f)

for idx, v in enumerate(videos[:20]):
    # replace non-ascii for safe printing
    safe_title = v['title'].encode('ascii', 'xmlcharrefreplace').decode('ascii')
    print(f"{idx+1}. ID: {v['vid']} | Title: {safe_title}")
